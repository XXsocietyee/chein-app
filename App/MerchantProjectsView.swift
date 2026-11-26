import SwiftUI

@MainActor
struct MerchantProjectsView<Reader: MerchantReading>: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.playGapAPIHost) private var playGapAPIHost
    @ObservedObject var reader: Reader
    var contentService: (any MerchantContentServing)? = nil
    var showsRecentEvents = true
    var workspaceReadFactory: MerchantProjectWorkspaceReadFactory? = nil
    /// True on the merchant 模板 tab root: shows Merchant/Root Header and hides the bar title.
    var showsRootHeader = false
    @StateObject private var model = MerchantLoadModel<MerchantProjectWorkspaceSnapshot>()
    @StateObject private var presentation = MerchantProjectWorkspacePresentation()
    @State private var tab: MerchantProjectBrowserTab = .topic
    @State private var opsProject: MerchantProject?
    @State private var deleteProject: MerchantProject?
    @State private var cancelRefundProject: MerchantProject?
    @State private var toastMessage: String?
    #if DEBUG
    @State private var summaryFixtureEvents: [String] = []
    private var summaryFixtureTracing: Bool {
        ProcessInfo.processInfo.arguments.contains("--merchant-project-summary-trace") &&
            MerchantFixtureScenario.selected(arguments: ProcessInfo.processInfo.arguments) == .projectBrowser
    }
    private func recordSummaryFixture(_ event: String) {
        guard summaryFixtureTracing, summaryFixtureEvents.count < 8 else { return }
        summaryFixtureEvents.append(event)
    }
    #endif
    private var context: MerchantProjectWorkspaceContext { .init(reader: reader, service: contentService, workspaceReadID: workspaceReadFactory?.id) }
    private var sourceFresh: Bool { !model.isLoading && model.errorKey == nil && model.loadedRevision == reader.sessionRevision }
    var body: some View {
        ZStack {
            if !reader.isConfigured {
                CYEmptyState(systemImage: "network.slash", "merchant.projects", detail: "auth.notConfigured")
            } else if !reader.isSignedIn {
                CYEmptyState(systemImage: "lock", "merchant.projects", detail: "merchant.signIn")
            } else if model.loadedRevision == reader.sessionRevision, let snapshot = model.value {
                let page = snapshot.page
                let shownTab = tab
                let browser = MerchantProjectBrowser(page: page, tab: shownTab)
                let permit = presentation.permit(snapshot: snapshot)
                List {
                    // Figma 233:12260 · Merchant/Root Header: 模板 as the large leading title.
                    if showsRootHeader {
                        MerchantRootHeader(OpsR3Text.text("r3merchant.root.templates"))
                            .merchantRootHeaderRow()
                    }
                    Section {
                        if page.hasUnloadedRows { Text("merchant.projects.partial").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        if model.isLoading { ProgressView("merchant.refreshing").cyText(.meta) }
                        if let error = model.errorKey {
                            Text("merchant.stale").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            MerchantInlineFailure(errorKey: error, retry: { Task { await reload() } })
                        }
                    }
                    MerchantProjectBrowserControls(browser: browser, canSelect: !model.isLoading) { selected in
                        guard model.value?.id == snapshot.id, !model.isLoading, tab == shownTab, browser.tabs.contains(selected) else { return }
                        presentation.invalidate(); tab = selected
                    }
                    if page.rows.isEmpty {
                        CYEmptyState(systemImage: "calendar", "merchant.projects.empty", messageIdentifier: "merchant.projects.empty")
                            .listRowBackground(Color.clear)
                    } else if browser.rows.isEmpty {
                        Text("merchant.projectBrowser.emptyTab")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("merchant.projectBrowser.emptyTab")
                        ForEach(browser.alternatives, id: \.rawValue) { alternative in
                            CYPillButton(LocalizedStringKey(alternative.titleKey), style: .secondary) {
                                guard model.value?.id == snapshot.id, !model.isLoading, tab == shownTab,
                                      browser.alternatives.contains(alternative) else { return }
                                presentation.invalidate(); tab = alternative
                            }.accessibilityIdentifier("merchant.projectBrowser.switch." + alternative.rawValue)
                        }
                    }
                    ForEach(browser.rows) { project in
                        HStack(alignment: .top, spacing: CYSpacing.xs) {
                        Button {
                            #if DEBUG
                            recordSummaryFixture("action snapshot=\(model.value?.id == snapshot.id) tab=\(tab == shownTab) row=\(browser.rows.contains(project)) " +
                                presentation.summaryFixtureGuards(project: project, snapshot: snapshot, context: context, permit: permit))
                            #endif
                            guard model.value?.id == snapshot.id else { return }
                            guard tab == shownTab, browser.rows.contains(project) else { return }
                            presentation.openSummary(project: project, snapshot: snapshot, context: context, permit: permit)
                            #if DEBUG
                            recordSummaryFixture("selected=\(presentation.selection != nil)")
                            #endif
                        } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                Text(project.title.isEmpty ? appLocalized("merchant.project.untitled",locale:locale) : project.title)
                                    .cyText(.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                if let text = project.projectTypeText, !text.isEmpty {
                                    Text(text).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                }
                                if let text = project.stateText, !text.isEmpty {
                                    Text(text).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                }
                                MerchantProjectCardContext(project: project)
                                if let text = project.startTime, !text.isEmpty {
                                    Label(text, systemImage: "calendar")
                                        .cyText(.meta)
                                        .monospacedDigit()
                                        .foregroundStyle(CYColor.textSecondary)
                                }
                            }
                            .padding(.vertical, CYSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("merchant.project.row.\(project.id)")
                        #if DEBUG
                        .accessibilityValue(summaryFixtureTracing ? summaryFixtureEvents.joined(separator: " | ") : "")
                        #endif
                        Button {
                            opsProject = project
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .cyText(.sectionTitle)
                                .foregroundStyle(CYColor.textSecondary)
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: MerchantCloseCopy.text("更多操作", "More actions", locale)))
                        .accessibilityIdentifier("merchant.project.ops.\(project.id)")
                        }
                    }
                }.refreshable { await reload() }
            } else if let error = model.errorKey {
                MerchantFailureView(errorKey: error, identifier: "merchant.projects", retry: { Task { await reload() } })
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    if showsRootHeader { MerchantRootHeader(OpsR3Text.text("r3merchant.root.templates")) }
                    CYSkeleton(variant: .card)
                }
                .padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .modifier(MerchantProjectsRootTitle(hidesBarTitle: showsRootHeader))
        .task(id: reader.sessionRevision) { await reload(discardOldValue: true) }
        .onChange(of: context) { _, _ in presentation.invalidate(); tab = .topic }
        .onChange(of: model.value?.id) { _, _ in
            presentation.invalidate()
            if tab == .other, let page = model.value?.page, !MerchantProjectBrowser(page: page, tab: tab).tabs.contains(.other) { tab = .topic }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presentation.activate() } else { presentation.retire() }
        }
        .onAppear { if scenePhase == .active { presentation.activate() } }
        .onDisappear { if presentation.selection == nil { presentation.retire() } }
        .background {
            Color.clear.frame(width: 0, height: 0)
        .cySheet(item: presentation.summaryBinding()) { selected in
            NavigationStack {
                if let snapshot = model.value, presentation.selectionIsCurrent(selected, snapshot: snapshot, context: context) {
                    MerchantProjectSummary(project: selected.project, canOpenWorkspace: presentation.canOpenWorkspace(selected, snapshot: snapshot, context: context, sourceFresh: sourceFresh)) {
                        guard model.value?.id == snapshot.id else { return }
                        presentation.openWorkspace(selected, snapshot: snapshot, context: context, sourceFresh: sourceFresh)
                    }
                    .safeAreaInset(edge: .bottom) {
                        if showsRecentEvents, snapshot.access.isOwner, let merchantID = snapshot.access.merchantID,
                           MerchantProjectEventKey(project: selected.project) != nil, sourceFresh {
                            NavigationLink {
                                MerchantProjectRecentEventsView(reader: reader, project: selected.project, merchantID: merchantID,
                                    sourceIsCurrent: {
                                        guard let current = model.value, current.id == snapshot.id else { return false }
                                        return sourceFresh && presentation.selectionIsCurrent(selected, snapshot: current, context: context)
                                    })
                                    .cyPushedChrome(domain: .merchant)
                            } label: { Label("merchant.projectEvents.open", systemImage: "bell").cyText(.button).foregroundStyle(CYColor.textPrimary) }
                            .padding(CYSpacing.md)
                            .frame(maxWidth: .infinity)
                            .background(CYColor.bgSurface)
                            .accessibilityIdentifier("merchant.projectEvents.open")
                        }
                    }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("merchant.done") { presentation.closeSummary(id: selected.id) }.accessibilityIdentifier("merchant.projectSummary.close") } }
                    .navigationDestination(item: presentation.workspaceBinding()) { route in
                        workspaceDestinationView(route: route)
                    }
                } else { ContentUnavailableView("merchant.projectWorkspace.changed", systemImage: "lock") }
            }
            .cyDomainSheet(detents: [.half, .full])
            .themeDomain(.merchant)
            #if DEBUG
            .onAppear { recordSummaryFixture("sheet appeared") }
            #endif
            .onDisappear { presentation.closeSummary(id: selected.id) }
        }
        // SwiftUI may retain the original sheet binding across tab/context changes.
        // Rebuild only its owner, never the loaded list or selected tab.
        .id(presentation.presentationIdentity)
        }
        .cySheet(item: $opsProject) { project in
            let isTopic = project.bizType == "topic"
            let moneyOpen = MerchantCloseCopy.isReviewedMoneyOpen(host: playGapAPIHost)
            let options: [CYOptionSheetItem<String>] = [
                CYOptionSheetItem(id: "open", title: MerchantCloseCopy.text("查看工作台", "Open summary", locale), systemImage: "rectangle.grid.1x2"),
                moneyOpen
                    ? CYOptionSheetItem(id: "cancelRefund", title: MerchantCloseCopy.text("取消并退款", "Cancel & refund", locale), systemImage: "arrow.uturn.backward", isDanger: true)
                    : nil,
                CYOptionSheetItem(id: "delete", title: MerchantCloseCopy.text(isTopic ? "删除路线" : "删除场次", isTopic ? "Delete route" : "Delete session", locale), systemImage: "trash", isDanger: true)
            ].compactMap { $0 }
            CYOptionSheet(
                title: project.title.isEmpty ? appLocalized("merchant.project.untitled", locale: locale) : project.title,
                items: options,
                onSelect: { actionID in
                    opsProject = nil
                    switch actionID {
                    case "open":
                        if let snapshot = model.value {
                            presentation.openSummary(project: project, snapshot: snapshot, context: context, permit: presentation.permit(snapshot: snapshot))
                        }
                    case "cancelRefund":
                        if MerchantCloseCopy.isReviewedMoneyOpen(host: playGapAPIHost) { cancelRefundProject = project }
                    case "delete":
                        deleteProject = project
                    default: break
                    }
                },
                onClose: { opsProject = nil }
            )
            .cyDomainSheet(detents: [.half])
        }
        .cyModalOverlay(isPresented: deleteProject != nil) {
            if let project = deleteProject {
                MerchantProjectDeleteModal(
                    kind: project.bizType == "topic" ? .route : .activity,
                    name: project.title.isEmpty ? "—" : project.title,
                    onCancel: { deleteProject = nil },
                    onUnpublishInstead: {
                        deleteProject = nil
                        if let snapshot = model.value {
                            presentation.openSummary(project: project, snapshot: snapshot, context: context, permit: presentation.permit(snapshot: snapshot))
                        }
                        toastMessage = MerchantCloseCopy.text("请在工作台执行下架操作", "Open workspace to unpublish instead", locale)
                    },
                    onConfirm: {
                        deleteProject = nil
                        if let snapshot = model.value {
                            presentation.openSummary(project: project, snapshot: snapshot, context: context, permit: presentation.permit(snapshot: snapshot))
                        }
                        toastMessage = MerchantCloseCopy.text("请在项目工作台完成二次校验删除", "Confirm deletion in project workspace", locale)
                    }
                )
            }
        }
        .cyModalOverlay(isPresented: cancelRefundProject != nil && MerchantCloseCopy.isReviewedMoneyOpen(host: playGapAPIHost)) {
            if let project = cancelRefundProject {
                MerchantCancelAndRefundModal(
                    kind: project.bizType == "topic" ? .topic : .activity,
                    name: project.title.isEmpty ? "—" : project.title,
                    paidCount: project.signupCount > 0 ? project.signupCount : nil,
                    onCancel: { cancelRefundProject = nil },
                    onConfirm: {
                        cancelRefundProject = nil
                        toastMessage = MerchantCloseCopy.text("退款与取消需由活动取消控制台提交", "Submit cancel & refund via host console", locale)
                    }
                )
            }
        }
        .cyToast(verbatimMessage: $toastMessage)
    }

    @ViewBuilder
    private func workspaceDestinationView(route: MerchantProjectWorkspacePresentation.Route) -> some View {
        Group {
            if let factory = workspaceReadFactory, presentation.workspaceIsCurrent(route, snapshot: model.value, context: context, sourceFresh: sourceFresh) {
                MerchantProjectWorkspaceReadHost(factory: factory, topicID: route.topicID, merchantID: route.merchantID,
                    isCurrent: { presentation.workspaceIsCurrent(route, snapshot: model.value, context: context, sourceFresh: sourceFresh) }, owner: presentation.readOwner)
                    .id(route.id)
            } else if let contentService, presentation.workspaceIsCurrent(route, snapshot: model.value, context: context, sourceFresh: sourceFresh) {
                MerchantContentDocumentView(service: contentService, query: .project(topicID: route.topicID),
                    focusedTopicID: route.topicID, focusedMerchantID: route.merchantID,
                    projectEntryIsCurrent: { presentation.workspaceIsCurrent(route, snapshot: model.value, context: context, sourceFresh: sourceFresh) })
                    .id(route.id)
            } else { Text("merchant.projectWorkspace.changed") }
        }
        .cyPushedChrome(domain: .merchant)
    }

    private func reload(discardOldValue: Bool = false) async {
        presentation.invalidate()
        let captured = context, revision = reader.sessionRevision
        await model.load(reader: reader, discardOldValue: discardOldValue) {
            let access = try await reader.merchantAccess()
            guard revision == reader.sessionRevision, reader.isSignedIn else { throw CancellationError() }
            guard access.allows(.projects) else { throw MerchantReadError.accessDenied }
            try Task.checkCancellation()
            let page = try await reader.merchantProjects(access: access)
            guard context == captured, reader.isSignedIn else { throw CancellationError() }
            return .init(page: page, access: access, context: captured)
        }
    }
}

