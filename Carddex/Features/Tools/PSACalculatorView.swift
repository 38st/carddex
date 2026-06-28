import SwiftUI

/// PSA profit calculator: card cost + grading fee + estimated grade → projected ROI.
/// Helps collectors decide whether grading a card is worth the $25+ fee.
struct PSACalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cardCostText = ""
    @State private var selectedService: GradingService = .psaValue
    @State private var estimatedGrade: String = "PSA 9"
    @State private var gradedValueText = ""

    enum GradingService: String, CaseIterable, Identifiable {
        case psaValue = "PSA Value ($19)"
        case psaRegular = "PSA Regular ($25)"
        case psaExpress = "PSA Express ($75)"
        case cgcStandard = "CGC Standard ($30)"
        case bgsStandard = "BGS Standard ($30)"

        var id: String { rawValue }
        var fee: Double {
            switch self {
            case .psaValue: 19
            case .psaRegular: 25
            case .psaExpress: 75
            case .cgcStandard: 30
            case .bgsStandard: 30
            }
        }
        var gradeOptions: [String] {
            switch self {
            case .psaValue, .psaRegular, .psaExpress: ["PSA 8", "PSA 9", "PSA 10"]
            case .cgcStandard: ["CGC 8", "CGC 9", "CGC 10"]
            case .bgsStandard: ["BGS 8", "BGS 9", "BGS 10"]
            }
        }
    }

    private var cardCost: Double { Double(cardCostText) ?? 0 }
    private var gradedValue: Double { Double(gradedValueText) ?? 0 }
    private var gradingFee: Double { selectedService.fee }
    private var totalCost: Double { cardCost + gradingFee }
    private var profit: Double { gradedValue - totalCost }
    private var roi: Double {
        guard totalCost > 0 else { return 0 }
        return profit / totalCost * 100
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        field("Card cost (what you paid)") {
                            HStack {
                                Text("$").foregroundStyle(Theme.textSecondary)
                                TextField("0.00", text: $cardCostText)
                                    .keyboardType(.decimalPad)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        field("Grading service") {
                            Picker("Service", selection: $selectedService) {
                                ForEach(GradingService.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.cream)
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        field("Estimated grade") {
                            Picker("Grade", selection: $estimatedGrade) {
                                ForEach(selectedService.gradeOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .tint(Theme.cream)
                        }

                        field("Estimated graded value") {
                            HStack {
                                Text("$").foregroundStyle(Theme.textSecondary)
                                TextField("0.00", text: $gradedValueText)
                                    .keyboardType(.decimalPad)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        resultsCard

                        recommendation
                    }
                    .padding()
                }
            }
            .navigationTitle("PSA Profit Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedService) { _, svc in
            estimatedGrade = svc.gradeOptions.last ?? "PSA 10"
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36))
                .foregroundStyle(Theme.cream)
            Text("Should you grade this card?")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Enter your card cost, pick a grading service, and estimate the graded value to see if it's worth it.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var resultsCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            resultRow("Grading fee", Money(amount: Decimal(gradingFee)).formatted)
            resultRow("Total cost", Money(amount: Decimal(totalCost)).formatted)
            Divider().overlay(Theme.hairline)
            HStack {
                Text("Projected profit").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(profit >= 0 ? "+" : "−")\(Money(amount: Decimal(abs(profit))).formatted)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(profit >= 0 ? Theme.gain : Theme.loss)
                    .monospacedDigit()
            }
            HStack {
                Text("ROI").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(roi >= 0 ? "+" : "")\(String(format: "%.0f", roi))%")
                    .font(.headline)
                    .foregroundStyle(roi >= 0 ? Theme.gain : Theme.loss)
                    .monospacedDigit()
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    @ViewBuilder private var recommendation: some View {
        if totalCost > 0 && gradedValue > 0 {
            let isWorthIt = profit > 0
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: isWorthIt ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isWorthIt ? Theme.gain : Theme.loss)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isWorthIt ? "Grade it" : "Sell raw")
                        .font(.headline)
                        .foregroundStyle(isWorthIt ? Theme.gain : Theme.loss)
                    Text(isWorthIt
                         ? "Grading could add \(Money(amount: Decimal(profit)).formatted) in value."
                         : "Grading costs \(Money(amount: Decimal(gradingFee)).formatted) — you'd lose \(Money(amount: Decimal(abs(profit))).formatted).")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .glassPanel(cornerRadius: Theme.Radius.card)
        }
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .font(.subheadline)
    }

    @ViewBuilder private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}
