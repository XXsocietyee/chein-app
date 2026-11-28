import Foundation
import Observation

// MARK: - TEAM backpack read (`_loadPlayerGameModule` → `_applyThemeTeamView`)

/// The TEAM theme backpack the mini-program shows on a ROUTE team run. Source:
/// `GET api/game/session/view {activityId, perspective: PLAYER}`; only `player.playMode == ROUTE` with
/// `player.scope == TEAM` becomes a backpack. TEAM item, quest and trade commands go through
/// `api/game/session/command`, which the player grant does not carry, so this snapshot is read-only
/// except for the shared help sheet and the trade preview (neither is a command).
public struct PlayTeamBackpackSnapshot: Equatable {
    /// The merged theme view (`_applyThemeTeamView`), the same shape the personal backpack reads.
    public let view: PlayWireValue
    public let backpack: PlayThemeBackpack
    public let activityID: Int
    public let sessionID: Int
    public let teamID: Int?
    public let revision: Int?
    public let authorityEpoch: Int?

    public var cooperation: PlayWireValue { view["cooperation"] }
    /// QUEST rows that carry the 「提示」 button (`item.kind === 'QUEST' && scope === 'TEAM' && cooperation`).
    public var helpQuests: [PlayThemeGameplayActionRow] {
        guard view["cooperation"].object != nil else { return [] }
        return PlayThemeGameplayRules.actionRows(view).filter { $0.kind == "QUEST" && PlayCoopHelp.canHelp(cooperation, questKey: $0.contentId) }
    }
    public var trade: (tradeTargets: [PlayThemeTradeTargetRow], tradeRows: [PlayThemeTradeRow], tradeLockedText: String) {
        PlayThemeTradeRules.present(view)
    }

    /// `Object.assign({}, player, { scope: 'TEAM', sessionId, activityId, revision, status, claimOnly, availableActions,
    /// inventoryEnabled: true, hpEnabled: typeof player.hp === 'number', authorityEpoch: player.authorityEpoch })`.
    static func merge(player: PlayWireValue, projection: PlayWireValue) -> PlayWireValue {
        var fields = player.object ?? [:]
        fields["scope"] = .string("TEAM")
        fields["sessionId"] = projection["sessionId"]
        fields["activityId"] = projection["activityId"]
        fields["revision"] = projection["revision"]
        fields["status"] = projection["status"]
        fields["claimOnly"] = .bool(PlayThemeRewardsRules.ended(player))
        fields["availableActions"] = projection["availableActions"].array.map(PlayWireValue.array) ?? .array([])
        fields["inventoryEnabled"] = .bool(true)
        fields["hpEnabled"] = .bool(player["hp"].double != nil)
        fields["authorityEpoch"] = player["authorityEpoch"]
        return .object(fields)
    }

    public init?(projection: PlayWireValue, activityID: Int) {
        let player = projection["player"]
        guard activityID > 0, projection["activityId"].tolerantInteger == activityID,
              let session = projection["sessionId"].playPositiveID,
              player["playMode"].text == "ROUTE", player["scope"].text == "TEAM" else { return nil }
        let merged = Self.merge(player: player, projection: projection)
        guard let backpack = try? PlayThemeBackpack(merged) else { return nil }
        view = merged; self.backpack = backpack; self.activityID = activityID; sessionID = session
        teamID = player["teamId"].tolerantInteger; revision = projection["revision"].integer
        authorityEpoch = player["authorityEpoch"].integer
    }
}

public enum PlayTeamBackpackRead: Equatable {
    /// Not a ROUTE team run, or no game session (`GAME_SESSION_NOT_FOUND / NOT_PREPARED / MODULE_DISABLED`).
    case hidden
    /// `本局状态暂未同步` (or the server's message).
    case failed(String?)
    case loaded(PlayTeamBackpackSnapshot)

    static let absentCodes: Set<String> = ["GAME_SESSION_NOT_FOUND", "GAME_SESSION_NOT_PREPARED", "GAME_MODULE_DISABLED"]

    public static func read(client: PlayRuntimeClient, activityID: Int) async -> PlayTeamBackpackRead {
        guard activityID > 0 else { return .hidden }
        let response: PlayRuntimeEnvelope
        do { response = try await client.get("api/game/session/view", query: ["activityId": String(activityID), "perspective": "PLAYER"]) }
        catch { return .failed(nil) }
        guard response.ok, response.data.object != nil else {
            if let code = response.errorCode ?? response.data["reasonCode"].text, absentCodes.contains(code) { return .hidden }
            return .failed(response.msg)
        }
        // A different activity's projection is not this run; a non-TEAM run has no TEAM backpack.
        guard response.data["activityId"].tolerantInteger == activityID else { return .failed(nil) }
        return PlayTeamBackpackSnapshot(projection: response.data, activityID: activityID).map(PlayTeamBackpackRead.loaded) ?? .hidden
    }
}

