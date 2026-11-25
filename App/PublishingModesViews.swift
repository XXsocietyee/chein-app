import SwiftUI
import UIKit
import MapKit
import Combine

/// Form chrome shared by the publish forms: page background from the role palette.
private struct PublishFormChrome: ViewModifier {
    @Environment(\.cyPalette) private var palette
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).cyDomainPageBackground().tint(palette.textPrimary)
    }
}
private extension View { func publishFormChrome() -> some View { modifier(PublishFormChrome()) } }

/// Additive composition surface. Parent supplies professional-editor routing and the current
/// account epoch. No production mutation approval, map provider or token is created here.
@MainActor struct PublishingModesView: View {
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
    /// Mini-program publish menu, second level 专业手动: an empty professional editor for the chosen route type.
    var makeProfessional: ((ProjectEditProduct) -> AnyView)? = nil
    /// Mini-program publish menu card 互动: template intro, naming, then the template editor.
    var makeTemplateAuthoring: (() -> AnyView)? = nil
    /// Mini-program: activity publishing is for club leaders; other roles never see the entry.
    private var showsActivity: Bool { account == nil || account?.role == "club" }
    /// Home plus AI quota for the simple page. Nil keeps the form visible and the quota as an em dash.
    private var simplePageRead: ((PublishingRead) async throws -> ProjectEditJSON)? {
        guard let service, let account else { return nil }
        return { query in try await service.read(query, session: account) }
    }
    var body: some View {
        // Same choices and order as the mini-program publish menu (cy-publish-sheet):
        // a topic (city orientation or free explore, quick or professional), then interaction.
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                CYHeroHeader("publishModes.title")
                // One primary action: the quick publish journey ("Quick setup").
                NavigationLink { QuickPublishingView(placeSearch: placeSearch, account: account, draftStore: draftStore, makeAIDraft: makeAIDraft, simplePageRead: simplePageRead, openProfessional: openProfessional).id(account?.epoch) } label: {
                    Label("publishModes.quick", systemImage: "wand.and.stars")
                }.buttonStyle(CYPillButtonStyle(style: .primary))
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    CYSectionHeader("publishModes.section.topic")
                    if let makeProfessional {
                        NavigationLink { makeProfessional(.city) } label: { CYListRow("publishModes.pro.city", card: true) { CYRowIcon(systemImage: "map") } }
                            .buttonStyle(.plain).accessibilityIdentifier("publishModes.pro.city")
                        NavigationLink { makeProfessional(.freeExplore) } label: { CYListRow("publishModes.pro.freeExplore", card: true) { CYRowIcon(systemImage: "location.magnifyingglass") } }
                            .buttonStyle(.plain).accessibilityIdentifier("publishModes.pro.freeExplore")
                    }
                }
                if let makeTemplateAuthoring {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYSectionHeader("publishModes.section.interaction")
                        NavigationLink { makeTemplateAuthoring() } label: { CYListRow("publishModes.interaction", card: true) { CYRowIcon(systemImage: "puzzlepiece.extension") } }
                            .buttonStyle(.plain).accessibilityIdentifier("publishModes.interaction")
                    }
                }
                VStack(spacing: CYSpacing.md) {
                    if showsActivity {
                        NavigationLink { ActivityPublishingView(service: service, account: account, placeSearch: placeSearch, draftStore: draftStore, makeIdentityRegistration: makeIdentityRegistration, makeActivityTemplate: makeActivityTemplate, makeActivityCover: makeActivityCover, openResource: openResource) } label: {
                            CYListRow("publishModes.activity", card: true) { CYRowIcon(systemImage: "calendar.badge.plus") }
                        }.buttonStyle(.plain)
                    }
                    NavigationLink { PublishingProjectsView(service: service, account: account, openResource: openResource) } label: {
                        CYListRow("publishModes.projects", card: true) { CYRowIcon(systemImage: "square.stack") }
                    }.buttonStyle(.plain)
                    NavigationLink { PublishingIdentityStatusView(service: service, account: account) } label: {
                        CYListRow("publishModes.identity", card: true) { CYRowIcon(systemImage: "person.text.rectangle") }
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .navigationTitle("").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("publishModes.home")
    }
}
@MainActor struct QuickPublishingView: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var journey = QuickPublishingJourneyOwner()
    @Environment(\.cyPalette) private var palette
    var placeSearch: (any PublishingPlaceSearching)?
    var account: PublishingSession? = nil
    var draftStore: PublishingDraftStore? = nil
    var makeAIDraft: (() -> any PublishingAIDraftServing)? = nil
    var simplePageRead: ((PublishingRead) async throws -> ProjectEditJSON)? = nil
    var openProfessional: (ProjectEditDraft) -> Void
    @StateObject private var simplePage = QuickPublishSimplePageOwner()
    var body: some View {
        let _ = journey.bind(account: account)
        let draft = journey.draftBinding()
        // Mini-program publish/simple order: AI draft, the draft (route type, name, story),
        // the stops to confirm on the map, then one primary action into the editor.
        Form {
            Section {
                QuickPublishSimplePageStatus(owner: simplePage)
            }
            Section {
                Button(action: journey.openAIAction(makeClient: makeAIDraft)) {
                    CYListRow("contextPublish.ai.title") { CYRowIcon(systemImage: "sparkles") }
                }.buttonStyle(.plain).accessibilityIdentifier("contextPublish.ai.open")
            }
            Section {
                Picker("publishModes.product", selection: draft.product) { Text("projectEdit.city").tag(ProjectEditProduct.city); Text("projectEdit.freeExplore").tag(ProjectEditProduct.freeExplore) }
                TextField("publishModes.name", text: draft.title).accessibilityIdentifier("publishModes.quick.name")
                TextField("publishModes.description", text: draft.description, axis: .vertical).lineLimit(3...8)
            } header: { CYSectionHeader("publishModes.details") }
            ForEach(draft.nodes) { $node in
                let index = (draft.wrappedValue.nodes.firstIndex { $0.id == node.id } ?? 0) + 1
                Section {
                    TextField("publishModes.name", text: $node.name)
                    TextField("publishModes.description", text: $node.description, axis: .vertical).lineLimit(2...6)
                    Button(action: journey.openPlaceAction(node.id)) {
                        CYListRow("publishModes.choosePlace", trailing: .valueChevron(node.confirmedPlace.map { $0.address.isEmpty ? $0.name : $0.address } ?? "—")) {
                            CYRowIcon(systemImage: node.confirmedPlace == nil ? "mappin.and.ellipse" : "checkmark.circle.fill")
                        }
                    }.buttonStyle(.plain)
                    Button("publishModes.remove", role: .destructive, action: journey.removeNodeAction(node.id))
                } header: { CYSectionHeader("publishModes.stopNumber \(index)") }
            }
            Section {
                Button(action: journey.addNodeAction()) { Label("publishModes.addNode", systemImage: "plus.circle").frame(maxWidth: .infinity) }
                    .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                    .accessibilityIdentifier("publishModes.quick.add")
            }
            if account != nil && draftStore != nil {
                Section {
                    Button("publishModes.saveLocal", action: journey.saveAction(store: draftStore))
                    Button("publishModes.restoreLocal", action: journey.restoreAction(store: draftStore))
                    if !journey.storageMessage.isEmpty { Text(LocalizedStringKey(journey.storageMessage)) }
                }
            }
        }.publishFormChrome().disabled(!journey.canEdit).navigationTitle(Text("publishModes.quick")).navigationBarTitleDisplayMode(.inline)
        .questifyBottomAction {
            VStack(spacing: 8) {
                if journey.problem {
                    Text("publishModes.confirmEveryPlace").cyText(.meta).foregroundStyle(palette.danger).multilineTextAlignment(.center)
                    ForEach(Array(QuickPublishValidation.issues(draft.wrappedValue).enumerated()), id: \.offset) { _, issue in
                        Text(verbatim: issue.message).cyText(.meta).foregroundStyle(palette.danger).multilineTextAlignment(.center)
                    }
                }
                CYPillButton("publishModes.continueEditor", action: journey.handoffAction(openProfessional))
                    .disabled(!journey.canEdit)
                    .accessibilityIdentifier("publishModes.quick.continue")
            }.background(palette.bgPage)
        }
        .onAppear { journey.appear(active: scenePhase == .active) }
        .task(id: account?.epoch) { await simplePage.load(read: simplePageRead, draft: journey.draft) }
        .onChange(of: scenePhase) { _, phase in journey.setActive(phase == .active) }
        .background { QuickPublishingJourneyLifetime(owner: journey).frame(width: 0, height: 0) }
        .background {
            if let original = journey.presentation {
                QuickPublishingJourneyPresenter(owner: journey, original: original, placeSearch: placeSearch).id(original.id)
            }
        }
    }
}
@MainActor struct ActivityPublishingView: View {
    @Environment(\.locale) private var locale
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// verify-r2 N-01: this page applies the topicEditor domain to itself, so its own palette is that domain's.
    /// Reading `cyPalette` here gave the pushing NavigationStack's palette (the dark player shell).
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }
    @StateObject private var localClear = ActivityPublishingLocalClearOwner()
    @StateObject private var timeRange = ActivityPublishingTimeRangeOwner()
    @StateObject private var identityRegistration = PublisherIdentityRegistrationOwner()
    @StateObject private var templateSelection = ActivityTemplateSelectionOwner()
    @StateObject private var cover = ActivityCoverAuthoringOwner()
    @StateObject private var submission = ActivityPublishingSubmissionOwner()
    let service: PublishingService?
    let account: PublishingSession?
    var placeSearch: (any PublishingPlaceSearching)?
    var draftStore: PublishingDraftStore? = nil
    @State private var draftID = UUID()
    var makeIdentityRegistration: (() -> PublisherIdentityRegistrationService?)? = nil
    var makeActivityTemplate: (() -> AnyView)? = nil
    var makeActivityCover: (() -> ActivityCoverService?)? = nil
    var openResource: ((PublishedResource) -> Void)? = nil
    @State private var draft = ActivityPublishDraft()
    @State private var picker: String?
    @StateObject private var organizerRead = ActivityPublishOrganizerRead()
    @State private var review: PublishingReview?
    @State private var localReview = false
    @State private var wizardStep = 0
    @State private var wizardBlock: String?
    @State private var abandonConfirm = false
    @State private var draftSaveState: CYPublishSaveState = .unsavedChanges
    @State private var showResultSheet = false
    /// MP activity/index.js onResultSheetClose: closing the result lands on 我的项目 › 活动.
    @State private var openProjectsAfterResult = false
    @State private var toastMessage: String?
    private var busy: Bool { submission.busy }
    @State private var message = ""
    private var acknowledged: Bool { submission.outcome == .acknowledged }
    private var uncertain: Bool { submission.outcome == .unknown || submission.lockUnavailable }
    private var coverEditable: Bool { !busy && !acknowledged && !uncertain && !identityRegistration.open && !templateSelection.open && review == nil && !localReview && picker == nil && timeRange.presentation == nil && (service == nil || service?.currentSession == account) }
    private var editable: Bool { !busy && !acknowledged && !uncertain && !identityRegistration.open && !templateSelection.open && !cover.isOpen }
    private var requiresIdentity: Bool {
        account?.region == .china && account?.role == "club" && draft.tickets.contains {
            Decimal(string: $0.price, locale: Locale(identifier: "en_US_POSIX")).map { $0 > 0 } == true
        }
    }
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        let _ = submission.bind(account: account, draftID: draftID, draft: draft, service: service)
        let _ = cover.bind(read: { .init(session: account, target: .newDraft(draftID), draft: ProjectEditPendingMaterials.exactData(draft), reference: draft.coverURL, editable: coverEditable) }, apply: { value in
            guard coverEditable else { return false }; draft.coverURL = value; return true
        }, service: { makeActivityCover?() })
        let _ = templateSelection.bind(session: account, draftID: draftID, draft: draft)
        let templateSelectionAction = templateSelection.actionID
        let templateReadID = templateSelection.readID
        let _ = identityRegistration.bind(account: account, draftID: draftID, draft: draft)
        let _ = localClear.bind(account: account, draftID: draftID, draft: draft, editable: mayClear)
        let _ = timeRange.bind(account: account, draftID: draftID, draft: draft, editable: mayEditTimeRange)
        // The modifier chain is split in two stages for the type checker;
        // the modifiers keep their original order.
        // Mini-program guardPublisherRole: publish_precheck admits the form; 403 shows the server's reason.
        // C-A6: a merchant account checks /api/merchant/access/me as the MP does.
        ActivityPublishPrecheckGate(merchantHost: account?.role == "merchant") { publishingForm(templateSelectionAction: templateSelectionAction, templateReadID: templateReadID) }
        .onChange(of: submission.receipt?.activityID) { _, id in
            guard let id, id > 0, submission.receipt?.committed == true else { return }
            MiniProgramAnalytics.track(analytics, "activity_publish_success", bizType: "activity", bizID: id,
                pagePath: "/pages/publish/activity/index", properties: ["name": .string(draft.name)])
            toastMessage = MerchantCloseCopy.text("活动已发布", "Activity published", locale)
            showResultSheet = true
        }
        .sheet(isPresented: $showResultSheet) {
            PlayCloseResultSheet(
                title: MerchantCloseCopy.text("活动已提交发布", "Activity Submitted", locale),
                message: MerchantCloseCopy.text("可在项目管理查看活动状态与审核进度。", "Track activity status in your project list.", locale),
                detail: nil,
                closeIdentifier: cyAccessibilityID(id: "publishModes.activity.result.close"),
                onClose: {
                    showResultSheet = false
                    if resultProjectsAvailable { openProjectsAfterResult = true }
                }
            )
            .themeDomain(.topicEditor)
        }
        .navigationDestination(isPresented: $openProjectsAfterResult) {
            if let account, let service, let openResource {
                PublishingProjectsView(service: service, account: account, openResource: { resource in
                    guard service.currentSession == account else { return }; openResource(resource)
                }, readOnly: true, initialType: "activity").id(account.epoch)
            }
        }
        .cyToast(verbatimMessage: $toastMessage)
        // C-A7: one creator domain for the whole activity form and its sheets.
        .cyDomainScreen(.topicEditor)
        .background {
            if let original = timeRange.presentation {
                ActivityPublishingTimeRangePresenter(owner: timeRange, original: original) { selected in
                    timeRange.apply(selected, original: original, draft: $draft, account: account, draftID: draftID,
                        timeZoneID: TimeZone.autoupdatingCurrent.identifier, allowed: mayEditTimeRange)
                }.id(original.id)
            }
        }
        .sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) {
            pickerSheet
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.topicEditor)
        }
        .sheet(isPresented: $localReview) {
            let snapshot = review
            NavigationStack {
                List {
                    Section {
                        LabeledContent("publishParity.activity.title", value: draft.name)
                        LabeledContent("publishModes.addressName", value: draft.addressName.isEmpty ? "—" : draft.addressName)
                        LabeledContent("publishModes.start", value: draft.start.isEmpty ? "—" : draft.start)
                        LabeledContent("publishModes.end", value: draft.end.isEmpty ? "—" : draft.end)
                        LabeledContent("publishModes.ticket", value: String(draft.tickets.count))
                    }
                    if !draft.description.isEmpty {
                        Section("publishParity.activity.description") { Text(draft.description) }
                    }
                }
                .cyDomainScreen(.topicEditor)
                .navigationTitle(Text("publishModes.review")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("publishModes.cancel", role: .cancel) {
                            guard review == snapshot else { return }
                            if let snapshot { service?.cancel(snapshot) }; review = nil; localReview = false
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    CYFooterBar {
                        Button { if let snapshot { Task { await submit(snapshot) } } } label: { Text("publishModes.confirm") }
                            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                            .disabled(snapshot == nil || busy || service?.mutationsConfigured != true)
                    }
                }
            }
            .cyDomainSheet(detents: [.half, .full])
            .themeDomain(.topicEditor)
        }
    }
    private func publishingForm(templateSelectionAction: UUID, templateReadID: UUID) -> some View {
        // Mini-program publish/activity: step dots, then per step —
        // basics (title, venue, dates, type), content (description, cover, template),
        // tickets (collaborators, ticket options, add ticket, publisher identity).
        // Input errors sit in red under the field they refer to.
        Form {
            Section {
                ActivityPublishingWizardChrome(
                    step: wizardStep,
                    block: wizardBlock,
                    issues: ActivityPublishingStatusHelper.issues(for: draft, locale: locale),
                    saveState: draftSaveState,
                    isSubmittingReview: busy,
                    onSelectStep: { target in
                        wizardStep = ActivityPublishingWizard.clamp(target)
                        wizardBlock = nil
                    },
                    onSubmitReview: { Task { await prepare() } }
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
            if ActivityPublishingWizard.clamp(wizardStep) == 0 {
                Section {
                    HStack {
                        TextField("publishParity.activity.title", text: $draft.name)
                            .foregroundStyle(palette.textPrimary)
                        clearButton(.name)
                    }
                    fieldError("name")
                    // C-A2 (MP activity index.wxml:43-50): the venue name comes from 选择地点, never typed.
                    LabeledContent("publishModes.addressName", value: draft.addressName.isEmpty ? "—" : draft.addressName)
                        .foregroundStyle(palette.textPrimary)
                    fieldError("addressName")
                    Button { picker = "place" } label: {
                        chooserRow("publishModes.choosePlace", value: draft.place.map { $0.address.isEmpty ? $0.name : $0.address }, icon: "mappin.and.ellipse")
                    }
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("配置基本信息", "Basics & Location")) }
                .listRowBackground(palette.bgElevated)
                .disabled(!editable)
                Section {
                    Button {
                        localClear.invalidate()
                        timeRange.open(account: account, draftID: draftID, draft: draft, now: Date(), timeZoneID: TimeZone.autoupdatingCurrent.identifier)
                    } label: { chooserRow("publishModes.chooseTimeRange", value: nil, icon: "calendar") }
                        .disabled(!mayEditTimeRange || !timeRange.canOpen(account: account, draftID: draftID, draft: draft, now: Date()))
                        .accessibilityIdentifier("publishModes.activity.timeRange.open")
                    // C-A2 (MP index.wxml:53-70): start / end come from 选择时间段 only; shown read-only.
                    LabeledContent("publishModes.start", value: draft.start.isEmpty ? "—" : draft.start)
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("publishModes.activity.start")
                    fieldError("startDate")
                    LabeledContent("publishModes.end", value: draft.end.isEmpty ? "—" : draft.end)
                        .foregroundStyle(palette.textPrimary)
                    fieldError("endDate")
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("活动时间", "Schedule")) }
                .listRowBackground(palette.bgElevated)
                .disabled(!editable)
                Section {
                    Button { picker = "category" } label: {
                        chooserRow("publishParity.activity.type", value: draft.categoryIDs.isEmpty ? nil : appLocalized("publishModes.selectedCount \(draft.categoryIDs.count)", locale: locale), icon: "tag")
                    }
                    fieldError("categoryIds")
                }
                .listRowBackground(palette.bgElevated)
                .disabled(!editable)
            }
            if ActivityPublishingWizard.clamp(wizardStep) == 1 {
                Section {
                    HStack(alignment: .top) {
                        TextField("publishParity.activity.description", text: $draft.description, axis: .vertical).lineLimit(3...8)
                            .foregroundStyle(palette.textPrimary)
                        clearButton(.description)
                    }
                    fieldError("description")
                    // Without the cover upload service, an existing cover link is the only way to set one.
                    if makeActivityCover == nil {
                        TextField("publishModes.cover", text: $draft.coverURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .foregroundStyle(palette.textPrimary)
                    }
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("活动说明", "Description")) }
                .listRowBackground(palette.bgElevated)
                .disabled(!editable)
                Section {
                    ActivityCoverAuthoringSection(owner: cover)
                    fieldError("imgUrl")
                } header: { CYSectionHeader("publishModes.coverSection") }
                .listRowBackground(palette.bgElevated)
                Section {
                    Button {
                        localClear.invalidate(); timeRange.retire()
                        templateSelection.begin(service: service, expected: templateSelectionAction, allowed: mayEditTimeRange)
                    } label: {
                        chooserRow("publishModes.template", value: draft.playTemplateID == nil ? nil : appLocalized("publishModes.selected", locale: locale), icon: "puzzlepiece")
                    }.accessibilityIdentifier("activityTemplate.open")
                    fieldError("templateId")
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("关联玩法模板", "Play Template")) }
                .listRowBackground(palette.bgElevated)
                .disabled(!editable)
                if templateSelection.open {
                    ActivityTemplateSelectionSection(owner: templateSelection, apply: { stamp in
                        templateSelection.apply(expected: stamp, draft: $draft, session: account, draftID: draftID,
                            allowed: !busy && !acknowledged && !uncertain && !identityRegistration.open)
                    }, createAvailable: makeActivityTemplate != nil)
                }
            }
            if ActivityPublishingWizard.clamp(wizardStep) == 2 {
                // r8 C-A4 (MP activity wxml:135, js getUserData): 发起人信息未加载 + 重试 above 合作者.
                ActivityPublishOrganizerHost(read: organizerRead)
                Section {
                    Button { picker = "collaborator" } label: {
                        chooserRow("publishModes.collaborators", value: draft.collaboratorMemberIDs.isEmpty ? nil : appLocalized("publishModes.selectedCount \(draft.collaboratorMemberIDs.count)", locale: locale), icon: "person.2")
                    }
                    Text(verbatim: CoreLoopCopy(locale: locale).tr(ActivityPublishingWizard.collaboratorSettlementNotice))
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                    fieldError("collaborators")
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("合作与核销", "Collaborators")) }
                .listRowBackground(palette.bgElevated)
                .disabled(!editable)
                .task { await organizerRead.load() }
                ForEach($draft.tickets) { $ticket in
                    let index = draft.tickets.firstIndex { $0.id == ticket.id } ?? 0
                        Section {
                            HStack {
                                TextField("publishParity.ticket.name", text: $ticket.name)
                                    .foregroundStyle(palette.textPrimary)
                                clearButton(.ticketName(ticket.id))
                            }
                            fieldError("ticketName\(index)")
                            // CF-48: prices carry 积分, the only currency.
                            HStack(spacing: CYSpacing.s1_5) {
                                TextField("publishParity.ticket.price", text: $ticket.price).keyboardType(.decimalPad)
                                    .foregroundStyle(palette.textPrimary)
                                EditorKitText.text(EditorUnit.points.key).foregroundStyle(palette.textSecondary)
                            }
                            fieldError("ticketPrice\(index)")
                            HStack {
                                TextField("publishParity.ticket.stock", text: $ticket.stock).keyboardType(.numberPad)
                                    .foregroundStyle(palette.textPrimary)
                                clearButton(.ticketStock(ticket.id))
                            }
                            fieldError("ticketStock\(index)")
                            TextField("publishModes.start", text: $ticket.start)
                                .foregroundStyle(palette.textPrimary)
                            fieldError("ticketStart\(index)")
                            TextField("publishModes.end", text: $ticket.end)
                                .foregroundStyle(palette.textPrimary)
                            fieldError("ticketEnd\(index)")
                        } header: {
                            // CF-33 / CF-58: one "⋯" per ticket (上移, 下移, 删除 last) instead of a red text link.
                            HStack {
                                Text("publishModes.ticketNumber \(index + 1)").foregroundStyle(palette.textPrimary)
                                Spacer(minLength: CYSpacing.sm)
                                EditorRowActionsMenu(index: index, count: draft.tickets.count, deleteTitle: Text("publishModes.remove"),
                                                     menuID: "publishModes.ticket.menu.\(index)") { action in
                                    switch action {
                                    case .delete:
                                        draft.tickets.removeAll { $0.id == ticket.id }
                                    case .moveUp, .moveDown:
                                        if let destination = EditorReorder.destination(for: action, index: index, count: draft.tickets.count) {
                                            draft.tickets.move(fromOffsets: IndexSet(integer: index), toOffset: destination)
                                        }
                                    case .duplicate:
                                        break
                                    }
                                }
                                .textCase(nil)
                            }
                        }
                        .listRowBackground(palette.bgElevated)
                        .disabled(!editable)
                }
                // Mini-program publish/activity: 添加票单 directly follows the ticket list, before publisher identity.
                Section {
                    EditorAddRow(title: Text("publishModes.addTicket"), accessibilityID: "editorKit.activity.addTicket") { draft.tickets.append(.init()) }
                        .disabled(!editable)
                    if wizardBlock == "ticket" { fieldError("ticket") }
                }
                .listRowBackground(palette.bgElevated)
                if requiresIdentity {
                    // Design hand-off r1 CF-58: real-name is its own pushed page, shown only when needed.
                    Section {
                        NavigationLink {
                            Form {
                                PublisherIdentityRegistrationSection(owner: identityRegistration, makeService: makeIdentityRegistration, enabled: mayClear)
                            }
                            .formStyle(.grouped).cyGroupedSurface()
                            .navigationTitle(Text("title", tableName: "PublisherIdentityRegistration"))
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            EditorRow(
                                label: Text("title", tableName: "PublisherIdentityRegistration"),
                                value: identityRegistration.confirmedRegistered ? Text("status.registered", tableName: "PublisherIdentityRegistration") : nil,
                                systemImage: "person.text.rectangle",
                                showsDot: !identityRegistration.confirmedRegistered,
                                accessory: .none
                            )
                        }
                        .accessibilityIdentifier("publishModes.activity.identityPage")
                    }
                    .listRowBackground(palette.bgElevated)
                }
                Section {
                    ActivityPublishingReviewSummaryCard(
                        summary: ActivityPublishingWizard.reviewSummary(draft: draft),
                        merchantHost: account?.role == "merchant"
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("发布前预览", "Preview Before Publishing")) }
            }
            if account != nil && draftStore != nil {
                Section {
                    Button("publishModes.saveLocal") {
                        saveLocalDraft()
                    }.disabled(!editable)
                    Button("publishModes.restoreLocal") {
                        localClear.invalidate(); timeRange.retire()
                        guard let account, let draftStore else { return }
                        do {
                            if let saved = try draftStore.loadActive(activity: true, session: account), let activity = saved.activity {
                                draft = activity; draftID = saved.identity; message = "publishModes.restoredLocal"
                                draftSaveState = .savedDraft(updatedAt: Self.draftTimestampNow())
                                wizardStep = ActivityPublishingWizard.resume(savedStep: saved.wizardStep, draft: activity)
                                wizardBlock = ActivityPublishingWizard.blockingField(wizardStep, activity)
                            } else { message = "publishModes.noSavedLocal" }
                        } catch {
                            message = "publishModes.storageFailed"
                            draftSaveState = .saveFailed(reason: appLocalized("publishModes.storageFailed", locale: locale), onRetry: { saveLocalDraft() })
                        }
                    }.disabled(!editable)
                } header: { CYSectionHeader(verbatim: CoreLoopCopy(locale: locale).t("草稿保存", "Draft Persistence")) }
                .listRowBackground(palette.bgElevated)
            }
            submissionResult
        }
        .scrollContentBackground(.hidden)
        .background(palette.bgPage)
        .publishFormChrome()
        .cyPushedChrome(domain: .topicEditor)
        .navigationTitle(Text("publishModes.activity"))
        // C-A3 (T&C §2): one system inline title; no second principal title drawn over it.
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CYFooterBar {
                VStack(spacing: CYSpacing.sm) {
                    if !message.isEmpty {
                        Text(LocalizedStringKey(message)).cyText(.meta)
                            .foregroundStyle(message == "publishModes.invalid" || message == "publishModes.storageFailed" ? palette.danger : palette.textSecondary)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("publishModes.message")
                    }
                    ActivityPublishingWizardNavigation(step: wizardStep, enabled: editable, onCancel: cancelWizard, onBack: goBack, onNext: goNext, onReview: { Task { await prepare() } })
                }
            }
        }
        .onChange(of: draft) { _, _ in
            timeRange.retire()
            if let review { service?.cancel(review) }
            review = nil; localReview = false
            draftSaveState = .unsavedChanges
        }
        .onChange(of: account) { _, _ in
            cover.accountChanged(); localClear.invalidate(); timeRange.retire(); service?.invalidateReviews()
            draft = .init(); draftID = UUID(); review = nil; localReview = false; message = ""
            wizardStep = 0; wizardBlock = nil; abandonConfirm = false
        }
        .overlay {
            if abandonConfirm {
                PlayAreaActivityAbandonModal(onConfirm: { abandonConfirm = false; dismiss() }, onCancel: { abandonConfirm = false })
            }
        }
        .onAppear { submission.setActive(scenePhase == .active); cover.appear(active: scenePhase == .active); localClear.appear(active: scenePhase == .active); timeRange.setActive(scenePhase == .active); identityRegistration.appear(active: scenePhase == .active); templateSelection.setActive(scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in
            submission.setActive(phase == .active)
            if phase != .active { if let review { service?.cancel(review) }; review = nil; localReview = false }
            cover.setActive(phase == .active); localClear.setActive(phase == .active); timeRange.setActive(phase == .active); identityRegistration.setActive(phase == .active); templateSelection.setActive(phase == .active) }
        .onDisappear { identityRegistration.disappear(); localClear.retire(); if let review { service?.cancel(review) }; review = nil }
        .background { ActivityCoverLifetime(owner: cover).frame(width: 0, height: 0) }
        .background { ActivityPublishingSubmissionLifetime(owner: submission).frame(width: 0, height: 0) }
        .background { RetainedImagePresenterHost(host: cover.pickerHost).frame(width: 0, height: 0) }
        .background { ActivityPublishingTimeRangeLifetimeAnchor(owner: timeRange).frame(width: 0, height: 0) }
        .background { ActivityTemplateSelectionLifetimeAnchor(owner: templateSelection).frame(width: 0, height: 0) }
        .background {
            if let creation = templateSelection.creation, let makeActivityTemplate {
                ActivityTemplateCreationPresenter(owner: templateSelection, original: creation, content: makeActivityTemplate).id(creation.id)
            }
        }
        .task(id: templateReadID) { await templateSelection.read(templateReadID) }
    }
    private var mayClear: Bool { mayEditTimeRange && timeRange.presentation == nil }
    private func saveLocalDraft() {
        guard let account, let draftStore else { return }
        do {
            try draftStore.saveActive(PublishingLocalDraft(session: account, identity: draftID, activity: draft, wizardStep: wizardStep), session: account)
            message = "publishModes.savedLocal"
            draftSaveState = .savedDraft(updatedAt: Self.draftTimestampNow())
        } catch {
            message = "publishModes.storageFailed"
            draftSaveState = .saveFailed(reason: appLocalized("publishModes.storageFailed", locale: locale), onRetry: { saveLocalDraft() })
        }
    }
    private static func draftTimestampNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    private var mayEditTimeRange: Bool {
        editable && review == nil && !localReview && picker == nil &&
            (service == nil || service?.currentSession == account)
    }
    /// Red input error under the field the wizard stopped on.
    @ViewBuilder private func fieldError(_ field: String) -> some View {
        if wizardBlock == field {
            Text(verbatim: ActivityPublishingWizardValidationPresentation(locale: locale).message(for: field))
                .cyText(.meta).foregroundStyle(palette.danger).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("publishModes.activity.wizard.validation")
        }
    }
    private func chooserRow(_ title: LocalizedStringKey, value: String?, icon: String? = nil) -> some View {
        CYListRow(title, trailing: .valueChevron(value ?? "—")) { if let icon { CYRowIcon(systemImage: icon) } }
    }
    private func clearButton(_ field: ActivityPublishingLocalClearOwner.Field) -> some View {
        let action = localClear.action(field, draft: $draft, account: account, draftID: draftID, allowed: { mayClear })
        return Button(action: action) {
            Label("publishModes.clear", systemImage: "xmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(palette.textTertiary)
        }.buttonStyle(.borderless)
            .disabled(!mayClear || !localClear.canClear(field, draft: draft, account: account, draftID: draftID))
            .accessibilityIdentifier("publishModes.activity.clear." + field.id)
    }
    @ViewBuilder private var pickerSheet: some View {
        if picker == "place" {
            PublishingPlacePicker(provider: placeSearch) { place in draft.place = place; draft.addressName = place.name; picker = nil }
        } else {
            PublishingOptionsPicker(service: service, account: account, kind: picker ?? "category", selected: picker == "category" ? draft.categoryIDs : picker == "collaborator" ? draft.collaboratorMemberIDs : draft.playTemplateID.map { [$0.rawValue] } ?? []) { values in
                if picker == "category" { draft.categoryIDs = values }
                else if picker == "collaborator" { draft.collaboratorMemberIDs = values }
                else { draft.playTemplateID = values.first.flatMap { AuthoringPlayTemplateID(rawValue: $0) } }; picker = nil
            }
        }
    }
    @ViewBuilder private var submissionResult: some View {
        if let outcome = submission.outcome {
            Section {
                switch outcome {
                case .acknowledged:
                    Text("publishModes.acknowledged")
                case .unknown:
                    Text("publishModes.unknown")
                case .notSent: Text("publishModes.notSent")
                case .rejected(let reason):
                    Text("publishModes.rejected")
                    if !reason.isEmpty { Text(verbatim: reason) }
                }
                if submission.canReadReceipt {
                    Button(chinese ? "查看本次创建结果" : "Read this creation request's outcome") { Task { await submission.readReceipt() } }
                        .accessibilityIdentifier("publishModes.activity.result.request")
                }
                if submission.receipt?.terminal == true {
                    Button(chinese ? "明确新建另一场活动" : "Explicitly create another activity") {
                        guard submission.startAnotherActivity() else { return }
                        draft = ActivityPublishDraft(); draftID = UUID(); wizardStep = 0; wizardBlock = nil
                        review = nil; localReview = false; message = ""
                    }.disabled(submission.busy)
                }
                if submission.receiptReadUnavailable { Text(chinese ? "本次回读暂不可用，保留原结果，不重发创建请求。" : "Readback is temporarily unavailable. Retain the original outcome without resending creation.") }
                if let receipt = submission.receipt {
                    if let id = receipt.activityID, receipt.committed {
                        Text(chinese ? "原请求创建的活动：\(id)。已创建不等于审核通过或上架。" : "Activity created by the original request: \(id). Creation does not mean approval or listing.")
                        if let openResource, let resource = try? PublishedResource(kind: .activity, value: id) {
                            Button(chinese ? "打开本次创建的活动" : "Open the activity created by this request") { openResource(resource) }.disabled(!submission.canReadProjects)
                        }
                    }
                    if let processing = receipt.processing {
                        Text((chinese ? "原抽检：" : "Original spot check: ") + processingLabel(processing.spotCheckState))
                        ForEach(processing.audits, id: \.taskID) { audit in
                            Text((chinese ? "原抽检任务 \(audit.taskID)：" : "Original spot-check task \(audit.taskID): ") + processingLabel(audit.state))
                            ForEach(Array(audit.actions.enumerated()), id: \.offset) { _, action in Text(processingLabel(action)) }
                        }
                        ForEach(processing.media, id: \.mediaSHA256) { media in
                            Text((chinese ? "原媒体送检：" : "Original media review: ") + processingLabel(media.state))
                            if let risky = media.risky { Text(risky ? (chinese ? "原回调判定有风险" : "Original callback flagged risk") : (chinese ? "原回调未标记风险" : "Original callback did not flag risk")) }
                        }
                        if submission.canResumeProcessing {
                            Button(chinese ? "继续本请求尚未完成的送检处理" : "Continue this request's unfinished review processing") { Task { await submission.readReceipt(resume: true) } }
                                .accessibilityIdentifier("publishModes.activity.result.resumeProcessing")
                            Text(chinese ? "只继续原后处理，不重建活动，不重复发送结果未知的媒体。" : "Continue original post-processing only, without recreating the activity or resending media with unknown outcomes.")
                        }
                    } else if receipt.postProcessing != nil {
                        Text(chinese ? "原后处理关联暂不可用，已提交的活动事实仍保留。" : "The original post-processing link is temporarily unavailable. The submitted activity facts remain intact.")
                    }
                    if let state = receipt.auditState { Text((chinese ? "原审核轮次：" : "Original review round: ") + state) }
                    if let actions = receipt.auditActions, !actions.isEmpty { Text(actions.joined(separator: "、")) }
                }
                if let account, let service, let openResource,
                   submission.canReadProjects, service.currentSession == account {
                    NavigationLink {
                        PublishingProjectsView(service: service, account: account, openResource: { resource in
                            guard service.currentSession == account else { return }; openResource(resource)
                        }, readOnly: true).id(account.epoch)
                    } label: { Text("publishModes.projects") }
                    .accessibilityIdentifier("publishModes.activity.result.projects")
                }
            }.accessibilityIdentifier("publishModes.activity.result")
        } else if submission.lockUnavailable {
            Text("publishModes.readFailed").accessibilityIdentifier("publishModes.activity.result.lockUnavailable")
        }
    }
    /// The same condition as the result card's 项目 link: a signed-in owner that can read its projects.
    private var resultProjectsAvailable: Bool {
        guard let account, let service, openResource != nil else { return false }
        return submission.canReadProjects && service.currentSession == account
    }
    private func processingLabel(_ code: String) -> String {
        if chinese { return ProjectEditPostProcessingReceipt.label(code) }
        switch code {
        case "PENDING": return "Waiting for processing"
        case "FAILED": return "Unfinished; processing can continue"
        case "NOT_REQUIRED": return "Not required for this request"
        case "DEFERRED_DRAFT": return "Draft markers retained without public review submission"
        case "RECORDED": return "Original processing record saved"
        case "STALE_SOURCE": return "Content changed; the old request was not continued"
        case "SUPERSEDED": return "A later submission round exists"
        case "AWAITING_NEW_RECORD": return "Waiting for the original review workflow's next record"
        case "RECORDED_DECISION": return "Associated review decision read back"
        case "WAITING", "PROCESSING": return "Waiting for the media review callback"
        case "DONE": return "Media callback processed"
        case "RETRYABLE_CALLBACK": return "Original callback queue awaits recovery"
        case "IGNORED_STALE": return "Stale media callback ignored"
        case "MANUAL_REVIEW": return "Manual review in the original workflow is needed"
        case "NOT_CONFIGURED": return "Review service is not configured"
        case "REGISTERED": return "Original review receipt registered"
        case "WRITER_BUNDLE_SUBMISSION": return "Combined review submission for this request"
        case "SPOT_CHECK_REUSED": return "Reused the original open spot check without a new submission"
        case "SPOT_CHECK_CREATED": return "Created the original spot check for this request"
        case "APPROVE": return "Approved"
        case "REJECT": return "Rejected"
        case "REVERT": return "Original decision reverted"
        case "CANCEL": return "Cancelled"
        case "ESCALATE": return "Escalated for review"
        default: return "Status is uncertain; nothing was resent"
        }
    }
    private func goNext() {
        if let next = ActivityPublishingWizard.advance(from: wizardStep, draft: draft) {
            wizardStep = next; wizardBlock = nil; message = ""
        } else {
            wizardStep = ActivityPublishingWizard.located(wizardStep, draft: draft)
            wizardBlock = ActivityPublishingWizard.blockingField(wizardStep, draft)
            message = "publishModes.invalid"
        }
    }
    private func goBack() { wizardStep = ActivityPublishingWizard.retreat(from: wizardStep); wizardBlock = nil }
    private func cancelWizard() {
        guard editable else { return }
        if draft == ActivityPublishDraft() { dismiss() } else { abandonConfirm = true }
    }
    private func prepare() async {
        guard ActivityPublishingWizard.acceptsReview(draft) else {
            wizardStep = ActivityPublishingWizard.located(ActivityPublishingWizard.steps.count, draft: draft)
            wizardBlock = ActivityPublishingWizard.blockingField(wizardStep, draft)
            message = "publishModes.invalid"
            return
        }
        guard let operation = submission.begin(allowCovered: false) else { return }
        localClear.invalidate(); timeRange.retire()
        defer { submission.finish(operation) }
        do {
            _ = try draft.wire()
            let value: PublishingReview?
            if let service, let account { value = try await service.prepareActivity(draft, session: account) }
            else { value = nil }
            guard submission.isCurrent(operation) else { if let value { service?.cancel(value) }; return }
            review = value; localReview = true; message = ""
        } catch {
            guard submission.isCurrent(operation), let key = ActivityPublishingSubmissionOwner.preparationMessage(error) else { return }; message = key
        }
    }
    private func submit(_ snapshot: PublishingReview) async {
        guard let review, review == snapshot, let service, review.session == account,
              let operation = submission.begin(allowCovered: true, submitting: true) else { return }
        localReview = false
        let result = await service.submit(review)
        guard submission.receive(result, operation: operation) else { return }
        self.review = nil; message = ""
    }
}
/// A local action lease for the full activity form, never a persistence or dispatch capability.
@MainActor final class ActivityPublishingLocalClearOwner: ObservableObject {
    enum Field {
        case name, description, ticketName(UUID), ticketStock(UUID)
        var id: String {
            switch self {
            case .name: return "name"
            case .description: return "description"
            case .ticketName(let id): return "ticketName." + id.uuidString
            case .ticketStock(let id): return "ticketStock." + id.uuidString
            }
        }
        func applying(to source: ActivityPublishDraft) -> ActivityPublishDraft? {
            var next = source
            switch self {
            case .name: guard !source.name.isEmpty else { return nil }; next.name = ""
            case .description: guard !source.description.isEmpty else { return nil }; next.description = ""
            case .ticketName(let id), .ticketStock(let id):
                guard source.tickets.filter({ $0.id == id }).count == 1,
                      let index = source.tickets.firstIndex(where: { $0.id == id }) else { return nil }
                if case .ticketName = self {
                    guard !source.tickets[index].name.isEmpty else { return nil }; next.tickets[index].name = ""
                } else {
                    guard source.tickets[index].stock != "0" else { return nil }; next.tickets[index].stock = "0"
                }
            }
            return next
        }
    }
    private struct Source: Encodable {
        let account: PublishingSession?
        let draftID: UUID
        let draft: ActivityPublishDraft
        let editable: Bool
    }
    private var source: Data?
    private var generation = UUID()
    private var visible = false
    private var active = false
    @Published private(set) var revision = 0
    private func bytes(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, editable: Bool = true) -> Data? {
        ProjectEditPendingMaterials.exactData(Source(account: account, draftID: draftID, draft: draft, editable: editable))
    }
    func bind(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, editable: Bool = true) {
        let next = bytes(account: account, draftID: draftID, draft: draft, editable: editable)
        if next != source { generation = UUID(); source = next }
    }
    func appear(active: Bool) {
        if !visible { invalidate(); visible = true }
        setActive(active)
    }
    func setActive(_ next: Bool) {
        guard next != active else { return }; invalidate(); active = next
    }
    func invalidate() { generation = UUID(); revision += 1 }
    func retire() { visible = false; invalidate() }
    func canClear(_ field: Field, draft: ActivityPublishDraft, account: PublishingSession?, draftID: UUID) -> Bool {
        visible && active && source != nil && source == bytes(account: account, draftID: draftID, draft: draft) &&
            field.applying(to: draft) != nil
    }
    func action(_ field: Field, draft: Binding<ActivityPublishDraft>, account: PublishingSession?, draftID: UUID,
                allowed: @escaping () -> Bool) -> () -> Void {
        let stamp = generation, expected = source
        return { [weak self] in
            guard let self, self.generation == stamp, self.source == expected, allowed(),
                  self.canClear(field, draft: draft.wrappedValue, account: account, draftID: draftID),
                  let next = field.applying(to: draft.wrappedValue) else { return }
            self.invalidate(); draft.wrappedValue = next
        }
    }
}


