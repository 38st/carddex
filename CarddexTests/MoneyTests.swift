import Testing
import Foundation
@testable import Carddex

@Suite struct MoneyTests {
    @Test func zeroIsZeroAmount() {
        #expect(Money.zero.amount == 0)
        #expect(Money.zero.currencyCode == "USD")
    }

    @Test func additionCombinesAmounts() {
        #expect((Money(amount: 100) + Money(amount: 200)).amount == 300)
        #expect((Money(amount: -50) + Money(amount: 50)).amount == 0)
    }

    @Test func compactFormattedAbbreviatesThousands() {
        #expect(Money(amount: 30_500).compactFormatted == "$30.5K")
    }

    @Test func compactFormattedAbbreviatesMillions() {
        #expect(Money(amount: 1_600_000).compactFormatted == "$1.6M")
    }

    @Test func compactFormattedAbbreviatesBillions() {
        #expect(Money(amount: 2_300_000_000).compactFormatted == "$2.3B")
    }

    @Test func compactFormattedPrefixesNegativeSign() {
        #expect(Money(amount: -30_500).compactFormatted == "-$30.5K")
    }

    @Test func codableRoundTripsExactAmount() throws {
        let original = Money(amount: 123.45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Money.self, from: data)
        #expect(decoded.amount == original.amount)
        #expect(decoded.currencyCode == "USD")
    }

    @Test func codableDecodesAmountFromString() throws {
        // The backend sends `amount` as a string for exactness.
        let json = #"{"amount":"320","currencyCode":"USD"}"#.data(using: .utf8)!
        let money = try JSONDecoder().decode(Money.self, from: json)
        #expect(money.amount == 320)
    }

    @Test func codableDecodesAmountFromNumber() throws {
        // And tolerates a JSON number for forward-compat.
        let json = #"{"amount":320,"currencyCode":"USD"}"#.data(using: .utf8)!
        let money = try JSONDecoder().decode(Money.self, from: json)
        #expect(money.amount == 320)
    }

    @Test func codableDefaultsCurrencyCodeToUSD() throws {
        let json = #"{"amount":"10"}"#.data(using: .utf8)!
        let money = try JSONDecoder().decode(Money.self, from: json)
        #expect(money.currencyCode == "USD")
    }
}
