-- Collection hardening: sync metadata, foil/grade, condition constraint, dedupe.

alter table collection_items add column if not exists updated_at timestamptz not null default now();
alter table collection_items add column if not exists is_foil boolean not null default false;
alter table collection_items add column if not exists grade text;          -- 'PSA 10', null = raw
alter table collection_items add column if not exists notes text;
alter table collection_items add column if not exists source_scan_id uuid;

alter table collection_items
    add constraint collection_items_condition_chk
    check (condition in ('Mint', 'Near Mint', 'Lightly Played', 'Moderately Played', 'Heavily Played', 'Damaged'));

create index if not exists collection_items_card_idx      on collection_items(card_id);
create index if not exists collection_items_user_game_idx on collection_items(user_id, card_id);

-- One stack per (user, card, condition, foil, grade) — lets upsert stack quantities.
create unique index if not exists collection_items_dedupe_idx
    on collection_items(user_id, card_id, condition, is_foil, coalesce(grade, ''));

-- Keep updated_at fresh for last-write-wins sync.
create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin
    new.updated_at := now();
    return new;
end $$;
drop trigger if exists collection_items_touch on collection_items;
create trigger collection_items_touch before update on collection_items
    for each row execute function touch_updated_at();
