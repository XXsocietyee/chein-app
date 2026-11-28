import SwiftUI
import UIKit

// r8 account-publish (Claude App): hosts that mount the compiled AccountPublish gap views
// from their MP-equivalent entry points. Each host owns only its own state; contracts stay in Core.

// MARK: - C-D2 入队申请 (MP pages/team/detail/index.js:340-376, wxml:76-95)

extension AccountPublishContractLane {
    enum ApplicantsRead: Equatable {
        case unavailable
        case failed
        case rows([TeamApplicantItem])
    }

    /// `POST /api/team/applications` with JSON `{teamId}`, the same request and row shape as the map team half-sheet
    /// (`NearbyTeamRequest.applications`). Rows decode with `NearbyApplicant` (memberId / memberName / memberAvatar / applyMessage).
    static func teamApplicants(teamID: Int) async -> ApplicantsRead {
        guard isInstalled, let baseURL, teamID > 0 else { return .unavailable }
        let url = baseURL.appendingPathComponent("api/team/applications")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        guard let body = try? JSONSerialization.data(withJSONObject: ["teamId": teamID]) else { return .failed }
        request.httpBody = body
        do {
            let (data, status) = try await send(request)
            guard (200..<300).contains(status),
                  let envelope = try? JSONDecoder().decode(TeamApplicantsEnvelope.self, from: data),
                  envelope.ok else { return .failed }
            return .rows(envelope.data.map {
                TeamApplicantItem(id: $0.memberID.rawValue, userID: $0.memberID.rawValue,
                                  nickname: $0.name.isEmpty ? appLocalized("i18nR3.thisPlayer", locale: .current) : $0.name,
                                  avatarURL: $0.avatar.isEmpty ? nil : $0.avatar,
                                  message: $0.message.isEmpty ? nil : $0.message)
            })
        } catch {
            return .failed
        }
    }
}

private struct TeamApplicantsEnvelope: Decodable {
    let ok: Bool
    let data: [NearbyApplicant]
    enum CodingKeys: String, CodingKey { case code, data }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let code = (try? c.decode(Int.self, forKey: .code)) ?? (try? c.decode(String.self, forKey: .code)).flatMap(Int.init)
        ok = code == 200
        // MP: `code == 200 && Array.isArray(res.data)`, otherwise the error state (never a silent 暂无申请).
        data = ok ? try c.decode([NearbyApplicant].self, forKey: .data) : []
    }
}

/// Leader-only 入队申请 block on the team detail page. The MP shows it only while the team is recruiting
/// (`leader && team.status === 0`); the caller enforces that. A handled row reloads the list from the server.
@MainActor struct TeamDetailApplicantsHost: View {
    let teamID: Int
    @State private var state: TeamDetailGapApplicantsSection.LoadState = .loading
    @State private var hidden = false

    var body: some View {
        Group {
            if !hidden {
                VStack(alignment: .leading) {
                    TeamDetailGapApplicantsSection(
                        state: state,
                        teamID: teamID,
                        onRetry: { Task { await load() } },
                        onReject: { _ in Task { await load() } },
                        onApprove: { _ in Task { await load() } })
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("team.applicants")
            }
        }
        .task(id: teamID) { await load() }
    }

    private func load() async {
        if case .ready = state {} else { state = .loading }
        switch await AccountPublishContractLane.teamApplicants(teamID: teamID) {
        case .unavailable:
            // Design fixtures and signed-out previews have no session lane: keep the page as it was.
            hidden = true
        case .failed:
            hidden = false
            state = .error("")
        case .rows(let rows):
            hidden = false
            state = .ready(rows)
        }
    }
}

// MARK: - C-F5 角色 (MP pages/publish/fabu/index.wxml:172-187, theme-cast.js, utils/publish/story-cast.js)

/// MP `formData.castConfig` in its interface shape: `{enabled, playerName, playerIdentity, identities, cast:[member]}`.
/// The app keeps that object in `ProjectEditDraft.preserved["castConfig"]`. `ProjectEditContract` posts it as the
/// JSON string `serializeCastConfig` sends, and loads the topic or edit-detail value back into the same key.
/// Member fields the app does not edit (avatar, a recorded voice) are kept as they were.
/// One MP player identity (`castConfig.identities[]`: key · title · sub).
public struct ProjectEditCastIdentity: Identifiable, Equatable {
    public let id: String
    public var title: String
    public var sub: String
}

/// MP cast sheet player card: 玩家起名 / 玩家身份 and, when on, up to 4 identities.
public struct ProjectEditCastPlayer: Equatable {
    public var playerName: Bool
    public var playerIdentity: Bool
    public var identities: [ProjectEditCastIdentity]
}

enum ProjectEditCastConfig {
    static let key = "castConfig"
    static let maxCast = 12
    static let nameMax = 8
    static let identityMax = 30
    /// MP story-cast.js COLORS order; a new member takes the first unused colour.
    static let colors = ["E8604C", "3D8BFD", "2FB57A", "B98AF0", "F2B33D", "8E8E93"].map { "#" + $0 }  // payload values, not UI colours
    /// MP story-cast.js PRESETS (value, label) plus 不出声.
    static let voicePresets: [(value: String, labelKey: String)] = [
        ("bright_female", "fixr8.cast.voice.bright_female"), ("warm_female", "fixr8.cast.voice.warm_female"),
        ("deep_male", "fixr8.cast.voice.deep_male"), ("youth", "fixr8.cast.voice.youth"), ("elder", "fixr8.cast.voice.elder")
    ]

