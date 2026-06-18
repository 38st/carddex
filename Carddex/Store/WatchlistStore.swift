import SwiftUI
import Observation
import SwiftData

/// Cards the user follows in the market (Card Ladder-style watchlist) and price
/// alerts. Backed by SwiftData; keeps the same in-memory surface views use.
/// `followed` stays local-only (not synced) — alerts are the persisted surface.
@MainActor
@Observable
final class WatchlistStore {
    var followed: Set<String>
    var alerts: [PriceAlert]
    private let persistence: PersistenceController?
    var sync: (any SyncServiceProtocol)? = nil

    /// Codable state snapshot persisted to disk. Internal so the one-time
    /// Disk→SwiftData migration can read the legacy file.
    struct State: Codable {
        var followed: Set<String>
        var alerts: [PriceAlert]
    }

    /// `persistence` enables SwiftData-backed persistence (production). Pass
    /// nil for previews/tests to stay purely in-memory.
    init(followed: Set<String> = [], alerts: [PriceAlert] = [], persistence: PersistenceController? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistence = persistence
        self.sync = sync
        if let persistence {
            let live = Self.fetchLive(from: persistence.context)
            self.followed = followed       // `followed` is local-only; seed from caller
            self.alerts = live
        } else {
            self.followed = followed
            self.alerts = alerts
        }
    }

    private static func fetchLive(from context: ModelContext) -> [PriceAlert] {
        let descriptor = FetchDescriptor<PriceAlertEntity>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.compactMap { $0.toModel() }
    }

    private func save() { persistence?.save() }

    /// Reload the in-memory array from SwiftData. Called after a SyncEngine cycle.
    func refresh() {
        guard let persistence else { return }
        alerts = Self.fetchLive(from: persistence.context)
    }

    // Sync push is owned by the SyncEngine; stores only mark dirty on mutation.

    func isFollowing(_ cardID: String) -> Bool { followed.contains(cardID) }

    func toggleFollow(_ cardID: String) {
        if followed.contains(cardID) { followed.remove(cardID) } else { followed.insert(cardID) }
        // `followed` is local-only; no persistence/sync.
    }

    func hasAlert(_ cardID: String) -> Bool { alerts.contains { $0.cardID == cardID } }

    func setAlert(cardID: String, target: Money) {
        alerts.removeAll { $0.cardID == cardID }
        let alert = PriceAlert(cardID: cardID, target: target)
        alerts.append(alert)
        upsertEntity(alert)
        save()
    }

    func removeAlert(_ cardID: String) {
        alerts.removeAll { $0.cardID == cardID }
        if let persistence,
           let entity = try? persistence.context.fetch(FetchDescriptor<PriceAlertEntity>(
               predicate: #Predicate { $0.cardID == cardID }
           )).first {
            entity.deletedAt = .now
            entity.dirty = true
            persistence.save()
        }
    }

    /// Merge remote alerts from a pull. Additive: alerts for cards not already
    /// tracked locally are appended. The LWW variant lands in Slice 3.
    func mergeRemote(_ remote: [PriceAlert]) {
        let localCardIDs = Set(alerts.map(\.cardID))
        for alert in remote where !localCardIDs.contains(alert.cardID) {
            alerts.append(alert)
            upsertEntity(alert, dirty: false)
        }
        save()
    }

    /// Clear all local state and persist the empty snapshot. Used after a
    /// successful account deletion so a re-launch doesn't restore wiped data.
    func wipeLocal() {
        followed = []
        alerts = []
        if let persistence {
            let all = (try? persistence.context.fetch(FetchDescriptor<PriceAlertEntity>())) ?? []
            for entity in all { persistence.context.delete(entity) }
            persistence.save()
        }
    }

    private func upsertEntity(_ alert: PriceAlert, dirty: Bool = true) {
        guard let persistence else { return }
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<PriceAlertEntity>(
            predicate: #Predicate { $0.cardID == alert.cardID }
        )))?.first
        if let existing {
            existing.targetAmount = NSDecimalNumber(decimal: alert.target.amount).doubleValue
            existing.targetCurrency = alert.target.currencyCode
            existing.dirty = dirty
            existing.deletedAt = nil
        } else {
            let entity = PriceAlertEntity.insert(from: alert, into: ctx)
            entity.dirty = dirty
        }
    }
}

struct PriceAlert: Identifiable, Hashable, Sendable, Codable {
    let cardID: String
    let target: Money
    var id: String { cardID }
}