/// A local pair draft. Conversion reuses the existing publishing date codec.
struct ActivityPublishingTimeRangeDraft {
    var start: Date
    var end: Date
    private let originalStart: String
    private let originalEnd: String
    init?(source: ActivityPublishDraft, now: Date) {
        let first = ProjectEditDateSelection.date(source.start, ending: false)
        let last = ProjectEditDateSelection.date(source.end, ending: false)
        guard (source.start.isEmpty || first != nil), (source.end.isEmpty || last != nil),
              let fallback = ProjectEditDateSelection.beijingValue(now).flatMap({ ProjectEditDateSelection.date($0, ending: false) }) else { return nil }
        start = first ?? fallback; end = last ?? start.addingTimeInterval(3600)
        originalStart = source.start; originalEnd = source.end
    }
    func applying(to source: ActivityPublishDraft) -> ActivityPublishDraft? {
        guard source.start.utf8.elementsEqual(originalStart.utf8), source.end.utf8.elementsEqual(originalEnd.utf8),
              end > start, let first = ProjectEditDateSelection.beijingValue(start),
              let last = ProjectEditDateSelection.beijingValue(end), last > first else { return nil }
        var next = source
        if ProjectEditDateSelection.date(originalStart, ending: false) != start { next.start = first }
        if ProjectEditDateSelection.date(originalEnd, ending: false) != end { next.end = last }
        return next
    }
}


