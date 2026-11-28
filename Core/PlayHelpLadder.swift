import Foundation

/// UG-05…UG-09 hint ladder for a route run (mini-program pages/play/utils/play-help-panel.js).
/// `runId` is `topic_route_session.id`. The panel only shows when `GET /api/play/help` returns a usable
/// layer; otherwise the legacy hint and reveal entries stay as they are. Rows, the shared free counter,
/// charges and the score detail are server facts. Nothing is decremented, judged or scored locally.
/// Use and skip keep their request id on disk before sending and resend the same id while the result is unknown.

/// One bounded reply. `refused` is a definitive 4xx business code; everything else that is not 200 stays unknown.
public enum PlayHelpReply: Equatable {
    case ok(PlayWireValue)
    case refused(code: Int, reason: String?, message: String?)
    case unauthorized
    case unknown
    /// A sentence arrived, and the write is not a proven 4xx refusal. The same request id is still the retry.
    case retryable(message: String)

    /// Mini-program `definitive`: only a 4xx business code proves the server did not apply the request.
    /// A non-empty `msg` on any other outcome is kept so the panel can show it beside the same-id retry.
    static func classify(data: Data, status: Int) -> PlayHelpReply {
        let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: data)
        let code = envelope?["code"].tolerantInteger
        let raw = envelope?["msg"].text
        if status == 401 || code == 401 { return .unauthorized }
        guard (200..<300).contains(status), let envelope, let code else {
            if let sentence = PlayerGapReply.sentence(raw) { return .retryable(message: sentence) }
            return .unknown
        }
        if code == 200 { return .ok(envelope["data"]) }
        guard (400..<500).contains(code) else {
            if let sentence = PlayerGapReply.sentence(raw) { return .retryable(message: sentence) }
            return .unknown
        }
        let reason = envelope["reasonCode"].text ?? envelope["data"]["reason"].text ?? envelope["data"]["reasonCode"].text
        return .refused(code: code, reason: reason, message: raw)
    }
}

/// Who and where a help request belongs to. A reply for another owner, run or node is dropped.
public struct PlayHelpIdentity: Equatable, Sendable {
    public let owner: String
    public let runID: Int
    public let nodeID: Int

    public init?(owner: String, runID: Int?, nodeID: Int) {
        guard !owner.isEmpty, let runID, runID > 0, nodeID > 0 else { return nil }
        self.owner = owner; self.runID = runID; self.nodeID = nodeID
    }

    func storageKey(_ action: PlayHelpAction, level: Int = 0) -> String {
        [owner, String(runID), String(nodeID), action.rawValue, String(level)].joined(separator: "|")
    }
}

public enum PlayHelpAction: String, Sendable { case use, skip }

/// Saved request ids for use and skip. `remember` returns false when the id could not be read back.
@MainActor public protocol PlayHelpRequestStore: AnyObject {
    func requestID(for key: String) -> String?
    func remember(_ requestID: String, for key: String) -> Bool
    func forget(_ key: String)
}

@MainActor public final class PlayHelpMemoryRequestStore: PlayHelpRequestStore {
    private var values: [String: String] = [:]
    public init() {}
    public func requestID(for key: String) -> String? { values[key] }
    public func remember(_ requestID: String, for key: String) -> Bool { values[key] = requestID; return true }
    public func forget(_ key: String) { values.removeValue(forKey: key) }
}

/// The four server calls for one node of one run, bound to the session that issued them.
@MainActor public struct PlayHelpClient {
    public let identity: PlayHelpIdentity
    let view: () async -> PlayHelpReply
    let use: (_ level: Int, _ requestID: String) async -> PlayHelpReply
    let skip: (_ requestID: String) async -> PlayHelpReply
    let receipt: () async -> PlayHelpReply
    let isCurrent: () -> Bool
    let onSkipped: () async -> Void
    let onUnauthorized: () -> Void

