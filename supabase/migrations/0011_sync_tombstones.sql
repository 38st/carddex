-- Sync hardening: updated_at + soft-delete tombstones on the synced user
-- tables, plus the missing `wishlists` table. Enables the Phase 2 SyncEngine
-- to do last-write-wins reconciliation and delete propagation across devices.
--
-- Soft-delete pattern: rows are marked `deleted_at` rather than removed, so an
-- incremental pull (`updated_at > lastSync`) still returns tombstoned rows and
-- the client can learn about remote deletes. Live-UI queries filter
-- `where deleted_at is null`.
--
-- `subscriptions` is intentionally left without a tombstone: it's a 1:1
-- per-user singleton (pk = user_id, cascade-deleted with the auth user); a
-- cancelled subscription is represented as tier/status, not a deleted row.

-- collection_items: already has updated_at + touch trigger (0003). Add tombstone
-- + an incremental-pull index on (user_id, updated_at).
alter table collection_items add column if not exists deleted_at timestamptz;
create index if not exists collection_items_user_updated_idx
    on collection_items(user_id, updated_at);

-- price_alerts: add updated_at + tombstone + a per-(user, card) unique index
-- so upserts can merge on conflict (the client keys alerts by card_id). The
-- partial index excludes soft-deleted rows so a re-add after a delete reuses
-- the slot rather than colliding with the tombstone.
alter table price_alerts add column if not exists updated_at timestamptz not null default now();
alter table price_alerts add column if not exists deleted_at timestamptz;
create unique index if not exists price_alerts_user_card_idx
    on price_alerts(user_id, card_id) where deleted_at is null;
create index if not exists price_alerts_user_updated_idx
    on price_alerts(user_id, updated_at);

-- wishlists (the "grail list"): was referenced by the iOS sync client but
-- never created — syncs to it would 404 against a real backend. One grail per
-- (user, card); re-adding replaces the existing entry.
create table if not exists wishlists (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    card_id     text not null references cards(id),
    target      numeric,
    note        text,
    date_added  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    deleted_at  timestamptz
);
create unique index if not exists wishlists_user_card_idx
    on wishlists(user_id, card_id) where deleted_at is null;
create index if not exists wishlists_user_updated_idx
    on wishlists(user_id, updated_at);
alter table wishlists enable row level security;
create policy "own wishlists" on wishlists
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
grant select, insert, update, delete on wishlists to authenticated, service_role;

-- Keep updated_at fresh on the tables that don't yet have a touch trigger.
-- (collection_items already has collection_items_touch from 0003; redefine the
-- shared function idempotently so both triggers share it.)
create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin
    new.updated_at := now();
    return new;
end $$;
drop trigger if exists price_alerts_touch on price_alerts;
create trigger price_alerts_touch before update on price_alerts
    for each row execute function touch_updated_at();
drop trigger if exists wishlists_touch on wishlists;
create trigger wishlists_touch before update on wishlists
    for each row execute function touch_updated_at();
