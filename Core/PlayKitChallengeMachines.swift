import Foundation

/// Device measurements are evidence for the server, never a completion or reward.
/// Monotonic time cannot be changed by adjusting the device wall clock.
public struct PlayKitTimingRun: Equatable {
    public enum Phase: String { case idle, running, measured, interrupted }
    public private(set) var phase = Phase.idle
    public private(set) var elapsedMilliseconds = 0
    private var startedAt: TimeInterval?
    public init() {}
    public mutating func beginAfterAcknowledgement(now: TimeInterval) {
        guard now.isFinite, now >= 0 else { return }
        startedAt = now; elapsedMilliseconds = 0; pausedElapsed = nil; phase = .running
    }
    /// MP playkit-stopwatch 暂停 / 继续 (`onPause`): the clock holds its reading while paused and resumes from it.
    /// A paused run stays `.running` (backgrounding still interrupts it) but cannot be measured (MP: 暂停中不接受停).
    public private(set) var pausedElapsed: Int?
    public var isPaused: Bool { phase == .running && pausedElapsed != nil }
    public mutating func pause(now: TimeInterval) {
        guard phase == .running, pausedElapsed == nil, startedAt != nil, now.isFinite else { return }
        pausedElapsed = elapsed(now: now)
    }
    public mutating func resume(now: TimeInterval) {
        guard phase == .running, let held = pausedElapsed, now.isFinite, now >= 0 else { return }
        startedAt = now - Double(held) / 1000; pausedElapsed = nil
    }
    public func elapsed(now: TimeInterval) -> Int {
        if phase == .running, let pausedElapsed { return pausedElapsed }
        guard phase == .running, let startedAt, now.isFinite, now >= startedAt else { return elapsedMilliseconds }
        return Int(min(3_600_000, ((now - startedAt) * 1000).rounded(.down)))
    }
    public mutating func measure(now: TimeInterval) {
        guard phase == .running, pausedElapsed == nil, let startedAt, now.isFinite, now >= startedAt else { return }
        elapsedMilliseconds = elapsed(now: now); self.startedAt = nil; phase = .measured
    }
    public mutating func interrupt() { if phase == .running { startedAt = nil; elapsedMilliseconds = 0; pausedElapsed = nil; phase = .interrupted } }
}

public struct PlayKitReactionRun: Equatable {
    public enum Phase: String { case idle, waiting, signal, early, betweenRounds, measured, interrupted }
    public private(set) var phase = Phase.idle
    public private(set) var roundsMilliseconds: [Int] = []
    public let rounds: Int
    private var waitUntil: TimeInterval?
    private var signalAt: TimeInterval?
    public init(rounds: Int) { self.rounds = min(100, max(1, rounds)) }
    public mutating func beginAfterAcknowledgement(now: TimeInterval, randomUnit: Double) {
        roundsMilliseconds = []; phase = .idle; arm(now: now, randomUnit: randomUnit)
    }
    public mutating func arm(now: TimeInterval, randomUnit: Double) {
        guard [.idle, .early, .betweenRounds].contains(phase), now.isFinite, randomUnit.isFinite else { return }
        waitUntil = now + (1.4 + min(1, max(0, randomUnit)) * 2.8); signalAt = nil; phase = .waiting
    }
    public mutating func tick(now: TimeInterval) {
        guard phase == .waiting, let waitUntil, now.isFinite, now >= waitUntil else { return }
        // The response starts when the cue is actually presented, not a missed timer deadline.
        signalAt = now; self.waitUntil = nil; phase = .signal
    }
    public mutating func tap(now: TimeInterval) {
        if phase == .waiting { waitUntil = nil; phase = .early; return }
        guard phase == .signal, let signalAt, now.isFinite, now >= signalAt else { return }
        let ms = Int(min(60_001, ((now - signalAt) * 1000).rounded(.down)))
        self.signalAt = nil
        guard ms >= 120, ms <= 60_000 else { phase = .early; return }
        roundsMilliseconds.append(ms); phase = roundsMilliseconds.count >= rounds ? .measured : .betweenRounds
    }
    public mutating func interrupt() {
        guard phase != .measured else { return }
        waitUntil = nil; signalAt = nil; roundsMilliseconds = []; phase = .interrupted
    }
}