    public init(identity: PlayHelpIdentity, view: @escaping () async -> PlayHelpReply,
                use: @escaping (Int, String) async -> PlayHelpReply, skip: @escaping (String) async -> PlayHelpReply,
                receipt: @escaping () async -> PlayHelpReply, isCurrent: @escaping () -> Bool = { true },
                onSkipped: @escaping () async -> Void = {}, onUnauthorized: @escaping () -> Void = {}) {
        self.identity = identity; self.view = view; self.use = use; self.skip = skip; self.receipt = receipt
        self.isCurrent = isCurrent; self.onSkipped = onSkipped; self.onUnauthorized = onUnauthorized
    }
}

public struct PlayHelpRow: Equatable, Identifiable {
    public enum State: String, Equatable { case review, gated, free, cost, unavailable }
    public enum Problem: Equatable {
        /// Sent, no definitive answer. The only action is to resend the same id.
        case pending
        /// Same as pending, with the server sentence to show beside the resend.
        case pendingNote(String)
        case insufficient
        case refused(String?)
    }
    public let level: Int
    /// TEXT, IMAGE, LETTER, DIGIT or ANSWER. Anything else is unavailable.
    public let type: String
    public internal(set) var state: State
    /// Author points for a first unlock. Only meaningful for `.cost`.
    public internal(set) var cost: Int
    public internal(set) var content: String?
    public internal(set) var contentType: String?
    public internal(set) var chargedPoints: Int?
    public internal(set) var balanceAfter: Int?
    public internal(set) var problem: Problem?
    public var id: Int { level }
    public var pending: Bool {
        switch problem {
        case .pending, .pendingNote: return true
        default: return false
        }
    }
    public var tappable: Bool { pending || state == .review || state == .free || state == .cost }
    /// First unlocks confirm; a re-view or a resend of the same request does not.
    public var needsConfirmation: Bool { !pending && (state == .free || state == .cost) }
    public var typeLabelKey: String { "playHelp.type." + (PlayHelpProjection.renderable.contains(type) ? type.lowercased() : "other") }
}

public struct PlayHelpProjection: Equatable {
    /// POOL_TRIM is requestable only while `poolTrimEnabled` is true. The gate defaults off.
    public static let renderable: [String] = ["TEXT", "IMAGE", "LETTER", "DIGIT", "ANSWER", "POOL_TRIM"]
    public let enabled: Bool
    public let rows: [PlayHelpRow]
    /// Level of a usable SKIP layer. Nil hides the skip row.
    public let skipLevel: Int?
    /// `remainingFreeUses` as sent. Missing or malformed stays nil and is never shown as 0.
    public let freeLeft: Int?

    public static let disabled = PlayHelpProjection(enabled: false, rows: [], skipLevel: nil, freeLeft: nil)

    /// Author order. A layer after a not-yet-unlocked (non-skip) layer is gated.
    public static func project(_ view: PlayWireValue, identity: PlayHelpIdentity? = nil, poolTrimEnabled: Bool = false) -> PlayHelpProjection {
        guard view["enabled"].bool == true, let layers = view["layers"].array else { return .disabled }
        if let identity {
            if let run = view["runId"].tolerantInteger, run != identity.runID { return .disabled }
            if let node = view["nodeId"].tolerantInteger, node != identity.nodeID { return .disabled }
        }
        var rows: [PlayHelpRow] = []
        var skip: Int?
        var previousUnlocked = true
        for layer in layers {
            guard let level = layer["level"].integer, level > 0 else { continue }
            let type = layer["type"].text ?? ""
            if type == "POOL_TRIM", !poolTrimEnabled {
                previousUnlocked = layer["unlocked"].bool == true
                continue
            }
            if type == "SKIP" {
                if layer["usable"].bool == true { skip = level }
                continue
            }
            let usable = renderable.contains(type) && layer["usable"].bool == true
            let unlocked = layer["unlocked"].bool == true
            let cost = layer["costPoints"].integer.flatMap { $0 >= 0 ? $0 : nil }
            let state: PlayHelpRow.State
            if usable && unlocked { state = .review }
            else if usable && !previousUnlocked { state = .gated }
            else if usable && layer["free"].bool == true { state = .free }
            else if usable, let cost, cost > 0 { state = .cost }
            else if usable, cost == 0 { state = .free }
            else { state = .unavailable }
            rows.append(PlayHelpRow(level: level, type: type, state: state, cost: state == .cost ? (cost ?? 0) : 0,
                                    content: nil, contentType: nil, chargedPoints: nil, balanceAfter: nil, problem: nil))
            previousUnlocked = unlocked
        }
        let free = view["remainingFreeUses"].integer.flatMap { $0 >= 0 ? $0 : nil }
        return PlayHelpProjection(enabled: !rows.isEmpty || skip != nil, rows: rows, skipLevel: skip, freeLeft: free)
    }
}

