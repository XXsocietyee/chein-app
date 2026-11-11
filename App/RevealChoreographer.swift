import SwiftUI

/// Roam fog spec stage 3 (§1c). Adapts `FogRevealEvent` (Core cells) onto the existing `CYRevealChoreographer`, so the
/// timing constants, the 150 ms haptic throttle, the first-reveal `.success` and the Reduce Motion crossfade counter
/// have one implementation. Injected clock and flags: no timers, no location, no network.
///
/// Flow: `enqueue` returns the cells that bake into the mask at once (everything under Reduce Motion or Low Power, the
/// overflow past 6 otherwise); the others wipe, and `settle` returns them when their wipe ends.
@MainActor @Observable final class RevealChoreographer {
    /// One in-flight wipe in Core terms; the host maps `cell` and `origin` to screen points.
    struct Wipe: Equatable {
        let cell: FogRenderCell
        let origin: RoamCoordinate
        let start: TimeInterval
        let duration: TimeInterval
    }

    private var inner = CYRevealChoreographer()
    private var slots: [CYFogPoint: (cell: FogRenderCell, origin: RoamCoordinate)] = [:]
    private var nextSlot = 0
    private let reduceMotion: () -> Bool
    private let lowPower: () -> Bool
    private let clock: () -> TimeInterval

    init(reduceMotion: @escaping () -> Bool, lowPower: @escaping () -> Bool = { false },
         clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.reduceMotion = reduceMotion; self.lowPower = lowPower; self.clock = clock
    }

    private(set) var wipes: [Wipe] = []
    var hapticSuccessSerial: Int { inner.successSerial }
    var hapticLightSerial: Int { inner.lightSerial }
    /// Bumps once per reveal event that skipped the wipe; the host animates the mask opacity over 200 ms on it.
    var crossfadeRevision: Int { inner.crossfadeRevision }
    static let crossfadeDuration: TimeInterval = 0.2

    @discardableResult
    func enqueue(_ event: FogRevealEvent) -> [FogRenderCell] {
        guard !event.cells.isEmpty else { return [] }
        var points: [CYFogPoint] = []
        for cell in event.cells {
            let point = CYFogPoint(x: nextSlot, y: 0)
            nextSlot += 1
            slots[point] = (cell, event.origin)
            points.append(point)
        }
        let baked = inner.enqueue(points, origin: .zero, now: clock(), reduceMotion: reduceMotion(), lowPower: lowPower())
        let cells = baked.compactMap { slots.removeValue(forKey: $0)?.cell }
        refresh()
        return cells
    }

    /// Cells whose wipe finished by `time` (default: now); the host unions them into the confirmed or pending bitmap.
    func settle(at time: TimeInterval? = nil) -> [FogRenderCell] {
        let now = time ?? clock()
        let done = inner.settle(at: now)
        let cells = done.compactMap { slots.removeValue(forKey: $0)?.cell }
        refresh()
        return cells
    }

    /// 0...1 ease-out progress of a wipe (0 before its staggered start).
    static func progress(start: TimeInterval, duration: TimeInterval, at now: TimeInterval) -> Double {
        CYRevealChoreographer.progress(.init(cell: CYFogPoint(x: 0, y: 0), origin: .zero, start: start, duration: duration), at: now)
    }

    private func refresh() {
        wipes = inner.active.compactMap { key in
            slots[key.cell].map { Wipe(cell: $0.cell, origin: $0.origin, start: key.start, duration: key.duration) }
        }
    }
}
