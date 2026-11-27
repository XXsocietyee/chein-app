import SwiftUI

/// GO press-and-hold (Night-city light, wave 3 / B4).
///
/// Hold the 72 pt pill for 600 ms: the lantern ring fills in three segments, so the two gaps read as ticks at 200 ms and
/// 400 ms (impactLight each), and the commit lands at 600 ms (impactHeavy). Releasing early drains the ring and cancels.
/// Reduce Motion replaces the hold with tap-to-start plus a confirmation. VoiceOver activation starts directly (a hold is
/// not an accessible gesture, and VoiceOver activation is already deliberate).
struct CYGoHoldPill: View {
    var enabled = true
    /// DEBUG fixtures drive a scripted press with this; live callers leave it false.
    var demoPress = false
    var onCommit: () -> Void

    static let holdDuration: Double = 0.6
    static let size = CGSize(width: 176, height: 72)

    @QuestifyReduceMotion private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var committed = false
    @State private var holdTask: Task<Void, Never>?
    @State private var tickA = 0
    @State private var tickB = 0
    @State private var commitTick = 0
    @State private var pulse: CGFloat = 1
    @State private var confirming = false

    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            pill
            Text(reduceMotion ? "roam.go.hint.tap" : "roam.go.hint.hold")
                .cyText(.bodyMedium)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityHidden(true)
        }
        .confirmationDialog("roam.go.confirm.title", isPresented: $confirming, titleVisibility: .visible) {
            Button("roam.go.confirm.action") { onCommit() }
            Button("roam.go.confirm.cancel", role: .cancel) {}
        }
        .cyHaptic(.impactLight, trigger: tickA)
        .cyHaptic(.impactLight, trigger: tickB)
        .cyHaptic(.impactHeavy, trigger: commitTick)
        .onChange(of: demoPress) { _, pressed in pressed ? begin() : end() }
        .onDisappear { holdTask?.cancel() }
    }

    private var face: some View {
        Text("GO")
            .cyText(.dataXL)
            .foregroundStyle(.black)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(Color.white, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
            .overlay { if !reduceMotion { ring } }
            .scaleEffect((holding ? 0.96 : 1) * pulse)
            .animation(QuestifyMotion.press, value: holding)
            .contentShape(Capsule())
            .opacity(enabled ? 1 : 0.4)
    }

    @ViewBuilder private var pill: some View {
        if reduceMotion {
            Button { confirming = true } label: { face }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityIdentifier("roam.live.start")
                .accessibilityLabel(Text("GO"))
        } else {
            face
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        // Sliding well off the pill is a cancel, like lifting early.
                        if hypot(value.translation.width, value.translation.height) > 64 { end() } else if !holding && !committed { begin() }
                    }
                    .onEnded { _ in end() })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("GO"))
                .accessibilityHint(Text("roam.go.hint.hold"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if enabled { commit() } }
                .accessibilityIdentifier("roam.live.start")
                // Until the player has agreed, the dimmed pill reports itself as disabled (it was only drawn faded).
                .disabled(!enabled)
        }
    }

    /// Three arc segments around the capsule. The gaps are the two ticks.
    private var ring: some View {
        GoHoldRingShape(progress: progress)
            .stroke(CYNight.lantern, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .shadow(color: CYNight.lantern.opacity(0.7), radius: 8)
            .padding(-6)
            .allowsHitTesting(false)
    }

    private func begin() {
        guard enabled, !holding, !committed else { return }
        holding = true
        progress = 0
        withAnimation(.linear(duration: Self.holdDuration)) { progress = 1 }
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            tickA += 1; tick()
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            tickB += 1; tick()
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            commit()
        }
    }

    private func tick() {
        withAnimation(QuestifyMotion.press) { pulse = 1.035 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(QuestifyMotion.release) { pulse = 1 }
        }
    }

    private func end() {
        holdTask?.cancel()
        guard holding else { return }
        holding = false
        if !committed { withAnimation(.easeOut(duration: 0.2)) { progress = 0 } }
    }

    private func commit() {
        guard !committed else { return }
        committed = true
        holding = false
        commitTick += 1
        onCommit()
        // Re-arm in case the commit was refused and the pill stays on screen.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            committed = false
            progress = 0
        }
    }
}

/// 44 pt walking puck, bottom-right. The pill shrinks into it (shared `matchedGeometryEffect` id owned by the caller).
/// The slow lantern halo breathes on the same 2.2 s clock as the fog edge; Reduce Motion keeps it still.
struct CYGoPuck: View {
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.2)
            Image(systemName: "figure.walk")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(Color.white, in: Circle())
                .background {
                    Circle().fill(CYNight.lantern.opacity(0.30 + 0.12 * phase))
                        .frame(width: 44, height: 44).scaleEffect(1.45 + 0.08 * phase).blur(radius: 8)
                }
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("roam.go.puck.a11y"))
        .accessibilityIdentifier("roam.live.puck")
    }
}

/// One lantern ring that crosses the map from the puck once per commit, then stops (<= 850 ms). Not a shader: a Canvas
/// ring keeps the frame cost flat and the one-shader-at-a-time budget free. Reduce Motion and Low Power draw nothing.
struct CYGoWave: View {
    var trigger: Int
    @QuestifyReduceMotion private var reduceMotion
    @State private var start: Date?
    private let duration = 0.85

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { ctx, size in
                guard let start, !reduceMotion, CYLightBudget.shadersAllowed else { return }
                let t = min(max(timeline.date.timeIntervalSince(start) / duration, 0), 1)
                guard t < 1 else { return }
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let ease = 1 - pow(1 - t, 3)
                for (lag, width, color, alpha) in [(0.0, 5.0, CYNight.lanternHot, 0.75), (0.12, 14.0, CYNight.lantern, 0.35)] {
                    let tt = max(0, ease - lag)
                    let r = tt * min(size.width, size.height) / 2
                    guard r > 1 else { continue }
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(color.opacity(alpha * (1 - t))), lineWidth: width * (1 - t * 0.6))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            let now = Date()
            start = now
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                if start == now { start = nil }
            }
        }
    }
}

/// The hold ring: the capsule outline filled by `progress` in three segments separated by small gaps.
private struct GoHoldRingShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let outline = Capsule().path(in: rect)
        var result = Path()
        for i in 0..<3 {
            let start = CGFloat(i) / 3
            let lo = start + 0.012
            let hi = start + 1.0 / 3 - 0.012
            let to = min(hi, start + max(0, min(progress - start, 1.0 / 3)))
            if to > lo { result.addPath(outline.trimmedPath(from: lo, to: to)) }
        }
        return result
    }
}
