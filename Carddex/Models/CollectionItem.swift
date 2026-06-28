import Foundation

/// One owned card (or stack of copies) in the user's collection.
struct CollectionItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var card: Card
    var quantity: Int
    var condition: CardCondition
    var dateAdded: Date
    var purchasePrice: Money?
    var certNumber: String?
    var gradingCompany: String?

    init(
        id: UUID = UUID(),
        card: Card,
        quantity: Int = 1,
        condition: CardCondition = .nearMint,
        dateAdded: Date = .now,
        purchasePrice: Money? = nil,
        certNumber: String? = nil,
        gradingCompany: String? = nil
    ) {
        self.id = id
        self.card = card
        self.quantity = quantity
        self.condition = condition
        self.dateAdded = dateAdded
        self.purchasePrice = purchasePrice
        self.certNumber = certNumber
        self.gradingCompany = gradingCompany
    }

    /// Current estimated value: market price × quantity.
    var estimatedValue: Money {
        let unit = card.marketPrice?.amount ?? 0
        return Money(amount: unit * Decimal(quantity))
    }

    var hasCostBasis: Bool { purchasePrice != nil }

    /// What the user paid: purchase price × quantity.
    var costBasis: Money {
        Money(amount: (purchasePrice?.amount ?? 0) * Decimal(quantity))
    }

    /// Current value minus cost basis.
    var gainLoss: Money {
        Money(amount: estimatedValue.amount - costBasis.amount)
    }

    /// Gain/loss as a percentage of cost basis, when there is one.
    var gainPercent: Double? {
        guard hasCostBasis, costBasis.amount > 0 else { return nil }
        return NSDecimalNumber(decimal: gainLoss.amount).doubleValue
            / NSDecimalNumber(decimal: costBasis.amount).doubleValue * 100
    }
}