@MainActor final class ActivityPublishingTimeRangeOwner: ObservableObject {
    struct Presentation: Identifiable {
        let id = UUID()
        let generation: UUID
        let source: Data
        let draft: ActivityPublishingTimeRangeDraft
        let timeZoneID: String
    }
    private struct Source: Encodable {
        let account: PublishingSession?
        let draftID: UUID
        let draft: ActivityPublishDraft
        let editable: Bool
    }
    let objectWillChange = ObservableObjectPublisher()
    private var dismantling = false
    private(set) var presentation: Presentation? { willSet { publishChange() } }
    private func publishChange() { if !dismantling { objectWillChange.send() } }
    private var source: Data?
    private var generation = UUID()
    private var pageVisible = false { willSet { publishChange() } }
    private var sheetID: UUID?
    private var coveredByOwnSheet = false
    private var active = false { willSet { publishChange() } }
    private func bytes(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, editable: Bool = true) -> Data? {
        ProjectEditPendingMaterials.exactData(Source(account: account, draftID: draftID, draft: draft, editable: editable))
    }
    func bind(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, editable: Bool) {
        let next = bytes(account: account, draftID: draftID, draft: draft, editable: editable)
        if source != next { source = next; generation = UUID() }
    }
    func appear(active: Bool) {
        if !pageVisible, sheetID == nil, presentation != nil { retire() }
        pageVisible = true; setActive(active)
    }
    func parentAppeared() { pageVisible = true; coveredByOwnSheet = false }
    func parentDisappeared(departing: Bool, coveredByPresentation: Bool) {
        // UIKit may report coverage before the new sheet's onAppear. The concrete
        // route may survive that order, but Apply still requires its own sheetID.
        guard !departing, coveredByPresentation, active, let presentation,
              generation == presentation.generation, source == presentation.source else { disappear(); return }
        coveredByOwnSheet = true; pageVisible = false
    }
    func disappear() { pageVisible = false; coveredByOwnSheet = false; retire() }
    func dismantle() {
        dismantling = true; disappear(); dismantling = false
        Task { @MainActor [weak self] in self?.objectWillChange.send() }
    }
    func setActive(_ value: Bool) { active = value; if !value { retire() } }
    func retire() { generation = UUID(); presentation = nil; sheetID = nil; coveredByOwnSheet = false }
    func canOpen(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, now: Date) -> Bool {
        pageVisible && active && presentation == nil && source != nil &&
        source == bytes(account: account, draftID: draftID, draft: draft) && ActivityPublishingTimeRangeDraft(source: draft, now: now) != nil
    }
    func open(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, now: Date, timeZoneID: String) {
        guard canOpen(account: account, draftID: draftID, draft: draft, now: now), let source,
              let value = ActivityPublishingTimeRangeDraft(source: draft, now: now), TimeZone(identifier: timeZoneID) != nil else { return }
        presentation = .init(generation: generation, source: source, draft: value, timeZoneID: timeZoneID)
    }
    func current(_ value: Presentation, timeZoneID: String) -> Bool {
        active && (pageVisible || coveredByOwnSheet) && presentation?.id == value.id &&
        generation == value.generation && source == value.source && value.timeZoneID == timeZoneID
    }
    func sheetAppeared(_ value: Presentation, timeZoneID: String) {
        guard current(value, timeZoneID: timeZoneID) else { return }; sheetID = value.id
    }
    func close(_ value: Presentation) {
        guard presentation?.id == value.id else { return }; retire()
    }
    func binding(_ value: Presentation, timeZoneID: @escaping () -> String) -> Binding<Presentation?> {
        .init(get: {
            guard self.current(value, timeZoneID: timeZoneID()) else { return nil }; return value
        }, set: { if $0 == nil { self.close(value) } })
    }
    @discardableResult func apply(_ edited: ActivityPublishingTimeRangeDraft, original: Presentation,
                                  draft: Binding<ActivityPublishDraft>, account: PublishingSession?, draftID: UUID,
                                  timeZoneID: String, allowed: Bool) -> Bool {
        guard allowed, sheetID == original.id, current(original, timeZoneID: timeZoneID),
              source == bytes(account: account, draftID: draftID, draft: draft.wrappedValue),
              let next = edited.applying(to: draft.wrappedValue) else { return false }
        retire()
        if ProjectEditPendingMaterials.exactData(next) != ProjectEditPendingMaterials.exactData(draft.wrappedValue) { draft.wrappedValue = next }
        return true
    }
}

