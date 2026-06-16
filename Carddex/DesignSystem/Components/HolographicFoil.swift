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
    /// Normalized tilt (-1…1 per axis). When set, the foil sheen + specular
    /// highlight track the tilt instead of animating on a timer — the "living
    /// card" effect. Driven by gyro + drag in `LivingCardView`.
    var tilt: CGSize? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let foil: [Color] = [
        Color(hex: 0xFF78C8), Color(hex: 0x78E1FF), Color(hex: 0x78FFB4),
        Color(hex: 0xFFE178), Color(hex: 0xFF78C8),
    ]

    var body: some View {
        GeometryReader { geo in
            Group {
                if let tilt, !reduceMotion {
                    tiltReactive(tilt: tilt, size: geo.size)
                } else if reduceMotion || !isAnimated {
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

    /// Foil hue + specular highlight that track device/drag tilt — the card
    /// "catches the light" as you move it.
    private func tiltReactive(tilt: CGSize, size: CGSize) -> some View {
        let tx = Double(tilt.width), ty = Double(tilt.height)
        let mag = min(1, hypot(tx, ty))
        return ZStack {
            AngularGradient(
                gradient: Gradient(colors: foil),
                center: .center,
                angle: .degrees(atan2(ty, tx) * 180 / .pi + 90)
            )
            .blendMode(.overlay)
            .opacity((0.24 + 0.22 * mag) * intensity)

            RadialGradient(
                colors: [.white.opacity(0.6), .clear],
                center: UnitPoint(x: 0.5 + tx * 0.45, y: 0.5 + ty * 0.45),
                startRadius: 0,
                endRadius: size.width * 0.75
            )
            .blendMode(.screen)
            .opacity((0.28 + 0.34 * mag) * intensity)
        }
    }
}
