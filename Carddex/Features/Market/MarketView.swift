import SwiftUI

/// The Market — a Card Ladder-style view of the card market: the Carddex Index,
/// your watchlist, movers, category filters, and a searchable, sports-first database.
struct MarketView: View {
    @Environment(WatchlistStore.self) private var watchlist
    @State private var search = ""
    @State private var filter: MarketFilter?
    @State private var showCompare = false

    enum MarketFilter: Hashable {
        case sport(SportCategory)
        case game(CardGame)
    }

    private func change(_ card: Card) -> Double { SampleData.market[card.id]?.change30d ?? 0 }

    private func matches(_ card: Card) -> Bool {
        guard let filter else { return true }
        switch filter {
        case .sport(let sport): return card.game == .sports && card.sport == sport
        case .game(let game): return card.game == game
        }
    }

    private var results: [Card] {
        SampleData.marketCards.filter { card in
            matches(card) && (search.isEmpty
                || card.name.lowercased().contains(search.lowercased())
                || card.setName.lowercased().contains(search.lowercased()))
        }
    }

    private var movers: [Card] {
        SampleData.marketCards.filter(matches).sorted { abs(change($0)) > abs(change($1)) }
    }

    private var watched: [Card] {
        SampleData.marketCards.filter { watchlist.isFollowing($0.id) }
    }

    struct SaleEntry: Identifiable {
        let card: Card
        let sale: Sale
        var id: UUID { sale.id }
    }

    private var recentSales: [SaleEntry] {
        SampleData.marketCards
            .flatMap { card in (SampleData.market[card.id]?.recentSales ?? []).map { SaleEntry(card: card, sale: $0) } }
            .sorted { $0.sale.date > $1.sale.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
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

                    if search.isEmpty && !movers.isEmpty {
                        sectionTitle("Movers")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.md) {
                                ForEach(movers) { card in
                                    NavigationLink(value: card) { MoverCard(card: card) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    sectionTitle(search.isEmpty ? "Top cards" : "Results")
                    cardList(results)

                    if search.isEmpty {
                        sectionTitle("Recent sales")
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(recentSales.prefix(8)) { entry in
                                SaleRow(card: entry.card, sale: entry.sale)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Market")
            .tabBarSafeArea()
            .searchable(text: $search, prompt: "Search the market")
            .navigationDestination(for: Card.self) { card in
                MarketCardView(card: card)
            }
            .navigationDestination(for: MarketIndexEntry.self) { entry in
                IndexDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Compare") { showCompare = true }
                }
            }
            .sheet(isPresented: $showCompare) { ComparisonView() }
        }
    }

    private func cardList(_ cards: [Card]) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(cards) { card in
                NavigationLink(value: card) { MarketRow(card: card) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.3)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.xs)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                MarketChip(title: "All", isSelected: filter == nil) { filter = nil }
                ForEach(SportCategory.allCases) { sport in
                    MarketChip(title: sport.displayName, isSelected: filter == .sport(sport)) {
                        filter = .sport(sport)
                    }
                }
                ForEach([CardGame.pokemon, .magic, .yugioh]) { game in
                    MarketChip(title: game.displayName, isSelected: filter == .game(game)) {
                        filter = .game(game)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var indexCard: some View {
        let index = SampleData.marketIndex
        let up = index.changeToday >= 0
        let accent = up ? Theme.gain : Theme.loss
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("Case Index", systemImage: "chart.xyaxis.line")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(up ? "+" : "")\(String(format: "%.1f", index.changeToday))% today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.16), in: Capsule())
            }
            Text(index.value, format: .number.precision(.fractionLength(2)))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            MiniAreaChart(values: index.series, tint: accent)
                .frame(height: 96)
        }
        .padding(Theme.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .fill(LinearGradient(colors: [accent.opacity(0.14), .clear], startPoint: .topTrailing, endPoint: .bottomLeading))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.hairline)
                )
        }
        .padding(.horizontal)
    }
}

private struct MarketChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, Theme.Spacing.sm)
                .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? .clear : Theme.hairline))
        }
    }
}

struct MarketRow: View {
    let card: Card

    var body: some View {
        let market = SampleData.market[card.id]
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(card.setName).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((market?.topPrice ?? card.marketPrice ?? .zero).formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if let change = market?.change30d {
                    Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

private struct MoverCard: View {
    let card: Card

    var body: some View {
        let market = SampleData.market[card.id]
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

private struct SaleRow: View {
    let card: Card
    let sale: Sale

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).font(.subheadline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text("\(sale.grade) · \(sale.platform)").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sale.price.formatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Text(sale.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(Theme.Spacing.sm)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

private struct IndexTile: View {
    let entry: MarketIndexEntry
    var body: some View {
        let change = SampleData.indexChange(entry.memberIDs)
        let up = change >= 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: entry.symbolName).font(.caption).foregroundStyle(entry.accent)
                Text(entry.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
            }
            MiniAreaChart(values: SampleData.indexSeries(entry.memberIDs), tint: up ? Theme.gain : Theme.loss)
                .frame(height: 40)
            Text("\(up ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(up ? Theme.gain : Theme.loss)
        }
        .frame(width: 150)
        .padding(Theme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(LinearGradient(colors: [entry.accent.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.hairline)
                )
        }
    }
}

#Preview {
    MarketView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(WatchlistStore(followed: [SampleData.jordan.id]))
        .preferredColorScheme(.dark)
}
