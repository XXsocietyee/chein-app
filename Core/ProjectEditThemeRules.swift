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
