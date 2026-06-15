import SwiftUI

/// Sub-category for sports cards (the `.sports` game spans several sports).
enum SportCategory: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case basketball
    case baseball
    case football
    case soccer
    case hockey

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basketball: "Basketball"
        case .baseball: "Baseball"
        case .football: "Football"
        case .soccer: "Soccer"
        case .hockey: "Hockey"
        }
    }

    var symbol: String {
        switch self {
        case .basketball: "basketball.fill"
        case .baseball: "baseball.fill"
        case .football: "football.fill"
        case .soccer: "soccerball"
        case .hockey: "hockey.puck.fill"
        }
    }

    var accent: Color {
        switch self {
        case .basketball: Color(hex: 0xEE6730)
        case .baseball: Color(hex: 0xC8102E)
        case .football: Color(hex: 0x8B5E3C)
        case .soccer: Color(hex: 0x2FAE60)
        case .hockey: Color(hex: 0x4AA3DF)
        }
    }

    var artGradient: [Color] {
        switch self {
        case .basketball: [Color(hex: 0x3A1E0E), Color(hex: 0x8A3F18), Color(hex: 0xEE6730)]
        case .baseball: [Color(hex: 0x2A0A10), Color(hex: 0x7A1020), Color(hex: 0xC8102E)]
        case .football: [Color(hex: 0x241710), Color(hex: 0x5A3A22), Color(hex: 0x8B5E3C)]
        case .soccer: [Color(hex: 0x0E2A18), Color(hex: 0x1E6A3C), Color(hex: 0x2FAE60)]
        case .hockey: [Color(hex: 0x0E2230), Color(hex: 0x1E5A7A), Color(hex: 0x4AA3DF)]
        }
    }
}
