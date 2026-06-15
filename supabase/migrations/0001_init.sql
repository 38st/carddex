-- Carddex initial schema
-- Run against a Supabase project (SQL editor or `supabase db push`).

create extension if not exists "uuid-ossp";

-- User profiles, linked to Supabase auth.
create table if not exists profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text,
    created_at timestamptz not null default now()
);

-- Card games we support.
do $$ begin
    create type card_game as enum ('pokemon', 'magic', 'yugioh', 'sports');
exception
    when duplicate_object then null;
end $$;

-- Canonical card catalog (shared, public read). `id` is the source catalog id.
create table if not exists cards (
    id text primary key,
    game card_game not null,
    name text not null,
    set_name text,
    number text,
    rarity text,
    image_url text,
    updated_at timestamptz not null default now()
);

-- A user's owned cards.
create table if not exists collection_items (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    card_id text not null references cards(id),
    quantity int not null default 1 check (quantity > 0),
    condition text not null default 'Near Mint',
    purchase_price numeric,
    currency text not null default 'USD',
    date_added timestamptz not null default now()
);
create index if not exists collection_items_user_idx on collection_items(user_id);

-- Historical price points per card, from various sources.
create table if not exists price_snapshots (
    id bigint generated always as identity primary key,
    card_id text not null references cards(id),
    source text not null,                 -- 'tcgplayer' | 'ebay' | 'pricecharting'
    market_price numeric,
    currency text not null default 'USD',
    captured_at timestamptz not null default now()
);
create index if not exists price_snapshots_card_idx on price_snapshots(card_id, captured_at desc);

-- eBay listings created from collection items.
create table if not exists ebay_listings (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    collection_item_id uuid references collection_items(id) on delete set null,
    ebay_offer_id text,
    ebay_listing_id text,
    status text not null default 'draft', -- 'draft' | 'active' | 'sold' | 'ended'
    price numeric,
    currency text not null default 'USD',
    created_at timestamptz not null default now()
);

-- Row-level security: users see only their own rows; catalog + prices are public read.
alter table profiles enable row level security;
alter table collection_items enable row level security;
alter table ebay_listings enable row level security;
alter table cards enable row level security;
alter table price_snapshots enable row level security;

create policy "own profile" on profiles
    for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own collection" on collection_items
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own listings" on ebay_listings
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "cards are public read" on cards
    for select using (true);
create policy "prices are public read" on price_snapshots
    for select using (true);
