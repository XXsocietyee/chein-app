import SwiftUI

// R3 scratch-to-win tiles, R4 snow globe (shake → particles settle).

// MARK: - R3 Scratch tiles

/// Coverage of one scratch tile on a coarse grid; a tile counts as scratched at `threshold` (60 %).
struct MotionR2ScratchCoverage: Equatable {
    static let side = 12
    var cells: Set<Int> = []
    var fraction: Double { Double(cells.count) / Double(Self.side * Self.side) }

    /// Marks the cells under a brush of `radius` at `point` in a tile of `size`.
    mutating func scratch(at point: CGPoint, radius: CGFloat, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let side = Self.side
        let cellWidth = size.width / CGFloat(side)
        let cellHeight = size.height / CGFloat(side)
        for row in 0..<side {
            for column in 0..<side {
                let center = CGPoint(x: (CGFloat(column) + 0.5) * cellWidth, y: (CGFloat(row) + 0.5) * cellHeight)
                if hypot(center.x - point.x, center.y - point.y) <= radius { cells.insert(row * side + column) }
            }
        }
    }
}

/// R3: three (or `prizes.count`) tiles, each a `Canvas` cover erased by a `DragGesture`. One selection haptic per tile
/// when it passes 60 %, which auto-completes the tile; `onComplete` when every tile is open. Reduce Motion: tap opens
/// a tile (fade). VoiceOver: each tile is a button "刮开第 n 格" with the prize as its value once open.
struct MotionR2ScratchTiles: View {
    let prizes: [String]
    var threshold: Double = 0.6
    var enabled: Bool = true
    var onComplete: (() -> Void)? = nil
    @State private var coverage: [Int: MotionR2ScratchCoverage] = [:]
    @State private var strokes: [Int: [CGPoint]] = [:]
    @State private var opened: Set<Int> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(prizes.enumerated()), id: \.offset) { index, prize in
                tile(index: index, prize: prize)
            }
        }
        .sensoryFeedback(.selection, trigger: opened.count)
        .sensoryFeedback(.success, trigger: opened.count == prizes.count) { old, new in !old && new }
        .accessibilityIdentifier("motion2.scratch.tiles")
    }

    private func tile(index: Int, prize: String) -> some View {
        let isOpen = opened.contains(index)
        return ZStack {
            Text(verbatim: prize)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            if !isOpen { cover(index: index).transition(.opacity) }
        }
        .frame(height: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("motion2.scratch.tile \(index + 1)"))
        .accessibilityValue(isOpen ? Text(verbatim: prize) : Text("motion2.scratch.covered"))
        .accessibilityAddTraits(isOpen ? [] : .isButton)
        .accessibilityAction { open(index) }
    }

    private func cover(index: Int) -> some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12), with: .color(.gray))
                context.blendMode = .destinationOut
                for point in strokes[index] ?? [] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)), with: .color(.black))
                }
            }
            .compositingGroup()
            .overlay {
                Image(systemName: "hand.draw").font(.title3).foregroundStyle(.white).allowsHitTesting(false).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .gesture(scratchGesture(index: index, size: proxy.size))
            .onTapGesture { if reduceMotion { open(index) } }
        }
    }

    private func scratchGesture(index: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard enabled, !opened.contains(index) else { return }
                strokes[index, default: []].append(value.location)
                var tileCoverage = coverage[index] ?? MotionR2ScratchCoverage()
                tileCoverage.scratch(at: value.location, radius: 18, in: size)
                coverage[index] = tileCoverage
                if tileCoverage.fraction >= threshold { open(index) }
            }
    }

    private func open(_ index: Int) {
        guard enabled, !opened.contains(index) else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth) { _ = opened.insert(index) }
        if prizes.indices.contains(index) { MotionR2.announce(verbatim: prizes[index]) }
        if opened.count == prizes.count { onComplete?() }
    }
}

// MARK: - R4 Snow globe

/// One particle of the globe: a fixed seed for its column, size and fall speed.
private struct MotionR2Flake {
    let x: Double
    let size: Double
    let speed: Double
    let drift: Double
}

