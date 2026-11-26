import SwiftUI

/// 发布 tab root (P 210:8374, skill-r1 SR1-07, SR2-06, SR2-20). Same inputs and destinations as `PublishingModesView`
/// (which stays as the pushed publish menu and is contract-frozen): every entry it offers is here too. Order: 继续上次的草稿
/// (only when a quick draft is saved on this device), 新主题 / 新玩法 cards, the professional routes, 从模板开始, then
/// 发布活动 / 我的项目 / 发布者身份.
@MainActor struct PublishRootContent: View {
    let service: PublishingService?
    let account: PublishingSession?
    var makeAIDraft: (() -> any PublishingAIDraftServing)? = nil
    var makeIdentityRegistration: (() -> PublisherIdentityRegistrationService?)? = nil
    var makeActivityTemplate: (() -> AnyView)? = nil
    var makeActivityCover: (() -> ActivityCoverService?)? = nil
    var placeSearch: (any PublishingPlaceSearching)? = nil
    var draftStore: PublishingDraftStore? = nil
    var openProfessional: (ProjectEditDraft) -> Void
    var openResource: (PublishedResource) -> Void
    var makeProfessional: ((ProjectEditProduct) -> AnyView)? = nil
    var makeTemplateAuthoring: (() -> AnyView)? = nil
    /// R7-PC-D1-1: the session's 我的项目 (`SessionCreatorProjectsView`); nil keeps the offline list for fixtures.
    var makeProjects: (() -> AnyView)? = nil
    /// Same rule as the publish menu: activity publishing is for club leaders.
    private var showsActivity: Bool { account == nil || account?.role == "club" }
    private var simplePageRead: ((PublishingRead) async throws -> ProjectEditJSON)? {
        guard let service, let account else { return nil }
        return { query in try await service.read(query, session: account) }
    }
    /// 从模板开始: opens the template browser (the host owns the destination). Nil hides the section.
    var openTemplates: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    /// The saved quick draft (local secure store only). Nil hides 继续上次的草稿.
    @State private var savedDraft: QuickPublishDraft?
    private var copy: CYKitCopy { CYKitCopy(locale: locale) }

    var body: some View {
        // skill-r1 SR1-07 (P 210:8374): the tab opens on what the creator was doing — 继续上次的草稿 — then the two
        // entries (新主题 / 新玩法), then the professional routes, 从模板开始 and the rest. Every earlier destination is
        // kept: quick setup is 新主题, 互动 is 新玩法, and the rows below are unchanged.
        List {
            if let savedDraft {
                Section { draftRow(savedDraft) }
            }
            Section { entries }
            if let makeProfessional {
                Section {
                    NavigationLink { makeProfessional(.city) } label: { Label("publishModes.pro.city", systemImage: "map") }
                        .accessibilityIdentifier("publishModes.pro.city")
                    NavigationLink { makeProfessional(.freeExplore) } label: { Label("publishModes.pro.freeExplore", systemImage: "location.magnifyingglass") }
                        .accessibilityIdentifier("publishModes.pro.freeExplore")
                } header: { Text("publishModes.section.topic") }
            }
            if let openTemplates {
                Section {
                    Button(action: openTemplates) {
                        Label("discovery.browseTemplates", systemImage: "square.stack.3d.up")
                    }
                    .accessibilityIdentifier("publishTab.openTemplates")
                } header: { Text(verbatim: copy("Start from a template", "从模板开始")) }
            }
            Section {
                if showsActivity {
                    NavigationLink { ActivityPublishingView(service: service, account: account, placeSearch: placeSearch, draftStore: draftStore, makeIdentityRegistration: makeIdentityRegistration, makeActivityTemplate: makeActivityTemplate, makeActivityCover: makeActivityCover, openResource: openResource) } label: {
                        Label("publishModes.activity", systemImage: "calendar.badge.plus")
                    }
                }
                // R7-PC-D1-1: one 我的项目 screen (MP subpackageA/pages/myproject), same as the deep link and ⋯ menu.
                NavigationLink { if let makeProjects { makeProjects() } else { PublishingProjectsView(service: service, account: account, openResource: openResource) } } label: {
                    Label("publishModes.projects", systemImage: "square.stack")
                }
                NavigationLink { PublishingIdentityStatusView(service: service, account: account) } label: {
                    Label("publishModes.identity", systemImage: "person.text.rectangle")
                }
            }
        }
        .listStyle(.insetGrouped)
        // Pull to refresh re-reads the local draft.
        .refreshable { await MainActor.run { loadSavedDraft() } }
        .onAppear { loadSavedDraft() }
        .onChange(of: account) { _, _ in loadSavedDraft() }
        // Tab root: the large root title 发布 (type-and-chrome §2); collapses on scroll.
        .cyRootHeader(.publish)
        .accessibilityIdentifier("publishModes.home")
    }

    private func loadSavedDraft() {
        guard let account, let draftStore,
              let saved = try? draftStore.loadActive(activity: false, session: account), let quick = saved.quick else {
            savedDraft = nil; return
        }
        savedDraft = quick
    }

    private var quickDestination: some View {
        QuickPublishingView(placeSearch: placeSearch, account: account, draftStore: draftStore, makeAIDraft: makeAIDraft, simplePageRead: simplePageRead, openProfessional: openProfessional).id(account?.epoch)
    }

    /// 继续上次的草稿: eyebrow, the draft's name (two lines at most) and one meta line, chevron.
    /// Opens quick setup, where 恢复本地草稿 brings the saved draft back (that page is contract-frozen, so it is not
    /// restored automatically).
    private func draftRow(_ draft: QuickPublishDraft) -> some View {
        let name = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let stops = draft.nodes.count
        return NavigationLink {
            quickDestination
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: copy("Continue your last draft", "继续上次的草稿"))
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(verbatim: name.isEmpty ? copy("Untitled draft", "未命名草稿") : name)
                        .font(.headline)
                        .lineLimit(2)
                    if stops > 0 {
                        Text(verbatim: copy("\(stops) places", "\(stops) 个地点"))
                            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: draft.product == .city ? "map" : "location.magnifyingglass")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("publishModes.resumeDraft")
    }

    /// 新主题 (quick setup → editor) and 新玩法 (互动 template authoring).
    @ViewBuilder private var entries: some View {
        NavigationLink { quickDestination } label: {
            entryLabel(title: copy("New topic", "新主题"), detail: copy("Route, chapters, places", "路线、章节、地点"), symbol: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .accessibilityIdentifier("publishModes.quick")
        if let makeTemplateAuthoring {
            NavigationLink { makeTemplateAuthoring() } label: {
                entryLabel(title: copy("New game", "新玩法"), detail: copy("Quiz, photo, race", "问答、拍照、竞速"), symbol: "square.grid.2x2")
            }
            .accessibilityIdentifier("publishModes.interaction")
        }
    }

    private func entryLabel(title: String, detail: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                Text(verbatim: detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: symbol) }
    }
}
