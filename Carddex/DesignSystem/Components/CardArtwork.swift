import SwiftUI

/// Placeholder card artwork. Once catalog image URLs are wired in (Phase 1),
/// this swaps to an `AsyncImage` while keeping the same framing.
struct CardArtwork: View {
    let game: CardGame
    var cornerRadius: CGFloat = Theme.Radius.md

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(game.accent.opacity(0.15))
            Image(systemName: game.symbol)
                .font(.largeTitle)
                .foregroundStyle(game.accent.opacity(0.5))
        }
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
    }
}
