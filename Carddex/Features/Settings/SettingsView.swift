import SwiftUI
import AuthenticationServices
import WidgetKit

/// Account, marketplace, and app info. Sign in with Apple + eBay connect are
/// wired up in later phases.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(CollectionStore.self) private var collection
    @Environment(SubscriptionStore.self) private var subs
    @Environment(WatchlistStore.self) private var watchlist
    @Environment(WishlistStore.self) private var wishlist
    @Environment(AuthSessionStore.self) private var auth
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Settings")
                    .padding(.bottom, Theme.Spacing.sm)
                List {
                Section {
                    Button { showPaywall = true } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.cream)
                            VStack(alignment: .leading) {
                                Text(subs.isPro ? "Case Pro" : "Upgrade to Case Pro")
                                    .font(.headline)
                                Text(subs.isPro ? "Thanks for supporting The Case" : "Unlimited scans, analytics, and selling")
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
                    if let session = auth.session {
                        signedInRow(userID: session.userID)
                        Button("Sign out", role: .destructive) { auth.signOut() }
                    } else {
                        signedOutRow
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        if auth.isSigningIn {
                            HStack { ProgressView(); Text("Signing in…") }
                                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                        if let error = auth.lastError {
                            Text(error)
                                .font(.caption).foregroundStyle(Theme.loss)
                        }
                    }
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

                Section {
                    Button("Delete account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } footer: {
                    Text("Permanently deletes your collection and account.")
                }
            }
                .scrollContentBackground(.hidden)
                .listRowBackground(Theme.surface)
                .tabBarSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your collection and account. This can't be undone.")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: Theme.Spacing.sm) {
                            ProgressView()
                            Text("Deleting account…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .padding(Theme.Spacing.lg)
                        .glassCard(cornerRadius: Theme.Radius.lg)
                    }
                }
            }
            .alert("Couldn't delete account", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    /// Delete the account server-side, then wipe all local stores + widgets.
    /// Any failure surfaces as an alert and leaves local state intact (the
    /// server-side delete is the source of truth; local wipe only on success).
    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await auth.deleteAccount()
            // Server-side deletion succeeded (cascaded all user tables) — wipe
            // the local mirrors so a re-launch boots into a fresh state.
            collection.wipeLocal()
            watchlist.wipeLocal()
            wishlist.wipeLocal()
            subs.wipeLocal()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func signedInRow(userID: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.cream)
            VStack(alignment: .leading) {
                Text("Signed in")
                    .font(.headline)
                Text("ID · \(userID.prefix(8))…")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    private var signedOutRow: some View {
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
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken else {
                auth.lastError = "No identity token from Apple."
                return
            }
            Task { await auth.signInWithApple(
                identityToken: identityToken,
                authorizationCode: credential.authorizationCode,
                fullName: credential.fullName
            ) }
        case .failure(let error):
            auth.lastError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environment(CollectionStore(items: SampleData.collection))
        .environment(AppEnvironment(identification: FakeIdentificationService()))
        .environment(SubscriptionStore())
        .environment(AuthSessionStore(service: FakeAuthService()))
        .environment(WatchlistStore())
        .environment(WishlistStore())
        .preferredColorScheme(.dark)
}
