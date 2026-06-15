import Foundation

/// A canonical card from a catalog (Pokémon TCG API, Scryfall, YGOPRODeck, …).
/// `id` is the catalog's stable identifier so we can re-fetch prices and images.
struct Card: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var game: CardGame
    var name: String
    var setName: String
    var number: String          // collector number, e.g. "025/198" or "LOB-001"
    var rarity: String?
    var imageURL: URL?
    var marketPrice: Money?
    var sport: SportCategory? = nil   // set only for `.sports` cards
}
