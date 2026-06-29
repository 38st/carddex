import Foundation

/// Standard TCG condition grades, from best to worst.
enum CardCondition: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case mint = "Mint"
    case nearMint = "Near Mint"
    case lightlyPlayed = "Lightly Played"
    case moderatelyPlayed = "Moderately Played"
    case heavilyPlayed = "Heavily Played"
    case damaged = "Damaged"

    var id: String { rawValue }

    /// Fraction of mint market value a card in this condition is worth. Used to
    /// derive a condition-adjusted estimate so portfolio value isn't assumed
    /// mint for every card. Heuristic (not market-sourced).
    var multiplier: Decimal {
        switch self {
        case .mint: 1.0
        case .nearMint: 0.9
        case .lightlyPlayed: 0.75
        case .moderatelyPlayed: 0.6
        case .heavilyPlayed: 0.45
        case .damaged: 0.3
        }
    }

    var abbreviation: String {
        switch self {
        case .mint: "M"
        case .nearMint: "NM"
        case .lightlyPlayed: "LP"
        case .moderatelyPlayed: "MP"
        case .heavilyPlayed: "HP"
        case .damaged: "DMG"
        }
    }
}
