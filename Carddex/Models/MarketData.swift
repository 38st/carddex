import Foundation

/// A completed sale — the raw data behind a card's value (Card Ladder-style).
struct Sale: Identifiable, Hashable, Sendable {
    let id: UUID
    let price: Money
    let date: Date
    let grade: String       // "PSA 10", "PSA 9", "Raw", …
    let platform: String    // "eBay", "Goldin", "PWCC", …

    init(price: Money, date: Date, grade: String, platform: String) {
        self.id = UUID()
        self.price = price
        self.date = date
        self.grade = grade
        self.platform = platform
    }
}

/// A card's value at a specific grade.
struct GradedPrice: Identifiable, Hashable, Sendable {
    let grade: String       // "PSA 10", "PSA 9", "Raw"
    let price: Money
    var id: String { grade }
}

/// Market data for a single card: graded values, recent sales, trend, population.
struct CardMarket: Identifiable, Sendable {
    let cardId: String
    let change30d: Double            // percent change over 30 days
    let gradedPrices: [GradedPrice]  // highest grade first
    let recentSales: [Sale]
    let priceSeries: [Double]        // normalized 0…1, scaled to the top graded price
    let population: Int

    var id: String { cardId }
    var topPrice: Money { gradedPrices.first?.price ?? .zero }
}

/// The overall market index (the "Carddex Index").
struct MarketIndex: Sendable {
    let value: Double
    let changeToday: Double          // percent
    let series: [Double]             // recent index values
}