    static func root(_ preserved: [String: ProjectEditJSON]) -> [String: ProjectEditJSON]? {
        switch preserved[key] {
        case .object(let object): return object
        case .string(let raw):
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(ProjectEditJSON.self, from: data) else { return nil }
            return decoded.object
        default: return nil
        }
    }

    static func isEnabled(_ preserved: [String: ProjectEditJSON]) -> Bool { root(preserved)?["enabled"] == .bool(true) }

    static func rawMembers(_ preserved: [String: ProjectEditJSON]) -> [[String: ProjectEditJSON]] {
        (root(preserved)?["cast"]?.array ?? []).compactMap(\.object)
    }

    static func members(_ preserved: [String: ProjectEditJSON]) -> [TopicCastMemberDraft] {
        rawMembers(preserved).map { m in
            let voice = m["voice"]?.object
            let preset = voice?["mode"]?.text == "preset" ? voice?["preset"]?.text : nil
            let lines = m["endingLines"]?.object ?? [:]
            let clues: [TopicCastClueDraft] = (m["clues"]?.array ?? []).compactMap(\.object).map { clue in
                let chapter = clue["chapterId"]
                let unlock: ProjectEditJSON? = (chapter == nil || chapter == .null || chapter == .string("")) ? nil : chapter
                return TopicCastClueDraft(text: clue["text"]?.text ?? "", chapterID: unlock)
            }
            let color = m["color"]?.text
            return TopicCastMemberDraft(id: m["id"]?.text ?? UUID().uuidString, name: m["name"]?.text ?? "",
                                        roleTitle: m["identity"]?.text ?? "", voiceID: preset,
                                        colorHex: colors.contains(color ?? "") ? color : nil, clues: clues,
                                        endingLow: lines["low"]?.text ?? "", endingMid: lines["mid"]?.text ?? "",
                                        endingHigh: lines["high"]?.text ?? "")
        }
    }

    /// Switch on: an absent config becomes the MP `emptyCastConfig()`; switch off only sets `enabled=false`.
    static func setEnabled(_ on: Bool, in preserved: inout [String: ProjectEditJSON]) {
        var object = root(preserved) ?? ["enabled": .bool(true), "playerName": .bool(true), "playerIdentity": .bool(false),
                                         "identities": .array([]), "cast": .array([])]
        object["enabled"] = .bool(on)
        preserved[key] = .object(object)
    }

    /// MP story-cast.js `draftView`: blank clues and clues whose unlock chapter was deleted are not saved
    /// (turning them into 开局就有 would show them early; the backend rejects a blank clue with 400).
    /// `chapterIDs == nil` means the chapter list is unknown, so only blank clues are dropped.
    static func savableClues(_ clues: [TopicCastClueDraft], chapterIDs: [ProjectEditJSON]?) -> [TopicCastClueDraft] {
        clues.filter { clue in
            if clue.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            guard let ids = chapterIDs, let unlock = clue.chapterID, unlock != .null else { return true }
            return ids.contains(unlock)
        }
    }

    static func setMembers(_ members: [TopicCastMemberDraft], chapterIDs: [ProjectEditJSON]? = nil,
                           in preserved: inout [String: ProjectEditJSON]) {
        var object = root(preserved) ?? ["enabled": .bool(true), "playerName": .bool(true), "playerIdentity": .bool(false),
                                         "identities": .array([])]
        let previous = Dictionary(rawMembers(preserved).compactMap { m in m["id"]?.text.map { ($0, m) } }, uniquingKeysWith: { a, _ in a })
        var used: [String] = []
        let rows: [ProjectEditJSON] = members.prefix(maxCast).enumerated().map { index, member in
            var row = previous[member.id] ?? [:]
            row["id"] = .string(member.id)
            row["name"] = .string(String(member.name.prefix(nameMax)))
            row["identity"] = .string(String(member.roleTitle.prefix(identityMax)))
            if row["avatarUrl"] == nil { row["avatarUrl"] = .string("") }
            if let chosen = member.colorHex, colors.contains(chosen) {
                row["color"] = .string(chosen)
            } else if row["color"]?.text == nil {
                row["color"] = .string(colors.first { !used.contains($0) } ?? colors[index % colors.count])
            }
            if let color = row["color"]?.text { used.append(color) }
            if let preset = member.voiceID, voicePresets.contains(where: { $0.value == preset }) {
                row["voice"] = .object(["mode": .string("preset"), "preset": .string(preset)])
            } else if row["voice"]?.object?["mode"]?.text != "record" {
                row["voice"] = .object(["mode": .string("none")])
            }
            // MP story-cast.js serialize: clues trimmed (≤6, ≤40), ending lines trimmed (≤60).
            row["clues"] = .array(savableClues(member.clues, chapterIDs: chapterIDs).prefix(maxClues).map { clue in
                .object(["text": .string(String(clue.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(clueMax))),
                         "chapterId": clue.chapterID ?? .null])
            })
            row["endingLines"] = .object([
                "low": .string(String(member.endingLow.trimmingCharacters(in: .whitespacesAndNewlines).prefix(endingLineMax))),
                "mid": .string(String(member.endingMid.trimmingCharacters(in: .whitespacesAndNewlines).prefix(endingLineMax))),
                "high": .string(String(member.endingHigh.trimmingCharacters(in: .whitespacesAndNewlines).prefix(endingLineMax)))
            ])
            return .object(row)
        }
        object["cast"] = .array(rows)
        preserved[key] = .object(object)
    }

