import Foundation
import SwiftData

/// A scan that couldn't be synced yet (offline / transient failure). Replayed
/// by the SyncEngine on the next connectivity change / successful sync. The
/// image is stored as JPEG bytes; `ocrText` is the on-device hint.
///
/// Not a tombstoned table — rows are deleted once the identify call succeeds,
/// so there are no `dirty`/`deletedAt` fields. `remoteUpdatedAt` is unused.
@Model
final class PendingScanEntity {
    @Attribute(.unique) var id: UUID
    var imageData: Data
    var ocrText: [String]
    var gameHint: String?
    var createdAt: Date

    init(id: UUID = UUID(), imageData: Data, ocrText: [String], gameHint: String?, createdAt: Date = .now) {
        self.id = id
        self.imageData = imageData
        self.ocrText = ocrText
        self.gameHint = gameHint
        self.createdAt = createdAt
    }
}

extension PendingScanEntity {
    func toInput() -> ScanInput {
        ScanInput(
            imageData: imageData,
            ocrText: ocrText,
            gameHint: gameHint.flatMap { CardGame(rawValue: $0) }
        )
    }
}
