import SwiftUI

// Fog-of-war presentation stages (spec: /Users/fanning/chengyin-refs/specs/roam-fog-engine.md, stages 2 and 3, UI side only).
// Everything here draws from fixture or injected data: no location, no Core types, no live reveal. The Core model
// (geohash bitmaps, FogCoverageReading in Core) lands separately; these types are the view-side stand-ins and carry
// a CY prefix so they never collide with it.

// MARK: - Data

/// One fog cell on the fixture grid (column, row), north-west origin.
struct CYFogPoint: Hashable { let x: Int; let y: Int }

/// Alpha mask of revealed ground. `alpha` is 8-bit (255 confirmed, 128 pending, 0 hidden); `image` is the same data as a
/// premultiplied-black RGBA image for `destinationOut`. `pendingRects` are normalized rects for the hatch pass.
struct CYFogMask: Equatable {
    let width: Int
    let height: Int
    let alpha: [UInt8]
    let pendingRects: [CGRect]
    let revision: Int
    let image: CGImage?
    static func == (a: CYFogMask, b: CYFogMask) -> Bool { a.revision == b.revision && a.width == b.width && a.height == b.height }
}

enum CYFogMaskRasterizer {
    static let maxSide = 512

    /// Builds the mask for a `cols` x `rows` grid. Each cell is `cellPx` pixels square (clamped so the long side <= 512).
    /// `soften` runs one 3x3 box pass for the cloud-like roll-off (skip it under Low Power).
    static func rasterize(confirmed: Set<CYFogPoint>, pending: Set<CYFogPoint>, cols: Int, rows: Int,
                          cellPx: Int = 8, soften: Bool = true, revision: Int) -> CYFogMask {
        let px = max(1, min(cellPx, maxSide / max(cols, rows, 1)))
        let w = cols * px, h = rows * px
        var a = [UInt8](repeating: 0, count: w * h)
        func fill(_ p: CYFogPoint, _ v: UInt8) {
            guard p.x >= 0, p.y >= 0, p.x < cols, p.y < rows else { return }
            for y in (p.y * px)..<((p.y + 1) * px) { for x in (p.x * px)..<((p.x + 1) * px) { a[y * w + x] = v } }
        }
        for p in pending.subtracting(confirmed) { fill(p, 128) }
        for p in confirmed { fill(p, 255) }
        if soften { a = boxBlur(a, w: w, h: h) }
        let rects = pending.subtracting(confirmed).map {
            CGRect(x: CGFloat($0.x) / CGFloat(cols), y: CGFloat($0.y) / CGFloat(rows), width: 1 / CGFloat(cols), height: 1 / CGFloat(rows))
        }
        return CYFogMask(width: w, height: h, alpha: a, pendingRects: rects, revision: revision, image: makeImage(a, w: w, h: h))
    }

    private static func boxBlur(_ src: [UInt8], w: Int, h: Int) -> [UInt8] {
        var out = src
        guard w > 2, h > 2 else { return out }
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                var sum = 0
                for dy in -1...1 { for dx in -1...1 { sum += Int(src[(y + dy) * w + (x + dx)]) } }
                out[y * w + x] = UInt8(sum / 9)
            }
        }
        return out
    }

    private static func makeImage(_ alpha: [UInt8], w: Int, h: Int) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) { rgba[i * 4 + 3] = alpha[i] }   // premultiplied black: only alpha carries data
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

// MARK: - Coverage reading

/// Explored share, with unknown as a first-class case: unknown prints an em dash, never `0` or `0%`.
enum CYFogCoverageReading: Equatable {
    enum UnknownReason: Equatable { case notLoaded, readFailed, noIdentity, permissionMissing, noAreaSelected }
    case known(confirmed: Int, pending: Int, areaCells: Int)
    case unknown(UnknownReason)

    /// Whole percent of confirmed cells over the selected area; nil when unknown or the area is empty.
    var percent: Int? {
        guard case let .known(confirmed, _, area) = self, area > 0 else { return nil }
        return min(100, confirmed * 100 / area)
    }
    var percentText: String { percent.map { "\($0)%" } ?? "—" }
    var pending: Int { if case let .known(_, p, _) = self { return p } else { return 0 } }
}

/// "Explored 37%  ·  4 unconfirmed" chip. Unknown shows an em dash; pending cells are labelled, never folded into the percent.
struct CYFogCoverageBadge: View {
    let reading: CYFogCoverageReading
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            Text("roam.fog.coverage.explored").font(.footnote).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: reading.percentText).font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(CYColor.textPrimary)
            if reading.pending > 0 {
                Text(verbatim: "·").foregroundStyle(CYColor.textTertiary)
                Text("roam.fog.coverage.unconfirmed \(reading.pending)").font(.footnote).foregroundStyle(CYColor.textSecondary)
            }
        }
        .padding(.horizontal, CYSpacing.md).frame(minHeight: 36)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .background(Color.black.opacity(0.5), in: Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("roam.fog.coverage.explored"))
        .accessibilityValue(Text(verbatim: reading.percentText))
        .accessibilityIdentifier("roam.fog.coverage")
    }
}

// MARK: - Reveal choreography

