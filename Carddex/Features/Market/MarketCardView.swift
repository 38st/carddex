import SwiftUI

/// Market detail for a card (Card Ladder-style): graded values, a price chart for
/// the selected grade, recent sales, and population.
struct MarketCardView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(WatchlistStore.self) private var watchlist
    @Environment(MarketStore.self) private var marketStore
    @Environment(\.dismiss) private var dismiss
    let card: Card
    @State private var selectedGrade: String
    @State private var priceRange: IndexRange = .month
    @State private var showAdd = false

    init(card: Card) {
        self.card = card
        _selectedGrade = State(initialValue: SampleData.market[card.id]?.gradedPrices.first?.grade ?? "Raw")
    }

    private var market: CardMarket? { marketStore.market[card.id] }

    /// Whether this card is already in the collection — drives the "Add" button
    /// label. Derived from the store so it's honest on appear *and* after a buy,
    /// and a second "Log a buy" is always allowed (it stacks quantity).
    private var isOwned: Bool { store.items.contains { $0.card.id == card.id } }

    /// Other tracked cards in the same sport (or game, for TCG).
    private var relatedCards: [Card] {
        SampleData.marketCards.filter { other in
            guard other.id != card.id else { return false }
            return card.game == .sports
                ? (other.game == .sports && other.sport == card.sport)
                : other.game == card.game
        }
    }

    /// The category index this card belongs to, if any.
    private var indexEntry: MarketIndexEntry? {
        SampleData.categoryIndices.first { $0.memberIDs.contains(card.id) }
    }
    private var selectedPrice: Money {
        market?.gradedPrices.first(where: { $0.grade == selectedGrade })?.price ?? card.marketPrice ?? .zero
    }

    /// Price trend derived from the card's LIVE 30-day change (backend → store).
    private func priceSeries(_ range: IndexRange) -> [Double] {
        SampleData.priceSeries(change30d: market?.change30d ?? 0, range: range, seed: card.id)
    }

    private func gradePopulation(_ grade: String) -> Int {
        let total = market?.population ?? 0
        switch grade {
        case "PSA 10": return Int(Double(total) * 0.12)
        case "PSA 9": return Int(Double(total) * 0.40)
        default: return max(0, total - Int(Double(total) * 0.52))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                HStack {
                    CircleIconButton(systemImage: "chevron.left") { dismiss() }
                    Spacer()
                    Text(card.name)
                        .font(.display(17))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 10) {
                        CircleIconButton(systemImage: watchlist.hasAlert(card.id) ? "bell.fill" : "bell") {
                            if watchlist.hasAlert(card.id) {
                                watchlist.removeAlert(card.id)
                            } else {
                                watchlist.setAlert(cardID: card.id, target: selectedPrice)
                                Haptics.success()
                            }
                        }
                        CircleIconButton(systemImage: watchlist.isFollowing(card.id) ? "star.fill" : "star") {
                            watchlist.toggleFollow(card.id)
                        }
                    }
                }

                LivingCardView(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport, maxWidth: 200)

                VStack(spacing: Theme.Spacing.xs) {
                    GamePill(game: card.game, sport: card.sport)
                    Text(card.name).font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
                    Text("\(card.setName) · \(card.number)").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }

                value
                keyStats
                gradeMatrix
                gradingHint
                VStack(spacing: Theme.Spacing.sm) {
                    SalesChart(
                        series: priceSeries(priceRange),
                        topPrice: NSDecimalNumber(decimal: selectedPrice.amount).doubleValue,
                        sales: market?.recentSales.filter { $0.grade == selectedGrade } ?? [],
                        windowDays: SampleData.windowDays(priceRange)
                    )
                    RangeSelector(selection: $priceRange)
                }
                salesSection
                relatedSection
                if let population = market?.population {
                    LabeledContent("Population", value: "\(population.formatted())")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.Spacing.md)
                        .glassPanel(cornerRadius: Theme.Radius.card)
                }

                PrimaryButton(title: isOwned ? "Add another to portfolio" : "Add to portfolio",
                              systemImage: isOwned ? "plus.rectangle.on.rectangle" : "plus") {
                    showAdd = true
                }
            }
            .padding()
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) {
            AddToPortfolioSheet(card: card, suggestedPrice: selectedPrice)
                .presentationDetents([.medium, .large])
        }
    }

    private var value: some View {
        let series = priceSeries(priceRange)
        let first = series.first ?? 0
        let change = first > 0 ? ((series.last ?? 0) - first) / first * 100 : (market?.change30d ?? 0)
        return VStack(spacing: 2) {
            Text(selectedPrice.formatted)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            if market != nil {
                Text("\(change >= 0 ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))% · \(priceRange.rawValue)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
                    .contentTransition(.numericText())
            }
        }
    }

    /// Card Ladder-style key stats: 52-week range, all-time high, and market cap.
    @ViewBuilder private var keyStats: some View {
        let price = NSDecimalNumber(decimal: selectedPrice.amount).doubleValue
        let year = priceSeries(.year)
        let all = priceSeries(.all)
        if price > 0, let yLo = year.min(), year.max() != nil, all.max() != nil {
            // Series end at the current price (1.0), so the high is never below it.
            let yHi = max(year.max() ?? 1, 1.0)
            let aHi = max(all.max() ?? 1, 1.0)
            let cap = Double(market?.population ?? 0) * NSDecimalNumber(decimal: (market?.topPrice ?? selectedPrice).amount).doubleValue
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    StatTile(title: "52W high", value: Money(amount: Decimal(yHi * price)).formatted, accent: Theme.gain)
                    StatTile(title: "52W low", value: Money(amount: Decimal(yLo * price)).formatted, accent: Theme.loss)
                }
                HStack(spacing: Theme.Spacing.sm) {
                    StatTile(title: "All-time high", value: Money(amount: Decimal(aHi * price)).formatted)
                    StatTile(title: "Market cap", value: Money(amount: Decimal(cap)).compactFormatted)
                }
            }
        }
    }

    @ViewBuilder private var gradeMatrix: some View {
        if let grades = market?.gradedPrices, !grades.isEmpty {
            VStack(spacing: 0) {
                ForEach(grades) { graded in
                    Button {
                        Haptics.selection()
                        selectedGrade = graded.grade
                    } label: {
                        HStack {
                            Text(graded.grade)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("Pop \(gradePopulation(graded.grade).formatted())")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .monospacedDigit()
                                .padding(.trailing, Theme.Spacing.md)
                            Text(graded.price.formatted)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedGrade == graded.grade ? Theme.cream : Theme.textPrimary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, Theme.Spacing.md)
                        .background(selectedGrade == graded.grade ? Theme.cream.opacity(0.14) : .clear)
                    }
                    .buttonStyle(.plain)
                    if graded.id != grades.last?.id {
                        Divider().overlay(Theme.hairline)
                    }
                }
            }
            .glassPanel(cornerRadius: Theme.Radius.card)
        }
    }

    @ViewBuilder private var gradingHint: some View {
        if let grades = market?.gradedPrices,
           let raw = grades.first(where: { $0.grade == "Raw" }),
           let psa10 = grades.first(where: { $0.grade == "PSA 10" }) {
            let rawValue = NSDecimalNumber(decimal: raw.price.amount).doubleValue
            let topValue = NSDecimalNumber(decimal: psa10.price.amount).doubleValue
            let multiple = rawValue > 0 ? Int((topValue / rawValue).rounded()) : 0
            Label("Grading upside: Raw → PSA 10 is \(multiple)×", systemImage: "arrow.up.right.circle")
                .font(.caption)
                .foregroundStyle(Theme.gain)
        }
    }

    @ViewBuilder private var relatedSection: some View {
        if !relatedCards.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    SectionHeader(card.game == .sports ? "More in \(card.sport?.displayName ?? "this sport")" : "More \(card.game.displayName)")
                    Spacer()
                    if let entry = indexEntry {
                        NavigationLink(value: entry) {
                            HStack(spacing: 3) {
                                Text("Index")
                                Image(systemName: "chevron.right").font(.caption2)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.cream)
                        }
                    }
                }
                ForEach(relatedCards.prefix(4)) { other in
                    NavigationLink(value: other) { MarketRow(card: other) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private var salesSection: some View {
        if let sales = market?.recentSales, !sales.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader("Recent sales")
                ForEach(sales) { sale in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sale.price.formatted)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .monospacedDigit()
                            Text("\(sale.grade) · \(sale.platform)")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(sale.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(Theme.Spacing.sm)
                    .glassPanel(cornerRadius: Theme.Radius.card)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MarketCardView(card: SampleData.jordan)
            .environment(CollectionStore(items: SampleData.collection))
            .environment(WatchlistStore())
            .environment(MarketStore())
    }
    .preferredColorScheme(.dark)
}
