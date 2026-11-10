import Foundation
import CoreFoundation

/// Port of `pages/activity/official-organizer/organizer-rules.js` plus the page's three server reads/commands.
/// Permission truth stays on the server: the console only shows controls after `publish-check` answers 200,
/// and a command is only believed from the server receipt (a later state read never proves the command).
public enum OfficialOrganizerAction: String, CaseIterable, Equatable {
    case schedule, pause, resume
}
public enum OfficialOrganizerControl: String, Equatable { case normal = "NORMAL", paused = "PAUSED" }

public struct OfficialOrganizerEventState: Equatable {
    public static let draft = 0, scheduled = 1, settling = 4
    public let status: Int?
    public let control: OfficialOrganizerControl?
    public let title: String
    public let pausedReason: String
    public let resumeNote: String
    public init(status: Int?, control: OfficialOrganizerControl?, title: String = "", pausedReason: String = "", resumeNote: String = "") {
        self.status = status; self.control = control; self.title = title
        self.pausedReason = pausedReason; self.resumeNote = resumeNote
    }
    /// `normalizeEventState`: status must be an integer, control only one of two known values.
    public init(raw: [String: Any]?) {
        let src = raw ?? [:]
        func int(_ v: Any?) -> Int? {
            guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue == Double(n.intValue) else { return nil }
            return n.intValue
        }
        func text(_ v: Any?) -> String { (v as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        self.init(status: int(src["status"]), control: (src["controlState"] as? String).flatMap(OfficialOrganizerControl.init(rawValue:)),
                  title: text(src["title"]), pausedReason: text(src["pausedReason"]), resumeNote: text(src["resumeNote"]))
    }
}

/// Why a command is unavailable (the view turns these into bilingual copy).
public enum OfficialOrganizerHint: Equatable {
    case stateUnknown, alreadyPublished, alreadyPaused, notPaused, publishFirst, ended, controlUnknown
}
public struct OfficialOrganizerAvailability: Equatable {
    public let enabled: Bool
    public let hint: OfficialOrganizerHint?
}

public struct OfficialOrganizerPauseEntry: Equatable {
    public var preset: String = ""
    public var extra: String = ""
    public init(preset: String = "", extra: String = "") { self.preset = preset; self.extra = extra }
}
public enum OfficialOrganizerFormError: Equatable {
    case pauseIncomplete, pauseTooLong, resumeMissing, resumeTooLong, unknownAction
}

public enum OfficialOrganizerRules {
    public static let pauseFields = ["reason", "impactScope", "alternativePlan", "notificationPlan"]
    /// Canonical (submitted) preset texts; the view shows English for each by index.
    public static let pausePresets: [String: [String]] = [
        "reason": ["天气或安全原因", "场地或合作商家临时不可用", "活动内容或任务需要修正"],
        "impactScope": ["全部已报名玩家", "部分节点或任务", "尚未报名的玩家"],
        "alternativePlan": ["恢复后按原计划继续", "改期，时间另行通知", "暂无替代方案，恢复前不开放"],
        "notificationPlan": ["站内通知全部已报名玩家", "主办方另行发布公告", "影响较小，暂不单独通知"],
    ]
    public static let planLimit = 300, reasonLimit = 200

    public static func availability(_ state: OfficialOrganizerEventState?) -> [OfficialOrganizerAction: OfficialOrganizerAvailability] {
        let status = state?.status
        func ok() -> OfficialOrganizerAvailability { .init(enabled: true, hint: nil) }
        func no(_ h: OfficialOrganizerHint) -> OfficialOrganizerAvailability { .init(enabled: false, hint: h) }
        var out: [OfficialOrganizerAction: OfficialOrganizerAvailability] = [:]
        if let status { out[.schedule] = status == OfficialOrganizerEventState.draft ? ok() : no(.alreadyPublished) }
        else { out[.schedule] = no(.stateUnknown) }
        switch state?.control {
        case .paused:
            out[.pause] = no(.alreadyPaused); out[.resume] = ok()
        case .normal:
            out[.resume] = no(.notPaused)
            if let status {
                out[.pause] = status < OfficialOrganizerEventState.scheduled ? no(.publishFirst)
                    : status >= OfficialOrganizerEventState.settling ? no(.ended) : ok()
            } else { out[.pause] = no(.stateUnknown) }
        default:
            out[.pause] = no(.controlUnknown); out[.resume] = no(.controlUnknown)
        }
        return out
    }

    /// Preset and extra text are both optional, either alone is enough; both -> "preset：extra".
    public static func compose(_ entry: OfficialOrganizerPauseEntry) -> String {
        let preset = entry.preset.trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = entry.extra.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preset.isEmpty && !extra.isEmpty { return preset + "：" + extra }
        return preset.isEmpty ? extra : preset
    }
    public static func validatePause(_ form: [String: OfficialOrganizerPauseEntry]) -> OfficialOrganizerFormError? {
        let values = pauseFields.map { compose(form[$0] ?? OfficialOrganizerPauseEntry()) }
        if values.contains(where: \.isEmpty) { return .pauseIncomplete }
        if values.contains(where: { $0.count > planLimit }) { return .pauseTooLong }
        return nil
    }
    public static func validateResume(reason: String) -> OfficialOrganizerFormError? {
        let t = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return .resumeMissing }
        return t.count > reasonLimit ? .resumeTooLong : nil
    }
    /// Body fields for `/api/official/command`, aligned with OfficialEventV2PauseRequest / PartyActionRequest.
    public static func payload(_ action: OfficialOrganizerAction, pause: [String: OfficialOrganizerPauseEntry] = [:], resumeReason: String = "") -> [String: String] {
        switch action {
        case .pause: return Dictionary(uniqueKeysWithValues: pauseFields.map { ($0, compose(pause[$0] ?? OfficialOrganizerPauseEntry())) })
        case .resume: return ["reason": resumeReason.trimmingCharacters(in: .whitespacesAndNewlines)]
        case .schedule: return [:]
        }
    }
    /// A read-back that disagrees with the expectation is only a hint to refresh, never a claim of success.
    public static func readBackMatches(_ action: OfficialOrganizerAction, _ after: OfficialOrganizerEventState) -> Bool {
        switch action {
        case .schedule: return (after.status ?? -1) >= OfficialOrganizerEventState.scheduled
        case .pause: return after.control == .paused
        case .resume: return after.control == .normal
        }
    }
}

public struct OfficialOrganizerCheck: Equatable {
    public let known: Bool
    public let blockers: [String]
    public let risks: [String]
    /// False when the server omitted `risks`. An omitted list is unknown, not zero.
    public let risksKnown: Bool
    public var pass: Bool { known && blockers.isEmpty }
    public init(known: Bool, blockers: [String], risks: [String], risksKnown: Bool = false) {
        self.known = known; self.blockers = blockers; self.risks = risks; self.risksKnown = risksKnown
    }
}
public enum OfficialOrganizerCheckResult: Equatable {
    case allowed(OfficialOrganizerCheck)
    /// Server refused: not a host/co-host of this event. No controls are shown.
    case denied(String?)
}
public struct OfficialOrganizerReceipt: Equatable {
    public enum State: String, Equatable { case applied = "APPLIED", rejected = "REJECTED", cancelled = "CANCELLED" }
    public let requestId: String
    public let state: State
    public let message: String
}
public enum OfficialOrganizerCommandMode: Equatable { case submit, query, cancel }
public struct OfficialOrganizerCommand: Equatable {
    public let eventID: Int
    public let action: OfficialOrganizerAction
    public let requestId: String
    public let fields: [String: String]
    public init(eventID: Int, action: OfficialOrganizerAction, requestId: String, fields: [String: String]) {
        self.eventID = eventID; self.action = action; self.requestId = requestId; self.fields = fields
    }
    /// 32 lowercase hex characters, like the mini-program's `newSessionKey`.
    public static func newRequestID() -> String { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }
}
public enum OfficialOrganizerFailure: Error, Equatable { case disabled, invalid, network, unauthorized }

@MainActor public protocol OfficialOrganizerAccess: AnyObject {
    var accountID: Int? { get }
    var enabled: Bool { get }
    func publishCheck(eventID: Int) async throws -> OfficialOrganizerCheckResult
    func eventState(eventID: Int) async throws -> OfficialOrganizerEventState?
    /// A receipt of nil means the outcome is unknown (network, 5xx, malformed); it never proves rollback.
    func command(_ command: OfficialOrganizerCommand, mode: OfficialOrganizerCommandMode) async throws -> OfficialOrganizerReceipt?
}

@MainActor public final class OfficialOrganizerHTTPAccess: OfficialOrganizerAccess {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let session: @MainActor () -> (accountID: Int, token: String)?
    private let isEnabled: @MainActor () -> Bool
    public var enabled: Bool { isEnabled() }
    public init(configuration: APIConfiguration, transport: any HTTPTransport, enabled: @escaping @MainActor () -> Bool,
                session: @escaping @MainActor () -> (accountID: Int, token: String)?) {
        self.configuration = configuration; self.transport = transport; self.isEnabled = enabled; self.session = session
    }
    public var accountID: Int? { session()?.accountID }

