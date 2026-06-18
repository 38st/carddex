import SwiftUI

/// The app's section header: a bold rounded title with an optional trailing
/// "See All" action (the reference's "All Collection · See All" pattern).
struct SectionHeader: View {
    let title: String
    var seeAllAction: (() -> Void)? = nil

    init(_ title: String, seeAllAction: (() -> Void)? = nil) {
        self.title = title
        self.seeAllAction = seeAllAction
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.display(18))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let seeAllAction {
                Button(action: seeAllAction) {
                    HStack(spacing: 3) {
                        Text("See All").font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SectionHeader("All Collection", seeAllAction: {})
        SectionHeader("Recent sales")
    }
    .padding()
    .background(VaultBackground())
}
