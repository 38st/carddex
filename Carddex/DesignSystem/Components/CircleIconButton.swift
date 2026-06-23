import SwiftUI

/// Circular "glass" icon button — back, more, header actions, grid toggle.
/// `prominent` fills it with cream for primary affordances (e.g. the like heart).
struct CircleIconButton: View {
    let systemImage: String
    /// VoiceOver label — icon-only buttons need one to be readable.
    var label: String
    var size: CGFloat = 44
    var prominent: Bool = false
    var tint: Color? = nil
    let action: () -> Void

    init(systemImage: String, label: String, size: CGFloat = 44, prominent: Bool = false, tint: Color? = nil, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.size = size
        self.prominent = prominent
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Group {
                if prominent {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(tint ?? Theme.onCream)
                        .frame(width: size, height: size)
                        .background(Circle().fill(Theme.cream))
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundStyle(tint ?? Theme.textPrimary)
                        .frame(width: size, height: size)
                        .glassCircle(interactive: true)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

extension View {
    /// Styles an icon as the circular "glass" chip — for `Menu` / `NavigationLink`
    /// labels where a plain `Button` (and `CircleIconButton`) won't fit.
    func circleIconChip(size: CGFloat = 44, label: String) -> some View {
        self.font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: size, height: size)
            .glassCircle(interactive: true)
            .accessibilityLabel(label)
    }
}

#Preview {
    HStack(spacing: 16) {
        CircleIconButton(systemImage: "chevron.left", label: "Back") {}
        CircleIconButton(systemImage: "ellipsis", label: "More") {}
        CircleIconButton(systemImage: "heart.fill", label: "Like", prominent: true) {}
        CircleIconButton(systemImage: "heart", label: "Like", tint: Theme.loss) {}
    }
    .padding(40)
    .background(VaultBackground())
}
