import Foundation

/// Reads live market data from the Supabase `market-data` Edge Function.
/// Returns raw DTOs; `MarketStore` maps them onto the app's domain models.
struct MarketService {
    let baseURL: URL          // …/functions/v1/market-data
    let apiKey: String
    var session: URLSession = .shared

    /// Local dev default: the colima-hosted stack + the standard local anon key
    /// (a fixed demo JWT shared by every local Supabase — not a secret).
    static let localDev = MarketService(
        baseURL: URL(string: "http://127.0.0.1:54321/functions/v1/market-data")!,
        apiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    )

    private func get(_ query: String) async throws -> Data {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.query = query
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 8
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    func fetchIndex(category: String? = nil) async throws -> [IndexPointDTO] {
        let data = try await get("index=\(category ?? "")")
        return try JSONDecoder().decode(IndexResponseDTO.self, from: data).points
    }

    func fetchCard(id: String) async throws -> CardBundleDTO {
        let data = try await get("cardId=\(id)")
        return try JSONDecoder().decode(CardBundleDTO.self, from: data)
    }
}

struct IndexResponseDTO: Decodable {
    let category: String?
    let points: [IndexPointDTO]
}

struct IndexPointDTO: Decodable {
    let asOf: String
    let value: Double
}

struct CardBundleDTO: Decodable {
    let cardId: String
    let gradedPrices: [Graded]
    let population: Int?
    let change30d: Double
    let recentSales: [SaleDTO]

    struct Graded: Decodable { let grade: String; let price: Double }
    struct SaleDTO: Decodable {
        let grade: String
        let price: Double
        let currency: String
        let platform: String
        let soldAt: String
    }
}
