import Foundation
import SwiftData

/// One day's total portfolio value. Local-only (not synced) — value history is
/// recorded on-device and accrues over time. Keyed by the start-of-day date so
/// there's exactly one point per calendar day.
@Model
final class PortfolioSnapshotEntity {
    @Attribute(.unique) var day: Date
    var value: Double

    init(day: Date, value: Double) {
        self.day = day
        self.value = value
    }
}
