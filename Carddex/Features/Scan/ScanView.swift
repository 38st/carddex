import SwiftUI

/// The scan screen: live on-device text scanning on a real device (simulator
/// falls back to a simulated scan), then identify → confirm / pick / manual.
struct ScanView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(SubscriptionStore.self) private var subs

    @State private var recognizedText: [String] = []
    @State private var isIdentifying = false
    @State private var outcome: IdentificationOutcome?
    @State private var showResult = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)
                cameraArea
                    .aspectRatio(0.82, contentMode: .fit)
                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryButton(
                    title: isIdentifying ? "Identifying…" : "Scan card",
                    systemImage: isIdentifying ? "sparkles" : "viewfinder"
                ) {
                    if subs.canScan {
                        Task { await identify() }
                    } else {
                        showPaywall = true
                    }
                }
                .disabled(isIdentifying)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Scan")
            .sheet(isPresented: $showResult) {
                if let outcome {
                    IdentifyResultSheet(outcome: outcome) { card in
                        store.add(card)
                        showResult = false
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder private var cameraArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Color.white.opacity(0.02))

            if CameraScanView.isSupported {
                CameraScanView { lines in recognizedText = lines }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.accent)
                    Text("Camera runs on a real device")
                        .foregroundStyle(Theme.textSecondary)
                    Text("Tap Scan to simulate identifying a card")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding()
            }

            ScanReticle(active: isIdentifying)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(Theme.hairline)
        )
    }

    private var statusText: String {
        if isIdentifying { return "Reading the card…" }
        if !subs.isPro { return "\(subs.remainingFreeScans) free scans left this month." }
        if CameraScanView.isSupported { return "Point at a card, then tap Scan." }
        return "Live camera + AI identification run on a real device."
    }

    private func identify() async {
        isIdentifying = true
        defer { isIdentifying = false }
        let input = ScanInput(imageData: Data(), ocrText: recognizedText, gameHint: nil)
        do {
            outcome = try await env.identification.identify(input)
        } catch {
            outcome = .unidentified(ocrText: recognizedText)
        }
        subs.recordScan()
        showResult = true
    }
}

/// Accent scan frame — dashed while idle, solid while identifying.
private struct ScanReticle: View {
    var active: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .strokeBorder(
                Theme.accent.opacity(active ? 0.9 : 0.5),
                style: StrokeStyle(lineWidth: active ? 3 : 2, dash: active ? [] : [9])
            )
            .padding(20)
            .animation(Theme.springUI, value: active)
    }
}

/// Shows an identification result and routes to confirm / pick / manual.
private struct IdentifyResultSheet: View {
    let outcome: IdentificationOutcome
    let onAdd: (Card) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch outcome {
                case .confident(let candidate): confirm(candidate.card)
                case .ambiguous(let candidates): picker(candidates)
                case .unidentified(let ocr): manual(ocr)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(.regularMaterial)
        }
    }

    private var title: String {
        switch outcome {
        case .confident: "Identified"
        case .ambiguous: "Is this your card?"
        case .unidentified: "Not sure"
        }
    }

    private func confirm(_ card: Card) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice)
                .frame(maxWidth: 150)
                .padding(.top)
            GamePill(game: card.game)
            Text(card.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(card.setName) · \(card.number)")
                .foregroundStyle(Theme.textSecondary)
            if let price = card.marketPrice {
                Text(price.formatted)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
            Spacer()
            PrimaryButton(title: "Add to collection", systemImage: "plus") { onAdd(card) }
        }
        .padding()
    }

    private func picker(_ candidates: [IdentificationCandidate]) -> some View {
        List(candidates) { candidate in
            Button {
                onAdd(candidate.card)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    CardArtwork(game: candidate.card.game, rarity: candidate.card.rarity, price: candidate.card.marketPrice)
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.card.name).foregroundStyle(Theme.textPrimary)
                        Text(candidate.card.setName).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(candidate.confidence * 100))%")
                        .font(.caption).foregroundStyle(Theme.textTertiary).monospacedDigit()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func manual(_ ocr: [String]) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary)
            Text("Couldn't identify that card")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Manual search arrives next.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            if !ocr.isEmpty {
                Text(ocr.prefix(6).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PrimaryButton(title: "Try again", systemImage: "arrow.clockwise") { dismiss() }
        }
        .padding()
    }
}

#Preview {
    ScanView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment())
        .environment(SubscriptionStore())
}
