import SwiftUI

/// Grid of owned cards with a per-game filter — the "Pokédex" view.
struct CollectionView: View {
    @Environment(CollectionStore.self) private var store
    @State private var selectedGame: CardGame?

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: Theme.Spacing.md)]

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    EmptyState(
                        icon: "square.grid.2x2",
                        title: "No cards yet",
                        message: "Scan a card to start your collection."
                    )
                } else {
                    ScrollView {
                        filterBar
                        LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                            ForEach(store.items(for: selectedGame)) { item in
                                NavigationLink(value: item) {
                                    CardCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Collection")
            .navigationDestination(for: CollectionItem.self) { item in
                CardDetailView(item: item)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "All", isSelected: selectedGame == nil) {
                    selectedGame = nil
                }
                ForEach(CardGame.allCases) { game in
                    FilterChip(title: game.displayName, isSelected: selectedGame == game) {
                        selectedGame = game
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, Theme.Spacing.sm)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.thinMaterial),
                    in: Capsule()
                )
        }
    }
}

#Preview {
    CollectionView()
        .environment(CollectionStore(items: SampleData.collection))
}