// MARK: - Shared help sheet (`coop-help-methods.js`)

/// VIEW / USE / SKIP on `POST api/play/help/shared`. An unconfirmed USE or SKIP is retried only with its
/// original request id; a VIEW that is lost is simply read again.
@MainActor @Observable public final class PlayCoopHelpFlow {
    public struct Unknown: Equatable { public let operation: PlayCoopHelp.Operation; public let level: Int?; public let requestID: String }
    public enum Issue: Equatable {
        /// 本题合作状态已变化，请刷新
        case stale
        /// 提示没有读到
        case viewUnknown
        /// 结果未确认，再点一次会查询原请求
        case writeUnknown
        case rejected(String)
    }

    public let questKey: String
    public let activityID: Int
    public private(set) var cooperation: PlayWireValue
    public private(set) var loading = true
    public private(set) var issue: Issue?
    /// Server sentence for the current issue, when the reply carried one. Empty when it did not.
    public private(set) var serverMessage: String?
    public private(set) var rows: [PlayCoopHelp.Row] = []
    public private(set) var skip: PlayCoopHelp.Skip?
    public private(set) var freeText = ""
    public private(set) var content = ""
    public private(set) var contentLevel: Int?
    public private(set) var chargedPoints: Int?
    public var skipConfirm = false
    public private(set) var busyLevel: Int?
    public private(set) var unknown: Unknown?
    /// SKIP applied: the sheet closes and the backpack re-reads authority.
    public private(set) var finished = false
    private var sending = false
    private let client: () -> PlayRuntimeClient?

    public init(activityID: Int, cooperation: PlayWireValue, questKey: String, client: @escaping () -> PlayRuntimeClient?) {
        self.activityID = activityID; self.cooperation = cooperation; self.questKey = questKey; self.client = client
    }

    public var isBusy: Bool { sending }

    public func open() async {
        guard PlayCoopHelp.canHelp(cooperation, questKey: questKey) else { loading = false; issue = .stale; return }
        await send(.view, level: nil, requestID: nil)
    }

    public func use(level: Int) async {
        guard let row = rows.first(where: { $0.level == level }), row.state != .off, busyLevel == nil, !sending else { return }
        let id = unknown.flatMap { $0.operation == .use && $0.level == level ? $0.requestID : nil } ?? PlayCoopHelp.newRequestID()
        await send(.use, level: level, requestID: id)
    }

    public func askSkip() { if let skip, skip.usable, busyLevel == nil { skipConfirm = true } }
    public func cancelSkip() { skipConfirm = false }

    public func confirmSkip() async {
        guard let skip, skip.usable, busyLevel == nil, !sending else { return }
        let id = unknown.flatMap { $0.operation == .skip ? $0.requestID : nil } ?? PlayCoopHelp.newRequestID()
        await send(.skip, level: skip.level, requestID: id)
    }

    private func send(_ operation: PlayCoopHelp.Operation, level: Int?, requestID: String?) async {
        guard let body = PlayCoopHelp.body(activityID: activityID, cooperation: cooperation, questKey: questKey,
                                           operation: operation, level: level, requestID: requestID) else {
            loading = false; issue = .stale; return
        }
        guard let client = client() else { loading = false; issue = operation == .view ? .viewUnknown : .writeUnknown; return }
        sending = true
        busyLevel = operation == .view ? nil : level
        issue = nil
        serverMessage = nil
        let outcome = await PlayCoopHelp.send(client: client, body: body)
        sending = false; loading = false; busyLevel = nil
        switch outcome {
        case .unknown:
            issue = operation == .view ? .viewUnknown : .writeUnknown
            unknown = operation == .view ? nil : Unknown(operation: operation, level: level, requestID: requestID ?? "")
        case .notedUnknown(let message):
            serverMessage = message
            issue = operation == .view ? .viewUnknown : .writeUnknown
            unknown = operation == .view ? nil : Unknown(operation: operation, level: level, requestID: requestID ?? "")
        case .rejected(let message):
            serverMessage = message
            issue = .rejected(message); unknown = nil; skipConfirm = false
        case .ok(let data):
            unknown = nil
            if data["levels"].array != nil { let parsed = PlayCoopHelp.rows(data["levels"]); rows = parsed.rows; skip = parsed.skip }
            if data["remainingFreeUses"] != .null { freeText = PlayCoopHelp.freeText(data["remainingFreeUses"]) }
            if operation == .use, let level {
                content = data["content"].text ?? ""
                contentLevel = level
                rows = rows.map { row in
                    row.level == level ? PlayCoopHelp.Row(level: row.level, title: row.title, state: .unlocked,
                                                          actionText: W8Text.t("重看", "View again")) : row
                }
                chargedPoints = (data["chargedPoints"].integer ?? 0) > 0 ? data["chargedPoints"].integer : nil
            }
            if operation == .skip { skipConfirm = false; finished = true; return }
            if data["cooperation"].object != nil { cooperation = data["cooperation"] }
        }
    }
}

