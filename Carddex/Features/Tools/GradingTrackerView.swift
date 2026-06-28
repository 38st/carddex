import SwiftUI

/// Grading submission tracker: track cards sent to PSA/CGC/BGS through the
/// submission pipeline with status updates, expected return dates, and
/// cost tracking. Blue ocean — no competitor has this.
struct GradingTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = GradingStore()
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        summaryCard

                        if !store.activeSubmissions.isEmpty {
                            sectionHeader("In Progress", count: store.activeSubmissions.count)
                            ForEach(store.activeSubmissions) { sub in
                                submissionCard(sub)
                            }
                        }

                        if !store.completedSubmissions.isEmpty {
                            sectionHeader("Completed", count: store.completedSubmissions.count)
                            ForEach(store.completedSubmissions) { sub in
                                submissionCard(sub)
                            }
                        }

                        if store.submissions.isEmpty {
                            emptyState
                        }

                        PrimaryButton(title: "New Submission", systemImage: "plus") {
                            showAddSheet = true
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Grading Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSubmissionSheet(store: store)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var summaryCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            statBlock("\(store.inTransitCount)", label: "In transit")
            Divider().frame(height: 40).overlay(Theme.hairline)
            statBlock("\(store.completedSubmissions.count)", label: "Completed")
            Divider().frame(height: 40).overlay(Theme.hairline)
            statBlock(Money(amount: Decimal(store.totalSpent)).formatted, label: "Total spent")
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private func statBlock(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            SectionHeader(title)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .monospacedDigit()
        }
    }

    private func submissionCard(_ sub: GradingSubmission) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                CardArtwork(game: sub.card.game, rarity: sub.card.rarity, price: sub.card.marketPrice, imageURL: sub.card.imageURL, sport: sub.card.sport)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.card.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(sub.company.rawValue) · \(sub.serviceLevel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(sub.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor(sub.status))
                    if let days = sub.daysRemaining {
                        if sub.isOverdue {
                            Text("Overdue \(-days)d")
                                .font(.caption2)
                                .foregroundStyle(Theme.loss)
                                .monospacedDigit()
                        } else {
                            Text("\(days)d left")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            // Status pipeline
            HStack(spacing: 0) {
                ForEach(GradingSubmission.SubmissionStatus.allCases, id: \.self) { status in
                    HStack(spacing: 0) {
                        Circle()
                            .fill(statusOrder(status) <= statusOrder(sub.status) ? statusColor(sub.status) : Color.white.opacity(0.1))
                            .frame(width: 10, height: 10)
                        if status != .completed {
                            Rectangle()
                                .fill(statusOrder(status) < statusOrder(sub.status) ? statusColor(sub.status) : Color.white.opacity(0.06))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            if let result = sub.resultGrade {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.gain)
                    Text("Graded \(result)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gain)
                    if let cert = sub.certNumber {
                        Text("· Cert #\(cert)")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }
                    Spacer()
                }
            }

            if !sub.isCompleted, sub.status.next != nil {
                Button {
                    Haptics.selection()
                    store.advance(sub)
                } label: {
                    Label("Advance to \(sub.status.next?.rawValue ?? "")", systemImage: "arrow.right.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "shippingbox")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("No submissions yet")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text("Track cards you send to PSA, CGC, or BGS — from submission to slab.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }

    private func statusColor(_ status: GradingSubmission.SubmissionStatus) -> Color {
        switch status {
        case .completed: Theme.gain
        case .preparing: Theme.textTertiary
        default: Theme.cream
        }
    }

    private func statusOrder(_ status: GradingSubmission.SubmissionStatus) -> Int {
        GradingSubmission.SubmissionStatus.allCases.firstIndex(of: status) ?? 0
    }
}

struct AddSubmissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: GradingStore
    @State private var cardName = ""
    @State private var company: GradingSubmission.GradingCompany = .psa
    @State private var game: CardGame = .pokemon
    @State private var serviceLevel = "Regular"
    @State private var costText = "25"
    @State private var expectedWeeks = 6
    @State private var notes = ""

    private var cost: Double { Double(costText) ?? 25 }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        field("Card name") {
                            HStack {
                                Image(systemName: "rectangle.stack").foregroundStyle(Theme.textSecondary)
                                TextField("e.g. Charizard", text: $cardName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        field("Game") {
                            Picker("Game", selection: $game) {
                                Text("Pokémon").tag(CardGame.pokemon)
                                Text("Magic").tag(CardGame.magic)
                                Text("Yu-Gi-Oh!").tag(CardGame.yugioh)
                                Text("Sports").tag(CardGame.sports)
                            }
                            .pickerStyle(.segmented)
                            .tint(Theme.cream)
                        }

                        field("Grading company") {
                            Picker("Company", selection: $company) {
                                ForEach(GradingSubmission.GradingCompany.allCases) { c in
                                    Text(c.rawValue).tag(c)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(Theme.cream)
                        }

                        field("Service level") {
                            Picker("Service", selection: $serviceLevel) {
                                Text("Value ($19)").tag("Value")
                                Text("Regular ($25)").tag("Regular")
                                Text("Express ($75)").tag("Express")
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.cream)
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        field("Cost ($)") {
                            HStack {
                                Text("$").foregroundStyle(Theme.textSecondary)
                                TextField("25", text: $costText)
                                    .keyboardType(.decimalPad)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        field("Expected turnaround (weeks)") {
                            Stepper("\(expectedWeeks) weeks", value: $expectedWeeks, in: 1...26)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(Theme.Spacing.md)
                                .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        field("Notes") {
                            TextField("Optional notes", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(Theme.Spacing.md)
                                .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        PrimaryButton(title: "Add submission", systemImage: "plus") {
                            let card = Card(id: "manual-\(cardName.lowercased().replacingOccurrences(of: " ", with: "-"))", game: game, name: cardName, setName: "", number: "")
                            let expected = Calendar.current.date(byAdding: .weekOfYear, value: expectedWeeks, to: Date())
                            store.add(GradingSubmission(
                                card: card,
                                company: company,
                                expectedReturnDate: expected,
                                serviceLevel: serviceLevel,
                                cost: cost,
                                notes: notes
                            ))
                            Haptics.success()
                            dismiss()
                        }
                        .disabled(cardName.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Submission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
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
