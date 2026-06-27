import SwiftUI
import Charts

/// Interactive price-trend chart for a card: range tabs + drag-to-scrub.
/// History is illustrative (scaled from the current price) until live snapshots
/// land in Phase 2.
struct CardPriceChart: View {
    let basePrice: Double
    /// Real captured price history (oldest → newest). When it has ≥2 points the
    /// chart plots it; otherwise it falls back to an illustrative curve.
    var series: [Double]? = nil
    @State private var range: Range = .month
    @State private var selected: Point?

    enum Range: String, CaseIterable, Identifiable {
        case week = "1W", month = "1M", quarter = "3M", year = "1Y"
        var id: String { rawValue }
    }

    struct Point: Identifiable {
        let index: Int
        let value: Double
        var id: Int { index }
    }

    private var usingRealHistory: Bool { (series?.count ?? 0) >= 2 }

    private var points: [Point] {
        // `series` is normalized 0…1 (ending at the current price); scale to dollars.
        if let series, series.count >= 2 {
            let sliced = Array(series.suffix(rangeCount(range)))
            return sliced.enumerated().map { Point(index: $0.offset, value: $0.element * basePrice) }
        }
        return shape(for: range).enumerated().map { Point(index: $0.offset, value: $0.element * basePrice) }
    }

    private func rangeCount(_ r: Range) -> Int {
        switch r {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Price trend")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Money(amount: Decimal(selected?.value ?? basePrice)).formatted)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.chart)
                    .monospacedDigit()
            }
            chart
            SegmentTabs(selection: $range, items: Range.allCases.map { (value: $0, label: $0.rawValue) })
        }
    }

    private var chart: some View {
        let values = points.map(\.value)
        let lo = (values.min() ?? 0) * 0.99
        let hi = (values.max() ?? 1) * 1.01
        return Chart {
            ForEach(points) { point in
                AreaMark(x: .value("t", point.index), yStart: .value("lo", lo), yEnd: .value("v", point.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.chart.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("t", point.index), y: .value("v", point.value))
                    .foregroundStyle(Theme.chart)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            if let selected {
                RuleMark(x: .value("t", selected.index))
                    .foregroundStyle(Theme.textTertiary.opacity(0.6))
                PointMark(x: .value("t", selected.index), y: .value("v", selected.value))
                    .foregroundStyle(Theme.chart)
            }
        }
        .chartYScale(domain: lo...hi)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 120)
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
                                    if let index: Int = proxy.value(atX: value.location.x - originX) {
                                        selected = points[max(0, min(points.count - 1, index))]
                                    }
                                }
                                .onEnded { _ in selected = nil }
                        )
                }
            }
        }
    }

    private func shape(for range: Range) -> [Double] {
        switch range {
        case .week: [0.97, 0.975, 0.97, 0.98, 0.985, 0.99, 1.0]
        case .month: [0.88, 0.9, 0.89, 0.93, 0.92, 0.96, 0.95, 0.98, 0.99, 1.0]
        case .quarter: [0.74, 0.78, 0.76, 0.82, 0.86, 0.84, 0.9, 0.94, 0.97, 1.0]
        case .year: [0.5, 0.55, 0.62, 0.58, 0.68, 0.74, 0.8, 0.88, 0.95, 1.0]
        }
    }
}
