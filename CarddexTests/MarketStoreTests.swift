import Testing
import Foundation
@testable import Carddex

@MainActor
@Suite struct MarketStoreTests {
    @Test func refreshIsNoOpWithoutService() async {
        let store = MarketStore(service: nil)
        let before = store.index.value
        await store.refresh()
        #expect(store.index.value == before)
        #expect(!store.isLive)
    }

    @Test func refreshUpdatesIndexFromServicePoints() async {
        let points = [
            IndexPointDTO(asOf: "2026-01-01T00:00:00Z", value: 100),
            IndexPointDTO(asOf: "2026-01-02T00:00:00Z", value: 110),
        ]
        let store = MarketStore(service: FakeMarketService(indexPoints: points))
        await store.refresh()
        #expect(store.isLive)
        // buildIndex takes values.last as the current value.
        #expect(store.index.value == 110)
        // changeToday is (last - prev) / prev * 100 = 10%.
        #expect(store.index.changeToday == 10)
    }

    @Test func refreshIgnoresEmptyIndexPoints() async {
        let store = MarketStore(service: FakeMarketService(indexPoints: []))
        let before = store.index.value
        await store.refresh()
        #expect(!store.isLive)
        #expect(store.index.value == before)
    }

    @Test func refreshReplacesCardMarketFromService() async {
        let id = SampleData.jordan.id
        let bundle = CardBundleDTO(
            cardId: id,
            gradedPrices: [CardBundleDTO.Graded(grade: "PSA 10", price: 99_999)],
            population: 500,
            change30d: 42.0,
            recentSales: []
        )
        let store = MarketStore(service: FakeMarketService(cards: [id: bundle]))
        await store.refresh()
        let market = store.market[id]
        #expect(market?.change30d == 42.0)
        #expect(market?.population == 500)
        #expect(market?.gradedPrices.first?.price.amount == 99_999)
        #expect(market?.gradedPrices.first?.grade == "PSA 10")
    }

    @Test func refreshKeepsSampleWhenCardFetchFails() async {
        let id = SampleData.jordan.id
        let bundle = CardBundleDTO(
            cardId: id,
            gradedPrices: [],
            population: 0,
            change30d: 42.0,
            recentSales: []
        )
        let store = MarketStore(service: FakeMarketService(cards: [id: bundle], failingCardIDs: [id]))
        let sampleChange = store.market[id]?.change30d
        await store.refresh()
        // Fetch threw → the entry is left untouched (still the bundled sample).
        #expect(store.market[id]?.change30d == sampleChange)
    }

    @Test func buildMarketMapsGradesSalesAndPopulation() {
        let bundle = CardBundleDTO(
            cardId: "c1",
            gradedPrices: [
                CardBundleDTO.Graded(grade: "PSA 10", price: 5000),
                CardBundleDTO.Graded(grade: "Raw", price: 300),
            ],
            population: 1234,
            change30d: 3.5,
            recentSales: [CardBundleDTO.SaleDTO(grade: "PSA 9", price: 1600, currency: "USD",
                                                platform: "eBay", soldAt: "2026-01-15T00:00:00Z")]
        )
        let market = MarketStore.buildMarket(from: bundle)
        #expect(market.cardId == "c1")
        #expect(market.change30d == 3.5)
        #expect(market.population == 1234)
        #expect(market.gradedPrices.count == 2)
        #expect(market.recentSales.count == 1)
        #expect(market.recentSales.first?.price.amount == 1600)
        #expect(market.recentSales.first?.grade == "PSA 9")
        #expect(market.recentSales.first?.platform == "eBay")
    }

    @Test func buildIndexFallsBackToSampleForEmptyPoints() {
        let index = MarketStore.buildIndex(from: [])
        #expect(index.value == SampleData.marketIndex.value)
    }

    @Test func indexChangeAcrossRangeIsFirstToLast() {
        // A category index whose members all move over the month should report a
        // change equal to first→last of the averaged series.
        let ids = [SampleData.jordan.id, SampleData.lebron.id]
        let store = MarketStore(service: nil)
        let change = store.indexChange(ids, range: .month)
        let series = store.indexSeries(ids, range: .month)
        let expected: Double
        if let first = series.first, let last = series.last, first != 0 {
            expected = (last - first) / first * 100
        } else {
            expected = 0
        }
        #expect(change.isFinite)
        #expect(abs(change - expected) < 0.0001)
    }
}
