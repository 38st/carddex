import Foundation

/// A currency amount. Uses `Decimal` so money math stays exact.
struct Money: Codable, Hashable, Sendable {
    var amount: Decimal
    var currencyCode: String

    init(amount: Decimal, currencyCode: String = "USD") {
        self.amount = amount
        self.currencyCode = currencyCode
    }

    var formatted: String {
        amount.formatted(.currency(code: currencyCode))
    }

    static let zero = Money(amount: 0)

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(amount: lhs.amount + rhs.amount, currencyCode: lhs.currencyCode)
    }
}
