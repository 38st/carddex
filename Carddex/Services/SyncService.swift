import Foundation

/// Sync seam — protocol so tests inject a fake/no-op instead of calling PostgREST.
/// Each method mirrors a store mutation; the live implementation POSTs to
/// Supabase's PostgREST under RLS using the user's JWT. No-op when signed out.
///
/// Two generations coexist:
/// - Legacy view-struct upserts (`upsertCollectionItem(_:)`, …) — kept for
///   backward compatibility with existing tests; stores no longer call these.
/// - DTO-based push + `pullChanges(since:)` — used by the `SyncEngine`. DTOs
///   align to the table columns and carry `updated_at`/`deleted_at` for LWW.
protocol SyncServiceProtocol: Sendable {
    // Legacy (view-struct) — retained for test fakes.
    func upsertCollectionItem(_ item: CollectionItem) async throws
    func deleteCollectionItem(id: UUID) async throws
    func upsertPriceAlert(_ alert: PriceAlert) async throws
    func deletePriceAlert(cardID: String) async throws
    func upsertWishlistEntry(_ entry: GrailEntry) async throws
    func deleteWishlistEntry(cardID: String) async throws
    func upsertSubscriptionState(_ state: SubscriptionStateDTO) async throws
    func pullAll() async throws -> RemoteState

    // DTO-based — used by the SyncEngine.
    /// Incremental pull: rows touched since `since` (nil = full pull), with
    /// tombstoned rows included so the client can learn of remote deletes.
    func pullChanges(since: Date?) async throws -> RemoteChanges
    /// Push a local dirty row. Soft-delete: when `deletedAt` is non-null the
    /// upsert carries the tombstone so other devices see the delete.
    func pushCollectionItem(_ dto: CollectionItemDTO) async throws
    func pushPriceAlert(_ dto: PriceAlertDTO) async throws
    func pushGrailEntry(_ dto: GrailEntryDTO) async throws
    func pushSubscription(_ dto: SubscriptionDTO) async throws
}

/// Snapshot of the user's remote state — what a fresh device boots from.
struct RemoteState: Sendable {
    var collectionItems: [CollectionItem]
    var priceAlerts: [PriceAlert]
    var wishlistEntries: [GrailEntry]
    var subscription: SubscriptionStateDTO?
}

/// Mirrors `SubscriptionStore.State` for transport.
struct SubscriptionStateDTO: Codable, Sendable, Equatable {
    var isPro: Bool
    var scansThisMonth: Int
}

/// No-op sync — used when signed out, in previews/tests, or when no backend is
/// configured. Every method succeeds without doing anything; `pullAll` returns
/// empty state. This is what the app uses until auth is live.
struct NoOpSyncService: SyncServiceProtocol {
    func upsertCollectionItem(_ item: CollectionItem) async throws {}
    func deleteCollectionItem(id: UUID) async throws {}
    func upsertPriceAlert(_ alert: PriceAlert) async throws {}
    func deletePriceAlert(cardID: String) async throws {}
    func upsertWishlistEntry(_ entry: GrailEntry) async throws {}
    func deleteWishlistEntry(cardID: String) async throws {}
    func upsertSubscriptionState(_ state: SubscriptionStateDTO) async throws {}
    func pullAll() async throws -> RemoteState {
        RemoteState(collectionItems: [], priceAlerts: [], wishlistEntries: [], subscription: nil)
    }

    func pullChanges(since: Date?) async throws -> RemoteChanges { .empty }
    func pushCollectionItem(_ dto: CollectionItemDTO) async throws {}
    func pushPriceAlert(_ dto: PriceAlertDTO) async throws {}
    func pushGrailEntry(_ dto: GrailEntryDTO) async throws {}
    func pushSubscription(_ dto: SubscriptionDTO) async throws {}
}

/// Calls Supabase PostgREST over REST (no SPM dependency). Uses the user's JWT
/// from `AuthSessionStore` as the `Authorization` + `apikey` headers. Tables are
/// guarded by RLS (`auth.uid() = user_id`); writes use `Prefer: resolution=
/// merge-duplicates` for upsert. Sync is best-effort — failures are logged via
/// `os.Logger` and surfaced as a `lastSyncError` on the session store.
struct LiveSyncService: SyncServiceProtocol {
    let baseURL: URL          // https://<ref>.supabase.co
    let apiKey: String        // anon key
    let tokenProvider: AuthSessionStore
    var session: URLSession = .shared

