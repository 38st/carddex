# Carddex — iOS Engineering Plan (Phase 1 → Launch)

*Author: iOS Engineer.*

## 0. Baseline (what the repo gives us)
- Models are value types, `Codable/Hashable/Sendable` (`Card`, `CollectionItem`, `Money`,
  `CardGame`, `CardCondition`). `Card.id` is the catalog's stable id — the join key for refresh,
  matches Supabase `cards.id text`.
- State = a single `@Observable CollectionStore`, injected via `.environment`, read via
  `@Environment`. Its doc comment promises views don't change when the backing store swaps to
  Supabase. That's the seam.
- Views are `NavigationStack` + value-based navigation, `LazyVGrid`, consistent `Theme` tokens.
- `CardArtwork` is a placeholder that "swaps to AsyncImage" once `imageURL` is populated.
- Scan is faked (a "Simulate scan" button) — replace the data source, not the UX skeleton.
- No service layer, networking, SPM packages, or persistence yet. Edge Functions are named in
  `supabase/README.md` but don't exist — the #1 cross-dependency.

## 1. Architecture — MV (`@Observable` + protocol-based service layer)
Not MVVM (ceremony over an already-observable store), not TCA (too heavy for a solo dev). The repo
already is MV. Thin `@Observable` stores own UI state and orchestrate; stateless, protocol-typed
services do I/O. Stores depend on service protocols → fakes for previews/tests for free.

```swift
@MainActor @Observable
final class AppEnvironment {
    let identification: any IdentificationService
    let catalog: any CatalogService
    let auth: any AuthService
    let collection: CollectionStore
    static let live = AppEnvironment(/* live */)
    static let preview = AppEnvironment(/* fakes + SampleData */)
}
```

Module structure: keep everything in the app target through Phase 1; extract local SPM packages
(`CarddexCore`, `CarddexCatalog`, `CarddexIdentify`, `CarddexNetworking`, `CarddexPersistence`,
`CarddexDesignSystem`) once boundaries are proven (end of Phase 2). Split `CardGame.accent/symbol`
UI extensions into the design-system package so core is UI-free.

## 2. Camera & scanning
Start with VisionKit `DataScannerViewController` (live camera + on-device text + bounding boxes for
free) for the fast path; build a custom `AVFoundation` capture path for the real card photo:
`AVCaptureSession` + `VNDetectRectanglesRequest` tuned to the 2.5×3.5 ratio for auto-crop +
`CIPerspectiveCorrection` to deskew. Card-shaped cutout guide, hold-steady coaching, haptic
auto-capture. Concurrency: keep the capture/Vision pipeline in a dedicated actor; convert
`CMSampleBuffer`/`CVPixelBuffer` to `CGImage`/`CIImage` inside the pipeline (they aren't Sendable).
Structure capture as an `AsyncStream<CapturedCard>` from day one so bulk/continuous scan needs no
rewrite.

## 3. Identification client
Protocol-based, swappable, with a fake.

```swift
struct ScanInput: Sendable { let image: CGImage; let ocrText: [String]; let gameHint: CardGame? }
struct IdentificationCandidate: Identifiable, Sendable { let id: String; let card: Card; let confidence: Double }
enum IdentificationResult: Sendable {
    case confident(IdentificationCandidate)
    case ambiguous([IdentificationCandidate])
    case unidentified(ocrText: [String])
}
protocol IdentificationService: Sendable {
    func identify(_ input: ScanInput) async throws -> IdentificationResult
}
```

On-device pre-pass: `VNRecognizeTextRequest` (`.accurate`, `usesLanguageCorrection = false`).
Backend call: POST `{image, ocrText, gameHint}` to the `identify` Edge Function. Confidence routing:
`confident` (≥0.85) → confirm sheet; `ambiguous` → candidate list; `unidentified` → manual-search
fallback. Always end at the same confirm → `store.add(card)` path. Offline: OCR runs on-device;
queue a `PendingScan` (SwiftData) when offline. `FakeIdentificationService` unblocks all client work
before the Edge Function exists.

## 4. Catalog API client
One `CatalogService` protocol; one mapper per source normalizing into `Card`. Notes: Pokémon TCG API
(native id, `tcgplayer.prices.*.market`, API key, server-side), Scryfall (UUID, `prices.usd` string,
strict etiquette → server-side), YGOPRODeck (passcode + set code, multi-printing → pick matching set
code). Keys stay server-side; the client mostly types the backend's endpoints + tests the mappers as
pure functions. Image loading: Nuke (memory+disk cache, decode-time downsampling, prefetch) over
`AsyncImage`. Swap `CardArtwork`'s placeholder for `LazyImage`.

## 5. Persistence & sync
SwiftData, offline-first, Supabase as source of truth. `CollectionStore`'s array becomes
SwiftData-backed behind the same API. `@Model` entities (`CardEntity`, `CollectionItemEntity` with
`dirty`/`deletedAt`/`remoteUpdatedAt`, `PendingScan`). Structs stay the wire/view layer; thin
`toEntity()/toModel()` conversions keep SwiftData off the view/service layers. A `SyncEngine` actor
pushes dirty rows + pulls `updated_at > lastSync`; conflict = last-write-wins by `updated_at`
(needs an `updated_at` column on `collection_items`); deletes via tombstones. Use `supabase-swift`
for Auth/PostgREST/Storage/Functions.

## 6. Networking, errors, concurrency (Swift 6 strict)
`APIClient` is an actor owning `URLSession` + authed request building. Models stay `Sendable`; stores
+ view state `@MainActor`; services `Sendable`. Typed `CarddexError` (offline, unauthorized,
rateLimited, notIdentified, server, decoding) → designed UI states. Retries w/ backoff on transient;
structured concurrency + cancellation tied to view lifecycle (`.task {}`).

## 7. Performance
Decode-time image downsampling is the #1 lever (Nuke `ImageProcessors.Resize` or
`CGImageSourceCreateThumbnailAtIndex`). `LazyVGrid` virtualization + Nuke prefetch; paginate via
SwiftData predicate for very large libraries. Tear down `AVCaptureSession` on leaving Scan.

