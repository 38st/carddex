import SwiftUI

/// Market detail for a card (Card Ladder-style): graded values, a price chart for
/// the selected grade, recent sales, and population.
struct MarketCardView: View {
    @Environment(CollectionStore.self) private var store
    let card: Card
    @State private var selectedGrade: String
    @State private var added = false

    init(card: Card) {
        self.card = card
        _selectedGrade = State(initialValue: SampleData.market[card.id]?.gradedPrices.first?.grade ?? "Raw")
    }

    private var market: CardMarket? { SampleData.market[card.id] }
    private var selectedPrice: Money {
        market?.gradedPrices.first(where: { $0.grade == selectedGrade })?.price ?? card.marketPrice ?? .zero
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
                gradeSelector
                CardPriceChart(basePrice: NSDecimalNumber(decimal: selectedPrice.amount).doubleValue)
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.card)
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
    }

    private var value: some View {
        let change = market?.change30d ?? 0
        return VStack(spacing: 2) {
            Text(selectedPrice.formatted)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            if market != nil {
                Text("\(change >= 0 ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))% · 30 days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
            }
        }
    }

    @ViewBuilder private var gradeSelector: some View {
        if let grades = market?.gradedPrices, !grades.isEmpty {
            Picker("Grade", selection: $selectedGrade) {
                ForEach(grades) { Text($0.grade).tag($0.grade) }
            }
            .pickerStyle(.segmented)
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
    }
    .preferredColorScheme(.dark)
}
