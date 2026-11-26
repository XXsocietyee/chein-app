import SwiftUI

/// Night glass (spec 2.2): chrome over a map or photo only. `glassFill` over `.ultraThinMaterial`, a 1 pt
/// inner edge (14 % at the top, 4 % at the bottom) and a 12 pt shadow at 40 % ink0. Never on rows or content cards.
/// Reduce Transparency: a solid `ink2` with the same edge, no material.
private struct CYNightGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Native r2: no glass, material, gradient edge or shadow. A plain system secondary background in the shape,
    /// so controls over a map stay legible.
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .secondarySystemBackground), in: shape)
    }
}

extension View {
    func cyNightGlass<S: InsettableShape>(in shape: S) -> some View { modifier(CYNightGlassModifier(shape: shape)) }

    func cyNightGlass(cornerRadius: CGFloat = CYRadius.lg) -> some View {
        cyNightGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
