import Foundation

/// Talks to the Supabase `identify` Edge Function. Holds no secrets — the
/// function does. Selected automatically by `AppEnvironment` when `Secrets.plist`
/// is present; otherwise the fake service is used. Pulls the current JWT via an
/// async closure so authenticated calls use a fresh, refreshed token without
/// capturing a non-Sendable store.
struct LiveIdentificationService: IdentificationService {
    let endpoint: URL
    let tokenProvider: @Sendable () async -> String?
    var session: URLSession = .shared

    init(endpoint: URL, tokenProvider: @escaping @Sendable () async -> String?, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.tokenProvider = tokenProvider
        self.session = session
    }

    func identify(_ input: ScanInput) async throws -> IdentificationOutcome {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body = IdentifyRequest(
            ocr: .init(lines: input.ocrText),
            gameHint: input.gameHint?.rawValue,
            imageBase64: input.imageData.isEmpty ? nil : input.imageData.base64EncodedString()
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw IdentificationError.offline
        }
        guard let http = response as? HTTPURLResponse else {
            throw IdentificationError.server("no response")
        }
        switch http.statusCode {
        case 200: break
        case 402: throw IdentificationError.quotaExceeded
        default: throw IdentificationError.server("status \(http.statusCode)")
        }
        guard let decoded = try? JSONDecoder().decode(IdentifyResponse.self, from: data) else {
            throw IdentificationError.decoding
        }
        return decoded.outcome
    }
}

private struct IdentifyRequest: Encodable {
    struct OCR: Encodable { let lines: [String] }
    let ocr: OCR
    let gameHint: String?
    let imageBase64: String?
}

/// Response from the `identify` function (see docs/backend-plan.md §3.1).
struct IdentifyResponse: Decodable {
    let candidates: [Candidate]
    let lowConfidence: Bool

    struct Candidate: Decodable {
        let card: Card
        let confidence: Double
    }

    var outcome: IdentificationOutcome {
        let mapped = candidates.map {
            IdentificationCandidate(card: $0.card, confidence: $0.confidence)
        }
        guard let top = mapped.first else {
            return .unidentified(ocrText: [])
        }
        if !lowConfidence, top.confidence >= 0.85 {
            return .confident(top)
        }
        return .ambiguous(mapped)
    }
}
