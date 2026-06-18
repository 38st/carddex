import Foundation
import Observation

/// Holds market data the UI reads (per-card markets + the overall index).
/// Seeded from `SampleData` for an instant first paint, then refreshed from the
/// backend when a `MarketService` is provided. Falls back silently when offline.
@Observable
final class MarketStore {
    var market: [String: CardMarket]
    var index: MarketIndex
    private(set) var isLive = false

    private let service: (any MarketServiceProtocol)?

    init(service: (any MarketServiceProtocol)? = nil) {
        self.market = SampleData.market
        self.index = SampleData.marketIndex
        self.service = service
    }

    @MainActor
    func refresh() async {
        guard let service else { return }

        if let points = try? await service.fetchIndex(category: nil), !points.isEmpty {
            index = Self.buildIndex(from: points)
            isLive = true
        }

        await withTaskGroup(of: (String, CardMarket?).self) { group in
            for id in SampleData.marketCards.map(\.id) {
                group.addTask {
                    let bundle = try? await service.fetchCard(id: id)
                    return (id, bundle.map(Self.buildMarket))
                }
            }
            for await (id, cardMarket) in group {
                if let cardMarket { market[id] = cardMarket }
            }
        }
    }

    /// Live per-category index series — averages members' change-derived series
    /// using the store's (backend) `change30d`, not the bundled sample.
    func indexSeries(_ memberIDs: [String], range: IndexRange) -> [Double] {
        let lists = memberIDs.compactMap { id -> [Double]? in
            guard let m = market[id] else { return nil }
            return SampleData.priceSeries(change30d: m.change30d, range: range, seed: id)
        }
        guard let first = lists.first else { return [] }
        return (0..<first.count).map { i in
            lists.map { $0[i] }.reduce(0, +) / Double(lists.count)
        }
    }

    func indexChange(_ memberIDs: [String], range: IndexRange) -> Double {
        let s = indexSeries(memberIDs, range: range)
        guard let first = s.first, let last = s.last, first != 0 else { return 0 }
        return (last - first) / first * 100
    }

    // MARK: - DTO → domain

    static func buildIndex(from points: [IndexPointDTO]) -> MarketIndex {
        let values = points.map(\.value)
        guard let current = values.last else { return SampleData.marketIndex }
        let changeToday = values.count >= 2 && values[values.count - 2] != 0
            ? (current - values[values.count - 2]) / values[values.count - 2] * 100
            : 0
        func tail(_ n: Int) -> [Double] { sampled(Array(values.suffix(n))) }
        let byRange: [IndexRange: [Double]] = [
            .week: tail(7),
            .month: tail(30),
            .quarter: tail(90),
            .year: tail(365),
            .all: sampled(values),
        ]
        return MarketIndex(value: current, changeToday: changeToday, seriesByRange: byRange)
    }

    /// Downsample a series to keep charts smooth without dropping the endpoints.
    private static func sampled(_ arr: [Double], to count: Int = 28) -> [Double] {
        guard arr.count > count else { return arr }
        let step = Double(arr.count - 1) / Double(count - 1)
        return (0..<count).map { arr[Int((Double($0) * step).rounded())] }
    }

    static func buildMarket(from b: CardBundleDTO) -> CardMarket {
        let graded = b.gradedPrices.map { GradedPrice(grade: $0.grade, price: Money(amount: Decimal($0.price))) }
        let sales = b.recentSales.map { dto in
            Sale(price: Money(amount: Decimal(dto.price)),
                 date: parseDate(dto.soldAt) ?? .now,
                 grade: dto.grade,
                 platform: dto.platform)
        }
        return CardMarket(
            cardId: b.cardId,
            change30d: b.change30d,
            gradedPrices: graded,
            recentSales: sales,
            priceSeries: SampleData.priceSeries(change30d: b.change30d, range: .month, seed: b.cardId),
            population: b.population ?? 0
        )
    }

    private static func parseDate(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: s)
    }
}
