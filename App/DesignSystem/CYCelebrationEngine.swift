import CoreGraphics
import Foundation

// Celebration queue engine (e4). Spec: docs/release/motion-spec-celebration.md.
// A pure value-type state machine: no SwiftUI, no timers, no haptic generators. Callers feed it actions with a
// monotonic `now` and run the effects it returns, so ordering, haptic spacing and Reduce Motion fallbacks are
// testable without a screen. `CYCelebrationCenter` (CYCelebrationViews.swift) is the thin runtime that drives it.

// MARK: - Unknown values

/// Unknown is a dash, never 0. A real zero must come in as `0`, an absent or invalid value as `nil`.
enum CYUnknown {
    static let dash = "—"

    static func count(_ value: Int?) -> String {
        guard let value, value >= 0 else { return dash }
        return String(value)
    }

    static func decimal(_ value: Double?, fractionDigits: Int = 1) -> String {
        guard let value, value.isFinite, value >= 0 else { return dash }
        return value.formatted(.number.precision(.fractionLength(max(0, fractionDigits))))
    }

    static func text(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? dash : trimmed
    }
}

// MARK: - Payloads

struct CYStampPayload: Equatable, Sendable {
    /// Stable id of the stamp (used to dedupe a re-delivered success).
    var id: String
    var symbol: String = "mappin.and.ellipse"
    /// Place name; nil renders as a dash, never a placeholder name.
    var place: String?
    /// Stamps in the passport after this one; nil = unknown (an em dash), never 0.
    var passportCount: Int?
}

struct CYBadgePayload: Equatable, Sendable {
    var id: String
    var name: String
    var symbol: String?
}

struct CYRoamSummaryPayload: Equatable, Sendable {
    var id: String
    /// nil = unknown (shown as a dash). A walk that really covered 0 passes 0.
    var kilometers: Double?
    var tiles: Int?
    var stamps: Int?
    /// Normalised route polyline (0...1, y down, see `CYShareCardContent.silhouette`). Empty = no route known: nothing is drawn.
    var route: [CGPoint] = []
}

enum CYCelebrationKind: Int, Equatable, Comparable, Sendable {
    // Raw value is the queue priority: a stamp finishes before a badge shows, a badge before the summary.
    case stamp = 0, badge = 1, roamSummary = 2
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum CYCelebrationPayload: Equatable, Sendable {
    case stamp(CYStampPayload)
    case badge(CYBadgePayload)
    case roamSummary(CYRoamSummaryPayload)

    var kind: CYCelebrationKind {
        switch self {
        case .stamp: .stamp
        case .badge: .badge
        case .roamSummary: .roamSummary
        }
    }

    /// Dedupe key: the same unlock delivered twice plays once per session.
    var key: String {
        switch self {
        case .stamp(let p): "stamp:\(p.id)"
        case .badge(let p): "badge:\(p.id)"
        case .roamSummary(let p): "roam:\(p.id)"
        }
    }
}

struct CYCelebrationEvent: Equatable, Identifiable, Sendable {
    let id: Int
    let payload: CYCelebrationPayload
    var kind: CYCelebrationKind { payload.kind }
}

// MARK: - Timeline

/// One haptic cue on a celebration's timeline, `offset` seconds after the celebration is presented.
struct CYHapticCue: Equatable, Sendable {
    var offset: TimeInterval
    var haptic: CYHaptics
}

/// The per-kind motion budget. Every duration is on the CYMotion grid or the spec table; nothing else is allowed.
struct CYCelebrationTimeline: Equatable, Sendable {
    var cues: [CYHapticCue]
    /// nil = stays until the person dismisses it (badge cover, summary sheet).
    var autoDismissAfter: TimeInterval?

