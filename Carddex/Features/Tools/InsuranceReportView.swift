import SwiftUI
import PDFKit
import UIKit

/// Insurance valuation report: generates a PDF of the collection's total
/// value, itemized with grades + market prices, formatted for insurance
/// underwriters. Pro-gated blue ocean feature.
struct InsuranceReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store
    @Environment(SubscriptionStore.self) private var subs

    @State private var pdfURL: URL?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header
                        summaryCard
                        itemsPreview
                        generateButton
                        if let pdfURL {
                            shareButton(pdfURL)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insurance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL { ShareSheet(items: [pdfURL]) }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.cream)
            Text("Collection Valuation Report")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Generate a PDF for your insurance underwriter with itemized values, grades, and totals.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            row("Total cards", "\(store.totalCards)")
            row("Unique cards", "\(store.items.count)")
            row("Total value", store.totalValue.formatted)
            row("Total cost basis", store.totalCost.formatted)
            Divider().overlay(Theme.hairline)
            row("Unrealized gain/loss", "\(store.totalGainLoss.amount >= 0 ? "+" : "−")\(Money(amount: abs(store.totalGainLoss.amount)).formatted)")
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private var itemsPreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Itemized holdings (\(store.items.count))")
            ForEach(store.topHoldings.prefix(5)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.card.name).font(.subheadline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Text("\(item.card.setName) · \(item.condition.abbreviation) · ×\(item.quantity)")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(item.estimatedValue.formatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
                .padding(Theme.Spacing.sm)
                .glassPanel(cornerRadius: Theme.Radius.card)
            }
            if store.items.count > 5 {
                Text("…and \(store.items.count - 5) more in the full report")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var generateButton: some View {
        PrimaryButton(title: isGenerating ? "Generating…" : "Generate PDF Report", systemImage: "doc.text.fill") {
            if subs.isPro {
                Task { await generatePDF() }
            } else {
                showPaywall = true
            }
        }
        .disabled(isGenerating || store.items.isEmpty)
    }

    private func shareButton(_ url: URL) -> some View {
        PrimaryButton(title: "Share Report", systemImage: "square.and.arrow.up") {
            showShareSheet = true
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .font(.subheadline)
    }

    @MainActor
    private func generatePDF() async {
        isGenerating = true
        defer { isGenerating = false }

        let pdfData = buildPDF()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Carddex_Insurance_\(Date().timeIntervalSince1970).pdf")
        do {
            try pdfData.write(to: url)
            pdfURL = url
        } catch {
            pdfURL = nil
        }
    }

    @MainActor
    private func buildPDF() -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            // Title.
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            "The Case — Collection Valuation Report".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray,
            ]
            "Generated: \(Date().formatted(date: .long, time: .shortened))".draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttrs)
            y += 28

            // Summary.
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray,
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]

            "SUMMARY".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 20

            let summaries: [(String, String)] = [
                ("Total cards", "\(store.totalCards)"),
                ("Unique cards", "\(store.items.count)"),
                ("Total estimated value", store.totalValue.formatted),
                ("Total cost basis", store.totalCost.formatted),
                ("Unrealized gain/loss", "\(store.totalGainLoss.amount >= 0 ? "+" : "−")\(Money(amount: abs(store.totalGainLoss.amount)).formatted)"),
            ]
            for (label, value) in summaries {
                label.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                value.draw(at: CGPoint(x: pageWidth - margin - 150, y: y), withAttributes: valueAttrs)
                y += 18
            }
            y += 16

            // Itemized holdings.
            "ITEMIZED HOLDINGS".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 20

            let columns: [(String, CGFloat)] = [("Name", margin), ("Set", margin + 200), ("Cond.", margin + 340), ("Qty", margin + 400), ("Value", margin + 450)]
            for (label, x) in columns {
                label.draw(at: CGPoint(x: x, y: y), withAttributes: bodyAttrs)
            }
            y += 18

            for item in store.topHoldings {
                if y > pageHeight - margin - 20 {
                    context.beginPage()
                    y = margin
                }
                item.card.name.draw(at: CGPoint(x: margin, y: y), withAttributes: bodyAttrs)
                item.card.setName.draw(at: CGPoint(x: margin + 200, y: y), withAttributes: bodyAttrs)
                item.condition.abbreviation.draw(at: CGPoint(x: margin + 340, y: y), withAttributes: bodyAttrs)
                "\(item.quantity)".draw(at: CGPoint(x: margin + 400, y: y), withAttributes: bodyAttrs)
                item.estimatedValue.formatted.draw(at: CGPoint(x: margin + 450, y: y), withAttributes: valueAttrs)
                y += 16
            }

            // Footer.
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray,
            ]
            "Values are estimated from market data and are not guaranteed. For insurance purposes only.".draw(at: CGPoint(x: margin, y: pageHeight - margin), withAttributes: footerAttrs)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