private struct MerchantProjectSummary: View {
    @Environment(\.locale) private var locale
    let project: MerchantProject
    var canOpenWorkspace = false
    var openWorkspace: () -> Void = {}
    var body: some View {
        Form {
            Section {
                Text(project.title.isEmpty ? appLocalized("merchant.project.untitled",locale:locale) : project.title)
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                Text("merchant.summarySnapshot")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                MerchantProjectCardContext(project: project)
                MerchantCountRow("merchant.recordID", value: project.projectID)
                if let text = project.projectTypeText, !text.isEmpty { LabeledContent("merchant.project.type", value: text) }
                if let text = project.stateText, !text.isEmpty { LabeledContent("merchant.project.state", value: text) }
                if let text = project.acceptStatusText, !text.isEmpty { LabeledContent("merchant.project.acceptance", value: text) }
                if let text = project.startTime, !text.isEmpty { LabeledContent("merchant.project.start", value: text) }
                if let text = project.endTime, !text.isEmpty { LabeledContent("merchant.project.end", value: text) }
            }
            if canOpenWorkspace {
                Section {
                    CYPillButton("merchant.projectWorkspace.open", style: .primary, action: openWorkspace)
                        .accessibilityIdentifier("merchant.projectWorkspace.open")
                    Text("merchant.projectWorkspace.explanation")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
            if project.signupCount > 0 || project.viewCount > 0 {
                Section("merchant.project.statistics") {
                    if project.signupCount > 0 { MerchantCountRow("merchant.project.signups", value: project.signupCount) }
                    if project.viewCount > 0 { MerchantCountRow("merchant.project.views", value: project.viewCount) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .cyDomainScreen(.merchant)
        .appNavigationTitle("merchant.project.summary")
    }
}

/// A list row proves only which project the user selected. Server reads still
/// establish membership, host/join visibility and every existing operation grant.
struct MerchantProjectWorkspaceContext: Hashable {
    let readerID: ObjectIdentifier
    let revision: UInt64
    let configured: Bool
    let signedIn: Bool
    let workspaceReadID: UUID?
    let serviceID: ObjectIdentifier?
    let serviceScope: UUID?
    let serviceConfigured: Bool
    let serviceAuthenticated: Bool
    @MainActor init<Reader: MerchantReading>(reader: Reader, service: (any MerchantContentServing)?, workspaceReadID: UUID? = nil) {
        self.workspaceReadID = workspaceReadID
        readerID = ObjectIdentifier(reader); revision = reader.sessionRevision
        configured = reader.isConfigured; signedIn = reader.isSignedIn
        serviceID = service.map { ObjectIdentifier($0) }; serviceScope = service?.scope
        serviceConfigured = service?.isConfigured == true; serviceAuthenticated = service?.isAuthenticated == true
    }
}
struct MerchantProjectWorkspaceSnapshot {
    let id = UUID()
    let page: MerchantProjectPage
    let access: MerchantAccess
    let context: MerchantProjectWorkspaceContext
}
@MainActor final class MerchantProjectWorkspacePresentation: ObservableObject {
    let readOwner = MerchantProjectWorkspaceReadOwner()
    struct Permit { let generation: UUID; let snapshotID: UUID }
    struct Selection: Identifiable {
        let id = UUID()
        let project: MerchantProject
        let snapshotID: UUID
        let context: MerchantProjectWorkspaceContext
        let generation: UUID
    }
    struct Route: Identifiable, Hashable {
        let id = UUID()
        let selectionID: UUID
        let topicID: Int
        let merchantID: Int
        let snapshotID: UUID
        let context: MerchantProjectWorkspaceContext
        let generation: UUID
    }
    @Published private(set) var selection: Selection?
    @Published private(set) var route: Route?
    private var generation = UUID()
    var presentationIdentity: UUID { generation }
    private(set) var active = true
    func permit(snapshot: MerchantProjectWorkspaceSnapshot) -> Permit { .init(generation: generation, snapshotID: snapshot.id) }
    func activate() { if !active { active = true; invalidate() } }
    func invalidate() { readOwner.retire(); generation = UUID(); selection = nil; route = nil }
    func retire() { active = false; invalidate() }
    private func current(_ snapshot: MerchantProjectWorkspaceSnapshot, _ context: MerchantProjectWorkspaceContext) -> Bool {
        active && context == snapshot.context && context.configured && context.signedIn && snapshot.access.allows(.projects) && (snapshot.access.merchantID ?? 0) > 0
    }
    #if DEBUG
    func summaryFixtureGuards(project: MerchantProject, snapshot: MerchantProjectWorkspaceSnapshot, context: MerchantProjectWorkspaceContext, permit: Permit) -> String {
        "empty=\(selection == nil) current=\(current(snapshot, context)) epoch=\(permit.generation == generation) snapshotPermit=\(permit.snapshotID == snapshot.id) unique=\(snapshot.page.rows.filter { $0.id == project.id }.count == 1) member=\(snapshot.page.rows.contains(project))"
    }
    #endif
    func openSummary(project: MerchantProject, snapshot: MerchantProjectWorkspaceSnapshot, context: MerchantProjectWorkspaceContext, permit: Permit) {
        guard selection == nil, current(snapshot, context), permit.generation == generation, permit.snapshotID == snapshot.id,
              snapshot.page.rows.filter({ $0.id == project.id }).count == 1, snapshot.page.rows.contains(project) else { return }
        selection = .init(project: project, snapshotID: snapshot.id, context: context, generation: generation)
    }
    func selectionIsCurrent(_ selected: Selection, snapshot: MerchantProjectWorkspaceSnapshot, context: MerchantProjectWorkspaceContext) -> Bool {
        current(snapshot, context) && selection?.id == selected.id && selected.generation == generation && selected.snapshotID == snapshot.id && selected.context == context
    }
    func canOpenWorkspace(_ selected: Selection, snapshot: MerchantProjectWorkspaceSnapshot, context: MerchantProjectWorkspaceContext, sourceFresh: Bool) -> Bool {
        sourceFresh && selectionIsCurrent(selected, snapshot: snapshot, context: context) && selected.project.bizType == "topic" && selected.project.projectID > 0 &&
            (context.workspaceReadID != nil || (context.serviceID != nil && context.serviceConfigured && context.serviceAuthenticated))
    }
    func openWorkspace(_ selected: Selection, snapshot: MerchantProjectWorkspaceSnapshot, context: MerchantProjectWorkspaceContext, sourceFresh: Bool) {
        guard route == nil, canOpenWorkspace(selected, snapshot: snapshot, context: context, sourceFresh: sourceFresh), let merchantID = snapshot.access.merchantID else { return }
        readOwner.retire()
        route = .init(selectionID: selected.id, topicID: selected.project.projectID, merchantID: merchantID,
                      snapshotID: snapshot.id, context: context, generation: generation)
    }
    func workspaceIsCurrent(_ value: Route, snapshot: MerchantProjectWorkspaceSnapshot?, context: MerchantProjectWorkspaceContext, sourceFresh: Bool) -> Bool {
        guard let snapshot, let selected = selection, route?.id == value.id, value.generation == generation,
              selected.id == value.selectionID, snapshot.id == value.snapshotID, snapshot.access.merchantID == value.merchantID,
              selected.project.projectID == value.topicID, value.context == context else { return false }
        return canOpenWorkspace(selected, snapshot: snapshot, context: context, sourceFresh: sourceFresh)
    }
    static func matches(snapshot: MerchantContentSnapshot, topicID: Int?, merchantID: Int?) -> Bool {
        guard let topicID, topicID > 0, let merchantID, merchantID > 0,
              snapshot.query == .project(topicID: topicID), snapshot.access.allows(.projects),
              snapshot.access.merchantID == merchantID else { return false }
        guard case .integer(let receivedID) = snapshot.value["topic"]["id"] else { return false }
        return receivedID == topicID
    }
    func closeSummary(id: UUID) { guard selection?.id == id else { return }; invalidate() }
    func summaryBinding() -> Binding<Selection?> {
        let epoch = generation
        var captured = selection?.id
        return Binding(get: { [weak self] in
            guard let self, self.generation == epoch, let selected = self.selection else { return nil }
            // SwiftUI may retain the binding installed before the first selection.
            // Adopt that first identity once; never adopt a reopened presentation.
            if captured == nil { captured = selected.id }
            return selected.id == captured ? selected : nil
        }, set: { [weak self] value in
            guard let self, self.generation == epoch, value == nil, let captured else { return }
            self.closeSummary(id: captured)
        })
    }
    func workspaceBinding() -> Binding<Route?> {
        let epoch = generation
        var captured = route?.id
        return Binding(get: { [weak self] in
            guard let self, self.generation == epoch, let current = self.route else { return nil }
            if captured == nil { captured = current.id }
            return current.id == captured ? current : nil
        }, set: { [weak self] value in
            guard let self, self.generation == epoch, value == nil, let captured, self.route?.id == captured else { return }
            self.readOwner.retire(); self.route = nil
        })
    }
}


/// The 模板 tab root hides its bar title (the root header carries it); a pushed 项目 page keeps it.
private struct MerchantProjectsRootTitle: ViewModifier {
    let hidesBarTitle: Bool
    func body(content: Content) -> some View {
        // The root header carries 模板; the bar keeps no title (the 我主办的项目 large title read as a second name).
        if hidesBarTitle { content.navigationTitle("").navigationBarTitleDisplayMode(.inline) }
        else { content.appNavigationTitle("merchant.projects") }
    }
}