public enum PlayKitSensorKind: String, CaseIterable { case acceleration, soundPeak, heading }
public enum PlayKitSensorSample: Equatable {
    /// Acceleration is m/s²; native CoreMotion g values must be converted once.
    case acceleration(x: Double, y: Double, z: Double, timestamp: TimeInterval)
    /// Peak linear amplitude in 0...1. No audio bytes are retained or uploaded.
    case soundPeak(Double, timestamp: TimeInterval)
    case heading(Double, accuracy: Double, timestamp: TimeInterval)
}
@MainActor public protocol PlayKitSensorProviding: AnyObject {
    var supported: Set<PlayKitSensorKind> { get }
    func samples(_ kind: PlayKitSensorKind) -> AsyncThrowingStream<PlayKitSensorSample, Error>
    func cancel()
}
@MainActor public final class PlayKitDormantSensorProvider: PlayKitSensorProviding {
    public let supported: Set<PlayKitSensorKind> = []
    public init() {}
    public func samples(_ kind: PlayKitSensorKind) -> AsyncThrowingStream<PlayKitSensorSample, Error> {
        AsyncThrowingStream { $0.finish(throwing: PlayExperienceError.disabled) }
    }
    public func cancel() {}
}

/// Calibration requires real samples. Empty/missing streams never become silent success.
public struct PlayKitQuietRun: Equatable {
    public enum Phase: String { case idle, calibrating, ready, running, measured, interrupted }
    public private(set) var phase = Phase.idle
    public private(set) var level: Double = 0
    public private(set) var warningThreshold: Double = 0.12
    public private(set) var stopThreshold: Double = 0.21
    public private(set) var heldSeconds: Double = 0
    public private(set) var exceeded = false
    public let targetSeconds: Double
    private var calibration: [Double] = []
    private var firstSampleAt: TimeInterval?
    private var lastSampleAt: TimeInterval?
    public init(seconds: Double) { targetSeconds = min(3600, max(1, seconds.isFinite ? seconds : 15)) }
    public mutating func calibrate() { phase = .calibrating; calibration = []; firstSampleAt = nil; lastSampleAt = nil; heldSeconds = 0; exceeded = false }
    public mutating func beginAfterAcknowledgement() { guard phase == .ready else { return }; phase = .running; lastSampleAt = nil; heldSeconds = 0 }
    public mutating func ingest(peak: Double, timestamp: TimeInterval) {
        guard [.calibrating, .running].contains(phase), peak.isFinite, (0...1).contains(peak), timestamp.isFinite, timestamp >= 0 else { return }
        if let lastSampleAt, timestamp <= lastSampleAt { return }
        let previous = lastSampleAt; lastSampleAt = timestamp; level = peak
        if phase == .calibrating {
            if let previous, timestamp - previous > 0.25 { calibration = []; firstSampleAt = nil }
            if firstSampleAt == nil { firstSampleAt = timestamp }
            calibration.append(peak)
            if let firstSampleAt, timestamp - firstSampleAt >= 2, calibration.count >= 10 {
                let sorted = calibration.sorted(), index = min(sorted.count - 1, Int(Double(sorted.count) * 0.8))
                warningThreshold = min(0.5, max(0.12, sorted[index] + 0.06)); stopThreshold = min(0.72, warningThreshold + 0.09)
                phase = .ready; calibration = []
            }
            return
        }
        if peak > stopThreshold { exceeded = true; phase = .measured; return }
        guard let previous else { return }
        guard timestamp - previous <= 0.25 else { interrupt(); return }
        heldSeconds = min(targetSeconds, heldSeconds + min(0.1, timestamp - previous))
        if heldSeconds >= targetSeconds { phase = .measured }
    }
    public mutating func interrupt() { if phase != .measured { phase = .interrupted; calibration = []; firstSampleAt = nil; lastSampleAt = nil; heldSeconds = 0 } }
}

