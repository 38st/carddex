import SwiftUI

/// Market detail for a card (Card Ladder-style): graded values, a price chart for
/// the selected grade, recent sales, and population.
struct MarketCardView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(WatchlistStore.self) private var watchlist
    let card: Card
    @State private var selectedGrade: String
    @State private var priceRange: IndexRange = .month
    @State private var added = false
    @State private var showAdd = false

    init(card: Card) {
        self.card = card
        _selectedGrade = State(initialValue: SampleData.market[card.id]?.gradedPrices.first?.grade ?? "Raw")
    }

    private var market: CardMarket? { SampleData.market[card.id] }

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
                CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport, animatedFoil: true)
                    .frame(maxWidth: 190)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 10)

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
                        series: SampleData.priceSeries(for: card.id, range: priceRange),
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

                PrimaryButton(title: added ? "Added to portfolio" : "Add to portfolio", systemImage: added ? "checkmark" : "plus") {
                    showAdd = true
                }
                .disabled(added)
            }
            .padding()
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddToPortfolioSheet(card: card, suggestedPrice: selectedPrice) { added = true }
                .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if watchlist.hasAlert(card.id) {
                        watchlist.removeAlert(card.id)
                    } else {
                        watchlist.setAlert(cardID: card.id, target: selectedPrice)
                        Haptics.success()
                    }
                } label: {
                    Image(systemName: watchlist.hasAlert(card.id) ? "bell.fill" : "bell")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    watchlist.toggleFollow(card.id)
                } label: {
                    Image(systemName: watchlist.isFollowing(card.id) ? "star.fill" : "star")
                }
            }
        }
    }

    private var value: some View {
        let series = SampleData.priceSeries(for: card.id, range: priceRange)
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
        let year = SampleData.priceSeries(for: card.id, range: .year)
        let all = SampleData.priceSeries(for: card.id, range: .all)
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
                                .foregroundStyle(selectedGrade == graded.grade ? Theme.accent : Theme.textPrimary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, Theme.Spacing.md)
                        .background(selectedGrade == graded.grade ? Theme.accent.opacity(0.14) : .clear)
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
                    Text(card.game == .sports ? "More in \(card.sport?.displayName ?? "this sport")" : "More \(card.game.displayName)")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let entry = indexEntry {
                        NavigationLink(value: entry) {
                            HStack(spacing: 3) {
                                Text("Index")
                                Image(systemName: "chevron.right").font(.caption2)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
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
                Text("Recent sales")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
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
    }
    .preferredColorScheme(.dark)
}
