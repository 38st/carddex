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

    // Sports cards — multiple sports, each its own category. Sports has no free
    // image catalog (unlike Pokémon/Yu-Gi-Oh), so these are temporary demo images
    // hotlinked from editorial CDNs; production uses the user's own scan photo.
    static let jordan = Card(id: "sports-fleer86-57", game: .sports, name: "Michael Jordan RC",
                             setName: "1986 Fleer", number: "57", rarity: nil,
                             imageURL: img("https://blog.justcollect.com/hs-fs/hubfs/Jordan-1.jpg?width=600&name=Jordan-1.jpg"),
                             marketPrice: Money(amount: 12000), sport: .basketball)
    static let lebron = Card(id: "sports-topps03-111", game: .sports, name: "LeBron James RC",
                             setName: "2003 Topps Chrome", number: "111", rarity: "Refractor",
                             imageURL: nil, marketPrice: Money(amount: 3500), sport: .basketball)
    static let brady = Card(id: "sports-bowman00-236", game: .sports, name: "Tom Brady RC",
                            setName: "2000 Bowman", number: "236", rarity: nil,
                            imageURL: img("https://www.joesalbums.com/cdn/shop/files/tom_brady_2000_bowman_rookie_football_card.jpg?v=1700085069&width=1500"),
                            marketPrice: Money(amount: 2800), sport: .football)
    static let trout = Card(id: "sports-topps11-175", game: .sports, name: "Mike Trout RC",
                            setName: "2011 Topps Update", number: "US175", rarity: nil,
                            imageURL: nil, marketPrice: Money(amount: 900), sport: .baseball)
    static let messi = Card(id: "sports-mega04-71", game: .sports, name: "Lionel Messi RC",
                            setName: "2004 Megacracks", number: "71", rarity: nil,
                            imageURL: nil, marketPrice: Money(amount: 1200), sport: .soccer)
    static let gretzky = Card(id: "sports-opc79-18", game: .sports, name: "Wayne Gretzky RC",
                              setName: "1979 O-Pee-Chee", number: "18", rarity: nil,
                              imageURL: nil, marketPrice: Money(amount: 5000), sport: .hockey)

    static let cards: [Card] = [
        charizard, blastoise, venusaur, mewtwo, gyarados, machamp,
        pikachu, blackLotus, ragavan, blueEyes,
        jordan, lebron, brady, trout, messi, gretzky,
    ]

    /// Resolves a catalog card id to a `Card`, or nil if it isn't in the bundled
    /// sample. (`cards` already spans the catalog + market-tracked sets.) Real
    /// catalogs replace this with a backend query.
    private static let cardByID: [String: Card] = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    static func card(id: String) -> Card? { cardByID[id] }

    static let collection: [CollectionItem] = [
        CollectionItem(card: charizard, condition: .nearMint, purchasePrice: Money(amount: 190)),
        CollectionItem(card: blastoise, condition: .nearMint, purchasePrice: Money(amount: 110)),
        CollectionItem(card: venusaur, condition: .lightlyPlayed, purchasePrice: Money(amount: 140)),
        CollectionItem(card: mewtwo, condition: .nearMint, purchasePrice: Money(amount: 30)),
        CollectionItem(card: gyarados, quantity: 2, condition: .nearMint, purchasePrice: Money(amount: 35)),
        CollectionItem(card: machamp, condition: .moderatelyPlayed, purchasePrice: Money(amount: 28)),
        CollectionItem(card: pikachu, quantity: 4, condition: .mint, purchasePrice: Money(amount: 8)),
        CollectionItem(card: ragavan, quantity: 2, condition: .nearMint, purchasePrice: Money(amount: 60)),
        CollectionItem(card: blueEyes, condition: .lightlyPlayed, purchasePrice: Money(amount: 70)),
        CollectionItem(card: jordan, condition: .nearMint, purchasePrice: Money(amount: 9000)),
        CollectionItem(card: lebron, condition: .mint, purchasePrice: Money(amount: 4200)),
        CollectionItem(card: brady, condition: .nearMint, purchasePrice: Money(amount: 2000)),
        CollectionItem(card: trout, condition: .nearMint, purchasePrice: Money(amount: 1100)),
    ]

    // A set checklist with some owned (above) and some still missing.
    static let baseSet = CardSet(
        id: "base1", game: .pokemon, name: "Base Set", total: 102,
        slots: [
            SetSlot(number: "1/102", name: "Alakazam", rarity: "Holo Rare"),
            SetSlot(number: "2/102", name: "Blastoise", rarity: "Holo Rare", cardID: blastoise.id),
            SetSlot(number: "3/102", name: "Chansey", rarity: "Holo Rare"),
            SetSlot(number: "4/102", name: "Charizard", rarity: "Holo Rare", cardID: charizard.id),
            SetSlot(number: "6/102", name: "Gyarados", rarity: "Holo Rare", cardID: gyarados.id),
            SetSlot(number: "8/102", name: "Machamp", rarity: "Holo Rare", cardID: machamp.id),
            SetSlot(number: "10/102", name: "Mewtwo", rarity: "Holo Rare", cardID: mewtwo.id),
            SetSlot(number: "14/102", name: "Raichu", rarity: "Holo Rare"),
            SetSlot(number: "15/102", name: "Venusaur", rarity: "Holo Rare", cardID: venusaur.id),
            SetSlot(number: "58/102", name: "Pikachu", rarity: "Common", cardID: pikachu.id),
        ]
    )

    // Pokémon Scarlet & Violet base — a modern set, none owned in the sample.
    static let scarletVioletSet = CardSet(
        id: "sv3", game: .pokemon, name: "Scarlet & Violet Base", total: 198,
        slots: [
            SetSlot(number: "024/198", name: "Sprigatito", rarity: "Common"),
            SetSlot(number: "038/198", name: "Fuecoco", rarity: "Common"),
            SetSlot(number: "052/198", name: "Quaxly", rarity: "Common"),
            SetSlot(number: "190/198", name: "Miraidon ex", rarity: "Ultra Rare"),
            SetSlot(number: "198/198", name: "Koraidon ex", rarity: "Illustration Rare"),
            SetSlot(number: "230/198", name: "Chien-Pao ex", rarity: "Special Illustration Rare"),
        ]
    )

    // Magic: Alpha — the grail set. Black Lotus is owned.
    static let alphaSet = CardSet(
        id: "mtg-alpha", game: .magic, name: "Alpha", total: 295,
        slots: [
            SetSlot(number: "232", name: "Black Lotus", rarity: "Rare", cardID: blackLotus.id),
            SetSlot(number: "231", name: "Mox Pearl", rarity: "Rare"),
            SetSlot(number: "230", name: "Mox Jet", rarity: "Rare"),
            SetSlot(number: "229", name: "Mox Ruby", rarity: "Rare"),
            SetSlot(number: "228", name: "Mox Emerald", rarity: "Rare"),
            SetSlot(number: "227", name: "Mox Sapphire", rarity: "Rare"),
            SetSlot(number: "226", name: "Ancestral Recall", rarity: "Rare"),
            SetSlot(number: "225", name: "Time Walk", rarity: "Rare"),
        ]
    )

    // Yu-Gi-Oh! Legend of Blue Eyes — Blue-Eyes owned.
    static let lobSet = CardSet(
        id: "ygo-lob", game: .yugioh, name: "Legend of Blue Eyes", total: 126,
        slots: [
            SetSlot(number: "LOB-001", name: "Blue-Eyes White Dragon", rarity: "Ultra Rare", cardID: blueEyes.id),
            SetSlot(number: "LOB-002", name: "Dark Magician", rarity: "Ultra Rare"),
            SetSlot(number: "LOB-003", name: "Exodia the Forbidden One", rarity: "Ultra Rare"),
            SetSlot(number: "LOB-004", name: "Right Arm of the Forbidden One", rarity: "Rare"),
            SetSlot(number: "LOB-005", name: "Left Leg of the Forbidden One", rarity: "Rare"),
            SetSlot(number: "LOB-000", name: "Tri-Horned Dragon", rarity: "Secret Rare"),
        ]
    )

    // 1986 Fleer basketball — the Jordan rookie set.
    static let fleer86Set = CardSet(
        id: "sports-fleer86", game: .sports, name: "1986 Fleer Basketball", total: 132,
        slots: [
            SetSlot(number: "57", name: "Michael Jordan RC", rarity: nil, cardID: jordan.id),
            SetSlot(number: "32", name: "Karl Malone RC", rarity: nil),
            SetSlot(number: "120", name: "Hakeem Olajuwon RC", rarity: nil),
            SetSlot(number: "74", name: "Charles Barkley RC", rarity: nil),
            SetSlot(number: "8", name: "Patrick Ewing RC", rarity: nil),
        ]
    )

    static let sets: [CardSet] = [baseSet, scarletVioletSet, alphaSet, lobSet, fleer86Set]
}
