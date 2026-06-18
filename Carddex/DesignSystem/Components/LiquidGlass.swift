import SwiftUI

/// iOS 26 Liquid Glass surfaces with a warm-material fallback for older systems.
/// Chrome (tab bar, icon buttons, search, chips, segments, cards, stat pills)
/// routes through these so the app picks up the refractive glass look on 26+.
extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = Theme.Radius.lg, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(liquidGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Theme.hairline))
        }
    }

    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(liquidGlass(tint: tint, interactive: interactive), in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
        }
    }

    @ViewBuilder
    func glassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(liquidGlass(tint: tint, interactive: interactive), in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline))
        }
    }

    /// Card surface — alias for `glassCard` so call sites read as "panel" for
    /// larger containers (stat tiles, rows, sheets). Kept alongside the other
    /// glass helpers so all Liquid Glass surfaces live in one place.
    func glassPanel(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        glassCard(cornerRadius: cornerRadius)
    }
}

@available(iOS 26.0, *)
private func liquidGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

/// Groups nearby glass elements so they blend/merge correctly (no-op fallback).
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
