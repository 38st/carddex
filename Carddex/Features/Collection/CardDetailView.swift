import SwiftUI

/// Detail screen for a single owned card — holo hero with gyroscope tilt,
/// stats, and actions.
struct CardDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var motion = MotionManager()
    let item: CollectionItem

    private func clamp(_ value: Double, _ limit: Double) -> Double {
        max(-limit, min(limit, value))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                CardArtwork(
                    game: item.card.game,
                    rarity: item.card.rarity,
                    price: item.card.marketPrice,
                    imageURL: item.card.imageURL,
                    cornerRadius: Theme.Radius.lg
                )
                .frame(maxWidth: 220)
                .rotation3DEffect(.degrees(clamp(motion.pitch * 16, 8) + 3), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(clamp(motion.roll * 16, 8)), axis: (x: 0, y: 1, z: 0))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
                .padding(.top, Theme.Spacing.sm)

                VStack(spacing: Theme.Spacing.sm) {
                    GamePill(game: item.card.game)
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

                VStack(spacing: Theme.Spacing.sm) {
                    LabeledContent("Condition", value: item.condition.rawValue)
                    Divider().overlay(Theme.hairline)
                    LabeledContent("Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)

                PrimaryButton(title: "List on eBay", systemImage: "tag") {}

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
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(item: SampleData.collection[0])
            .environment(CollectionStore(items: SampleData.collection))
    }
    .preferredColorScheme(.dark)
}
