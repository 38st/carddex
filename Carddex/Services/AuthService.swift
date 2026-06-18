import Foundation

/// Auth seam — protocol so tests inject a fake instead of calling Supabase.
protocol AuthServiceProtocol: Sendable {
    /// Exchange an Apple identity token for a Supabase session via
    /// `auth/v1/token?grant_type=id_token` (Sign in with Apple provider).
    func signInWithApple(
        identityToken: Data,
        authorizationCode: Data?,
        fullName: PersonNameComponents?
    ) async throws -> AuthSession

    /// Refresh an expired access token via `auth/v1/token?grant_type=refresh_token`.
    func refresh(refreshToken: String) async throws -> AuthSession

    /// Permanently delete the signed-in user's account by calling the
    /// `account-delete` Edge Function (which uses the service-role key to
    /// remove the auth user — cascading to all user tables). Requires a valid
    /// access token; throws on any failure.
    func deleteAccount(accessToken: String) async throws
}

/// Calls Supabase Auth over REST (no supabase-swift dependency — keeps the app
/// SPM-free as the rest of the codebase). Uses the project's anon key as the
/// `apikey` header (required by GoTrue), and the Apple provider.
struct SupabaseAuthService: AuthServiceProtocol {
    let baseURL: URL          // https://<ref>.supabase.co
    let accountDeleteURL: URL // https://<ref>.functions.supabase.co/account-delete
    let apiKey: String        // anon key
    var session: URLSession = .shared

    init?(config: SupabaseConfig) {
        self.baseURL = config.baseURL
        self.accountDeleteURL = config.accountDeleteURL
        self.apiKey = config.anonKey
    }

    func signInWithApple(
        identityToken: Data,
        authorizationCode: Data?,
        fullName: PersonNameComponents?
    ) async throws -> AuthSession {
        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidIdentityToken
        }
        var body: [String: Any] = [
            "provider": "apple",
            "token": tokenString,
        ]
        if let name = fullName {
            let data = PersonNameComponentsFormatter().string(from: name)
            if !data.isEmpty { body["user_metadata"] = ["full_name": data] }
        }
        let url = baseURL.appendingPathComponent("auth/v1/token")
        let data = try await post(url, query: "grant_type=id_token", body: body)
        return try Self.decode(data)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        let url = baseURL.appendingPathComponent("auth/v1/token")
        let body: [String: Any] = ["refresh_token": refreshToken]
        let data = try await post(url, query: "grant_type=refresh_token", body: body)
        return try Self.decode(data)
    }

    func deleteAccount(accessToken: String) async throws {
        var req = URLRequest(url: accountDeleteURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // Surface a best-effort server message for the UI.
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["error"] as? String {
                throw AuthError.serverError(message)
            }
            throw AuthError.serverError("account deletion failed")
        }
    }

    private func post(_ url: URL, query: String, body: [String: Any]) async throws -> Data {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        comps.query = query
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.serverError("auth failed")
        }
        return data
    }

    /// Decodes GoTrue's token response → `AuthSession`.
    static func decode(_ data: Data) throws -> AuthSession {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let userID = user["id"] as? String
        else { throw AuthError.decoding }
        let expiresAt = (json["expires_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            ?? (json["expires_in"] as? Double).map { Date().addingTimeInterval($0) }
        return AuthSession(userID: userID, accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }
}

/// In-process fake auth service for previews/tests — returns a fixed session
/// without any network call.
struct FakeAuthService: AuthServiceProtocol {
    var session: AuthSession = AuthSession(
        userID: "fake-user",
        accessToken: "fake.jwt.access",
        refreshToken: "fake.refresh",
        expiresAt: Date().addingTimeInterval(3600)
    )

    func signInWithApple(
        identityToken: Data,
        authorizationCode: Data?,
        fullName: PersonNameComponents?
    ) async throws -> AuthSession { session }

    func refresh(refreshToken: String) async throws -> AuthSession { session }

    func deleteAccount(accessToken: String) async throws {
        // Simulates a successful server-side delete; the store clears its session.
    }
}

enum AuthError: Error, LocalizedError {
    case invalidIdentityToken
    case decoding
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidIdentityToken: "Sign in with Apple returned an invalid token."
        case .decoding: "Couldn't read the auth response."
        case .serverError(let msg): msg
        }
    }
}
