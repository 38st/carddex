import SwiftUI

enum Tab: CaseIterable {
    case market, collection, scan, portfolio, settings
}

extension View {
    /// Reserves space at the bottom of a scroll view for the floating tab bar so
    /// content (and search results) stop above it instead of sliding under.
    func tabBarSafeArea() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 80) }
    }
}

/// Floating bottom tab bar — four evenly-spaced tabs over an iOS 26 Liquid Glass
/// capsule (tinted dark so it doesn't pick up the colors of the content behind it).
struct GlassTabBar: View {
    @Binding var selection: Tab

    private let items: [(tab: Tab, icon: String, label: String)] = [
        (.market, "chart.line.uptrend.xyaxis", "Market"),
        (.collection, "square.grid.2x2", "Collection"),
        (.scan, "viewfinder", "Scan"),
        (.portfolio, "dollarsign.circle", "Portfolio"),
        (.settings, "gearshape", "Settings"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                tabButton(item.tab, item.icon, item.label)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 58)
        .modifier(BarGlass())
        .padding(.horizontal, 22)
    }

    private func tabButton(_ tab: Tab, _ icon: String, _ label: String) -> some View {
        let selected = selection == tab
        return Button {
            if selection != tab { Haptics.selection() }
            withAnimation(Theme.springTap) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: selected ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

/// Liquid Glass capsule for the bar, tinted dark to tame color bleed, with a
/// pre-iOS 26 material fallback.
private struct BarGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
    }
}
