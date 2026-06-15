import Foundation

/// One owned card (or stack of copies) in the user's collection.
struct CollectionItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var card: Card
    var quantity: Int
    var condition: CardCondition
    var dateAdded: Date
    var purchasePrice: Money?

    init(
        id: UUID = UUID(),
        card: Card,
        quantity: Int = 1,
        condition: CardCondition = .nearMint,
        dateAdded: Date = .now,
        purchasePrice: Money? = nil
    ) {
        self.id = id
        self.card = card
        self.quantity = quantity
        self.condition = condition
        self.dateAdded = dateAdded
        self.purchasePrice = purchasePrice
    }

    /// Current estimated value: market price × quantity.
    var estimatedValue: Money {
        let unit = card.marketPrice?.amount ?? 0
        return Money(amount: unit * Decimal(quantity))
    }
}
