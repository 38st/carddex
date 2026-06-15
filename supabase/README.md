# Carddex backend (Supabase)

Database schema and Edge Functions for Carddex. The iOS app holds only the
Supabase URL + anon key — every third-party secret (vision model, catalog APIs,
eBay) lives in Edge Function secrets.

## Setup (Phase 1)

1. Create a project at https://supabase.com (free tier is fine).
2. Install the CLI: `brew install supabase/tap/supabase`, then `supabase link --project-ref <ref>`.
3. Apply the schema: `supabase db push` (runs `migrations/0001` … `0006` in order).
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

`0001` is immutable; everything else is additive.

## Edge Functions

- `functions/identify` — OCR-first ladder → catalog grounding → ranked candidates.
  Implemented as a scaffold: the free OCR/catalog path works; the paid vision-model
  step is marked `TODO` (wire `VISION_PROVIDER`). Contract in `docs/backend-plan.md` §3.1 / §9.

### Coming next
- `refresh-prices` (cron) — daily price snapshots for owned/alerted cards
- `account-delete` — App Store / GDPR erasure
- `ebay-oauth` + `ebay-list` — connect account, auto-list
- `catalog-sync` (cron) — ingest Pokémon TCG API / Scryfall bulk / YGOPRODeck
