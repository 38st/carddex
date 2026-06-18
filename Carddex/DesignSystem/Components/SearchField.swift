import SwiftUI

/// Dark rounded search pill — replaces the system `.searchable` bar on the main
/// screens so search matches the reference's pill language.
struct SearchField: View {
    @Binding var text: String
    var prompt: String = "Search"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextField("", text: $text, prompt: Text(prompt).foregroundColor(Theme.textTertiary))
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.cream)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Theme.surface2, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}

#Preview {
    VStack(spacing: 16) {
        SearchField(text: .constant(""), prompt: "Search NFT or artist name…")
        SearchField(text: .constant("Charizard"), prompt: "Search cards")
    }
    .padding()
    .background(VaultBackground())
}
