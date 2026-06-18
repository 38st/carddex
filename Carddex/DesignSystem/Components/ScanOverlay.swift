import SwiftUI

/// The animated scan overlay — the "magic moment" from the design spec.
/// Phases: idle (dashed frame) → scanning (L-corners snap inward + scan-line
/// sweep) → found (accent flash). Respects Reduce Motion (static frame, no sweep).
struct ScanOverlay: View {
    let phase: Phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase: Equatable {
        case idle, scanning, found
    }

    @State private var scanLineY: CGFloat = 0
    @State private var flashOpacity: Double = 0
    @State private var cornerInset: CGFloat = 20

    var body: some View {
        ZStack {
            reticle
            if phase == .scanning { scanLine }
            if phase == .found { flash }
        }
        .onChange(of: phase) { _, new in
            switch new {
            case .idle:
                cornerInset = 20
                scanLineY = 0
            case .scanning:
                startSweep()
                snapCorners()
            case .found:
                flashBurst()
            }
        }
    }

    // MARK: - Reticle (L-corners that snap inward when scanning)

    private var reticle: some View {
        let color = phase == .idle ? Theme.accent.opacity(0.5) : Theme.accent.opacity(0.9)
        let width: CGFloat = phase == .idle ? 2 : 3
        return ZStack {
            if phase == .idle {
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .strokeBorder(color, style: StrokeStyle(lineWidth: width, dash: [9]))
                    .padding(20)
            } else {
                cornerBrackets(color: color, width: width)
            }
        }
        .animation(Theme.springUI, value: phase)
    }

    private func cornerBrackets(color: Color, width: CGFloat) -> some View {
        let len: CGFloat = 28
        let inset = cornerInset
        return Path { p in
            // Top-left
            p.move(to: CGPoint(x: inset, y: inset + len))
            p.addLine(to: CGPoint(x: inset, y: inset))
            p.addLine(to: CGPoint(x: inset + len, y: inset))
            // Top-right
            p.move(to: CGPoint(x: -inset - len, y: inset))
            p.addLine(to: CGPoint(x: -inset, y: inset))
            p.addLine(to: CGPoint(x: -inset, y: inset + len))
            // Bottom-left
            p.move(to: CGPoint(x: inset + len, y: -inset))
            p.addLine(to: CGPoint(x: inset, y: -inset))
            p.addLine(to: CGPoint(x: inset, y: -inset - len))
            // Bottom-right
            p.move(to: CGPoint(x: -inset, y: -inset - len))
            p.addLine(to: CGPoint(x: -inset, y: -inset))
            p.addLine(to: CGPoint(x: -inset - len, y: -inset))
        }
        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Scan-line sweep

    private var scanLine: some View {
        VStack {
            Spacer()
            HStack {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(height: 2)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 8)
                Rectangle()
                    .fill(Theme.accent.opacity(0.3))
                    .frame(height: 2)
            }
            .frame(height: 60)
            .blur(radius: 12)
            .offset(y: scanLineY)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    // MARK: - Accent flash

    private var flash: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(Theme.accent)
            .opacity(flashOpacity)
            .padding(20)
    }

    // MARK: - Animations

    private func startSweep() {
        guard !reduceMotion else { return }
        scanLineY = -120
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: true)) {
            scanLineY = 120
        }
    }

    private func snapCorners() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            cornerInset = 28
        }
    }

    private func flashBurst() {
        guard !reduceMotion else {
            flashOpacity = 0.15
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            flashOpacity = 0.35
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            flashOpacity = 0
        }
    }
}
