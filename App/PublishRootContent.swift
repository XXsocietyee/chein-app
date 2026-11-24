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
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The saved quick draft (local secure store only). Nil hides 继续上次的草稿.
    @State private var savedDraft: QuickPublishDraft?
    @State private var stagger = CYStaggerGate()
    private var copy: CYKitCopy { CYKitCopy(locale: locale) }

    var body: some View {
        // skill-r1 SR1-07 (P 210:8374): the tab opens on what the creator was doing — 继续上次的草稿 — then two entry
        // cards (新主题 / 新玩法), then the professional routes, 从模板开始 and the rest. Every earlier destination is kept:
        // quick setup is 新主题, 互动 is 新玩法, and the rows below are unchanged.
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                if let savedDraft {
                    draftCard(savedDraft)
                        .transition(.opacity)
                        .cyStaggeredAppear(index: 0, gate: stagger)
                }
                entries.cyStaggeredAppear(index: 1, gate: stagger)
                if let makeProfessional {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYSectionHeader("publishModes.section.topic")
                        NavigationLink { makeProfessional(.city) } label: { CYListRow("publishModes.pro.city", card: true) { CYRowIcon(systemImage: "map") } }
                            .buttonStyle(.plain).accessibilityIdentifier("publishModes.pro.city")
                        NavigationLink { makeProfessional(.freeExplore) } label: { CYListRow("publishModes.pro.freeExplore", card: true) { CYRowIcon(systemImage: "location.magnifyingglass") } }
                            .buttonStyle(.plain).accessibilityIdentifier("publishModes.pro.freeExplore")
                    }
                    .cyStaggeredAppear(index: 2, gate: stagger)
                }
                if let openTemplates {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYSectionHeader(verbatim: copy("Start from a template", "从模板开始"))
                        Button(action: openTemplates) {
                            CYListRow("discovery.browseTemplates", card: true) { CYRowIcon(systemImage: "square.stack.3d.up") }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("publishTab.openTemplates")
                    }
                    .cyStaggeredAppear(index: 3, gate: stagger)
                }
                VStack(spacing: CYSpacing.md) {
                    if showsActivity {
                        NavigationLink { ActivityPublishingView(service: service, account: account, placeSearch: placeSearch, draftStore: draftStore, makeIdentityRegistration: makeIdentityRegistration, makeActivityTemplate: makeActivityTemplate, makeActivityCover: makeActivityCover, openResource: openResource) } label: {
                            CYListRow("publishModes.activity", card: true) { CYRowIcon(systemImage: "calendar.badge.plus") }
                        }.buttonStyle(.plain)
                    }
                    // R7-PC-D1-1: one 我的项目 screen (MP subpackageA/pages/myproject), same as the deep link and ⋯ menu.
                    NavigationLink { if let makeProjects { makeProjects() } else { PublishingProjectsView(service: service, account: account, openResource: openResource) } } label: {
                        CYListRow("publishModes.projects", card: true) { CYRowIcon(systemImage: "square.stack") }
                    }.buttonStyle(.plain)
                    NavigationLink { PublishingIdentityStatusView(service: service, account: account) } label: {
                        CYListRow("publishModes.identity", card: true) { CYRowIcon(systemImage: "person.text.rectangle") }
                    }.buttonStyle(.plain)
                }
                .cyStaggeredAppear(index: 4, gate: stagger)
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            // The draft card arrives or leaves in place; the blocks under it slide on `standard`.
            .cyAnimation(CYMotion.standard, value: savedDraft)
        }
        // Pull to refresh re-reads the local draft (light tick at release, 0.45 s floor).
        .cyRefreshable { await MainActor.run { loadSavedDraft() } }
        .onAppear { loadSavedDraft() }
        .onChange(of: account) { _, _ in loadSavedDraft() }
        .cyDomainPageBackground()
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

    /// 继续上次的草稿: thumbnail, eyebrow, the draft's name (two lines at most) and one meta line, chevron.
    /// Opens quick setup, where 恢复本地草稿 brings the saved draft back (that page is contract-frozen, so it is not
    /// restored automatically).
    private func draftCard(_ draft: QuickPublishDraft) -> some View {
        let name = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let stops = draft.nodes.count
        return NavigationLink {
            quickDestination
        } label: {
            HStack(spacing: CYSpacing.md) {
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                    .fill(palette.bgRaised)
                    .overlay {
                        Image(systemName: draft.product == .city ? "map" : "location.magnifyingglass")
                            .font(.title3).foregroundStyle(palette.textSecondary)
                    }
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(verbatim: copy("Continue your last draft", "继续上次的草稿"))
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                    Text(verbatim: name.isEmpty ? copy("Untitled draft", "未命名草稿") : name)
                        .cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    if stops > 0 {
                        Text(verbatim: copy("\(stops) places", "\(stops) 个地点"))
                            .cyText(.meta).monospacedDigit().foregroundStyle(palette.textSecondary)
                    }
                }
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, CYSpacing.md).padding(.horizontal, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
        .buttonStyle(.cyPressable)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("publishModes.resumeDraft")
    }

    /// 新主题 (quick setup → editor) and 新玩法 (互动 template authoring): two equal cards; stacked at accessibility sizes.
    private var entries: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: CYSpacing.lg))
        return layout {
            NavigationLink { quickDestination } label: {
                entryCard(title: copy("New topic", "新主题"), detail: copy("Route, chapters, places", "路线、章节、地点"), symbol: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .buttonStyle(.cyPressable)
            .accessibilityIdentifier("publishModes.quick")
            if let makeTemplateAuthoring {
                NavigationLink { makeTemplateAuthoring() } label: {
                    entryCard(title: copy("New game", "新玩法"), detail: copy("Quiz, photo, race", "问答、拍照、竞速"), symbol: "square.grid.2x2")
                }
                .buttonStyle(.cyPressable)
                .accessibilityIdentifier("publishModes.interaction")
            }
        }
    }

    private func entryCard(title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Image(systemName: symbol).font(.title2).foregroundStyle(palette.textPrimary).accessibilityHidden(true)
            Spacer(minLength: CYSpacing.lg)
            Text(verbatim: title).cyText(.cardTitle).foregroundStyle(palette.textPrimary).cyWrapText()
            Text(verbatim: detail).cyText(.meta).foregroundStyle(palette.textSecondary).cyWrapText()
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
