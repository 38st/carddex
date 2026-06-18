import SwiftUI

/// The signature "vault" backdrop: warm espresso spotlight gradient lit from the top.
struct VaultBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            // Gentle warm lift from the top — stays an even taupe, never blacks
            // out at the edges (matches the reference's evenly-lit brown room).
            LinearGradient(
                colors: [Color(hex: 0x362927), Color(hex: 0x241C1B)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(hex: 0x42322D).opacity(0.55), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Card surface: solid warm panel + hairline stroke. (Named `glassPanel` for
    /// continuity; the warm theme reads better as a solid fill than frosted glass.)
    func glassPanel(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline)
            )
    }
}
