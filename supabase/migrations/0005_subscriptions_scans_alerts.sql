-- Subscriptions/entitlements, scan history + quotas, price alerts, push tokens.

create table if not exists subscriptions (
    user_id         uuid primary key references auth.users(id) on delete cascade,
    tier            text not null default 'free',    -- 'free'|'pro'
    status          text not null default 'active',   -- 'active'|'expired'|'grace'|'revoked'
    store           text,
    original_txn_id text,
    expires_at      timestamptz,
    updated_at      timestamptz not null default now()
);
alter table subscriptions enable row level security;
create policy "own subscription read" on subscriptions for select using (auth.uid() = user_id);

create table if not exists scans (
    id              uuid primary key default uuid_generate_v4(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    storage_path    text,
    game_hint       card_game,
    ocr_text        text,
    used_vision     boolean not null default false,
    vision_provider text,
    result          jsonb,
    chosen_card_id  text references cards(id),
    confidence      numeric,
    latency_ms      int,
    cost_usd        numeric,
    created_at      timestamptz not null default now()
);
create index if not exists scans_user_time_idx on scans(user_id, created_at desc);
alter table scans enable row level security;
create policy "own scans" on scans for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists scan_usage (
    user_id      uuid not null references auth.users(id) on delete cascade,
    period_start date not null,            -- first of month (UTC)
    scan_count   int not null default 0,
    vision_count int not null default 0,
    primary key (user_id, period_start)
);
alter table scan_usage enable row level security;
create policy "own usage read" on scan_usage for select using (auth.uid() = user_id);

create table if not exists price_alerts (
    id            uuid primary key default uuid_generate_v4(),
    user_id       uuid not null references auth.users(id) on delete cascade,
    card_id       text not null references cards(id),
    direction     text not null default 'up',     -- 'up'|'down'|'either'
    threshold_pct numeric,
    target_price  numeric,
    active        boolean not null default true,
    last_triggered_at timestamptz,
    created_at    timestamptz not null default now()
);
create index if not exists price_alerts_card_idx on price_alerts(card_id) where active;
alter table price_alerts enable row level security;
create policy "own alerts" on price_alerts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists device_tokens (
    user_id    uuid not null references auth.users(id) on delete cascade,
    token      text not null,
    platform   text not null default 'ios',
    updated_at timestamptz not null default now(),
    primary key (user_id, token)
);
alter table device_tokens enable row level security;
create policy "own devices" on device_tokens for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Create profile + free subscription on signup.
create or replace function handle_new_user() returns trigger
    language plpgsql security definer set search_path = public as $$
begin
    insert into public.profiles (id, display_name)
    values (new.id, coalesce(new.raw_user_meta_data->>'full_name', null))
    on conflict (id) do nothing;
    insert into public.subscriptions (user_id, tier, status)
    values (new.id, 'free', 'active')
    on conflict (user_id) do nothing;
    return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users for each row execute function handle_new_user();
