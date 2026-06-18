import SwiftUI

/// Pill filter chip used across Market and Collection.
/// Active = cream fill + dark text; inactive = warm surface + hairline.
struct Chip: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if let count {
                    Text("\(count)")
                        .opacity(isSelected ? 0.6 : 0.5)
                }
            }
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? Theme.onCream : Theme.textSecondary)
            .modifier(ChipBackground(isSelected: isSelected))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Selected chips are a solid cream pill (the primary affordance); unselected
/// chips are Liquid Glass.
private struct ChipBackground: ViewModifier {
    let isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected {
            content.background(Theme.cream, in: Capsule())
        } else {
            content.glassCapsule(interactive: true)
        }
    }
}

#Preview {
    HStack {
        Chip(title: "All", count: 42, isSelected: true) {}
        Chip(title: "Trending", isSelected: false) {}
        Chip(title: "Pokémon", count: 12, isSelected: false) {}
    }
    .padding(40)
    .background(VaultBackground())
}
