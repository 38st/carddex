import Testing
import Foundation
@testable import Carddex

@Suite struct IdentificationServiceTests {
    @Test func fakeReturnsConfidentCandidateForGameHint() async throws {
        let service = FakeIdentificationService()
        let outcome = try await service.identify(ScanInput(imageData: Data(), ocrText: [], gameHint: .pokemon))
        guard case .confident(let candidate) = outcome else {
            Issue.record("expected .confident, got \(outcome)")
            return
        }
        #expect(candidate.confidence == 0.95)
        #expect(candidate.card.game == .pokemon)
    }

    @Test func fakeRespectsGameHintFilter() async throws {
        let service = FakeIdentificationService()
        let outcome = try await service.identify(ScanInput(imageData: Data(), ocrText: [], gameHint: .yugioh))
        guard case .confident(let candidate) = outcome else {
            Issue.record("expected .confident, got \(outcome)")
            return
        }
        #expect(candidate.card.game == .yugioh)
    }

    @Test func throwingServicePropagatesOfflineError() async {
        let service = ThrowingIdentificationService(.offline)
        await #expect(throws: IdentificationError.offline) {
            try await service.identify(ScanInput(imageData: Data(), ocrText: [], gameHint: nil))
        }
    }

    @Test func searchReturnsCatalogGroundedCards() async throws {
        let service = FakeIdentificationService()
        let target = SampleData.cards[0]
        let needle = String(target.name.prefix(4))
        let results = try await service.searchCatalog(query: needle, gameHint: nil)
        #expect(!results.isEmpty)
        // Results are real catalog cards, not untracked `manual-` orphans.
        #expect(results.allSatisfy { !$0.card.id.hasPrefix("manual-") })
        #expect(results.contains { $0.card.name.lowercased().contains(needle.lowercased()) })
    }

    @Test func searchRespectsGameHintFilter() async throws {
        let service = FakeIdentificationService()
        guard let yugioh = SampleData.cards.first(where: { $0.game == .yugioh }) else { return }
        let needle = String(yugioh.name.prefix(3))
        let results = try await service.searchCatalog(query: needle, gameHint: .yugioh)
        #expect(results.allSatisfy { $0.card.game == .yugioh })
    }

    @Test func searchIgnoresBlankQuery() async throws {
        let service = FakeIdentificationService()
        let results = try await service.searchCatalog(query: "   ", gameHint: nil)
        #expect(results.isEmpty)
    }
}

/// Rollup math behind the bulk-scan "your box is worth $X" reveal.
@Suite struct ShoeboxSummaryTests {
    private func card(_ id: String, price: Decimal? = nil, game: CardGame = .pokemon) -> Card {
        Card(id: id, game: game, name: id, setName: "Set", number: "1",
             rarity: nil, imageURL: nil, marketPrice: price.map { Money(amount: $0) })
    }

    @Test func totalSumsMarketPriceTreatingNilAsZero() {
        let s = ShoeboxSummary(cards: [card("a", price: 100), card("b", price: 50), card("c", price: nil)])
        #expect(s.total.amount == 150)
        #expect(s.count == 3)
    }

    @Test func topCardsAreHighestValueFirstAndLimited() {
        let s = ShoeboxSummary(cards: [
            card("a", price: 10), card("b", price: 300), card("c", price: 50), card("d", price: 200),
        ])
        #expect(s.topCards(2).map(\.id) == ["b", "d"])
    }

    @Test func gamesAreDistinctInScanOrder() {
        let s = ShoeboxSummary(cards: [
            card("1", game: .pokemon), card("2", game: .magic), card("3", game: .pokemon),
        ])
        #expect(s.games(4) == [.pokemon, .magic])
    }

    @Test func emptyBatchIsZero() {
        let s = ShoeboxSummary(cards: [])
        #expect(s.total.amount == 0)
        #expect(s.topCards().isEmpty)
    }
}

/// A stub service that always throws a given error — used to verify callers
/// (e.g. the scan flow) handle identify failures without consuming quota.
private struct ThrowingIdentificationService: IdentificationService {
    let error: IdentificationError
    init(_ error: IdentificationError) { self.error = error }
    func identify(_ input: ScanInput) async throws -> IdentificationOutcome { throw error }
    func searchCatalog(query: String, gameHint: CardGame?) async throws -> [IdentificationCandidate] { throw error }
}
