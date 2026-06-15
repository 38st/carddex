import SwiftUI

/// A market sub-index detail (Card Ladder-style): the index trend + its constituents.
struct IndexDetailView: View {
    let entry: MarketIndexEntry

    private var change: Double { SampleData.indexChange(entry.memberIDs) }
    private var series: [Double] { SampleData.indexSeries(entry.memberIDs) }
    private var members: [Card] { SampleData.indexMembers(entry.memberIDs) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                MiniAreaChart(values: series, tint: change >= 0 ? Theme.gain : Theme.loss)
                    .frame(height: 140)
                    .padding(Theme.Spacing.md)
                    .glassPanel(cornerRadius: Theme.Radius.lg)

                Text("\(members.count) cards")
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
                Text("\(change >= 0 ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(change)))% · 30 days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Theme.gain : Theme.loss)
            }
            Spacer()
        }
    }
}
