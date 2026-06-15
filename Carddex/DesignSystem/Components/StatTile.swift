import SwiftUI

/// Compact labeled metric used on detail and portfolio screens.
struct StatTile: View {
    let title: String
    let value: String
    var accent: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}
