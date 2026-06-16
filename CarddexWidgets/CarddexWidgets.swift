import WidgetKit
import SwiftUI

// MARK: - Timeline

struct CaseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct CaseProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaseEntry {
        CaseEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CaseEntry) -> Void) {
        completion(CaseEntry(date: Date(), snapshot: WidgetBridge.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaseEntry>) -> Void) {
        let entry = CaseEntry(date: Date(), snapshot: WidgetBridge.read() ?? .placeholder)
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Sparkline

private struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: CGPoint(x: f.x, y: geo.size.height))
                    p.addLine(to: f)
                    for q in pts.dropFirst() { p.addLine(to: q) }
                    p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))

                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: f)
                    for q in pts.dropFirst() { p.addLine(to: q) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let lo = values.min(), let hi = values.max(), hi > lo else { return [] }
        return values.enumerated().map { i, v in
            CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                    y: size.height * (1 - CGFloat((v - lo) / (hi - lo))))
        }
    }
}

// MARK: - Views

struct CaseIndexView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        let up = snapshot.indexChange >= 0
        let accent = up ? Theme.gain : Theme.loss
        let changeText = "\(up ? "+" : "")\(String(format: "%.1f", snapshot.indexChange))%"
        let valueText = snapshot.indexValue.formatted(.number.precision(.fractionLength(2)))

        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 1) {
                Text("CASE INDEX").font(.caption2).foregroundStyle(.secondary)
                Text(valueText).font(.headline.weight(.bold))
                Text(changeText).font(.caption2.weight(.semibold))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Case Index", systemImage: "chart.xyaxis.line")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(changeText).font(.caption2.weight(.bold)).foregroundStyle(accent)
                }
                Text(valueText)
                    .font(.system(size: family == .systemMedium ? 34 : 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if family == .systemMedium {
                    Sparkline(values: snapshot.indexSeries, tint: accent).frame(height: 48)
                }
                Spacer(minLength: 0)
                Text("Top mover · \(snapshot.topMoverName)")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

struct PortfolioWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Collection", systemImage: "square.stack")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Text(snapshot.portfolioValue)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(snapshot.portfolioGain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.gainUp ? Theme.gain : Theme.loss)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widgets

struct CaseIndexWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaseIndexWidget", provider: CaseProvider()) { entry in
            CaseIndexView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.bg }
        }
        .configurationDisplayName("Case Index")
        .description("The market at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct PortfolioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PortfolioWidget", provider: CaseProvider()) { entry in
            PortfolioWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Theme.bg }
        }
        .configurationDisplayName("Collection Value")
        .description("Your collection's value and today's gain.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct CarddexWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaseIndexWidget()
        PortfolioWidget()
    }
}
