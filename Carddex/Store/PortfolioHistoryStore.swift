import Foundation
import Observation
import SwiftData

/// Records the portfolio's total value once per calendar day and serves the
/// history to the Portfolio chart. Local-only (device history); backed by
/// SwiftData. Starts empty and accrues — the chart falls back to a synthetic
/// curve until at least two real days exist.
@MainActor
@Observable
final class PortfolioHistoryStore {
    private(set) var snapshots: [Snapshot] = []
    private let persistence: PersistenceController?

    struct Snapshot: Identifiable, Sendable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    init(persistence: PersistenceController? = nil) {
        self.persistence = persistence
        reload()
    }

    /// Record (or update) today's total value. Safe to call on every launch.
    func record(value: Double) {
        guard let persistence, value > 0 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let ctx = persistence.context
        let all = (try? ctx.fetch(FetchDescriptor<PortfolioSnapshotEntity>())) ?? []
        if let existing = all.first(where: { $0.day == today }) {
            existing.value = value
        } else {
            ctx.insert(PortfolioSnapshotEntity(day: today, value: value))
        }
        persistence.save()
        reload()
    }

    /// Snapshots on or after `since` (nil → all of them).
    func points(since: Date?) -> [Snapshot] {
        guard let since else { return snapshots }
        return snapshots.filter { $0.date >= since }
    }

    private func reload() {
        guard let persistence else { snapshots = []; return }
        let all = (try? persistence.context.fetch(
            FetchDescriptor<PortfolioSnapshotEntity>(sortBy: [SortDescriptor(\.day)]))) ?? []
        snapshots = all.map { Snapshot(date: $0.day, value: $0.value) }
    }
}
