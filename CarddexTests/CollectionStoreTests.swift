import Testing
import Foundation
@testable import Carddex

@Suite struct CollectionStoreTests {
    @Test func addingStacksQuantity() {
        let store = CollectionStore(items: [])
        store.add(SampleData.charizard)
        store.add(SampleData.charizard)
        #expect(store.items.count == 1)
        #expect(store.totalCards == 2)
        #expect(store.items.first?.quantity == 2)
    }

    @Test func loggingABuyRecordsCostBasis() {
        // Charizard market = 320; logged a buy of 2 @ 200 each.
        let store = CollectionStore(items: [])
        store.add(SampleData.charizard, purchasePrice: Money(amount: 200), quantity: 2)
        #expect(store.totalCards == 2)
        #expect(store.totalCost.amount == 400)
        #expect(store.totalValue.amount == 640)
        #expect(store.totalGainLoss.amount == 240)
    }

    @Test func gainLossFromCostBasis() {
        // Charizard market = 320; paid 200 → +120.
        let item = CollectionItem(card: SampleData.charizard, purchasePrice: Money(amount: 200))
        #expect(item.gainLoss.amount == 120)
        #expect(item.hasCostBasis)
    }

    @Test func setCompletionCountsOwnedSlots() {
        let store = CollectionStore(items: SampleData.collection)
        let progress = store.completion(for: SampleData.baseSet)
        #expect(progress.owned == 7)
        #expect(progress.total == 10)
    }

    @Test func rarityMapsToFoilTier() {
        #expect(Rarity.tier(rarityText: "Common", price: Money(amount: 5)) == .none)
        #expect(Rarity.tier(rarityText: "Holo Rare", price: Money(amount: 320)) == .rare)
        #expect(Rarity.tier(rarityText: nil, price: Money(amount: 600)) == .mythic)
    }

    @Test func portfolioGainIsValueMinusCost() {
        let store = CollectionStore(items: [
            CollectionItem(card: SampleData.charizard, purchasePrice: Money(amount: 200)),
        ])
        #expect(store.totalValue.amount == 320)
        #expect(store.totalCost.amount == 200)
        #expect(store.totalGainLoss.amount == 120)
    }
}
