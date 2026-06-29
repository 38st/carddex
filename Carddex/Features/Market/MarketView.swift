import SwiftUI

/// The Market — a Card Ladder-style view of the card market: the Carddex Index,
/// your watchlist, movers, category filters, and a searchable, sports-first database.
struct MarketView: View {
    @Environment(WatchlistStore.self) private var watchlist
    @Environment(MarketStore.self) private var marketStore
    @State private var search = ""
    @State private var filter: MarketFilter?
    @State private var showCompare = false
    @State private var showAlerts = false
    @State private var indexRange: IndexRange = .month
    @State private var moverSide: MoverSide = .gainers
    @State private var sortKey: SortKey = .topMovers

    enum MarketFilter: Hashable {
        case sport(SportCategory)
        case game(CardGame)
    }

    enum MoverSide: String, CaseIterable, Identifiable {
        case gainers = "Gainers", losers = "Losers"
        var id: String { rawValue }
    }

    enum SortKey: String, CaseIterable, Identifiable {
        case topMovers = "Top movers"
        case priceHigh = "Price: high → low"
        case priceLow = "Price: low → high"
        case alpha = "Name: A–Z"
        var id: String { rawValue }
    }

    private func change(_ card: Card) -> Double { marketStore.market[card.id]?.change30d ?? 0 }

    private func price(_ card: Card) -> Double {
        NSDecimalNumber(decimal: (marketStore.market[card.id]?.topPrice ?? card.marketPrice ?? .zero).amount).doubleValue
    }

