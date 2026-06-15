import SwiftUI

/// Branded, shareable poster of the whole collection's value — the "my collection
/// is worth $X" growth loop. Rendered to an image via `ImageRenderer`.
struct ShareableCollectionCard: View {
    let totalValue: String
    let gain: String
    let gainUp: Bool
    let cardCount: Int
    let uniqueCount: Int
    let tiles: [CardGame]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("The Case")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            Spacer()
            Text("My collection")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            Text(totalValue)
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(gain)
                .font(.title3.weight(.semibold))
                .foregroundStyle(gainUp ? Theme.gain : Theme.loss)
            Text("\(cardCount) cards · \(uniqueCount) unique")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 2)
            Spacer()
            HStack(spacing: 12) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, game in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: game.artGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 78, height: 109)
                        .overlay(Image(systemName: game.symbol).font(.title2).foregroundStyle(.white.opacity(0.55)))
                }
            }
            Spacer()
            Text("Scan, value & track your cards with The Case")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(44)
        .frame(width: 600, height: 750)
        .background(posterBackground)
    }
}

/// Branded poster for a single card.
struct ShareableCardPoster: View {
    let name: String
    let setLine: String
    let price: String
    let game: CardGame
    let sport: SportCategory?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("The Case")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            Spacer()
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: sport?.artGradient ?? game.artGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 230, height: 322)
                .overlay(Image(systemName: sport?.symbol ?? game.symbol).font(.system(size: 60)).foregroundStyle(.white.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.15)))
            Text(name)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(setLine)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.6))
            Text(price)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()
            Spacer()
            Text("Identified with The Case")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(44)
        .frame(width: 600, height: 750)
        .background(posterBackground)
    }
}

private var posterBackground: some View {
    ZStack {
        Color(hex: 0x0B0B0F)
        LinearGradient(colors: [Color(hex: 0x20202E), Color(hex: 0x0B0B0F)], startPoint: .top, endPoint: .bottom)
        RadialGradient(colors: [Color(hex: 0x35354C).opacity(0.6), .clear], center: .top, startRadius: 0, endRadius: 500)
    }
}
