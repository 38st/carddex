import Foundation

/// Sync seam — protocol so tests inject a fake/no-op instead of calling PostgREST.
/// The live implementation talks to Supabase's PostgREST under RLS using the
/// user's JWT (no-op when signed out). DTOs align to the table columns and carry
/// `updated_at`/`deleted_at` so the `SyncEngine` can do last-write-wins. The
/// engine owns the cycle: it pushes dirty rows and pulls incrementally.
protocol SyncServiceProtocol: Sendable {
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

/// Mirrors `SubscriptionStore.State` for transport.
struct SubscriptionStateDTO: Codable, Sendable, Equatable {
    var isPro: Bool
    var scansThisMonth: Int
}

/// No-op sync — used when signed out, in previews/tests, or when no backend is
/// configured. Every method succeeds without doing anything; pulls return empty.
/// This is what the app uses until auth is live.
struct NoOpSyncService: SyncServiceProtocol {
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
}

/// In-process fake for tests — records every call so tests can assert on sync.
final class FakeSyncService: SyncServiceProtocol, @unchecked Sendable {
    private(set) var pushedCollectionItems: [CollectionItemDTO] = []
    private(set) var pushedPriceAlerts: [PriceAlertDTO] = []
    private(set) var pushedGrailEntries: [GrailEntryDTO] = []
    private(set) var pushedSubscriptions: [SubscriptionDTO] = []
    private(set) var pullSinceArgs: [Date?] = []
    /// What `pullChanges` returns. Set this in tests to drive the engine.
    var remoteChanges: RemoteChanges = .empty
    /// When true, the next `pullChanges`/push calls throw to exercise error paths.
    var shouldFail = false

    /// Clear all DTO recordings. Used by tests that want to assert only a single
    /// cycle's pushes.
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
