# Carddex — Development Handoff Guide

*Current state after: bug fixes, Sets/Grails feature, UI uplifts, auth + sync layer.
Read this to understand what's built, the patterns to follow, and what's next.*

## 1. Current state at a glance

| Area | Status | Key files |
|---|---|---|
| **Bug fixes** | Done | `Persistence.swift`, `WidgetShared.swift`, `MarketService.swift`, `AppConfig.swift`, `ScanView.swift`, `BulkScanView.swift`, `Marketplace.swift`, `CaseIntents.swift`, `MiniAreaChart.swift` |
| **Sets browser + Grail List** | Done | `Store/WishlistStore.swift`, `Features/Collection/SetDetailView.swift`, `Features/Grails/GrailsView.swift`, `DesignSystem/Components/BinderPageView.swift` |
| **UI uplifts** | Done | `DesignSystem/Components/RollingNumber.swift`, `FlipCardView.swift`, `ScanOverlay.swift` |
| **Auth (Sign in with Apple)** | Done (client-side) | `Services/KeychainStore.swift`, `AuthService.swift`, `Store/AuthSessionStore.swift`, `App/AppEnvironment.swift` |
| **Sync (PostgREST CRUD)** | Done — bidirectional via `SyncEngine` (push dirty + incremental pull + LWW apply); new-device restore wired | `Services/SyncEngine.swift`, `Services/SyncService.swift`, `App/CarddexApp.swift`, `Store/CollectionStore.swift`, `WatchlistStore.swift`, `WishlistStore.swift`, `SubscriptionStore.swift` |
| **StoreKit 2** | Done — real `Product.purchase()` + verified entitlement; needs App Store Connect products to go live (§4) | `Services/StoreKitService.swift`, `Store/SubscriptionStore.swift`, `Features/Paywall/PaywallView.swift` |
| **Condition tracking** | Done — editable picker + condition-adjusted value | `Features/Collection/CardDetailView.swift`, `Models/CardCondition.swift`, `Models/CollectionItem.swift` |
| **Account deletion** | Done — confirm → `account-delete` Edge Function → local wipe + sign-out | `Features/Settings/SettingsView.swift`, `Services/AuthService.swift`, `supabase/functions/account-delete/` |
| **Weekly Recap / Light mode** | Done — `WeeklyRecapView` on Portfolio; system-following light mode via dynamic `Theme` tokens | `Features/Portfolio/WeeklyRecapView.swift`, `DesignSystem/Theme.swift` |
| **Tests** | 104 passing, 15 suites | `CarddexTests/` |
| **Build** | 0 warnings, 0 errors | `bash scripts/dev.sh build` |

## 2. Architecture patterns (follow these)

### Observable stores + environment injection
All state is `@Observable final class`, created as `@State` in `CarddexApp`, injected via `.environment(_:)`. Views read with `@Environment(Store.self)`. No Combine, no `@StateObject`/`@Published`.

```
CarddexApp (@State stores) → .environment(store) → View (@Environment(Store.self))
```

### Protocol seams for testability
Every service has a protocol + live + fake/no-op:
- `IdentificationService` → `LiveIdentificationService` / `FakeIdentificationService`
- `AuthServiceProtocol` → `SupabaseAuthService` / `FakeAuthService` / `NoOpAuthService`
- `SyncServiceProtocol` → `LiveSyncService` / `NoOpSyncService` / `FakeSyncService`
- `MarketServiceProtocol` → `MarketService` / `FakeMarketService`

**When adding a new service**: create the protocol first, then a fake, then the live impl. Inject via `AppEnvironment` (the composition root). Tests use the fake.

### Persistence
`Disk` (Codable→JSON in the App Group container) with `os.Logger` diagnostics. Stores take an optional `persistKey` (nil = in-memory for previews/tests). Sync is fire-and-forget `Task { try? await sync.upsert(...) }` after every mutation.

### No SPM dependencies
The entire app uses raw `URLSession` for all network calls (Supabase Auth, PostgREST, Edge Functions). This is intentional — keeps the project SPM-free and build times fast. **Do not add supabase-swift or other SPM deps** unless the team explicitly decides otherwise.

### Swift 6 strict concurrency
- `@Observable` stores that are captured in `@Sendable` closures are `@MainActor` (see `AuthSessionStore`, `AppEnvironment`).
- Token access from `@Sendable` closures uses `await MainActor.run { ... }`.
- `nonisolated(unsafe)` is used sparingly for immutable `let` dicts that Swift 6 can't prove Sendable (see `AppConfig.secrets`).

### Design system
- `Theme` enum holds all tokens (colors, spacing, radii, springs). Dark-first.
- Components in `DesignSystem/Components/`. Every new component follows the existing glass-panel + hairline pattern.
- `Haptics` for all tactile feedback. Gate animations on `@Environment(\.accessibilityReduceMotion)`.
- Big numbers use `RollingNumber` (count-up with spring). Charts use Swift Charts with hidden axes + drag-to-scrub.

