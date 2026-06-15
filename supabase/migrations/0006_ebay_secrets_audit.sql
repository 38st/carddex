-- eBay OAuth tokens (service-role only), listing extensions, audit log.

create table if not exists ebay_accounts (
    user_id               uuid primary key references auth.users(id) on delete cascade,
    ebay_user_id          text,
    refresh_token_enc     text not null,     -- encrypted at rest
    access_token_enc      text,
    access_expires_at     timestamptz,
    refresh_expires_at    timestamptz,
    merchant_location_key text,
    fulfillment_policy_id text,
    payment_policy_id     text,
    return_policy_id      text,
    scopes                text[],
    connected_at          timestamptz not null default now(),
    updated_at            timestamptz not null default now()
);
-- RLS enabled with NO policies → only the service role (Edge Functions) can touch it.
alter table ebay_accounts enable row level security;

alter table ebay_listings add column if not exists sku text;
alter table ebay_listings add column if not exists view_url text;
alter table ebay_listings add column if not exists last_error text;
alter table ebay_listings add column if not exists updated_at timestamptz not null default now();

create table if not exists audit_events (
    id         bigint generated always as identity primary key,
    user_id    uuid,
    kind       text not null,         -- 'account_deleted','ebay_connected','scan','listing_created',...
    detail     jsonb,
    created_at timestamptz not null default now()
);
create index if not exists audit_events_user_idx on audit_events(user_id, created_at desc);
alter table audit_events enable row level security;
create policy "own audit read" on audit_events for select using (auth.uid() = user_id);

-- Make the read-only intent on catalog/price tables explicit.
revoke insert, update, delete on cards, sets, price_snapshots, card_prices_latest from anon, authenticated;
