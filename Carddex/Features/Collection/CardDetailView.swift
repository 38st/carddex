import SwiftUI
import UIKit

/// Detail screen for a single owned card — holo hero with gyroscope tilt,
/// stats, and actions.
struct CardDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showSell = false
    @State private var showRemoveConfirm = false
    @State private var shareImage: Image?
    let item: CollectionItem

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                LivingCardView(
                    game: item.card.game,
                    rarity: item.card.rarity,
                    price: item.card.marketPrice,
                    imageURL: item.card.imageURL,
                    sport: item.card.sport,
                    maxWidth: 220
                )
                .padding(.top, Theme.Spacing.sm)

                VStack(spacing: Theme.Spacing.sm) {
                    GamePill(game: item.card.game, sport: item.card.sport)
                    Text(item.card.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("\(item.card.setName) · \(item.card.number)")
                        .foregroundStyle(Theme.textSecondary)
                    if let rarity = item.card.rarity {
                        Text(rarity)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                HStack(spacing: Theme.Spacing.md) {
                    StatTile(title: "Market", value: item.card.marketPrice?.formatted ?? "—")
                    StatTile(title: "Qty", value: "\(item.quantity)")
                    StatTile(title: "Value", value: item.estimatedValue.formatted, accent: Theme.gain)
                }

                if item.hasCostBasis {
                    let gain = NSDecimalNumber(decimal: item.gainLoss.amount).doubleValue
                    HStack(spacing: Theme.Spacing.md) {
                        StatTile(title: "Paid", value: item.costBasis.formatted)
                        StatTile(
                            title: gain >= 0 ? "Gain" : "Loss",
                            value: "\(gain >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(gain))).formatted)",
                            accent: gain >= 0 ? Theme.gain : Theme.loss
                        )
                    }
                }

                CardPriceChart(basePrice: NSDecimalNumber(decimal: item.card.marketPrice?.amount ?? 0).doubleValue)
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.card)

                VStack(spacing: Theme.Spacing.sm) {
                    LabeledContent("Condition", value: item.condition.rawValue)
                    Divider().overlay(Theme.hairline)
                    LabeledContent("Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)

                PrimaryButton(title: "List on eBay", systemImage: "tag") { showSell = true }

                Button(role: .destructive) {
                    showRemoveConfirm = true
                } label: {
                    Label("Remove from collection", systemImage: "trash")
                }
                .tint(Theme.loss)
                .padding(.top, Theme.Spacing.xs)
                .confirmationDialog("Remove this card?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) {
                        Haptics.warning()
                        store.remove(item)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding()
        }
        .navigationTitle(item.card.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSell) { SellSheet(item: item) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(item.card.name, image: shareImage)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear { renderShareImage() }
    }

    @MainActor private func renderShareImage() {
        let poster = ShareableCardPoster(
            name: item.card.name,
            setLine: "\(item.card.setName) · \(item.card.number)",
            price: item.card.marketPrice?.formatted ?? "—",
            game: item.card.game,
            sport: item.card.sport
        )
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(item: SampleData.collection[0])
            .environment(CollectionStore(items: SampleData.collection))
    }
    .preferredColorScheme(.dark)
}