## 3. Feature status (all shipped)

> These were the v1.0/v1.1 gaps; all are now implemented. Each note points at the
> shipped code. The only blockers left are external credentials, not code — see §4.

### 3.1 Cross-device sync — DONE (via `SyncEngine`, not legacy `pullAll()`)

**Status**: Bidirectional sync is implemented and wired. This section originally
described wiring the legacy `pullAll()` → `store.mergeRemote(...)` path, but the
app moved to a more capable `SyncEngine` and that plan is now stale.

**What's actually built**:
- `Services/SyncEngine.swift` owns the cycle: push dirty entities → incremental
  pull (`pullChanges(since: lastSyncAt)`) → **last-writer-wins** apply into
  SwiftData (inserts new remote rows, updates by `updated_at`, applies
  tombstones) → stores refresh from SwiftData.
- `App/CarddexApp.runSync()` runs the engine then refreshes the in-memory stores.
  It fires on launch `.task` (if signed in), on `scenePhase == .active`, and on
  the `isSignedIn` transition.
- **New-device / reinstall restore**: on sign-in, `CarddexApp.onChange(of:isSignedIn)`
  awaits `syncEngine.resetWatermark()` (drops `lastSyncAt`) *before* `runSync()`,
  forcing a full pull that reconstructs the account. On a fresh install
  `lastSyncAt` is already nil, so the launch path does the full pull too.

**Tests**: `SyncEngineTests` covers push/pull/LWW/tombstones, full-vs-incremental
watermark behavior, and `resetThenSyncRestoresCollectionOnNewDevice` (the
new-device restore). `PullMergeTests` still covers the legacy store-merge
primitives.

**Legacy dead code — removed**: the old `pullAll()` / `RemoteState` /
`store.mergeRemote(...)` / `SubscriptionStore.applyRemote(...)` path (plus the
legacy view-struct `upsert*`/`delete*` `SyncServiceProtocol` methods and their
`PullMergeTests`) has been deleted. The DTO-based `SyncEngine` path is the only
sync mechanism now.

### 3.2 StoreKit 2 purchases — DONE

**Status**: Real StoreKit 2 purchases are wired; the paywall is no longer a stub.
- `Services/StoreKitService.swift` — `StoreKitService` implements `fetchProducts()`
  (`Product.products(for:)`), `purchase()` (`product.purchase()` → verify →
  `finish()`), and `verifyEntitlement()` (iterates `Transaction.currentEntitlements`).
  `NoOpStoreKitService` is the fake used without `Secrets.plist`.
- `App/AppEnvironment.swift` exposes `storeKit: any StoreKitServiceProtocol`.
- `Features/Paywall/PaywallView.swift` runs `env.storeKit.purchase(_:)` and only
  flips `SubscriptionStore.activatePro()` on a **verified** transaction.
- `App/CarddexApp.swift` `verifyEntitlement()` runs on launch to restore Pro after
  reinstall / on another device.

**Still external (not code)**: App Store Connect must define the two auto-renewable
products (`com.carddex.pro.monthly` / `.annual`) + a subscription group before
purchases resolve in sandbox/production — see §4.

### 3.3 Account deletion — DONE

**Status**: In-app account deletion is wired (satisfies App Store 5.1.1(v)).
- `Features/Settings/SettingsView.swift` — the Delete button shows a confirm
  alert, then `deleteAccount()` → `auth.deleteAccount()`.
- `Services/AuthService.swift` — `deleteAccount(accessToken:)` POSTs to the
  `account-delete` Edge Function with the user's JWT.
- `supabase/functions/account-delete/index.ts` — deletes the user with the
  service-role key (cascades the RLS tables); the client then wipes local stores
  and signs out.

### 3.4 Condition editor + condition-adjusted value — DONE

**Status**: Condition is editable and feeds a condition-adjusted value.
- `Models/CardCondition.swift` — `multiplier` (mint 1.0 → damaged 0.3).
- `Models/CollectionItem.swift` — `conditionAdjustedValue` (= estimatedValue ×
  multiplier).
- `Store/CollectionStore.swift` — `setCondition(_:for:)` persists + marks the row
  dirty so the SyncEngine pushes it.
- `Features/Collection/CardDetailView.swift` — a menu `Picker` writes via the
  store; a live "Condition value" row updates as the condition changes.

### 3.5 Weekly Recap card — DONE

**Status**: `Features/Portfolio/WeeklyRecapView.swift` ships at the top of
`PortfolioView` — net 7-day value change, a "new this week" count, and the top
mover, derived from `CollectionStore` + `PortfolioHistoryStore`, with a "building
your first week" empty state until ≥2 days of value history accrue.

### 3.6 Light mode ("daylight case") — DONE

