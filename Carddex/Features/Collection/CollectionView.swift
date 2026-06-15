import SwiftUI

/// Grid of owned cards with search, sort, a per-game/sport filter, and a Sets mode
/// showing set completion as binder pages — the "Pokédex".
struct CollectionView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var selectedGame: CardGame?
    @State private var selectedSport: SportCategory?
    @State private var mode: Mode = .grid
    @State private var searchText = ""
    @State private var sort: SortOption = .recent
    @Namespace private var cardNamespace

    enum Mode: String, CaseIterable, Identifiable {
        case grid = "Grid"
        case sets = "Sets"
        var id: String { rawValue }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case recent = "Recent", value = "Value", name = "Name", set = "Set"
        var id: String { rawValue }
        var comparator: (CollectionItem, CollectionItem) -> Bool {
            switch self {
            case .recent: { $0.dateAdded > $1.dateAdded }
            case .value: { $0.estimatedValue.amount > $1.estimatedValue.amount }
            case .name: { $0.card.name < $1.card.name }
            case .set: { $0.card.setName < $1.card.setName }
            }
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: Theme.Spacing.md)]

    private var filteredItems: [CollectionItem] {
        var items = store.items(for: selectedGame)
        if selectedGame == .sports, let sport = selectedSport {
            items = items.filter { $0.card.sport == sport }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.card.name.lowercased().contains(q)
                    || $0.card.setName.lowercased().contains(q)
                    || $0.card.number.lowercased().contains(q)
            }
        }
        return items.sorted(by: sort.comparator)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                header

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
            .tabBarSafeArea()
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(SortOption.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .navigationDestination(for: CollectionItem.self) { item in
                CardDetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: cardNamespace))
            }
        }
    }

    private var header: some View {
        HStack {
            Label("\(store.totalCards) cards", systemImage: "square.stack")
            Spacer()
            Text(store.totalValue.formatted)
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal)
        .padding(.top, Theme.Spacing.xs)
    }

    @ViewBuilder private var gridContent: some View {
        if store.items.isEmpty {
            EmptyState(
                icon: "square.grid.2x2",
                title: "No cards yet",
                message: "Scan a card to start your collection.",
                actionTitle: "Scan your first card",
                actionIcon: "viewfinder",
                action: { router.selectedTab = .scan }
            )
            .padding(.top, Theme.Spacing.xxxl)
        } else {
            gameFilterBar
            if selectedGame == .sports {
                sportFilterBar
            }
            if filteredItems.isEmpty {
                EmptyState(
                    icon: "magnifyingglass",
                    title: "No matches",
                    message: "No cards match this filter or search."
                )
                .padding(.top, Theme.Spacing.xl)
            } else {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item) {
                            CardCell(item: item)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: item.id, in: cardNamespace)
                    }
                }
                .padding()
            }
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
                FilterChip(title: "All", count: store.items.count, isSelected: selectedGame == nil) {
                    select(game: nil)
                }
                ForEach(CardGame.allCases) { game in
                    FilterChip(title: game.displayName, count: store.items(for: game).count, isSelected: selectedGame == game) {
                        select(game: game)
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
                    Haptics.selection()
                    selectedSport = nil
                }
                ForEach(SportCategory.allCases) { sport in
                    let count = store.items.filter { $0.card.sport == sport }.count
                    FilterChip(title: sport.displayName, count: count, isSelected: selectedSport == sport) {
                        Haptics.selection()
                        selectedSport = sport
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func select(game: CardGame?) {
        Haptics.selection()
        selectedGame = game
        selectedSport = nil
    }
}

private struct FilterChip: View {
    let title: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let count {
                    Text("\(count)")
                        .opacity(isSelected ? 0.85 : 0.55)
                }
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
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
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}
