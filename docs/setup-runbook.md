# Go-live runbook

Everything in the app is wired and working against a fake identification service.
These are the steps that flip Carddex from "sample" to identifying real cards. The
app already chooses the live path automatically once `Secrets.plist` exists.

## 1. Apple Developer account (for device testing + TestFlight)
- Enroll at https://developer.apple.com ($99/yr).
- In Xcode → Signing & Capabilities, set your team. Needed for on-device camera testing
  and TestFlight; the simulator works without it.

## 2. Supabase project (database + identify function)
```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref <your-ref>
supabase db push                      # applies migrations 0001–0006
supabase functions deploy identify
```
- Enable Sign in with Apple under Authentication → Providers.
- Create a private Storage bucket `user-photos`.

## 3. Vision model key (powers card recognition)
The `identify` function now calls a Claude vision model to read the card, then grounds the
result against the catalog. Set the key (and optionally override the model):
```bash
supabase secrets set ANTHROPIC_API_KEY=<key> POKEMON_TCG_API_KEY=<key>
# optional: supabase secrets set VISION_MODEL=claude-haiku-4-5-20251001
```
The OCR-first fast path resolves clean scans for free; the vision call only fires on ambiguous
ones. The app sends a card photo via Scan → "Choose from photos" (or the live camera on device).

## 4. Point the app at your project
```bash
cp Secrets.example.plist Carddex/Resources/Secrets.plist
# edit Secrets.plist → SUPABASE_PROJECT_REF + SUPABASE_ANON_KEY (Settings → API in Supabase)
xcodegen generate
```
Build and run. `Settings → About → Identification` will read **Live** instead of **Sample**,
and scans now call your `identify` function. `Secrets.plist` is gitignored — never commit it.

## How the swap works
`AppConfig` loads `Secrets.plist`; if present, `AppEnvironment` uses
`LiveIdentificationService` (pointed at `https://<ref>.functions.supabase.co/identify`),
otherwise `FakeIdentificationService`. No code change needed to go live.

## Selling (eBay)
- `functions/ebay-oauth` + `functions/ebay-list` are scaffolded (connect account, publish a
  listing). They need `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` / `EBAY_REDIRECT_URI` and the
  token-exchange + Sell-API calls (marked `TODO`). Start eBay production-access review early.
- The app's Sell sheet (card detail → "List on eBay") composes the listing; "See recent sold
  prices" already works as an affiliate link — set your eBay Partner Network campaign id in
  `Carddex/Services/Marketplace.swift` (`EPN_CAMPAIGN_ID`) to earn from day one.

## Still to build after go-live (see launch-plan.md)
- Sign in with Apple + Supabase sync (passes the user JWT to `identify`)
- `refresh-prices` cron + real portfolio history
- StoreKit 2 purchase wiring, privacy manifest, App Privacy label → TestFlight
