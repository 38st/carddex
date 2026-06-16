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

    init(card: Card) {
        self.card = card
        _selectedGrade = State(initialValue: SampleData.market[card.id]?.gradedPrices.first?.grade ?? "Raw")
    }

    private var market: CardMarket? { SampleData.market[card.id] }
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
                gradeMatrix
                gradingHint
                VStack(spacing: Theme.Spacing.sm) {
                    SalesChart(
                        series: SampleData.priceSeries(for: card.id, range: priceRange),
                        topPrice: NSDecimalNumber(decimal: selectedPrice.amount).doubleValue,
                        sales: market?.recentSales.filter { $0.grade == selectedGrade } ?? [],
                        windowDays: SampleData.windowDays(priceRange)
                    )
                    rangePicker
                }
                salesSection
                if let population = market?.population {
                    LabeledContent("Population", value: "\(population.formatted())")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.Spacing.md)
                        .glassPanel(cornerRadius: Theme.Radius.card)
                }

                PrimaryButton(title: added ? "Added to portfolio" : "Add to portfolio", systemImage: added ? "checkmark" : "plus") {
                    store.add(card)
                    Haptics.success()
                    added = true
                }
                .disabled(added)
            }
            .padding()
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(IndexRange.allCases) { range in
                let selected = priceRange == range
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.25)) { priceRange = range }
                } label: {
                    Text(range.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(selected ? .white : Theme.textSecondary)
                        .background { if selected { Capsule().fill(Theme.accent) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(Theme.hairline))
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
