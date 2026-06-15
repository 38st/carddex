import SwiftUI

enum Tab: CaseIterable {
    case scan, collection, portfolio, settings
}

/// Floating bottom tab bar — four evenly-spaced tabs over an iOS 26 Liquid Glass
/// capsule (tinted dark so it doesn't pick up the colors of the content behind it).
struct GlassTabBar: View {
    @Binding var selection: Tab

    private let items: [(tab: Tab, icon: String, label: String)] = [
        (.scan, "viewfinder", "Scan"),
        (.collection, "square.grid.2x2", "Collection"),
        (.portfolio, "chart.line.uptrend.xyaxis", "Portfolio"),
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
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.28)), in: Capsule())
        } else {
            content
                .background(Theme.bgRaised.opacity(0.8), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
        }
    }
}
