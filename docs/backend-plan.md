# Carddex — Backend & Infrastructure Plan

*Author: Backend Engineer. Targets App Store v1 (Phases 1–3). Field names chosen so JSON maps to the
client structs (`Card`, `CollectionItem`, `Money`, `CardGame`, `CardCondition`).*

Compatibility constraints from the client:
- `Card.id` is a String (catalog-native id) → keep `cards.id text`.
- `Card.setName`/`number` are non-optional → API always sends a string.
- `Money` JSON = `{ "amount": "320.00", "currencyCode": "USD" }` (amount as string → exact `Decimal`).
- `CardCondition` raw values are display strings → DB stores them, add a CHECK.

## 1. Schema review & refinements
`0001_init.sql` is a sensible core (profiles, cards, collection_items, price_snapshots,
ebay_listings) with RLS on every table. Gaps to fix (additive migrations `0002`–`0006`):

- `0002_catalog_expansion`: a `sets` table (for completion tracking); enrich `cards` with `set_id`,
  `variant`, `number_normalized`, `name_normalized`, `external_ids jsonb`, `search_tsv tsvector`;
  trigram + GIN indexes for fuzzy grounding; a tsv-maintenance trigger.
- `0003_collection_hardening`: add `updated_at` (for sync LWW), `is_foil`, `grade`, `notes`,
  `source_scan_id`; CHECK-constrain `condition` to the 6 values; a unique dedupe index on
  `(user_id, card_id, condition, is_foil, coalesce(grade,''))` so upsert stacks quantities.
- `0004_prices`: per-condition + low/high on `price_snapshots`; a `card_prices_latest` cache table
  (one row per `(card, source)`) maintained by an after-insert trigger (last-writer-wins).
- `0005_subscriptions_scans_alerts`: `subscriptions` (entitlements, webhook-fed), `scans` (history +
  quota + cost observability), `scan_usage` (monthly counters), `price_alerts`, `device_tokens` (APNs).
- `0006_ebay_secrets_audit`: `ebay_accounts` (encrypted tokens, service-role only — no RLS policies);
  extend `ebay_listings` (sku, view_url, last_error, updated_at); `audit_events`.

RLS: keep the `auth.uid() = user_id` policies; Edge Functions use the service-role key (bypasses RLS)
for all privileged writes. `cards/sets/price_snapshots/card_prices_latest` are public read-only;
`revoke insert,update,delete ... from anon, authenticated` to make read-only explicit.

Storage: `user-photos` (private, RLS by `(storage.foldername(name))[1] = auth.uid()`), 30-day TTL for
raw scan photos; optional `catalog-images` (public CDN cache).

## 2. Auth — Sign in with Apple
Supabase Apple provider; iOS native `ASAuthorizationAppleIDProvider` → `signInWithIdToken`. A
`handle_new_user()` trigger creates `profiles` + a free `subscriptions` row on signup. Account
deletion (App Store 5.1.1(v)): an `account-delete` Edge Function revokes eBay + Apple tokens, deletes
`user-photos/{uid}/*`, deletes `auth.users` (cascades), writes an audit row.

## 3. Edge Functions (Deno/TS)
Standard error envelope `{ "error": { "code", "message", "retryable" } }`; HTTP 200/400/401/402/429/502/500.

- `identify` — turn a photo (+ on-device OCR hints) into ranked canonical candidates, minimizing paid
  vision calls. Input `{ scanId, storagePath, gameHint?, ocr: { lines, topToken, numberGuess } }`.
  Logic ladder: (1) OCR-only fast path — structured catalog query; single high-confidence match
  (≥0.92) returns with no model call (~$0). (2) Vision path — only when OCR is ambiguous: fetch photo,
  call the vision model with OCR as a hint → `{game,name,set,number,variant,confidence}`. (3) Ground
  against the catalog (fuzzy) → top-N. (4) Cache lookups. (5) Quota check vs entitlement (`scan_usage`).
  Output: `{ scanId, usedVision, candidates:[{ card, confidence, matchReasons }], lowConfidence }`
  (up to 5, `card` decodes straight into `Card`).
- `refresh-prices` (cron, daily 06:00 UTC) — price only cards in ≥1 collection or with an active alert.
  Pokémon TCG API / Scryfall / YGOPRODeck bundle prices; eBay sold comps only for >$50 cards. Dedupe:
  insert a snapshot only if the price changed vs `card_prices_latest`.
- `ebay-oauth` (start + callback) — consent URL with signed `state`; exchange code → encrypted tokens
  in `ebay_accounts`; cache business-policy + merchant-location ids.
- `ebay-list` — Inventory item → Offer → publish (Sell API); persist to `ebay_listings`. Production
  access needs eBay review (1–2 wk) — start early.
- `alerts` (cron, optional v1.1) — detect threshold crossings → APNs push; debounce 24h.

## 4. Catalog data strategy
Ingest core catalog into our Postgres, refresh on a schedule; never proxy-per-request for grounding
(grounding needs fuzzy SQL; avoids latency + rate-limit exposure). Pokémon TCG API (free key, raises
limits), Scryfall (no key; use bulk data dumps), YGOPRODeck (no key; bulk pull). A `catalog-sync` cron
upserts `sets` + `cards` (computing normalized fields). Sports deferred. Completion% = owned distinct
cards in set / `sets.total_cards`.

