import SwiftUI
import UIKit

/// Detail screen for a single owned card — holo hero with gyroscope tilt,
/// stats, and actions.
struct CardDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var motion = MotionManager()
    @State private var showSell = false
    @State private var shareImage: Image?
    let item: CollectionItem

    private func clamp(_ value: Double, _ limit: Double) -> Double {
        max(-limit, min(limit, value))
    }

    private var priceHistory: [Double] {
        let price = NSDecimalNumber(decimal: item.card.marketPrice?.amount ?? 0).doubleValue
        let shape: [Double] = [0.72, 0.78, 0.75, 0.83, 0.80, 0.88, 0.92, 0.90, 0.96, 1.0]
        return shape.map { $0 * price }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                CardArtwork(
                    game: item.card.game,
                    rarity: item.card.rarity,
                    price: item.card.marketPrice,
                    imageURL: item.card.imageURL,
                    sport: item.card.sport,
                    cornerRadius: Theme.Radius.lg
                )
                .frame(maxWidth: 220)
                .rotation3DEffect(.degrees(clamp(motion.pitch * 16, 8) + 3), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(clamp(motion.roll * 16, 8)), axis: (x: 0, y: 1, z: 0))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
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

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Price trend")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    MiniAreaChart(values: priceHistory)
                        .frame(height: 70)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    store.remove(item)
                    dismiss()
                } label: {
                    Label("Remove from collection", systemImage: "trash")
                }
                .tint(Theme.loss)
                .padding(.top, Theme.Spacing.xs)
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
        .onAppear {
            motion.start()
            renderShareImage()
        }
        .onDisappear { motion.stop() }
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
