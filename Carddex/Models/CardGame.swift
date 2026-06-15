import SwiftUI

/// The card games Carddex supports. Pokémon, Magic, and Yu-Gi-Oh! lead because
/// they have great free catalog APIs; sports is staged in later.
enum CardGame: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case pokemon
    case magic
    case yugioh
    case sports

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pokemon: "Pokémon"
        case .magic: "Magic"
        case .yugioh: "Yu-Gi-Oh!"
        case .sports: "Sports"
        }
    }

    var symbol: String {
        switch self {
        case .pokemon: "bolt.fill"
        case .magic: "wand.and.stars"
        case .yugioh: "eye.fill"
        case .sports: "sportscourt.fill"
        }
    }

    /// Refined accent, tuned for the dark vault.
    var accent: Color {
        switch self {
        case .pokemon: Color(hex: 0xFFD23F)
        case .magic: Color(hex: 0x9B6BFF)
        case .yugioh: Color(hex: 0xE8702A)
        case .sports: Color(hex: 0x2DD4A7)
        }
    }

    /// Placeholder card-art gradient until real catalog images load.
    var artGradient: [Color] {
        switch self {
        case .pokemon: [Color(hex: 0x3A2A12), Color(hex: 0x7A5418), Color(hex: 0xD9AF3F)]
        case .magic: [Color(hex: 0x241A3A), Color(hex: 0x4A357E), Color(hex: 0x9B6BFF)]
        case .yugioh: [Color(hex: 0x3A2410), Color(hex: 0x7A4520), Color(hex: 0xE8853A)]
        case .sports: [Color(hex: 0x10241A), Color(hex: 0x1E5A45), Color(hex: 0x2DD4A7)]
        }
    }
}
