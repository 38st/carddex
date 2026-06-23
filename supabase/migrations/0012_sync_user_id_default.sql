-- Sync push fix: the iOS client never sends `user_id` (it relies on RLS to
-- scope rows), but every synced user table declares `user_id ... not null`
-- with no default. So a PostgREST insert from the SyncEngine failed: NOT NULL
-- violation on insert, and even if it didn't, RLS `with check (auth.uid() =
-- user_id)` would reject it. The standard Supabase fix is to default
-- `user_id` to `auth.uid()` so the JWT fills it server-side at insert time.
--
-- This makes the SyncEngine's push path writable for collection_items,
-- price_alerts, wishlists, and subscriptions without the client having to
-- (or being able to) spoof another user's id.

alter table collection_items alter column user_id set default auth.uid();
alter table price_alerts     alter column user_id set default auth.uid();
alter table wishlists        alter column user_id set default auth.uid();
alter table subscriptions    alter column user_id set default auth.uid();
