import SwiftUI
import Observation
import SwiftData

/// In-memory collection state, backed by SwiftData. Keeps the same surface
/// views depend on (`items`, computed totals, `add`/`remove`); mutations now
/// write through to `CollectionItemEntity` and mark rows dirty for the
/// SyncEngine. Previews/tests pass `persistence: nil` to stay purely
/// in-memory (no SwiftData).
@MainActor
@Observable
final class CollectionStore {
    var items: [CollectionItem]
    private let persistence: PersistenceController?
    /// Set post-init by the app composition root so stores created without a
    /// backend (previews/tests) stay local-only, while production wires sync
    /// once `AppEnvironment` is available.
    var sync: (any SyncServiceProtocol)? = nil

    /// `persistence` enables SwiftData-backed persistence (production). Pass
    /// nil for previews/tests to stay purely in-memory. The legacy
    /// `persistKey`/`items` inits route through the in-memory path.
    init(items: [CollectionItem] = [], persistence: PersistenceController? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistence = persistence
        self.sync = sync
        if let persistence {
            // Load live (non-tombstoned) rows from SwiftData.
            self.items = Self.fetchLive(from: persistence.context)
        } else {
            self.items = items
        }
    }

    // MARK: - SwiftData load

    private static func fetchLive(from context: ModelContext) -> [CollectionItem] {
        var descriptor = FetchDescriptor<CollectionItemEntity>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = []
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.compactMap { $0.toModel() }
    }

    private func reloadFromStore() {
        guard let persistence else { return }
        items = Self.fetchLive(from: persistence.context)
    }

    /// Reload the in-memory array from SwiftData. Called by the app after a
    /// SyncEngine cycle reconciles remote changes into entities.
    func refresh() {
        reloadFromStore()
    }

    private func save() {
        persistence?.save()
    }

    // MARK: - Sync
    // Push is owned by the SyncEngine, which reads dirty entities directly.
    // Stores only mark entities dirty on mutation (see upsertEntity/remove).

    // MARK: - Computed totals (unchanged surface)

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

    // MARK: - Mutations

    /// Add a scanned/identified card, stacking quantity if already owned.
    func add(_ card: Card) {
        if let index = items.firstIndex(where: { $0.card.id == card.id }) {
            items[index].quantity += 1
            upsertEntity(items[index])
        } else {
            let item = CollectionItem(card: card)
            items.append(item)
            upsertEntity(item)
        }
        save()
    }

    /// Log a buy with a cost basis. Stacks onto an existing holding, filling in a
    /// cost basis if it didn't have one yet.
    func add(_ card: Card, purchasePrice: Money?, quantity: Int = 1) {
        if let index = items.firstIndex(where: { $0.card.id == card.id }) {
            items[index].quantity += quantity
            if items[index].purchasePrice == nil { items[index].purchasePrice = purchasePrice }
            upsertEntity(items[index])
        } else {
            let item = CollectionItem(card: card, quantity: quantity, purchasePrice: purchasePrice)
            items.append(item)
            upsertEntity(item)
        }
        save()
    }

    func remove(_ item: CollectionItem) {
        items.removeAll { $0.id == item.id }
        // Soft-delete the entity (tombstone) so the SyncEngine can propagate.
        if let persistence,
           let entity = try? persistence.context.fetch(FetchDescriptor<CollectionItemEntity>(
               predicate: #Predicate { $0.id == item.id }
           )).first {
            entity.deletedAt = .now
            entity.dirty = true
            persistence.save()
        }
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

    // MARK: - Merge

    /// Merge remote items from a pull. Additive: remote items whose id isn't
    /// already local are appended. Existing local items keep their state (they
    /// may have unsynced changes). The LWW variant lands in Slice 3 alongside
    /// the SyncEngine; this keeps first-sync working in the meantime.
    func mergeRemote(_ remote: [CollectionItem]) {
        let localIDs = Set(items.map(\.id))
        for item in remote where !localIDs.contains(item.id) {
            items.append(item)
            upsertEntity(item, dirty: false)
        }
        save()
    }

    /// Clear all local state and persist the empty snapshot. Used after a
    /// successful account deletion so a re-launch doesn't restore wiped data.
    /// Does not sync — the server-side rows are gone via cascade.
    func wipeLocal() {
        items = []
        if let persistence {
            // Hard-delete entities (not tombstones) — the account is gone.
            let all = (try? persistence.context.fetch(FetchDescriptor<CollectionItemEntity>())) ?? []
            for entity in all { persistence.context.delete(entity) }
            persistence.save()
        }
    }

    // MARK: - Entity helpers

    /// Upsert the entity for `item`, marking it dirty (a local mutation).
    private func upsertEntity(_ item: CollectionItem, dirty: Bool = true) {
        guard let persistence else { return }
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<CollectionItemEntity>(
            predicate: #Predicate { $0.id == item.id }
        )))?.first
        if let existing {
            existing.cardData = CollectionItemEntity.encodeCard(item.card)
            existing.quantity = item.quantity
            existing.conditionRaw = item.condition.rawValue
            existing.dateAdded = item.dateAdded
            existing.purchasePriceAmount = item.purchasePrice.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            existing.purchasePriceCurrency = item.purchasePrice?.currencyCode
            existing.certNumber = item.certNumber
            existing.gradingCompany = item.gradingCompany
            existing.dirty = dirty
            existing.deletedAt = nil
        } else {
            let entity = CollectionItemEntity.insert(from: item, into: ctx)
            entity.dirty = dirty
        }
    }
}
