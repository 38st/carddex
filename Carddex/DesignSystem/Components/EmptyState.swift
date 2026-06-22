import SwiftUI

/// Centered placeholder shown when a screen has no content yet — styled as an
/// empty display case: a spotlit ghost card slot waiting to be filled.
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.cream.opacity(0.20), .clear],
                                         center: .center, startRadius: 0, endRadius: 130))
                    .frame(width: 260, height: 260)

                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 118, height: 165)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(Theme.textTertiary.opacity(0.55),
                                          style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                    )
                    .shadow(color: .black.opacity(0.4), radius: 14, y: 10)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.cream)
            }
            .frame(height: 200)

            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, systemImage: actionIcon, action: action)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding()
    }
}
