import SwiftUI
import PhotosUI
import UIKit

/// The scan screen: live on-device text scanning on a real device (simulator
/// falls back to a simulated scan), then identify → confirm / pick / manual.
struct ScanView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(SubscriptionStore.self) private var subs

    @State private var recognizedText: [String] = []
    @State private var isIdentifying = false
    @State private var scanPhase: ScanOverlay.Phase = .idle
    @State private var outcome: IdentificationOutcome?
    @State private var showResult = false
    @State private var showPaywall = false
    @State private var showBulk = false
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Scan") {
                    CircleIconButton(systemImage: "rectangle.stack") { showBulk = true }
                }
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

                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label("Choose from photos", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                .disabled(isIdentifying)

                Spacer(minLength: 0)
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabBarSafeArea()
            .sheet(isPresented: $showBulk) { BulkScanView() }
            .onChange(of: pickedPhoto) { _, item in
                Task { await identifyPickedPhoto(item) }
            }
            .sheet(isPresented: $showResult) {
                if let outcome {
                    IdentifyResultSheet(outcome: outcome) { card in
                        store.add(card)
                        Haptics.impact(.medium)
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

            ScanOverlay(phase: scanPhase)

            if isIdentifying {
                Color.black.opacity(0.35)
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Reading the card…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .glassCapsule()
                }
            }
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
        scanPhase = .scanning
        defer { isIdentifying = false; scanPhase = .idle }
        let input = ScanInput(imageData: Data(), ocrText: recognizedText, gameHint: nil)
        do {
            outcome = try await env.identification.identify(input)
            // Charge a scan only when the call returned an outcome. A thrown
            // error (offline/quota/server) leaves the quota untouched so a
            // network failure doesn't burn a free scan.
            subs.recordScan()
        } catch {
            outcome = .unidentified(ocrText: recognizedText)
        }
        scanPhase = .found
        notifyOutcome()
        try? await Task.sleep(for: .milliseconds(250))
        showResult = true
    }

    private func notifyOutcome() {
        switch outcome {
        case .confident: Haptics.success()
        case .unidentified: Haptics.warning()
        default: break
        }
    }

    private func identifyPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard subs.canScan else { showPaywall = true; return }
        isIdentifying = true
        scanPhase = .scanning
        defer { isIdentifying = false; scanPhase = .idle }
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data),
            let cgImage = image.cgImage
        else { return }
        let ocr = await CardTextRecognizer.recognize(cgImage)
        let jpeg = image.jpegData(compressionQuality: 0.8) ?? data
        let input = ScanInput(imageData: jpeg, ocrText: ocr, gameHint: nil)
        do {
            outcome = try await env.identification.identify(input)
            subs.recordScan()
        } catch {
            outcome = .unidentified(ocrText: ocr)
        }
        scanPhase = .found
        notifyOutcome()
        try? await Task.sleep(for: .milliseconds(250))
        showResult = true
        pickedPhoto = nil
    }
}

/// Shows an identification result and routes to confirm / pick / manual.
private struct IdentifyResultSheet: View {
    let outcome: IdentificationOutcome
    let onAdd: (Card) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var revealScale: CGFloat = 0.85
    @State private var revealOpacity: Double = 0
    @State private var shownPrice: Double = 0
    @State private var manualName = ""
    @State private var manualSet = ""
    @State private var manualGame: CardGame = .pokemon
    @State private var manualPrice = ""

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
        let priceValue = NSDecimalNumber(decimal: card.marketPrice?.amount ?? 0).doubleValue
        return VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.accent.opacity(0.35), .clear],
                                         center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300, height: 300)
                    .opacity(revealOpacity)
                LivingCardView(game: card.game, rarity: card.rarity, price: card.marketPrice,
                               imageURL: card.imageURL, sport: card.sport, maxWidth: 160)
                    .scaleEffect(revealScale)
                    .opacity(revealOpacity)
            }
            .padding(.top)
            GamePill(game: card.game, sport: card.sport)
            Text(card.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(card.setName) · \(card.number)")
                .foregroundStyle(Theme.textSecondary)
            if card.marketPrice != nil {
                Text(Money(amount: Decimal(shownPrice)).formatted)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shownPrice))
            }
            Spacer()
            PrimaryButton(title: "Add to collection", systemImage: "plus") { onAdd(card) }
        }
        .padding()
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                revealScale = 1
                revealOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
                shownPrice = priceValue
            }
        }
    }

    private func picker(_ candidates: [IdentificationCandidate]) -> some View {
        List(candidates) { candidate in
            Button {
                onAdd(candidate.card)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    CardArtwork(game: candidate.card.game, rarity: candidate.card.rarity, price: candidate.card.marketPrice, imageURL: candidate.card.imageURL, sport: candidate.card.sport)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Couldn't identify it — add it manually")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)

                labeled("Card name") {
                    TextField("e.g. Charizard", text: $manualName).textFieldStyle(.roundedBorder)
                }
                labeled("Set") {
                    TextField("e.g. Base Set", text: $manualSet).textFieldStyle(.roundedBorder)
                }
                labeled("Game") {
                    Picker("Game", selection: $manualGame) {
                        ForEach(CardGame.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                labeled("Price (USD, optional)") {
                    TextField("0.00", text: $manualPrice).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                }

                PrimaryButton(title: "Add card", systemImage: "plus") {
                    onAdd(manualCard())
                }
                .disabled(manualName.isEmpty)

                Button("Try again") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .onAppear {
            if manualName.isEmpty, let first = ocr.first { manualName = first }
        }
    }

    private func manualCard() -> Card {
        let price = Double(manualPrice).map { Money(amount: Decimal($0)) }
        return Card(id: "manual-\(UUID().uuidString)", game: manualGame, name: manualName,
                    setName: manualSet, number: "", rarity: nil, imageURL: nil, marketPrice: price)
    }

    @ViewBuilder private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}

#Preview {
    ScanView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment())
        .environment(SubscriptionStore())
}