/// Physical board state. The player tilts the device; wall contacts are measured,
/// while passed/submitted remain server-owned. Source board uses 0.05 m/s² tilt scale.
public struct PlayKitBallRun: Equatable {
    public enum Phase: String { case idle, calibrating, ready, running, measured, interrupted }
    public private(set) var phase = Phase.idle
    public private(set) var x = 150.0, y = 210.0
    public private(set) var hits = 0
    public private(set) var elapsedSeconds = 0.0
    public let goal: Int; public let limitSeconds: Double
    private var zeroX = 0.0, zeroY = 0.0, vx = 0.0, vy = 0.0
    private var samples: [(Double, Double)] = []
    private var firstAt: TimeInterval?, lastAt: TimeInterval?, runAt: TimeInterval?
    public init(goal: Int, limitSeconds: Double) { self.goal = min(100_000, max(1, goal)); self.limitSeconds = min(3600, max(0, limitSeconds.isFinite ? limitSeconds : 0)) }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.phase == rhs.phase && lhs.x == rhs.x && lhs.y == rhs.y && lhs.hits == rhs.hits && lhs.elapsedSeconds == rhs.elapsedSeconds && lhs.goal == rhs.goal && lhs.limitSeconds == rhs.limitSeconds
    }
    public mutating func calibrate() { phase = .calibrating; samples = []; firstAt = nil; lastAt = nil; hits = 0; x = 150; y = 210; vx = 0; vy = 0 }
    public mutating func beginAfterAcknowledgement() { guard phase == .ready else { return }; phase = .running; lastAt = nil; runAt = nil; elapsedSeconds = 0 }
    public mutating func ingest(x ax: Double, y ay: Double, timestamp: TimeInterval, randomUnit: Double) {
        guard [.calibrating, .running].contains(phase), [ax, ay, timestamp, randomUnit].allSatisfy(\.isFinite), timestamp >= 0 else { return }
        if let lastAt, timestamp <= lastAt { return }
        let previous = lastAt; lastAt = timestamp
        if phase == .calibrating {
            if let previous, timestamp - previous > 0.25 { samples = []; firstAt = nil }
            if firstAt == nil { firstAt = timestamp }
            samples.append((ax, ay))
            if let firstAt, timestamp - firstAt >= 1.2, samples.count >= 10 {
                zeroX = samples.map { $0.0 }.reduce(0,+) / Double(samples.count)
                zeroY = samples.map { $0.1 }.reduce(0,+) / Double(samples.count); samples = []; phase = .ready
            }
            return
        }
        if runAt == nil { runAt = timestamp }
        guard let previous, let runAt else { return }
        guard timestamp - previous <= 0.25 else { interrupt(); return }
        elapsedSeconds = timestamp - runAt
        let frames = min(3, (timestamp - previous) / 0.016)
        vx = (vx - (ax - zeroX) * 0.05 * frames) * pow(0.999, frames)
        vy = (vy + (ay - zeroY) * 0.05 * frames) * pow(0.999, frames)
        x += vx * frames; y += vy * frames
        let jitter = (min(1, max(0, randomUnit)) - 0.5) * 0.5
        if x < 13 || x > 287 { x = min(287, max(13, x)); vx = -vx * 0.98 + jitter; hits += 1 }
        if y < 13 || y > 407 { y = min(407, max(13, y)); vy = -vy * 0.98 - jitter; hits += 1 }
        if hits >= goal || (limitSeconds > 0 && elapsedSeconds >= limitSeconds) { phase = .measured }
    }
    public mutating func interrupt() { if phase != .measured { phase = .interrupted; samples = []; firstAt = nil; lastAt = nil; runAt = nil; hits = 0 } }
}

