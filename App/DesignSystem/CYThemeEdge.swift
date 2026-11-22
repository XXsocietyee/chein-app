import SwiftUI

// Chapter-story and locked-gate stroke. The color comes from the existing
// `CYThemeLook` struct (`edge`), not a second type with that name.
// Mood names follow the chapter atmosphere set (DEFAULT / BLUE / RED / YELLOW / WHITE,
// plus NIGHT, ARCHIVE, NEON, MOSS). The stroke uses mute and dim so the accent
// channel, which carries lantern gold on some rows, stays off the card.
// Violet is not used: it stays on selection. Reduce Motion keeps the resting stroke
// and does not run the odd-level pulse.
// `View.cyThemeLook(_:)` remains the look-scope API and is not overloaded.

enum CYThemeEdge {
    /// Unknown or empty moods stay on DEFAULT. Aliases match the chapter mood contract.
    static func palette(for mood: String?) -> CYThemeLook.Palette {
        let raw = mood?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let name: String
        switch raw {
        case "NIGHT": name = "BLUE"
        case "ARCHIVE": name = "YELLOW"
        case "NEON": name = "RED"
        case "MOSS", "": name = "DEFAULT"
        default: name = raw
        }
        return CYThemeLook.Palette(rawValue: name) ?? .black
    }

    /// Keep the topic look's style when one is already in the environment.
    /// A card outside a theme uses stardust, the quiet default.
    static func look(mood: String?, ambient: CYThemeLook?) -> CYThemeLook {
        CYThemeLook(style: ambient?.style ?? .stardust, palette: palette(for: mood), neon: ambient?.neon ?? .yellowCyan)
    }
}

extension CYThemeLook {
    /// Quiet hairline for one chapter card or the locked gate.
    var edge: Color {
        switch palette {
        case .black: return colors.dim.swiftUIColor
        case .white: return colors.mute.swiftUIColor
        case .blue, .red, .yellow: return colors.b.swiftUIColor
        }
    }
}

private struct CYThemeEdgeModifier: ViewModifier {
    let look: CYThemeLook
    var odd: Int
    @QuestifyReduceMotion private var reduceMotion
    @State private var pulse = false

    private var level: Int { min(3, max(0, odd)) }

    func body(content: Content) -> some View {
        let resting = 0.45 + Double(level) * 0.08
        let opacity = (!reduceMotion && pulse) ? min(0.95, resting + 0.28) : resting
        content.overlay {
            RoundedRectangle(cornerRadius: look.cardRadius, style: .continuous)
                .strokeBorder(look.edge.opacity(opacity), lineWidth: 0.5 + CGFloat(level) * 0.25)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .accessibilityIdentifier("cy.themeEdge." + look.palette.rawValue)
        }
        .onAppear {
            guard !reduceMotion, level > 0 else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { pulse = false }
        }
    }
}

private struct CYThemeEdgeMoodModifier: ViewModifier {
    let mood: String?
    var odd: Int
    @Environment(\.cyThemeLook) private var ambient

    func body(content: Content) -> some View {
        content.cyThemeEdge(CYThemeEdge.look(mood: mood, ambient: ambient), odd: odd)
    }
}

extension View {
    /// Decorative edge for one chapter card. Does not change layout, copy, or hit testing.
    func cyThemeEdge(_ look: CYThemeLook, odd: Int = 0) -> some View {
        modifier(CYThemeEdgeModifier(look: look, odd: odd))
    }

    /// Resolves a chapter mood onto `CYThemeLook` and strokes `look.edge`.
    func cyThemeEdge(mood: String?, odd: Int = 0) -> some View {
        modifier(CYThemeEdgeMoodModifier(mood: mood, odd: odd))
    }
}

#Preview("Theme edges") {
    VStack(alignment: .leading, spacing: CYSpacing.md) {
        ForEach(CYThemeLook.Palette.allCases, id: \.rawValue) { palette in
            let look = CYThemeLook(style: .stardust, palette: palette)
            Text(verbatim: palette.rawValue)
                .cyText(.body)
                .foregroundStyle(look.colors.ink.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.lg)
                .background(look.colors.card.swiftUIColor, in: RoundedRectangle(cornerRadius: look.cardRadius, style: .continuous))
                .cyThemeEdge(look, odd: 2)
        }
    }
    .padding(CYSpacing.pageHorizontal)
    .frame(maxHeight: .infinity)
    .background(CYNight.ink0)
    .themeDomain(.player)
    .preferredColorScheme(.dark)
}
