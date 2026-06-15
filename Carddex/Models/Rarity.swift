import Foundation

/// Foil treatment tiers, derived from a card's free-text rarity and price.
enum FoilTier {
    case none
    case rare
    case mythic
}

enum Rarity {
    /// Maps a card's rarity text + price to a foil tier.
    static func tier(rarityText: String?, price: Money?) -> FoilTier {
        if let amount = price?.amount, amount >= 500 { return .mythic }
        guard let text = rarityText?.lowercased() else { return .none }
        if text.contains("secret") || text.contains("special") || text.contains("mythic") {
            return .mythic
        }
        if text.contains("holo") || text.contains("rare") || text.contains("ultra") {
            return .rare
        }
        return .none
    }
}
