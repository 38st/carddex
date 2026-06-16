-- 0010: eBay ingestion support — a per-card search query + a rollup that turns
-- raw card_sales into card_grade_values (30-day avg price per grade + 30d change).

alter table cards add column if not exists ebay_query text;

-- Recompute a card's per-grade values from its raw sales. Call after ingesting.
create or replace function rollup_card(p_card_id text) returns void language plpgsql as $$
declare g text;
begin
  insert into card_grade_values (card_id, grade, market_price, updated_at)
  select card_id, grade, round(avg(price)::numeric, 2), now()
    from card_sales
   where card_id = p_card_id and sold_at >= now() - interval '30 days'
   group by card_id, grade
  on conflict (card_id, grade) do update
     set market_price = excluded.market_price,
         updated_at   = now();

  for g in select distinct grade from card_sales where card_id = p_card_id loop
    perform refresh_grade_change(p_card_id, g);
  end loop;
end $$;
