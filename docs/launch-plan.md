# Carddex → App Store: unified launch plan

Synthesis of the four specialist plans (product, iOS, design, backend). Each domain plan
lives alongside this file in `docs/`.

## The bet
North Star: **weekly active collectors who scanned ≥1 card.** The one promise that earns a
5-star review: *"I pointed my camera at a real card, it instantly told me what it is and what
it's worth, and saved it to a beautiful collection."*

Positioning: the only app that nails the full physical-card loop — scan → identify → organize
as a living "dex" → value → sell. Wedge = scan-first intake + the "Pokédex" emotional hook
(set completion). Lead with Pokémon; Magic + Yu-Gi-Oh! ship as labeled beta; sports is v2.0.

## v1.0 scope — ship this, cut that

In v1.0:
- Live camera + real identification (Pokémon-first)
- Confirm sheet + manual-search fallback (protects the rating)
- Save to collection (qty/condition) + grid with filters
- Real market price + portfolio total
- Sign in with Apple + Supabase sync + account deletion
- Carddex Pro paywall (scan cap)
- Stretch: Pokémon set-completion

Cut to later:
- eBay auto-listing → v1.2 (keep the disabled button as "coming soon")
- Sports cards → v2.0
- Bulk/continuous scan → v1.1
- Price-movement push alerts → v1.1
- Social/sharing feed → v2.0
- Rich price-history charts → v1.1

The whole launch's engineering oxygen goes into identification accuracy.

## Design direction — "The Vault"
A glass display case in a dark, climate-controlled vault. Cards float on graphite under soft
museum lighting; chrome is quiet glass; the cards are the only thing that glows. The signature
interaction is holographic foil — gyroscope-driven sheen on rare cards, tier-gated by rarity.
Refined indigo `#6E6BFF` accent, per-game accents scoped to card context, SF Pro Rounded with
monospaced-digit number roll-ups, floating glass tab bar with a center Scan FAB. See
`design-spec.md`.

## Technical spine
- Architecture: keep the repo's MV pattern (`@Observable` + protocol-based service layer).
  Services are protocols with fakes, so the app builds before the backend exists.
- Identification: OCR-first cost ladder — on-device Apple Vision reads card text for free and
  resolves clean scans with no paid call; only ambiguous scans hit the cloud vision model;
  every result is grounded against the catalog so confidence = "we found a real, priceable
  card," and the user always gets a candidate picker + manual search. Keys live only in
  Supabase Edge Functions.
- Data: SwiftData offline-first, Supabase as source of truth (last-write-wins + tombstones).
  Catalogs ingested into our own Postgres (Scryfall bulk, Pokémon TCG API key, YGOPRODeck) so
  grounding is fuzzy SQL. Price only owned cards, daily. Nuke + decode-time downsampling.

## Roadmap

| Milestone | Ships | Effort (solo) |
|---|---|---|
| M0 — Foundations + design system | Vault theme, glass tab bar, holo component; agree `identify` contract | 1–1.5 wk |
| M1 — Core loop | Camera + auto-crop, on-device OCR, identify→confirm→save | 3–4 wk |
| M2 — Accounts + sync | Sign in with Apple, Supabase sync, account deletion | 2–3 wk |
| M3 — Pricing + portfolio | Real prices, portfolio value + daily change, set-completion | 2 wk |
| M4 — Pro + hardening | StoreKit 2 paywall, privacy manifest, App Store assets, TestFlight | 1.5–2 wk |
| v1.0 launch | | ≈10–13 weeks to TestFlight |
| v1.1 | Bulk scan, price alerts, history charts, share cards | post-launch |
| v1.2 | eBay connect + auto-list (start API approval in M3) | post-launch |

## Monetization
Carddex Pro — $6.99/mo or $39.99/yr (7-day trial on annual). Free = full magic moment + ~15
scans/mo + current price + 1 tracked set. Pro = unlimited scans, price history & analytics, all
set tracking, bulk scan, alerts, and (v1.2) eBay listing. Never gate collection size or basic
price.

## Top risks → de-risked
- Wrong card = 1-star → Pokémon-first, high confidence threshold, always-available manual
  fallback, a real-photo test set before launch.
- eBay API/policy friction → cut from launch; start production-access application in M3.
- Pricing ToS/rate limits → cache via daily server refresh, attribute sources, never imply a
  guaranteed sale price.
- App Review → Sign in with Apple + account deletion + privacy manifest are M4 line items.

## Start now (external lead-time)
1. Apple Developer Program ($99/yr) — gates TestFlight, push, Sign in with Apple, submission.
2. Create the Supabase project (dev/staging/prod) and run the schema migrations.
3. Pick + key the vision provider; get a Pokémon TCG API key.
4. Agree the `identify` request/response contract between iOS and backend (critical path).
