import SwiftUI
import Observation

/// In-memory collection state. Phase 1 swaps the backing store for Supabase
/// (sync + persistence) but keeps this same surface so views don't change.
@Observable
final class CollectionStore {
    var items: [CollectionItem]
    private let persistKey: String?
    /// Set post-init by the app composition root so stores created without a
    /// backend (previews/tests) stay local-only, while production wires sync
    /// once `AppEnvironment` is available.
    var sync: (any SyncServiceProtocol)? = nil

    /// `persistKey` enables Codable-to-disk persistence (production). Pass nil for
    /// previews/tests to stay purely in-memory. `sync` (when present) mirrors
    /// mutations to Supabase; nil = local-only.
    init(items: [CollectionItem] = [], persistKey: String? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistKey = persistKey
        self.sync = sync
        if let persistKey, let saved = Disk.load([CollectionItem].self, from: persistKey) {
            self.items = saved
        } else {
            self.items = items
            persist()
        }
    }

    private func persist() {
        if let persistKey { Disk.save(items, to: persistKey) }
    }

    /// Fire-and-forget a sync upsert. Best-effort: failures are swallowed (the
    /// local store stays correct; a later pull will reconcile).
    private func syncUpsert(_ item: CollectionItem) {
        guard let sync else { return }
        Task { try? await sync.upsertCollectionItem(item) }
    }

    private func syncDelete(_ id: UUID) {
        guard let sync else { return }
        Task { try? await sync.deleteCollectionItem(id: id) }
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

    /// Gain/loss contributed by a game (value minus cost basis).
    func gainLoss(for game: CardGame) -> Money {
        items
            .filter { $0.card.game == game }
            .reduce(Money.zero) { Money(amount: $0.amount + $1.gainLoss.amount) }
    }

    func items(for game: CardGame?) -> [CollectionItem] {
        guard let game else { return items }
        return items.filter { $0.card.game == game }
    }

    /// Add a scanned/identified card, stacking quantity if already owned.
    func add(_ card: Card) {
        if let index = items.firstIndex(where: { $0.card.id == card.id }) {
            items[index].quantity += 1
            syncUpsert(items[index])
        } else {
            let item = CollectionItem(card: card)
            items.append(item)
            syncUpsert(item)
        }
        persist()
    }

    /// Log a buy with a cost basis. Stacks onto an existing holding, filling in a
    /// cost basis if it didn't have one yet.
    func add(_ card: Card, purchasePrice: Money?, quantity: Int = 1) {
        if let index = items.firstIndex(where: { $0.card.id == card.id }) {
            items[index].quantity += quantity
            if items[index].purchasePrice == nil { items[index].purchasePrice = purchasePrice }
            syncUpsert(items[index])
        } else {
            let item = CollectionItem(card: card, quantity: quantity, purchasePrice: purchasePrice)
            items.append(item)
            syncUpsert(item)
        }
        persist()
    }

    func remove(_ item: CollectionItem) {
        items.removeAll { $0.id == item.id }
        syncDelete(item.id)
        persist()
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

    /// Merge remote items from a pull. Additive: remote items whose id isn't
    /// already local are appended. Existing local items keep their state (they
    /// may have unsynced changes). A proper LWW merge needs `updated_at` (Phase 2).
    func mergeRemote(_ remote: [CollectionItem]) {
        let localIDs = Set(items.map(\.id))
        for item in remote where !localIDs.contains(item.id) {
            items.append(item)
        }
        persist()
    }
}
