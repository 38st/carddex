import Foundation
import Observation

/// A signed-in session: the Supabase JWT (access token) + refresh token + user id.
/// `accessToken` is what every authenticated request (identify, sync, account-delete)
/// carries as `Authorization: Bearer …`. Sendable so it can cross actor boundaries.
struct AuthSession: Sendable, Equatable {
    let userID: String
    let accessToken: String
    let refreshToken: String
    /// Approximate expiry (decoded from the JWT `exp`). When in the past, the
    /// auth layer attempts a refresh before the next authenticated call.
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt.addingTimeInterval(-60) // 60s skew
    }
}

/// The auth state machine, observable so views react to sign-in / sign-out.
/// Owns the session lifecycle: restore from Keychain on init, sign in with an
/// Apple identity token (delegated to an `AuthService`), refresh on demand,
/// sign out (clears Keychain + session). Sync starts/stops on session changes.
/// `@MainActor` so it can be safely captured in `@Sendable` token closures.
@MainActor
@Observable
final class AuthSessionStore {
    private(set) var session: AuthSession?
    private(set) var isSigningIn = false
    /// Last user-facing auth error (sign-in failure, missing token, etc.).
    /// Read-write so the UI can clear or set it. Cleared on a successful sign-in.
    var lastError: String?

    private let service: any AuthServiceProtocol

    init(service: any AuthServiceProtocol = NoOpAuthService()) {
        self.service = service
        self.session = Self.restore()
    }

    var isSignedIn: Bool { session != nil }

    /// Exchange an Apple identity token (from `ASAuthorizationAppleIDCredential`)
    /// for a Supabase session. On success, persists tokens to the Keychain and
    /// publishes the session. On failure, records the error and stays signed-out.
    func signInWithApple(identityToken: Data, authorizationCode: Data?, fullName: PersonNameComponents?) async {
        isSigningIn = true
        defer { isSigningIn = false }
        lastError = nil
        do {
            let session = try await service.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName
            )
            Self.persist(session)
            self.session = session
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Refresh the access token if it's expired (or force). No-op when signed out.
    func refreshIfNeeded(force: Bool = false) async {
        guard let current = session else { return }
        guard force || current.isExpired else { return }
        do {
            let refreshed = try await service.refresh(refreshToken: current.refreshToken)
            Self.persist(refreshed)
            self.session = refreshed
        } catch {
            // A failed refresh means the session is no longer valid — sign out.
            signOut()
        }
    }

    func signOut() {
        KeychainStore.clearAll()
        session = nil
    }

    // MARK: - Keychain persistence

    private static let keyAccount = "accessToken"
    private static let keyRefresh = "refreshToken"
    private static let keyUser = "userId"
    private static let keyExpiry = "expiry"

    private static func persist(_ session: AuthSession) {
        KeychainStore.setString(session.accessToken, for: keyAccount)
        KeychainStore.setString(session.refreshToken, for: keyRefresh)
        KeychainStore.setString(session.userID, for: keyUser)
        if let expiresAt = session.expiresAt {
            KeychainStore.setString(String(expiresAt.timeIntervalSince1970), for: keyExpiry)
        } else {
            KeychainStore.setString(nil, for: keyExpiry)
        }
    }

    private static func restore() -> AuthSession? {
        guard
            let access = KeychainStore.getString(for: keyAccount),
            let refresh = KeychainStore.getString(for: keyRefresh),
            let user = KeychainStore.getString(for: keyUser)
        else { return nil }
        let expiry = KeychainStore.getString(for: keyExpiry)
            .flatMap { Double($0) }
            .map { Date(timeIntervalSince1970: $0) }
        return AuthSession(userID: user, accessToken: access, refreshToken: refresh, expiresAt: expiry)
    }
}