    private func matches(_ card: Card) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .sport(let sport): return card.game == .sports && card.sport == sport
        case .game(let game): return card.game == game
        }
    }

    private var results: [Card] {
        let filtered = SampleData.marketCards.filter { card in
            matches(card) && (search.isEmpty
                || card.name.lowercased().contains(search.lowercased())
                || card.setName.lowercased().contains(search.lowercased()))
        }
        switch sortKey {
        case .topMovers: return filtered.sorted { abs(change($0)) > abs(change($1)) }
        case .priceHigh: return filtered.sorted { price($0) > price($1) }
        case .priceLow: return filtered.sorted { price($0) < price($1) }
        case .alpha: return filtered.sorted { $0.name < $1.name }
        }
    }

    private var gainers: [Card] {
        SampleData.marketCards.filter(matches).filter { change($0) > 0 }.sorted { change($0) > change($1) }
    }

    private var losers: [Card] {
        SampleData.marketCards.filter(matches).filter { change($0) < 0 }.sorted { change($0) < change($1) }
    }

    private var shownMovers: [Card] { moverSide == .gainers ? gainers : losers }

    private var watched: [Card] {
        SampleData.marketCards.filter { watchlist.isFollowing($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ScreenHeader(title: "Market") {
                        GlassGroup(spacing: 10) {
                            HStack(spacing: 10) {
                                CircleIconButton(systemImage: watchlist.alerts.isEmpty ? "bell" : "bell.badge.fill", label: "Alerts") {
                                    showAlerts = true
                                }
                                CircleIconButton(systemImage: "rectangle.portrait.on.rectangle.portrait", label: "Compare") {
                                    showCompare = true
                                }
                            }
                        }
                    }

                    SearchField(text: $search, prompt: "Search the market")
                        .padding(.horizontal)

                    if search.isEmpty, let top = shownMovers.first ?? results.first {
                        NavigationLink(value: top) {
                            FeaturedCard(
                                card: top,
                                eyebrow: moverSide == .gainers ? "Top mover" : "Biggest dip",
                                trailingValue: (marketStore.market[top.id]?.topPrice ?? top.marketPrice ?? .zero).formatted,
                                trailingDelta: "\(change(top) >= 0 ? "+" : "")\(String(format: "%.1f", change(top)))%",
                                deltaUp: change(top) >= 0,
                                isLiked: watchlist.isFollowing(top.id),
                                onLike: { Haptics.impact(.light); watchlist.toggleFollow(top.id) }
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    indexCard

                    sectionTitle("Indices")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(SampleData.categoryIndices) { entry in
                                NavigationLink(value: entry) { IndexTile(entry: entry) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    categoryBar

                    if search.isEmpty && !watched.isEmpty {
                        sectionTitle("Watchlist")
                        cardList(watched)
                    }

                    if search.isEmpty {
                        HStack {
                            sectionTitle("Movers")
                            Spacer()
                            moverToggle.padding(.trailing)
                        }
                        if shownMovers.isEmpty {
                            Text("No \(moverSide.rawValue.lowercased()) in this category")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.md) {
                                    ForEach(shownMovers) { card in
                                        NavigationLink(value: card) { MoverCard(card: card) }
                                            .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    HStack {
                        sectionTitle(search.isEmpty ? "Top cards" : "Results")
                        Spacer()
                        sortMenu.padding(.trailing)
                    }
                    cardList(results, ranked: true)
                }
                .padding(.vertical)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabBarSafeArea()
            .navigationDestination(for: Card.self) { card in
                MarketCardView(card: card)
            }
            .navigationDestination(for: MarketIndexEntry.self) { entry in
                IndexDetailView(entry: entry)
            }
            .sheet(isPresented: $showCompare) { ComparisonView() }
            .sheet(isPresented: $showAlerts) { AlertsView() }
        }
    }

    private func cardList(_ cards: [Card], ranked: Bool = false) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                NavigationLink(value: card) { MarketRow(card: card, rank: ranked ? index + 1 : nil) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func sectionTitle(_ text: String) -> some View {
        SectionHeader(text)
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.xs)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassGroup(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Chip(title: "All", isSelected: filter == nil) { filter = nil }
                    ForEach(SportCategory.allCases) { sport in
                        Chip(title: sport.displayName, isSelected: filter == .sport(sport)) {
                            filter = .sport(sport)
                        }
                    }
                    ForEach([CardGame.pokemon, .magic, .yugioh]) { game in
                        Chip(title: game.displayName, isSelected: filter == .game(game)) {
                            filter = .game(game)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var indexCard: some View {
        let index = marketStore.index
        let change = index.change(for: indexRange)
        let up = change >= 0
        let accent = up ? Theme.gain : Theme.loss
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("Case Index", systemImage: "chart.xyaxis.line")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(up ? "+" : "")\(String(format: "%.1f", change))% · \(indexRange.rawValue)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.16), in: Capsule())
            }
            RollingNumber(
                index.value,
                format: { $0.formatted(.number.precision(.fractionLength(2))) },
                size: 46
            )
            MiniAreaChart(values: index.series(for: indexRange), tint: accent, interactive: true)
                .frame(height: 96)
                .animation(.easeInOut(duration: 0.35), value: indexRange)
            RangeSelector(selection: $indexRange)
        }
        .padding(Theme.Spacing.lg)
        .glassCard(cornerRadius: Theme.Radius.xl)
        .padding(.horizontal)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortKey.allCases) { key in
                Button {
                    Haptics.selection()
                    sortKey = key
                } label: {
                    if sortKey == key {
                        Label(key.rawValue, systemImage: "checkmark")
                    } else {
                        Text(key.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Sort")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var moverToggle: some View {
        HStack(spacing: 0) {
            ForEach(MoverSide.allCases) { side in
                let selected = moverSide == side
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.2)) { moverSide = side }
                } label: {
                    Text(side.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(selected ? .white : Theme.textSecondary)
                        .background {
                            if selected {
                                Capsule().fill(side == .gainers ? Theme.gain : Theme.loss)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .glassCapsule()
    }
}

struct MarketRow: View {
    @Environment(MarketStore.self) private var marketStore
    let card: Card
    var rank: Int? = nil

    var body: some View {
        let market = marketStore.market[card.id]
        let change = market?.change30d ?? 0
        let up = change >= 0
        HStack(spacing: Theme.Spacing.sm) {
            if let rank {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 18, alignment: .center)
            }
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(card.setName).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.sm)
            if market != nil {
                MiniAreaChart(values: SampleData.priceSeries(change30d: change, range: .month, seed: card.id),
                              tint: up ? Theme.gain : Theme.loss)
                    .frame(width: 50, height: 26)
                    .opacity(0.9)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text((market?.topPrice ?? card.marketPrice ?? .zero).formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if market != nil {
                    Text("\(up ? "+" : "")\(String(format: "%.1f", change))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(up ? Theme.gain : Theme.loss)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

private struct MoverCard: View {
    @Environment(MarketStore.self) private var marketStore
    let card: Card

    var body: some View {
        let market = marketStore.market[card.id]
        VStack(alignment: .leading, spacing: 8) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 94)
            Text(card.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text((market?.topPrice ?? .zero).formatted)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
            if let change = market?.change30d {
                Text("\(change >= 0 ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
            }
        }
        .frame(width: 114)
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}


private struct IndexTile: View {
    @Environment(MarketStore.self) private var marketStore
    let entry: MarketIndexEntry
    var body: some View {
        let change = marketStore.indexChange(entry.memberIDs, range: .month)
        let up = change >= 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: entry.symbolName).font(.caption).foregroundStyle(entry.accent)
                Text(entry.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
            }
            MiniAreaChart(values: marketStore.indexSeries(entry.memberIDs, range: .month), tint: up ? Theme.gain : Theme.loss)
                .frame(height: 40)
            Text("\(up ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(up ? Theme.gain : Theme.loss)
        }
        .frame(width: 150)
        .padding(Theme.Spacing.md)
        .glassCard(cornerRadius: Theme.Radius.card)
    }
}

#Preview {
    MarketView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(WatchlistStore(followed: [SampleData.jordan.id]))
        .environment(MarketStore())
        .preferredColorScheme(Theme.appColorScheme)
}