// MARK: - Trade preview (`theme-trade.js previewThemeTrade`)

public struct PlayTeamTradePreview: Equatable {
    public let payload: PlayThemeTradePayload
    public let revision: Int
    public let authorityEpoch: Int
    public let fromUsed: Int, toUsed: Int, capacity: Int
    public let giveText: String, takeText: String

    public enum Read: Equatable {
        case ready(PlayTeamTradePreview)
        /// 交易预览未确认，请重新预览 (or the server's message)
        case unconfirmed(String?)
        /// 状态尚未同步，请刷新后重新预览: the preview is for a revision the backpack has not read yet.
        case stale
    }

    static func wire(_ rows: [PlayThemeTradePayloadItem]) -> PlayWireValue {
        .array(rows.map { .object(["itemId": .string($0.itemId), "quantity": .integer(Int64($0.quantity))]) })
    }

    static func matches(_ value: PlayWireValue, _ rows: [PlayThemeTradePayloadItem]) -> Bool {
        guard let array = value.array, array.count == rows.count else { return false }
        return zip(array, rows).allSatisfy { $0["itemId"].text == $1.itemId && $0["quantity"].integer == $1.quantity }
    }

    /// `POST api/game/session/shared/preview {activityId, action: 'TRADE_OPEN', payload}`. Never a write.
    public static func read(client: PlayRuntimeClient, snapshot: PlayTeamBackpackSnapshot, payload: PlayThemeTradePayload) async -> Read {
        let body: [String: PlayWireValue] = [
            "tradeKey": .string(payload.tradeKey), "toTeamId": .integer(Int64(payload.toTeamId)),
            "give": wire(payload.give), "take": wire(payload.take)]
        guard let response = try? await client.postJSON("api/game/session/shared/preview", body: [
            "activityId": .integer(Int64(snapshot.activityID)), "action": .string("TRADE_OPEN"), "payload": .object(body)]) else {
            return .unconfirmed(nil)
        }
        let preview = response.data, result = preview["result"]
        func count(_ value: PlayWireValue) -> Int? { value.integer.flatMap { $0 >= 0 ? $0 : nil } }
        guard response.ok, preview["previewOnly"].bool == true, result["preview"].bool == true,
              result["tradeKey"].text == payload.tradeKey,
              result["toTeamId"].tolerantInteger == payload.toTeamId,
              snapshot.teamID != nil, result["fromTeamId"].tolerantInteger == snapshot.teamID,
              matches(result["give"], payload.give), matches(result["take"], payload.take),
              let fromUsed = count(result["fromUsed"]), let toUsed = count(result["toUsed"]), let capacity = count(result["capacity"]),
              let revision = preview["expectedRevision"].integer, let epoch = preview["authorityEpoch"].integer else {
            return .unconfirmed(response.ok ? nil : response.msg)
        }
        guard revision == snapshot.revision, epoch == snapshot.authorityEpoch else { return .stale }
        return .ready(PlayTeamTradePreview(payload: payload, revision: revision, authorityEpoch: epoch, fromUsed: fromUsed, toUsed: toUsed,
            capacity: capacity, giveText: PlayThemeTradeRules.itemText(result["give"].array ?? [], view: snapshot.view),
            takeText: PlayThemeTradeRules.itemText(result["take"].array ?? [], view: snapshot.view)))
    }

    /// `selectThemeTradeTarget`: a fresh trade key and one zero row per catalogue item.
    public static func form(target: PlayThemeTradeTargetRow, snapshot: PlayTeamBackpackSnapshot) -> PlayThemeTradeForm? {
        guard target.enabled else { return nil }
        let items = PlayThemeTradeRules.catalogue(snapshot.view).compactMap { row -> PlayThemeTradeFormItem? in
            guard let id = row["id"].text, !id.isEmpty else { return nil }
            return PlayThemeTradeFormItem(id: id, name: row["name"].text ?? id)
        }
        let key = "trade_" + String(Int64(Date().timeIntervalSince1970 * 1000)) + "_" + UUID().uuidString.lowercased().prefix(8)
        return PlayThemeTradeForm(toTeamId: target.teamId, tradeKey: key, items: items)
    }
}