    /// MP story-cast.js: at most 4 player identities, title 1–8 characters, line up to 24.
    static let maxIdentities = 4
    /// MP story-cast.js MAX_CLUES / CLUE_MAX / ENDING_LINE_MAX.
    static let maxClues = 6
    static let clueMax = 40
    static let endingLineMax = 60

    /// MP `clueChapterOptions`: 开局就有 (nil) + saved ordinary chapters (no opening / ending), numbered among ordinary chapters.
    static func clueChapters(_ chapters: [ProjectEditChapter]) -> [(value: ProjectEditJSON, number: Int, name: String)] {
        var out: [(value: ProjectEditJSON, number: Int, name: String)] = []
        var n = 0
        for chapter in chapters {
            if chapter.preserved["opening"] == .bool(true) { continue }
            if chapter.preserved["ending"]?.object != nil { continue }
            n += 1
            guard let id = chapter.preserved["id"], id != .null, id != .string("") else { continue }
            out.append((value: id, number: n, name: chapter.name.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return out
    }
    static let identityTitleMax = 8
    static let identitySubMax = 24

    /// MP `castView.playerName / playerIdentity / identities`; an absent config reads as `emptyCastConfig()`.
    static func player(_ preserved: [String: ProjectEditJSON]) -> ProjectEditCastPlayer {
        guard let object = root(preserved) else { return ProjectEditCastPlayer(playerName: true, playerIdentity: false, identities: []) }
        let identities: [ProjectEditCastIdentity] = (object["identities"]?.array ?? []).compactMap(\.object).map { row in
            ProjectEditCastIdentity(id: row["key"]?.text ?? "", title: row["title"]?.text ?? "", sub: row["sub"]?.text ?? "")
        }
        return ProjectEditCastPlayer(playerName: object["playerName"] == .bool(true),
                                     playerIdentity: object["playerIdentity"] == .bool(true),
                                     identities: identities)
    }

    static func setPlayer(_ player: ProjectEditCastPlayer, in preserved: inout [String: ProjectEditJSON]) {
        var object = root(preserved) ?? ["enabled": .bool(true), "cast": .array([])]
        object["playerName"] = .bool(player.playerName)
        object["playerIdentity"] = .bool(player.playerIdentity)
        let rows: [ProjectEditJSON] = player.identities.prefix(maxIdentities).map { identity in
            .object(["key": .string(identity.id),
                     "title": .string(String(identity.title.prefix(identityTitleMax))),
                     "sub": .string(String(identity.sub.prefix(identitySubMax)))])
        }
        object["identities"] = .array(rows)
        preserved[key] = .object(object)
    }

    /// MP `newIdentity`: `i_` + 6 base-36 characters, unique among the identities.
    static func freshIdentityKey(existing: [ProjectEditCastIdentity]) -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        for _ in 0..<50 {
            let id = "i_" + String((0..<6).map { _ in alphabet.randomElement()! })
            if !existing.contains(where: { $0.id == id }) { return id }
        }
        return "i_" + UUID().uuidString.prefix(6).lowercased()
    }

    /// MP `freshId('c_', …)`: `c_` + 6 base-36 characters, unique in this cast.
    static func freshID(existing: [TopicCastMemberDraft]) -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        for _ in 0..<50 {
            let id = "c_" + String((0..<6).map { _ in alphabet.randomElement()! })
            if !existing.contains(where: { $0.id == id }) { return id }
        }
        return "c_" + UUID().uuidString.prefix(6).lowercased()
    }
}

/// 角色 card on the fabu editor: switch + 「N 位」, tap opens the 角色列表 sheet. City themes only, not in the
/// whitelist scope (MP wxml:172 `productType === 1 && editScope !== 'WHITELIST'`). Voice preview stays off:
/// owner decision 2026-11-24 #7 (fixture content, no live cast calls).
@MainActor struct ProjectEditCastHost: View {
    @Binding var preserved: [String: ProjectEditJSON]
    let readOnly: Bool
    var chapters: [ProjectEditChapter] = []
    @State private var editing = false
    @State private var sheetMembers: [TopicCastMemberDraft] = []
    @State private var sheetPlayer = ProjectEditCastPlayer(playerName: true, playerIdentity: false, identities: [])

    var body: some View {
        let enabled = Binding<Bool>(
            get: { ProjectEditCastConfig.isEnabled(preserved) },
            set: { on in ProjectEditCastConfig.setEnabled(on, in: &preserved) })
        ProjectEditGapCastAndLookSection(
            castEnabled: enabled,
            castMembers: ProjectEditCastConfig.members(preserved),
            selectedLookID: nil,
            onOpenCastEditor: {
                sheetMembers = ProjectEditCastConfig.members(preserved)
                sheetPlayer = ProjectEditCastConfig.player(preserved)
                editing = true
            })
        .disabled(readOnly)
        .cySheet(isPresented: $editing, onDismiss: {
            let chapterIDs: [ProjectEditJSON] = chapters.compactMap { chapter in
                guard let id = chapter.preserved["id"], id != .null, id != .string("") else { return nil }
                return id
            }
            ProjectEditCastConfig.setMembers(sheetMembers, chapterIDs: chapterIDs, in: &preserved)
            ProjectEditCastConfig.setPlayer(sheetPlayer, in: &preserved)
        }) {
            ProjectEditGapCastEditorSheet(members: $sheetMembers, player: $sheetPlayer, chapters: chapters, onPreviewVoice: nil)
                .cySheet(detents: [.large])
        }
    }
}

// MARK: - A4-01 据点 → place detail (MP pages/mylike/mylike.wxml:43, mylike.js:435 → subpackageRoam/poi-detail)

/// Opens the same `RoamItemDetailView` the map uses for a place, seeded by `poiId` only. The detail view reads
/// `roamNodeDetail(id:)` itself; the seed carries no coordinate, so nothing is invented before that read lands.
@MainActor struct RoamPOIDetailHost: View {
    @EnvironmentObject private var session: AppSession
    let poiID: Int
    var name: String?

