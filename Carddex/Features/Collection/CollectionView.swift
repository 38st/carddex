import SwiftUI

/// Grid of owned cards with a per-game filter (and a sport sub-filter for sports
/// cards), plus a Sets mode showing set completion as binder pages — the "Pokédex".
struct CollectionView: View {
    @Environment(CollectionStore.self) private var store
    @State private var selectedGame: CardGame?
    @State private var selectedSport: SportCategory?
    @State private var mode: Mode = .grid

    enum Mode: String, CaseIterable, Identifiable {
        case grid = "Grid"
        case sets = "Sets"
        var id: String { rawValue }
    }

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: Theme.Spacing.md)]

    private var filteredItems: [CollectionItem] {
        let base = store.items(for: selectedGame)
        if selectedGame == .sports, let sport = selectedSport {
            return base.filter { $0.card.sport == sport }
        }
        return base
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, Theme.Spacing.sm)

                switch mode {
                case .grid: gridContent
                case .sets: setsContent
                }
            }
            .navigationTitle("Collection")
            .navigationDestination(for: CollectionItem.self) { item in
                CardDetailView(item: item)
            }
        }
    }

    @ViewBuilder private var gridContent: some View {
        if store.items.isEmpty {
            EmptyState(
                icon: "square.grid.2x2",
                title: "No cards yet",
                message: "Scan a card to start your collection."
            )
            .padding(.top, Theme.Spacing.xxxl)
        } else {
            gameFilterBar
            if selectedGame == .sports {
                sportFilterBar
            }
            LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                ForEach(filteredItems) { item in
                    NavigationLink(value: item) {
                        CardCell(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    @ViewBuilder private var setsContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ForEach(SampleData.sets) { set in
                BinderPageView(set: set)
            }
        }
        .padding()
    }

    private var gameFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "All", isSelected: selectedGame == nil) {
                    selectedGame = nil
                    selectedSport = nil
                }
                ForEach(CardGame.allCases) { game in
                    FilterChip(title: game.displayName, isSelected: selectedGame == game) {
                        selectedGame = game
                        selectedSport = nil
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.sm)
        }
    }

    private var sportFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "All sports", isSelected: selectedSport == nil) {
                    selectedSport = nil
                }
                ForEach(SportCategory.allCases) { sport in
                    FilterChip(title: sport.displayName, isSelected: selectedSport == sport) {
                        selectedSport = sport
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
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .background(
                    isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.ultraThinMaterial),
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(isSelected ? .clear : Theme.hairline))
        }
    }
}

#Preview {
    CollectionView()
        .environment(CollectionStore(items: SampleData.collection))
        .preferredColorScheme(.dark)
}
