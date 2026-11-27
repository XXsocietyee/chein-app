import SwiftUI

// Explore / Today polish (design-wave3, pass pol1): night-city ground, staggered section reveal, backdrop parallax,
// card edge + depth, eyebrow type. Presentation only; every effect has a Reduce Motion / Low Power fallback.

// MARK: - Ground

/// Explore's page ground: ink0 (never pure black) with an indigo wash at the top that fades out by mid-screen.
/// Light appearance keeps the standard page colour.
struct CYExploreGround: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack(alignment: .top) {
            if scheme == .dark {
                CYNight.ink0
                LinearGradient(colors: [CYNight.indigo.opacity(0.55), CYNight.indigo.opacity(0.18), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 420)
            } else {
                CYColor.bgPage
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Section reveal

/// Remembers which sections already revealed and when the first pass began, so the stagger plays once per screen and
/// sections that scroll in later appear without a delay.
@MainActor final class CYSectionRevealGate {
    fileprivate var shown: Set<Int> = []
    fileprivate var firstPass: Date?
    init() {}
}

private struct CYSectionReveal: ViewModifier {
    let order: Int
    let gate: CYSectionRevealGate
    @State private var visible: Bool
    @QuestifyReduceMotion private var reduceMotion

    init(order: Int, gate: CYSectionRevealGate) {
        self.order = order
        self.gate = gate
        _visible = State(initialValue: gate.shown.contains(order))
    }

    func body(content: Content) -> some View {
        content
            .opacity(visible || reduceMotion ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 22)
            .scaleEffect(visible || reduceMotion ? 1 : 0.97, anchor: .top)
            .onAppear {
                guard !visible else { return }
                let now = Date()
                if gate.firstPass == nil { gate.firstPass = now }
                gate.shown.insert(order)
                // Only the first fold staggers (70 ms apart); later sections reveal the moment they arrive.
                let inFirstPass = now.timeIntervalSince(gate.firstPass ?? now) < 0.45
                let delay = inFirstPass ? Double(min(order, 5)) * 0.07 : 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay)) { visible = true }
            }
    }
}

extension View {
    /// Spring reveal (fade, 22 pt rise, 0.97 to 1) for one Explore section. `order` is the section's place on the screen.
    func cySectionReveal(order: Int, gate: CYSectionRevealGate) -> some View {
        modifier(CYSectionReveal(order: order, gate: gate))
    }
}

// MARK: - Backdrop parallax

private struct CYBackdropParallax: ViewModifier {
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            // Oversized by 12 % so the lag never exposes an edge; the card's clip shape trims the overhang.
            content
                .scaleEffect(1.12)
                .visualEffect { view, proxy in
                    let viewport = proxy.bounds(of: .scrollView)?.height ?? 800
                    let offsetFromMid = proxy.frame(in: .scrollView).midY - viewport / 2
                    // The backdrop lags the card: it drifts 8 % of the card's distance from mid-screen, capped.
                    return view.offset(y: max(-14, min(14, -offsetFromMid * 0.08)))
                }
        }
    }
}

extension View {
    /// Card art that drifts slower than its card while the feed scrolls. Reduce Motion: static.
    func cyBackdropParallax() -> some View { modifier(CYBackdropParallax()) }
}

// MARK: - Card edge and depth

private struct CYNightCardDepth: ViewModifier {
    let radius: CGFloat
    /// Native r2: no glass edge or depth shadows. Shows the content as is.
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    /// 1 pt night-glass edge (14 % top, 4 % bottom) plus layered depth shadows.
    func cyNightCardDepth(radius: CGFloat = CYRadius.xl) -> some View { modifier(CYNightCardDepth(radius: radius)) }
}

// MARK: - Eyebrow

extension Text {
    /// Uppercase eyebrow in the footnote text style, system letter spacing (owner rule 2: no custom tracking).
    func cyEyebrow(isChinese: Bool) -> some View {
        self.font(.footnote.weight(isChinese ? .medium : .semibold))
            .textCase(.uppercase)
    }
}

// MARK: - Lantern medallion

/// The Today card's single light source: a glass disc with its glyph, top trailing, behind nothing. Lantern gold only when
/// the card is a discovery prompt (`lit`); tickets and club events keep a neutral glass disc. Breathes unless
/// Reduce Motion or Low Power is on.
struct CYTodayMedallion: View {
    let symbol: String
    let lit: Bool
    @QuestifyReduceMotion private var reduceMotion
    @State private var breathe = false

    private var animates: Bool { !reduceMotion && CYLightBudget.shadersAllowed }

    var body: some View {
        ZStack {
            if lit {
                Circle().fill(CYNight.glow(radius: 36)).frame(width: 150, height: 150)
                    .scaleEffect(animates && breathe ? 1.08 : 1)
                    .opacity(animates && breathe ? 1 : 0.8)
            }
            Image(systemName: symbol)
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(lit ? CYNight.lanternHot : .white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.ultraThinMaterial).overlay(Circle().fill(CYNight.glassFill)))
                .overlay(Circle().strokeBorder(LinearGradient(colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom],
                                                              startPoint: .top, endPoint: .bottom), lineWidth: 1))
        }
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
        .onAppear {
            guard animates, lit else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
