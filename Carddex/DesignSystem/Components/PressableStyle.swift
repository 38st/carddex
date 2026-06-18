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
    /// Big, tight display heading used on hero / empty states
    /// (the reference's "Exclusive Digital Collectibles" treatment).
    func heroTitle(size: CGFloat = 34) -> some View {
        self.font(.system(size: size, weight: .heavy, design: .default))
            .foregroundStyle(Theme.textPrimary)
    }
}

extension Font {
    /// Sharp geometric display font (SF Pro) for headings — matches the
    /// reference's tight display face rather than a rounded one.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
