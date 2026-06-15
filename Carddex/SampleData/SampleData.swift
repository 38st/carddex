import Foundation

/// Placeholder data so the UI is populated before the catalog APIs are wired in.
/// Removed once real identification + Supabase sync land in Phase 1.
enum SampleData {
    static let cards: [Card] = [
        Card(id: "pkm-base-4", game: .pokemon, name: "Charizard",
             setName: "Base Set", number: "4/102", rarity: "Holo Rare",
             imageURL: nil, marketPrice: Money(amount: 320)),
        Card(id: "pkm-sv-025", game: .pokemon, name: "Pikachu",
             setName: "Scarlet & Violet", number: "025/198", rarity: "Common",
             imageURL: nil, marketPrice: Money(amount: 4.50)),
        Card(id: "mtg-alpha-blacklotus", game: .magic, name: "Black Lotus",
             setName: "Alpha", number: "232", rarity: "Rare",
             imageURL: nil, marketPrice: Money(amount: 28000)),
        Card(id: "mtg-mh2-ragavan", game: .magic, name: "Ragavan, Nimble Pilferer",
             setName: "Modern Horizons 2", number: "138", rarity: "Mythic",
             imageURL: nil, marketPrice: Money(amount: 55)),
        Card(id: "ygo-lob-001", game: .yugioh, name: "Blue-Eyes White Dragon",
             setName: "Legend of Blue Eyes", number: "LOB-001", rarity: "Ultra Rare",
             imageURL: nil, marketPrice: Money(amount: 90)),
        Card(id: "sports-fleer86-57", game: .sports, name: "Michael Jordan RC",
             setName: "1986 Fleer", number: "57", rarity: nil,
             imageURL: nil, marketPrice: Money(amount: 12000)),
    ]

    static let collection: [CollectionItem] = [
        CollectionItem(card: cards[0], quantity: 1, condition: .nearMint),
        CollectionItem(card: cards[1], quantity: 4, condition: .mint),
        CollectionItem(card: cards[3], quantity: 2, condition: .nearMint),
        CollectionItem(card: cards[4], quantity: 1, condition: .lightlyPlayed),
    ]
}
