-- Sync push fix: alert/grail upserts had no conflict target on their natural
-- key. `LiveSyncService` sent `Prefer: resolution=merge-duplicates`, which
-- infers the PRIMARY KEY (`id`). But the client keys alerts/grails by
-- `card_id` and sends `id: nil`, so every push minted a new row — a second
-- push for the same card (edit target, or a tombstone) then collided with the
-- `(user_id, card_id)` unique index and 409'd.
--
-- Fix part 1 (this migration): the existing unique indexes on the natural keys
-- were PARTIAL (`where deleted_at is null`). A partial index can't be used as
-- an `ON CONFLICT` arbiter unless the insert matches the partial predicate, so
-- a tombstone upsert (deleted_at set) wouldn't find the live row to merge —
-- it would insert a second row instead of toggling the existing one. Replace
-- them with FULL unique indexes so the single row per (user, card) is reused
-- for both live upserts and soft-delete toggles (a re-add after a delete
-- reuses the slot, matching the original migration's stated intent).
--
-- Fix part 2 (client): the upserts now send `on_conflict=user_id,card_id`
-- (alerts/grails) and `on_conflict=user_id` (subscription singleton) so
-- PostgREST merges on the natural key instead of inferring the PK.

drop index if exists price_alerts_user_card_idx;
create unique index price_alerts_user_card_idx
    on price_alerts(user_id, card_id);

drop index if exists wishlists_user_card_idx;
create unique index wishlists_user_card_idx
    on wishlists(user_id, card_id);
