import SwiftUI

/// Composition root for services. Views depend on this rather than concrete
/// types, so the cloud provider is swappable and previews/tests use fakes.
///
/// Picks the live identification service automatically when `Secrets.plist` is
/// present (see `AppConfig`); otherwise falls back to the fake.
@MainActor
@Observable
final class AppEnvironment {
    let identification: any IdentificationService
    let auth: AuthSessionStore
    let sync: any SyncServiceProtocol
    let storeKit: any StoreKitServiceProtocol
    let isLiveBackend: Bool

    init() {
        if let config = AppConfig.supabase {
            let auth = AuthSessionStore(service: SupabaseAuthService(config: config) ?? NoOpAuthService())
            self.auth = auth
            self.identification = LiveIdentificationService(
                endpoint: config.identifyURL,
                tokenProvider: { [auth] in
                    await auth.refreshIfNeeded()
                    return await MainActor.run { auth.session?.accessToken }
                }
            )
            self.sync = LiveSyncService(config: config, tokenProvider: auth) ?? NoOpSyncService()
            self.storeKit = StoreKitService()
            self.isLiveBackend = true
        } else {
            let auth = AuthSessionStore(service: FakeAuthService())
            self.auth = auth
            self.identification = FakeIdentificationService()
            self.sync = NoOpSyncService()
            self.storeKit = NoOpStoreKitService()
            self.isLiveBackend = false
        }
    }

    /// For previews and tests.
    init(identification: any IdentificationService, auth: AuthSessionStore? = nil,
         sync: (any SyncServiceProtocol)? = nil, storeKit: (any StoreKitServiceProtocol)? = nil) {
        self.identification = identification
        self.auth = auth ?? AuthSessionStore(service: FakeAuthService())
        self.sync = sync ?? NoOpSyncService()
        self.storeKit = storeKit ?? NoOpStoreKitService()
        self.isLiveBackend = false
    }
}

/// No-op auth service used when `SupabaseConfig` exists but the auth endpoint
/// couldn't be built (defensive — `SupabaseAuthService.init?` already guards).
struct NoOpAuthService: AuthServiceProtocol {
    func signInWithApple(identityToken: Data, authorizationCode: Data?, fullName: PersonNameComponents?) async throws -> AuthSession {
        throw AuthError.serverError("auth not configured")
    }
    func refresh(refreshToken: String) async throws -> AuthSession {
        throw AuthError.serverError("auth not configured")
    }
    func deleteAccount(accessToken: String) async throws {
        throw AuthError.serverError("auth not configured")
    }
}