/// Read model for `pages/play/poi-challenge/index` (`PlayKitTimedChallengeView`).
/// A missing advanced grant or either live route keeps the page hidden.
/// Unknown, null, and non-numeric fields stay an em dash. A literal 0 stays 0.
/// This type does not send, invent a route, or enable a write.
public struct PlayKitTimedChallengePage: Equatable {
    public enum Phase: String, Equatable {
        case loading, empty, error, unknown, ready
    }
    public enum Fact: Equatable {
        case unknown
        case value(Double)
        public static let unknownDisplay = "—"
        public var literal: Double? {
            if case .value(let number) = self { return number }
            return nil
        }
        public var displayText: String {
            switch self {
            case .unknown:
                return Self.unknownDisplay
            case .value(let number):
                guard number.isFinite else { return Self.unknownDisplay }
                if number == 0 { return "0" }
                let whole = number.rounded(.towardZero)
                if whole == number, abs(number) <= Double(Int.max) { return String(Int(number)) }
                return String(number)
            }
        }
    }
    public enum TextFact: Equatable {
        case unknown
        case value(String)
        public var displayText: String {
            switch self {
            case .unknown: return Fact.unknownDisplay
            case .value(let text): return text
            }
        }
    }
    public struct Readout: Equatable {
        public let accessibilityIdentifier: String
        public let copyKey: String
        public let number: Fact
        public var displayText: String { number.displayText }
    }
    public struct TextReadout: Equatable {
        public let accessibilityIdentifier: String
        public let copyKey: String
        public let text: TextFact
        public var displayText: String { text.displayText }
    }

    public static let readPath = "/api/play/advanced/state"
    public static let actionPath = "/api/play/advanced/action"
    public static let kinds: [PlayKitScreenKind] = [.reaction, .countdown, .stopwatch, .typeIn]
    /// City-node completion stays hidden while the existing write gate is closed.
    public static var cityNodeCompleteOffered: Bool {
        PlayWriteAvailability.current(for: .challengeSubmit).isAvailable
    }

    public let kind: PlayKitScreenKind
    public let hidden: Bool
    public let phase: Phase?
    public let targetSeconds: Fact
    public let toleranceMilliseconds: Fact
    public let rounds: Fact
    public let goalMilliseconds: Fact
    public let attempts: Fact
    public let attemptLimit: Fact
    public let readouts: [Readout]
    public let typeInTarget: TextReadout?
    public let configurationValid: Bool
    public let startReviewAllowed: Bool
    public let offeredPaths: [String]

    public var copyKey: String? {
        guard !hidden, let phase else { return nil }
        return "playkit.timed." + phase.rawValue
    }
    public var accessibilityIdentifier: String? { copyKey }

    public static func number(_ value: PlayWireValue) -> Fact {
        switch value {
        case .integer(let raw):
            guard let exact = Int(exactly: raw) else { return .unknown }
            return .value(Double(exact))
        case .number(let raw):
            guard raw.isFinite else { return .unknown }
            return .value(raw)
        case .string, .bool, .array, .object, .null:
            return .unknown
        }
    }
    public static func text(_ value: PlayWireValue) -> TextFact {
        if case .string(let raw) = value { return .value(raw) }
        return .unknown
    }

    public static func project(kind: PlayKitScreenKind, playKit: PlayWireValue?, coordinatorPhase: String,
        advancedEnabled: Bool, configuration: RegionalConfiguration) -> Self {
        project(kind: kind, playKit: playKit, coordinatorPhase: coordinatorPhase, advancedEnabled: advancedEnabled,
            showsReadRoute: configuration.showsRoute(readPath), showsActionRoute: configuration.showsRoute(actionPath))
    }