## 5. Identification service detail
Provider: a hosted multimodal vision LLM with strong OCR + JSON structured output, server-side, swappable
via `VISION_PROVIDER`. Feed it the on-device OCR text so it structures + disambiguates rather than doing
raw OCR. Grounding (not the model) guarantees a canonical, priceable result. Output schema:
`{ game, name, setName, setCode, number, variantCues[], language, confidence }`. Matching: normalize →
candidate query (trigram name + number_normalized + game [+ set]) → score (name 0.45, number 0.30, set
0.15, variant 0.10) → auto-pick at ≥0.92 with ≥0.1 margin, else return top-5 with `lowConfidence`.
Returned confidence = grounding score.

## 6. Pricing & valuation
Store every source's raw price; define `market_price` via priority tcgplayer → scryfall → cardmarket →
ebay. Native currency per snapshot, FX-convert at read. `price_snapshots` = history. Portfolio value =
Σ quantity × market_price per game + total; daily change = today − yesterday. No-price cards = `null`
→ contribute 0 (matches client `?? 0`), show "Price unavailable", never block save.

## 7. Secrets, security, cost
All keys in Supabase Edge Function secrets; app holds only Supabase URL + anon key. eBay tokens encrypted
at rest (pgsodium/vault). Per-user scan quotas in `identify` via `scan_usage` (free vs pro) → `402
QUOTA_EXCEEDED` drives the paywall; global token bucket vs scripted abuse. Rough cost (vision is the main
driver, ~40% of scans after OCR fast-path, ~$0.002–0.01/call): low tens → hundreds → low thousands of
$/mo at 1k → 10k → 100k users. Levers: OCR-first, cache lookups, bulk-sync catalogs, price only owned/
alerted cards, 30-day photo TTL, dedupe snapshots, tie vision usage to the paid tier.

## 8. Observability, backups, environments
Three Supabase projects (dev/staging/prod); eBay + vision in sandbox/cheap mode for non-prod. Migrations
via Supabase CLI (`supabase db push`) in CI; `0001` immutable, everything additive. Structured Edge
Function logs (request id, uid, latency, cost) + optional Sentry; `scans` doubles as cost/accuracy
analytics; alert on vision-spend/day. Supabase daily backups + PITR; test restore quarterly.

## 9. API contract (app ↔ backend)
Plain CRUD on `collection_items`/`profiles`/`price_alerts` goes through PostgREST (supabase-swift) under
RLS. Custom Edge Functions for privileged/orchestrated work:

| Function | Method | Body → Returns |
|---|---|---|
| identify | POST | (§3 input) → `{ scanId, usedVision, candidates[], lowConfidence }` |
| portfolio | GET | → `{ total, dailyChange:{amount,currencyCode,pct}, byGame:[{game,value}], totalCards, uniqueCards }` |
| account-delete | POST | `{}` → `{ ok: true }` |
| ebay-oauth/start | GET | → `{ consentUrl }` |
| ebay-oauth/callback | GET | → 302 back to app deep link |
| ebay-list | POST | `{ collectionItemId, price, condition, quantity, title?, description? }` → `{ listingId, viewUrl, status }` |
| register-device | POST | `{ token }` → `{ ok }` |

Money JSON = `{amount: string, currencyCode}`. A DB view `collection_items_with_card` embeds the card so
`CollectionItem` decodes in one round-trip. Mirror the client's quantity-stacking with the dedupe-index
upsert.

## 10. Compliance
Scan photos private + 30-day TTL; choose a vision provider with no-training/zero-retention and disclose
it. eBay ToS (official APIs, OAuth consent, honor revocation). Attribute price sources ("Prices via
TCGplayer/Cardmarket", "Data via Scryfall"); use Scryfall bulk data, don't hotlink at scale. App Store
nutrition label: Photos, Identifiers, Purchases, Apple-relay email — functionality only, no tracking.
GDPR: `account-delete` = erasure; add a `GET /export` for data access.

## Top 5 backend decisions
1. Ingest catalogs into our Postgres and ground there (not per-request proxy).
2. OCR-first identify ladder — the biggest cost lever; makes scan quotas/monetization coherent.
3. Confidence = grounding score; return ranked candidates (auto-pick ≥0.92, else picker).
4. `card_prices_latest` cache + deduped snapshots; price only owned/alerted cards daily.
5. eBay tokens in a service-role-only encrypted table; all secrets in Edge Functions; deletion cascade.

## Dependencies
- iOS: on-device OCR hints to `identify`; upload photo before calling; decode the exact JSON shapes;
  Sign in with Apple; candidate-picker UI; "Delete account" + "Connect eBay"; eBay deep-link callback;
  APNs token registration.
- Product: free-tier scan quota numbers + paywall trigger; low-confidence picker UX; eBay listing fields.
- Design: `sets.total_cards` + symbols for completion visuals; `price_snapshots` series for charts;
  source-attribution placement.
- Team/timeline: start eBay production-access in Phase 2; set up dev/staging/prod + Apple entitlements early.
