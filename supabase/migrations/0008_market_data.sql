-- 0008: Card Ladder-style market data — raw sales, per-grade values, and indices.
-- This is the schema the app's Market features read from once live. Populate it
-- from a sales source (see supabase/README.md → "Sports market data").

-- Raw completed sales — the data behind every price. One row per sale.
create table if not exists card_sales (
    id          bigint generated always as identity primary key,
    card_id     text not null references cards(id),
    grade       text not null,                 -- 'PSA 10' | 'PSA 9' | 'Raw' | ...
    price       numeric not null,
    currency    text not null default 'USD',
    platform    text not null,                 -- 'eBay' | 'Goldin' | 'PWCC' | 'Heritage' | ...
    sold_at     timestamptz not null,
    source      text not null default 'ebay',  -- ingestion source
    external_id text,                           -- de-dupe key from the source
    created_at  timestamptz not null default now(),
    unique (source, external_id)
);
create index if not exists card_sales_card_grade_idx on card_sales(card_id, grade, sold_at desc);

-- Latest value + population per (card, grade). Maintained by the ingestion job.
create table if not exists card_grade_values (
    card_id      text not null references cards(id),
    grade        text not null,
    market_price numeric,
    population   int,
    change_30d   numeric,                       -- percent change over 30 days
    updated_at   timestamptz not null default now(),
    primary key (card_id, grade)
);

-- Daily index values. category null = the overall "Case Index"; otherwise a
-- per-category sub-index ('basketball' | 'football' | 'baseball' | …).
create table if not exists market_index_points (
    id       bigint generated always as identity primary key,
    category text,
    as_of    date not null,
    value    numeric not null,
    unique (category, as_of)
);
create index if not exists market_index_points_cat_idx on market_index_points(category, as_of);

-- Public read (market data is shared, like the catalog). Writes are service-role only.
alter table card_sales enable row level security;
alter table card_grade_values enable row level security;
alter table market_index_points enable row level security;

create policy "sales public read" on card_sales for select using (true);
create policy "grade values public read" on card_grade_values for select using (true);
create policy "index public read" on market_index_points for select using (true);

-- Roll the 30-day change for a (card, grade) from raw sales. Call from the
-- ingestion job after inserting new sales, or schedule via pg_cron.
create or replace function refresh_grade_change(p_card_id text, p_grade text)
returns void language plpgsql as $$
declare
    recent numeric;
    prior  numeric;
begin
    select avg(price) into recent
    from card_sales
    where card_id = p_card_id and grade = p_grade
      and sold_at >= now() - interval '7 days';

    select avg(price) into prior
    from card_sales
    where card_id = p_card_id and grade = p_grade
      and sold_at >= now() - interval '37 days'
      and sold_at <  now() - interval '30 days';

    if recent is not null and prior is not null and prior <> 0 then
        update card_grade_values
        set change_30d = round(((recent - prior) / prior) * 100, 2),
            updated_at = now()
        where card_id = p_card_id and grade = p_grade;
    end if;
end $$;
