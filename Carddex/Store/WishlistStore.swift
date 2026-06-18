import SwiftUI

/// The "Grail List" — cards the user is hunting but doesn't own yet, optionally
/// with a target price ("ping me when a PSA 9 Charizard drops below $1,200").
/// Distinct from `WatchlistStore` (which follows market cards the user may
/// already own) and `CollectionStore` (owned). In-memory for now; persists to
/// Supabase (`wishlists`) at go-live.
@Observable
final class WishlistStore {
    var grails: [GrailEntry]
    private let persistKey: String?
    var sync: (any SyncServiceProtocol)? = nil

    /// `persistKey` enables Codable-to-disk persistence (production). Pass nil for
    /// previews/tests to stay purely in-memory. `sync` mirrors mutations to
    /// Supabase; nil = local-only.
    init(grails: [GrailEntry] = [], persistKey: String? = nil, sync: (any SyncServiceProtocol)? = nil) {
        self.persistKey = persistKey
        self.sync = sync
        if let persistKey, let saved = Disk.load([GrailEntry].self, from: persistKey) {
            self.grails = saved
        } else {
            self.grails = grails
            persist()
        }
    }

    private func persist() {
        if let persistKey { Disk.save(grails, to: persistKey) }
    }

    private func syncUpsert(_ entry: GrailEntry) {
        guard let sync else { return }
        Task { try? await sync.upsertWishlistEntry(entry) }
    }

    private func syncDelete(_ cardID: String) {
        guard let sync else { return }
        Task { try? await sync.deleteWishlistEntry(cardID: cardID) }
    }

    func contains(_ cardID: String) -> Bool { grails.contains { $0.cardID == cardID } }

    /// Add a card to the grail list. Replaces any existing entry for the same card
    /// (so re-adding updates the target/note rather than duplicating).
    func add(cardID: String, target: Money? = nil, note: String? = nil) {
        grails.removeAll { $0.cardID == cardID }
        let entry = GrailEntry(cardID: cardID, target: target, note: note)
        grails.append(entry)
        syncUpsert(entry)
        persist()
    }

    func remove(_ cardID: String) {
        grails.removeAll { $0.cardID == cardID }
        syncDelete(cardID)
        persist()
    }

    /// Update just the target on an existing entry (no-op if the card isn't a grail).
    func setTarget(_ cardID: String, target: Money?) {
        guard let index = grails.firstIndex(where: { $0.cardID == cardID }) else { return }
        grails[index].target = target
        syncUpsert(grails[index])
        persist()
    }

    /// Merge remote grails from a pull. Additive: entries for cards not already
    /// tracked locally are appended.
    func mergeRemote(_ remote: [GrailEntry]) {
        let localCardIDs = Set(grails.map(\.cardID))
        for entry in remote where !localCardIDs.contains(entry.cardID) {
            grails.append(entry)
        }
        persist()
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