    private func request(_ path: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard enabled else { throw OfficialOrganizerFailure.disabled }
        guard let token = session()?.token, AuthRequestBuilder.isValidToken(token) else { throw OfficialOrganizerFailure.unauthorized }
        var r = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        r.httpMethod = method; r.timeoutInterval = 20; r.cachePolicy = .reloadIgnoringLocalCacheData
        r.setValue(token, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { r.httpBody = body; r.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return r
    }
    private func envelope(_ data: Data) -> (code: Int, msg: String?, data: Any?)? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let n = o["code"] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return (n.intValue, o["msg"] as? String, o["data"])
    }
    private func send(_ r: URLRequest) async throws -> (Data, Int) {
        do { return try await transport.send(r) } catch is CancellationError { throw CancellationError() }
        catch { throw OfficialOrganizerFailure.network }
    }
    public func publishCheck(eventID: Int) async throws -> OfficialOrganizerCheckResult {
        guard eventID > 0 else { throw OfficialOrganizerFailure.invalid }
        let (data, status) = try await send(try request("api/official/v2/events/\(eventID)/publish-check", method: "GET"))
        guard (200..<300).contains(status), let env = envelope(data) else {
            if status == 401 { throw OfficialOrganizerFailure.unauthorized }
            if status >= 500 || status == 408 { throw OfficialOrganizerFailure.network }
            return .denied(nil)
        }
        guard env.code == 200 else { return .denied(env.msg) }
        let body = env.data as? [String: Any] ?? [:]
        func list(_ v: Any?) -> [String] { (v as? [Any])?.compactMap { ($0 as? String).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } } ?? [] }
        return .allowed(OfficialOrganizerCheck(known: body["blockers"] is [Any], blockers: list(body["blockers"]), risks: list(body["risks"]),
                                               risksKnown: body["risks"] is [Any]))
    }
    public func eventState(eventID: Int) async throws -> OfficialOrganizerEventState? {
        guard eventID > 0 else { throw OfficialOrganizerFailure.invalid }
        // Scheduled events are readable publicly; drafts only show in "my published".
        if let (data, status) = try? await send(try request("api/official/events/\(eventID)", method: "GET")),
           (200..<300).contains(status), let env = envelope(data), env.code == 200,
           let row = env.data as? [String: Any], (row["contractVersion"] as? NSNumber)?.intValue ?? 0 >= 2 {
            return OfficialOrganizerEventState(raw: row)
        }
        let (data, status) = try await send(try request("api/official/my-published", method: "GET"))
        guard (200..<300).contains(status), let env = envelope(data), env.code == 200 else { throw OfficialOrganizerFailure.network }
        let events = (env.data as? [String: Any])?["events"] as? [[String: Any]] ?? []
        guard let row = events.first(where: { "\(($0["id"] as? NSNumber) ?? 0)" == String(eventID) }) else { return nil }
        return OfficialOrganizerEventState(raw: row)
    }
    public func command(_ command: OfficialOrganizerCommand, mode: OfficialOrganizerCommandMode) async throws -> OfficialOrganizerReceipt? {
        guard command.eventID > 0, command.requestId.count == 32 else { throw OfficialOrganizerFailure.invalid }
        var body: [String: Any] = mode == .query ? ["requestId": command.requestId] : command.fields
        if mode != .query {
            body["targetId"] = String(command.eventID); body["action"] = command.action.rawValue; body["requestId"] = command.requestId
        }
        let path = mode == .query ? "api/official/command/query" : mode == .cancel ? "api/official/command/cancel" : "api/official/command"
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let req = try request(path, method: "POST", body: data)
        guard let (resp, status) = try? await send(req), (200..<300).contains(status),
              let env = envelope(resp), env.code == 200, let r = env.data as? [String: Any],
              (r["requestId"] as? String) == command.requestId,
              let state = (r["state"] as? String).flatMap(OfficialOrganizerReceipt.State.init(rawValue:)) else { return nil }
        return OfficialOrganizerReceipt(requestId: command.requestId, state: state, message: (r["message"] as? String) ?? "")
    }
}

/// Page facts for the organizer console. A missing capability stays `.hidden`.
/// This is not a player-first entry: `showsPlayerEntry` is always false.
public enum OfficialOrganizerConsoleLoad: Equatable {
    case idle, loading, failed, denied
    case allowed(OfficialOrganizerCheck, OfficialOrganizerEventState?)
}

public enum OfficialOrganizerConsoleState: Equatable {
    case hidden, loading, empty, error, unknown, denied, ready
}

public struct OfficialOrganizerConsoleSnapshot: Equatable {
    public static let unknownMark = "—"
    /// Never a tab, home row, or signed-out entry. The console opens only from a host gate.
    public static let showsPlayerEntry = false
    public let state: OfficialOrganizerConsoleState
    public var showsPlayerEntry: Bool { false }
    public let statusText: String
    public let controlText: String
    public let blockerCountText: String
    public let riskCountText: String
    public let accessibilityIdentifier: String?

