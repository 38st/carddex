import Foundation

/// Computes a 0-100 collection health score from diversification, liquidity,
/// condition distribution, and trend momentum. Like a credit score for your
/// collection — shareable and gamified.
struct CollectionHealthScore {

    struct Breakdown {
        let overall: Int
        let diversification: Int
        let liquidity: Int
        let condition: Int
        let momentum: Int
        let grade: String
        let advice: [String]
    }

    @MainActor
    static func compute(
        items: [CollectionItem],
        marketStore: MarketStore,
        portfolioHistory: PortfolioHistoryStore
    ) -> Breakdown {
        guard !items.isEmpty else {
            return Breakdown(overall: 0, diversification: 0, liquidity: 0, condition: 0, momentum: 0, grade: "—", advice: ["Add cards to your collection to get a health score."])
        }

        let diversification = computeDiversification(items)
        let liquidity = computeLiquidity(items)
        let condition = computeCondition(items)
        let momentum = computeMomentum(items: items, marketStore: marketStore)

        // Weighted average: diversification 25%, liquidity 25%, condition 20%, momentum 30%.
        let overall = Int(
            Double(diversification) * 0.25 +
            Double(liquidity) * 0.25 +
            Double(condition) * 0.20 +
            Double(momentum) * 0.30
        )

        let grade = gradeFor(overall)
        let advice = adviceFor(diversification: diversification, liquidity: liquidity, condition: condition, momentum: momentum, items: items)

        return Breakdown(
            overall: overall,
            diversification: diversification,
            liquidity: liquidity,
            condition: condition,
            momentum: momentum,
            grade: grade,
            advice: advice
        )
    }

    // MARK: - Components

    /// How spread across games/sports. 1 game = 20, 2 = 50, 3 = 75, 4+ = 100.
    @MainActor
    private static func computeDiversification(_ items: [CollectionItem]) -> Int {
        let games = Set(items.map { $0.card.game })
        let sports = Set(items.compactMap { $0.card.sport })
        let categories = games.count + max(0, sports.count - (games.contains(.sports) ? 1 : 0))

        switch categories {
        case 0: return 0
        case 1: return 20
        case 2: return 50
        case 3: return 75
        default: return 100
        }
    }

    /// How liquid the collection is. Based on % of items with a market price
    /// and the proportion of value in the top 3 holdings (concentration risk).
    @MainActor
    private static func computeLiquidity(_ items: [CollectionItem]) -> Int {
        let withPrice = items.filter { $0.card.marketPrice != nil }
        let pricedRatio = items.isEmpty ? 0 : Double(withPrice.count) / Double(items.count)

        let totalValue = NSDecimalNumber(decimal: items.reduce(Money.zero) { $0 + $1.estimatedValue }.amount).doubleValue
        let top3Value = NSDecimalNumber(decimal: items
            .sorted { $0.estimatedValue.amount > $1.estimatedValue.amount }
            .prefix(3)
            .reduce(Money.zero) { $0 + $1.estimatedValue }
            .amount).doubleValue
        let concentration = totalValue > 0 ? top3Value / totalValue : 1.0

        // High priced ratio + low concentration = high liquidity.
        let concentrationScore = max(0, 100 - Int(concentration * 100))
        return Int(pricedRatio * 60 + Double(concentrationScore) * 0.4)
    }

    /// Condition distribution. More Mint/NM = higher score.
    @MainActor
    private static func computeCondition(_ items: [CollectionItem]) -> Int {
        let scores: [CardCondition: Int] = [
            .mint: 100,
            .nearMint: 85,
            .lightlyPlayed: 65,
            .moderatelyPlayed: 40,
            .heavilyPlayed: 20,
            .damaged: 5,
        ]
        let total = items.reduce(0) { $0 + (scores[$1.condition] ?? 50) }
        return items.isEmpty ? 0 : total / items.count
    }

    /// Trend momentum from market data. Average of 30d changes weighted by value.
    @MainActor
    private static func computeMomentum(items: [CollectionItem], marketStore: MarketStore) -> Int {
        let weighted = items.compactMap { item -> (change: Double, weight: Double)? in
            guard let market = marketStore.market[item.card.id] else { return nil }
            let weight = NSDecimalNumber(decimal: item.estimatedValue.amount).doubleValue
            return (market.change30d, weight)
        }

        guard !weighted.isEmpty else { return 50 }

        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 50 }

        let weightedChange = weighted.reduce(0) { $0 + ($1.change * $1.weight) } / totalWeight

        // Map -20% → 0, 0% → 50, +20% → 100.
        let score = 50 + weightedChange * 2.5
        return max(0, min(100, Int(score)))
    }

    // MARK: - Grading

    private static func gradeFor(_ score: Int) -> String {
        switch score {
        case 90...: return "Excellent"
        case 75..<90: return "Strong"
        case 60..<75: return "Good"
        case 40..<60: return "Fair"
        case 20..<40: return "Weak"
        default: return "Poor"
        }
    }

    private static func adviceFor(diversification: Int, liquidity: Int, condition: Int, momentum: Int, items: [CollectionItem]) -> [String] {
        var tips: [String] = []
        if diversification < 50 {
            tips.append("Diversify across more games or sports to reduce concentration risk.")
        }
        if liquidity < 50 {
            let topItem = items.max(by: { $0.estimatedValue.amount < $1.estimatedValue.amount })
            if let top = topItem {
                tips.append("Your \(top.card.name) dominates portfolio value — consider rebalancing.")
            }
        }
        if condition < 60 {
            tips.append("Several cards are in played condition — grading or upgrading could boost value.")
        }
        if momentum < 40 {
            tips.append("Market trends are dragging your portfolio down — review underperformers.")
        }
        if tips.isEmpty {
            tips.append("Your collection is well-balanced. Keep tracking and adding strategically.")
        }
        return tips
    }
}
