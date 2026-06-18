import SwiftUI

/// A small filled-area sparkline. When `interactive`, drag to scrub: a value flag
/// follows your finger, with a haptic tick on each point and a firmer tap on the
/// all-time high/low.
struct MiniAreaChart: View {
    var values: [Double]
    var tint: Color = Theme.accent
    var interactive: Bool = false
    var valueFormat: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(2))) }

    @State private var selected: Int?

    private var peakIndex: Int? { values.indices.max(by: { values[$0] < values[$1] }) }
    private var troughIndex: Int? { values.indices.min(by: { values[$0] < values[$1] }) }

    var body: some View {
        GeometryReader { geo in
            let points = normalized(in: geo.size)
            let chart = ZStack(alignment: .topLeading) {
                Path { path in
                    guard let first = points.first, let last = points.last else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    path.addLine(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if interactive, let sel = selected, points.indices.contains(sel) {
                    scrubOverlay(point: points[sel], value: values[sel], size: geo.size)
                }
            }
            .contentShape(Rectangle())

            if interactive {
                chart.gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard points.count > 1 else { return }
                            let frac = value.location.x / geo.size.width
                            let idx = min(max(Int((frac * CGFloat(points.count - 1)).rounded()), 0), points.count - 1)
                            if idx != selected {
                                if idx == peakIndex || idx == troughIndex { Haptics.impact(.rigid) } else { Haptics.selection() }
                                selected = idx
                            }
                        }
                        .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { selected = nil } }
                )
            } else {
                chart
            }
        }
    }

    @ViewBuilder
    private func scrubOverlay(point: CGPoint, value: Double, size: CGSize) -> some View {
        Path { $0.move(to: CGPoint(x: point.x, y: 0)); $0.addLine(to: CGPoint(x: point.x, y: size.height)) }
            .stroke(Theme.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        Circle()
            .fill(tint)
            .frame(width: 9, height: 9)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .position(point)

        Text(valueFormat(value))
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .glassCapsule()
            .fixedSize()
            .position(x: min(max(point.x, 32), size.width - 32), y: max(point.y - 16, 10))
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let lo = values.min(), let hi = values.max(), hi > lo else { return [] }
        return values.enumerated().map { index, value in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                y: size.height * (1 - CGFloat((value - lo) / (hi - lo)))
            )
        }
    }
}
