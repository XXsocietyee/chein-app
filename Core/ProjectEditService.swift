import Foundation

public struct ProjectEditCapability: Equatable {
    public let canProPublish: Bool
    public let remaining: Int?
    public init(canProPublish: Bool, remaining: Int?) { self.canProPublish = canProPublish; self.remaining = remaining }
    public var allowsCreate: Bool { canProPublish && (remaining.map { $0 > 0 } ?? true) }
}
#if DEBUG
public enum ProjectEditServiceAuthority { case disabled, readOnly, approved, synthetic }
#else
public enum ProjectEditServiceAuthority { case disabled, readOnly, approved }
#endif
public struct ProjectEditPreflight: Equatable {
    public var capability: ProjectEditCapability
    public var snapshot: ProjectEditSnapshot?
    public init(capability: ProjectEditCapability, snapshot: ProjectEditSnapshot?) { self.capability = capability; self.snapshot = snapshot }
}
public enum ProjectEditWriteOutcome: Equatable {
    /// Fixture-only terminal receipt, kept separate from immediate HTTP acknowledgments.
    case simulatedReceipt(operationID: UUID, topicID: Int)
    /// Immediate server acknowledgment; not a later terminal receipt.
    case acknowledged(operationID: UUID, topicID: Int)
    /// Exact immediate V2 submission facts. PENDING + legacy published=true is not approval.
    case bundleAcknowledged(operationID: UUID, acknowledgment: ProjectEditBundleAcknowledgment)
    /// Same-transaction original writer fact, not a claim that review/publication/post-processing completed.
    case postProcessingReceipt(operationID: UUID, topicID: Int, bundle: ProjectEditBundleAcknowledgment?, receipt: ProjectEditPostProcessingReceipt)
    case committedReceipt(operationID: UUID, topicID: Int, bundle: ProjectEditBundleAcknowledgment?)
    case notSent, rejected, unknown
}
@MainActor public protocol ProjectEditServing: AnyObject {
    var authority: ProjectEditServiceAuthority { get }
    var supportsRequestReadback: Bool { get }
    var supportsRequestRetry: Bool { get }
    var supportsPostProcessingResume: Bool { get }
    func preflight(topicID: Int?, session: ProjectEditSession) async throws -> ProjectEditPreflight
    func submit(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome
    func terminalReceipt(operation: ProjectEditPending, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome?
    func resumePostProcessing(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome
    func retrySameRequest(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome
    func terminalReceipt(operationID: UUID, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome?
}
public extension ProjectEditServing {
    var supportsRequestReadback: Bool { false }
    var supportsRequestRetry: Bool { false }
    var supportsPostProcessingResume: Bool { false }
    func resumePostProcessing(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome { .unknown }
    func terminalReceipt(operation: ProjectEditPending, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome? {
        try await terminalReceipt(operationID: operation.operationID, session: session)
    }
    func retrySameRequest(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome { .unknown }
}
/// Default composition remains disabled. The separate HTTP adapter requires independently
/// scoped approval and a durable local lock; it never invents a reconciliation endpoint.
@MainActor public final class ProjectEditDisabledService: ProjectEditServing {
    public init() {}
    public var authority: ProjectEditServiceAuthority { .disabled }
    public func preflight(topicID: Int?, session: ProjectEditSession) async throws -> ProjectEditPreflight { throw ProjectEditError.notConfigured }
    public func submit(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome { .notSent }
    public func terminalReceipt(operationID: UUID, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome? { throw ProjectEditError.notConfigured }
}

/// Page model for `pages/publish/fabu/index` (专业主题编辑器).
///
/// Reads the permission and quota fields `PublishingCapability` and
/// `ProjectEditHTTPService.preflight` already decode. It does not register a
/// route, mark a route live, or open the player-first entry. A missing pro
/// capability stays hidden. Empty and unknown text is an em dash (U+2014).
/// A literal integer, including 0, stays that integer. A numeric string is unknown.
public enum PublishFabuPagePhase: String, Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready
}

public enum PublishFabuCoordinatorState: String, Equatable, Sendable, CaseIterable {
    case idle
    case loading
    case reviewing
    case submitting
    case simulated
    case acknowledged
    case unknown
    case rejected
    case notSent
    case blocked
}

extension PublishFabuCoordinatorState {
    /// Names match `ProjectEditCoordinator.State`. No new route is introduced.
    @MainActor init(matching state: ProjectEditCoordinator.State) {
        switch state {
        case .idle: self = .idle
        case .loading: self = .loading
        case .reviewing: self = .reviewing
        case .submitting: self = .submitting
        case .simulated: self = .simulated
        case .acknowledged: self = .acknowledged
        case .unknown: self = .unknown
        case .rejected: self = .rejected
        case .notSent: self = .notSent
        case .blocked: self = .blocked
        }
    }
}

public enum PublishFabuAccessibility {
    public static let loading = "projectEdit.fabu.loading"
    public static let empty = "projectEdit.fabu.empty"
    public static let error = "projectEdit.fabu.error"
    public static let unknown = "projectEdit.fabu.unknown"
    public static let ready = "projectEdit.fabu.ready"
    public static let hidden = "projectEdit.fabu.hidden"
    public static let quota = "projectEdit.fabu.quota"
    public static let chapters = "projectEdit.fabu.chapters"
}

public struct PublishFabuFieldState: Equatable, Sendable {
    public static let emptyText = "—"
    public static let unknownText = "—"

    public let phase: PublishFabuPagePhase
    public let text: String
    public let reason: String
    public let accessibilityIdentifier: String

    public init(phase: PublishFabuPagePhase, text: String, reason: String, accessibilityIdentifier: String) {
        self.phase = phase
        self.text = text
        self.reason = reason
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

public struct PublishFabuPageProjection: Equatable, Sendable {
    public static let miniPath = "pages/publish/fabu/index"
    public static let registersRoute = false
    public static let marksRouteLive = false
    public static let opensPlayerFirstEntry = false

    public let phase: PublishFabuPagePhase
    public let text: String
    public let reason: String
    public let visible: Bool
    public let accessibilityIdentifier: String
    public let quota: PublishFabuFieldState
    public let chapters: PublishFabuFieldState

    public init(phase: PublishFabuPagePhase, text: String, reason: String, visible: Bool, accessibilityIdentifier: String, quota: PublishFabuFieldState, chapters: PublishFabuFieldState) {
        self.phase = phase
        self.text = text
        self.reason = reason
        self.visible = visible
        self.accessibilityIdentifier = accessibilityIdentifier
        self.quota = quota
        self.chapters = chapters
    }
}

public enum PublishFabuPageModel {
    public static func project(coordinatorState: PublishFabuCoordinatorState, messageKey: String?, home: [String: ProjectEditJSON]?, chapterCount: Int?) -> PublishFabuPageProjection {
        switch coordinatorState {
        case .loading, .reviewing, .submitting:
            return loadingProjection()
        case .unknown, .notSent:
            return unknownProjection()
        case .blocked, .rejected:
            return failureProjection(messageKey, home: home)
        case .idle, .simulated, .acknowledged:
            return contentProjection(home: home, chapterCount: chapterCount)
        }
    }

    private static func loadingProjection() -> PublishFabuPageProjection {
        PublishFabuPageProjection(
            phase: .loading, text: "", reason: "loading", visible: false,
            accessibilityIdentifier: PublishFabuAccessibility.loading,
            quota: PublishFabuFieldState(phase: .loading, text: "", reason: "loading", accessibilityIdentifier: PublishFabuAccessibility.quota),
            chapters: PublishFabuFieldState(phase: .loading, text: "", reason: "loading", accessibilityIdentifier: PublishFabuAccessibility.chapters))
    }

    private static func unknownProjection() -> PublishFabuPageProjection {
        PublishFabuPageProjection(phase: .unknown, text: PublishFabuFieldState.unknownText, reason: "unknown", visible: false, accessibilityIdentifier: PublishFabuAccessibility.unknown, quota: unknownField(PublishFabuAccessibility.quota), chapters: unknownField(PublishFabuAccessibility.chapters))
    }

    private static func failureProjection(_ messageKey: String?, home: [String: ProjectEditJSON]?) -> PublishFabuPageProjection {
        guard explicitPro(home) else { return hiddenProjection() }
        let token = (messageKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if isUnknownToken(token) { return visibleUnknown() }
        return PublishFabuPageProjection(phase: .error, text: token, reason: "error", visible: true, accessibilityIdentifier: PublishFabuAccessibility.error, quota: unknownField(PublishFabuAccessibility.quota), chapters: unknownField(PublishFabuAccessibility.chapters))
    }

    private static func contentProjection(home: [String: ProjectEditJSON]?, chapterCount: Int?) -> PublishFabuPageProjection {
        guard explicitPro(home) else { return hiddenProjection() }
        let quota = quotaField(home)
        let chapters = chapterField(chapterCount)
        if chapters.phase == .empty {
            return PublishFabuPageProjection(phase: .empty, text: PublishFabuFieldState.emptyText, reason: "empty", visible: true, accessibilityIdentifier: PublishFabuAccessibility.empty, quota: quota, chapters: chapters)
        }
        if quota.phase == .unknown, chapters.phase == .unknown {
            return PublishFabuPageProjection(phase: .unknown, text: PublishFabuFieldState.unknownText, reason: "unknown", visible: true, accessibilityIdentifier: PublishFabuAccessibility.unknown, quota: quota, chapters: chapters)
        }
        let text = quota.phase == .ready ? quota.text : chapters.text
        return PublishFabuPageProjection(phase: .ready, text: text, reason: "ready", visible: true, accessibilityIdentifier: PublishFabuAccessibility.ready, quota: quota, chapters: chapters)
    }

    private static func hiddenProjection() -> PublishFabuPageProjection {
        PublishFabuPageProjection(phase: .unknown, text: PublishFabuFieldState.unknownText, reason: "hidden", visible: false, accessibilityIdentifier: PublishFabuAccessibility.hidden, quota: unknownField(PublishFabuAccessibility.quota), chapters: unknownField(PublishFabuAccessibility.chapters))
    }

    private static func visibleUnknown() -> PublishFabuPageProjection {
        PublishFabuPageProjection(phase: .unknown, text: PublishFabuFieldState.unknownText, reason: "unknown", visible: true, accessibilityIdentifier: PublishFabuAccessibility.unknown, quota: unknownField(PublishFabuAccessibility.quota), chapters: unknownField(PublishFabuAccessibility.chapters))
    }

    /// Explicit true only. A missing permission, a missing flag, or false stays hidden.
    private static func explicitPro(_ home: [String: ProjectEditJSON]?) -> Bool {
        guard let permission = home?["permission"]?.object, let flag = permission["canProPublish"] else { return false }
        if case .bool(true) = flag { return true }
        return false
    }

    private static func quotaField(_ home: [String: ProjectEditJSON]?) -> PublishFabuFieldState {
        guard let quota = home?["quota"]?.object, let raw = quota["themesRemaining"], raw != .null else {
            return unknownField(PublishFabuAccessibility.quota)
        }
        guard let number = raw.integer else { return unknownField(PublishFabuAccessibility.quota) }
        return PublishFabuFieldState(phase: .ready, text: String(number), reason: "ready.quota", accessibilityIdentifier: PublishFabuAccessibility.quota)
    }

    private static func chapterField(_ chapterCount: Int?) -> PublishFabuFieldState {
        guard let chapterCount, chapterCount >= 0 else { return unknownField(PublishFabuAccessibility.chapters) }
        if chapterCount == 0 {
            return PublishFabuFieldState(phase: .empty, text: PublishFabuFieldState.emptyText, reason: "empty", accessibilityIdentifier: PublishFabuAccessibility.chapters)
        }
        return PublishFabuFieldState(phase: .ready, text: String(chapterCount), reason: "ready.chapters", accessibilityIdentifier: PublishFabuAccessibility.chapters)
    }

    private static func unknownField(_ identifier: String) -> PublishFabuFieldState {
        PublishFabuFieldState(phase: .unknown, text: PublishFabuFieldState.unknownText, reason: "unknown", accessibilityIdentifier: identifier)
    }

    /// Blank, UNKNOWN, an em dash, or a numeric token. Never shown as 0.
    private static func isUnknownToken(_ token: String) -> Bool {
        if token.isEmpty { return true }
        if token.caseInsensitiveCompare("UNKNOWN") == .orderedSame { return true }
        if token == PublishFabuFieldState.unknownText { return true }
        return token.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil
    }
}
