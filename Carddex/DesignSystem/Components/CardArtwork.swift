import SwiftUI

/// Card artwork. Currently a game-tinted placeholder with a rarity-aware holo
/// overlay; swaps to an `AsyncImage` once catalog `imageURL`s are wired in (Phase 1).
struct CardArtwork: View {
    let game: CardGame
    var rarity: String? = nil
    var price: Money? = nil
    var cornerRadius: CGFloat = Theme.Radius.card

    var body: some View {
        let tier = Rarity.tier(rarityText: rarity, price: price)
        ZStack {
            LinearGradient(colors: game.artGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: game.symbol)
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.42))
            if tier != .none {
                HolographicFoil(cornerRadius: cornerRadius, intensity: tier == .mythic ? 1.0 : 0.6)
            }
        }
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12))
        )
    }
}
