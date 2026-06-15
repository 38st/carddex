import SwiftUI

/// Card artwork: real catalog image when available (with a game-tinted gradient
/// placeholder while it loads / when absent), plus a rarity-aware holo overlay.
struct CardArtwork: View {
    let game: CardGame
    var rarity: String? = nil
    var price: Money? = nil
    var imageURL: URL? = nil
    var sport: SportCategory? = nil
    var animatedFoil: Bool = false
    var cornerRadius: CGFloat = Theme.Radius.card

    var body: some View {
        let tier = Rarity.tier(rarityText: rarity, price: price)
        ZStack {
            if let imageURL {
                CachedAsyncImage(url: imageURL) { placeholder }
            } else {
                placeholder
            }

            if tier != .none {
                HolographicFoil(cornerRadius: cornerRadius, intensity: tier == .mythic ? 1.0 : 0.6, isAnimated: animatedFoil)
            }
        }
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12))
        )
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: sport?.artGradient ?? game.artGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: sport?.symbol ?? game.symbol)
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.42))
        }
    }
}
