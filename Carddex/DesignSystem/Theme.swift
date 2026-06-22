import SwiftUI

/// "The Vault" design tokens — a warm, espresso-lit display case for cards.
/// Dark-first; light mode comes later.
enum Theme {
    // Primary action surface: warm cream/white pills with dark text (the
    // reference's "Get Started" / "Place Bid" / active-chip language).
    static let cream = Color(hex: 0xF6EFE7)
    static let creamPressed = Color(hex: 0xE3DACE)
    static let onCream = Color(hex: 0x1A1210)

    // Vault surfaces — warm taupe/espresso, evenly lit (sampled from the
    // reference: bg ~#261D1D, raised cards ~#2D2424, lighter surfaces ~#453636).
    static let bg = Color(hex: 0x271E1D)
    static let bgRaised = Color(hex: 0x312625)
    static let surface = Color(hex: 0x3A2E2C)
    static let surface2 = Color(hex: 0x463835)

    // Text — warm off-whites.
    static let textPrimary = Color(hex: 0xF6F1ED)
    static let textSecondary = Color(hex: 0xBCAFA9)
    static let textTertiary = Color(hex: 0x8C7E78)

    // Semantic — unchanged for data legibility.
    static let gain = Color(hex: 0x34D399)
    static let loss = Color(hex: 0xFB7185)
    static let warning = Color(hex: 0xFBBF24)
    /// Warm amber for neutral price charts (reads better than cream on the espresso bg).
    static let chart = Color(hex: 0xF2A35E)

    // Hairline stroke on glass — faintly warm.
    static let hairline = Color(hex: 0xFFE9DB).opacity(0.10)

    /// Standard trading-card aspect ratio (2.5" × 3.5").
    static let cardAspectRatio: CGFloat = 2.5 / 3.5

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let xms: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let card: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    static let springUI = Animation.spring(response: 0.4, dampingFraction: 0.82)
    static let springTap = Animation.spring(response: 0.28, dampingFraction: 0.7)
}
