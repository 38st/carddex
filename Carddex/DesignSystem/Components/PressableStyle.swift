import SwiftUI

/// Subtle press feedback — dim + scale. Shared across the interactive components
/// so taps feel of-a-piece across the app.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.springTap, value: configuration.isPressed)
    }
}

extension View {
    /// Big display heading for hero / empty states (the reference's
    /// "Exclusive Digital Collectibles" treatment). Scales with Dynamic Type.
    func heroTitle(size: CGFloat = 34) -> some View {
        self.font(.custom("SpaceGrotesk-Bold", size: size, relativeTo: .largeTitle))
            .foregroundStyle(Theme.textPrimary)
    }
}

extension Font {
    /// Space Grotesk — the bundled geometric display face used for headings.
    /// Scales with Dynamic Type; falls back to the system font if unavailable.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .medium: name = "SpaceGrotesk-Medium"
        case .semibold: name = "SpaceGrotesk-SemiBold"
        default: name = "SpaceGrotesk-Bold"
        }
        return .custom(name, size: size, relativeTo: .title)
    }
}
