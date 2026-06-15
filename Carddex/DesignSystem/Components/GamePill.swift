import SwiftUI

/// Small colored capsule showing which game a card belongs to.
struct GamePill: View {
    let game: CardGame

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: game.symbol)
                .font(.caption2)
            Text(game.displayName)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .foregroundStyle(game.accent)
        .background(game.accent.opacity(0.18), in: Capsule())
    }
}