**Status**: System-following light mode ships. `DesignSystem/Theme.swift` tokens
are dynamic `UIColor`s (warm espresso in dark, warm paper in light);
`VaultBackground` is scheme-adaptive; and every screen's forced
`.preferredColorScheme` now routes through the single `Theme.appColorScheme`
(`nil` = follow system, ready for a future manual toggle).

## 4. Backend setup checklist (for going live)

These are the steps that require human accounts/credentials — the code is ready:

1. **Apple Developer account** ($99/yr) — for device testing, TestFlight, Sign in with Apple.
2. **Supabase project** — `supabase link --project-ref <ref>`, `supabase db push` (runs migrations 0001–0010).
3. **Enable Sign in with Apple** — Supabase Dashboard → Authentication → Providers → Apple. Follow Apple's setup (Services ID, key, redirect URL).
4. **Vision model key** — `supabase secrets set ANTHROPIC_API_KEY=<key>`, deploy `identify`.
5. **Secrets.plist** — `cp Secrets.example.plist Carddex/Resources/Secrets.plist`, fill in `SUPABASE_PROJECT_REF` + `SUPABASE_ANON_KEY` + `EBAY_AFFILIATE_CAMPAIGN_ID`.
6. **StoreKit** — App Store Connect → create subscription products → set IDs in `StoreKitService`.
7. **eBay (Phase 3)** — `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` / `EBAY_REDIRECT_URI` + the `ebay-oauth` / `ebay-list` functions.
8. **APNs (price-alert push)** — enable Push Notifications on the App ID; create an APNs Auth Key (.p8) and set `supabase secrets set APNS_KEY_P8=@AuthKey.p8 APNS_KEY_ID=<id> APNS_TEAM_ID=<team> APNS_BUNDLE_ID=com.carddex.app APNS_HOST=api.sandbox.push.apple.com` (use `api.push.apple.com` for release). Deploy `register-device` + `push-price-alerts`; run migrations through 0016 (schedules the hourly push). Flip `aps-environment` to `production` in `Carddex.entitlements` for the App Store build. Code is ready; until these exist, the in-app local notifications still fire while the app is open.

## 5. Test & build commands

```bash
bash scripts/dev.sh build    # regenerate + build (0 warnings expected)
bash scripts/dev.sh test     # regenerate + run 71 tests
bash scripts/dev.sh run      # build + install + launch in simulator
bash scripts/dev.sh shot     # run + screenshot to /tmp/carddex.png
```

## 6. Key file map

```
Carddex/
  App/
    CarddexApp.swift          # composition root — all @State stores + wiring
    AppEnvironment.swift      # service picker (live vs fake) — @MainActor
    RootView.swift            # tab switch + GlassTabBar
    AppRouter.swift           # selectedTab state
  Store/
    CollectionStore.swift     # owned cards + sync triggers
    MarketStore.swift         # market data (protocol-backed service)
    WatchlistStore.swift      # followed cards + price alerts + sync
    WishlistStore.swift       # grail list + sync
    SubscriptionStore.swift   # Pro entitlement + scan quota + sync
    AuthSessionStore.swift    # session lifecycle + Keychain (@MainActor)
    Persistence.swift         # Disk (Codable→JSON + os.Logger)
    WidgetShared.swift        # widget snapshot IPC
  Services/
    IdentificationService.swift   # protocol + ScanInput/Outcome/Error
    LiveIdentificationService.swift  # Supabase identify + JWT
    FakeIdentificationService.swift
    AuthService.swift          # protocol + SupabaseAuthService + FakeAuthService
    SyncService.swift          # protocol + LiveSyncService + NoOpSyncService + FakeSyncService
    MarketService.swift        # protocol + MarketService + FakeMarketService
    AppConfig.swift            # Secrets.plist loader + service factory
    KeychainStore.swift        # secure token storage
    Marketplace.swift          # eBay affiliate link builder
    CardTextRecognizer.swift   # Vision OCR
    CameraScanView.swift       # VisionKit DataScanner
    MotionManager.swift        # CoreMotion gyro
  Models/                      # Card, Money, CollectionItem, CardSet, MarketData, etc.
  DesignSystem/
    Theme.swift                # all tokens (dark-first)
    RollingNumber.swift        # count-up animation
    FlipCardView.swift         # tap-to-flip card + CardBackView
    ScanOverlay.swift          # choreographed scan animation
    Components/                # 16 reusable views
  Features/
    Collection/               # CollectionView, CardDetailView, CardPriceChart, SetDetailView
    Market/                   # MarketView, MarketCardView, SalesChart, etc.
    Scan/                     # ScanView, BulkScanView
    Portfolio/                # PortfolioView
    Grails/                   # GrailsView
    Onboarding, Paywall, Selling, Sharing, Settings
  Intents/                    # AppIntents + SpotlightIndexer
  SampleData/                 # bundled catalog + market data
CarddexTests/                 # 11 suites, 71 tests
CarddexWidgets/               # Case Index + Portfolio widgets
supabase/                     # migrations 0001–0010 + Edge Functions
```
