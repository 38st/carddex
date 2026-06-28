import SwiftUI

/// Tools hub: central entry point for calculator, insurance report,
/// cert lookup, CSV import/export, and health score.
struct ToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPSA = false
    @State private var showInsurance = false
    @State private var showCert = false
    @State private var showCSV = false
    @State private var showHealth = false
    @State private var showGrading = false
    @State private var showCompletion = false
    @State private var showTrade = false
    @State private var showAllocation = false

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(tools) { tool in
                            Button { tool.action() } label: { toolRow(tool) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPSA) { PSACalculatorView() }
        .sheet(isPresented: $showInsurance) { InsuranceReportView() }
        .sheet(isPresented: $showCert) { CertLookupView() }
        .sheet(isPresented: $showCSV) { CSVImportExportView() }
        .sheet(isPresented: $showHealth) { HealthScoreView() }
        .sheet(isPresented: $showGrading) { GradingTrackerView() }
        .sheet(isPresented: $showCompletion) { SetCompletionView() }
        .sheet(isPresented: $showTrade) { TradeModeView() }
        .sheet(isPresented: $showAllocation) { AllocationChartsView() }
    }

    private struct Tool: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let badge: String?
        let action: () -> Void
    }

    private var tools: [Tool] {
        [
            Tool(icon: "heart.text.clipboard", title: "Health Score", subtitle: "How healthy is your collection?", badge: "NEW", action: { showHealth = true }),
            Tool(icon: "shippingbox", title: "Grading Tracker", subtitle: "Track PSA / CGC / BGS submissions", badge: "NEW", action: { showGrading = true }),
            Tool(icon: "square.stack.3d.up.fill", title: "Set Completion", subtitle: "Track set progress across your collection", badge: "NEW", action: { showCompletion = true }),
            Tool(icon: "arrow.left.arrow.right.square.fill", title: "Trade Mode", subtitle: "Compare trade values with fairness check", badge: "NEW", action: { showTrade = true }),
            Tool(icon: "chart.pie.fill", title: "Allocation Charts", subtitle: "Diversification by game, set, condition", badge: "NEW", action: { showAllocation = true }),
            Tool(icon: "wand.and.stars", title: "PSA Profit Calculator", subtitle: "Should you grade or sell raw?", badge: nil, action: { showPSA = true }),
            Tool(icon: "doc.text.fill", title: "Insurance Report", subtitle: "PDF valuation for underwriters", badge: "PRO", action: { showInsurance = true }),
            Tool(icon: "checkmark.seal.fill", title: "Cert Lookup", subtitle: "Verify PSA / CGC / BGS slabs", badge: nil, action: { showCert = true }),
            Tool(icon: "tablecells.fill", title: "Import / Export CSV", subtitle: "Backup or migrate your collection", badge: nil, action: { showCSV = true }),
        ]
    }

    private func toolRow(_ tool: Tool) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: tool.icon)
                .font(.title2)
                .foregroundStyle(Theme.cream)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tool.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let badge = tool.badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(badge == "PRO" ? Theme.cream.opacity(0.2) : Theme.gain.opacity(0.2), in: Capsule())
                            .overlay(Capsule().strokeBorder(badge == "PRO" ? Theme.cream.opacity(0.5) : Theme.gain.opacity(0.5)))
                            .foregroundStyle(badge == "PRO" ? Theme.cream : Theme.gain)
                    }
                }
                Text(tool.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }
}
