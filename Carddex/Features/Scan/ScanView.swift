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
                    CircleIconButton(systemImage: "rectangle.stack", label: "Bulk scan") { showBulk = true }
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
                        .foregroundStyle(Theme.cream)
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
                        .foregroundStyle(Theme.cream)
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
        // Live camera path: grab a real JPEG so the identify function gets the
        // actual card photo. Simulator (no camera) falls back to empty data
        // and ships just the OCR hint, matching the prior behavior.
        let jpeg = CameraScanView.isSupported ? await CameraScanView.capturePhoto() : nil
        let input = ScanInput(imageData: jpeg ?? Data(), ocrText: recognizedText, gameHint: nil)
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
    @Environment(AppEnvironment.self) private var env
    @State private var revealScale: CGFloat = 0.85
    @State private var revealOpacity: Double = 0
    @State private var shownPrice: Double = 0
    @State private var manualName = ""
    @State private var manualSet = ""
    @State private var manualGame: CardGame? = nil
    @State private var manualPrice = ""
    @State private var searchResults: [IdentificationCandidate] = []
    @State private var isSearching = false
    @State private var didSearch = false
    @State private var showUntracked = false

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
            .presentationBackground { VaultBackground() }
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
                    .fill(RadialGradient(colors: [Theme.cream.opacity(0.35), .clear],
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
                    .foregroundStyle(Theme.cream)
                    .monospacedDigit()
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
            shownPrice = priceValue
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
                Text("Couldn't auto-identify — search the catalog")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Pick the real card so it tracks price, set, and grade.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)

                searchField
                gameFilter
                results

                untrackedFallback

                Button("Try scanning again") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding()
        }
        // Re-runs (auto-cancelling the prior task) whenever the query or game
        // filter changes; runSearch() debounces before hitting the network.
        .task(id: SearchKey(query: manualName, game: manualGame)) {
            await runSearch()
        }
        .onAppear {
            if manualName.isEmpty, let first = ocr.first { manualName = first }
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
            TextField("Card name or number", text: $manualName)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !manualName.isEmpty {
                Button { manualName = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .glassCard(cornerRadius: Theme.Radius.md)
    }

    private var gameFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                Chip(title: "All games", isSelected: manualGame == nil) { manualGame = nil }
                ForEach(CardGame.allCases) { game in
                    Chip(title: game.displayName, isSelected: manualGame == game) { manualGame = game }
                }
            }
        }
    }

    @ViewBuilder private var results: some View {
        if isSearching {
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView()
                Text("Searching…").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
        } else if !searchResults.isEmpty {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(searchResults) { candidate in
                    Button { onAdd(candidate.card) } label: { resultRow(candidate.card) }
                        .buttonStyle(.plain)
                }
            }
        } else if didSearch && manualName.trimmingCharacters(in: .whitespaces).count >= 2 {
            Text("No catalog match for “\(manualName)”.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private func resultRow(_ card: Card) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            CardArtwork(game: card.game, rarity: card.rarity, price: card.marketPrice, imageURL: card.imageURL, sport: card.sport)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).foregroundStyle(Theme.textPrimary)
                Text([card.setName, card.number].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.cream)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCard(cornerRadius: Theme.Radius.md)
    }

    @ViewBuilder private var untrackedFallback: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showUntracked.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showUntracked ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("Can't find it? Add as an untracked card")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            if showUntracked {
                Text("Untracked cards appear in your dex but get no price updates or set tracking.")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                labeled("Set (optional)") {
                    TextField("e.g. Base Set", text: $manualSet)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .glassCard(cornerRadius: Theme.Radius.md)
                }
                labeled("Price (USD, optional)") {
                    TextField("0.00", text: $manualPrice)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .glassCard(cornerRadius: Theme.Radius.md)
                }
                PrimaryButton(title: "Add untracked card", systemImage: "plus") {
                    onAdd(manualCard())
                }
                .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    /// Debounced catalog search. `.task(id:)` cancels the in-flight task when the
    /// query/filter changes, so the sleep both debounces typing and the
    /// `Task.isCancelled` checks drop stale results.
    private func runSearch() async {
        let q = manualName.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            searchResults = []
            didSearch = false
            isSearching = false
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        if Task.isCancelled { return }
        isSearching = true
        let found = (try? await env.identification.searchCatalog(query: q, gameHint: manualGame)) ?? []
        if Task.isCancelled { return }
        searchResults = found
        isSearching = false
        didSearch = true
    }

    /// Last-resort orphan card when nothing in the catalog matches. The
    /// `manual-` id prefix marks it untracked (no price/set grounding).
    private func manualCard() -> Card {
        let price = Double(manualPrice).map { Money(amount: Decimal($0)) }
        return Card(id: "manual-\(UUID().uuidString)", game: manualGame ?? .pokemon, name: manualName,
                    setName: manualSet, number: "", rarity: nil, imageURL: nil, marketPrice: price)
    }

    @ViewBuilder private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
            content()
        }
    }
}

/// Identity for the debounced catalog search `.task(id:)` — re-runs only when
/// the typed query or the selected game filter actually changes.
private struct SearchKey: Equatable {
    let query: String
    let game: CardGame?
}

#Preview {
    ScanView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment())
        .environment(SubscriptionStore())
}
