import SwiftUI
import Charts
import UIKit

/// Portfolio: total value, a value-over-time chart, and a by-game breakdown.
/// History is illustrative until real price snapshots land in Phase 2.
struct PortfolioView: View {
    @Environment(CollectionStore.self) private var store
    @State private var range: Range = .month
    @State private var shareImage: Image?

    enum Range: String, CaseIterable, Identifiable {
        case week = "1W", month = "1M", quarter = "3M", year = "1Y", all = "All"
        var id: String { rawValue }
    }

    private var gamesWithValue: [CardGame] {
        CardGame.allCases.filter { store.value(for: $0).amount > 0 }
    }

    private var totalDouble: Double {
        NSDecimalNumber(decimal: store.totalValue.amount).doubleValue
    }

    private var series: [PricePoint] {
        shape(for: range).enumerated().map { PricePoint(index: $0.offset, value: $0.element * totalDouble) }
    }

    private var deltaAbs: Double { (series.last?.value ?? 0) - (series.first?.value ?? 0) }
    private var deltaPct: Double {
        let first = series.first?.value ?? 0
        return first > 0 ? deltaAbs / first * 100 : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    hero
                    rangePicker
                    chart
                    insightsRow
                    if !gamesWithValue.isEmpty { byGame }
                    if !store.movers.isEmpty { moversSection }
                    Text("Value history is illustrative — live snapshots arrive in Phase 2.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding()
            }
            .navigationTitle("Portfolio")
            .tabBarSafeArea()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("My Carddex collection", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear(perform: renderShareImage)
        }
    }

    @MainActor private func renderShareImage() {
        var seen = Set<CardGame>()
        let tiles = store.items.map(\.card.game).filter { seen.insert($0).inserted }
        let poster = ShareableCollectionCard(
            totalValue: store.totalValue.formatted,
            gain: "\(allTimeGain >= 0 ? "▲ +" : "▼ −")\(money(abs(allTimeGain))) (\(String(format: "%.0f", abs(store.gainLossPercent)))%) all-time",
            gainUp: allTimeGain >= 0,
            cardCount: store.totalCards,
            uniqueCount: store.items.count,
            tiles: Array(tiles.prefix(4))
        )
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Total value")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text(store.totalValue.formatted)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Image(systemName: deltaAbs >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(deltaAbs >= 0 ? "+" : "−")\(money(abs(deltaAbs))) (\(String(format: "%.1f", deltaPct))%) · \(range.rawValue)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(deltaAbs >= 0 ? Theme.gain : Theme.loss)
            .monospacedDigit()
        }
    }

    private var chart: some View {
        let values = series.map(\.value)
        let lo = (values.min() ?? 0) * 0.995
        let hi = (values.max() ?? 1) * 1.005
        return Chart(series) { point in
            AreaMark(
                x: .value("t", point.index),
                yStart: .value("lo", lo),
                yEnd: .value("v", point.value)
            )
            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.catmullRom)

            LineMark(x: .value("t", point.index), y: .value("v", point.value))
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .chartYScale(domain: lo...hi)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 150)
        .overlay(alignment: .topLeading) {
            Text("Sample")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var allTimeGain: Double { NSDecimalNumber(decimal: store.totalGainLoss.amount).doubleValue }

    private var insightsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatTile(title: "Cost basis", value: store.totalCost.formatted)
            StatTile(
                title: "All-time gain",
                value: "\(allTimeGain >= 0 ? "+" : "−")\(money(abs(allTimeGain))) (\(String(format: "%.0f", abs(store.gainLossPercent)))%)",
                accent: allTimeGain >= 0 ? Theme.gain : Theme.loss
            )
        }
    }

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Movers")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            ForEach(store.movers.prefix(4)) { item in
                let gain = NSDecimalNumber(decimal: item.gainLoss.amount).doubleValue
                HStack(spacing: Theme.Spacing.md) {
                    CardArtwork(game: item.card.game, rarity: item.card.rarity, price: item.card.marketPrice, imageURL: item.card.imageURL, sport: item.card.sport)
                        .frame(width: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.card.name).font(.subheadline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Text(item.card.setName).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    Text("\(gain >= 0 ? "+" : "−")\(money(abs(gain)))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(gain >= 0 ? Theme.gain : Theme.loss)
                        .monospacedDigit()
                }
                .padding(Theme.Spacing.sm)
                .glassPanel(cornerRadius: Theme.Radius.card)
            }
        }
    }

    private var byGame: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("By game")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            ForEach(gamesWithValue) { game in
                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        GamePill(game: game)
                        Spacer()
                        Text(store.value(for: game).formatted)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule().fill(game.accent)
                                .frame(width: geo.size.width * fraction(game))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)
            }
        }
    }

    private func fraction(_ game: CardGame) -> CGFloat {
        guard totalDouble > 0 else { return 0 }
        return CGFloat(NSDecimalNumber(decimal: store.value(for: game).amount).doubleValue / totalDouble)
    }

    private func money(_ value: Double) -> String {
        Money(amount: Decimal(value)).formatted
    }

    private func shape(for range: Range) -> [Double] {
        switch range {
        case .week: [0.97, 0.975, 0.97, 0.98, 0.985, 0.99, 1.0]
        case .month: [0.94, 0.95, 0.945, 0.96, 0.955, 0.97, 0.975, 0.985, 0.99, 1.0]
        case .quarter: [0.80, 0.82, 0.85, 0.83, 0.88, 0.90, 0.92, 0.95, 0.97, 1.0]
        case .year: [0.55, 0.60, 0.65, 0.62, 0.70, 0.75, 0.80, 0.88, 0.95, 1.0]
        case .all: [0.30, 0.40, 0.50, 0.55, 0.65, 0.75, 0.85, 0.95, 1.0]
        }
    }
}

private struct PricePoint: Identifiable {
    let index: Int
    let value: Double
    var id: Int { index }
}

#Preview {
    PortfolioView()
        .environment(CollectionStore(items: SampleData.collection))
        .preferredColorScheme(.dark)
}
