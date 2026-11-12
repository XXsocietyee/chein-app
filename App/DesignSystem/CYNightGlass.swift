import SwiftUI

/// Night glass (spec 2.2): chrome over a map or photo only. `glassFill` over `.ultraThinMaterial`, a 1 pt
/// inner edge (14 % at the top, 4 % at the bottom) and a 12 pt shadow at 40 % ink0. Never on rows or content cards.
/// Reduce Transparency: a solid `ink2` with the same edge, no material.
private struct CYNightGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    shape.fill(CYNight.ink2)
                } else {
                    shape.fill(.ultraThinMaterial).overlay(shape.fill(CYNight.glassFill))
                }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .shadow(color: CYNight.ink0.opacity(0.4), radius: 12, y: 4)
    }
}

extension View {
    func cyNightGlass<S: InsettableShape>(in shape: S) -> some View { modifier(CYNightGlassModifier(shape: shape)) }

    func cyNightGlass(cornerRadius: CGFloat = CYRadius.lg) -> some View {
        cyNightGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
