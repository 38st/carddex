import SwiftUI

/// The app's main call-to-action — a cream pill with dark text.
/// `.hero` renders the reference's "label pill inside a dark track + › › ›" look.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var style: Style = .filled
    let action: () -> Void

    enum Style { case filled, hero }

    var body: some View {
        Button(action: action) {
            switch style {
            case .filled:
                HStack(spacing: Theme.Spacing.sm) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title).fontWeight(.semibold)
                }
                .foregroundStyle(Theme.onCream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.cream, in: Capsule())
            case .hero:
                HStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        if let systemImage { Image(systemName: systemImage) }
                        Text(title).fontWeight(.semibold)
                    }
                    .foregroundStyle(Theme.onCream)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 26)
                    .background(Theme.cream, in: Capsule())
                    Spacer(minLength: 0)
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "chevron.right")
                                .opacity(1 - Double(i) * 0.32)
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 20)
                }
                .padding(6)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
            }
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Add to collection", systemImage: "plus") {}
        PrimaryButton(title: "Get Started", style: .hero) {}
    }
    .padding()
    .background(VaultBackground())
}
