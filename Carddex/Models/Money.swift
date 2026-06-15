import Foundation

/// A currency amount. Uses `Decimal` so money math stays exact. Decodes `amount`
/// from either a JSON number or string (the backend sends strings for exactness).
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

    enum CodingKeys: String, CodingKey { case amount, currencyCode }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let string = try? container.decode(String.self, forKey: .amount),
           let decimal = Decimal(string: string) {
            amount = decimal
        } else {
            amount = try container.decode(Decimal.self, forKey: .amount)
        }
        currencyCode = (try? container.decode(String.self, forKey: .currencyCode)) ?? "USD"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("\(amount)", forKey: .amount)
        try container.encode(currencyCode, forKey: .currencyCode)
    }
}
