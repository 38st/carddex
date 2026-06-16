import SwiftUI

/// The signature "living card": a card that catches the light and tilts in your
/// hand. Combines device gyro (`MotionManager`) with touch-drag to drive a
/// gyro-reactive holo sheen, a specular highlight, 3D perspective, and a
/// motion-tracking shadow. The app's hero interaction.
struct LivingCardView: View {
    let game: CardGame
    var rarity: String? = nil
    var price: Money? = nil
    var imageURL: URL? = nil
    var sport: SportCategory? = nil
    var maxWidth: CGFloat = 220
    var maxTilt: Double = 15

    @State private var motion = MotionManager()
    @State private var drag: CGSize = .zero
    @State private var pressing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func clamp(_ v: Double, _ limit: Double = 1) -> Double { max(-limit, min(limit, v)) }

    /// Combined normalized tilt: gyro + active drag, with a gentle resting lean
    /// so the card looks alive even without motion (e.g. the simulator).
    private var tilt: CGSize {
        if reduceMotion { return .zero }
        let restX = 0.16, restY = -0.10
        let dx = Double(drag.width) / 90
        let dy = Double(drag.height) / 90
        return CGSize(width: clamp(restX + motion.roll + dx),
                      height: clamp(restY + motion.pitch + dy))
    }

    var body: some View {
        let t = tilt
        CardArtwork(
            game: game, rarity: rarity, price: price, imageURL: imageURL,
            sport: sport, cornerRadius: Theme.Radius.lg, tilt: t
        )
        .frame(maxWidth: maxWidth)
        .rotation3DEffect(.degrees(t.width * maxTilt), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(-t.height * maxTilt), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .scaleEffect(pressing ? 1.04 : 1)
        .shadow(color: .black.opacity(0.55), radius: 22, x: t.width * 14, y: 16 - t.height * 10)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !pressing { Haptics.selection(); pressing = true }
                    drag = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                        drag = .zero
                        pressing = false
                    }
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: pressing)
        .onAppear { if !reduceMotion { motion.start() } }
        .onDisappear { motion.stop() }
    }
}
