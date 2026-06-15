import SwiftUI

/// Grid cell for a collection item: artwork, name, set, and price.
struct CardCell: View {
    let item: CollectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            CardArtwork(game: item.card.game)
                .overlay(alignment: .topTrailing) {
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(6)
                    }
                }

            Text(item.card.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(item.card.setName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let price = item.card.marketPrice {
                Text(price.formatted)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}
