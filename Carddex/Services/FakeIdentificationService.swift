import Foundation

/// Deterministic-ish identification for the simulator, previews, and tests.
/// Used until the Supabase `identify` Edge Function is deployed.
struct FakeIdentificationService: IdentificationService {
    func identify(_ input: ScanInput) async throws -> IdentificationOutcome {
        try? await Task.sleep(for: .milliseconds(650))
        let pool = input.gameHint.map { hint in
            SampleData.cards.filter { $0.game == hint }
        } ?? SampleData.cards
        let card = pool.randomElement() ?? SampleData.cards.first ?? Card(id: "unknown", game: .pokemon, name: "Unknown", setName: "", number: "")
        return .confident(IdentificationCandidate(card: card, confidence: 0.95))
    }

    func searchCatalog(query: String, gameHint: CardGame?) async throws -> [IdentificationCandidate] {
        try? await Task.sleep(for: .milliseconds(200))
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return SampleData.cards
            .filter { gameHint == nil || $0.game == gameHint }
            .filter { $0.name.lowercased().contains(needle) || $0.number.lowercased().contains(needle) }
            .prefix(8)
            .map { IdentificationCandidate(card: $0, confidence: 0.9) }
    }
}