    var body: some View {
        if let place = Self.seed(poiID: poiID, name: name) {
            RoamItemDetailView(item: .place(place), reader: session.roamReader,
                               mediaScope: session.platformConsumers.scope, makeExternalMaps: session.platformConsumers.mapsFactory,
                               stampDestination: { AnyView(SessionRoamStampCameraView()) },
                               posterDestination: { AnyView(SessionRoamPosterView(node: $0)) },
                               eventDestination: { AnyView(RoamNearbyEventsDetailHost(target: $0, session: session)) },
                               couponWalletDestination: session.makeRoamCouponWalletDestination(reader: session.roamReader),
                               embedsNavigationStack: false)
        } else {
            RoamStatusView(issue: .notConfigured)
        }
    }

    /// `RoamPlace` is decode-only; build the seed the same way the list read does (`id`, `name`, `type` 1 = city node).
    static func seed(poiID: Int, name: String?) -> RoamPlace? {
        guard poiID > 0 else { return nil }
        let object: [String: Any] = ["id": poiID, "name": name ?? "", "type": 1]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return try? JSONDecoder().decode(RoamPlace.self, from: data)
    }
}

// MARK: - A1-01 own-profile composer (MP cyp wxml:262-275, js:1225-1245)

/// Shown on the 帖文 tab of the viewer's own profile only; opens the same square composer as the square toolbar.
@MainActor struct OwnProfileComposerHost: View {
    let actions: SocialActionCoordinator
    let offline: Bool
    @State private var composing = false

    var body: some View {
        Section {
            AccountGapOwnProfileComposerRow(joinDateText: nil) { composing = true }
        }
        .cySheet(isPresented: $composing) {
            SquareCloudComposerView(coordinator: actions, offline: offline,
                                    joinedHosted: { offline ? .offline : .permission },
                                    completed: { offline ? .offline : .permission },
                                    onClose: { composing = false })
                .id(actions.identity)
                .cySheet(detents: [.large])
        }
    }
}

// MARK: - C-F7 画面风格 (MP fabu topic-detail-sheet.wxml:79-88, look-sheet.wxml, theme-look-editor.js, utils/publish/theme-look.js)

/// MP `formData.look`: a JSON string sent as `payload.look`. The app keeps it in `ProjectEditDraft.preserved["look"]`,
/// and `topicCarryOver` loads and posts that string. Keys the app does not edit (map, transition) are kept;
/// a style change resets that style's params to the MP defaults, as `onLookStyle` + `normalizeLook` do.
enum ProjectEditLook {
    static let key = "look"
    struct Param { let key: String; let options: [String]; let defaultValue: String }
    struct Style { let value: String; let labelKey: String; let params: [Param] }
    /// MP `STYLES` (theme-look.js): each style's own params, in MP order, with the MP defaults.
    static let styles: [Style] = [
        .init(value: "STARDUST", labelKey: "fixr8.look.style.stardust", params: [
            .init(key: "density", options: ["SPARSE", "NORMAL", "DENSE"], defaultValue: "NORMAL"),
            .init(key: "drift", options: ["SLOW", "NORMAL", "FAST"], defaultValue: "SLOW"),
            .init(key: "tone", options: ["WHITE", "WARM", "COOL"], defaultValue: "WHITE")
        ]),
        .init(value: "PAPER", labelKey: "fixr8.look.style.paper", params: [
            .init(key: "paper", options: ["KRAFT", "XUAN", "CARD"], defaultValue: "KRAFT"),
            .init(key: "grain", options: ["LIGHT", "MEDIUM", "HEAVY"], defaultValue: "MEDIUM"),
            .init(key: "stamp", options: ["VERIFIED", "VISITED", "SEAL"], defaultValue: "VERIFIED")
        ]),
        .init(value: "SURVIVAL", labelKey: "fixr8.look.style.survival", params: [
            .init(key: "climate", options: ["CLEAR", "RAIN", "STORM", "SAND"], defaultValue: "RAIN"),
            .init(key: "volatility", options: ["CALM", "SHIFTING", "VIOLENT"], defaultValue: "SHIFTING"),
            .init(key: "edge", options: ["HP", "FIXED", "OFF"], defaultValue: "HP")
        ]),
        .init(value: "CYBER", labelKey: "fixr8.look.style.cyber", params: [
            .init(key: "neon", options: ["YELLOW_CYAN", "CYAN_PINK", "RED_CYAN"], defaultValue: "YELLOW_CYAN"),
            .init(key: "current", options: ["LOW", "MID", "HIGH"], defaultValue: "MID"),
            .init(key: "glitch", options: ["TRANSITION", "OFF"], defaultValue: "TRANSITION")
        ])
    ]
    static let palettes: [(value: String, labelKey: String)] = [
        ("DEFAULT", "fixr8.look.palette.default"), ("BLUE", "fixr8.look.palette.blue"), ("RED", "fixr8.look.palette.red"),
        ("YELLOW", "fixr8.look.palette.yellow"), ("WHITE", "fixr8.look.palette.white")
    ]
    static let fonts: [(value: String, labelKey: String)] = [
        ("HAND", "fixr8.look.font.hand"), ("SONG", "fixr8.look.font.song"), ("KAI", "fixr8.look.font.kai"),
        ("HEI", "fixr8.look.font.hei"), ("BOLD", "fixr8.look.font.bold")
    ]
    /// MP `TIMES`: one per chapter, 末世 only; "" = this chapter has none.
    static let times = ["DAWN", "NOON", "DUSK", "NIGHT"]
    static let maxTimes = 60
    /// MP `TEXT_FX`; "" = 跟随风格.
    static let textEffects = ["rise", "type", "ink", "gather", "glow", "wipe", "drop", "wind", "signal", "fog", "neon", "scan", "decode"]

