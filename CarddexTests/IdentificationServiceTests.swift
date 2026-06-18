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
}

/// A stub service that always throws a given error — used to verify callers
/// (e.g. the scan flow) handle identify failures without consuming quota.
private struct ThrowingIdentificationService: IdentificationService {
    let error: IdentificationError
    init(_ error: IdentificationError) { self.error = error }
    func identify(_ input: ScanInput) async throws -> IdentificationOutcome { throw error }
}
