import SwiftUI

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
                                  nickname: $0.name.isEmpty ? "这位玩家" : $0.name,
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
        data = (try? c.decode([NearbyApplicant].self, forKey: .data)) ?? []
        if ok, !c.contains(.data) { throw DecodingError.keyNotFound(CodingKeys.data, .init(codingPath: [], debugDescription: "data")) }
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
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
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
/// The app keeps it in `ProjectEditDraft.preserved["castConfig"]`, so local drafts keep it and the save payload carries
/// it once Core lists `castConfig` in `ProjectEditContract.topicCarryOver` (see the r8 receipt, "for Cursor").
/// Member fields the app does not edit (avatar, colour, clues, ending lines) are kept as they were.
enum ProjectEditCastConfig {
    static let key = "castConfig"
    static let maxCast = 12
    static let nameMax = 8
    static let identityMax = 30
    /// MP story-cast.js COLORS order; a new member takes the first unused colour.
    static let colors = ["#E8604C", "#3D8BFD", "#2FB57A", "#B98AF0", "#F2B33D", "#8E8E93"]
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
            return TopicCastMemberDraft(id: m["id"]?.text ?? UUID().uuidString, name: m["name"]?.text ?? "",
                                        roleTitle: m["identity"]?.text ?? "", voiceID: preset)
        }
    }

    /// Switch on: an absent config becomes the MP `emptyCastConfig()`; switch off only sets `enabled=false`.
    static func setEnabled(_ on: Bool, in preserved: inout [String: ProjectEditJSON]) {
        var object = root(preserved) ?? ["enabled": .bool(true), "playerName": .bool(true), "playerIdentity": .bool(false),
                                         "identities": .array([]), "cast": .array([])]
        object["enabled"] = .bool(on)
        preserved[key] = .object(object)
    }

    static func setMembers(_ members: [TopicCastMemberDraft], in preserved: inout [String: ProjectEditJSON]) {
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
            if row["color"]?.text == nil {
                row["color"] = .string(colors.first { !used.contains($0) } ?? colors[index % colors.count])
            }
            if let color = row["color"]?.text { used.append(color) }
            if let preset = member.voiceID, voicePresets.contains(where: { $0.value == preset }) {
                row["voice"] = .object(["mode": .string("preset"), "preset": .string(preset)])
            } else if row["voice"]?.object?["mode"]?.text != "record" {
                row["voice"] = .object(["mode": .string("none")])
            }
            if row["clues"] == nil { row["clues"] = .array([]) }
            if row["endingLines"] == nil {
                row["endingLines"] = .object(["low": .string(""), "mid": .string(""), "high": .string("")])
            }
            return .object(row)
        }
        object["cast"] = .array(rows)
        preserved[key] = .object(object)
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
    @State private var editing = false
    @State private var sheetMembers: [TopicCastMemberDraft] = []

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
                editing = true
            })
        .disabled(readOnly)
        .sheet(isPresented: $editing, onDismiss: { ProjectEditCastConfig.setMembers(sheetMembers, in: &preserved) }) {
            ProjectEditGapCastEditorSheet(members: $sheetMembers, onPreviewVoice: nil)
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
                               couponWalletDestination: session.makeRoamCouponWalletDestination(reader: session.roamReader))
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
