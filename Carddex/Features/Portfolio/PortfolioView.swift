import SwiftUI
import Charts
import UIKit

/// Portfolio: total value, a value-over-time chart, and a by-game breakdown.
/// History is illustrative until real price snapshots land in Phase 2.
struct PortfolioView: View {
    @Environment(CollectionStore.self) private var store
    @State private var range: Range = .month
    @State private var shareImage: Image?
    @State private var scrub: PricePoint?

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
                    ScreenHeader(title: "Portfolio") {
                        if let shareImage {
                            ShareLink(item: shareImage, preview: SharePreview("My collection · The Case", image: shareImage)) {
                                Image(systemName: "square.and.arrow.up").circleIconChip(label: "Share")
                            }
                        }
                    }
                    hero
                    if let top = store.items.max(by: { $0.estimatedValue.amount < $1.estimatedValue.amount }) {
                        NavigationLink(value: top) {
                            FeaturedCard(card: top.card, eyebrow: "Top holding", trailingValue: top.estimatedValue.formatted)
                        }
                        .buttonStyle(.plain)
                    }
                    rangePicker
                    chart
                    insightsRow
                    if !gamesWithValue.isEmpty { byGame }
                    if !gamesWithValue.isEmpty { attribution }
                    if !store.movers.isEmpty { moversSection }
                    Text("Value history is illustrative — live snapshots arrive in Phase 2.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabBarSafeArea()
            .navigationDestination(for: CollectionItem.self) { item in
                CardDetailView(item: item)
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
        let up = deltaAbs >= 0
        let accent = up ? Theme.gain : Theme.loss
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Total value")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            RollingNumber(totalDouble,
                          format: { Money(amount: Decimal($0)).formatted },
                          size: 42)
            HStack(spacing: 6) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                Text("\(up ? "+" : "−")\(money(abs(deltaAbs))) (\(String(format: "%.1f", deltaPct))%) · \(range.rawValue)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accent)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .glassCard(cornerRadius: Theme.Radius.xl)
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
            .foregroundStyle(LinearGradient(colors: [Theme.chart.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.catmullRom)

            LineMark(x: .value("t", point.index), y: .value("v", point.value))
                .foregroundStyle(Theme.chart)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            if let scrub {
                RuleMark(x: .value("t", scrub.index))
                    .foregroundStyle(Theme.textTertiary.opacity(0.5))
                PointMark(x: .value("t", scrub.index), y: .value("v", scrub.value))
                    .foregroundStyle(Theme.chart)
                    .symbolSize(90)
            }
        }
        .chartYScale(domain: lo...hi)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 150)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame {
                    let originX = geo[plotFrame].origin.x
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if let idx: Double = proxy.value(atX: value.location.x - originX),
                                       let nearest = series.min(by: { abs(Double($0.index) - idx) < abs(Double($1.index) - idx) }) {
                                        if nearest.id != scrub?.id { Haptics.selection() }
                                        scrub = nearest
                                    }
                                }
                                .onEnded { _ in scrub = nil }
                        )
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let scrub {
                Text(money(scrub.value))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.chart)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassCapsule()
            } else {
                Text("Sample")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassCapsule()
            }
        }
    }

    private var rangePicker: some View {
        SegmentTabs(selection: $range, items: Range.allCases.map { (value: $0, label: $0.rawValue) })
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

    private var attribution: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Attribution")
            ForEach(gamesWithValue) { game in
                let gain = NSDecimalNumber(decimal: store.gainLoss(for: game).amount).doubleValue
                HStack {
                    GamePill(game: game)
                    Spacer()
                    Text("\(gain >= 0 ? "+" : "−")\(money(abs(gain)))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(gain >= 0 ? Theme.gain : Theme.loss)
                        .monospacedDigit()
                }
                .padding(Theme.Spacing.md)
                .glassPanel(cornerRadius: Theme.Radius.card)
            }
        }
    }

    private var moversSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Movers")
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
            SectionHeader("By game")
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
