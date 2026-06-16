import SwiftUI

/// The app's section header: an accent tick + uppercase tracked label. One look
/// across every screen so the UI feels of-a-piece.
struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 3, height: 13)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.3)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
