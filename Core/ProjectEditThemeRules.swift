import Foundation

/// 主题详情 → 玩法规则: 允许再玩一次 (`replayEnabled`) and 同场路线 (`teamTrail`) on `themeRuntimeConfig`,
/// plus 队伍之间可以交换物资 (`gameplayRuntime.allowTrade`) and 表决方式 (`gameplayRuntime.votePolicy`)
/// from `theme-ownership.js` `onThemeAllowTrade` / `onThemeVotePolicy` (shown only for a shared team world).
/// Mini-program: `pages/publish/fabu/theme-runtime-survival.js` `_refreshSurvivalSummary`, `toggleThemeReplay`,
/// `toggleThemeTeamTrail`; rows in `topic-detail-sheet.wxml` after 结果卡.
/// This does not post. The topic save already carries `themeRuntimeConfig`.
public enum ProjectEditThemeRules {
    public enum Copy {
        public static let title = "mpPublish.rules.title"
        public static let replay = "mpPublish.rules.replay"
        public static let teamTrail = "mpPublish.rules.teamTrail"
        public static let replayTeamRefused = "mpPublish.rules.replay.teamRefused"
        public static let unreadable = "mpPublish.rules.unreadable"
        public static let allowTrade = "mpPublish.rules.allowTrade"
        public static let votePolicy = "mpPublish.rules.votePolicy"
    }

    /// MP `theme-ownership.js` `VOTE_POLICIES`, in MP order; `labelKey` is the localized label.
    public enum VotePolicy: String, CaseIterable, Identifiable, Sendable {
        case majority = "MAJORITY", unanimous = "UNANIMOUS", majorityAcceptance = "MAJORITY_ACCEPTANCE"
        public var id: String { rawValue }
        public var labelKey: String {
            switch self {
            case .majority: return "mpPublish.rules.vote.majority"
            case .unanimous: return "mpPublish.rules.vote.unanimous"
            case .majorityAcceptance: return "mpPublish.rules.vote.majorityAcceptance"
            }
        }
    }

