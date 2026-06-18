import Foundation

/// Sync seam — protocol so tests inject a fake/no-op instead of calling PostgREST.
/// Each method mirrors a store mutation; the live implementation POSTs to
/// Supabase's PostgREST under RLS using the user's JWT. No-op when signed out.
protocol SyncServiceProtocol: Sendable {
    func upsertCollectionItem(_ item: CollectionItem) async throws
    func deleteCollectionItem(id: UUID) async throws
    func upsertPriceAlert(_ alert: PriceAlert) async throws
    func deletePriceAlert(cardID: String) async throws
    func upsertWishlistEntry(_ entry: GrailEntry) async throws
    func deleteWishlistEntry(cardID: String) async throws
    func upsertSubscriptionState(_ state: SubscriptionStateDTO) async throws
    /// Pull the remote state for the signed-in user (first sync / new device).
    func pullAll() async throws -> RemoteState
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

    // MARK: - REST helpers

    private func upsert(_ table: String, body: Data) async throws {
        guard !body.isEmpty else { return }
        var req = try await authedRequest(table: table)
        req.httpMethod = "POST"
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = body
        try await send(req)
    }

    private func delete(_ table: String, filter: String) async throws {
        var req = try await authedRequest(table: table)
        req.httpMethod = "DELETE"
        guard var comps = URLComponents(url: req.url!, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        comps.query = filter
        req.url = comps.url
        try await send(req)
    }

    private func select<T: Decodable>(_ table: String) async throws -> [T] {
        var req = try await authedRequest(table: table)
        guard var comps = URLComponents(url: req.url!, resolvingAgainstBaseURL: false) else {
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

    func upsertCollectionItem(_ item: CollectionItem) async throws { collectionUpserts.append(item) }
    func deleteCollectionItem(id: UUID) async throws { collectionDeletes.append(id) }
    func upsertPriceAlert(_ alert: PriceAlert) async throws { alertUpserts.append(alert) }
    func deletePriceAlert(cardID: String) async throws { alertDeletes.append(cardID) }
    func upsertWishlistEntry(_ entry: GrailEntry) async throws { wishlistUpserts.append(entry) }
    func deleteWishlistEntry(cardID: String) async throws { wishlistDeletes.append(cardID) }
    func upsertSubscriptionState(_ state: SubscriptionStateDTO) async throws { subscriptionUpserts.append(state) }
    func pullAll() async throws -> RemoteState { remoteState }
}
