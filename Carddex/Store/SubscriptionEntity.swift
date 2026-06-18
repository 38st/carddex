import Foundation
import SwiftData

/// SwiftData backing for subscription/entitlement state. A 1:1 per-user
/// singleton (one row, keyed by a fixed id). No tombstone — a cancelled
/// subscription is represented as tier/status, not a deleted row — but it
/// still carries `remoteUpdatedAt` for LWW on the single row.
@Model
final class SubscriptionEntity {
    /// Fixed singleton key — there's only ever one row.
    @Attribute(.unique) var key: String
    var isPro: Bool
    var scansThisMonth: Int

    var dirty: Bool
    var remoteUpdatedAt: Date?

    init(
        key: String = "default",
        isPro: Bool = false,
        scansThisMonth: Int = 0,
        dirty: Bool = true,
        remoteUpdatedAt: Date? = nil
    ) {
        self.key = key
        self.isPro = isPro
        self.scansThisMonth = scansThisMonth
        self.dirty = dirty
        self.remoteUpdatedAt = remoteUpdatedAt
    }
}

extension SubscriptionEntity {
    func toDTO() -> SubscriptionStateDTO {
        SubscriptionStateDTO(isPro: isPro, scansThisMonth: scansThisMonth)
    }

    @discardableResult
    static func insert(from dto: SubscriptionStateDTO, into context: ModelContext) -> SubscriptionEntity {
        let entity = SubscriptionEntity(isPro: dto.isPro, scansThisMonth: dto.scansThisMonth)
        context.insert(entity)
        return entity
    }

    func apply(from dto: SubscriptionStateDTO, remoteUpdatedAt: Date?) {
        isPro = dto.isPro
        scansThisMonth = dto.scansThisMonth
        self.remoteUpdatedAt = remoteUpdatedAt
        dirty = false
    }
}
