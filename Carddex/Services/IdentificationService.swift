import Foundation

/// Input to identification: the captured card image plus on-device OCR hints.
struct ScanInput: Sendable {
    /// JPEG of the (ideally cropped) card. May be empty when only OCR is used.
    var imageData: Data
    /// Text lines read on-device by Vision (cheap hint that saves cloud calls).
    var ocrText: [String]
    /// Optional game filter from the UI to narrow the search.
    var gameHint: CardGame?
}

/// A ranked identification result, already grounded against the catalog.
struct IdentificationCandidate: Identifiable, Sendable, Hashable {
    let card: Card
    let confidence: Double
    var id: String { card.id }
}

/// What identification produced — drives the confirm / picker / manual UI.
enum IdentificationOutcome: Sendable {
    case confident(IdentificationCandidate)
    case ambiguous([IdentificationCandidate])
    case unidentified(ocrText: [String])
}

enum IdentificationError: Error, Sendable, Equatable {
    case offline
    case quotaExceeded
    case server(String)
    case decoding
}

/// Swappable so the cloud provider can change and previews/tests use a fake.
protocol IdentificationService: Sendable {
    func identify(_ input: ScanInput) async throws -> IdentificationOutcome

    /// Free-text catalog search, used by the manual fallback when a scan can't be
    /// identified. Returns real, catalog-grounded cards (with stable ids, set,
    /// number, rarity) ranked by match quality — never untracked orphans.
    /// Unlike `identify`, this makes no vision call and costs nothing, so it's
    /// safe to call on every keystroke (debounced by the caller).
    func searchCatalog(query: String, gameHint: CardGame?) async throws -> [IdentificationCandidate]
}
