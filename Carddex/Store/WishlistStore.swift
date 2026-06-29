import SwiftUI
import Observation
import SwiftData

/// The "Grail List" — cards the user is hunting but doesn't own yet, optionally
/// with a target price ("ping me when a PSA 9 Charizard drops below $1,200").
/// Distinct from `WatchlistStore` (which follows market cards the user may
/// already own) and `CollectionStore` (owned). Backed by SwiftData; keeps the
/// same in-memory surface views use.
@MainActor
@Observable
final class WishlistStore {
    var grails: [GrailEntry]
    private let persistence: PersistenceController?
    var sync: (any SyncServiceProtocol)? = nil

    /// `persistence` enables SwiftData-backed persistence (production). Pass
    /// nil for previews/tests to stay purely in-memory.
    init(grails: [GrailEntry] = [], persistence: PersistenceController? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistence = persistence
        self.sync = sync
        if let persistence {
            self.grails = Self.fetchLive(from: persistence.context)
        } else {
            self.grails = grails
        }
    }

    private static func fetchLive(from context: ModelContext) -> [GrailEntry] {
        let descriptor = FetchDescriptor<GrailEntryEntity>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        return entities.compactMap { $0.toModel() }
    }

    private func save() { persistence?.save() }

    /// Reload the in-memory array from SwiftData. Called after a SyncEngine cycle.
    func refresh() {
        guard let persistence else { return }
        grails = Self.fetchLive(from: persistence.context)
    }

    // Sync push is owned by the SyncEngine; stores only mark dirty on mutation.

    func contains(_ cardID: String) -> Bool { grails.contains { $0.cardID == cardID } }

    /// Add a card to the grail list. Replaces any existing entry for the same card
    /// (so re-adding updates the target/note rather than duplicating).
    func add(cardID: String, target: Money? = nil, note: String? = nil) {
        grails.removeAll { $0.cardID == cardID }
        let entry = GrailEntry(cardID: cardID, target: target, note: note)
        grails.append(entry)
        upsertEntity(entry)
        save()
    }

    func remove(_ cardID: String) {
        grails.removeAll { $0.cardID == cardID }
        if let persistence,
           let entity = try? persistence.context.fetch(FetchDescriptor<GrailEntryEntity>(
               predicate: #Predicate { $0.cardID == cardID }
           )).first {
            entity.deletedAt = .now
            entity.dirty = true
            persistence.save()
        }
    }

    /// Update just the target on an existing entry (no-op if the card isn't a grail).
    func setTarget(_ cardID: String, target: Money?) {
        guard let index = grails.firstIndex(where: { $0.cardID == cardID }) else { return }
        grails[index].target = target
        upsertEntity(grails[index])
        save()
    }

    /// Clear all local state and persist the empty snapshot. Used after a
    /// successful account deletion so a re-launch doesn't restore wiped data.
    func wipeLocal() {
        grails = []
        if let persistence {
            let all = (try? persistence.context.fetch(FetchDescriptor<GrailEntryEntity>())) ?? []
            for entity in all { persistence.context.delete(entity) }
            persistence.save()
        }
    }

    private func upsertEntity(_ entry: GrailEntry, dirty: Bool = true) {
        guard let persistence else { return }
        let ctx = persistence.context
        let existing = (try? ctx.fetch(FetchDescriptor<GrailEntryEntity>(
            predicate: #Predicate { $0.cardID == entry.cardID }
        )))?.first
        if let existing {
            existing.targetAmount = entry.target.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
            existing.targetCurrency = entry.target?.currencyCode
            existing.note = entry.note
            existing.dateAdded = entry.dateAdded
            existing.dirty = dirty
            existing.deletedAt = nil
        } else {
            let entity = GrailEntryEntity.insert(from: entry, into: ctx)
            entity.dirty = dirty
        }
    }
}

/// One grail: a card the user wants, with an optional target price and note.
struct GrailEntry: Identifiable, Hashable, Sendable, Codable {
    let cardID: String
    var target: Money?
    var note: String?
    var dateAdded: Date
    var id: String { cardID }

    init(cardID: String, target: Money? = nil, note: String? = nil, dateAdded: Date = .now) {
        self.cardID = cardID
        self.target = target
        self.note = note
        self.dateAdded = dateAdded
    }
}
