import SwiftUI

/// Account, marketplace, and app info. Sign in with Apple + eBay connect are
/// wired up in later phases.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text("Not signed in")
                                .font(.headline)
                            Text("Sign in to sync your collection across devices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Sign in with Apple") {}
                        .disabled(true)
                }

                Section("Marketplace") {
                    Label("Connect eBay", systemImage: "tag")
                    Text("Auto-list cards for sale — coming in Phase 3.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Backend", value: "Supabase")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