    static func paramLabelKey(_ param: String) -> String { "mpPublish.look.param.\(param)" }
    static func optionLabelKey(_ param: String, _ option: String) -> String { "mpPublish.look.option.\(param).\(option.lowercased())" }
    static func timeLabelKey(_ time: String) -> String { "mpPublish.look.time.\(time.lowercased())" }
    static func textEffectLabelKey(_ effect: String) -> String { "mpPublish.look.textFx.\(effect)" }

    static func object(_ preserved: [String: ProjectEditJSON]) -> [String: ProjectEditJSON] {
        switch preserved[key] {
        case .object(let object): return object
        case .string(let raw):
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(ProjectEditJSON.self, from: data) else { return [:] }
            return decoded.object ?? [:]
        default: return [:]
        }
    }

    static func style(_ preserved: [String: ProjectEditJSON]) -> String {
        let raw = (object(preserved)["style"]?.text ?? "").uppercased()
        return styles.contains { $0.value == raw } ? raw : "STARDUST"
    }
    static func styleDefinition(_ preserved: [String: ProjectEditJSON]) -> Style {
        let current = style(preserved)
        return styles.first { $0.value == current } ?? styles[0]
    }
    static func palette(_ preserved: [String: ProjectEditJSON]) -> String {
        let raw = (object(preserved)["palette"]?.text ?? "").uppercased()
        return palettes.contains { $0.value == raw } ? raw : ""
    }
    static func font(_ preserved: [String: ProjectEditJSON]) -> String {
        let raw = (object(preserved)["storyFont"]?.text ?? "").uppercased()
        return fonts.contains { $0.value == raw } ? raw : "HAND"
    }
    /// MP `normalizeLook` for one param: an unknown value falls back to the style default.
    static func param(_ preserved: [String: ProjectEditJSON], _ param: Param) -> String {
        let raw = (object(preserved)["params"]?.object?[param.key]?.text ?? "").uppercased()
        return param.options.contains(raw) ? raw : param.defaultValue
    }
    static func time(_ preserved: [String: ProjectEditJSON], chapter index: Int) -> String {
        let list = object(preserved)["times"]?.array ?? []
        guard index >= 0, index < list.count else { return "" }
        let raw = (list[index].text ?? "").uppercased()
        return times.contains(raw) ? raw : ""
    }
    static func textEffect(_ preserved: [String: ProjectEditJSON]) -> String {
        let raw = (object(preserved)["textFx"]?.text ?? "").lowercased()
        return textEffects.contains(raw) ? raw : ""
    }

    static func update(_ preserved: inout [String: ProjectEditJSON], style newStyle: String? = nil, palette: String? = nil, font: String? = nil) {
        var look = object(preserved)
        let current = style(preserved)
        if look["style"] == nil { look["style"] = .string(current) }
        if look["transition"] == nil { look["transition"] = .string("AUTO") }
        if look["storyFont"] == nil { look["storyFont"] = .string("HAND") }
        if look["params"]?.object == nil || (newStyle != nil && newStyle != current) {
            let target = newStyle ?? current
            let defaults = styles.first { $0.value == target }?.params ?? []
            var params: [String: ProjectEditJSON] = [:]
            for item in defaults { params[item.key] = .string(item.defaultValue) }
            look["params"] = .object(params)
        }
        if let newStyle {
            look["style"] = .string(newStyle)
            look["transition"] = .string("AUTO")
            if newStyle != "SURVIVAL" { look["times"] = nil }
        }
        if let palette { if palette.isEmpty { look["palette"] = nil } else { look["palette"] = .string(palette) } }
        if let font { look["storyFont"] = .string(font) }
        write(look, into: &preserved)
    }

    /// MP `onLookParam`.
    static func update(_ preserved: inout [String: ProjectEditJSON], param: Param, value: String) {
        update(&preserved)
        var look = object(preserved)
        var params = look["params"]?.object ?? [:]
        params[param.key] = .string(value)
        look["params"] = .object(params)
        write(look, into: &preserved)
    }

