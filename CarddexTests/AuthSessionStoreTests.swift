import Testing
import Foundation
@testable import Carddex

@MainActor
@Suite struct AuthSessionStoreTests {
    @Test func freshStoreHasNoSession() {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: NoOpAuthService())
        #expect(!store.isSignedIn)
        #expect(store.session == nil)
    }

    @Test func signInWithFakeServiceStoresSession() async {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: FakeAuthService())
        let token = "fake-apple-jwt".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)
        #expect(store.isSignedIn)
        #expect(store.session?.userID == "fake-user")
        #expect(store.session?.accessToken == "fake.jwt.access")
        #expect(store.session?.refreshToken == "fake.refresh")
        #expect(store.lastError == nil)
        KeychainStore.clearAll()
    }

    @Test func signInFailureRecordsErrorAndStaysSignedOut() async {
        KeychainStore.clearAll() // ensure no leaked session from a prior test
        struct ThrowingAuth: AuthServiceProtocol {
            func signInWithApple(identityToken: Data, authorizationCode: Data?, fullName: PersonNameComponents?) async throws -> AuthSession {
                throw AuthError.serverError("boom")
            }
            func refresh(refreshToken: String) async throws -> AuthSession { throw AuthError.serverError("boom") }
            func deleteAccount(accessToken: String) async throws { throw AuthError.serverError("boom") }
        }
        let store = AuthSessionStore(service: ThrowingAuth())
        let token = "x".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)
        #expect(!store.isSignedIn)
        #expect(store.lastError == "boom")
        KeychainStore.clearAll()
    }

    @Test func signOutClearsSession() async {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: FakeAuthService())
        let token = "x".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)
        #expect(store.isSignedIn)
        store.signOut()
        #expect(!store.isSignedIn)
        #expect(store.session == nil)
    }

    @Test func refreshIfNeededIsNoOpWhenNotExpired() async {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: FakeAuthService())
        let token = "x".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)
        let before = store.session
        await store.refreshIfNeeded()
        // FakeAuthService returns the same session, so it shouldn't change.
        #expect(store.session == before)
    }

    @Test func refreshForcedOnFakeServiceReturnsSession() async {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: FakeAuthService())
        let token = "x".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)
        await store.refreshIfNeeded(force: true)
        #expect(store.isSignedIn)
        #expect(store.session?.accessToken == "fake.jwt.access")
        KeychainStore.clearAll()
    }

    @Test func authSessionIsExpiredChecksExpiry() {
        let past = AuthSession(userID: "u", accessToken: "a", refreshToken: "r",
                               expiresAt: Date().addingTimeInterval(-100))
        #expect(past.isExpired)
        let future = AuthSession(userID: "u", accessToken: "a", refreshToken: "r",
                                 expiresAt: Date().addingTimeInterval(3600))
        #expect(!future.isExpired)
        let unknown = AuthSession(userID: "u", accessToken: "a", refreshToken: "r", expiresAt: nil)
        #expect(!unknown.isExpired)
    }

    @Test func deleteAccountCallsServiceAndClearsSession() async throws {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: FakeAuthService())
        let token = "x".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)
        #expect(store.isSignedIn)

        try await store.deleteAccount()

        #expect(!store.isSignedIn)
        #expect(store.session == nil)
        KeychainStore.clearAll()
    }

    @Test func deleteAccountRecordsErrorAndStaysSignedInOnFailure() async {
        KeychainStore.clearAll()
        struct ThrowingAuth: AuthServiceProtocol {
            func signInWithApple(identityToken: Data, authorizationCode: Data?, fullName: PersonNameComponents?) async throws -> AuthSession {
                AuthSession(userID: "u", accessToken: "a", refreshToken: "r", expiresAt: nil)
            }
            func refresh(refreshToken: String) async throws -> AuthSession {
                AuthSession(userID: "u", accessToken: "a", refreshToken: "r", expiresAt: nil)
            }
            func deleteAccount(accessToken: String) async throws {
                throw AuthError.serverError("backend refused")
            }
        }
        let store = AuthSessionStore(service: ThrowingAuth())
        let token = "x".data(using: .utf8)!
        await store.signInWithApple(identityToken: token, authorizationCode: nil, fullName: nil)

        await #expect(throws: AuthError.self) {
            try await store.deleteAccount()
        }
        // A failed server-side delete must NOT clear the local session — the
        // account still exists, so the user can retry.
        #expect(store.isSignedIn)
        #expect(store.lastError == "backend refused")
        KeychainStore.clearAll()
    }

    @Test func deleteAccountThrowsWhenSignedOut() async {
        KeychainStore.clearAll()
        let store = AuthSessionStore(service: FakeAuthService())
        await #expect(throws: AuthError.self) {
            try await store.deleteAccount()
        }
        #expect(!store.isSignedIn)
    }
}
