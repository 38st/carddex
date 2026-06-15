-- Pricing: per-condition snapshots + a latest-price cache for fast valuation.

alter table price_snapshots add column if not exists condition text;
alter table price_snapshots add column if not exists low_price numeric;
alter table price_snapshots add column if not exists high_price numeric;

create table if not exists card_prices_latest (
    card_id      text not null references cards(id),
    source       text not null,            -- 'tcgplayer'|'scryfall'|'cardmarket'|'ebay'|'pricecharting'
    market_price numeric,
    currency     text not null default 'USD',
    captured_at  timestamptz not null default now(),
    primary key (card_id, source)
);
create index if not exists card_prices_latest_card_idx on card_prices_latest(card_id);
alter table card_prices_latest enable row level security;
create policy "latest prices public read" on card_prices_latest for select using (true);

-- Maintain the latest-price cache on every snapshot insert (last-writer-wins per source).
create or replace function upsert_latest_price() returns trigger language plpgsql as $$
begin
    insert into card_prices_latest (card_id, source, market_price, currency, captured_at)
    values (new.card_id, new.source, new.market_price, new.currency, new.captured_at)
    on conflict (card_id, source) do update
        set market_price = excluded.market_price,
            currency     = excluded.currency,
            captured_at  = excluded.captured_at
        where excluded.captured_at >= card_prices_latest.captured_at;
    return new;
end $$;
drop trigger if exists price_latest_trg on price_snapshots;
create trigger price_latest_trg after insert on price_snapshots
    for each row execute function upsert_latest_price();
