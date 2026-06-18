import SwiftUI

/// Cards the user follows in the market (Card Ladder-style watchlist) and price
/// alerts. In-memory for now; persists to Supabase (`price_alerts`) at go-live.
@Observable
final class WatchlistStore {
    var followed: Set<String>
    var alerts: [PriceAlert]
    private let persistKey: String?
    var sync: (any SyncServiceProtocol)? = nil

    private struct State: Codable {
        var followed: Set<String>
        var alerts: [PriceAlert]
    }

    /// `persistKey` enables Codable-to-disk persistence (production). Pass nil for
    /// previews/tests to stay purely in-memory. `sync` mirrors alert mutations to
    /// Supabase; nil = local-only. (`followed` is local-only until the watchlist
    /// table lands — alerts are the persisted/alerting surface.)
    init(followed: Set<String> = [], alerts: [PriceAlert] = [], persistKey: String? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistKey = persistKey
        self.sync = sync
        if let persistKey, let saved = Disk.load(State.self, from: persistKey) {
            self.followed = saved.followed
            self.alerts = saved.alerts
        } else {
            self.followed = followed
            self.alerts = alerts
            persist()
        }
    }

    private func persist() {
        if let persistKey { Disk.save(State(followed: followed, alerts: alerts), to: persistKey) }
    }

    private func syncUpsertAlert(_ alert: PriceAlert) {
        guard let sync else { return }
        Task { try? await sync.upsertPriceAlert(alert) }
    }

    private func syncDeleteAlert(_ cardID: String) {
        guard let sync else { return }
        Task { try? await sync.deletePriceAlert(cardID: cardID) }
    }

    func isFollowing(_ cardID: String) -> Bool { followed.contains(cardID) }

    func toggleFollow(_ cardID: String) {
        if followed.contains(cardID) { followed.remove(cardID) } else { followed.insert(cardID) }
        persist()
    }

    func hasAlert(_ cardID: String) -> Bool { alerts.contains { $0.cardID == cardID } }

    func setAlert(cardID: String, target: Money) {
        alerts.removeAll { $0.cardID == cardID }
        let alert = PriceAlert(cardID: cardID, target: target)
        alerts.append(alert)
        syncUpsertAlert(alert)
        persist()
    }

    func removeAlert(_ cardID: String) {
        alerts.removeAll { $0.cardID == cardID }
        syncDeleteAlert(cardID)
        persist()
    }

    /// Merge remote alerts from a pull. Additive: alerts for cards not already
    /// tracked locally are appended.
    func mergeRemote(_ remote: [PriceAlert]) {
        let localCardIDs = Set(alerts.map(\.cardID))
        for alert in remote where !localCardIDs.contains(alert.cardID) {
            alerts.append(alert)
        }
        persist()
    }
}

struct PriceAlert: Identifiable, Hashable, Sendable, Codable {
    let cardID: String
    let target: Money
    var id: String { cardID }
}