/// UG-07 detail lines. Only server numbers; a missing number is left out, never written as 0.
public enum PlayHelpReceiptLine: Equatable, Identifiable {
    case skipped
    case revealed
    case notScored
    case baseScore(Int)
    case bonus(Int)
    case helpDeduction(Int)
    case skipDeduction(Int)
    case netScore(Int)
    case pointsCharged(Int)
    case level(level: Int, type: String, free: Bool, points: Int?)
    case detailMissing

    public var id: String {
        switch self {
        case .skipped: return "skipped"
        case .revealed: return "revealed"
        case .notScored: return "notScored"
        case .baseScore: return "base"
        case .bonus: return "bonus"
        case .helpDeduction: return "help"
        case .skipDeduction: return "skip"
        case .netScore: return "net"
        case .pointsCharged: return "points"
        case .level(let level, _, _, _): return "level.\(level)"
        case .detailMissing: return "missing"
        }
    }

    public static func lines(_ raw: PlayWireValue) -> [PlayHelpReceiptLine]? {
        guard raw.object != nil else { return nil }
        var out: [PlayHelpReceiptLine] = []
        let notScored = raw["scoreState"].text == "NOT_SCORED"
        if raw["skipped"].bool == true { out.append(.skipped) }
        else if raw["assisted"].bool == true { out.append(.revealed) }
        if notScored { out.append(.notScored) }
        else {
            if let base = raw["baseScore"].integer { out.append(.baseScore(base)) }
            if let bonus = raw["bonus"].integer, bonus != 0 { out.append(.bonus(bonus)) }
            if let help = raw["helpDeduction"].integer, help != 0 { out.append(.helpDeduction(help)) }
            if let skip = raw["skipDeduction"].integer, skip != 0 { out.append(.skipDeduction(skip)) }
            if let net = raw["netScore"].integer { out.append(.netScore(net)) }
        }
        if let points = raw["pointsCharged"].integer, points > 0 { out.append(.pointsCharged(points)) }
        if let levels = raw["levels"].array {
            for row in levels {
                guard let level = row["level"].integer else { continue }
                out.append(.level(level: level, type: row["type"].text ?? "", free: row["free"].bool == true, points: row["pointsCharged"].integer))
            }
        } else if !notScored {
            out.append(.detailMissing)
        }
        return out
    }
}

@MainActor @Observable public final class PlayHelpLadderModel {
    public enum Notice: Equatable {
        case storageUnavailable
        case pending
        case pendingNote(String)
        case refused(String?)
    }
    public private(set) var projection = PlayHelpProjection.disabled
    public private(set) var rows: [PlayHelpRow] = []
    public private(set) var skipPending = false
    public private(set) var skipped = false
    public private(set) var busyLevel: Int?
    public private(set) var busy = false
    public private(set) var notice: Notice?
    public private(set) var receipt: [PlayHelpReceiptLine]?
    public private(set) var receiptUnavailable = false
    public private(set) var receiptOpen = false
    public private(set) var loaded = false
    /// Bumps after a POOL_TRIM use so the host can re-read the trimmed pool.
    public private(set) var poolTrimGeneration = 0

