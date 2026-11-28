import SwiftUI

// Night-city light, wave 3 (B6), recipe 2 (Kubai087 continuity): the wallet card is tapped and the pass grows out of
// that very card; dragging the pass down past 120 pt (or tapping the backdrop) sends it back along the same path.
// No `.sheet`: one progress value `p` (0 = the card in its slot, 1 = the pass) drives the pass layer's scale, offset
// and clip rect between the measured card frame and the pass frame, so forward and back are the same motion and a
// drag scrubs it. The card in the slot cross-dissolves into the pass over the first third.
// The host is laid out at the card's width, so the pass uses the same width (inset it from outside).
// Reduce Motion: no travel and no scale, a 0.2 s crossfade only. Backdrop is `ink0` at 70 %.

@MainActor struct CYPassFromCard<Card: View, Pass: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let card: () -> Card
    @ViewBuilder let pass: () -> Pass

    @State private var mounted = false
    @State private var p: CGFloat = 0
    @State private var drag: CGFloat = 0
    @State private var source: CGRect = .zero
    @State private var target: CGRect = .zero
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private let space = "cyPassFromCard"
    private let grow = Animation.spring(response: 0.52, dampingFraction: 0.84)
    private let dismissDistance: CGFloat = 120

    /// Effective progress: the drag scrubs it back along the same path.
    private var progress: CGFloat { max(0, min(1, p - drag / 520)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button { isPresented = true } label: {
                card().opacity(mounted ? 1 - min(1, Double(progress) * 3) : 1)
            }
            .buttonStyle(.plain)
            .background(GeometryReader { g in
                Color.clear.preference(key: CYPassSourceFrameKey.self, value: g.frame(in: .named(space)))
            })
            .onPreferenceChange(CYPassSourceFrameKey.self) { source = $0 }
            .accessibilityLabel(Text(verbatim: c.t("打开票券", "Open pass")))
            .accessibilityIdentifier("ticketPass.host.card")

            if mounted { overlayLayer }
        }
        .coordinateSpace(name: space)
        .onChange(of: isPresented) { _, now in now ? present() : dismiss() }
        .onAppear { if isPresented { present() } }
        .cyHaptic(.selection, trigger: isPresented, where: CYHapticTransition.isOn)
        .cyHaptic(.impactLight, trigger: isPresented, where: CYHapticTransition.turnedOff)
    }

    private var overlayLayer: some View {
        ZStack {
            CYNight.ink0.opacity(0.7 * Double(progress))
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                passLayer
                Spacer(minLength: 0)
            }
            VStack {
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark").font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                            .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                            .background(CYColor.actionSecondary, in: Circle())
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityLabel(Text("action.close"))
                    .accessibilityIdentifier("ticketPass.host.close")
                    .opacity(Double(max(0, progress * 2 - 1)))
                }
                .padding(.horizontal, CYSpacing.lg)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var passLayer: some View {
        let t = progress
        let measured = target.width > 1 && source.width > 1
        let s = reduceMotion || !measured ? 1 : lerp(source.width / target.width, 1, t)
        let dx = reduceMotion || !measured ? 0 : lerp(source.minX - target.minX, 0, t)
        let dy = reduceMotion || !measured ? 0 : lerp(source.minY - target.minY, 0, t)
        let clipHeight = reduceMotion || !measured ? target.height : lerp(source.height / max(s, 0.01), target.height, t)
        return pass()
            .background(GeometryReader { g in
                Color.clear.preference(key: CYPassTargetFrameKey.self, value: g.frame(in: .named(space)))
            })
            .onPreferenceChange(CYPassTargetFrameKey.self) { if target.width <= 1, $0.width > 1 { target = $0 } }
            .mask(alignment: .topLeading) {
                Rectangle().frame(height: measured && !reduceMotion ? max(clipHeight, 1) : nil)
            }
            .scaleEffect(s, anchor: .topLeading)
            .offset(x: dx, y: dy)
            .opacity(measured ? (reduceMotion ? Double(t) : min(1, Double(t) * 3 + 0.12)) : 0)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { drag = max(0, $0.translation.height) }
                    .onEnded { value in
                        if value.translation.height > dismissDistance || value.predictedEndTranslation.height > dismissDistance * 2.4 {
                            isPresented = false
                        } else {
                            withAnimation(CYMotion.release) { drag = 0 }
                        }
                    }
            )
            .accessibilityAction(.escape) { isPresented = false }
            .accessibilityElement(children: .contain)
    }

    private func present() {
        guard !mounted else { return }
        mounted = true; p = 0; drag = 0
        Task { @MainActor in
            // One layout pass so the pass frame is measured before it travels.
            for _ in 0..<20 where target.width <= 1 { try? await Task.sleep(for: .milliseconds(16)) }
            withAnimation(reduceMotion ? CYMotion.reduced : grow) { p = 1 }
        }
    }

    private func dismiss() {
        guard mounted else { return }
        withAnimation(reduceMotion ? CYMotion.reduced : grow, completionCriteria: .logicallyComplete) {
            p = 0; drag = 0
        } completion: { mounted = false }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
}

private struct CYPassSourceFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
private struct CYPassTargetFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
