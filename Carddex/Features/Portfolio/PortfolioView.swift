import SwiftUI
import Charts

/// Portfolio: total value, a value-over-time chart, and a by-game breakdown.
/// History is illustrative until real price snapshots land in Phase 2.
struct PortfolioView: View {
    @Environment(CollectionStore.self) private var store
    @State private var range: Range = .month

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
                    chart
                    rangePicker
                    if !gamesWithValue.isEmpty { byGame }
                    Text("Value history is illustrative — live snapshots arrive in Phase 2.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding()
            }
            .navigationTitle("Portfolio")
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
    }

    private var rangePicker: some View {
        Picker("Range", selection: $range) {
            ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
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
