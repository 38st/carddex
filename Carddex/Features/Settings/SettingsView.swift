import SwiftUI

/// Account, marketplace, and app info. Sign in with Apple + eBay connect are
/// wired up in later phases.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(SubscriptionStore.self) private var subs
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showPaywall = true } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading) {
                                Text(subs.isPro ? "Carddex Pro" : "Upgrade to Carddex Pro")
                                    .font(.headline)
                                Text(subs.isPro ? "Thanks for supporting Carddex" : "Unlimited scans, analytics, and selling")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if !subs.isPro {
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }

                Section("Account") {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textSecondary)
                        VStack(alignment: .leading) {
                            Text("Not signed in")
                                .font(.headline)
                            Text("Sign in to sync your collection across devices")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Button("Sign in with Apple") {}
                }

                Section("Marketplace") {
                    Label("Connect eBay", systemImage: "tag")
                    Text("Auto-list cards for sale — coming in Phase 3.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Backend", value: "Supabase")
                    LabeledContent("Identification", value: env.isLiveBackend ? "Live" : "Sample")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment(identification: FakeIdentificationService()))
        .environment(SubscriptionStore())
        .preferredColorScheme(.dark)
}
