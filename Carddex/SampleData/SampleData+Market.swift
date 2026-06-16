import Foundation

/// Placeholder market data (Card Ladder-style): a market index, graded values,
/// and recent sales. Replaced by real sales/price feeds in production.
extension SampleData {
    static let marketIndex = MarketIndex(
        value: 1284.50,
        changeToday: 2.4,
        seriesByRange: [
            .week: [1255, 1262, 1258, 1268, 1275, 1280, 1284.5],
            .month: [1180, 1195, 1188, 1210, 1225, 1218, 1240, 1255, 1262, 1271, 1284.5],
            .quarter: [1050, 1080, 1110, 1095, 1140, 1175, 1200, 1230, 1255, 1271, 1284.5],
            .year: [820, 870, 910, 960, 1005, 1060, 1100, 1150, 1200, 1250, 1284.5],
            .all: [400, 520, 640, 720, 810, 905, 1010, 1120, 1200, 1284.5],
        ]
    )

    private static func daysAgo(_ d: Int) -> Date { Date.now.addingTimeInterval(-Double(d) * 86400) }

    /// Market-tracked cards, sports first.
    static let marketCards: [Card] = [jordan, lebron, brady, trout, messi, gretzky, charizard, blueEyes]

    /// Per-category sub-indices (Card Ladder-style), sports first.
    static let categoryIndices: [MarketIndexEntry] = [
        MarketIndexEntry(id: "idx-basketball", name: "Basketball", symbolName: "basketball.fill", memberIDs: [jordan.id, lebron.id], accentHex: 0xEE6730),
        MarketIndexEntry(id: "idx-football", name: "Football", symbolName: "football.fill", memberIDs: [brady.id], accentHex: 0x8B5E3C),
        MarketIndexEntry(id: "idx-baseball", name: "Baseball", symbolName: "baseball.fill", memberIDs: [trout.id], accentHex: 0xC8102E),
        MarketIndexEntry(id: "idx-soccer", name: "Soccer", symbolName: "soccerball", memberIDs: [messi.id], accentHex: 0x2FAE60),
        MarketIndexEntry(id: "idx-hockey", name: "Hockey", symbolName: "hockey.puck.fill", memberIDs: [gretzky.id], accentHex: 0x4AA3DF),
        MarketIndexEntry(id: "idx-pokemon", name: "Pokémon", symbolName: "bolt.fill", memberIDs: [charizard.id], accentHex: 0xFFD23F),
    ]

    /// Element-wise average of member price series (normalized 0…1).
    static func indexSeries(_ memberIDs: [String]) -> [Double] {
        let lists = memberIDs.compactMap { market[$0]?.priceSeries }
        guard let first = lists.first else { return [] }
        return (0..<first.count).map { i in
            lists.map { $0[i] }.reduce(0, +) / Double(lists.count)
        }
    }

    /// Average 30-day change of an index's members.
    static func indexChange(_ memberIDs: [String]) -> Double {
        let changes = memberIDs.compactMap { market[$0]?.change30d }
        return changes.isEmpty ? 0 : changes.reduce(0, +) / Double(changes.count)
    }

    static func indexMembers(_ memberIDs: [String]) -> [Card] {
        marketCards.filter { memberIDs.contains($0.id) }
    }

