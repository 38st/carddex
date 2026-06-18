import Foundation
import SwiftData

/// SwiftData backing for a `CollectionItem`. Owns the sync-relevant fields as
/// first-class columns (quantity, condition, dates, dirty/deleted flags) and
/// stores the immutable catalog `Card` as a JSON blob — the card is catalog
/// data the client never mutates, so a blob keeps the entity simple and
/// queryable on the fields sync actually reconciles.
///
/// Sync fields (consumed by the Phase 2 SyncEngine):
/// - `dirty`: true when a local mutation hasn't been pushed yet.
/// - `remoteUpdatedAt`: the server's `updated_at` for last-write-wins merges.
/// - `deletedAt`: soft-delete tombstone; non-null means the row is logically
///   removed but retained so an incremental pull can propagate the delete to
///   other devices.
@Model
final class CollectionItemEntity {
    @Attribute(.unique) var id: UUID
    var cardData: Data                 // encoded `Card`
    var quantity: Int
    var conditionRaw: String           // `CardCondition.rawValue`
    var dateAdded: Date
    var purchasePriceAmount: Double?   // `Money.amount` as Double (SwiftData-friendly)
    var purchasePriceCurrency: String?

    // Sync metadata
    var dirty: Bool
    var remoteUpdatedAt: Date?
    var deletedAt: Date?

    init(
        id: UUID,
        cardData: Data,
        quantity: Int,
        conditionRaw: String,
        dateAdded: Date,
        purchasePriceAmount: Double?,
        purchasePriceCurrency: String?,
        dirty: Bool = true,
        remoteUpdatedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.cardData = cardData
        self.quantity = quantity
        self.conditionRaw = conditionRaw
        self.dateAdded = dateAdded
        self.purchasePriceAmount = purchasePriceAmount
        self.purchasePriceCurrency = purchasePriceCurrency
        self.dirty = dirty
        self.remoteUpdatedAt = remoteUpdatedAt
        self.deletedAt = deletedAt
    }
}

extension CollectionItemEntity {
    /// Encode a `Card` to the stored blob.
    static func encodeCard(_ card: Card) -> Data {
        (try? JSONEncoder().encode(card)) ?? Data()
    }

    /// Decode the stored blob back to a `Card`.
    var card: Card? {
        guard let card = try? JSONDecoder().decode(Card.self, from: cardData) else { return nil }
        return card
    }

    /// Build the view/wire struct from the entity.
    func toModel() -> CollectionItem? {
        guard let card else { return nil }
        let price = purchasePriceAmount.map {
            Money(amount: Decimal($0), currencyCode: purchasePriceCurrency ?? "USD")
        }
        return CollectionItem(
            id: id,
            card: card,
            quantity: quantity,
            condition: CardCondition(rawValue: conditionRaw) ?? .nearMint,
            dateAdded: dateAdded,
            purchasePrice: price
        )
    }

    /// Insert a new entity from a wire struct, marked dirty by default.
    @discardableResult
    static func insert(from item: CollectionItem, into context: ModelContext) -> CollectionItemEntity {
        let entity = CollectionItemEntity(
            id: item.id,
            cardData: encodeCard(item.card),
            quantity: item.quantity,
            conditionRaw: item.condition.rawValue,
            dateAdded: item.dateAdded,
            purchasePriceAmount: item.purchasePrice.map { NSDecimalNumber(decimal: $0.amount).doubleValue },
            purchasePriceCurrency: item.purchasePrice?.currencyCode
        )
        context.insert(entity)
        return entity
    }

    /// Apply a wire struct's fields onto an existing entity (used by LWW merge).
    func apply(from item: CollectionItem, remoteUpdatedAt: Date?, deletedAt: Date? = nil) {
        cardData = Self.encodeCard(item.card)
        quantity = item.quantity
        conditionRaw = item.condition.rawValue
        dateAdded = item.dateAdded
        purchasePriceAmount = item.purchasePrice.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
        purchasePriceCurrency = item.purchasePrice?.currencyCode
        self.remoteUpdatedAt = remoteUpdatedAt
        self.deletedAt = deletedAt
        dirty = false
    }
}
