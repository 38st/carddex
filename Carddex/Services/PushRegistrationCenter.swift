import Foundation
import Observation

/// Bridges the UIKit APNs registration callbacks (in `AppDelegate`) to the
/// SwiftUI app: stores the device token, then `CarddexApp` uploads it to the
/// `register-device` Edge Function once a signed-in JWT is available. Uploading
/// is idempotent (server upserts on `(user_id, token)`).
@MainActor
@Observable
final class PushRegistrationCenter {
    static let shared = PushRegistrationCenter()

    /// Hex APNs device token; set by `AppDelegate` when registration succeeds.
    /// Observed by `CarddexApp` to trigger the upload.
    var deviceTokenHex: String?

    /// Tokens already uploaded for the current session, so re-uploading is a no-op.
    private var uploaded: Set<String> = []

    private init() {}

    /// POST the token to `register-device` with the user's JWT. No-op if the
    /// token is missing/already uploaded or there's no endpoint/JWT.
    func upload(endpoint: URL?, jwt: String?) async {
        guard let token = deviceTokenHex, let endpoint, let jwt,
              !uploaded.contains(token) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token, "platform": "ios"])
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
            uploaded.insert(token)
        }
    }

    /// Clear upload memory on sign-out so the next account re-registers the token.
    func reset() { uploaded.removeAll() }
}
