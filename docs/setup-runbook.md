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

## 3. Vision provider key (fills the one TODO in identify)
```bash
supabase secrets set VISION_PROVIDER=<name> VISION_API_KEY=<key> POKEMON_TCG_API_KEY=<key>
```
Then implement the vision step in `supabase/functions/identify/index.ts` (the OCR-first
catalog grounding already works; the paid vision call is marked `TODO`).

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

## Still to build after go-live (see launch-plan.md)
- Sign in with Apple + Supabase sync (passes the user JWT to `identify`)
- `refresh-prices` cron + real portfolio history
- eBay connect + auto-list (start the production-access application early)
- StoreKit 2 paywall, privacy manifest, App Privacy label → TestFlight
