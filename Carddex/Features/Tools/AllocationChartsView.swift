import SwiftUI

/// Portfolio allocation charts: donut breakdowns by game, set, condition, and
/// grading status. Shows diversification at a glance.
struct AllocationChartsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store
    @State private var selectedBreakdown: Breakdown = .game

    enum Breakdown: String, CaseIterable, Identifiable {
        case game = "Game"
        case set = "Set"
        case condition = "Condition"
        case grading = "Grading"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        Picker("Breakdown", selection: $selectedBreakdown) {
                            ForEach(Breakdown.allCases) { b in
                                Text(b.rawValue).tag(b)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(Theme.cream)

                        donutChart
                        legend
                    }
                    .padding()
                }
            }
            .navigationTitle("Allocation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private struct Slice: Identifiable {
        let label: String
        let value: Double
        let color: Color
        var id: String { label }
    }

    private var slices: [Slice] {
        let items = store.items
        guard !items.isEmpty else { return [] }

        switch selectedBreakdown {
        case .game:
            let palette: [Color] = [Theme.cream, Theme.gain, Theme.loss, Theme.warning]
            let groups = Dictionary(grouping: items) { $0.card.game }
            return groups.map { key, groupItems in
                let val = groupItems.reduce(0.0) { $0 + $1.estimatedValue.amount.doubleValue }
                return Slice(label: key.displayName, value: val, color: .clear)
            }
            .sorted { $0.value > $1.value }
            .enumerated().map { idx, slice in
                Slice(label: slice.label, value: slice.value, color: palette[idx % palette.count])
            }

        case .set:
            let palette: [Color] = [Theme.cream, Theme.gain, Theme.loss, Theme.warning, .purple, .teal, .indigo, .orange]
            let groups = Dictionary(grouping: items) { $0.card.setName }
            return groups.map { key, groupItems in
                let val = groupItems.reduce(0.0) { $0 + $1.estimatedValue.amount.doubleValue }
                return Slice(label: key.isEmpty ? "Unknown" : key, value: val, color: .clear)
            }
            .sorted { $0.value > $1.value }
            .enumerated().map { idx, slice in
                Slice(label: slice.label, value: slice.value, color: palette[idx % palette.count])
            }

        case .condition:
            let palette: [Color] = [Theme.gain, Theme.cream, Theme.warning, Theme.loss, .gray]
            let groups = Dictionary(grouping: items) { $0.condition.rawValue }
            return groups.map { key, groupItems in
                let val = groupItems.reduce(0.0) { $0 + $1.estimatedValue.amount.doubleValue }
                return Slice(label: key, value: val, color: .clear)
            }
            .sorted { $0.value > $1.value }
            .enumerated().map { idx, slice in
                Slice(label: slice.label, value: slice.value, color: palette[idx % palette.count])
            }

        case .grading:
            let graded = items.filter { $0.certNumber != nil }
            let raw = items.filter { $0.certNumber == nil }
            let gradedVal = graded.reduce(0.0) { $0 + $1.estimatedValue.amount.doubleValue }
            let rawVal = raw.reduce(0.0) { $0 + $1.estimatedValue.amount.doubleValue }
            return [
                Slice(label: "Graded (\(graded.count))", value: gradedVal, color: Theme.gain),
                Slice(label: "Raw (\(raw.count))", value: rawVal, color: Theme.cream),
            ].sorted { $0.value > $1.value }
        }
    }

    @ViewBuilder private var donutChart: some View {
        let total = slices.reduce(0.0) { $0 + $1.value }
        ZStack {
            if total > 0 {
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2 - 8
                    let innerRadius = radius * 0.62
                    var startAngle = Angle.degrees(-90)

                    for slice in slices {
                        if slice.value <= 0 { continue }
                        let fraction = slice.value / total
                        let endAngle = startAngle + .degrees(360 * fraction)
                        let path = Path { p in
                            p.move(to: point(center, innerRadius, startAngle))
                            p.addArc(center: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                            p.addLine(to: point(center, radius, endAngle))
                            p.addArc(center: center, radius: radius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                            p.closeSubpath()
                        }
                        ctx.fill(path, with: .color(slice.color))
                        startAngle = endAngle
                    }
                }
                .frame(width: 220, height: 220)

                VStack(spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(Money(amount: Decimal(total)).formatted)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textTertiary)
                    Text("No data")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(height: 220)
            }
        }
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Angle) -> CGPoint {
        CGPoint(x: center.x + cos(angle.radians) * radius, y: center.y + sin(angle.radians) * radius)
    }

    @ViewBuilder private var legend: some View {
        let total = slices.reduce(0.0) { $0 + $1.value }
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(slices) { slice in
                HStack(spacing: Theme.Spacing.sm) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(Money(amount: Decimal(slice.value)).formatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(total > 0 ? "\(Int(slice.value / total * 100))%" : "0%")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
