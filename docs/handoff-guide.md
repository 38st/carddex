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
| **StoreKit 2** | Stub (`activatePro()` flips a bool) | `Store/SubscriptionStore.swift`, `Features/Paywall/PaywallView.swift` |
| **Condition tracking** | Read-only display; no editor | `Features/Collection/CardDetailView.swift`, `Models/CollectionItem.swift` |
| **Account deletion** | Stub (empty button handler) | `Features/Settings/SettingsView.swift` |
| **Tests** | 71 passing, 11 suites | `CarddexTests/` |
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

## 3. Remaining work — implementation guides

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

### 3.2 StoreKit 2 — replace the paywall stub (HIGH PRIORITY)

**What**: Replace `SubscriptionStore.activatePro()` (a bool flip) with real StoreKit 2 `Product.purchase()` + verified `Transaction`.

**Why**: Monetization is the last stubbed loop. Auth + sync are ready; StoreKit is the revenue gate.

**How**:
1. Create `Services/StoreKitService.swift`:
```swift
import StoreKit

protocol StoreKitServiceProtocol: Sendable {
    func fetchProducts() async throws -> [Product]
    func purchase(_ product: Product) async throws -> Transaction?
    func verifyEntitlement() async -> Bool
}

struct StoreKitService: StoreKitServiceProtocol {
    // Product IDs from App Store Connect (set up there first):
    // "com.carddex.pro.monthly" and "com.carddex.pro.annual"
    let productIDs: Set<String> = ["com.carddex.pro.monthly", "com.carddex.pro.annual"]

    func fetchProducts() async throws -> [Product] {
        try await Product.products(for: productIDs).sorted { $0.price < $1.price }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func verifyEntitlement() async -> Bool {
        // Iterate current entitlements — if any active transaction exists, user is Pro.
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == "com.carddex.pro.annual" || transaction.productID == "com.carddex.pro.monthly" {
                    if transaction.revocationDate == nil && transaction.expirationDate ?? .distantFuture > .now {
                        return true
                    }
                }
            }
        }
        return false
    }
}

struct FakeStoreKitService: StoreKitServiceProtocol {
    func fetchProducts() async throws -> [Product] { [] } // can't fake Product; tests mock at the store level
    func purchase(_ product: Product) async throws -> Transaction? { nil }
    func verifyEntitlement() async -> Bool { false }
}
```
2. Add `storeKit: any StoreKitServiceProtocol` to `AppEnvironment` (same pattern as auth/sync).
3. Update `PaywallView.swift` — replace the `subs.activatePro()` call:
```swift
PrimaryButton(title: "Subscribe", systemImage: "crown") {
    Task {
        if let product = selectedProduct {
            if let transaction = try? await env.storeKit.purchase(product) {
                subs.activatePro() // flips the local flag + syncs
            }
        }
    }
}
```
4. On app launch (`.task` in `CarddexApp`), verify the entitlement:
```swift
if await environment.storeKit.verifyEntitlement() {
    subscriptions.activatePro()
}
```

**Prerequisites**: 
- App Store Connect: create the two auto-renewable subscriptions + a subscription group.
- Set the product IDs in `StoreKitService`.
- Test in the sandbox environment (Settings → App Store → Sandbox Account on the simulator).
- Add the `StoreKit` configuration file to the project for local testing.

**Gotcha**: `Product` and `Transaction` are StoreKit types that can't be easily faked. Tests should mock at the `SubscriptionStore` level (call `activatePro()` directly), not at the StoreKit service level. The `StoreKitServiceProtocol` is for the app's DI seam, not for unit tests.

### 3.3 Account deletion (MEDIUM PRIORITY)

**What**: Wire the Settings "Delete account" button to an Edge Function that revokes tokens + deletes the user's data.

**Why**: App Store requirement (5.1.1(v)). The JWT is already available via `AuthSessionStore`.

**How**:
1. Deploy a Supabase Edge Function `account-delete` (POST, requires auth):
```typescript
// supabase/functions/account-delete/index.ts
Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response("unauthorized", { status: 401 });
  // The service-role key can delete the user from auth.users
  // (cascades to all RLS-protected tables via user_id FK).
  // Revoke eBay tokens if any. Write an audit row.
  // Return { ok: true }.
});
```
2. Add a method to `SyncServiceProtocol` (or a new `AccountService`):
```swift
func deleteAccount() async throws
```
3. In `LiveSyncService` (or the new service):
```swift
func deleteAccount() async throws {
    var req = try await authedRequest(table: "account-delete") // different path — adjust
    req.httpMethod = "POST"
    req.url = baseURL.appendingPathComponent("functions/v1/account-delete")
    try await send(req)
    // On success: clear local state
    await MainActor.run {
        KeychainStore.clearAll()
        // clear all stores
    }
}
```
4. In `SettingsView.swift`, replace the empty handler:
```swift
Button("Delete", role: .destructive) {
    Task {
        try? await environment.sync.deleteAccount()
        auth.signOut()
        // clear local stores
    }
}
```

### 3.4 Condition tracking on Card Detail (MEDIUM PRIORITY)

**What**: Let the user edit a card's condition and see a condition-adjusted value estimate.