    @ObservationIgnored private let client: PlayHelpClient
    @ObservationIgnored private let poolTrimEnabled: Bool
    @ObservationIgnored private let store: any PlayHelpRequestStore
    @ObservationIgnored private let makeRequestID: () -> String
    @ObservationIgnored private var epoch: UInt64 = 0

    public var identity: PlayHelpIdentity { client.identity }
    public var enabled: Bool { projection.enabled }
    public var freeLeft: Int? { projection.freeLeft }
    public var showsSkip: Bool { (projection.skipLevel != nil && !skipped) || skipPending }

    public init(client: PlayHelpClient, store: any PlayHelpRequestStore,
                poolTrimEnabled: Bool = false,
                makeRequestID: @escaping () -> String = PlayHelpLadderModel.newRequestID) {
        self.client = client; self.store = store; self.poolTrimEnabled = poolTrimEnabled; self.makeRequestID = makeRequestID
    }

    /// `h` plus 32 hex characters: printable ASCII, under the server's 64-character limit.
    nonisolated public static func newRequestID() -> String {
        "h" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// One read when the task opens. A failed read leaves the legacy entries alone.
    public func load() async {
        epoch &+= 1
        let ticket = epoch
        let reply = await client.view()
        guard current(ticket) else { return }
        loaded = true
        guard case .ok(let data) = reply else {
            if reply == .unauthorized { client.onUnauthorized() }
            projection = .disabled; rows = []
            return
        }
        apply(PlayHelpProjection.project(data, identity: client.identity, poolTrimEnabled: poolTrimEnabled), keepContent: false)
    }

    public func row(_ level: Int) -> PlayHelpRow? { rows.first { $0.level == level } }

    /// A free or charged first unlock asks first. A re-view or a pending resend goes straight to `use`.
    public func needsConfirmation(_ level: Int) -> Bool { row(level)?.needsConfirmation ?? false }

    public func use(_ level: Int) async {
        guard !busy, let row = row(level), row.tappable else { return }
        let key = client.identity.storageKey(.use, level: level)
        let requestID = store.requestID(for: key) ?? makeRequestID()
        guard store.remember(requestID, for: key), store.requestID(for: key) == requestID else {
            notice = .storageUnavailable; return
        }
        let ticket = epoch
        busy = true; busyLevel = level; notice = nil
        let reply = await client.use(level, requestID)
        guard current(ticket) else { return }
        busy = false; busyLevel = nil
        switch reply {
        case .ok(let data):
            if data["reason"].text == "POINTS_INSUFFICIENT" {
                store.forget(key)
                patch(level) { $0.problem = .insufficient; $0.content = nil }
                return
            }
            if row.type == "POOL_TRIM" || data["type"].text == "POOL_TRIM" {
                guard data["level"].integer == level else {
                    patch(level) { $0.problem = .pending }
                    return
                }
                store.forget(key)
                let type = data["type"].text ?? "POOL_TRIM"
                patch(level) {
                    $0.problem = nil; $0.state = .review; $0.contentType = type
                    if let content = data["content"].text { $0.content = Self.renderable(content: content, type: type) }
                    $0.chargedPoints = data["chargedPoints"].integer
                    $0.balanceAfter = data["balanceAfter"].integer
                }
                poolTrimGeneration &+= 1
                await reloadCounter(ticket)
                return
            }
            guard data["level"].integer == level, let content = data["content"].text else {
                patch(level) { $0.problem = .pending }
                return
            }
            store.forget(key)
            let type = data["type"].text ?? row.type
            patch(level) {
                $0.problem = nil; $0.state = .review
                $0.content = Self.renderable(content: content, type: type)
                $0.contentType = type
                $0.chargedPoints = data["chargedPoints"].integer
                $0.balanceAfter = data["balanceAfter"].integer
            }
            await reloadCounter(ticket)
        case .refused(_, let reason, let message):
            store.forget(key)
            patch(level) { $0.content = nil; $0.problem = reason == "POINTS_INSUFFICIENT" ? .insufficient : .refused(message) }
        case .unauthorized:
            patch(level) { $0.problem = .pending }
            client.onUnauthorized()
        case .retryable(let message):
            patch(level) { $0.problem = .pendingNote(message) }
        case .unknown:
            patch(level) { $0.problem = .pending }
        }
    }

    public func skip() async {
        guard !busy, showsSkip else { return }
        let key = client.identity.storageKey(.skip)
        let requestID = store.requestID(for: key) ?? makeRequestID()
        guard store.remember(requestID, for: key), store.requestID(for: key) == requestID else {
            notice = .storageUnavailable; return
        }
        let ticket = epoch
        busy = true; notice = nil
        let reply = await client.skip(requestID)
        guard current(ticket) else { return }
        busy = false
        switch reply {
        case .ok(let data) where data["skipped"].bool == true:
            store.forget(key)
            skipPending = false; skipped = true
            receipt = PlayHelpReceiptLine.lines(data["helpReceipt"])
            receiptUnavailable = receipt == nil
            receiptOpen = true
            await client.onSkipped()
        case .refused(_, _, let message):
            store.forget(key)
            skipPending = false; notice = .refused(message)
        case .unauthorized:
            skipPending = true; notice = .pending
            client.onUnauthorized()
        case .retryable(let message):
            skipPending = true; notice = .pendingNote(message)
        case .ok, .unknown:
            skipPending = true; notice = .pending
        }
    }

    /// Opening the panel marks requests that were sent and never settled, so only "keep checking" is offered.
    public func markSavedRequests() {
        for index in rows.indices where store.requestID(for: client.identity.storageKey(.use, level: rows[index].level)) != nil {
            rows[index].problem = .pending
        }
        skipPending = store.requestID(for: client.identity.storageKey(.skip)) != nil
    }

    public func toggleReceipt() async {
        if receiptOpen { receiptOpen = false; return }
        receiptOpen = true; receiptUnavailable = false
        let ticket = epoch
        let reply = await client.receipt()
        guard current(ticket) else { return }
        if case .ok(let data) = reply, let lines = PlayHelpReceiptLine.lines(data) { receipt = lines }
        else { receipt = nil; receiptUnavailable = true }
    }

    /// LETTER and DIGIT carry exactly one character. Anything else is not drawn.
    static func renderable(content: String, type: String) -> String? {
        if type == "LETTER" || type == "DIGIT" { return content.unicodeScalars.count == 1 ? content : nil }
        return PlayHelpProjection.renderable.contains(type) ? content : nil
    }

    private func current(_ ticket: UInt64) -> Bool { ticket == epoch && client.isCurrent() }

    private func patch(_ level: Int, _ change: (inout PlayHelpRow) -> Void) {
        guard let index = rows.firstIndex(where: { $0.level == level }) else { return }
        change(&rows[index])
    }

    /// Re-read the counter and row states after a use. The counter is never decremented here.
    private func reloadCounter(_ ticket: UInt64) async {
        guard case .ok(let data) = await client.view(), current(ticket) else { return }
        apply(PlayHelpProjection.project(data, identity: client.identity, poolTrimEnabled: poolTrimEnabled), keepContent: true)
    }

    private func apply(_ next: PlayHelpProjection, keepContent: Bool) {
        let old = Dictionary(uniqueKeysWithValues: rows.map { ($0.level, $0) })
        projection = next
        rows = next.rows.map { row in
            guard keepContent, let previous = old[row.level] else { return row }
            var merged = row
            merged.content = previous.content; merged.contentType = previous.contentType
            merged.chargedPoints = previous.chargedPoints; merged.balanceAfter = previous.balanceAfter
            return merged
        }
    }
}
