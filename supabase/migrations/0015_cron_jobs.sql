-- 0015: Cron jobs for market data pipeline.
--   1) rollup_all_cards()     — recompute every card's grade values + 30d change
--   2) recompute_market_index() — rebuild daily index points from grade values
--   3) snapshot_market_prices() — capture current Raw price into price_snapshots
--   4) pg_cron schedules for all three + ebay-ingest edge function trigger
--
-- Requires the pg_cron + pg_net extensions (enabled by default on Supabase).

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists dblink;

-- ──────────────────────────────────────────────────────────────────────────────
-- 1) Rollup ALL cards (batch version of rollup_card). Recomputes per-grade
--    market_price + 30d change for every card that has recent sales.
-- ──────────────────────────────────────────────────────────────────────────────
create or replace function rollup_all_cards() returns void language plpgsql as $$
declare card_id text;
begin
  for card_id in select distinct card_id from card_sales where sold_at >= now() - interval '30 days' loop
    perform rollup_card(card_id);
  end loop;
end $$;

-- ──────────────────────────────────────────────────────────────────────────────
-- 2) Recompute the overall + per-category market indices.
--    The overall index is the equal-weighted average of all cards' top-grade
--    market_price. Categories are computed from cards.sport (sports) or
--    cards.game (pokemon/magic/yugioh). One point per day.
-- ──────────────────────────────────────────────────────────────────────────────
create or replace function recompute_market_index() returns void language plpgsql as $$
declare
  overall numeric;
  cat_name text;
  cat_value numeric;
  today date := now()::date;
begin
  -- Overall index: average of top-grade market prices across all priced cards.
  select avg(market_price) into overall
    from card_grade_values cgv
    join cards c on c.id = cgv.card_id
   where cgv.market_price is not null and cgv.market_price > 0
     and cgv.grade = (
       select grade from card_grade_values sub
        where sub.card_id = cgv.card_id
        order by market_price desc limit 1
     );

  if overall is not null then
    insert into market_index_points (category, as_of, value)
    values (null, today, round(overall, 2))
    on conflict (category, as_of) do update set value = excluded.value;
  end if;

  -- Per-category indices.
  -- Sports: one index per sport value.
  for cat_name in select distinct sport from cards where sport is not null loop
    select avg(market_price) into cat_value
      from card_grade_values cgv
      join cards c on c.id = cgv.card_id
     where c.sport = cat_name
       and cgv.market_price is not null and cgv.market_price > 0
       and cgv.grade = (
         select grade from card_grade_values sub
          where sub.card_id = cgv.card_id
          order by market_price desc limit 1
       );

    if cat_value is not null then
      insert into market_index_points (category, as_of, value)
      values (cat_name, today, round(cat_value, 2))
      on conflict (category, as_of) do update set value = excluded.value;
    end if;
  end loop;

  -- TCG categories: pokemon, magic, yugioh.
  for cat_name in select unnest(array['pokemon','magic','yugioh']) loop
    select avg(market_price) into cat_value
      from card_grade_values cgv
      join cards c on c.id = cgv.card_id
     where c.game = cat_name::card_game
       and cgv.market_price is not null and cgv.market_price > 0
       and cgv.grade = (
         select grade from card_grade_values sub
          where sub.card_id = cgv.card_id
          order by market_price desc limit 1
       );

    if cat_value is not null then
      insert into market_index_points (category, as_of, value)
      values (cat_name, today, round(cat_value, 2))
      on conflict (category, as_of) do update set value = excluded.value;
    end if;
  end loop;
end $$;

-- ──────────────────────────────────────────────────────────────────────────────
-- 3) Snapshot current market prices into price_snapshots for historical charts.
--    Captures the Raw (ungraded) price per card once daily.
-- ──────────────────────────────────────────────────────────────────────────────
create or replace function snapshot_market_prices() returns void language plpgsql as $$
begin
  insert into price_snapshots (card_id, source, market_price, currency, captured_at)
  select cgv.card_id, 'rollup', cgv.market_price, 'USD', now()
    from card_grade_values cgv
   where cgv.grade = 'Raw'
     and cgv.market_price is not null
     and cgv.market_price > 0
   group by cgv.card_id, cgv.market_price;

  -- Also update cards.market_price for the catalog join used by sync.
  update cards c
    set market_price = sub.market_price, last_priced_at = now()
   from (
     select card_id, market_price
       from card_grade_values
      where grade = 'Raw'
        and market_price is not null
   ) sub
  where c.id = sub.card_id;
end $$;

-- ──────────────────────────────────────────────────────────────────────────────
-- 4) pg_cron schedules.
--    Times are in UTC (pg_cron default). Staggered to avoid contention.
-- ──────────────────────────────────────────────────────────────────────────────

-- Daily at 02:00 UTC: rollup all cards from recent sales.
select cron.schedule('rollup-all-cards', '0 2 * * *', 'select rollup_all_cards()');

-- Daily at 02:15 UTC: recompute market indices from grade values.
select cron.schedule('recompute-index', '15 2 * * *', 'select recompute_market_index()');

-- Daily at 02:30 UTC: snapshot prices for historical charts + update cards.market_price.
select cron.schedule('snapshot-prices', '30 2 * * *', 'select snapshot_market_prices()');

-- Daily at 03:00 UTC: trigger the ebay-ingest Edge Function to pull fresh sold data.
-- Uses pg_net to POST to the function endpoint (service-role key required as secret).
-- The ANON_KEY and SUPABASE_URL are injected from the cron job's environment.
-- On Supabase cloud, `net.http_post` is available via pg_net.
select cron.schedule(
  'ebay-ingest',
  '0 3 * * *',
  $$select net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/ebay-ingest',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
      'apikey', current_setting('app.service_role_key')
    ),
    body := '{}'::jsonb
  )$$
);

-- Daily at 04:00 UTC: trigger the catalog-sync Edge Function to refresh card data.
select cron.schedule(
  'catalog-sync',
  '0 4 * * *',
  $$select net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/catalog-sync',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
      'apikey', current_setting('app.service_role_key')
    ),
    body := '{}'::jsonb
  )$$
);