    public init(state: OfficialOrganizerConsoleState, statusText: String, controlText: String,
                blockerCountText: String, riskCountText: String, accessibilityIdentifier: String?) {
        self.state = state
        self.statusText = statusText
        self.controlText = controlText
        self.blockerCountText = blockerCountText
        self.riskCountText = riskCountText
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    /// A missing integer is an em dash. A server `0` stays `"0"`.
    public static func countText(known: Bool, count: Int) -> String {
        guard known, count >= 0 else { return unknownMark }
        return String(count)
    }
    public static func statusText(_ status: Int?) -> String {
        guard let status else { return unknownMark }
        return String(status)
    }
    public static func controlText(_ control: OfficialOrganizerControl?) -> String {
        control?.rawValue ?? unknownMark
    }

    public static func resolve(enabled: Bool, load: OfficialOrganizerConsoleLoad) -> OfficialOrganizerConsoleSnapshot {
        let dash = unknownMark
        func snap(_ state: OfficialOrganizerConsoleState, status: String = dash, control: String = dash,
                  blockers: String = dash, risks: String = dash, id: String? = nil) -> OfficialOrganizerConsoleSnapshot {
            OfficialOrganizerConsoleSnapshot(state: state, statusText: status, controlText: control,
                                             blockerCountText: blockers, riskCountText: risks, accessibilityIdentifier: id)
        }
        guard enabled else { return snap(.hidden) }
        switch load {
        case .idle, .loading:
            return snap(.loading, id: "official.organizer.loading")
        case .failed:
            return snap(.error, id: "official.organizer.error")
        case .denied:
            return snap(.denied, id: "official.organizer.denied")
        case .allowed(let check, nil):
            return snap(.empty,
                        blockers: countText(known: check.known, count: check.blockers.count),
                        risks: countText(known: check.risksKnown, count: check.risks.count),
                        id: "official.organizer.empty")
        case .allowed(let check, let event?):
            let status = statusText(event.status)
            let control = controlText(event.control)
            let blockers = countText(known: check.known, count: check.blockers.count)
            let risks = countText(known: check.risksKnown, count: check.risks.count)
            let factsKnown = event.status != nil && event.control != nil && check.known && check.risksKnown
            if factsKnown {
                return snap(.ready, status: status, control: control, blockers: blockers, risks: risks,
                            id: "official.organizer.content")
            }
            return snap(.unknown, status: status, control: control, blockers: blockers, risks: risks,
                        id: "official.organizer.unknown")
        }
    }
}

#if DEBUG
/// Synthetic organizer-console payloads. Not a live host, account, or route.
public enum OfficialOrganizerConsoleFixtureData {
    public static let allowedCheck = Data(#"{"code":200,"data":{"blockers":[],"risks":[],"pass":true}}"#.utf8)
    public static let omittedCounts = Data(#"{"code":200,"data":{}}"#.utf8)
    public static let denied = Data(#"{"code":500,"msg":"synthetic host gate"}"#.utf8)
    public static let readyEvent = Data(#"{"code":200,"data":{"id":5,"status":2,"controlState":"NORMAL","title":"Synthetic official event","contractVersion":2}}"#.utf8)
    public static let draftEvent = Data(#"{"code":200,"data":{"id":5,"status":0,"controlState":"NORMAL","title":"Synthetic draft","contractVersion":2}}"#.utf8)
    public static let unknownEvent = Data(#"{"code":200,"data":{"id":5,"title":"Synthetic official event","contractVersion":2}}"#.utf8)
    public static let emptyPublished = Data(#"{"code":200,"data":{"events":[]}}"#.utf8)
}
#endif
