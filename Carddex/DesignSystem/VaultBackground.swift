import SwiftUI

/// The signature "vault" backdrop: a warm spotlight gradient lit from the top —
/// espresso in dark mode, a frosted warm-paper "daylight case" in light mode.
struct VaultBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Theme.bg
            // Gentle warm lift from the top — stays evenly lit, never blacks out
            // (dark) or washes flat (light) at the edges.
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(hex: 0x362927), Color(hex: 0x241C1B)]
                    : [Color(hex: 0xFCF8F2), Color(hex: 0xEDE3D6)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    (scheme == .dark ? Color(hex: 0x42322D) : Color(hex: 0xFFFFFF))
                        .opacity(scheme == .dark ? 0.55 : 0.6),
                    .clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}
