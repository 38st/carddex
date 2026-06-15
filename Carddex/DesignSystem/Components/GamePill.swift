import SwiftUI

/// Small colored capsule showing a card's category. For sports cards it shows the
/// specific sport (Basketball, Baseball, …); otherwise the game (Pokémon, Magic, …).
struct GamePill: View {
    let game: CardGame
    var sport: SportCategory? = nil

    private var icon: String { sport?.symbol ?? game.symbol }
    private var label: String { sport?.displayName ?? game.displayName }
    private var color: Color { sport?.accent ?? game.accent }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .foregroundStyle(color)
        .background(color.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.30)))
    }
}
