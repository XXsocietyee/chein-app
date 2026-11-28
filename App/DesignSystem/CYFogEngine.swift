import SwiftUI

// Fog-of-war presentation pieces (spec: /Users/fanning/chengyin-refs/specs/roam-fog-engine.md, stages 2 and 3).
// The mask and the overlay layer now live in App/FogOverlayLayer.swift (Core `FogMask`); `RevealChoreographer` adapts
// Core reveal events onto `CYRevealChoreographer` below, and `CYFogCoverageReading` is the badge's view-side reading
// (`CYFogCoverageReading(_ core:)` maps Core `FogCoverageReading`).

// MARK: - Data

/// Opaque slot key for one in-flight cell (`RevealChoreographer` maps it back to a Core `FogRenderCell`).
struct CYFogPoint: Hashable { let x: Int; let y: Int }

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
            Text("roam.fog.coverage.explored").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: reading.percentText).cyText(.bodyMedium).monospacedDigit().foregroundStyle(CYColor.textPrimary)
            if reading.pending > 0 {
                Text(verbatim: "·").foregroundStyle(CYColor.textTertiary)
                Text("roam.fog.coverage.unconfirmed \(reading.pending)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .padding(.horizontal, CYSpacing.md).frame(minHeight: 36)
        .background(.regularMaterial, in: Capsule(style: .continuous))
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
