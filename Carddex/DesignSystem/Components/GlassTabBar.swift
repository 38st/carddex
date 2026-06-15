import SwiftUI

enum Tab: CaseIterable {
    case scan, collection, portfolio, settings
}

/// Floating bottom bar with a raised center Scan action. Uses iOS 26 Liquid
/// Glass where available, falling back to a translucent material.
struct GlassTabBar: View {
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 0) {
            tab(.collection, "square.grid.2x2")
            Spacer(minLength: 0)
            tab(.portfolio, "chart.line.uptrend.xyaxis")
            Spacer(minLength: 0)
            scanButton
            Spacer(minLength: 0)
            tab(.settings, "gearshape")
        }
        .padding(.horizontal, 30)
        .frame(height: 60)
        .modifier(BarGlass())
        .padding(.horizontal, 26)
    }

    private func tab(_ destination: Tab, _ symbol: String) -> some View {
        Button {
            selection = destination
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(selection == destination ? Theme.accent : Theme.textTertiary)
                .frame(width: 44, height: 44)
        }
    }

    private var scanButton: some View {
        Button {
            selection = .scan
        } label: {
            Image(systemName: "viewfinder")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.accent, in: Circle())
                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 4))
        }
        .offset(y: -14)
    }
}

/// Liquid Glass capsule for the bar, with a pre-iOS 26 material fallback.
private struct BarGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
        }
    }
}
