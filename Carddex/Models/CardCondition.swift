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