## 8. Testing (solo priorities)
Swift Testing. 1) Catalog mappers (JSON fixtures → `Card`). 2) Identification routing + `CollectionStore`
math (stacking, totals). 3) `SyncEngine` conflict/tombstone logic. 4) Snapshot tests for design-system
components. 5) One end-to-end UI smoke test injecting `AppEnvironment.preview`.

## 9. CI/CD
GitHub Actions (`xcodegen generate` → `xcodebuild build test`) + fastlane (`beta`, `release`) +
`fastlane match` for low-overhead signing + TestFlight. App Store Connect API key for non-interactive
auth. Xcode Cloud as the escape hatch if signing eats time. CI must regenerate the project from
`project.yml` (or check it produces no diff).

## 10. App Store technical checklist
- `PrivacyInfo.xcprivacy` manifest + required-reason APIs (UserDefaults `CA92.1`, file timestamp, etc.).
- App Privacy nutrition label: Camera/Photos (functionality), User Content, Account (Apple), Purchases.
- Sign in with Apple (`ASAuthorizationAppleIDProvider` → Supabase `signInWithIdToken`) + a
  delete-account flow (required).
- StoreKit 2 subscriptions (`Product`/`Transaction.currentEntitlements`); server-side validation via
  App Store Server Notifications V2 → Edge Function.
- Permission strings: `NSCameraUsageDescription` (set); add `NSPhotoLibraryUsageDescription` if importing.
- Push notifications capability (price alerts) — Phase 2–3.
- ATT: ship without tracking for v1 (keeps the privacy label clean).
- App icon set, launch screen, screenshots, age rating, export compliance (`ITSAppUsesNonExemptEncryption = NO`).

## 11. Security
Keychain for tokens (never UserDefaults). No third-party secrets in the app — all in Edge Functions.
Supabase anon key is public by design; safety = RLS + verified JWT (verify RLS is exhaustive before
launch). Certificate pinning = nice-to-have, not launch-blocking.

## 12. Milestones (effort, risk)
- Phase 1 — core loop (≈4–6 wk): service layer + `AppEnvironment`; SwiftData behind `CollectionStore`;
  🔴 camera + auto-crop; on-device OCR + client; 🔴 `identify` Edge Function integration (mock until
  ready); confirm/ambiguous/manual UI; Nuke artwork.
- Phase 1.5 — accounts & sync (≈2–3 wk): Sign in with Apple ↔ Supabase + delete-account; 🔴 `SyncEngine`.
- Phase 2 — pricing & portfolio (≈2 wk): consume `refresh-prices`; Swift Charts history; mapper tests.
- Phase 3 — eBay (≈2–3 wk): 🔴 OAuth connect + list flow (wires the disabled "List on eBay" button).
- Phase 4: continuous/bulk scan, embedding variant matching, sports, condition assist.
- Launch hardening (≈1–1.5 wk): 🔴 privacy manifest + label + StoreKit gate + permissions; CI + TestFlight.

Critical-path risks: (1) the `identify` contract & accuracy; (2) camera/auto-crop in real lighting;
(3) sync correctness; (4) App Review compliance. Mitigate #1/#3 by building against fakes.

## Top 5 engineering decisions
1. MV (`@Observable` + protocol service layer), not MVVM/TCA.
2. Everything cloud-routed through Supabase Edge Functions for keys; services are protocols with fakes.
3. SwiftData offline-first, server-as-truth, LWW + tombstones (needs `updated_at` on `collection_items`).
4. Nuke + decode-time downsampling for all card imagery.
5. VisionKit for v1 speed, custom AVFoundation + `VNDetectRectangles` for real capture, `AsyncStream`
   from day one.

## Dependencies
- Backend (hard blockers): `identify` function + JSON contract; `updated_at` on `collection_items`;
  catalog search endpoint; `refresh-prices`; Sign in with Apple + account-deletion; eBay functions;
  StoreKit Server Notifications handler; exhaustive RLS.
- Product: full scan/capture flow spec incl. ambiguous + manual-correction UI; onboarding + auth;
  paywall UX.
- Design: final tokens (typography, dark mode, semantic colors); app icon; per-game treatments.
- Shared: publish the `IdentificationService`/`CatalogService` protocols + DTOs early so the wire
  format stays in lockstep.
