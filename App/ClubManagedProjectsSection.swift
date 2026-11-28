import SwiftUI

/// CLB-detail-09: one 管理 project row from `/api/club/topics` (MP `decorateTopicCard`, detail js:329-342).
struct ClubManagedProjectRow: Identifiable, Equatable {
    let id: Int
    let name: String?
    let cover: URL?
    /// MP `item.nextSessionStart ? item.timeText : '还没有场次'` (wxml:461). Nil = no upcoming session.
    let nextSessionText: String?
    /// MP `item.signupCount != null ? N + ' 人报名' : '—'`.
    let signupCount: Int?
    /// MP wxml:465-468: 活动导演台 for the owner or an admin when the topic has the game module.
    let showsDirector: Bool

    init?(value: ClubGovernanceValue, showsDirector: Bool, locale: Locale) {
        guard let id = value["id"].int, id > 0 else { return nil }
        self.id = id
        let trimmed = value["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = trimmed.isEmpty ? nil : trimmed
        if let raw = value["imgUrl"].string, let url = URL(string: raw), url.scheme == "https", url.host != nil {
            cover = url
        } else {
            cover = nil
        }
        let next = value["nextSessionStart"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        nextSessionText = next.isEmpty ? nil : Self.eventTimeText(next, locale: locale)
        signupCount = value["signupCount"].int
        let gameModule = value["gameModuleEnabled"].bool == true || value["gameModuleEnabled"].int == 1
        self.showsDirector = showsDirector && gameModule
    }

    /// MP `eventTimeText` (js:299-306): 「周六 11月29日, 14:00」 in China time; a bare date drops the clock.
    static func eventTimeText(_ raw: String, locale: Locale) -> String {
        guard let date = ClubActivitySourceTime.date(raw) else {
            return LocaleDisplay.civil(String(raw.prefix(16)).replacingOccurrences(of: "T", with: " "), locale: locale)
        }
        let dateOnly = raw.range(of: #"^\d{4}[-/]\d{1,2}[-/]\d{1,2}$"#, options: .regularExpression) != nil
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.setLocalizedDateFormatFromTemplate(dateOnly ? "EEE MMMd" : "EEE MMMd jmm")
        return formatter.string(from: date)
    }
}

/// MP `topicState` (detail js:2265-2316): loading → skeleton, error → 项目列表加载失败, ready → rows or empty.
enum ClubManagedProjectsState: Equatable {
    case idle, loading, failed, ready
}

/// MP `chooseActivityTool` (detail js:1179-1215) permissions for 本场工具.
struct ClubManagedProjectPermissions: Equatable {
    var isOwner = false
    var isAdmin = false
    var canManageActivities = false
    var canOperateEvents = false
    var canCheckInEvents = false
    var canManageRoles = false

    /// 现场名册与核销 → operate or check-in; 分配领队与核销员 → owner or role manager; 通知本场成员 → operate.
    var tools: [ClubSessionToolChoice] {
        let operate = isOwner || canManageActivities || canOperateEvents || isAdmin
        let checkIn = isOwner || canManageActivities || canCheckInEvents || isAdmin
        var result: [ClubSessionToolChoice] = []
        if operate || checkIn { result.append(.rosterAndVerify) }
        if isOwner || canManageRoles { result.append(.assignLeader) }
        if operate { result.append(.notifySessionMembers) }
        return result
    }
}

/// CLB-detail-09 / CLB-r7-A-04: the 管理 project list (MP detail wxml:453-482) in a system inset-grouped `Section`.
/// - Row tap → the club topic page (`goManageTopic` js:2976-2987).
/// - 活动导演台 (`goGameDirector` js:2989-3009): read sessions; none → 还没有可管理的活动场次; one → open; several → 选择场次.
/// - 场次工具 (`openActivityTools` js:1110-1157): read sessions; a failed read stays silent; none → 这个项目还没有可管理的具体场次;
///   one → 本场工具; several → 选择场次. 本场工具 opens the only tool directly, else a confirmation dialog.
/// Notices sit in the section footer instead of a toast.
@MainActor struct ClubManagedProjectsSection: View {
    @ObservedObject var model: ClubDetailR8MountModel
    let clubID: Int
    let access: any ClubGovernanceAccess
    let permissions: ClubManagedProjectPermissions
    /// MP wxml:453: the owner whose stage is 发布主题 sees the stage card instead of an empty project list.
    let hidesEmpty: Bool
    let onRetry: () -> Void
    let onOpenTopic: (Int) -> Void
    /// MP `onCreateTeam`; nil for viewers who may not publish (they get 暂无分配给你的项目).
    let onPublish: (() -> Void)?
    let open: (ClubDetailR8Route) -> Void

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var coverSide: CGFloat = 56
    @State private var busyTopicID: Int?
    @State private var notice: LocalizedStringKey?
    @State private var picker: SessionPicker?
    @State private var toolTarget: ToolTarget?

    private struct SessionPicker: Identifiable {
        enum Purpose { case director, tools }
        let topicID: Int
        let purpose: Purpose
        let sessions: [ClubManagedDirectorSession]
        var id: Int { topicID }
    }

    private struct ToolTarget {
        let topicID: Int
        let session: ClubManagedDirectorSession
    }

    var body: some View {
        if !(hidesEmpty && model.projectsState == .ready && model.projects.isEmpty) {
            Section {
                content
            } footer: {
                if let notice {
                    Text(notice)
                        .accessibilityIdentifier("club.projects.notice")
                }
            }
            .cySheet(item: $picker) { picker in
                sessionPicker(picker)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog(Text("club.projects.sessionTools"), isPresented: toolDialogShown, titleVisibility: .visible) {
                if let target = toolTarget {
                    ForEach(permissions.tools) { tool in
                        Button(toolTitle(tool)) { openTool(tool, target: target) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.projectsState {
        case .idle, .loading:
            // MP `cy-skeleton type="list" count="2"` → mp-states r3: the one loading pattern, a labelled ProgressView.
            ProgressView { Text("club.projects.placeholder") }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("club.projects.loading")
        case .failed:
            ContentUnavailableView {
                Label("club.projects.loadFailed", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("action.reload", action: onRetry)
                    .buttonStyle(.bordered)
            }
            .accessibilityIdentifier("club.projects.failed")
        case .ready:
            if model.projects.isEmpty {
                emptyState
            } else {
                ForEach(model.projects) { project in
                    row(project)
                }
                if let onPublish {
                    // MP wxml:478-480: the 发布主题 add row under the list.
                    Button(action: onPublish) {
                        Label("club.detail.events.publish", systemImage: "plus")
                    }
                    .accessibilityIdentifier("club.projects.publish")
                }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if let onPublish {
            ContentUnavailableView {
                Label("club.projects.empty", systemImage: "folder")
            } actions: {
                Button("club.detail.events.publish", action: onPublish)
                    .buttonStyle(.borderedProminent)
            }
            .accessibilityIdentifier("club.projects.empty")
        } else {
            ContentUnavailableView("club.projects.emptyAssigned", systemImage: "folder")
                .accessibilityIdentifier("club.projects.emptyAssigned")
        }
    }

    private func row(_ project: ClubManagedProjectRow) -> some View {
        VStack(alignment: .leading) {
            Button { onOpenTopic(project.id) } label: {
                HStack {
                    cover(project)
                    VStack(alignment: .leading) {
                        if let name = project.name {
                            Text(verbatim: name).font(.body).foregroundStyle(.primary)
                        } else {
                            Text("clubR8.project.untitled").font(.body).foregroundStyle(.primary)
                        }
                        meta(project)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("club.projects.row.\(project.id)")
            HStack {
                if project.showsDirector {
                    Button("club.projects.director") { openDirector(project.id) }
                        .accessibilityIdentifier("club.projects.director.\(project.id)")
                }
                Button("club.projects.tools") { openTools(project.id) }
                    .accessibilityIdentifier("club.projects.tools.\(project.id)")
                if busyTopicID == project.id { ProgressView() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(busyTopicID != nil)
        }
        .contextMenu {
            if project.showsDirector {
                Button { openDirector(project.id) } label: { Label("club.projects.director", systemImage: "play.rectangle") }
            }
            Button { openTools(project.id) } label: { Label("club.projects.tools", systemImage: "wrench.and.screwdriver") }
        }
    }

    @ViewBuilder private func cover(_ project: ClubManagedProjectRow) -> some View {
        Group {
            if let url = project.cover {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        MPAsset.BannerCover.routeFreeCover.resizable().scaledToFill()
                    }
                }
            } else {
                // MP wxml:459: `/pages/club/images/route_free_cover.png` fallback.
                MPAsset.BannerCover.routeFreeCover.resizable().scaledToFill()
            }
        }
        .frame(width: coverSide, height: coverSide)
        .clipped()
        .accessibilityHidden(true)
    }

    /// MP wxml:461: 「timeText · N 人报名」, 还没有场次 without a session, — without a count.
    private func meta(_ project: ClubManagedProjectRow) -> Text {
        let time: Text = project.nextSessionText.map { Text(verbatim: $0) } ?? Text("club.topic.noSessions")
        let count: Text = project.signupCount.map { Text("club.projects.signups \($0)") } ?? Text(verbatim: "—")
        return time + Text(verbatim: " · ") + count
    }

    @ViewBuilder private func sessionPicker(_ picker: SessionPicker) -> some View {
        NavigationStack {
            List {
                Section {
                    ForEach(picker.sessions) { session in
                        Button {
                            self.picker = nil
                            switch picker.purpose {
                            case .director: open(.director(topicID: picker.topicID, activityID: session.id))
                            case .tools: chooseTool(topicID: picker.topicID, session: session)
                            }
                        } label: {
                            LabeledContent {
                                if let time = session.timeLabel { Text(verbatim: time) }
                            } label: {
                                Text(verbatim: session.title)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    if picker.purpose == .tools { Text("club.projects.selectSessionHint") }
                }
            }
            .navigationTitle(Text("club.topic.sessionPicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { self.picker = nil }
                }
            }
        }
    }

    private var toolDialogShown: Binding<Bool> {
        Binding(get: { toolTarget != nil }, set: { if !$0 { toolTarget = nil } })
    }

    private func toolTitle(_ tool: ClubSessionToolChoice) -> LocalizedStringKey {
        switch tool {
        case .rosterAndVerify: return "club.projects.tool.roster"
        case .assignLeader: return "club.projects.tool.roles"
        case .notifySessionMembers: return "club.projects.tool.notify"
        }
    }

    private func openDirector(_ topicID: Int) {
        guard busyTopicID == nil else { return }
        busyTopicID = topicID
        notice = nil
        Task {
            defer { busyTopicID = nil }
            guard let sessions = await ClubDetailR8MountModel.topicSessions(topicID: topicID, clubID: clubID, locale: locale, access: access) else {
                notice = "club.projects.networkError"
                return
            }
            if sessions.isEmpty {
                notice = "club.projects.noDirectorSession"
            } else if sessions.count == 1, let only = sessions.first {
                open(.director(topicID: topicID, activityID: only.id))
            } else {
                picker = SessionPicker(topicID: topicID, purpose: .director, sessions: sessions)
            }
        }
    }

    private func openTools(_ topicID: Int) {
        guard busyTopicID == nil else { return }
        busyTopicID = topicID
        notice = nil
        Task {
            defer { busyTopicID = nil }
            // MP E-15f: a failed read is not "no sessions", so it says nothing.
            guard let sessions = await ClubDetailR8MountModel.topicSessions(topicID: topicID, clubID: clubID, locale: locale, access: access) else {
                return
            }
            if sessions.isEmpty {
                notice = "club.projects.noSessionsToast"
            } else if sessions.count == 1, let only = sessions.first {
                chooseTool(topicID: topicID, session: only)
            } else {
                picker = SessionPicker(topicID: topicID, purpose: .tools, sessions: sessions)
            }
        }
    }

    private func chooseTool(topicID: Int, session: ClubManagedDirectorSession) {
        let tools = permissions.tools
        if tools.count == 1, let only = tools.first {
            openTool(only, target: ToolTarget(topicID: topicID, session: session))
        } else if !tools.isEmpty {
            toolTarget = ToolTarget(topicID: topicID, session: session)
        }
    }

    private func openTool(_ tool: ClubSessionToolChoice, target: ToolTarget) {
        toolTarget = nil
        // MP CU-C-57: the label 「活动名 · 开始时间」 rides along (max 40 characters).
        let label = String([target.session.title, target.session.timeLabel].compactMap { $0 }.joined(separator: " · ").prefix(40))
        open(.tool(topicID: target.topicID, activityID: target.session.id, tool, label: label))
    }
}