    /// MP `themeWorldShared`: a TEAM runtime whose teams share one world (`worldMode == WORLD_SHARED`).
    public static func worldShared(in draft: ProjectEditDraft) -> Bool {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return false }
        let game = theme["gameplayRuntime"]?.object ?? [:]
        return game["runtimeScope"]?.text == "TEAM" && game["worldMode"]?.text == "WORLD_SHARED"
    }

    /// MP `themeAllowTrade`: only an explicit `true` counts.
    public static func allowTrade(in draft: ProjectEditDraft) -> Bool {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return false }
        return theme["gameplayRuntime"]?.object?["allowTrade"] == .bool(true)
    }

    /// MP `themeVotePolicyIndex`: an unknown or missing key reads as the first policy (过半数).
    public static func votePolicy(in draft: ProjectEditDraft) -> VotePolicy {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft),
              let key = theme["gameplayRuntime"]?.object?["votePolicy"]?.text,
              let policy = VotePolicy(rawValue: key) else { return .majority }
        return policy
    }

    /// MP `onThemeAllowTrade`: only while the world is shared; on writes `true`, off writes `false` when the key exists.
    public static func setAllowTrade(_ enabled: Bool, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try readable(draft)
        guard var game = theme["gameplayRuntime"]?.object,
              game["runtimeScope"]?.text == "TEAM", game["worldMode"]?.text == "WORLD_SHARED" else { return draft }
        if enabled {
            game["allowTrade"] = .bool(true)
        } else if game["allowTrade"] != nil {
            game["allowTrade"] = .bool(false)
        } else {
            return draft
        }
        theme["gameplayRuntime"] = .object(game)
        return try write(theme, into: draft)
    }

    /// MP `onThemeVotePolicy`: only while the world is shared; writes the policy key.
    public static func setVotePolicy(_ policy: VotePolicy, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try readable(draft)
        guard var game = theme["gameplayRuntime"]?.object, game["worldMode"]?.text == "WORLD_SHARED" else { return draft }
        game["votePolicy"] = .string(policy.rawValue)
        theme["gameplayRuntime"] = .object(game)
        return try write(theme, into: draft)
    }

    /// MP `themeReplayEnabled`: only an explicit `true` counts.
    public static func replayEnabled(in draft: ProjectEditDraft) -> Bool {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return false }
        return theme["replayEnabled"] == .bool(true)
    }

    /// MP `themeTeamTrail`: explicit `true`, or not `false` while the runtime is not PLAYER (default on).
    public static func teamTrail(in draft: ProjectEditDraft) -> Bool {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return true }
        if theme["teamTrail"] == .bool(true) { return true }
        return theme["teamTrail"] != .bool(false) && scope(theme) != "PLAYER"
    }

    /// MP `toggleThemeReplay`: turning on is refused for a TEAM runtime; the value is written as a Bool.
    public static func setReplay(_ enabled: Bool, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try readable(draft)
        if enabled && scope(theme) == "TEAM" { throw ProjectEditRuntimeActsError.refused(Copy.replayTeamRefused) }
        if theme.isEmpty { theme = defaults }
        theme["replayEnabled"] = .bool(enabled)
        return try write(theme, into: draft)
    }

    /// MP `toggleThemeTeamTrail`: on writes `true` for a PLAYER runtime, else removes the key (default on); off writes `false`.
    public static func setTeamTrail(_ enabled: Bool, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try readable(draft)
        if enabled && scope(theme) != "PLAYER" && theme["teamTrail"] == nil { return draft }
        if theme.isEmpty { theme = defaults }
        if enabled && scope(theme) == "PLAYER" {
            theme["teamTrail"] = .bool(true)
        } else if enabled {
            theme["teamTrail"] = nil
        } else {
            theme["teamTrail"] = .bool(false)
        }
        return try write(theme, into: draft)
    }

    // MARK: 进行方式 (`theme-runtime-structure.js` `MODES`, `modeKey`, `modeReason`, `setMode`)

    public typealias RunMode = NativeRuntimeStructureAuthorDraft.Mode

    /// Why a 进行方式 choice is unavailable: a localized key for the MP theme checks,
    /// or the existing Core node reason text (support matrix read).
    public enum ModeReason: Equatable, Sendable {
        case key(String)
        case text(String)
    }

    /// MP `modeKey`: PLAYER, or the TEAM world mode; anything else is 未选择.
    public static func runMode(in draft: ProjectEditDraft) -> RunMode? {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return nil }
        let game = theme["gameplayRuntime"]?.object ?? [:]
        if game["runtimeScope"]?.text == "PLAYER" { return .player }
        guard game["runtimeScope"]?.text == "TEAM", let raw = game["worldMode"]?.text,
              let mode = RunMode(rawValue: raw), mode != .player else { return nil }
        return mode
    }

    /// Localized label of a mode in MP `MODES` order; nil reads 未选择.
    public static func modeLabelKey(_ mode: RunMode?) -> String {
        switch mode {
        case .player: return "mpPublish.rules.mode.player"
        case .team: return "mpPublish.rules.mode.team"
        case .sharedWorld: return "mpPublish.rules.mode.shared"
        case nil: return "mpPublish.rules.mode.none"
        }
    }

    /// MP `modeReason`: the two theme checks always; the per-node support checks only when the
    /// support matrix was read (MP `if (!matrix) return ''`).
    public static func modeReason(_ mode: RunMode, in draft: ProjectEditDraft, inputs: NativeRuntimeStructureAuthorInputs?) -> ModeReason? {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return .key(Copy.unreadable) }
        let game = theme["gameplayRuntime"]?.object ?? [:]
        if mode == .player && (game["acts"]?.array ?? []).contains(where: { truthy($0.object?["hostUnlock"]) }) {
            return .key("mpPublish.rules.mode.reason.hostUnlock")
        }
        if mode != .sharedWorld {
            let facilities = (game["facilities"]?.array ?? []).compactMap(\.object)
            let sharedFacility = facilities.contains { $0["scope"]?.text != "OWNER" || $0["targetScope"]?.text != "OWNER" }
            if truthy(game["allowTrade"]) || truthy(game["votePolicy"]) || !(game["plans"]?.array ?? []).isEmpty || sharedFacility {
                return .key("mpPublish.rules.mode.reason.shared")
            }
        }
        guard let inputs else { return nil }
        for node in draft.chapters.flatMap(\.nodes) {
            if let reason = inputs.reason(node: node, theme: theme, mode: mode) {
                return .text((node.name.isEmpty ? "节点" : node.name) + "：" + reason)
            }
        }
        return nil
    }

    /// MP `setMode`: refused while `modeReason` has a reason; adds `schemaVersion` 1 / `capacity` 0 when missing,
    /// writes `runtimeScope` + `worldMode` (removed for PLAYER), and the server's explicit survival default
    /// only when no survival setting exists yet.
    public static func setMode(_ mode: RunMode, in draft: ProjectEditDraft, inputs: NativeRuntimeStructureAuthorInputs?) throws -> ProjectEditDraft {
        var theme = try readable(draft)
        switch modeReason(mode, in: draft, inputs: inputs) {
        case .key(let key)?: throw ProjectEditRuntimeActsError.refused(key)
        case .text?: throw ProjectEditRuntimeActsError.refused("mpPublish.rules.mode.reason.node")
        case nil: break
        }
        if theme["schemaVersion"] == nil || theme["schemaVersion"] == .null {
            theme["schemaVersion"] = .number(1)
            theme["capacity"] = .number(0)
        }
        var game = theme["gameplayRuntime"]?.object ?? [:]
        game["runtimeScope"] = .string(mode.scope)
        game["worldMode"] = mode == .player ? nil : .string(mode.rawValue)
        if game["survival"] == nil {
            game["survival"] = .object(["zeroHpPolicy": .string("BLOCK_HP_COST"), "actionLimitPolicy": .string("BLOCK_OVERFLOW")])
        }
        theme["gameplayRuntime"] = .object(game)
        return try write(theme, into: draft)
    }

    /// JavaScript truthiness for a JSON value.
    private static func truthy(_ value: ProjectEditJSON?) -> Bool {
        switch value {
        case .bool(let flag)?: return flag
        case .number(let number)?: return number != 0
        case .string(let text)?: return !text.isEmpty
        case .array?, .object?: return true
        default: return false
        }
    }

    /// MP `config()` defaults for a topic that has no runtime config yet.
    static var defaults: [String: ProjectEditJSON] {
        ["schemaVersion": .number(1), "capacity": .number(6), "allowDiscard": .bool(true),
         "items": .array([]), "chapters": .array([]), "grants": .array([]), "events": .array([])]
    }

    private static func scope(_ theme: [String: ProjectEditJSON]) -> String? {
        theme["gameplayRuntime"]?.object?["runtimeScope"]?.text
    }

    private static func readable(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        do {
            return try NativeRuntimeStructureAuthorDraft.readTheme(draft)
        } catch {
            throw ProjectEditRuntimeActsError.refused(Copy.unreadable)
        }
    }

    private static func write(_ theme: [String: ProjectEditJSON], into draft: ProjectEditDraft) throws -> ProjectEditDraft {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ProjectEditJSON.object(theme))
        guard let text = String(data: data, encoding: .utf8), text.utf16.count <= 200_000 else { throw ProjectEditError.invalidDraft }
        var next = draft
        next.preserved["themeRuntimeConfig"] = .string(text)
        return next
    }
}