/// One already-open route owns its sheet binding; an initial nil body owns no presenter.
@MainActor struct ActivityPublishingTimeRangePresenter: View {
    @ObservedObject var owner: ActivityPublishingTimeRangeOwner
    let original: ActivityPublishingTimeRangeOwner.Presentation
    let apply: (ActivityPublishingTimeRangeDraft) -> Bool
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(item: owner.binding(original, timeZoneID: { TimeZone.autoupdatingCurrent.identifier })) { offered in
                Group {
                    ActivityPublishingTimeRangeSheet(owner: owner, original: offered, apply: apply)
                }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
    }
}

/// Keep modal coverage separate from the source controller leaving its hierarchy.
@MainActor struct ActivityPublishingTimeRangeLifetimeAnchor: UIViewControllerRepresentable {
    let owner: ActivityPublishingTimeRangeOwner
    func makeUIViewController(context: Context) -> ActivityPublishingTimeRangeLifetimeController {
        ActivityPublishingTimeRangeLifetimeController(owner: owner)
    }
    func updateUIViewController(_ controller: ActivityPublishingTimeRangeLifetimeController, context: Context) {}
    static func dismantleUIViewController(_ controller: ActivityPublishingTimeRangeLifetimeController, coordinator: ()) {
        controller.owner?.dismantle()
    }
}
@MainActor final class ActivityPublishingTimeRangeLifetimeController: UIViewController {
    weak var owner: ActivityPublishingTimeRangeOwner?
    private var departing = false
    init(owner: ActivityPublishingTimeRangeOwner) { self.owner = owner; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { return nil }
    private var ancestry: [UIViewController] {
        var result: [UIViewController] = [], next: UIViewController? = self
        while let value = next { result.append(value); next = value.parent }
        return result
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); departing = false; owner?.parentAppeared()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        departing = ancestry.contains { $0.isMovingFromParent || $0.isBeingDismissed }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated); let source = ancestry
        owner?.parentDisappeared(departing: departing || source.contains { $0.isMovingFromParent || $0.isBeingDismissed },
            coveredByPresentation: source.contains { $0.presentedViewController != nil })
    }
}

