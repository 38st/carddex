import SwiftUI

/// A market sub-index detail (Card Ladder-style): the index trend + its constituents.
struct IndexDetailView: View {
    @Environment(MarketStore.self) private var marketStore
    let entry: MarketIndexEntry
    @State private var range: IndexRange = .month

    private var change: Double { marketStore.indexChange(entry.memberIDs, range: range) }
    private var series: [Double] { marketStore.indexSeries(entry.memberIDs, range: range) }
    private var members: [Card] { SampleData.indexMembers(entry.memberIDs) }

    private var totalValue: Decimal {
        members.reduce(Decimal(0)) { $0 + (marketStore.market[$1.id]?.topPrice ?? $1.marketPrice ?? .zero).amount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                VStack(spacing: Theme.Spacing.md) {
                    MiniAreaChart(values: series, tint: change >= 0 ? Theme.gain : Theme.loss, interactive: true)
                        .frame(height: 140)
                        .animation(.easeInOut(duration: 0.35), value: range)
                    RangeSelector(selection: $range)
                }
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.lg)

                HStack(spacing: Theme.Spacing.sm) {
                    StatTile(title: "Index value", value: Money(amount: totalValue).compactFormatted)
                    StatTile(title: "Cards", value: "\(members.count)")
                    StatTile(
                        title: "Avg · \(range.rawValue)",
                        value: "\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%",
                        accent: change >= 0 ? Theme.gain : Theme.loss
                    )
                }

                Text("Constituents")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(members) { card in
                        NavigationLink(value: card) { MarketRow(card: card) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: entry.symbolName)
                .font(.title)
                .foregroundStyle(entry.accent)
                .frame(width: 56, height: 56)
                .background(entry.accent.opacity(0.16), in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(change >= 0 ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))% · \(range.rawValue)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
    }
}
