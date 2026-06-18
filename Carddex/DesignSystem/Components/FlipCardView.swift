import SwiftUI

/// A card that flips front-to-back on tap. The front is the living holo card
/// (gyro tilt + foil); the back shows set info, condition, and completion
/// status — the "tap to flip to back" interaction from the design spec.
/// The flip is a 180° Y-axis rotation with a spring; Reduce Motion snaps.
struct FlipCardView<Front: View, Back: View>: View {
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back
    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            front()
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(flipped ? 0 : 1)

            back()
                .rotation3DEffect(.degrees(flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(flipped ? 1 : 0)
        }
        .onTapGesture {
            Haptics.impact(.rigid)
            if reduceMotion {
                flipped.toggle()
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    flipped.toggle()
                }
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(flipped ? "Card back. Tap to flip to front." : "Card front. Tap to flip to back.")
    }
}

/// The card back — a vault-style info panel with set details, condition, and
/// completion status. Styled as the "back of a trading card": dark surface,
/// game accent border, centered info.
struct CardBackView: View {
    let card: Card
    var condition: CardCondition? = nil
    var setCompletion: (owned: Int, total: Int)? = nil

    private var setInfo: CardSet? {
        SampleData.sets.first { $0.name == card.setName }
    }

    var body: some View {
        let gameAccent = card.game == .sports
            ? (card.sport?.accent ?? CardGame.sports.accent)
            : card.game.accent

        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [gameAccent.opacity(0.5), gameAccent.opacity(0.15)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5
                    )
            )
            .overlay {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()

                    Image(systemName: card.game == .sports
                          ? (card.sport?.symbol ?? CardGame.sports.symbol)
                          : card.game.symbol)
                        .font(.system(size: 36))
                        .foregroundStyle(gameAccent)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(card.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Text(card.setName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)

                        Text(card.number)
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }

                    if let rarity = card.rarity {
                        Text(rarity)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(gameAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(gameAccent.opacity(0.15), in: Capsule())
                    }

                    if let condition {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .font(.caption2)
                            Text(condition.rawValue)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }

                    if let completion = setCompletion, completion.total > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack")
                                .font(.caption2)
                            Text("Set \(completion.owned)/\(completion.total)")
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                        }
                        .foregroundStyle(completion.owned == completion.total ? Theme.gain : Theme.textTertiary)
                    }

                    Spacer()

                    Text("Tap to flip")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)

                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
            .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
    }
}
