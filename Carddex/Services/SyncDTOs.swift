import Foundation

/// Wire-layer DTOs for sync. These align to the Supabase table columns
/// (snake_case) and carry the sync timestamps the `SyncEngine` needs for
/// last-write-wins + tombstone application. Kept separate from the view
/// structs (`Card`/`CollectionItem`/…) so the wire format and the UI model
/// can evolve independently — the plan's "thin toModel()/fromModel()".sendable
///
/// Date decoding: Supabase `timestamptz` arrives as ISO8601 strings; the
/// transport configures `JSONDecoder` with `.iso8601`.

// MARK: - Card

/// The `cards` table shape. `market_price` and `sport` are populated by the
/// catalog-sync / rollup jobs; they may be nil for cards that haven't been
/// priced yet or non-sports cards (sport is nil for pokemon/magic/yugioh).
struct CardDTO: Codable, Sendable {
    let id: String
    let game: String
    let name: String
    let set_name: String?
    let number: String?
    let rarity: String?
    let image_url: String?
    let market_price: Double?
    let sport: String?

    func toCard() -> Card? {
        guard let game = CardGame(rawValue: game) else { return nil }
        return Card(
            id: id,
            game: game,
            name: name,
            setName: set_name ?? "",
            number: number ?? "",
            rarity: rarity,
            imageURL: image_url.flatMap(URL.init(string:)),
            marketPrice: market_price.map { Money(amount: Decimal($0)) },
            sport: sport.flatMap(SportCategory.init(rawValue:))
        )
    }
}

// MARK: - Collection item

/// `collection_items` row + the joined `card` (PostgREST:
/// `select=*,card:cards(*)`). The engine reconstructs a `CollectionItem` from
/// these; if the join is absent or the card can't be parsed, the row is held
/// aside (logged) rather than crashing.
struct CollectionItemDTO: Codable, Sendable {
    let id: UUID
    let card_id: String
    let quantity: Int
    let condition: String
    let purchase_price: Double?
    let currency: String?
    let date_added: Date?
    let updated_at: Date?
    let deleted_at: Date?
    let card: CardDTO?

    func toModel() -> CollectionItem? {
        let cardModel = card?.toCard()
        // If the join didn't arrive, we can't fully rebuild the item — the
        // engine will skip and retry once card data is available.
        guard let cardModel else { return nil }
        let price = purchase_price.map {
            Money(amount: Decimal($0), currencyCode: currency ?? "USD")
        }
        return CollectionItem(
            id: id,
            card: cardModel,
            quantity: quantity,
            condition: CardCondition(rawValue: condition) ?? .nearMint,
            dateAdded: date_added ?? .now,
            purchasePrice: price
        )
    }
}

// MARK: - Price alert

struct PriceAlertDTO: Codable, Sendable {
    let id: UUID?
    let card_id: String
    let target_price: Double?
    let updated_at: Date?
    let deleted_at: Date?

    func toModel() -> PriceAlert {
        PriceAlert(
            cardID: card_id,
            target: Money(amount: Decimal(target_price ?? 0))
        )
    }
}

// MARK: - Grail / wishlist

struct GrailEntryDTO: Codable, Sendable {
    let id: UUID?
    let card_id: String
    let target: Double?
    let note: String?
    let date_added: Date?
    let updated_at: Date?
    let deleted_at: Date?

    func toModel() -> GrailEntry {
        let target = target.map { Money(amount: Decimal($0)) }
        return GrailEntry(
            cardID: card_id,
            target: target,
            note: note,
            dateAdded: date_added ?? .now
        )
    }
}

// MARK: - Subscription (1:1 singleton)

struct SubscriptionDTO: Codable, Sendable {
    // The `subscriptions` table only has `tier`/`status`/`updated_at` — it has
    // no `is_pro` or `scans_this_month` column (scan usage lives in
    // `scan_usage`). Pushing those columns 400'd every subscription sync, so
    // the wire DTO carries only the entitlement (`tier`) the server stores.
    // `isPro` is derived from `tier == "pro"` on pull; `scansThisMonth` is a
    // local-only quota counter (the server is the source of truth via scans).
    let tier: String?
    let updated_at: Date?

    func toDTO() -> SubscriptionStateDTO {
        SubscriptionStateDTO(
            isPro: tier == "pro",
            scansThisMonth: 0
        )
    }

    var updatedAt: Date? { updated_at }
}

// MARK: - Aggregate pull result

/// Everything an incremental pull returns. Each array entry carries its own
/// `updated_at`/`deleted_at` so the `SyncEngine` can do per-row LWW.
struct RemoteChanges: Sendable {
    var collectionItems: [CollectionItemDTO]
    var priceAlerts: [PriceAlertDTO]
    var wishlistEntries: [GrailEntryDTO]
    var subscription: SubscriptionDTO?

    static let empty = RemoteChanges(collectionItems: [], priceAlerts: [], wishlistEntries: [], subscription: nil)
}
