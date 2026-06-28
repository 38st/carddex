import SwiftUI
import UniformTypeIdentifiers

/// CSV import/export view. Export collection to CSV or import from
/// Collectr/TCGplayer/Card Atlas exports.
struct CSVImportExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CollectionStore.self) private var store

    @State private var showFilePicker = false
    @State private var showShareSheet = false
    @State private var importMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        exportSection
                        Divider().overlay(Theme.hairline)
                        importSection

                        if let importMessage {
                            Text(importMessage)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Import / Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText]) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showShareSheet) {
            let csv = CSVService.export(store.items)
            ShareSheet(items: [csv])
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "tablecells.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.cream)
            Text("Import or export your collection")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Export to CSV for backup or spreadsheets. Import from Collectr, TCGplayer, or Card Atlas exports.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Export")
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundStyle(Theme.cream)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export collection to CSV")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(store.items.count) items · \(store.totalValue.formatted) total value")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .glassPanel(cornerRadius: Theme.Radius.card)

            PrimaryButton(title: "Export CSV", systemImage: "square.and.arrow.up") {
                showShareSheet = true
            }
            .disabled(store.items.isEmpty)
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Import")
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                    .foregroundStyle(Theme.cream)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from CSV file")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Supports Collectr, TCGplayer, Card Atlas, and The Case formats")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(Theme.Spacing.md)
            .glassPanel(cornerRadius: Theme.Radius.card)

            PrimaryButton(title: "Choose CSV file", systemImage: "doc.badge.plus") {
                showFilePicker = true
            }

            if isImporting {
                HStack { ProgressView(); Text("Importing…") }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            isImporting = true
            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }

                guard let data = try? Data(contentsOf: url),
                      let csv = String(data: data, encoding: .utf8) else {
                    importMessage = "Couldn't read the file."
                    isImporting = false
                    return
                }

                let rows = CSVService.parse(csv)
                let items = CSVService.toCollectionItems(rows)

                await MainActor.run {
                    for item in items {
                        store.add(item.card, purchasePrice: item.purchasePrice, quantity: item.quantity)
                    }
                    importMessage = "Imported \(items.count) cards."
                    isImporting = false
                }
            }

        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}