/// Pure choreography state (injectable clock, no timers). New cells get a 480 ms radial wipe from the fix point,
/// staggered 40 ms, at most 6 animated (the rest bake at once). Reduce Motion or Low Power: no wipe; the host crossfades
/// the mask over 200 ms (`crossfadeRevision`). Haptics are throttled to >= 150 ms; the session's first reveal is `.success`.
struct CYRevealChoreographer {
    struct Keyframe: Equatable { let cell: CYFogPoint; let origin: CGPoint; let start: TimeInterval; let duration: TimeInterval }
    static let wipe: TimeInterval = 0.48
    static let stagger: TimeInterval = 0.04
    static let maxAnimated = 6
    static let hapticInterval: TimeInterval = 0.15

    private(set) var active: [Keyframe] = []
    private(set) var successSerial = 0
    private(set) var lightSerial = 0
    private(set) var crossfadeRevision = 0
    private var lastHaptic: TimeInterval = -.infinity
    private var hadFirst = false

    /// Returns cells that bake immediately (all of them under Reduce Motion; the overflow past 6 otherwise).
    @discardableResult
    mutating func enqueue(_ cells: [CYFogPoint], origin: CGPoint, now: TimeInterval, reduceMotion: Bool, lowPower: Bool = false) -> [CYFogPoint] {
        guard !cells.isEmpty else { return [] }
        if now - lastHaptic >= Self.hapticInterval {
            lastHaptic = now
            if hadFirst { lightSerial += 1 } else { successSerial += 1; hadFirst = true }
        }
        if reduceMotion || lowPower { crossfadeRevision += 1; return cells }
        let animated = cells.prefix(Self.maxAnimated)
        for (i, cell) in animated.enumerated() {
            active.append(Keyframe(cell: cell, origin: origin, start: now + Double(i) * Self.stagger, duration: Self.wipe))
        }
        return Array(cells.dropFirst(Self.maxAnimated))
    }

    /// 0...1 ease-out progress of a keyframe (0 before its staggered start).
    static func progress(_ k: Keyframe, at now: TimeInterval) -> Double {
        let t = min(max((now - k.start) / k.duration, 0), 1)
        return 1 - pow(1 - t, 3)
    }

    /// Removes finished wipes and returns their cells so the host can bake them into the mask.
    mutating func settle(at now: TimeInterval) -> [CYFogPoint] {
        let done = active.filter { now >= $0.start + $0.duration }
        active.removeAll { now >= $0.start + $0.duration }
        return done.map(\.cell)
    }
}

// MARK: - Overlay

/// Pure draw: dark scrim (spec token: grey at 0.35 over the basemap, stronger here for the fixture map), the mask cut out
/// with `destinationOut`, a hatch over unconfirmed cells (state is never colour-only), and in-flight radial wipes.
/// No state, no location. One Canvas; ticks only while wipes are in flight.
struct CYFogOverlayLayer: View {
    let mask: CYFogMask
    var grid: (cols: Int, rows: Int)
    var wipes: [CYRevealChoreographer.Keyframe] = []
    var scrimOpacity: Double = 0.62
    var clock: () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: wipes.isEmpty)) { _ in
            let now = clock()
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                ctx.drawLayer { layer in
                    layer.fill(Path(rect), with: .color(Color(red: 0.5, green: 0.52, blue: 0.56).opacity(scrimOpacity)))
                    layer.blendMode = .destinationOut
                    if let image = mask.image { layer.draw(layer.resolve(Image(decorative: image, scale: 1)), in: rect) }
                    for k in wipes {
                        let p = CYRevealChoreographer.progress(k, at: now)
                        guard p > 0 else { continue }
                        let cw = size.width / CGFloat(grid.cols), ch = size.height / CGFloat(grid.rows)
                        let cell = CGRect(x: CGFloat(k.cell.x) * cw, y: CGFloat(k.cell.y) * ch, width: cw, height: ch)
                        let center = CGPoint(x: k.origin.x * size.width, y: k.origin.y * size.height)
                        let r = hypot(cw, ch) * CGFloat(p) * 1.6
                        var inner = layer
                        inner.clip(to: Path(cell))
                        inner.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                                   with: .radialGradient(Gradient(colors: [.black, .black, .black.opacity(0)]), center: center, startRadius: 0, endRadius: max(r, 1)))
                    }
                }
                var hatch = Path()
                for n in mask.pendingRects {
                    let c = CGRect(x: n.minX * size.width, y: n.minY * size.height, width: n.width * size.width, height: n.height * size.height)
                    var x = c.minX - c.height
                    while x < c.maxX {
                        hatch.move(to: CGPoint(x: x, y: c.maxY)); hatch.addLine(to: CGPoint(x: x + c.height, y: c.minY)); x += 6
                    }
                }
                var clipped = ctx
                var clip = Path(); for n in mask.pendingRects {
                    clip.addRect(CGRect(x: n.minX * size.width, y: n.minY * size.height, width: n.width * size.width, height: n.height * size.height))
                }
                clipped.clip(to: clip)
                clipped.stroke(hatch, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("roam.fog.layer")
    }
}
