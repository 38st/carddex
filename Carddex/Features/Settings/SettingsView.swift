import SwiftUI
import AuthenticationServices

/// Account, marketplace, and app info. Sign in with Apple + eBay connect are
/// wired up in later phases.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(SubscriptionStore.self) private var subs
    @Environment(AuthSessionStore.self) private var auth
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

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
                                .foregroundStyle(Theme.accent)
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
                    Button("Delete account", role: .destructive) { showDeleteConfirm = true }
                } footer: {
                    Text("Permanently deletes your collection and account.")
                }
            }
                .scrollContentBackground(.hidden)
                .tabBarSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    // Phase 1: call the `account-delete` Edge Function.
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your collection and account. This can't be undone.")
            }
        }
    }

    private func signedInRow(userID: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
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
        .environment(AppEnvironment(identification: FakeIdentificationService()))
        .environment(SubscriptionStore())
        .environment(AuthSessionStore(service: FakeAuthService()))
        .preferredColorScheme(.dark)
}