    public static func project(kind: PlayKitScreenKind, playKit: PlayWireValue?, coordinatorPhase: String,
        advancedEnabled: Bool, showsReadRoute: Bool, showsActionRoute: Bool) -> Self {
        let revealed = kinds.contains(kind) && advancedEnabled && showsReadRoute && showsActionRoute
        guard revealed else { return hidden(kind) }
        let phase = resolve(kind: kind, playKit: playKit, coordinatorPhase: coordinatorPhase)
        guard phase == .ready, let segment = playKit?[kind.rawValue], segment.object != nil else {
            return presented(kind: kind, phase: phase, segment: nil, showsReadRoute: showsReadRoute, showsActionRoute: showsActionRoute)
        }
        return presented(kind: kind, phase: phase, segment: segment, showsReadRoute: showsReadRoute, showsActionRoute: showsActionRoute)
    }

    public func acknowledgedStartPayload() throws -> [String: PlayWireValue] {
        guard startReviewAllowed else { throw PlayExperienceError.disabled }
        return try PlayKitActionCatalog.payload(kind: kind.rawValue, action: "START_CHALLENGE", detail: ["game": .string(kind.rawValue)])
    }

    private static func resolve(kind: PlayKitScreenKind, playKit: PlayWireValue?, coordinatorPhase: String) -> Phase {
        switch coordinatorPhase {
        case "idle", "loading":
            return .loading
        case "submitting":
            return playKit?[kind.rawValue].object == nil ? .loading : .ready
        case "rejected", "disabled", "stale":
            return .error
        case "unknown", "retryable":
            return .unknown
        case "ready":
            guard let playKit else { return .empty }
            guard playKit.object != nil else { return playKit == .null ? .empty : .unknown }
            let segment = playKit[kind.rawValue]
            if segment.object != nil { return .ready }
            if case .null = segment { return .empty }
            return .unknown
        default:
            return .unknown
        }
    }

    private static func hidden(_ kind: PlayKitScreenKind) -> Self {
        Self(kind: kind, hidden: true, phase: nil, targetSeconds: .unknown, toleranceMilliseconds: .unknown,
            rounds: .unknown, goalMilliseconds: .unknown, attempts: .unknown, attemptLimit: .unknown,
            readouts: [], typeInTarget: nil, configurationValid: false, startReviewAllowed: false, offeredPaths: [])
    }

    private static func presented(kind: PlayKitScreenKind, phase: Phase, segment: PlayWireValue?,
        showsReadRoute: Bool, showsActionRoute: Bool) -> Self {
        let source = segment ?? .null
        let targetKey = kind == .stopwatch ? "targetSeconds" : "seconds"
        let target = phase == .ready ? number(source[targetKey]) : Fact.unknown
        let tolerance = phase == .ready && kind == .stopwatch ? number(source["toleranceMs"]) : Fact.unknown
        let rounds = phase == .ready && kind == .reaction ? number(source["rounds"]) : Fact.unknown
        let goal = phase == .ready && kind == .reaction ? number(source["goalMs"]) : Fact.unknown
        let attempts = phase == .ready && kind == .typeIn ? number(source["attempts"]) : Fact.unknown
        let limit = phase == .ready && kind == .typeIn ? number(source["tries"]) : Fact.unknown
        var readouts: [Readout] = []
        if phase == .ready {
            switch kind {
            case .countdown:
                readouts = [Readout(accessibilityIdentifier: "playkit.timed.target", copyKey: "playkit.challenge.target", number: target)]
            case .stopwatch:
                readouts = [
                    Readout(accessibilityIdentifier: "playkit.timed.target", copyKey: "playkit.challenge.target", number: target),
                    Readout(accessibilityIdentifier: "playkit.timed.tolerance", copyKey: "playkit.stopwatch.tolerance", number: tolerance)
                ]
            case .reaction:
                readouts = [
                    Readout(accessibilityIdentifier: "playkit.timed.rounds", copyKey: "playkit.reaction.round", number: rounds),
                    Readout(accessibilityIdentifier: "playkit.timed.goal", copyKey: "playkit.reaction.goal", number: goal)
                ]
            case .typeIn:
                readouts = [
                    Readout(accessibilityIdentifier: "playkit.timed.target", copyKey: "playkit.challenge.target", number: target),
                    Readout(accessibilityIdentifier: "playkit.timed.attempts", copyKey: "playkit.attempts", number: attempts),
                    Readout(accessibilityIdentifier: "playkit.timed.attemptLimit", copyKey: "playkit.attemptLimit", number: limit)
                ]
            default:
                readouts = []
            }
        }
        let typeTarget: TextReadout? = phase == .ready && kind == .typeIn
            ? TextReadout(accessibilityIdentifier: "playkit.timed.typeTarget", copyKey: "playkit.type.input", text: text(source["target"]))
            : nil
        let valid = configurationValid(kind: kind, phase: phase, target: target, typeTarget: typeTarget?.text)
        let start = phase == .ready && valid && PlayKitActionCatalog.actions[kind.rawValue]?.contains("START_CHALLENGE") == true
        var paths: [String] = []
        if showsReadRoute { paths.append(readPath) }
        if showsActionRoute { paths.append(actionPath) }
        return Self(kind: kind, hidden: false, phase: phase, targetSeconds: target, toleranceMilliseconds: tolerance,
            rounds: rounds, goalMilliseconds: goal, attempts: attempts, attemptLimit: limit, readouts: readouts,
            typeInTarget: typeTarget, configurationValid: valid, startReviewAllowed: start, offeredPaths: paths)
    }

