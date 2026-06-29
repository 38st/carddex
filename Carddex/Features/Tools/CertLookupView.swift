import SwiftUI

/// Graded card certificate lookup. Enter a PSA/CGC/BGS cert number to
/// verify the grade and deep-link to the grading company's verification page.
struct CertLookupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedCompany: CertLookupService.GradingCompany = .psa
    @State private var certNumber = ""
    @State private var showError = false

    private var isValid: Bool {
        CertLookupService.isValidFormat(certNumber, company: selectedCompany)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VaultBackground()
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        header

                        field("Grading company") {
                            Picker("Company", selection: $selectedCompany) {
                                ForEach(CertLookupService.GradingCompany.allCases) { company in
                                    Text(company.rawValue).tag(company)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(Theme.cream)
                        }

                        field("Certificate number") {
                            HStack {
                                Image(systemName: "number")
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("e.g. 87654321", text: $certNumber)
                                    .keyboardType(.numberPad)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if !certNumber.isEmpty {
                                    Button { certNumber = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .glassPanel(cornerRadius: Theme.Radius.card)
                        }

                        if !certNumber.isEmpty && !isValid {
                            Text("That doesn't look like a valid \(selectedCompany.rawValue) cert number.")
                                .font(.caption)
                                .foregroundStyle(Theme.loss)
                        }

                        PrimaryButton(title: "Verify on \(selectedCompany.rawValue)", systemImage: "arrow.up.right.square") {
                            if let url = CertLookupService.lookupURL(company: selectedCompany, certNumber: certNumber) {
                                openURL(url)
                            }
                        }
                        .disabled(!isValid)

                        infoCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Cert Lookup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(Theme.appColorScheme)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.cream)
            Text("Verify a graded card")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Enter the certificate number from the slab to verify the grade on the grading company's website.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("How to find the cert number", systemImage: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.cream)
            Text("The certificate number is printed on the grading label inside the slab. It's a 7-12 digit number that uniquely identifies your card in the grader's database.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .glassPanel(cornerRadius: Theme.Radius.card)
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
