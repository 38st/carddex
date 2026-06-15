import Foundation

/// Placeholder data so the UI is populated before the catalog APIs are wired in.
/// Image URLs are real public catalog images (pokemontcg.io, ygoprodeck.com).
/// Removed once real identification + Supabase sync land in Phase 1.
enum SampleData {
    private static func img(_ string: String) -> URL? { URL(string: string) }

    // Base Set (Pokémon) — a partially-complete set for the binder view.
    static let charizard = Card(id: "pkm-base-4", game: .pokemon, name: "Charizard",
                                setName: "Base Set", number: "4/102", rarity: "Holo Rare",
                                imageURL: img("https://images.pokemontcg.io/base1/4_hires.png"),
                                marketPrice: Money(amount: 320))
    static let blastoise = Card(id: "pkm-base-2", game: .pokemon, name: "Blastoise",
                                setName: "Base Set", number: "2/102", rarity: "Holo Rare",
                                imageURL: img("https://images.pokemontcg.io/base1/2_hires.png"),
                                marketPrice: Money(amount: 150))
    static let venusaur = Card(id: "pkm-base-15", game: .pokemon, name: "Venusaur",
                               setName: "Base Set", number: "15/102", rarity: "Holo Rare",
                               imageURL: img("https://images.pokemontcg.io/base1/15_hires.png"),
                               marketPrice: Money(amount: 120))
    static let mewtwo = Card(id: "pkm-base-10", game: .pokemon, name: "Mewtwo",
                             setName: "Base Set", number: "10/102", rarity: "Holo Rare",
                             imageURL: img("https://images.pokemontcg.io/base1/10_hires.png"),
                             marketPrice: Money(amount: 45))
    static let gyarados = Card(id: "pkm-base-6", game: .pokemon, name: "Gyarados",
                               setName: "Base Set", number: "6/102", rarity: "Holo Rare",
                               imageURL: img("https://images.pokemontcg.io/base1/6_hires.png"),
                               marketPrice: Money(amount: 40))
    static let machamp = Card(id: "pkm-base-8", game: .pokemon, name: "Machamp",
                              setName: "Base Set", number: "8/102", rarity: "Holo Rare",
                              imageURL: img("https://images.pokemontcg.io/base1/8_hires.png"),
                              marketPrice: Money(amount: 25))
    static let pikachu = Card(id: "pkm-base-58", game: .pokemon, name: "Pikachu",
                              setName: "Base Set", number: "58/102", rarity: "Common",
                              imageURL: img("https://images.pokemontcg.io/base1/58_hires.png"),
                              marketPrice: Money(amount: 12))

    static let blackLotus = Card(id: "mtg-alpha-blacklotus", game: .magic, name: "Black Lotus",
                                 setName: "Alpha", number: "232", rarity: "Rare",
                                 imageURL: nil, marketPrice: Money(amount: 28000))
    static let ragavan = Card(id: "mtg-mh2-ragavan", game: .magic, name: "Ragavan, Nimble Pilferer",
                              setName: "Modern Horizons 2", number: "138", rarity: "Mythic",
                              imageURL: nil, marketPrice: Money(amount: 55))

    static let blueEyes = Card(id: "ygo-lob-001", game: .yugioh, name: "Blue-Eyes White Dragon",
                               setName: "Legend of Blue Eyes", number: "LOB-001", rarity: "Ultra Rare",
                               imageURL: img("https://images.ygoprodeck.com/images/cards/89631139.jpg"),
                               marketPrice: Money(amount: 90))

    static let jordan = Card(id: "sports-fleer86-57", game: .sports, name: "Michael Jordan RC",
                             setName: "1986 Fleer", number: "57", rarity: nil,
                             imageURL: nil, marketPrice: Money(amount: 12000))

    static let cards: [Card] = [
        charizard, blastoise, venusaur, mewtwo, gyarados, machamp,
        pikachu, blackLotus, ragavan, blueEyes, jordan,
    ]

    static let collection: [CollectionItem] = [
        CollectionItem(card: charizard, condition: .nearMint),
        CollectionItem(card: blastoise, condition: .nearMint),
        CollectionItem(card: venusaur, condition: .lightlyPlayed),
        CollectionItem(card: mewtwo, condition: .nearMint),
        CollectionItem(card: gyarados, quantity: 2, condition: .nearMint),
        CollectionItem(card: machamp, condition: .moderatelyPlayed),
        CollectionItem(card: pikachu, quantity: 4, condition: .mint),
        CollectionItem(card: ragavan, quantity: 2, condition: .nearMint),
        CollectionItem(card: blueEyes, condition: .lightlyPlayed),
    ]

    // A set checklist with some owned (above) and some still missing.
    static let baseSet = CardSet(
        id: "base1", game: .pokemon, name: "Base Set", total: 102,
        slots: [
            SetSlot(number: "1/102", name: "Alakazam", rarity: "Holo Rare"),
            SetSlot(number: "2/102", name: "Blastoise", rarity: "Holo Rare"),
            SetSlot(number: "3/102", name: "Chansey", rarity: "Holo Rare"),
            SetSlot(number: "4/102", name: "Charizard", rarity: "Holo Rare"),
            SetSlot(number: "6/102", name: "Gyarados", rarity: "Holo Rare"),
            SetSlot(number: "8/102", name: "Machamp", rarity: "Holo Rare"),
            SetSlot(number: "10/102", name: "Mewtwo", rarity: "Holo Rare"),
            SetSlot(number: "14/102", name: "Raichu", rarity: "Holo Rare"),
            SetSlot(number: "15/102", name: "Venusaur", rarity: "Holo Rare"),
        ]
    )

    static let sets: [CardSet] = [baseSet]
}