    /// MP `onLookTime`: pad with "" up to the chapter, then drop trailing blanks (`normalizeLook`).
    static func update(_ preserved: inout [String: ProjectEditJSON], chapter index: Int, time: String) {
        guard index >= 0, index < maxTimes else { return }
        update(&preserved)
        var look = object(preserved)
        var list = (look["times"]?.array ?? []).map { $0.text ?? "" }
        while list.count <= index { list.append("") }
        list[index] = time
        while let last = list.last, last.isEmpty { list.removeLast() }
        look["times"] = list.isEmpty ? nil : .array(list.map { ProjectEditJSON.string($0) })
        write(look, into: &preserved)
    }

    /// MP `onLookTextFx`: "" removes the key (跟随风格).
    static func update(_ preserved: inout [String: ProjectEditJSON], textEffect: String) {
        update(&preserved)
        var look = object(preserved)
        look["textFx"] = textEffect.isEmpty ? nil : .string(textEffect)
        write(look, into: &preserved)
    }

    private static func write(_ look: [String: ProjectEditJSON], into preserved: inout [String: ProjectEditJSON]) {
        guard let data = try? JSONEncoder().encode(ProjectEditJSON.object(look)),
              let text = String(data: data, encoding: .utf8) else { return }
        preserved[key] = .string(text)
    }
}

/// 画面风格 card in the 主题详情 sheet (MP topic-detail-sheet.wxml:79): title + summary 风格 · 主题配色 · 字体,
/// tap opens the MP look sheet as a pushed page.
@MainActor struct ProjectEditLookHost: View {
    @Binding var preserved: [String: ProjectEditJSON]
    let readOnly: Bool
    var chapterNames: [String] = []

    var body: some View {
        Section {
            NavigationLink {
                ProjectEditLookPage(preserved: $preserved, readOnly: readOnly, chapterNames: chapterNames)
            } label: {
                LabeledContent {
                    summary
                } label: {
                    Label("fixr8.look.title", systemImage: "photo")
                }
            }
            .accessibilityIdentifier("projectEdit.look.open")
        }
    }

    private var summary: Text {
        let style = ProjectEditLook.styleDefinition(preserved)
        let palette = ProjectEditLook.palette(preserved)
        let paletteKey = ProjectEditLook.palettes.first { $0.value == palette }?.labelKey ?? "fixr8.look.palette.chapter"
        let fontKey = ProjectEditLook.fonts.first { $0.value == ProjectEditLook.font(preserved) }?.labelKey ?? "fixr8.look.font.hand"
        return Text(LocalizedStringKey(style.labelKey)) + Text(verbatim: " · ") + Text(LocalizedStringKey(paletteKey))
            + Text(verbatim: " · ") + Text(LocalizedStringKey(fontKey))
    }
}

/// MP look-sheet.wxml in MP order: 风格 → this style's params → (末世) each chapter's time → 主题配色 → 字体 → 文字动效.
/// A choice applies at once, as on the MP (no save button). The live preview (`cy-look-preview`) is not ported.
@MainActor struct ProjectEditLookPage: View {
    @Binding var preserved: [String: ProjectEditJSON]
    let readOnly: Bool
    let chapterNames: [String]

    var body: some View {
        Form {
            Section {
                Picker(selection: Binding(get: { ProjectEditLook.style(preserved) },
                                          set: { ProjectEditLook.update(&preserved, style: $0) })) {
                    ForEach(ProjectEditLook.styles, id: \.value) { Text(LocalizedStringKey($0.labelKey)).tag($0.value) }
                } label: { Text("fixr8.look.style") }
                .accessibilityIdentifier("projectEdit.look.style")
            }
            Section {
                ForEach(ProjectEditLook.styleDefinition(preserved).params, id: \.key) { param in
                    Picker(selection: Binding(get: { ProjectEditLook.param(preserved, param) },
                                              set: { ProjectEditLook.update(&preserved, param: param, value: $0) })) {
                        ForEach(param.options, id: \.self) { option in
                            Text(LocalizedStringKey(ProjectEditLook.optionLabelKey(param.key, option))).tag(option)
                        }
                    } label: { Text(LocalizedStringKey(ProjectEditLook.paramLabelKey(param.key))) }
                    .accessibilityIdentifier("projectEdit.look.param.\(param.key)")
                }
            }
            if ProjectEditLook.style(preserved) == "SURVIVAL", !chapterNames.isEmpty {
                Section {
                    ForEach(Array(chapterNames.prefix(ProjectEditLook.maxTimes).enumerated()), id: \.offset) { item in
                        Picker(selection: Binding(get: { ProjectEditLook.time(preserved, chapter: item.offset) },
                                                  set: { ProjectEditLook.update(&preserved, chapter: item.offset, time: $0) })) {
                            Text("mpPublish.look.time.none").tag("")
                            ForEach(ProjectEditLook.times, id: \.self) { time in
                                Text(LocalizedStringKey(ProjectEditLook.timeLabelKey(time))).tag(time)
                            }
                        } label: { chapterLabel(item.offset, item.element) }
                    }
                }
            }
            Section {
                Picker(selection: Binding(get: { ProjectEditLook.palette(preserved) },
                                          set: { ProjectEditLook.update(&preserved, palette: $0) })) {
                    Text("fixr8.look.palette.chapter").tag("")
                    ForEach(ProjectEditLook.palettes, id: \.value) { Text(LocalizedStringKey($0.labelKey)).tag($0.value) }
                } label: { Text("fixr8.look.palette") }
                .accessibilityIdentifier("projectEdit.look.palette")
            }
            Section {
                Picker(selection: Binding(get: { ProjectEditLook.font(preserved) },
                                          set: { ProjectEditLook.update(&preserved, font: $0) })) {
                    ForEach(ProjectEditLook.fonts, id: \.value) { Text(LocalizedStringKey($0.labelKey)).tag($0.value) }
                } label: { Text("fixr8.look.font") }
                .accessibilityIdentifier("projectEdit.look.font")
                Picker(selection: Binding(get: { ProjectEditLook.textEffect(preserved) },
                                          set: { ProjectEditLook.update(&preserved, textEffect: $0) })) {
                    Text("mpPublish.look.textFx.auto").tag("")
                    ForEach(ProjectEditLook.textEffects, id: \.self) { effect in
                        Text(LocalizedStringKey(ProjectEditLook.textEffectLabelKey(effect))).tag(effect)
                    }
                } label: { Text("mpPublish.look.textFx") }
                .accessibilityIdentifier("projectEdit.look.textFx")
            }
        }
        .disabled(readOnly)
        .navigationTitle(Text("fixr8.look.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func chapterLabel(_ index: Int, _ name: String) -> some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("castMember.clue.chapterNumber \(index + 1)")
        } else {
            Text(verbatim: trimmed)
        }
    }
}

// MARK: - C-A4 发起人信息 (MP pages/publish/activity/index.wxml:135, index.js:1302-1342)

/// The MP reads `/api/user/info` for the publisher on step 3 and shows only a failure: 发起人信息未加载 with
/// 发起人信息加载失败，请重试 and 重试. A good read shows nothing. Hosts without the contract lane show nothing.
@MainActor final class ActivityPublishOrganizerRead: ObservableObject {
    @Published private(set) var failed = false
    @Published private(set) var loading = false

