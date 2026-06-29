import SwiftUI

/// "The Vault" design tokens — a warm, espresso-lit display case for cards.
/// Dark-first, but every surface/text token is scheme-adaptive: in light mode
/// the vault becomes a "frosted daylight case" (warm paper) so the app stays
/// readable when scanning outdoors. Tokens are dynamic `UIColor`s so call sites
/// don't change — SwiftUI resolves them against the active `colorScheme`.
enum Theme {
    /// App-wide color-scheme preference. `nil` = follow the system (the MVP).
    /// Every screen routes its `.preferredColorScheme` through this single point,
    /// so a future Settings toggle can force light/dark from one place.
    static let appColorScheme: ColorScheme? = nil

    /// A token that resolves to `light` or `dark` against the active scheme.
    private static func dyn(light: UInt, dark: UInt, opacity: Double = 1) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(Color(hex: hex)).withAlphaComponent(opacity)
        })
    }

    // Primary action surface: a high-contrast "inverted" pill — warm cream on the
    // dark vault, warm espresso on the light case. Both `cream` (the fill/accent)
    // and `onCream` (text on it) flip together, so contrast holds in either mode.
    static let cream = dyn(light: 0x2E2421, dark: 0xF6EFE7)
    static let creamPressed = dyn(light: 0x453633, dark: 0xE3DACE)
    static let onCream = dyn(light: 0xF6EFE7, dark: 0x1A1210)

    // Vault surfaces — warm espresso in dark, warm paper in light.
    static let bg = dyn(light: 0xF3ECE3, dark: 0x271E1D)
    static let bgRaised = dyn(light: 0xFBF6EF, dark: 0x312625)
    static let surface = dyn(light: 0xFCF8F2, dark: 0x3A2E2C)
    static let surface2 = dyn(light: 0xEFE6DB, dark: 0x463835)

    // Text — warm off-whites in dark, warm espressos in light.
    static let textPrimary = dyn(light: 0x2A211E, dark: 0xF6F1ED)
    static let textSecondary = dyn(light: 0x6F615A, dark: 0xBCAFA9)
    static let textTertiary = dyn(light: 0x9D8E86, dark: 0x8C7E78)

    // Semantic — unchanged for data legibility (readable on both surfaces).
    static let gain = Color(hex: 0x34D399)
    static let loss = Color(hex: 0xFB7185)
    static let warning = Color(hex: 0xFBBF24)
    /// Warm amber for neutral price charts (reads better than cream on the espresso bg).
    static let chart = Color(hex: 0xF2A35E)

    // Hairline stroke on glass — faintly warm; darkens on the light case.
    static let hairline = dyn(light: 0x2A1A12, dark: 0xFFE9DB, opacity: 0.12)

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
