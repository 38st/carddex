import SwiftUI

/// Cards the user follows in the market (Card Ladder-style watchlist) and price
/// alerts. In-memory for now; persists to Supabase (`price_alerts`) at go-live.
@Observable
final class WatchlistStore {
    var followed: Set<String>
    var alerts: [PriceAlert]

    init(followed: Set<String> = [], alerts: [PriceAlert] = []) {
        self.followed = followed
        self.alerts = alerts
    }

    func isFollowing(_ cardID: String) -> Bool { followed.contains(cardID) }

    func toggleFollow(_ cardID: String) {
        if followed.contains(cardID) { followed.remove(cardID) } else { followed.insert(cardID) }
    }

    func hasAlert(_ cardID: String) -> Bool { alerts.contains { $0.cardID == cardID } }

    func setAlert(cardID: String, target: Money) {
        alerts.removeAll { $0.cardID == cardID }
        alerts.append(PriceAlert(cardID: cardID, target: target))
    }

    func removeAlert(_ cardID: String) {
        alerts.removeAll { $0.cardID == cardID }
    }
}

struct PriceAlert: Identifiable, Hashable, Sendable {
    let cardID: String
    let target: Money
    var id: String { cardID }
}