    private static func configurationValid(kind: PlayKitScreenKind, phase: Phase, target: Fact, typeTarget: TextFact?) -> Bool {
        guard phase == .ready else { return false }
        switch kind {
        case .reaction:
            return true
        case .countdown, .stopwatch:
            guard case .value(let seconds) = target, seconds.isFinite, seconds > 0, seconds <= 3600 else { return false }
            return true
        case .typeIn:
            guard case .value(let seconds) = target, seconds.isFinite, (0...3600).contains(seconds) else { return false }
            guard let prompt = typeTarget, case .value(let text) = prompt else { return false }
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }
}

#if DEBUG
/// Synthetic timed-challenge documents. Debug builds only. No account, route, or secret.
public enum PlayKitTimedChallengeFixtureData {
    public static let countdownSegment = #"{"seconds":30,"submitted":false}"#
    public static let stopwatchSegment = #"{"targetSeconds":10,"toleranceMs":50,"submitted":false}"#
    public static let reactionSegment = #"{"rounds":5,"goalMs":400,"submitted":false}"#
    public static let typeInSegment = #"{"seconds":20,"target":"synthetic phrase","attempts":0,"tries":3,"submitted":false,"passed":false}"#
    public static let unknownSegment = #"{"seconds":"UNKNOWN","targetSeconds":null,"toleranceMs":"UNKNOWN","rounds":"UNKNOWN","goalMs":null,"attempts":"UNKNOWN","tries":null,"target":null}"#
    public static let literalZeroSegment = #"{"seconds":0,"targetSeconds":0,"toleranceMs":0,"rounds":0,"goalMs":0,"attempts":0,"tries":0,"target":""}"#
    public static func stateJSON(kind: String, segment: String) -> String {
        "{\"sessionId\":601,\"activityId\":41,\"topicId\":71,\"nodeId\":701,\"version\":2,\"status\":\"RUNNING\",\"readyForBase\":false,\"present\":\"inline\",\"config\":{},\"playKit\":{\"" + kind + "\":" + segment + "}}"
    }
    public static var countdownState: String { stateJSON(kind: "countdown", segment: countdownSegment) }
    public static var emptyState: String { "{\"sessionId\":601,\"activityId\":41,\"topicId\":71,\"nodeId\":701,\"version\":2,\"status\":\"RUNNING\",\"readyForBase\":false,\"present\":\"inline\",\"config\":{},\"playKit\":{}}" }
    public static func wire(_ json: String) throws -> PlayWireValue {
        try JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8))
    }
    public static func state(_ json: String) throws -> PlayAdvancedState {
        try PlayAdvancedState(wire(json))
    }
}
#endif
