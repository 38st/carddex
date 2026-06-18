import SwiftUI

/// The app's top-of-screen header: an optional avatar, a title + subtitle, and
/// trailing controls (typically `CircleIconButton`s). Replaces the system large
/// navigation title on the main tabs.
struct ScreenHeader<Trailing: View>: View {
    private let avatarSystemImage: String?
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    init(
        avatarSystemImage: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.avatarSystemImage = avatarSystemImage
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let avatarSystemImage {
                Image(systemName: avatarSystemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.onCream)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.cream))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(24))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal)
        .padding(.top, Theme.Spacing.sm)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(avatarSystemImage: String? = nil, title: String, subtitle: String? = nil) {
        self.init(avatarSystemImage: avatarSystemImage, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ScreenHeader(avatarSystemImage: "person.fill", title: "Helo Pamaddog", subtitle: "1.2k cards") {
            CircleIconButton(systemImage: "square.grid.2x2") {}
        }
        ScreenHeader(title: "Market")
    }
    .padding(.vertical)
    .background(VaultBackground())
}