    init?(config: SupabaseConfig, tokenProvider: AuthSessionStore) {
        self.baseURL = config.baseURL
        self.apiKey = config.anonKey
        self.tokenProvider = tokenProvider
    }

    // MARK: - Collection

    func upsertCollectionItem(_ item: CollectionItem) async throws {
        try await upsert("collection_items", body: encode(item))
    }
    func deleteCollectionItem(id: UUID) async throws {
        try await delete("collection_items", filter: "id=eq.\(id.uuidString.lowercased())")
    }

    // MARK: - Price alerts

    func upsertPriceAlert(_ alert: PriceAlert) async throws {
        try await upsert("price_alerts", body: encode(alert))
    }
    func deletePriceAlert(cardID: String) async throws {
        try await delete("price_alerts", filter: "card_id=eq.\(cardID)")
    }

    // MARK: - Wishlist

    func upsertWishlistEntry(_ entry: GrailEntry) async throws {
        try await upsert("wishlists", body: encode(entry))
    }
    func deleteWishlistEntry(cardID: String) async throws {
        try await delete("wishlists", filter: "card_id=eq.\(cardID)")
    }

    // MARK: - Subscription

    func upsertSubscriptionState(_ state: SubscriptionStateDTO) async throws {
        try await upsert("subscriptions", body: encode(state))
    }

    // MARK: - Pull

    func pullAll() async throws -> RemoteState {
        let items: [CollectionItem] = try await select("collection_items")
        let alerts: [PriceAlert] = try await select("price_alerts")
        let grails: [GrailEntry] = try await select("wishlists")
        let subs: [SubscriptionStateDTO] = try await select("subscriptions")
        return RemoteState(
            collectionItems: items,
            priceAlerts: alerts,
            wishlistEntries: grails,
            subscription: subs.first
        )
    }

    // MARK: - DTO push/pull (SyncEngine)

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    /// ISO8601 string for the `updated_at=gt.<since>` PostgREST filter.
    private func iso8601String(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    func pullChanges(since: Date?) async throws -> RemoteChanges {
        let sinceFilter = since.map(iso8601String)
        let items: [CollectionItemDTO] = try await selectDTO(
            "collection_items",
            select: "*,card:cards(*)",
            since: sinceFilter
        )
        let alerts: [PriceAlertDTO] = try await selectDTO("price_alerts", select: "*", since: sinceFilter)
        let grails: [GrailEntryDTO] = try await selectDTO("wishlists", select: "*", since: sinceFilter)
        let subs: [SubscriptionDTO] = try await selectDTO("subscriptions", select: "*", since: sinceFilter)
        return RemoteChanges(
            collectionItems: items,
            priceAlerts: alerts,
            wishlistEntries: grails,
            subscription: subs.first
        )
    }

    func pushCollectionItem(_ dto: CollectionItemDTO) async throws {
        try await upsert("collection_items", body: try encoder().encode(dto), onConflict: "id")
    }
    func pushPriceAlert(_ dto: PriceAlertDTO) async throws {
        try await upsert("price_alerts", body: try encoder().encode(dto), onConflict: "user_id,card_id")
    }
    func pushGrailEntry(_ dto: GrailEntryDTO) async throws {
        try await upsert("wishlists", body: try encoder().encode(dto), onConflict: "user_id,card_id")
    }
    func pushSubscription(_ dto: SubscriptionDTO) async throws {
        try await upsert("subscriptions", body: try encoder().encode(dto), onConflict: "user_id")
    }

    /// PostgREST select with an optional `updated_at=gt.<since>` filter and a
    /// custom `select` projection (used for the card join on collection_items).
    private func selectDTO<T: Decodable>(_ table: String, select: String, since: String?) async throws -> [T] {
        var req = try await authedRequest(table: table)
        guard let url = req.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        var query = "select=\(select)"
        if let since { query += "&updated_at=gt.\(since)" }
        comps.query = query
        req.url = comps.url
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try decoder().decode([T].self, from: data)
    }

    // MARK: - REST helpers

    private func upsert(_ table: String, body: Data, onConflict: String? = nil) async throws {
        guard !body.isEmpty else { return }
        var req = try await authedRequest(table: table)
        req.httpMethod = "POST"
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = body
        if let onConflict {
            guard let url = req.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw URLError(.badURL)
            }
            comps.query = "on_conflict=\(onConflict)"
            req.url = comps.url
        }
        try await send(req)
    }

