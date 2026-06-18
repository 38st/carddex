import Foundation
import SwiftData

/// SwiftData backing for a `GrailEntry` (a wishlist/grail-list item). One per
/// (user, card); the local entity is keyed by `cardID`.
///
/// Sync fields match `CollectionItemEntity` — see its header for the pattern.
@Model
final class GrailEntryEntity {
    @Attribute(.unique) var cardID: String
    var targetAmount: Double?
    var targetCurrency: String?
    var note: String?
    var dateAdded: Date

    var dirty: Bool
    var remoteUpdatedAt: Date?
    var deletedAt: Date?

    init(
        cardID: String,
        targetAmount: Double?,
        targetCurrency: String?,
        note: String?,
        dateAdded: Date,
        dirty: Bool = true,
        remoteUpdatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.cardID = cardID
        self.targetAmount = targetAmount
        self.targetCurrency = targetCurrency
        self.note = note
        self.dateAdded = dateAdded
        self.dirty = dirty
        self.remoteUpdatedAt = remoteUpdatedAt
        self.deletedAt = deletedAt
    }
}

extension GrailEntryEntity {
    func toModel() -> GrailEntry {
        let target = targetAmount.map {
            Money(amount: Decimal($0), currencyCode: targetCurrency ?? "USD")
        }
        return GrailEntry(
            cardID: cardID,
            target: target,
            note: note,
            dateAdded: dateAdded
        )
    }

    @discardableResult
    static func insert(from entry: GrailEntry, into context: ModelContext) -> GrailEntryEntity {
        let entity = GrailEntryEntity(
            cardID: entry.cardID,
            targetAmount: entry.target.map { NSDecimalNumber(decimal: $0.amount).doubleValue },
            targetCurrency: entry.target?.currencyCode,
            note: entry.note,
            dateAdded: entry.dateAdded
        )
        context.insert(entity)
        return entity
    }

    func apply(from entry: GrailEntry, remoteUpdatedAt: Date?, deletedAt: Date? = nil) {
        targetAmount = entry.target.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
        targetCurrency = entry.target?.currencyCode
        note = entry.note
        dateAdded = entry.dateAdded
        self.remoteUpdatedAt = remoteUpdatedAt
        self.deletedAt = deletedAt
        dirty = false
    }
}
