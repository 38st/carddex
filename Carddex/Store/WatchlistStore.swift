import SwiftUI

/// Cards the user follows in the market (Card Ladder-style watchlist) and price
/// alerts. In-memory for now; persists to Supabase (`price_alerts`) at go-live.
@Observable
final class WatchlistStore {
    var followed: Set<String>
    var alerts: [PriceAlert]
    private let persistKey: String?

    private struct State: Codable {
        var followed: Set<String>
        var alerts: [PriceAlert]
    }

    /// `persistKey` enables Codable-to-disk persistence (production). Pass nil for
    /// previews/tests to stay purely in-memory.
    init(followed: Set<String> = [], alerts: [PriceAlert] = [], persistKey: String? = nil) {
        self.persistKey = persistKey
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

    func isFollowing(_ cardID: String) -> Bool { followed.contains(cardID) }

    func toggleFollow(_ cardID: String) {
        if followed.contains(cardID) { followed.remove(cardID) } else { followed.insert(cardID) }
        persist()
    }

    func hasAlert(_ cardID: String) -> Bool { alerts.contains { $0.cardID == cardID } }

    func setAlert(cardID: String, target: Money) {
        alerts.removeAll { $0.cardID == cardID }
        alerts.append(PriceAlert(cardID: cardID, target: target))
        persist()
    }

    func removeAlert(_ cardID: String) {
        alerts.removeAll { $0.cardID == cardID }
        persist()
    }
}

struct PriceAlert: Identifiable, Hashable, Sendable, Codable {
    let cardID: String
    let target: Money
    var id: String { cardID }
}
