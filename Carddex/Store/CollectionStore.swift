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
}
