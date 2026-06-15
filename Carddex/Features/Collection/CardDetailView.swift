import SwiftUI

/// Detail screen for a single owned card.
struct CardDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: CollectionItem

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                CardArtwork(game: item.card.game, cornerRadius: Theme.Radius.lg)
                    .frame(maxWidth: 220)

                VStack(spacing: Theme.Spacing.sm) {
                    GamePill(game: item.card.game)
                    Text(item.card.name)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("\(item.card.setName) · \(item.card.number)")
                        .foregroundStyle(.secondary)
                    if let rarity = item.card.rarity {
                        Text(rarity)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: Theme.Spacing.md) {
                    StatTile(title: "Market", value: item.card.marketPrice?.formatted ?? "—")
                    StatTile(title: "Qty", value: "\(item.quantity)")
                    StatTile(title: "Value", value: item.estimatedValue.formatted, accent: .green)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    LabeledContent("Condition", value: item.condition.rawValue)
                    Divider()
                    LabeledContent("Added", value: item.dateAdded.formatted(date: .abbreviated, time: .omitted))
                }
                .padding(Theme.Spacing.md)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

                Button {
                    // Phase 3: kicks off the eBay listing flow.
                } label: {
                    Label("List on eBay", systemImage: "tag")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .disabled(true)

                Button(role: .destructive) {
                    store.remove(item)
                    dismiss()
                } label: {
                    Label("Remove from collection", systemImage: "trash")
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding()
        }
        .navigationTitle(item.card.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CardDetailView(item: SampleData.collection[0])
            .environment(CollectionStore(items: SampleData.collection))
    }
}
