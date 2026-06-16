import SwiftUI
import Charts

/// Compare up to 3 cards' 30-day trends on one chart, normalized to % change —
/// a Card Ladder power-user staple.
struct ComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MarketStore.self) private var marketStore
    @State private var selected: [String] = []

    private let palette: [Color] = [Theme.accent, Theme.gain, Color(hex: 0xF0997B)]

    private var selectedCards: [Card] {
        selected.compactMap { id in SampleData.marketCards.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if selectedCards.isEmpty {
                            Text("Pick up to 3 cards to compare their 30-day trend.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, Theme.Spacing.xl)
                        } else {
                            chart
                            legend
                        }

                        Text("Cards")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        ForEach(SampleData.marketCards) { card in
                            row(card)
                        }
                    }
                    .padding()
                }
                .tabBarSafeArea()
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func color(for card: Card) -> Color {
        let index = selected.firstIndex(of: card.id) ?? 0
        return palette[index % palette.count]
    }

    private func pctSeries(_ card: Card) -> [Double] {
        guard let series = marketStore.market[card.id]?.priceSeries, let first = series.first, first != 0 else { return [] }
        return series.map { ($0 / first - 1) * 100 }
    }

    private var chart: some View {
        Chart {
            ForEach(selectedCards) { card in
                ForEach(Array(pctSeries(card).enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("t", index), y: .value("change", value))
                        .foregroundStyle(by: .value("card", card.name))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
        }
        .chartForegroundStyleScale(range: selectedCards.map { color(for: $0) })
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .frame(height: 200)
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(selectedCards) { card in
                HStack(spacing: 6) {
                    Circle().fill(color(for: card)).frame(width: 10, height: 10)
                    Text(card.name).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
        }
    }

    private func row(_ card: Card) -> some View {
        let isOn = selected.contains(card.id)
        let change = marketStore.market[card.id]?.change30d ?? 0
        return Button {
            Haptics.selection()
            if isOn {
                selected.removeAll { $0 == card.id }
            } else if selected.count < 3 {
                selected.append(card.id)
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Theme.accent : Theme.textTertiary)
                CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                    .frame(width: 36)
                Text(card.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Spacer()
                Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
            }
            .padding(Theme.Spacing.sm)
            .glassPanel(cornerRadius: Theme.Radius.card)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ComparisonView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(MarketStore())
}
