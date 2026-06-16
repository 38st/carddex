-- Public market data must be readable by the anon/authenticated roles via
-- PostgREST and Edge Functions. RLS policies gate rows; these grant table access.
grant usage on schema public to anon, authenticated, service_role;
grant select on card_sales to anon, authenticated, service_role;
grant select on card_grade_values to anon, authenticated, service_role;
grant select on market_index_points to anon, authenticated, service_role;
