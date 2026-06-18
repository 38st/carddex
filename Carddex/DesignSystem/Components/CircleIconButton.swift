import SwiftUI

/// Circular "glass" icon button — back, more, header actions, grid toggle.
/// `prominent` fills it with cream for primary affordances (e.g. the like heart).
struct CircleIconButton: View {
    let systemImage: String
    var size: CGFloat = 44
    var prominent: Bool = false
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint ?? (prominent ? Theme.onCream : Theme.textPrimary))
                .frame(width: size, height: size)
                .background {
                    if prominent {
                        Circle().fill(Theme.cream)
                    } else {
                        Circle().fill(Theme.surface)
                        Circle().strokeBorder(Theme.hairline)
                    }
                }
        }
        .buttonStyle(PressableStyle())
    }
}

extension View {
    /// Styles an icon as the circular "glass" chip — for `Menu` / `NavigationLink`
    /// labels where a plain `Button` (and `CircleIconButton`) won't fit.
    func circleIconChip(size: CGFloat = 44) -> some View {
        self.font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.surface))
            .overlay(Circle().strokeBorder(Theme.hairline))
    }
}

#Preview {
    HStack(spacing: 16) {
        CircleIconButton(systemImage: "chevron.left") {}
        CircleIconButton(systemImage: "ellipsis") {}
        CircleIconButton(systemImage: "heart.fill", prominent: true) {}
        CircleIconButton(systemImage: "heart", tint: Theme.loss) {}
    }
    .padding(40)
    .background(VaultBackground())
}