/// R4: snow inside a globe. Every increment of `shakes` (the ball-shake kit's existing CoreMotion hit count, or a
/// device shake through `cyOnShake` when `stirsOnShake`) throws the flakes up; they then settle with damping. Drawn
/// with `TimelineView` + `Canvas` (no SpriteKit); the timeline pauses once the snow has settled. Reduce Motion / flag
/// off: the settled globe, static. Decoration: hidden from VoiceOver (the kit announces hits).
struct MotionR2SnowGlobe: View {
    var shakes: Int = 0
    var stirsOnShake: Bool = false
    var tint: Color = .accentColor
    @State private var stirredAt: Date?
    @State private var localShakes = 0
    /// Bumped once the snow has settled so the timeline re-reads `paused` and stops ticking.
    @State private var settledTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let settleSeconds = 2.4
    private static let flakes: [MotionR2Flake] = (0..<48).map { index in
        let a = Double((index * 37) % 100) / 100
        let b = Double((index * 61) % 100) / 100
        let c = Double((index * 17) % 100) / 100
        return MotionR2Flake(x: 0.15 + a * 0.7, size: 2 + b * 3, speed: 0.6 + c * 0.6, drift: (b - 0.5) * 0.2)
    }

    private var live: Bool { MotionR2.live(reduceMotion: reduceMotion) }

    var body: some View {
        let _ = settledTick
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isStirring(Date()))) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, now: timeline.date)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 180)
        .frame(maxWidth: .infinity)
        .background { globe }
        .accessibilityHidden(true)
        .onChange(of: shakes) { _, _ in stir() }
        .onChange(of: localShakes) { _, _ in stir() }
        .cyOnShake(enabled: stirsOnShake && live) { localShakes += 1 }
        .accessibilityIdentifier("motion2.snowGlobe")
    }

    private var globe: some View {
        ZStack(alignment: .bottom) {
            Circle().fill(tint.opacity(0.12))
            Circle().strokeBorder(tint.opacity(0.35), lineWidth: 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 180)
    }

    private func isStirring(_ now: Date) -> Bool {
        guard live, let stirredAt else { return false }
        return now.timeIntervalSince(stirredAt) < Self.settleSeconds
    }

    private func stir() {
        guard live else { return }
        stirredAt = Date()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.settleSeconds + 0.1))
            settledTick += 1
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, now: Date) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let elapsed = stirredAt.map { now.timeIntervalSince($0) } ?? Self.settleSeconds
        let t = min(1, max(0, elapsed / Self.settleSeconds))
        // 0 = thrown to the top, 1 = settled at the bottom; damped wobble on the way down.
        let fall = 1 - pow(1 - t, 2)
        for (index, flake) in Self.flakes.enumerated() {
            let settledY = 0.78 + Double(index % 5) * 0.035
            let thrownY = 0.12 + Double(index % 7) * 0.05
            let y = thrownY + (settledY - thrownY) * min(1, fall * (0.8 + 0.2 * flake.speed) * 1.1)
            let wobble = sin(elapsed * 6 + Double(index)) * flake.drift * (1 - t)
            let point = CGPoint(x: center.x + CGFloat(flake.x - 0.5 + wobble) * radius * 1.6,
                                y: center.y + CGFloat(y - 0.5) * radius * 1.8)
            guard hypot(point.x - center.x, point.y - center.y) < radius - 4 else { continue }
            context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: flake.size, height: flake.size)),
                         with: .color(.white.opacity(0.9)))
            context.stroke(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: flake.size, height: flake.size)),
                           with: .color(tint.opacity(0.4)), lineWidth: 0.5)
        }
    }
}

#Preview("Motion r2 games") {
    VStack(spacing: 24) {
        MotionR2ScratchTiles(prizes: ["10 积分", "谢谢参与", "徽章"])
        MotionR2SnowGlobe(shakes: 1, stirsOnShake: true)
    }
    .padding()
}