    static let market: [String: CardMarket] = [
        jordan.id: CardMarket(
            cardId: jordan.id, change30d: 6.8,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 95000)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 12000)),
                GradedPrice(grade: "Raw", price: Money(amount: 1800)),
            ],
            recentSales: [
                Sale(price: Money(amount: 12250), date: daysAgo(2), grade: "PSA 9", platform: "eBay"),
                Sale(price: Money(amount: 11800), date: daysAgo(6), grade: "PSA 9", platform: "Goldin"),
                Sale(price: Money(amount: 1750), date: daysAgo(9), grade: "Raw", platform: "eBay"),
            ],
            priceSeries: [0.82, 0.85, 0.83, 0.88, 0.9, 0.92, 0.95, 0.97, 1.0],
            population: 320
        ),
        lebron.id: CardMarket(
            cardId: lebron.id, change30d: -3.1,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 28000)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 3500)),
                GradedPrice(grade: "Raw", price: Money(amount: 650)),
            ],
            recentSales: [
                Sale(price: Money(amount: 3450), date: daysAgo(1), grade: "PSA 9", platform: "eBay"),
                Sale(price: Money(amount: 27500), date: daysAgo(8), grade: "PSA 10", platform: "PWCC"),
            ],
            priceSeries: [1.0, 0.99, 1.01, 0.98, 0.96, 0.97, 0.95, 0.96, 0.97],
            population: 1840
        ),
        brady.id: CardMarket(
            cardId: brady.id, change30d: 11.2,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 52000)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 2800)),
                GradedPrice(grade: "Raw", price: Money(amount: 900)),
            ],
            recentSales: [
                Sale(price: Money(amount: 2900), date: daysAgo(3), grade: "PSA 9", platform: "eBay"),
                Sale(price: Money(amount: 850), date: daysAgo(5), grade: "Raw", platform: "eBay"),
            ],
            priceSeries: [0.78, 0.8, 0.82, 0.85, 0.84, 0.9, 0.93, 0.96, 1.0],
            population: 760
        ),
        trout.id: CardMarket(
            cardId: trout.id, change30d: -1.4,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 4200)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 900)),
                GradedPrice(grade: "Raw", price: Money(amount: 220)),
            ],
            recentSales: [
                Sale(price: Money(amount: 910), date: daysAgo(2), grade: "PSA 9", platform: "eBay"),
            ],
            priceSeries: [1.0, 0.99, 0.98, 0.99, 0.97, 0.98, 0.99, 0.98, 0.99],
            population: 5400
        ),
        messi.id: CardMarket(
            cardId: messi.id, change30d: 8.5,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 18000)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 1200)),
                GradedPrice(grade: "Raw", price: Money(amount: 300)),
            ],
            recentSales: [
                Sale(price: Money(amount: 1250), date: daysAgo(4), grade: "PSA 9", platform: "eBay"),
            ],
            priceSeries: [0.8, 0.84, 0.86, 0.85, 0.9, 0.92, 0.95, 0.98, 1.0],
            population: 410
        ),
        gretzky.id: CardMarket(
            cardId: gretzky.id, change30d: 2.2,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 1600000)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 5000)),
                GradedPrice(grade: "Raw", price: Money(amount: 900)),
            ],
            recentSales: [
                Sale(price: Money(amount: 4950), date: daysAgo(7), grade: "PSA 9", platform: "Heritage"),
            ],
            priceSeries: [0.94, 0.95, 0.96, 0.95, 0.97, 0.98, 0.99, 0.99, 1.0],
            population: 2300
        ),
        charizard.id: CardMarket(
            cardId: charizard.id, change30d: 4.1,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 12000)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 1600)),
                GradedPrice(grade: "Raw", price: Money(amount: 320)),
            ],
            recentSales: [
                Sale(price: Money(amount: 1650), date: daysAgo(1), grade: "PSA 9", platform: "eBay"),
                Sale(price: Money(amount: 320), date: daysAgo(4), grade: "Raw", platform: "TCGplayer"),
            ],
            priceSeries: [0.86, 0.88, 0.87, 0.9, 0.92, 0.93, 0.96, 0.98, 1.0],
            population: 9100
        ),
        blueEyes.id: CardMarket(
            cardId: blueEyes.id, change30d: 1.1,
            gradedPrices: [
                GradedPrice(grade: "PSA 10", price: Money(amount: 6500)),
                GradedPrice(grade: "PSA 9", price: Money(amount: 600)),
                GradedPrice(grade: "Raw", price: Money(amount: 90)),
            ],
            recentSales: [
                Sale(price: Money(amount: 610), date: daysAgo(5), grade: "PSA 9", platform: "eBay"),
            ],
            priceSeries: [0.96, 0.97, 0.98, 0.97, 0.99, 0.98, 0.99, 1.0, 1.0],
            population: 3200
        ),
    ]
}
