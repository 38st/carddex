import SwiftUI
import Observation

/// In-memory collection state. Phase 1 swaps the backing store for Supabase
/// (sync + persistence) but keeps this same surface so views don't change.
@Observable
final class CollectionStore {
    var items: [CollectionItem]

    init(items: [CollectionItem] = []) {
        self.items = items
    }

    var totalValue: Money {
        items.reduce(Money.zero) { $0 + $1.estimatedValue }
    }

    var totalCards: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var totalCost: Money {
        items.reduce(Money.zero) { $0 + $1.costBasis }
    }

    var totalGainLoss: Money {
        Money(amount: totalValue.amount - totalCost.amount)
    }

    var gainLossPercent: Double {
        let cost = NSDecimalNumber(decimal: totalCost.amount).doubleValue
        guard cost > 0 else { return 0 }
        return NSDecimalNumber(decimal: totalGainLoss.amount).doubleValue / cost * 100
    }

    /// Most valuable holdings first.
    var topHoldings: [CollectionItem] {
        items.sorted { $0.estimatedValue.amount > $1.estimatedValue.amount }
    }

    /// Biggest absolute gain/loss first (only items with a cost basis).
    var movers: [CollectionItem] {
        items.filter(\.hasCostBasis).sorted { abs($0.gainLoss.amount) > abs($1.gainLoss.amount) }
    }

    func value(for game: CardGame) -> Money {
        items
            .filter { $0.card.game == game }
            .reduce(Money.zero) { $0 + $1.estimatedValue }
    }

    func items(for game: CardGame?) -> [CollectionItem] {
        guard let game else { return items }
        return items.filter { $0.card.game == game }
    }

    /// Add a scanned/identified card, stacking quantity if already owned.
    func add(_ card: Card) {
        if let index = items.firstIndex(where: { $0.card.id == card.id }) {
            items[index].quantity += 1
        } else {
            items.append(CollectionItem(card: card))
        }
    }

    func remove(_ item: CollectionItem) {
        items.removeAll { $0.id == item.id }
    }

    /// The owned card filling a given set slot, if any.
    func ownedCard(setName: String, number: String) -> Card? {
        items.first { $0.card.setName == setName && $0.card.number == number }?.card
    }

    /// How many checklist slots in a set the user owns.
    func completion(for set: CardSet) -> (owned: Int, total: Int) {
        let owned = set.slots.filter { ownedCard(setName: set.name, number: $0.number) != nil }.count
        return (owned, set.slots.count)
    }
}
