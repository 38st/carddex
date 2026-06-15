import SwiftUI

/// The signature "vault" backdrop: graphite spotlight gradient lit from the top.
struct VaultBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            LinearGradient(
                colors: [Color(hex: 0x20202E), Theme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(hex: 0x35354C).opacity(0.65), .clear],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Glass panel surface: translucent material + hairline stroke.
    func glassPanel(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline)
            )
    }
}
