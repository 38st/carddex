import SwiftUI

/// "Should you grade or sell raw?" — an actionable recommendation card that
/// combines raw price, PSA 9/10 prices, and grading fees into a clear verdict.
/// Shown inline on MarketCardView when graded price data is available.
struct GradeOrSellCard: View {
    let market: CardMarket?
    @State private var showCalculator = false

    private struct Recommendation {
        let verdict: String
        let icon: String
        let color: Color
        let detail: String
        let netProfit: Double
        let roi: Double
    }

    private func compute() -> Recommendation? {
        guard let grades = market?.gradedPrices,
              let raw = grades.first(where: { $0.grade == "Raw" }),
              let psa9 = grades.first(where: { $0.grade == "PSA 9" }),
              let psa10 = grades.first(where: { $0.grade == "PSA 10" })
        else { return nil }

        let rawValue = NSDecimalNumber(decimal: raw.price.amount).doubleValue
        let psa9Value = NSDecimalNumber(decimal: psa9.price.amount).doubleValue
        let psa10Value = NSDecimalNumber(decimal: psa10.price.amount).doubleValue
        let gradingFee = 25.0 // PSA Regular — TODO: make configurable per company/service level

        // Expected value: weighted average of PSA 10 (20%), PSA 9 (55%), PSA 8 (25%).
        // Conservative — most raw cards don't gem. Weights sum to 1.0.
        let psa8Value = psa9Value * 0.65 // estimate PSA 8 at 65% of PSA 9 when no explicit data
        let expectedGradedValue = psa10Value * 0.20 + psa9Value * 0.55 + psa8Value * 0.25
        let totalCost = rawValue + gradingFee
        let netProfit = expectedGradedValue - totalCost
        let roi = totalCost > 0 ? netProfit / totalCost * 100 : 0

        if netProfit > 0 && roi > 15 {
            return Recommendation(
                verdict: "Grade it",
                icon: "checkmark.seal.fill",
                color: Theme.gain,
                detail: "Expected value \(Money(amount: Decimal(expectedGradedValue)).formatted) vs cost \(Money(amount: Decimal(totalCost)).formatted) — grading is worth it.",
                netProfit: netProfit,
                roi: roi
            )
        } else if netProfit > 0 {
            return Recommendation(
                verdict: "Maybe grade",
                icon: "minus.circle",
                color: Theme.cream,
                detail: "Slim margin: \(Money(amount: Decimal(netProfit)).formatted) expected profit. Only grade if you're confident in a PSA 10.",
                netProfit: netProfit,
                roi: roi
            )
        } else {
            return Recommendation(
                verdict: "Sell raw",
                icon: "xmark.seal.fill",
                color: Theme.loss,
                detail: "Grading costs \(Money(amount: Decimal(gradingFee)).formatted) — you'd lose \(Money(amount: Decimal(abs(netProfit))).formatted) on average.",
                netProfit: netProfit,
                roi: roi
            )
        }
    }

    var body: some View {
        if let rec = compute() {
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: rec.icon)
                        .font(.title2)
                        .foregroundStyle(rec.color)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(rec.verdict)
                            .font(.headline)
                            .foregroundStyle(rec.color)
                        Text(rec.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(3)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(rec.netProfit >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(rec.netProfit))).formatted)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(rec.netProfit >= 0 ? Theme.gain : Theme.loss)
                            .monospacedDigit()
                        Text("\(rec.roi >= 0 ? "+" : "")\(String(format: "%.0f", rec.roi))% ROI")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }
                }

                Button { showCalculator = true } label: {
                    Label("Open PSA calculator", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                }
                .padding(.top, 2)
            }
            .padding(Theme.Spacing.md)
            .glassPanel(cornerRadius: Theme.Radius.card)
            .sheet(isPresented: $showCalculator) {
                PSACalculatorView()
            }
        }
    }
}
