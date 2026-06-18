import SwiftUI
import Charts

/// Price trend with real sales scattered on the line — Card Ladder's signature
/// "every point is a sale" chart. Scrub to read a value.
struct SalesChart: View {
    let series: [Double]    // normalized 0…1 (the card's price trend)
    let topPrice: Double    // value the series scales to (selected grade)
    let sales: [Sale]       // sales for the selected grade
    var windowDays: Double = 30

    @State private var selected: LinePoint?

    struct LinePoint: Identifiable {
        let day: Double
        let value: Double
        var id: Double { day }
    }

    private var linePoints: [LinePoint] {
        guard series.count > 1 else { return [] }
        return series.enumerated().map { index, value in
            LinePoint(day: windowDays * Double(index) / Double(series.count - 1), value: value * topPrice)
        }
    }

    private struct SalePoint: Identifiable {
        let id: UUID
        let day: Double
        let price: Double
        let platform: String
    }

    private var salePoints: [SalePoint] {
        let now = Date.now
        return sales.compactMap { sale in
            let daysAgo = now.timeIntervalSince(sale.date) / 86400
            guard daysAgo <= windowDays else { return nil }
            return SalePoint(id: sale.id, day: windowDays - daysAgo,
                             price: NSDecimalNumber(decimal: sale.price.amount).doubleValue,
                             platform: sale.platform)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Price history")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let selected {
                    Text(Money(amount: Decimal(selected.value)).formatted)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }
                Text("Sample")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .glassCapsule()
            }
            chart
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private var bounds: (lo: Double, hi: Double) {
        let values = linePoints.map(\.value) + salePoints.map(\.price)
        let lo = (values.min() ?? 0) * 0.96
        let hi = (values.max() ?? 1) * 1.04
        return (lo, hi == lo ? hi + 1 : hi)
    }

    private var chart: some View {
        let (lo, hi) = bounds
        return Chart {
            ForEach(linePoints) { point in
                AreaMark(x: .value("day", point.day), yStart: .value("lo", lo), yEnd: .value("value", point.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("day", point.day), y: .value("value", point.value))
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            ForEach(salePoints) { sale in
                PointMark(x: .value("day", sale.day), y: .value("value", sale.price))
                    .foregroundStyle(Theme.gain)
                    .symbolSize(70)
            }
            if let selected {
                RuleMark(x: .value("day", selected.day))
                    .foregroundStyle(Theme.textTertiary.opacity(0.5))
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
                                    if let day: Double = proxy.value(atX: value.location.x - originX),
                                       let nearest = linePoints.min(by: { abs($0.day - day) < abs($1.day - day) }) {
                                        if nearest.id != selected?.id { Haptics.selection() }
                                        selected = nearest
                                    }
                                }
                                .onEnded { _ in selected = nil }
                        )
                }
            }
        }
    }
}