@MainActor struct ActivityPublishingTimeRangeSheet: View {
    @ObservedObject var owner: ActivityPublishingTimeRangeOwner
    let original: ActivityPublishingTimeRangeOwner.Presentation
    let apply: (ActivityPublishingTimeRangeDraft) -> Bool
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @State private var draft: ActivityPublishingTimeRangeDraft
    @State private var editingEnd = false
    @State private var failure = false
    #if DEBUG
    /// Design fixtures only: treats the synthetic presentation as current so the controls render enabled.
    var designPreview = false
    #endif
    init(owner: ActivityPublishingTimeRangeOwner, original: ActivityPublishingTimeRangeOwner.Presentation,
         apply: @escaping (ActivityPublishingTimeRangeDraft) -> Bool) {
        self.owner = owner; self.original = original; self.apply = apply
        _draft = State(initialValue: original.draft)
    }
    private var current: Bool {
        #if DEBUG
        if designPreview { return true }
        #endif
        return owner.current(original, timeZoneID: TimeZone.autoupdatingCurrent.identifier)
    }
    private func endpointRow(_ key: LocalizedStringKey, value: String, selected: Bool) -> some View {
        HStack(spacing: CYSpacing.md) {
            Text(key).cyText(selected ? .label : .body).foregroundStyle(selected ? palette.textPrimary : palette.textSecondary)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: value).cyText(.numericBody).monospacedDigit()
                .foregroundStyle(selected ? palette.textPrimary : palette.textTertiary)
        }
        .padding(CYSpacing.lg).frame(minHeight: 56)
        .background(selected ? palette.bgRaised : palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).stroke(selected ? palette.borderStrong : .clear, lineWidth: 1) }
        .contentShape(Rectangle())
    }
    var body: some View {
        // Mini-program 设置活动时间 sheet: start / end switch, the picker, then one primary step button.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    Text("publishModes.beijingTime").cyText(.label).foregroundStyle(palette.textTertiary)
                    VStack(spacing: CYSpacing.sm) {
                        Button { editingEnd = false; failure = false } label: {
                            endpointRow("publishModes.start", value: ProjectEditDateSelection.beijingValue(draft.start) ?? "—", selected: !editingEnd)
                        }.buttonStyle(.plain)
                        endpointRow("publishModes.end", value: editingEnd ? (ProjectEditDateSelection.beijingValue(draft.end) ?? "—") : "—", selected: editingEnd)
                    }
                    DatePicker(selection: editingEnd ? $draft.end : $draft.start, displayedComponents: [.date, .hourAndMinute]) {
                        Text(LocalizedStringKey(editingEnd ? "publishModes.end" : "publishModes.start"))
                    }.datePickerStyle(.graphical).labelsHidden()
                        .tint(palette.textPrimary)
                        .environment(\.timeZone, TimeZone(identifier: original.timeZoneID) ?? .gmt)
                        .padding(CYSpacing.sm)
                        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityIdentifier("publishModes.activity.timeRange.date")
                    if failure || (editingEnd && draft.end <= draft.start) {
                        Text("publishModes.timeRange.invalid").cyText(.meta).foregroundStyle(palette.danger)
                            .accessibilityIdentifier("publishModes.activity.timeRange.invalid")
                    }
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            }
            .disabled(!current)
            .cyDomainPageBackground()
            .navigationTitle(Text("publishModes.timeRange.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("publishModes.cancel") { owner.close(original) }.accessibilityIdentifier("publishModes.activity.timeRange.cancel")
            } }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if editingEnd {
                        CYPillButton("publishModes.done") {
                            guard current else { return }; failure = !apply(draft)
                        }
                        .disabled(!current || draft.end <= draft.start).accessibilityIdentifier("publishModes.activity.timeRange.apply")
                    } else {
                        CYPillButton("publishModes.wizard.next") {
                            guard current else { return }
                            if draft.end <= draft.start { draft.end = draft.start.addingTimeInterval(3600) }
                            editingEnd = true; failure = false
                        }
                        .disabled(!current)
                        .accessibilityIdentifier("publishModes.activity.timeRange.next")
                    }
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                .background(palette.bgPage)
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { owner.sheetAppeared(original, timeZoneID: TimeZone.autoupdatingCurrent.identifier) }
            .onDisappear { owner.close(original) }
    }
}

