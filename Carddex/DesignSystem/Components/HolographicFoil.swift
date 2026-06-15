import SwiftUI

/// The signature holographic-foil overlay for rare cards: a rotating foil sheen
/// plus a moving specular sweep, clipped to the card shape. On a real device this
/// later reacts to gyroscope tilt; here it animates on its own. Respects Reduce Motion.
struct HolographicFoil: View {
    var cornerRadius: CGFloat = Theme.Radius.card
    var intensity: Double = 1
    /// When false, renders a single static foil sheen (no per-frame redraw) — use
    /// in grids where many cards are on screen at once.
    var isAnimated: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let foil: [Color] = [
        Color(hex: 0xFF78C8), Color(hex: 0x78E1FF), Color(hex: 0x78FFB4),
        Color(hex: 0xFFE178), Color(hex: 0xFF78C8),
    ]

    var body: some View {
        GeometryReader { geo in
            Group {
                if reduceMotion || !isAnimated {
                    AngularGradient(gradient: Gradient(colors: foil), center: .center)
                        .blendMode(.overlay)
                        .opacity(0.22 * intensity)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let angle = Angle.degrees((t * 36).truncatingRemainder(dividingBy: 360))
                        let sweep = CGFloat(sin(t * 1.1))
                        ZStack {
                            AngularGradient(gradient: Gradient(colors: foil), center: .center, angle: angle)
                                .blendMode(.overlay)
                                .opacity(0.33 * intensity)
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.55), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 0.55)
                            .offset(x: sweep * geo.size.width * 0.7)
                            .blendMode(.screen)
                            .opacity(0.6 * intensity)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}
