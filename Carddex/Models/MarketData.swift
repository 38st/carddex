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

/// Selectable time horizons for index and price charts (Card Ladder-style).
enum IndexRange: String, CaseIterable, Identifiable, Sendable {
    case week = "1W", month = "1M", quarter = "3M", year = "1Y", all = "All"
    var id: String { rawValue }
}

/// The overall market index (the "Case Index"), with a series per time range.
struct MarketIndex: Sendable {
    let value: Double                          // current index value
    let changeToday: Double                    // percent change today (intraday)
    let seriesByRange: [IndexRange: [Double]]  // index values per range, oldest → newest

    func series(for range: IndexRange) -> [Double] { seriesByRange[range] ?? [] }

    /// Percent change across the selected range (first → last).
    func change(for range: IndexRange) -> Double {
        let s = series(for: range)
        guard let first = s.first, let last = s.last, first != 0 else { return 0 }
        return (last - first) / first * 100
    }
}
