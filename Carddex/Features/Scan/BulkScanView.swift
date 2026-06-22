import SwiftUI
import PhotosUI
import UIKit

/// Bulk scan: pick a stack of card photos, identify them all, review the batch,
/// and add the keepers to the collection in one go (the reseller's fast intake).
struct BulkScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @Environment(CollectionStore.self) private var store
    @Environment(SubscriptionStore.self) private var subs

    @State private var picked: [PhotosPickerItem] = []
    @State private var results: [BulkResult] = []
    @State private var isProcessing = false

    struct BulkResult: Identifiable {
        let id = UUID()
        let card: Card
        var include: Bool = true
    }

    private var includedCount: Int { results.filter(\.include).count }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VaultBackground()
                content
                if !results.isEmpty {
                    PrimaryButton(title: "Add \(includedCount) to collection", systemImage: "plus") {
                        for result in results where result.include { store.add(result.card) }
                        dismiss()
                    }
                    .padding()
                    .disabled(includedCount == 0)
                }
            }
            .navigationTitle("Bulk scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $picked, maxSelectionCount: 12, matching: .images) {
                        Image(systemName: "photo.stack")
                    }
                }
            }
            .onChange(of: picked) { _, items in
                Task { await process(items) }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        if isProcessing {
            VStack(spacing: Theme.Spacing.md) {
                ProgressView().tint(Theme.cream)
                Text("Identifying \(picked.count) cards…").foregroundStyle(Theme.textSecondary)
            }
        } else if results.isEmpty {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 44)).foregroundStyle(Theme.cream)
                Text("Scan a whole stack").font(.headline).foregroundStyle(Theme.textPrimary)
                Text("Pick several card photos and The Case identifies them all at once.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                PhotosPicker(selection: $picked, maxSelectionCount: 12, matching: .images) {
                    Label("Choose photos", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                }
            }
            .padding(Theme.Spacing.xl)
        } else {
            List {
                ForEach($results) { $result in
                    HStack(spacing: Theme.Spacing.md) {
                        CardArtwork(game: result.card.game, rarity: result.card.rarity, price: result.card.marketPrice, imageURL: result.card.imageURL, sport: result.card.sport)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.card.name).foregroundStyle(Theme.textPrimary).lineLimit(1)
                            Text(result.card.setName).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        if let price = result.card.marketPrice {
                            Text(price.formatted).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.cream).monospacedDigit()
                        }
                        Toggle("", isOn: $result.include).labelsHidden().tint(Theme.cream)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 72) }
        }
    }

    private func process(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isProcessing = true
        var output: [BulkResult] = []
        for item in items {
            guard subs.canScan else { break }
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data),
                let cgImage = image.cgImage
            else { continue }
            let ocr = await CardTextRecognizer.recognize(cgImage)
            let jpeg = image.jpegData(compressionQuality: 0.8) ?? data
            let input = ScanInput(imageData: jpeg, ocrText: ocr, gameHint: nil)
            // Distinguish a thrown error (offline/quota/server) from a returned
            // `.unidentified`: only the latter consumed a backend scan.
            let outcome: IdentificationOutcome?
            do {
                outcome = try await env.identification.identify(input)
            } catch {
                outcome = nil
            }
            switch outcome {
            case .confident(let candidate):
                output.append(BulkResult(card: candidate.card))
                subs.recordScan()
            case .ambiguous(let candidates):
                if let first = candidates.first { output.append(BulkResult(card: first.card)) }
                subs.recordScan()
            case .unidentified:
                subs.recordScan()
            case nil:
                break
            }
        }
        results = output
        picked = []
        isProcessing = false
    }
}
