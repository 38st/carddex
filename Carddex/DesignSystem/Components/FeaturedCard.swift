import SwiftUI

/// Large image-led hero — the reference's signature: card art on a vibrant
/// tinted panel with an eyebrow, name, and value overlay. Caller wraps it in a
/// NavigationLink. This is the focal point at the top of the main screens.
struct FeaturedCard: View {
    let card: Card
    var eyebrow: String? = nil
    var trailingValue: String? = nil
    var trailingDelta: String? = nil
    var deltaUp: Bool = true

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: card.sport?.artGradient ?? card.game.artGradient,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            CardArtwork(
                game: card.game, rarity: card.rarity, price: card.marketPrice,
                imageURL: card.imageURL, sport: card.sport
            )
            .frame(maxWidth: 186)
            .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
            .padding(.top, 30)
            .padding(.bottom, 78)

            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold)).tracking(1.4)
                        .foregroundStyle(.white.opacity(0.85))
                }
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .font(.title3.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                        Text(card.setName)
                            .font(.caption).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    if let trailingValue {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(trailingValue)
                                .font(.headline.weight(.bold)).foregroundStyle(.white).monospacedDigit()
                            if let trailingDelta {
                                Text(trailingDelta)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(deltaUp ? Theme.gain : Theme.loss)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(Theme.hairline)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "heart.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.black.opacity(0.28)))
                .padding(Theme.Spacing.md)
        }
    }
}

#Preview {
    FeaturedCard(card: SampleData.jordan, eyebrow: "Top card",
                 trailingValue: "$2,800", trailingDelta: "+40%")
        .padding()
        .background(VaultBackground())
}