    private func delete(_ table: String, filter: String) async throws {
        var req = try await authedRequest(table: table)
        req.httpMethod = "DELETE"
        guard let url = req.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        comps.query = filter
        req.url = comps.url
        try await send(req)
    }

    private func select<T: Decodable>(_ table: String) async throws -> [T] {
        var req = try await authedRequest(table: table)
        guard let url = req.url, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        comps.query = "select=*"
        req.url = comps.url
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([T].self, from: data)
    }

    private func authedRequest(table: String) async throws -> URLRequest {
        await tokenProvider.refreshIfNeeded()
        let url = baseURL.appendingPathComponent("rest/v1/\(table)")
        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        if let token = await MainActor.run(body: { tokenProvider.session?.accessToken }) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send(_ req: URLRequest) async throws {
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }
}

/// In-process fake for tests — records every call so tests can assert on sync.
final class FakeSyncService: SyncServiceProtocol, @unchecked Sendable {
    private(set) var collectionUpserts: [CollectionItem] = []
    private(set) var collectionDeletes: [UUID] = []
    private(set) var alertUpserts: [PriceAlert] = []
    private(set) var alertDeletes: [String] = []
    private(set) var wishlistUpserts: [GrailEntry] = []
    private(set) var wishlistDeletes: [String] = []
    private(set) var subscriptionUpserts: [SubscriptionStateDTO] = []
    var remoteState: RemoteState = RemoteState(collectionItems: [], priceAlerts: [], wishlistEntries: [], subscription: nil)

    // DTO recordings (used by SyncEngine tests).
    private(set) var pushedCollectionItems: [CollectionItemDTO] = []
    private(set) var pushedPriceAlerts: [PriceAlertDTO] = []
    private(set) var pushedGrailEntries: [GrailEntryDTO] = []
    private(set) var pushedSubscriptions: [SubscriptionDTO] = []
    private(set) var pullSinceArgs: [Date?] = []
    /// What `pullChanges` returns. Set this in tests to drive the engine.
    var remoteChanges: RemoteChanges = .empty
    /// When true, the next `pullChanges`/push calls throw to exercise error paths.
    var shouldFail = false

    func upsertCollectionItem(_ item: CollectionItem) async throws { collectionUpserts.append(item) }
    func deleteCollectionItem(id: UUID) async throws { collectionDeletes.append(id) }
    func upsertPriceAlert(_ alert: PriceAlert) async throws { alertUpserts.append(alert) }
    func deletePriceAlert(cardID: String) async throws { alertDeletes.append(cardID) }
    func upsertWishlistEntry(_ entry: GrailEntry) async throws { wishlistUpserts.append(entry) }
    func deleteWishlistEntry(cardID: String) async throws { wishlistDeletes.append(cardID) }
    func upsertSubscriptionState(_ state: SubscriptionStateDTO) async throws { subscriptionUpserts.append(state) }
    func pullAll() async throws -> RemoteState { remoteState }

    /// Clear all DTO recordings (legacy recordings left as-is). Used by tests
    /// that want to assert only a single cycle's pushes.
    func resetDTORecordings() {
        pushedCollectionItems.removeAll()
        pushedPriceAlerts.removeAll()
        pushedGrailEntries.removeAll()
        pushedSubscriptions.removeAll()
        pullSinceArgs.removeAll()
    }

    func pullChanges(since: Date?) async throws -> RemoteChanges {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        pullSinceArgs.append(since)
        return remoteChanges
    }
    func pushCollectionItem(_ dto: CollectionItemDTO) async throws {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        pushedCollectionItems.append(dto)
    }
    func pushPriceAlert(_ dto: PriceAlertDTO) async throws {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        pushedPriceAlerts.append(dto)
    }
    func pushGrailEntry(_ dto: GrailEntryDTO) async throws {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        pushedGrailEntries.append(dto)
    }
    func pushSubscription(_ dto: SubscriptionDTO) async throws {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        pushedSubscriptions.append(dto)
    }
}
