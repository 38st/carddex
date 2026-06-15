import Foundation

/// One slot in a set's checklist.
struct SetSlot: Identifiable, Hashable, Sendable {
    let number: String      // collector number, e.g. "4/102"
    let name: String
    var rarity: String? = nil
    var id: String { number }
}

/// A card set, for completion tracking — the "Pokédex" view.
struct CardSet: Identifiable, Hashable, Sendable {
    let id: String
    let game: CardGame
    let name: String
    let total: Int          // full printed set size (real catalogs supply this)
    let slots: [SetSlot]    // the checklist shown in the binder
}
