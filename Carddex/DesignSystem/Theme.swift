import SwiftUI

/// Central design tokens. Keep colors, spacing, and corner radii here so the
/// look stays consistent as the app grows.
enum Theme {
    static let accent = Color(red: 0.36, green: 0.32, blue: 0.85)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
    }

    /// Standard trading-card aspect ratio (2.5" × 3.5").
    static let cardAspectRatio: CGFloat = 2.5 / 3.5
}
