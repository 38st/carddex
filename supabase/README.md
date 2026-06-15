# Carddex backend (Supabase)

This folder holds the database schema and (later) Edge Functions for Carddex.

## Setup (when you're ready to wire up accounts/sync — Phase 1)

1. Create a project at https://supabase.com (free tier is fine).
2. In the dashboard, open **SQL Editor** and run `migrations/0001_init.sql`.
3. Enable **Sign in with Apple** under Authentication → Providers.
4. Copy your project URL and anon key into the app's config (a `Secrets.xcconfig`,
   which is gitignored — never commit keys).

## What's here

- `migrations/0001_init.sql` — tables for profiles, the card catalog, collection
  items, price snapshots, and eBay listings, with row-level security.

## What's coming

- Edge Functions that hold all secrets and run server-side work:
  - `identify` — vision model + catalog grounding (Pokémon TCG API / Scryfall / YGOPRODeck)
  - `refresh-prices` — scheduled price snapshots
  - `ebay-oauth` / `ebay-list` — eBay account connect + listing creation
