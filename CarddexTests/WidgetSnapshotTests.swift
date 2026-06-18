import Testing
import Foundation
@testable import Carddex

@Suite struct WidgetSnapshotTests {
    @Test func placeholderHasSaneDefaults() {
        let p = WidgetSnapshot.placeholder
        #expect(p.indexValue == 1284.50)
        #expect(p.indexChange == 3.1)
        #expect(p.gainUp == true)
        #expect(p.topMoverName == "Tom Brady RC")
        #expect(p.topMoverChange == 11.2)
        #expect(p.updatedAt == Date(timeIntervalSince1970: 0))
        #expect(!p.indexSeries.isEmpty)
    }

    @Test func codableRoundTripsAllFields() throws {
        let now = Date()
        let original = WidgetSnapshot(
            indexValue: 1500.25,
            indexChange: -2.4,
            indexSeries: [1500, 1490, 1488, 1500.25],
            portfolioValue: "$12,345.67",
            portfolioGain: "-$300 (2%)",
            gainUp: false,
            topMoverName: "Lionel Messi",
            topMoverChange: -5.5,
            updatedAt: now
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.indexValue == original.indexValue)
        #expect(decoded.indexChange == original.indexChange)
        #expect(decoded.indexSeries == original.indexSeries)
        #expect(decoded.portfolioValue == original.portfolioValue)
        #expect(decoded.portfolioGain == original.portfolioGain)
        #expect(decoded.gainUp == original.gainUp)
        #expect(decoded.topMoverName == original.topMoverName)
        #expect(decoded.topMoverChange == original.topMoverChange)
        #expect(decoded.updatedAt == original.updatedAt)
    }

    @Test func codableRoundTripsPlaceholder() throws {
        // The placeholder is what the widget falls back to — ensure it survives.
        let data = try JSONEncoder().encode(WidgetSnapshot.placeholder)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.indexValue == WidgetSnapshot.placeholder.indexValue)
        #expect(decoded.topMoverName == WidgetSnapshot.placeholder.topMoverName)
        #expect(decoded.indexSeries == WidgetSnapshot.placeholder.indexSeries)
    }
}