**Why**: `CollectionItem.condition` exists but Card Detail only displays it read-only. The design spec calls for a condition selector. Condition-adjusted value makes portfolio value honest.

**How**:
1. Add a condition multiplier to `CardCondition`:
```swift
enum CardCondition: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case mint = "Mint", nearMint = "Near Mint", lightlyPlayed = "Lightly Played",
         moderatelyPlayed = "Moderately Played", heavilyPlayed = "Heavily Played", damaged = "Damaged"

    var multiplier: Decimal {
        switch self {
        case .mint: 1.0
        case .nearMint: 0.9
        case .lightlyPlayed: 0.75
        case .moderatelyPlayed: 0.6
        case .heavilyPlayed: 0.45
        case .damaged: 0.3
        }
    }
}
```
2. Add to `CollectionItem`:
```swift
var conditionAdjustedValue: Money {
    Money(amount: estimatedValue.amount * condition.multiplier)
}
```
3. In `CardDetailView.swift`, replace the read-only `LabeledContent("Condition", ...)` with an editable `Picker`:
```swift
Picker("Condition", selection: Binding(
    get: { item.condition },
    set: { newCondition in
        if let index = store.items.firstIndex(where: { $0.id == item.id }) {
            store.items[index].condition = newCondition
            // sync + persist happen in the store if you add a setter method
        }
    }
)) {
    ForEach(CardCondition.allCases) { Text($0.rawValue).tag($0) }
}
.pickerStyle(.menu)
```
4. Add a condition-adjusted value `StatTile`:
```swift
StatTile(title: "Condition value", value: item.conditionAdjustedValue.formatted, accent: Theme.accent)
```
5. Add a `setCondition(_:for:)` method to `CollectionStore` that persists + syncs:
```swift
func setCondition(_ condition: CardCondition, for item: CollectionItem) {
    if let index = items.firstIndex(where: { $0.id == item.id }) {
        items[index].condition = condition
        syncUpsert(items[index])
        persist()
    }
}
```

### 3.5 Weekly Recap card (LOW PRIORITY)

**What**: A "This week" panel on Portfolio: net $ change, biggest gainer/loser, new additions, set progress.

**Why**: The product plan calls it the #1 retention push ("weekly your portfolio moved $X"). Pure client-side derivation from existing stores.

**How**:
1. Create `Features/Portfolio/WeeklyRecapView.swift`:
2. Derive everything from `CollectionStore` + `MarketStore`:
```swift
struct WeeklyRecapView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(MarketStore.self) private var marketStore

    private var newThisWeek: [CollectionItem] {
        store.items.filter { $0.dateAdded > Date().addingTimeInterval(-7 * 86400) }
    }
    private var biggestGainer: CollectionItem? {
        store.movers.max { ($0.gainPercent ?? 0) < ($1.gainPercent ?? 0) }
    }
    private var biggestLoser: CollectionItem? {
        store.movers.min { ($0.gainPercent ?? 0) < ($1.gainPercent ?? 0) }
    }
    // ... render as a glass panel with stat tiles + movers
}
```
3. Insert it at the top of `PortfolioView`'s `VStack` (before the chart).

### 3.6 Light mode ("daylight case") (LOW PRIORITY)

**What**: Implement the spec's light theme with adaptive `Theme` tokens.

**Why**: The design spec defines it fully but the app is dark-only. Some users prefer light mode.

**How**: This is a larger refactor — `Theme` currently uses static `Color(hex:)` values. To support light mode:
1. Convert `Theme` from an enum with static `let` to use `@Environment(\.colorScheme)` adaptive assets:
```swift
static let accent = Color("AccentColor") // in Assets.xcassets with light + dark variants
```
2. Or use `Color(light:dark:)` (iOS 18+):
```swift
static let accent = Color(light: Color(hex: 0x5A57F0), dark: Color(hex: 0x6E6BFF))
```
3. Test every screen in both modes. The vault background gradient needs a light variant.

**Estimate**: Half a day. Not hard, but touches every screen.

## 4. Backend setup checklist (for going live)

These are the steps that require human accounts/credentials — the code is ready:

1. **Apple Developer account** ($99/yr) — for device testing, TestFlight, Sign in with Apple.
2. **Supabase project** — `supabase link --project-ref <ref>`, `supabase db push` (runs migrations 0001–0010).
3. **Enable Sign in with Apple** — Supabase Dashboard → Authentication → Providers → Apple. Follow Apple's setup (Services ID, key, redirect URL).
4. **Vision model key** — `supabase secrets set ANTHROPIC_API_KEY=<key>`, deploy `identify`.
5. **Secrets.plist** — `cp Secrets.example.plist Carddex/Resources/Secrets.plist`, fill in `SUPABASE_PROJECT_REF` + `SUPABASE_ANON_KEY` + `EBAY_AFFILIATE_CAMPAIGN_ID`.
6. **StoreKit** — App Store Connect → create subscription products → set IDs in `StoreKitService`.
7. **eBay (Phase 3)** — `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` / `EBAY_REDIRECT_URI` + the `ebay-oauth` / `ebay-list` functions.

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
