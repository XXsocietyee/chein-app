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
        .sheet(isPresented: $composing) {
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

/// MP `formData.look`: a JSON string sent as `payload.look`. The app keeps it in `ProjectEditDraft.preserved["look"]`
/// (the payload carries it once Core lists `look` in `topicCarryOver`). Keys the app does not edit (map, times, textFx,
/// transition) are kept; a style change resets that style's params to the MP defaults, as `normalizeLook` does.
enum ProjectEditLook {
    static let key = "look"
    struct Style { let value: String; let labelKey: String; let params: [String: String] }
    static let styles: [Style] = [
        .init(value: "STARDUST", labelKey: "fixr8.look.style.stardust", params: ["density": "NORMAL", "drift": "SLOW", "tone": "WHITE"]),
        .init(value: "PAPER", labelKey: "fixr8.look.style.paper", params: ["paper": "KRAFT", "grain": "MEDIUM", "stamp": "VERIFIED"]),
        .init(value: "SURVIVAL", labelKey: "fixr8.look.style.survival", params: ["climate": "RAIN", "volatility": "SHIFTING", "edge": "HP"]),
        .init(value: "CYBER", labelKey: "fixr8.look.style.cyber", params: ["neon": "YELLOW_CYAN", "current": "MID", "glitch": "TRANSITION"])
    ]
    static let palettes: [(value: String, labelKey: String)] = [
        ("DEFAULT", "fixr8.look.palette.default"), ("BLUE", "fixr8.look.palette.blue"), ("RED", "fixr8.look.palette.red"),
        ("YELLOW", "fixr8.look.palette.yellow"), ("WHITE", "fixr8.look.palette.white")
    ]
    static let fonts: [(value: String, labelKey: String)] = [
        ("HAND", "fixr8.look.font.hand"), ("SONG", "fixr8.look.font.song"), ("KAI", "fixr8.look.font.kai"),
        ("HEI", "fixr8.look.font.hei"), ("BOLD", "fixr8.look.font.bold")
    ]

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
    static func palette(_ preserved: [String: ProjectEditJSON]) -> String {
        let raw = (object(preserved)["palette"]?.text ?? "").uppercased()
        return palettes.contains { $0.value == raw } ? raw : ""
    }
    static func font(_ preserved: [String: ProjectEditJSON]) -> String {
        let raw = (object(preserved)["storyFont"]?.text ?? "").uppercased()
        return fonts.contains { $0.value == raw } ? raw : "HAND"
    }

    static func update(_ preserved: inout [String: ProjectEditJSON], style newStyle: String? = nil, palette: String? = nil, font: String? = nil) {
        var look = object(preserved)
        let current = style(preserved)
        if look["style"] == nil { look["style"] = .string(current) }
        if look["transition"] == nil { look["transition"] = .string("AUTO") }
        if look["storyFont"] == nil { look["storyFont"] = .string("HAND") }
        if look["params"]?.object == nil || (newStyle != nil && newStyle != current) {
            let target = newStyle ?? current
            let defaults = styles.first { $0.value == target }?.params ?? [:]
            look["params"] = .object(defaults.mapValues { ProjectEditJSON.string($0) })
        }
        if let newStyle { look["style"] = .string(newStyle) }
        if let palette { if palette.isEmpty { look["palette"] = nil } else { look["palette"] = .string(palette) } }
        if let font { look["storyFont"] = .string(font) }
        guard let data = try? JSONEncoder().encode(ProjectEditJSON.object(look)),
              let text = String(data: data, encoding: .utf8) else { return }
        preserved[key] = .string(text)
    }
}

/// 画面风格 row on the fabu editor: style, 主题配色 (unset keeps each chapter's own colours) and 故事字体.
@MainActor struct ProjectEditLookHost: View {
    @Binding var preserved: [String: ProjectEditJSON]
    let readOnly: Bool

    var body: some View {
        Section {
            Picker(selection: Binding(get: { ProjectEditLook.style(preserved) },
                                      set: { ProjectEditLook.update(&preserved, style: $0) })) {
                ForEach(ProjectEditLook.styles, id: \.value) { Text(LocalizedStringKey($0.labelKey)).tag($0.value) }
            } label: { Text("fixr8.look.style") }
            .accessibilityIdentifier("projectEdit.look.style")
            Picker(selection: Binding(get: { ProjectEditLook.palette(preserved) },
                                      set: { ProjectEditLook.update(&preserved, palette: $0) })) {
                Text("fixr8.look.palette.chapter").tag("")
                ForEach(ProjectEditLook.palettes, id: \.value) { Text(LocalizedStringKey($0.labelKey)).tag($0.value) }
            } label: { Text("fixr8.look.palette") }
            .accessibilityIdentifier("projectEdit.look.palette")
            Picker(selection: Binding(get: { ProjectEditLook.font(preserved) },
                                      set: { ProjectEditLook.update(&preserved, font: $0) })) {
                ForEach(ProjectEditLook.fonts, id: \.value) { Text(LocalizedStringKey($0.labelKey)).tag($0.value) }
            } label: { Text("fixr8.look.font") }
            .accessibilityIdentifier("projectEdit.look.font")
        } header: {
            Text("fixr8.look.title").cyText(.sectionTitle)
        }
        .disabled(readOnly)
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
                CYEmptyState(systemImage: "exclamationmark.triangle", "fixr8.activity.organizerFailed",
                             detail: "fixr8.activity.organizerFailedDetail", actionTitle: "重试",
                             actionIdentifier: "activityPublish.organizer.retry", kind: .failure,
                             action: { Task { await read.load() } })
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
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            TeamDetailGapSaveInviteImageRow { save() }
                .disabled(phase == .saving)
                .frame(minHeight: 44)
                .accessibilityIdentifier("team.invite.saveImage")
            switch phase {
            case .saving: ProgressView().controlSize(.small)
            case .saved: Text("fixr8.team.saveImage.saved").cyText(.meta).foregroundStyle(CYColor.successText)
            case .failed: Text("fixr8.team.saveImage.failed").cyText(.meta).foregroundStyle(CYColor.dangerText)
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
                CYLoadingState("fixr8.settings.identityPicker.loading", messageIdentifier: "settings.identityPicker.loading")
            case .signedOut:
                CYEmptyState(systemImage: "person.crop.circle", "fixr8.settings.identityPicker.signedOut")
            case .denied:
                CYEmptyState(systemImage: "lock", verbatimTitle: SettingsAccountProfileClient.deniedCopy)
            case .failed:
                CYEmptyState(systemImage: "exclamationmark.triangle", "fixr8.settings.identityPicker.failed",
                             actionTitle: "重试", actionIdentifier: "settings.identityPicker.retry", kind: .failure,
                             action: { Task { await load() } })
            case .ready:
                if let profile, SettingsIdentityApplications.isOffered(toRole: profile.role, isClubLeader: profile.isClubLeader) {
                    SettingsIdentityApplicationEntries(session: session, profile: profile)
                        .environment(\.settingsTileTint, SettingsTint.orange)
                } else {
                    CYEmptyState(systemImage: "checkmark.seal", "fixr8.settings.identityPicker.none")
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
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.xs) {
                Label("fixr8.profile.clubPost", systemImage: "person.3").labelStyle(.titleAndIcon)
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Spacer()
                if !post.formattedCreateTime.isEmpty {
                    Text(verbatim: post.formattedCreateTime).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }
            }
            if !post.content.isEmpty {
                Text(verbatim: post.content).cyText(.body).foregroundStyle(CYColor.textPrimary).lineLimit(4)
            }
            if !post.images.isEmpty {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(Array(post.images.prefix(3).enumerated()), id: \.offset) { _, raw in
                        if let url = URL(string: raw), url.scheme == "https" {
                            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { CYColor.bgSurfaceSubtle }
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        guard AccountPublishContractLane.isInstalled, let baseURL = AccountPublishContractLane.baseURL,
              let request = try? AccountPublishMPContract.ownClubPostsRequest(baseURL: baseURL, token: AccountPublishContractLane.token),
              let (data, status) = try? await AccountPublishContractLane.send(request), (200..<300).contains(status) else { return }
        posts = AccountPublishMPContract.ownClubPosts(from: data)
    }
}
