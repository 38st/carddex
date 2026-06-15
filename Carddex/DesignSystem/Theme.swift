import SwiftUI

/// "The Vault" design tokens — a dark, museum-lit display case for cards.
/// Dark-first; light mode comes later.
enum Theme {
    // Brand
    static let accent = Color(hex: 0x6E6BFF)
    static let accentPressed = Color(hex: 0x5552E6)

    // Vault surfaces
    static let bg = Color(hex: 0x0B0B0F)
    static let bgRaised = Color(hex: 0x16161D)
    static let surface = Color(hex: 0x1C1C26)
    static let surface2 = Color(hex: 0x262633)

    // Text
    static let textPrimary = Color(hex: 0xF4F4F7)
    static let textSecondary = Color(hex: 0xA0A0AE)
    static let textTertiary = Color(hex: 0x6C6C7A)

    // Semantic
    static let gain = Color(hex: 0x34D399)
    static let loss = Color(hex: 0xFB7185)
    static let warning = Color(hex: 0xFBBF24)

    // Hairline stroke on glass
    static let hairline = Color.white.opacity(0.09)

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
        static let card: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    static let springUI = Animation.spring(response: 0.4, dampingFraction: 0.82)
    static let springTap = Animation.spring(response: 0.28, dampingFraction: 0.7)
}