@MainActor struct PublishingOptionsPicker: View {
    let service: PublishingService?
    let account: PublishingSession?
    let kind: String
    @State var selected: [Int]
    var onConfirm: ([Int]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var rows: [PublishingOption] = []
    @State private var busy = false
    @State private var failed = false
    @State private var generation = 0
    var body: some View {
        NavigationStack {
            List {
                if busy { ProgressView().frame(maxWidth: .infinity) }
                if failed {
                    ContentUnavailableView {
                        Label("publishModes.readFailed", systemImage: "exclamationmark.triangle")
                    } actions: { Button("publishModes.retry") { Task { await load() } } }
                }
                if !busy && !failed && rows.isEmpty { ContentUnavailableView("publishModes.empty", systemImage: "magnifyingglass") }
                ForEach(rows) { row in
                    Button {
                        if selected.contains(row.id) { selected.removeAll { $0 == row.id } }
                        else if kind == "template" { selected = [row.id] } else { selected.append(row.id) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name).foregroundStyle(Color.primary)
                                if !row.detail.isEmpty { Text(row.detail).font(.footnote).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if selected.contains(row.id) { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        }
                    }.accessibilityValue(selected.contains(row.id) ? Text("publishModes.selected") : Text("publishModes.notSelected"))
                }
            }.searchable(text: $keyword).onSubmit(of: .search) { Task { await load() } }
            .onChange(of: keyword) { _, value in if value.isEmpty { Task { await load() } } }
            .navigationTitle(Text(LocalizedStringKey(kind == "category" ? "publishParity.activity.type" : kind == "collaborator" ? "publishModes.collaborators" : "publishModes.template")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("publishModes.cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("publishModes.done") { onConfirm(selected) } } }
            .task { await load() }.onDisappear { generation += 1 }
        }
    }
    private func load() async {
        generation += 1; let stamp = generation; busy = true; failed = false
        guard let service, let account else { failed = true; busy = false; return }
        let query: PublishingRead = kind == "category" ? .categories(activity: true) : kind == "collaborator" ? .collaborators(keyword: keyword) : .templates(keyword: keyword, scope: "")
        do { let value = try await service.read(query, session: account); guard stamp == generation else { return }; rows = try PublishingContracts.options(value, kind: query); busy = false }
        catch { guard stamp == generation else { return }; rows = []; busy = false; failed = true }
    }
}
@MainActor struct PublishingPlacePicker: View {
    var provider: (any PublishingPlaceSearching)?
    var onConfirm: (PublishingPlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var rows: [PublishingPlace] = []
    @State private var selected: PublishingPlace?
    @State private var busy = false
    @State private var failed = false
    @State private var generation = 0
    var body: some View {
        NavigationStack {
            List {
                if busy { ProgressView().frame(maxWidth: .infinity) }
                if failed || provider == nil { Text("publishModes.mapUnavailable").foregroundStyle(CYColor.dangerText) }
                if let selected {
                    Map(initialPosition: .region(.init(center: .init(latitude: selected.latitude, longitude: selected.longitude), span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker(selected.name, coordinate: .init(latitude: selected.latitude, longitude: selected.longitude))
                    }.frame(height: 240).id(selected.id).accessibilityLabel(Text(selected.name))
                    .listRowInsets(EdgeInsets())
                }
                ForEach(rows) { place in
                    Button { selected = place } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name).foregroundStyle(Color.primary)
                                Text(place.address).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected?.id == place.id { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        }
                    }
                }
                if rows.isEmpty && !busy && !failed && provider != nil { ContentUnavailableView("publishModes.searchPlace", systemImage: "mappin.and.ellipse") }
            }.searchable(text: $keyword).onSubmit(of: .search) { Task { await search() } }
            .onChange(of: keyword) { _, value in if value.isEmpty { generation += 1; selected = nil; rows = []; busy = false } }
            .navigationTitle(Text("publishModes.choosePlace")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("publishModes.cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("publishModes.confirmPlace") { if let selected { onConfirm(selected) } }.disabled(selected == nil) } }
            .onDisappear { generation += 1 }
        }
    }
    private func search() async {
        generation += 1; let stamp = generation; selected = nil; rows = []; failed = false
        guard let provider, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { busy = false; return }; busy = true
        do { let result = try await provider.search(keyword); guard stamp == generation else { return }; rows = result; busy = false }
        catch { guard stamp == generation else { return }; busy = false; failed = true }
    }
}

/// A view occurrence owns presentation only. The existing service and persistent journal
/// retain write approval, dispatch and uncertain-outcome authority.
@MainActor final class ActivityPublishingSubmissionOwner: ObservableObject {
    struct Context: Equatable {
        let account: PublishingSession?
        let draftID: UUID
        let draft: Data
        let serviceID: ObjectIdentifier?
    }
    struct Operation: Equatable { let visit: UUID; let id: UUID; let context: Context; let submitting: Bool }
    @Published private(set) var busy = false
    @Published private(set) var outcome: PublishingWriteOutcome?
    @Published private(set) var receipt: ActivityCreateRequestContract.Receipt?
    @Published private(set) var receiptReadUnavailable = false
    @Published private(set) var lockUnavailable = false
    private var ignoredCompletedRequest: String?
    private var context: Context?
    private var service: PublishingService?
    private var visit = UUID()
    private var operation: Operation?
    private var visible = false
    private var covered = false
    private var active = true
    private var current: Bool {
        active && (visible || covered) && context != nil &&
            (service == nil || service?.currentSession == context?.account)
    }
    var canResumeProcessing: Bool { current && visible && !busy && receipt?.committed == true && receipt?.processing?.canResume == true && service?.canResumeActivityProcessing == true }
    var canReadReceipt: Bool { current && visible && !busy && service?.canReadActivityReceipt == true }
    var canReadProjects: Bool { current && visible && !busy && context?.account != nil && outcome != nil }
    func bind(account: PublishingSession?, draftID: UUID, draft: ActivityPublishDraft, service: PublishingService?) {
        guard let bytes = ProjectEditPendingMaterials.exactData(draft) else { retire(); context = nil; return }
        let next = Context(account: account, draftID: draftID, draft: bytes, serviceID: service.map(ObjectIdentifier.init))
        if context != next {
            if context?.account != account { ignoredCompletedRequest = nil }
            let preserveUnknown = context?.account == account && (outcome == .unknown || operation?.submitting == true)
            retire(); context = next; self.service = service
            if preserveUnknown { outcome = .unknown }
            refreshLock()
        }
    }
    func appeared() { visible = true; covered = false; refreshLock() }
    func disappeared(departing: Bool, coveredByPresentation: Bool) {
        visible = false
        if !departing && coveredByPresentation && active { covered = true; return }
        covered = false; invalidateOperation()
    }
    func setActive(_ value: Bool) { active = value; if !value { invalidateOperation() } else { refreshLock() } }
    func retire() { invalidateOperation(); outcome = nil; receipt = nil; receiptReadUnavailable = false; lockUnavailable = false }
    private func invalidateOperation() {
        // An interrupted submission cannot become a fresh editable form just because
        // its presentation callback was retired. Never clear the service journal here.
        if operation?.submitting == true { outcome = .unknown }
        visit = UUID(); operation = nil; busy = false
    }
    private func refreshLock() {
        guard let account = context?.account, let service, service.currentSession == account else { return }
        do {
            let pending = try service.hasUncertainOutcome(targetKey: "publishModes:activity:create", session: account)
            receipt = try service.retainedActivityReceipt(session: account)
            if !pending, receipt?.requestId == ignoredCompletedRequest { receipt = nil; outcome = nil }
            lockUnavailable = false
            if pending { outcome = .unknown }
            else if receipt?.committed == true { outcome = .acknowledged }
            else if receipt?.state == "REJECTED" { outcome = .rejected("原创建请求已拒绝") }
        } catch { lockUnavailable = true }
    }
    func startAnotherActivity() -> Bool {
        guard current && visible && !busy, receipt?.terminal == true, outcome != .unknown, !lockUnavailable else { return false }
        ignoredCompletedRequest = receipt?.requestId; receipt = nil; outcome = nil
        return true
    }
    func readReceipt(resume: Bool = false) async {
        guard (resume ? canResumeProcessing : canReadReceipt), let account = context?.account, let service, let context else { return }
        let value = Operation(visit: visit, id: UUID(), context: context, submitting: false)
        operation = value; busy = true; receiptReadUnavailable = false
        do {
            let result: ActivityCreateRequestContract.Receipt
            if resume { result = try await service.resumeActivityProcessing(session: account) }
            else { result = try await service.readActivityOutcome(session: account) }
            guard isCurrent(value) else { return }
            receipt = result; outcome = result.committed ? .acknowledged : result.state == "REJECTED" ? .rejected("原创建请求已拒绝") : .unknown
            operation = nil; busy = false; refreshLock()
        } catch {
            guard isCurrent(value) else { return }; receiptReadUnavailable = true; operation = nil; busy = false
        }
    }
    static func preparationMessage(_ error: Error) -> String? {
        if error is CancellationError { return nil }
        guard let failure = error as? PublishModesError else { return "publishModes.readFailed" }
        switch failure {
        case .invalidDraft: return "publishModes.invalid"
        case .changedSession: return nil
        case .forbidden: return "publishModes.clubOnly"
        case .staleReview, .conflict: return "publishModes.conflict"
        case .storage: return "publishModes.storageFailed"
        case .rejected: return "publishModes.rejected"
        case .invalidContract, .unavailable, .uncertain: return "publishModes.readFailed"
        }
    }
    func begin(allowCovered: Bool, submitting: Bool = false) -> Operation? {
        refreshLock()
        guard current, (visible || allowCovered), !busy, !lockUnavailable,
              outcome != .acknowledged, outcome != .unknown, let context else { return nil }
        let value = Operation(visit: visit, id: UUID(), context: context, submitting: submitting)
        operation = value; busy = true; outcome = nil; return value
    }
    func isCurrent(_ value: Operation) -> Bool {
        current && busy && operation == value && value.visit == visit && value.context == context
    }
    func finish(_ value: Operation) {
        guard isCurrent(value) else { return }; operation = nil; busy = false
    }
    @discardableResult func receive(_ result: PublishingWriteOutcome, operation value: Operation) -> Bool {
        guard isCurrent(value) else { return false }
        operation = nil; busy = false; outcome = result; refreshLock(); return true
    }
}

/// Modal review coverage is distinct from leaving the creator navigation hierarchy.
@MainActor struct ActivityPublishingSubmissionLifetime: UIViewControllerRepresentable {
    let owner: ActivityPublishingSubmissionOwner
    func makeUIViewController(context: Context) -> ActivityPublishingSubmissionLifetimeController { .init(owner: owner) }
    func updateUIViewController(_ controller: ActivityPublishingSubmissionLifetimeController, context: Context) {}
    static func dismantleUIViewController(_ controller: ActivityPublishingSubmissionLifetimeController, coordinator: ()) {
        controller.owner?.disappeared(departing: true, coveredByPresentation: false)
    }
}
@MainActor final class ActivityPublishingSubmissionLifetimeController: UIViewController {
    weak var owner: ActivityPublishingSubmissionOwner?
    private var departing = false
    init(owner: ActivityPublishingSubmissionOwner) { self.owner = owner; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { return nil }
    private var ancestry: [UIViewController] {
        var result: [UIViewController] = [], next: UIViewController? = self
        while let value = next { result.append(value); next = value.parent }; return result
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); departing = false; owner?.appeared() }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); departing = ancestry.contains { $0.isMovingFromParent || $0.isBeingDismissed } }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let source = ancestry
        owner?.disappeared(departing: departing || parent == nil || source.contains { $0.isMovingFromParent || $0.isBeingDismissed },
                           coveredByPresentation: source.contains { $0.presentedViewController != nil })
    }
}