    /// `assistive` (VoiceOver on) gives the auto-dismissing stamp time to be read: 4 s instead of 1.8 s.
    static func make(for kind: CYCelebrationKind, reduceMotion: Bool, assistive: Bool = false) -> CYCelebrationTimeline {
        switch (kind, reduceMotion) {
        // Reduce Motion: cross-fade in, one `.success`, no landing impact.
        case (.stamp, true):
            return .init(cues: [.init(offset: 0, haptic: .success)], autoDismissAfter: assistive ? 4 : 2.0)
        case (.badge, true), (.roamSummary, true):
            return .init(cues: [.init(offset: 0, haptic: .success)], autoDismissAfter: nil)
        // Wave 3 5A: seal drops at 120 ms (impactHeavy), `.success` at 250 ms (the 150 ms spacing rule logs it at ~270 ms).
        case (.stamp, false):
            return .init(cues: [.init(offset: 0.12, haptic: .impactHeavy), .init(offset: 0.25, haptic: .success)], autoDismissAfter: assistive ? 4 : 2.4)
        // Wave 3 5B: medal lands on the bloom overshoot at 450 ms (impactMedium), `.success` when the stars arrive at 1000 ms.
        case (.badge, false):
            return .init(cues: [.init(offset: 0.45, haptic: .impactMedium), .init(offset: 1.0, haptic: .success)], autoDismissAfter: nil)
        // `.success` once, after the three staggered numbers (3 x 50 ms) have rolled (0.60 s).
        case (.roamSummary, false):
            return .init(cues: [.init(offset: 0.80, haptic: .success)], autoDismissAfter: nil)
        }
    }
}

// MARK: - State machine

enum CYCelebrationAction: Equatable, Sendable {
    case enqueue(CYCelebrationPayload)
    case setReduceMotion(Bool)
    case setAssistive(Bool)
    /// Person dismissed the active celebration (button, swipe, tap).
    case dismiss
    /// Stop the active celebration's auto-dismiss (a share sheet is open on top of it); a tap still dismisses.
    case hold
    /// The clock reached `deadline`; drives auto-dismiss and the next item.
    case tick
}

enum CYCelebrationEffect: Equatable, Sendable {
    case present(CYCelebrationEvent)
    /// Play at the absolute time `at` (same clock as `now`). Never closer than `CYCelebrationState.minimumHapticInterval`.
    case haptic(CYHaptics, at: TimeInterval)
    /// Post a VoiceOver announcement for this event.
    case announce(CYCelebrationEvent)
    case dismiss(CYCelebrationEvent)
}

struct CYCelebrationState: Equatable, Sendable {
    /// Haptics are never closer than this (the generators coalesce anything tighter into one buzz).
    static let minimumHapticInterval: TimeInterval = 0.15
    /// Breathing room between one celebration leaving and the next arriving.
    static let gapBetween: TimeInterval = 0.45

    struct Active: Equatable, Sendable {
        var event: CYCelebrationEvent
        var presentedAt: TimeInterval
        var autoDismissAt: TimeInterval?
    }

    private(set) var pending: [CYCelebrationEvent] = []
    private(set) var active: Active?
    private(set) var reduceMotion = false
    private(set) var assistive = false
    /// Earliest time the next celebration may be presented (set when one leaves).
    private(set) var nextPresentAt: TimeInterval = 0
    private var nextID = 1
    private var seen: Set<String> = []
    /// Absolute time of the last haptic handed out; the next one is pushed to at least this + the interval.
    private var lastHapticAt: TimeInterval?

    init() {}

    var current: CYCelebrationEvent? { active?.event }

    /// The next moment the runtime must call `.tick`, or nil if nothing is waiting on the clock.
    var nextDeadline: TimeInterval? {
        if let active { return active.autoDismissAt }
        return pending.isEmpty ? nil : nextPresentAt
    }

    @discardableResult
    mutating func reduce(_ action: CYCelebrationAction, now: TimeInterval) -> [CYCelebrationEffect] {
        var effects: [CYCelebrationEffect] = []
        switch action {
        case .setReduceMotion(let value):
            reduceMotion = value
        case .setAssistive(let value):
            assistive = value
        case .enqueue(let payload):
            guard seen.insert(payload.key).inserted else { return [] }
            insert(CYCelebrationEvent(id: nextID, payload: payload))
            nextID += 1
        case .dismiss:
            leave(now: now, into: &effects)
        case .hold:
            if active != nil { active?.autoDismissAt = nil }
        case .tick:
            if let active, let deadline = active.autoDismissAt, now >= deadline { leave(now: now, into: &effects) }
        }
        presentIfPossible(now: now, into: &effects)
        return effects
    }

    // Lower kind first, then arrival order.
    private mutating func insert(_ event: CYCelebrationEvent) {
        let index = pending.firstIndex { $0.kind > event.kind } ?? pending.endIndex
        pending.insert(event, at: index)
    }

    private mutating func leave(now: TimeInterval, into effects: inout [CYCelebrationEffect]) {
        guard let active else { return }
        effects.append(.dismiss(active.event))
        self.active = nil
        nextPresentAt = now + Self.gapBetween
    }

    private mutating func presentIfPossible(now: TimeInterval, into effects: inout [CYCelebrationEffect]) {
        guard active == nil, now >= nextPresentAt, !pending.isEmpty else { return }
        let event = pending.removeFirst()
        let timeline = CYCelebrationTimeline.make(for: event.kind, reduceMotion: reduceMotion, assistive: assistive)
        active = Active(event: event, presentedAt: now, autoDismissAt: timeline.autoDismissAfter.map { now + $0 })
        effects.append(.present(event))
        effects.append(.announce(event))
        for cue in timeline.cues {
            var at = now + cue.offset
            if let last = lastHapticAt { at = max(at, last + Self.minimumHapticInterval) }
            lastHapticAt = at
            effects.append(.haptic(cue.haptic, at: at))
        }
    }
}
