import SwiftUI

/// Collection health score: a single 0-100 metric combining diversification,
/// liquidity, condition, and momentum. Shareable, gamified, blue ocean feature.
struct HealthScoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store
    @Environment(MarketStore.self) private var marketStore
    @Environment(PortfolioHistoryStore.self) private var history
    @State private var shareImage: Image?

    private var breakdown: CollectionHealthScore.Breakdown {
        CollectionHealthScore.compute(items: store.items, marketStore: marketStore, portfolioHistory: history)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        scoreRing

                        metricsGrid

                        adviceSection

                        if let shareImage {
                            ShareLink(item: shareImage, preview: SharePreview("My collection health score", image: shareImage)) {
                                PrimaryButton(title: "Share score", systemImage: "square.and.arrow.up") {}
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Health Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .onAppear(perform: renderShareImage)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(Theme.cream)
            Text("Collection Health Score")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("A single metric for your portfolio's diversification, liquidity, condition, and momentum.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var scoreRing: some View {
        let score = breakdown.overall
        let color = colorFor(score)
        return VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.springUI, value: score)
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(breakdown.grade)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
            .frame(width: 160, height: 160)
        }
    }

    private var metricsGrid: some View {
        VStack(spacing: Theme.Spacing.sm) {
            metricBar("Diversification", breakdown.diversification, icon: "square.grid.3x3")
            metricBar("Liquidity", breakdown.liquidity, icon: "dollarsign.circle")
            metricBar("Condition", breakdown.condition, icon: "sparkles")
            metricBar("Momentum", breakdown.momentum, icon: "chart.line.uptrend.xyaxis")
        }
    }

    private func metricBar(_ label: String, _ value: Int, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(value)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(colorFor(value))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(colorFor(value))
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 6)
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Recommendations")
            ForEach(breakdown.advice, id: \.self) { tip in
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.cream)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(Theme.Spacing.sm)
                .glassPanel(cornerRadius: Theme.Radius.card)
            }
        }
    }

    private func colorFor(_ score: Int) -> Color {
        switch score {
        case 75...: return Theme.gain
        case 50..<75: return Theme.cream
        case 25..<50: return Color(hex: 0xF0997B)
        default: return Theme.loss
        }
    }

    @MainActor private func renderShareImage() {
        let poster = HealthScorePoster(score: breakdown.overall, grade: breakdown.grade)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

private struct HealthScorePoster: View {
    let score: Int
    let grade: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("The Case")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            Spacer()
            Text("Collection Health Score")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(score)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(grade)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .padding(30)
        .frame(width: 400, height: 500)
        .background(
            LinearGradient(colors: [Color(hex: 0x1A1A2E), Color(hex: 0x16213E)], startPoint: .top, endPoint: .bottom)
        )
    }
}
