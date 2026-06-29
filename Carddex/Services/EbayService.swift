import Foundation
import Observation

/// One-tap eBay listing. The heavy lifting (OAuth, inventory item → offer →
/// publish) lives in the `ebay-oauth` / `ebay-list` Edge Functions; this client
/// fetches the consent URL to connect an account and POSTs a list request.
/// The app never sees eBay tokens.

struct EbayListRequest: Sendable {
    let collectionItemID: UUID
    let price: Money
    let condition: CardCondition
    let quantity: Int
    let title: String
}

struct EbayListing: Sendable, Decodable {
    let listingID: String
    let viewURL: URL?
    let status: String

    enum CodingKeys: String, CodingKey {
        case listingID = "listingId"
        case viewURL = "viewUrl"
        case status
    }
}

enum EbayError: Error, Equatable, Sendable {
    case notConnected
    case offline
    case server(String)
    case decoding
}

protocol EbayServiceProtocol: Sendable {
    /// eBay consent URL to open in Safari to connect the seller account.
    func connectConsentURL() async throws -> URL
    /// Publish a collection item as a live eBay listing.
    func list(_ request: EbayListRequest) async throws -> EbayListing
}

/// Talks to the Supabase eBay Edge Functions with the user's JWT.
struct LiveEbayService: EbayServiceProtocol {
    let oauthURL: URL
    let listURL: URL
    let tokenProvider: @Sendable () async -> String?
    var session: URLSession = .shared

    func connectConsentURL() async throws -> URL {
        var comps = URLComponents(url: oauthURL, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "action", value: "start")]
        guard let url = comps?.url else { throw EbayError.server("bad url") }
        var req = URLRequest(url: url)
        await authorize(&req)

        let (data, resp) = try await dataOrOffline(req)
        try ensureOK(resp, data: data)
        struct StartResponse: Decodable { let consentUrl: URL }
        guard let decoded = try? JSONDecoder().decode(StartResponse.self, from: data) else {
            throw EbayError.decoding
        }
        return decoded.consentUrl
    }

    func list(_ request: EbayListRequest) async throws -> EbayListing {
        var req = URLRequest(url: listURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await authorize(&req)
        let body: [String: Any] = [
            "collectionItemId": request.collectionItemID.uuidString.lowercased(),
            "price": ["amount": "\(request.price.amount)", "currencyCode": request.price.currencyCode],
            "condition": request.condition.rawValue,
            "quantity": request.quantity,
            "title": request.title,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await dataOrOffline(req)
        try ensureOK(resp, data: data)
        guard let listing = try? JSONDecoder().decode(EbayListing.self, from: data) else {
            throw EbayError.decoding
        }
        return listing
    }

    private func authorize(_ req: inout URLRequest) async {
        if let token = await tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func dataOrOffline(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: req) }
        catch { throw EbayError.offline }
    }

    /// Maps the Edge Function's status codes onto typed errors. 409 =
    /// EBAY_NOT_CONNECTED (the user must connect their account first).
    private func ensureOK(_ resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { throw EbayError.server("no response") }
        switch http.statusCode {
        case 200: return
        case 409: throw EbayError.notConnected
        default:
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }
            throw EbayError.server(msg ?? "status \(http.statusCode)")
        }
    }
}

/// Previews/tests: pretends to publish without a network call.
struct FakeEbayService: EbayServiceProtocol {
    var connected = true
    func connectConsentURL() async throws -> URL { URL(string: "https://auth.ebay.com/oauth2/authorize")! }
    func list(_ request: EbayListRequest) async throws -> EbayListing {
        if !connected { throw EbayError.notConnected }
        return EbayListing(listingID: "v1|fake|0", viewURL: URL(string: "https://www.ebay.com/itm/fake"), status: "active")
    }
}

/// Tracks whether the user's eBay account is connected. Set true when the OAuth
/// callback deep-links `carddex://ebay/connected`, false on a `notConnected`
/// list error. Persisted so the Sell sheet knows the state across launches.
@MainActor
@Observable
final class EbayConnection {
    private let key = "ebay.connected"
    var isConnected: Bool {
        didSet { UserDefaults.standard.set(isConnected, forKey: key) }
    }
    /// Last error surfaced from an OAuth callback, for the UI to show.
    var lastError: String?

    init() {
        isConnected = UserDefaults.standard.bool(forKey: key)
    }

    /// Handle a `carddex://ebay/...` deep link from the OAuth callback
    /// (`/connected` on success, `/error?msg=...` on failure).
    /// - Returns: true if the URL was an eBay callback we consumed.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "carddex", url.host == "ebay" else { return false }
        if url.path == "/error" {
            lastError = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "msg" })?.value ?? "eBay connection failed"
        } else {
            isConnected = true
            lastError = nil
        }
        return true
    }
}
