import Foundation
import SwiftData

/// SwiftData backing for a `PriceAlert`. Keyed by (user, card) server-side;
/// the local entity is keyed by `cardID` (matches the wire struct's id).
///
/// Sync fields match `CollectionItemEntity` — see its header for the pattern.
@Model
final class PriceAlertEntity {
    @Attribute(.unique) var cardID: String
    var targetAmount: Double           // `Money.amount` as Double
    var targetCurrency: String

    var dirty: Bool
    var remoteUpdatedAt: Date?
    var deletedAt: Date?

    init(
        cardID: String,
        targetAmount: Double,
        targetCurrency: String,
        dirty: Bool = true,
        remoteUpdatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.cardID = cardID
        self.targetAmount = targetAmount
        self.targetCurrency = targetCurrency
        self.dirty = dirty
        self.remoteUpdatedAt = remoteUpdatedAt
        self.deletedAt = deletedAt
    }
}

extension PriceAlertEntity {
    func toModel() -> PriceAlert {
        PriceAlert(
            cardID: cardID,
            target: Money(amount: Decimal(targetAmount), currencyCode: targetCurrency)
        )
    }

    @discardableResult
    static func insert(from alert: PriceAlert, into context: ModelContext) -> PriceAlertEntity {
        let entity = PriceAlertEntity(
            cardID: alert.cardID,
            targetAmount: NSDecimalNumber(decimal: alert.target.amount).doubleValue,
            targetCurrency: alert.target.currencyCode
        )
        context.insert(entity)
        return entity
    }

    func apply(from alert: PriceAlert, remoteUpdatedAt: Date?, deletedAt: Date? = nil) {
        targetAmount = NSDecimalNumber(decimal: alert.target.amount).doubleValue
        targetCurrency = alert.target.currencyCode
        self.remoteUpdatedAt = remoteUpdatedAt
        self.deletedAt = deletedAt
        dirty = false
    }
}
