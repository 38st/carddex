import SwiftUI

/// Grid of owned cards with search, sort, a per-game/sport filter, and a Sets mode
/// showing set completion as binder pages — the "Pokédex".
struct CollectionView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(WishlistStore.self) private var wishlist
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

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

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
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ScreenHeader(title: "Collection", subtitle: "\(store.totalCards) cards") {
                        GlassGroup(spacing: 10) {
                            HStack(spacing: 10) {
                                NavigationLink {
                                    GrailsView()
                                } label: {
                                    Image(systemName: wishlist.grails.isEmpty ? "heart" : "heart.fill")
                                        .circleIconChip()
                                }
                                Menu {
                                    Picker("Sort", selection: $sort) {
                                        ForEach(SortOption.allCases) { Text($0.rawValue).tag($0) }
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down").circleIconChip()
                                }
                            }
                        }
                    }

                    if let featured = store.items.max(by: { $0.estimatedValue.amount < $1.estimatedValue.amount }) {
                        NavigationLink(value: featured) {
                            FeaturedCard(
                                card: featured.card,
                                eyebrow: "Top card",
                                trailingValue: featured.estimatedValue.formatted
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    valueStats

                    SearchField(text: $searchText, prompt: "Search cards")
                        .padding(.horizontal)

                    SegmentTabs(selection: $mode, items: [(.grid, "Grid"), (.sets, "Sets")])
                        .padding(.horizontal)

                    switch mode {
                    case .grid: gridContent
                    case .sets: setsContent
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabBarSafeArea()
            .navigationDestination(for: CollectionItem.self) { item in
                CardDetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: cardNamespace))
            }
            .navigationDestination(for: CardSet.self) { set in
                SetDetailView(cardSet: set)
            }
        }
    }

    private var valueStats: some View {
        let gain = NSDecimalNumber(decimal: store.totalGainLoss.amount).doubleValue
        let up = gain >= 0
        return HStack(spacing: Theme.Spacing.sm) {
            StatPill(icon: "dollarsign.circle.fill", title: "Collection value", value: store.totalValue.formatted)
            if store.totalCost.amount > 0 {
                StatPill(
                    icon: up ? "arrow.up.right" : "arrow.down.right",
                    title: up ? "All-time gain" : "All-time loss",
                    value: "\(up ? "+" : "−")\(Money(amount: Decimal(abs(gain))).formatted) (\(String(format: "%.0f", abs(store.gainLossPercent)))%)",
                    accent: up ? Theme.gain : Theme.loss
                )
            }
        }
        .padding(.horizontal)
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
        let sets = filteredSets
        gameFilterBar
        if sets.isEmpty {
            EmptyState(
                icon: "square.stack.3d.up",
                title: "No sets here",
                message: "No sets match this filter. Switch the filter or scan more cards to grow your completion."
            )
            .padding(.top, Theme.Spacing.xl)
        } else {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(sets) { set in
                    NavigationLink(value: set) { SetRow(set: set) }
                        .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    /// Sets filtered by the same game/sport selection as the grid, plus search.
    private var filteredSets: [CardSet] {
        SampleData.sets.filter { set in
            if let selectedGame, set.game != selectedGame { return false }
            return true
        }
    }

    private var gameFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Chip(title: "All", count: store.items.count, isSelected: selectedGame == nil) {
                        select(game: nil)
                    }
                    ForEach(CardGame.allCases) { game in
                        Chip(title: game.displayName, count: store.items(for: game).count, isSelected: selectedGame == game) {
                            select(game: game)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var sportFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Chip(title: "All sports", isSelected: selectedSport == nil) {
                        selectedSport = nil
                    }
                    ForEach(SportCategory.allCases) { sport in
                        let count = store.items.filter { $0.card.sport == sport }.count
                        Chip(title: sport.displayName, count: count, isSelected: selectedSport == sport) {
                            selectedSport = sport
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func select(game: CardGame?) {
        Haptics.selection()
        selectedGame = game
        selectedSport = nil
    }
}

/// A row in the Sets browser: set name, game pill, completion ring, owned/total,
/// and a count of missing cards the user could add to their grail list.
private struct SetRow: View {
    @Environment(CollectionStore.self) private var store
    @Environment(WishlistStore.self) private var wishlist
    let set: CardSet

    var body: some View {
        let progress = store.completion(for: set)
        let fraction = progress.total > 0 ? Double(progress.owned) / Double(progress.total) : 0
        let groundedMissing = set.slots.filter { slot in
            slot.cardID != nil && store.ownedCard(setName: set.name, number: slot.number) == nil
        }.count
        let grailsInSet = set.slots.filter { slot in
            slot.cardID.map { wishlist.contains($0) } ?? false
        }.count

        return HStack(spacing: Theme.Spacing.md) {
            CompletionRing(fraction: fraction, label: "\(progress.owned)/\(progress.total)")
            VStack(alignment: .leading, spacing: 4) {
                Text(set.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                GamePill(game: set.game)
                HStack(spacing: 6) {
                    Text("\(progress.owned) of \(set.total) owned")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                    if groundedMissing > 0 {
                        Text("· \(groundedMissing) to grail")
                            .font(.caption)
                            .foregroundStyle(grailsInSet > 0 ? Theme.cream : Theme.textTertiary)
                            .monospacedDigit()
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(fraction >= 1 ? Theme.gain.opacity(0.4) : .clear, lineWidth: 1)
        )
    }
}

#Preview {
    CollectionView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppRouter())
        .environment(WishlistStore())
        .preferredColorScheme(.dark)
}
