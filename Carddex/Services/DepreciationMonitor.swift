import Foundation

/// Monitors portfolio-level depreciation and fires alerts when the total
/// collection value drops significantly. Complements per-card price alerts
/// with a portfolio-wide risk signal.
struct DepreciationMonitor {

    struct Alert {
        let dropPercent: Double
        let dropAmount: Double
        let days: Int
        let message: String
    }

    /// Check portfolio history for recent drops. Returns an alert if the
    /// portfolio has declined more than `threshold`% over the last `days`.
    @MainActor
    static func check(
        history: PortfolioHistoryStore,
        threshold: Double = 10,
        days: Int = 7
    ) -> Alert? {
        let snapshots = history.points(since: Calendar.current.date(byAdding: .day, value: -days, to: Date()))
        guard snapshots.count >= 2,
              let first = snapshots.first,
              let last = snapshots.last,
              first.value > 0 else { return nil }

        let drop = first.value - last.value
        let dropPct = drop / first.value * 100

        guard dropPct >= threshold else { return nil }

        let message: String
        switch days {
        case 1:
            message = "Your collection dropped \(String(format: "%.1f", dropPct))% today — consider reviewing underperformers."
        case 7:
            message = "Your collection is down \(String(format: "%.1f", dropPct))% this week (\(Money(amount: Decimal(abs(drop))).formatted) lost)."
        case 30:
            message = "Your collection is down \(String(format: "%.1f", dropPct))% this month — the market may be cooling."
        default:
            message = "Your collection dropped \(String(format: "%.1f", dropPct))% over \(days) days."
        }

        return Alert(
            dropPercent: dropPct,
            dropAmount: drop,
            days: days,
            message: message
        )
    }

    /// Check multiple time windows and return the most severe alert.
    @MainActor
    static func checkAll(history: PortfolioHistoryStore) -> Alert? {
        let windows: [(days: Int, threshold: Double)] = [
            (1, 8),
            (7, 10),
            (30, 15),
        ]

        var worst: Alert?
        for window in windows {
            if let alert = check(history: history, threshold: window.threshold, days: window.days) {
                if worst == nil || alert.dropPercent > (worst?.dropPercent ?? -Double.infinity) {
                    worst = alert
                }
            }
        }

        return worst
    }
}