    func load() async {
        guard AccountPublishContractLane.isInstalled, !loading else { return }
        loading = true
        defer { loading = false }
        guard let (data, status) = try? await AccountPublishContractLane.userInfo(), (200..<300).contains(status),
              AccountPublishMPContract.activityOwner(from: data) != nil else { failed = true; return }
        failed = false
    }
}

@MainActor struct ActivityPublishOrganizerHost: View {
    @ObservedObject var read: ActivityPublishOrganizerRead

    var body: some View {
        if read.failed {
            Section {
                ContentUnavailableView {
                    Label("fixr8.activity.organizerFailed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("fixr8.activity.organizerFailedDetail")
                } actions: {
                    Button("重试") { Task { await read.load() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("activityPublish.organizer.retry")
                }
                .disabled(read.loading)
            }
        }
    }
}

// MARK: - C-D11-r7 邀请卡 保存图片 (MP team/detail wxml:157-159: wx.saveImageToPhotosAlbum behind the in-page privacy gate)

/// Downloads the server's team code image (https only) and adds it to Photos (add-only access; the system asks once,
/// with `NSPhotoLibraryAddUsageDescription`). The in-page notice comes first, as on the MP.
@MainActor struct TeamInviteImageSaveRow: View {
    let imageURL: URL
    @State private var phase: Phase = .idle
    enum Phase: Equatable { case idle, saving, saved, failed }

    var body: some View {
        VStack(alignment: .leading) {
            TeamDetailGapSaveInviteImageRow { save() }
                .disabled(phase == .saving)
                .accessibilityIdentifier("team.invite.saveImage")
            switch phase {
            case .saving: ProgressView().controlSize(.small)
            case .saved: Text("fixr8.team.saveImage.saved").font(.footnote).foregroundStyle(CYColor.successText)
            case .failed: Text("fixr8.team.saveImage.failed").font(.footnote).foregroundStyle(CYColor.dangerText)
            case .idle: EmptyView()
            }
        }
    }

    private func save() {
        guard phase != .saving, imageURL.scheme == "https" else { phase = .failed; return }
        phase = .saving
        Task {
            guard let (data, response) = try? await URLSession.shared.data(from: imageURL),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false,
                  let image = UIImage(data: data) else { phase = .failed; return }
            phase = await TeamInvitePhotoSaver.save(image) ? .saved : .failed
        }
    }
}

/// `UIImageWriteToSavedPhotosAlbum` with its completion selector bridged to async.
@MainActor final class TeamInvitePhotoSaver: NSObject {
    private var continuation: CheckedContinuation<Bool, Never>?
    private static var active: Set<TeamInvitePhotoSaver> = []

    static func save(_ image: UIImage) async -> Bool {
        let saver = TeamInvitePhotoSaver()
        active.insert(saver)
        defer { active.remove(saver) }
        return await withCheckedContinuation { continuation in
            saver.continuation = continuation
            UIImageWriteToSavedPhotosAlbum(image, saver, #selector(TeamInvitePhotoSaver.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        continuation?.resume(returning: error == nil)
        continuation = nil
    }
}

// MARK: - B-SZ-12b `pages/shezhi/shezhi?scene=settings-identity-picker` (MP utils/scene-registry.js:27)

/// 选择要申请的身份: the identity application rows from Settings, on their own page. Reads `/api/user/info` the same
/// way Settings does; signed-out, denied and failed reads show their state instead of the rows.
@MainActor struct SettingsIdentityPickerHost: View {
    @ObservedObject var session: AppSession
    @State private var profile: SettingsAccountProfile?
    @State private var state: ReadState = .loading
    enum ReadState: Equatable { case loading, ready, signedOut, denied, failed }

    var body: some View {
        List {
            switch state {
            case .loading:
                HStack {
                    Text("fixr8.settings.identityPicker.loading")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.identityPicker.loading")
            case .signedOut:
                ContentUnavailableView("fixr8.settings.identityPicker.signedOut", systemImage: "person.crop.circle")
            case .denied:
                ContentUnavailableView {
                    Label { Text(verbatim: SettingsAccountProfileClient.deniedCopy) } icon: { Image(systemName: "lock") }
                }
            case .failed:
                ContentUnavailableView {
                    Label("fixr8.settings.identityPicker.failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("重试") { Task { await load() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("settings.identityPicker.retry")
                }
            case .ready:
                if let profile, SettingsIdentityApplications.isOffered(toRole: profile.role, isClubLeader: profile.isClubLeader) {
                    SettingsIdentityApplicationEntries(session: session, profile: profile)
                        .environment(\.settingsTileTint, SettingsTint.orange)
                } else {
                    ContentUnavailableView("fixr8.settings.identityPicker.none", systemImage: "checkmark.seal")
                }
            }
        }
        .navigationTitle(Text("fixr8.settings.identityPicker.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        state = .loading
        guard let memberID = session.account?.id, memberID > 0,
              let token = session.token, AuthRequestBuilder.isValidToken(token),
              let api = session.regionalConfiguration?.apiConfiguration else {
            state = session.account == nil ? .signedOut : .failed
            return
        }
        do {
            let request = try AccountPublishMPContract.userInfoRequest(baseURL: api.baseURL, memberID: String(memberID), token: token)
            let (data, status) = try await session.runtimeHTTPTransport.send(request)
            switch AccountPublishMPContract.settingsAccess(status: status, body: data) {
            case .signedOut: state = .signedOut
            case .denied: state = .denied
            case .failed: state = .failed
            case .ready(let read):
                let home = AccountPublishMPContract.homeAccount(from: data)
                profile = SettingsAccountProfile(role: read.role, isClubLeader: home?.isClubLeader == true || read.role == "club")
                state = .ready
            }
        } catch {
            state = .failed
        }
    }
}

// MARK: - C-I9-r7 floating covers (MP pages/publish/template-intro/index.wxml:9-11, orbit.js)

/// The intro's featured covers drift slowly, each on its own period. Reduce Motion keeps them still.
struct TemplateIntroFloatingCover: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion ? 0 : (lifted ? -6 : 6))
            .rotationEffect(.degrees(reduceMotion ? 0 : (lifted ? 0.8 : -0.8) * (index.isMultiple(of: 2) ? 1 : -1)))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.6 + Double(index % 3) * 0.7).repeatForever(autoreverses: true)) { lifted = true }
            }
            .onChange(of: reduceMotion) { _, reduced in if reduced { lifted = false } }
    }
}

// MARK: - A2-08 own club posts on 帖文 (MP cy/profile index.js:2104-2128, wxml:277-282)

/// Self only: the viewer's club posts (`POST /api/club/post/feed {scope:all, author:me, limit:20}`), after the
/// community posts. A row opens the club with that post (`pages/club/detail?id=&postId=`). A failed read draws
/// nothing, as on the MP (the community list owns the empty / error state).
@MainActor struct OwnProfileClubPostsSection: View {
    @State private var posts: [AccountPublishMPContract.ClubFeedPost] = []
    @Environment(\.locale) private var locale

    var body: some View {
        Section {
            ForEach(Array(posts.enumerated()), id: \.offset) { _, post in
                if let clubID = post.clubID, clubID > 0 {
                    NavigationLink {
                        MPReviewedPageScreen(page: "pages/club/detail/index",
                                             query: ["id": String(clubID)].merging(post.id.map { ["postId": String($0)] } ?? [:]) { a, _ in a })
                    } label: { row(post) }
                    .accessibilityIdentifier("profile.clubPost.\(post.id ?? 0)")
                } else {
                    row(post)
                }
            }
        }
        .task { await load() }
    }

    private func row(_ post: AccountPublishMPContract.ClubFeedPost) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Label("fixr8.profile.clubPost", systemImage: "person.3").labelStyle(.titleAndIcon)
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if !post.formattedCreateTime.isEmpty {
                    Text(verbatim: LocaleDisplay.isChinese(locale) ? post.formattedCreateTime : LocaleDisplay.civil(post.createTime, locale: locale)).font(.subheadline).foregroundStyle(.tertiary)
                }
            }
            if !post.content.isEmpty {
                Text(verbatim: post.content).font(.body).foregroundStyle(.primary).lineLimit(4)
            }
            if !post.images.isEmpty {
                HStack {
                    ForEach(Array(post.images.prefix(3).enumerated()), id: \.offset) { _, raw in
                        if let url = URL(string: raw), url.scheme == "https" {
                            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }
                                .frame(width: 72, height: 72)
                                .clipped()
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        guard AccountPublishContractLane.isInstalled, let baseURL = AccountPublishContractLane.baseURL,
              let request = try? AccountPublishMPContract.ownClubPostsRequest(baseURL: baseURL, token: AccountPublishContractLane.token),
              let (data, status) = try? await AccountPublishContractLane.send(request), (200..<300).contains(status) else { return }
        posts = AccountPublishMPContract.ownClubPosts(from: data)
    }
}
