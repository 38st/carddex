# Carddex backend (Supabase)

Database schema and Edge Functions for Carddex. The iOS app holds only the
Supabase URL + anon key — every third-party secret (vision model, catalog APIs,
eBay) lives in Edge Function secrets.

## Setup (Phase 1)

1. Create a project at https://supabase.com (free tier is fine).
2. Install the CLI: `brew install supabase/tap/supabase`, then `supabase link --project-ref <ref>`.
3. Apply the schema: `supabase db push` (runs `migrations/0001` … `0008` in order).
4. Enable Sign in with Apple under Authentication → Providers.
5. Create a private Storage bucket `user-photos` (see backend-plan.md §1.5 for the RLS policies).
6. Set function secrets and deploy:
   ```bash
   supabase secrets set VISION_PROVIDER=... VISION_API_KEY=... POKEMON_TCG_API_KEY=...
   supabase functions deploy identify
   ```
7. Point the app at the project: put the URL + anon key in a gitignored `Secrets.xcconfig`,
   then swap `AppEnvironment` from `FakeIdentificationService` to
   `LiveIdentificationService(endpoint:)`.

## Migrations

| File | Adds |
|---|---|
| `0001_init.sql` | profiles, cards, collection_items, price_snapshots, ebay_listings + RLS |
| `0002_catalog_expansion.sql` | sets, richer cards, trigram + tsvector search |
| `0003_collection_hardening.sql` | sync `updated_at`, foil/grade, condition CHECK, dedupe index |
| `0004_prices.sql` | per-condition snapshots + `card_prices_latest` cache |
| `0005_subscriptions_scans_alerts.sql` | subscriptions, scans + quotas, alerts, device tokens, signup trigger |
| `0006_ebay_secrets_audit.sql` | encrypted `ebay_accounts`, listing fields, audit log |
| `0007_scan_cache.sql` | `scan_cache` for the identify result cache |
| `0008_market_data.sql` | `card_sales`, `card_grade_values`, `market_index_points` + `refresh_grade_change()` |

`0001` is immutable; everything else is additive.

## Edge Functions

- `functions/identify` — OCR-first ladder → catalog grounding → ranked candidates.
  Implemented as a scaffold: the free OCR/catalog path works; the paid vision-model
  step is marked `TODO` (wire `VISION_PROVIDER`). Contract in `docs/backend-plan.md` §3.1 / §9.
- `functions/market-data` — serves a card's market bundle (graded prices, recent
  sales, population, 30d change) and index series from the `0008` tables. Public
  read; maps 1:1 onto the app's `CardMarket` / `MarketIndex`. Deploy with
  `supabase functions deploy market-data`.

## Sports market data (the real-data pipeline)

The Market tab currently reads bundled `SampleData`. To go live, three things are
needed — only the first is code:

1. **Schema + serving (done):** `0008_market_data.sql` + `functions/market-data`.
2. **A sales source (requires your accounts/licensing):** ingest completed sales
   into `card_sales`. Options, roughly in order of effort/cost:
   - eBay **Marketplace Insights API** (completed-sales; requires an approved eBay
     developer account — access is gated).
   - A licensed feed (Card Ladder / Market Movers / PriceCharting) per their terms.
   - Manual/CSV seeding for a starter set of cards.
   After inserting sales, upsert `card_grade_values` (price + population) and call
   `refresh_grade_change(card_id, grade)`; recompute `market_index_points` daily
   (a `market-rollup` cron — not yet written).
3. **Flip the client seam:** point the app's market reads at `functions/market-data`
   with a `SampleData` fallback. Best done once (2) is populated so it's testable
   end-to-end; until then the app stays on sample data and nothing breaks.

> Honest wall: I can't deploy your project or obtain a licensed sales feed. Steps
> (2) and the credentials/secrets are yours to provide; the schema, serving
> function, and ingestion hooks above are ready for them.

### Coming next
- `market-rollup` (cron) — recompute `card_grade_values` + `market_index_points` from new sales
- `refresh-prices` (cron) — daily price snapshots for owned/alerted cards
- `account-delete` — App Store / GDPR erasure
- `ebay-oauth` + `ebay-list` — connect account, auto-list
- `catalog-sync` (cron) — ingest Pokémon TCG API / Scryfall bulk / YGOPRODeck
