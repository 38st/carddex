import SwiftUI

/// Grid cell for a collection item: artwork (holo if rare), name, set, and price.
struct CardCell: View {
    let item: CollectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            CardArtwork(game: item.card.game, rarity: item.card.rarity, price: item.card.marketPrice)
                .overlay(alignment: .topTrailing) {
                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.hairline))
                            .padding(6)
                    }
                }

            Text(item.card.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(item.card.setName)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            if let price = item.card.marketPrice {
                Text(price.formatted)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
        }
    }
}
