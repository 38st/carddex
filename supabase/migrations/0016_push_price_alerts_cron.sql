-- 0016: Schedule the push-price-alerts Edge Function.
--
-- Runs hourly: the function evaluates active price_alerts against current
-- cards.market_price and sends APNs pushes for any that just reached target
-- (and re-arms ones that fell back). Mirrors the ebay-ingest cron in 0015.
--
-- Device tokens (device_tokens) and price_alerts already exist (migration 0005);
-- this only adds the schedule. APNs secrets are configured on the function, not
-- here (APNS_KEY_P8 / APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID / APNS_HOST).

-- Hourly on the hour: evaluate + push price alerts.
select cron.schedule(
  'push-price-alerts',
  '0 * * * *',
  $$select net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/push-price-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
      'apikey', current_setting('app.service_role_key')
    ),
    body := '{}'::jsonb
  )$$
);
