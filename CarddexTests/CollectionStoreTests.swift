import Testing
import Foundation
@testable import Carddex

@MainActor
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

    // MARK: - Condition (#4)

    @Test func conditionMultipliersDiscountValue() {
        #expect(CardCondition.mint.multiplier == 1.0)
        #expect(CardCondition.nearMint.multiplier == 0.9)
        #expect(CardCondition.damaged.multiplier == 0.3)
    }

    @Test func conditionAdjustedValueAppliesMultiplier() {
        // Charizard market = 320.
        let mint = CollectionItem(card: SampleData.charizard, condition: .mint)
        #expect(mint.conditionAdjustedValue.amount == 320)
        let lightlyPlayed = CollectionItem(card: SampleData.charizard, condition: .lightlyPlayed)
        #expect(lightlyPlayed.conditionAdjustedValue.amount == 240)   // 320 × 0.75
    }

    @Test func setConditionUpdatesItem() {
        let item = CollectionItem(card: SampleData.charizard, condition: .nearMint)
        let store = CollectionStore(items: [item])
        store.setCondition(.heavilyPlayed, for: item)
        #expect(store.items.first?.condition == .heavilyPlayed)
        #expect(store.items.first?.conditionAdjustedValue.amount == 144)  // 320 × 0.45
    }

    @Test func setConditionNoOpForMissingItem() {
        let store = CollectionStore(items: [CollectionItem(card: SampleData.charizard)])
        let stranger = CollectionItem(card: SampleData.jordan)
        store.setCondition(.damaged, for: stranger)
        #expect(store.items.count == 1)
        #expect(store.items.first?.condition == .nearMint)  // unchanged
    }
}
