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

    var accent: Color {
        switch self {
        case .pokemon: Color(red: 0.96, green: 0.76, blue: 0.13)
        case .magic: Color(red: 0.45, green: 0.30, blue: 0.66)
        case .yugioh: Color(red: 0.78, green: 0.40, blue: 0.13)
        case .sports: Color(red: 0.16, green: 0.55, blue: 0.40)
        }
    }
}
