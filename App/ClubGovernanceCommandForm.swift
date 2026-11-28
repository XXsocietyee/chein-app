import SwiftUI

/// View activity only. Retiring a ticket never changes the coordinator or its journal.
/// A separate UUID distinguishes concurrent/repeated work within the same generation.
@MainActor struct ClubGovernanceFormLifecycle {
    enum Work: Equatable { case prepare, confirm, customerEdit }
    struct Context: Equatable {
        let identity: ClubReadIdentity?
        let currentIdentity: ClubReadIdentity?
        let authorization: UUID?
        let access: ObjectIdentifier
        let coordinator: ObjectIdentifier
        let operation: ClubGovernanceMutation
        let scope: ClubGovernanceScope
        let namespace: Data
        let realm: Data
        let configured: Bool
        let visible: Bool
        let active: Bool
        @MainActor init(identity: ClubReadIdentity?, access: any ClubGovernanceAccess, coordinator: ClubGovernanceCoordinator,
             operation: ClubGovernanceMutation, scope: ClubGovernanceScope, visible: Bool, active: Bool) {
            self.identity = identity; currentIdentity = access.identity; authorization = access.authorizationGeneration
            self.access = ObjectIdentifier(access); self.coordinator = ObjectIdentifier(coordinator)
            self.operation = operation; self.scope = scope
            namespace = Data(access.storageNamespace.utf8); realm = Data(access.journalRealm.utf8)
            configured = access.isConfigured; self.visible = visible; self.active = active
        }
        var permitsPresentation: Bool { visible && active && configured && identity?.accountID != nil && identity == currentIdentity }
    }
    struct Ticket: Equatable {
        fileprivate let id: UUID
        fileprivate let generation: UInt64
        fileprivate let context: Context
        let work: Work
    }
    private(set) var generation: UInt64 = 0
    private var activity: Ticket?
    var busy: Bool { activity != nil }
    mutating func begin(_ work: Work, in context: Context) -> Ticket? {
        guard !busy, context.permitsPresentation else { return nil }
        let ticket = Ticket(id: UUID(), generation: generation, context: context, work: work)
        activity = ticket; return ticket
    }
    func owns(_ ticket: Ticket, in context: Context) -> Bool {
        activity == ticket && generation == ticket.generation && context.permitsPresentation && ticket.context == context
    }
    mutating func finish(_ ticket: Ticket) {
        guard activity == ticket else { return }
        activity = nil
    }
    mutating func retire() { generation &+= 1; activity = nil }
}

@MainActor struct ClubGovernanceCommandForm: View {
    let route: ClubGovernanceFormRoute
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    let validateTarget: (() async throws -> Void)?
    let seriesUpdateReturn: ClubSeriesUpdateReturn.Callbacks?
    let seriesCreationReturn: ClubSeriesCreationReturn.Callbacks?
    let occurrenceCancellationReturn: ClubOccurrenceCancellationReturn.Callbacks?
    let caseSubmissionReturn: ClubCaseSubmissionReturn.Callbacks?
    let attendanceReturn: ClubAttendanceCorrectionReturn.Callbacks?
    let roleManagementReturn: ClubRoleManagementReturn.Callbacks?
    let topicSettingsReturn: ClubTopicSettingsReturn.Callbacks?
    let banRemovalReturn: ClubBanRemovalReturn.Callbacks?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var hostMaterials = ClubHostApplicationMaterials()
    @StateObject private var rolePicker = ClubRoleAssignmentReadModel()
    @StateObject private var seriesLeadPicker = ClubSeriesLeadReadModel()
    @StateObject private var notificationAudience = ClubNotificationAudienceReadModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.clubOpsEventTopicFact) private var eventTopicFact
    @Environment(\.clubProfileDraftFlow) private var profileDraftFlow
    @Environment(\.clubDissolvedReturn) private var dissolvedReturn
    /// The object the consequence sheet names: the role (revoke), the member (ban), the topic (结束主题) or the club (解散).
    private var consequenceObjectName: String? {
        switch route.operation {
        case .revokeRole: return route.seed["roleName"]?.string
        case .ban: return route.seed["targetNickname"]?.string
        case .endTopic: return route.seed["topicName"]?.string
        case .dissolve: return dissolvedReturn?.clubName
        default: return nil
        }
    }
    /// mp-club r3 pass 17 (MP danger-actions `club.dissolve.alt`, edit js:35-39 goGovernance): the dissolve confirm's
    /// 改为转让主理人 closes this form without dissolving and lets the edit page open 成员治理. Nil outside the edit page.
    private var transferInsteadAction: (() -> Void)? {
        guard route.operation == .dissolve, let transfer = dissolvedReturn?.transferInstead else { return nil }
        return {
            consequenceReview = nil
            retirePresentation()
            coordinator.cancelReview()
            dismiss()
            transfer()
        }
    }
    /// CLB-group-code-04 (fix-r3-club-b round 3): the session label the event tools pass in (never a command field).
    @Environment(\.clubRoleActivityLabel) private var sessionLabel
    @QuestifyReduceMotion private var reduceMotion
    @State private var audienceVisible = false
    @State private var scheduleSession: ClubSeriesScheduleSession?
    @State private var draft: ClubGovernanceFormDraft
    @State private var review: ClubGovernanceReview?
    @State private var failure: ClubGovernanceFailure?
    @State private var receipt: ClubGovernanceValue?
    @State private var groupCode: ClubGovernanceGroupCode?
    /// CLB-notify-05 (fix-r3-club-b round 4): the latest silently re-read status of the campaign in `receipt`.
    @State private var campaignRefresh: ClubGovernanceValue?
    /// CLB-notify-05 (MP notify wxml:76-78, js:300-325): the inline 刷新 / 刷新中… read and its one-line result.
    @State private var campaignRefreshing = false
    @State private var campaignRefreshNotice: LocalizedStringKey?
    @State private var presentation = ClubGovernanceFormLifecycle()
    private var busy: Bool { presentation.busy }
    @State private var dirty = false
    @State private var locked = false
    @State private var showDiscard = false
    @State private var cancelConfirmReview: ClubGovernanceReview?
    /// verify-r1 3.8 / MC-33: the heavy club commands (封禁, 转让, 撤销身份, 解散) confirm in `ClubConsequenceSheet`,
    /// which replaces the plain confirm, so the organiser is asked once, with the consequences in front of them.
    @State private var consequenceReview: ClubGovernanceReview?
    @State private var consequenceAccepted: ClubGovernanceReview.ID?
    /// CLB-apply-02 (MP apply wxml:36-43): the intro already showed on the host-status page, so the form opens at step 1.
    @State private var applyStep = 1
    @State private var applyBlocked = false
    /// CLB-roles-04: the missing-field line under 分配, cleared on the next tap that passes.
    @State private var directHint: String?
    private var generation: UInt64 { presentation.generation }
    private var presentationContext: ClubGovernanceFormLifecycle.Context {
        .init(identity: identity, access: access, coordinator: coordinator, operation: route.operation,
              scope: route.scope, visible: audienceVisible, active: scenePhase == .active)
    }
    private func retirePresentation() {
        presentation.retire(); review = nil; cancelConfirmReview = nil; consequenceReview = nil
    }
    init(route: ClubGovernanceFormRoute, identity: ClubReadIdentity?, access: any ClubGovernanceAccess, coordinator: ClubGovernanceCoordinator, validateTarget: (() async throws -> Void)? = nil, caseSubmissionReturn: ClubCaseSubmissionReturn.Callbacks? = nil, attendanceReturn: ClubAttendanceCorrectionReturn.Callbacks? = nil, roleManagementReturn: ClubRoleManagementReturn.Callbacks? = nil, topicSettingsReturn: ClubTopicSettingsReturn.Callbacks? = nil, banRemovalReturn: ClubBanRemovalReturn.Callbacks? = nil, seriesUpdateReturn: ClubSeriesUpdateReturn.Callbacks? = nil, seriesCreationReturn: ClubSeriesCreationReturn.Callbacks? = nil, occurrenceCancellationReturn: ClubOccurrenceCancellationReturn.Callbacks? = nil) {
        self.route = route; self.identity = identity; self.access = access; self.coordinator = coordinator; self.validateTarget = validateTarget
        self.caseSubmissionReturn = caseSubmissionReturn
        self.attendanceReturn = attendanceReturn
        self.roleManagementReturn = roleManagementReturn
        self.topicSettingsReturn = topicSettingsReturn
        self.banRemovalReturn = banRemovalReturn
        self.seriesUpdateReturn = seriesUpdateReturn
        self.seriesCreationReturn = seriesCreationReturn
        self.occurrenceCancellationReturn = occurrenceCancellationReturn
        let initial = ClubGovernanceFormDraft(operation: route.operation, scope: route.scope, seed: route.seed)
        _draft = State(initialValue: initial)
    }
    var body: some View {
        let _ = bindRolePicker()
        let _ = bindSeriesLeadPicker()
        let _ = bindNotificationAudience()
        Form {
            // The internal draft/gate notes and the raw target IDs are no longer shown: users never chose them.
            if ClubOpsGovernanceFormNotes.applies(route.operation) { Section { ClubOpsGovernanceFormNotes(operation: route.operation, seed: route.seed) } }
            if route.operation == .hostApply {
                // Mini-program club/apply: intro, then one of four steps. Cert upload stays hidden.
                if applyStep == 0 {
                    Section {
                        Text(verbatim: ClubPlayerCopy.applyIntroTitle(locale))
                            .cyText(.pageTitle)
                            .accessibilityIdentifier("club.player.apply.intro")
                    }
                }
                if applyStep == 1 {
                    Section {
                        ForEach(["leaderName", "phone", "identity", "coFounders"], id: \.self) { applyFieldRow($0) }
                    } header: { applyStepHeader(1) } footer: { applyContactFooter }
                        .disabled(busy || locked || review != nil)
                }
                if applyStep == 2 {
                    Section {
                        ForEach(["experience", "maxEventSize", "avgEventSize"], id: \.self) { applyFieldRow($0) }
                    } header: { applyStepHeader(2) } footer: {
                        // CLB-r10-nat-apply-03: the field error sits in the footer (MP apply js 请选择组织经验 toast).
                        if applyBlocked, (draft.text["experience"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(verbatim: ClubPlayerCopy.applyExperienceGap(locale)).foregroundStyle(.red)
                                .accessibilityIdentifier("club.player.apply.experienceGap")
                        }
                    }
                        .disabled(busy || locked || review != nil)
                }
                if applyStep == 3 {
                    Section {
                        ForEach(["canDesignRoute", "canDesignTask", "canNpc", "canMerchantCoop"], id: \.self) { flagRow($0) }
                        Text("club.host.skills.selectedCount \(ClubHostApplyPort.capabilityCount(draft.flags))").cyText(.bodyCompact).foregroundStyle(.secondary)
                    } header: { applyStepHeader(3) }
                        .disabled(busy || locked || review != nil)
                }
                if applyStep == 4 {
                    Section {
                        flagRow("hasGuideCert")
                    } header: { applyStepHeader(4) }
                        .disabled(busy || locked || review != nil)
                    // CLB-apply-05: 资质 / 案例图, uploaded like the MP and sent as `certImages` (comma-joined URLs).
                    ClubHostCertImagesSection(urlsText: textBinding("certImages"), disabled: busy || locked || review != nil)
                }
            } else if route.operation == .sendNotification {
                // Mini-program club/notify: 选择受众 list, then 内容.
                Section("club.gov.field.audienceType") {
                    ClubNotificationAudienceView(context: audienceContext, access: access, model: notificationAudience,
                        selection: textBinding("audienceType"), canEdit: { audienceIsCurrent && !busy && !locked && review == nil },
                        isCurrent: { audienceIsCurrent })
                }.disabled(busy || locked || review != nil)
                Section {
                    ClubOpsNotifyContentFields(title: textBinding("title"), content: textBinding("content"))
                } header: { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.content.section") }
                    .disabled(busy || locked || review != nil)
            } else if route.operation == .createSeries {
                // CLB-r10-nat-event-ops-04 (MP event-ops wxml:253): 容量 / 候补 are their own Section between the
                // schedule rows and the remaining fields; the other operations keep one Section.
                Section { commandLeadRows }.disabled(busy || locked || review != nil)
                ClubOpsEventCapacitySection(capacity: textBinding("capacity"), waitlist: flagBinding("waitlistEnabled"),
                                            showsCapacity: eventTopicFact?.showsCapacity ?? true)
                    .disabled(busy || locked || review != nil)
                Section { commandFieldRows }.disabled(busy || locked || review != nil)
            } else {
                Section {
                    commandLeadRows
                    commandFieldRows
                }.disabled(busy || locked || review != nil)
                // CLB-r10-nat-event-ops-04: the cancel / correct reason is its own Section with a footer.
                if route.operation == .cancelOccurrence || route.operation == .correctAttendance {
                    ClubOpsEventReasonField(operation: route.operation, reason: textBinding("reason"))
                        .disabled(busy || locked || review != nil)
                }
            }
            if let failure, route.operation == .issueGroupCode, ClubGroupCodePort.classify(failure) == .noPermission {
                // Mini isPermissionDenial: terminal state with an exit, not a retry.
                Section {
                    Label("club.gov.groupCode.noPermission", systemImage: "lock").accessibilityIdentifier("club.gov.groupCode.noPermission")
                    // mp-club r3 (MP group-code wxml:28-31): the exit is 进入俱乐部管理 (goManage), not a plain back.
                    NavigationLink { ClubGroupCodeMissingLinkView.manageDestination } label: { Text("gap.club.groupCode.enterManage") }
                        .accessibilityIdentifier("club.gov.groupCode.back")
                }
            } else if let failure, route.operation == .saveCustomer {
                // CLB-customer-detail-04 (fix-r3-club-b round 2): MP cy-inline-error 标签与备注没保存成功, the server
                // sentence (or 请重试), and 重试保存. An unknown outcome (`locked`) never offers the retry.
                Section {
                    Label { Text("clubR3b.customer.saveFailed") } icon: { Image(systemName: "exclamationmark.circle") }
                        .font(.headline).foregroundStyle(.red)
                        .accessibilityIdentifier("club.gov.formError")
                    if let message = failure.message { Text(verbatim: message).foregroundStyle(.secondary) }
                    else { Text("clubR3b.customer.saveFailedRetry").foregroundStyle(.secondary) }
                    if !locked {
                        Button("clubR3b.customer.retrySave") { Task { await submitDirectly() } }
                            .disabled(busy || identity == nil)
                            .accessibilityIdentifier("club.gov.customer.retrySave")
                    }
                }
            } else if let failure, route.operation == .issueGroupCode {
                // CLB-r8-group-code-02 (fix-r8-club): MP club-game-code-sheet error state (wxml:15-19): the server
                // sentence or 团码暂时没能生成，请稍后重试, and 重试 inside the code card.
                Section {
                    Group {
                        if let message = failure.message { Text(verbatim: message) }
                        else { Text("clubR8b.groupCode.failed") }
                    }
                    .accessibilityIdentifier("club.gov.formError")
                    if !locked {
                        Button("clubR8b.retry") { Task { await reissueGroupCode() } }
                            .disabled(busy || identity == nil)
                            .accessibilityIdentifier("club.gov.groupCode.retry")
                    }
                }
            } else if let failure, route.operation == .hostApply {
                // CLB-r8-apply-01 (fix-r8-club): MP apply wxml:157 cy-inline-error 提交没有完成 + submitError + 重试.
                Section {
                    Label { Text("clubR8b.apply.submitFailed") } icon: { Image(systemName: "exclamationmark.circle") }
                        .font(.headline).foregroundStyle(.red)
                        .accessibilityIdentifier("club.gov.formError")
                    if let message = failure.message { Text(verbatim: message).foregroundStyle(.secondary) }
                    else { Text(LocalizedStringKey(failure.localizationKey)).foregroundStyle(.secondary) }
                    if !locked {
                        Button("clubR8b.retry") {
                            Task {
                                if let pending = review { await confirm(pending) }
                                else { await prepare(); if let pending = review { await confirm(pending) } }
                            }
                        }
                        .disabled(busy || identity == nil || !hostMaterialsReady)
                        .accessibilityIdentifier("club.player.apply.retrySubmit")
                    }
                }
            } else if let failure, route.operation == .sendNotification, review == nil, receipt == nil {
                // MP notify wxml:59-62: a failed 预览受众 is inline 受众预览失败 + the reason + 重试.
                Section {
                    Label { Text("club.notify.previewFailed") } icon: { Image(systemName: "exclamationmark.circle") }
                        .font(.headline).foregroundStyle(.red)
                        .accessibilityIdentifier("club.gov.formError")
                    if let message = failure.message { Text(verbatim: message).foregroundStyle(.secondary) }
                    else { Text(LocalizedStringKey(failure.localizationKey)).foregroundStyle(.secondary) }
                    if !locked {
                        Button("action.retry") { Task { await prepare() } }
                            .disabled(busy || identity == nil || !notificationAudienceReady)
                            .accessibilityIdentifier("club.notify.previewRetry")
                    }
                }
            } else if let failure { Section { Text(LocalizedStringKey(failure.localizationKey)).accessibilityIdentifier("club.gov.formError"); if let message = failure.message { Text(verbatim: message) } } }
            if busy, route.operation == .issueGroupCode, groupCode == nil {
                // CLB-r8-group-code-01 (fix-r8-club): MP sheet state loading shows a 生成中 placeholder in the code slot.
                // CLB-r10-nat-group-code-02: one system `ProgressView("生成中")`.
                Section {
                    ProgressView {
                        Text("clubR8b.groupCode.generating")
                            .accessibilityIdentifier("club.gov.groupCode.generating")
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if busy { ProgressView() }
            if let review, !(Self.directOperations.contains(route.operation) && consequenceReview?.id == review.id) {
                Section {
                    // mp-club r3 (MP notify wxml:55-64): the notify review is the preview card (N 人) only; 受众/标题/内容
                    // stay visible in the form above, so they are not repeated as fact rows.
                    if route.operation != .sendNotification {
                    ClubGovernanceFactRows(value: .object(review.command.fields), fields: Array(review.command.fields.keys).sorted().filter { $0 != "expiresAtEpochMs" && $0 != "durationDays" && $0 != "id" && !$0.hasSuffix("Id") && !$0.hasSuffix("Ids") && !$0.hasSuffix("ID") }, showUnknown: true, localizesEnums: true)
                    }
                    if route.operation == .createSeries, review.command.fields["defaultLeadMemberId"] == .null {
                        LabeledContent("club.gov.field.defaultLeadMemberId") { Text("clubOpsEvent.lead.ownerDefault", tableName: "ClubOpsEvent") }
                            .accessibilityIdentifier("clubOpsEvent.review.ownerDefault")
                    }
                    ClubOpsBanExpiryReview(fields: review.command.fields)
                    if showsCustomDateConversion {
                        Text("club.schedule.customConversion", tableName: "ClubSeriesSchedule")
                            .accessibilityIdentifier("club.schedule.reviewConversion")
                    }
                    if route.operation == .sendNotification { ClubOpsNotifyPreviewSummary(value: review.snapshot.value) }
                    // CLB-notify-01 (fix-r3-club-b), MC-26: the send primary names the action and the head count.
                    Button {
                        if route.operation == .cancelOccurrence { cancelConfirmReview = review } else { Task { await confirm(review) } }
                    } label: {
                        if route.operation == .sendNotification, !access.allowsOfflineWrites,
                           let count = ClubNotifyPage.previewRecipient(review.snapshot.value).literal {
                            Text("clubR3b.notify.sendTo \(count)")
                        } else if route.operation == .sendNotification, !access.allowsOfflineWrites {
                            Text("clubR3b.notify.send")
                        } else {
                            Text(LocalizedStringKey(access.allowsOfflineWrites ? "club.gov.confirmOffline" : "club.gov.confirmProduction"))
                        }
                    }
                        .disabled(!coordinator.canDispatch(review.command) || busy || locked).accessibilityIdentifier("club.gov.confirm")
                    if ClubOpsEventWriteGate.state(canDispatch: coordinator.canDispatch(review.command), busy: busy, locked: locked).showsNotAvailableNote {
                        Text("clubOpsEvent.write.notAvailable", tableName: "ClubOpsEvent").cyText(.bodyCompact).foregroundStyle(.secondary)
                            .accessibilityIdentifier("clubOpsEvent.write.notAvailable")
                    }
                    Button("club.gov.cancelReview") { self.review = nil; coordinator.cancelReview() }.disabled(busy)
                }
            } else if receipt == nil {
                if route.operation == .hostApply && applyStep < 4 { applyAdvanceButton }
                if route.operation == .hostApply && applyStep > 1 {
                    Button {
                        guard !busy, !locked else { return }
                        applyBlocked = false
                        setApplyStep(applyStep - 1)
                    } label: { Text(verbatim: locale.pick("上一步", "Back")) }
                    .disabled(busy || locked)
                    .accessibilityIdentifier("club.player.apply.back")
                }
                if route.operation == .hostApply && applyStep == 4 {
                    // CLB-apply-03 (parity r2), MC-10: the last step submits directly as 提交申请; the fact-row review
                    // stays only as the fallback when the submit could not finish.
                    // mp-club r3 (MP apply wxml:164-165): the button reads 成为俱乐部主理人, 提交中… while it submits.
                    Button(busy ? LocalizedStringKey("gap.club.coopPool.submitting") : LocalizedStringKey("settings.becomeClubHost")) {
                        Task {
                            await prepare()
                            if let pending = review { await confirm(pending) }
                        }
                    }
                    .disabled(busy || locked || identity == nil || !hostMaterialsReady || !ClubHostApplyPort.canReview(text: draft.text))
                    .accessibilityIdentifier("club.gov.prepare")
                }
                if route.operation == .saveCustomer || route.operation == .issueGroupCode {
                    // CLB-customer-detail-04 / CLB-group-code-02 (fix-r3-club-b): MP 保存 and 出示团码 act on one tap;
                    // the reviewed command still runs (prepare, then confirm), with no separate 下一步 → 确认 step.
                    Button(LocalizedStringKey(route.operation == .saveCustomer ? "clubR3b.customer.save" : "clubR3b.groupCode.issue")) {
                        Task { await submitDirectly() }
                    }
                    .disabled(busy || locked || identity == nil || !groupCodeCanIssue)
                    .accessibilityIdentifier("club.gov.prepare")
                } else if Self.directOperations.contains(route.operation) {
                    // CLB-governance-03 / CLB-roles-04 (fix-r8-club): MP governance and roles act on one tap (governance
                    // js:435-452, roles js:400-415). Heavy commands still stop once on the consequence sheet (MC-33);
                    // 分配 stays tappable and names the missing field instead of greying out.
                    if let directHint {
                        Text(LocalizedStringKey(directHint)).font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("club.gov.directHint")
                    }
                    Button(LocalizedStringKey("club.gov.action." + route.operation.rawValue)) {
                        if let missing = directMissingField { directHint = missing; return }
                        directHint = nil
                        Task { await submitDirectly() }
                    }
                    .disabled(busy || locked || identity == nil)
                    .accessibilityIdentifier("club.gov.prepare")
                } else if route.operation != .hostApply {
                // CLB-notify-01 (fix-r3-club-b): MP 预览受众 before the send, not a generic 下一步.
                Button(LocalizedStringKey(route.operation == .sendNotification ? "clubR3b.notify.preview" : "club.gov.review")) { Task { await prepare() } }.disabled(busy || locked || identity == nil || !roleAssignmentReady || !seriesScheduleReady || !seriesLeadReady || !hostMaterialsReady || !notificationAudienceReady || (route.operation == .hostApply && !ClubHostApplyPort.canReview(text: draft.text))).accessibilityIdentifier("club.gov.prepare")
                }
            }
            if route.operation == .createSeries {
                ClubSeriesOriginalResultSection(scope: route.scope, identity: identity, access: access,
                    coordinator: coordinator, formID: route.id)
            }
            if let groupCode {
                // mp-club r3 pass 8 (MP group-code wxml:38-39 → club-game-code-sheet wxml:9-24): 活动核验团码, the code,
                // then the session name under it and 保存到相册; no name above the card.
                Section {
                    ClubGroupCodePresentation(value: groupCode,
                        current: identity == access.identity && scenePhase == .active,
                        onReissue: busy || locked ? nil : { Task { await reissueGroupCode() } },
                        sessionName: ClubRoleActivityLabel.entry(sessionLabel))
                }
            }
            if let receipt {
                Section {
                    ClubOpsGovernanceSuccess(operation: route.operation)
                    if route.operation == .correctAttendance { Text("clubOpsEvent.correct.success", tableName: "ClubOpsEvent").accessibilityIdentifier("clubOpsEvent.correct.success") }
                    // Campaign counts render once, in the notify card, when the receipt parses as a campaign.
                    let campaignReceipt = [.sendNotification, .retryNotification].contains(route.operation) && (try? ClubOpsNotifyCampaign(value: receipt)) != nil
                    ClubGovernanceFactRows(value: receipt, fields: campaignReceipt ? ["id"] : ["id", "activityId", "refundStatus", "totalCount", "successCount", "failedCount", "refundedOrders", "manualOrders"])
                    ForEach(Array((receipt["failedSessions"].array ?? []).enumerated()), id: \.offset) { _, value in Text(verbatim: value.string ?? "") }
                    if route.operation == .endTopic {
                        // CLB-r11-topic-detail-01: MP topic-detail/index.js:1172 toast(endResultText(d)).
                        Text(verbatim: endTopicResultText(receipt))
                            .accessibilityIdentifier("club.gov.endTopic.result")
                    }
                    // CLB-G15 (MP event-ops wxml:200): the series-create receipt's windowWarning, the server's own sentence.
                    if route.operation == .createSeries, let warning = receipt["windowWarning"].string?.trimmingCharacters(in: .whitespacesAndNewlines), !warning.isEmpty {
                        Label { Text(verbatim: warning) } icon: { Image(systemName: "exclamationmark.triangle") }
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("clubOpsEvent.series.windowWarning")
                    }
                    // CLB-apply-11 (MP apply/index.js:415, wxml:177): 主理人 comes from the submitted draft, not a status read.
                    if route.operation == .hostApply, let leader = draft.text["leaderName"]?.trimmingCharacters(in: .whitespacesAndNewlines), !leader.isEmpty {
                        LabeledContent("club.host.done.leaderLabel") { Text(verbatim: leader) }
                            .accessibilityIdentifier("club.host.receipt.leader")
                    }
                } header: {
                    Text("club.gov.acknowledged")
                }
                if [.sendNotification, .retryNotification].contains(route.operation), let campaign = try? ClubOpsNotifyCampaign(value: refreshedCampaign ?? receipt) {
                    // MP notify/index.wxml:72-111: 投递状态 is its own section, 刷新 / 刷新中… in the section head,
                    // the five count rows, then 只重试失败项 under the card.
                    Section {
                        ClubOpsNotifyCampaignRows(campaign: campaign, outcome: route.operation)
                        notifyRetryLink
                        if let campaignRefreshNotice {
                            Text(campaignRefreshNotice)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("club.notify.refreshNotice")
                        }
                    } header: {
                        HStack(alignment: .firstTextBaseline) {
                            Text("club.notify.deliveryStatus")
                                .accessibilityAddTraits(.isHeader)
                            Spacer(minLength: 8)
                            if notifyCampaignID != nil { notifyRefreshButton }
                        }
                    }
                }
                if route.operation == .hostApply { Section { ClubCreateMyClubLink(identity: identity) } }
            }
        }
        .background {
            if route.operation == .hostApply {
                let context = hostMaterialsContext
                if let attachment = hostMaterials.attachment {
                    ClubHostApplicationMaterialsLifetime { hostMaterials.depart(context, attachment: attachment) }
                        .frame(width: 0, height: 0).id(attachment)
                }
                if let value = hostMaterials.presentation {
                    ClubHostApplicationMaterialsOwner(model: hostMaterials, value: value,
                        allowed: { hostMaterialsAllowed }, changed: { dirty = true }).id(value.id)
                }
            }
        }
        .onAppear { activateHostMaterials(appearing: true) }
        .onDisappear { hostMaterials.hide() }
        .onChange(of: hostMaterialsContext) { _, _ in activateHostMaterials() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { activateHostMaterials() } else { hostMaterials.retire() }
        }
        .navigationTitle(ClubOpsEventFormCopy.title(route)).navigationBarTitleDisplayMode(.inline)
        .cySheet(isPresented: Binding(get: { cancelConfirmReview != nil }, set: { if !$0 { cancelConfirmReview = nil } })) {
            NavigationStack {
                List {
                    Section {
                        Label { Text("clubOpsEvent.cancel.consequence1", tableName: "ClubOpsEvent") } icon: { Image(systemName: "exclamationmark.triangle") }
                        Label { Text("clubOpsEvent.cancel.consequence2", tableName: "ClubOpsEvent") } icon: { Image(systemName: "person.2.slash") }
                    } footer: {
                        Text("clubOpsEvent.cancel.confirmBody", tableName: "ClubOpsEvent")
                    }
                }
                .navigationTitle(Text("clubOpsEvent.cancel.confirmTitle", tableName: "ClubOpsEvent"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { cancelConfirmReview = nil } label: { Text("clubOpsEvent.cancel.keep", tableName: "ClubOpsEvent") }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .destructive) {
                            guard let pending = cancelConfirmReview, pending.id == review?.id else { cancelConfirmReview = nil; return }
                            cancelConfirmReview = nil; Task { await confirm(pending) }
                        } label: { Text("clubOpsEvent.cancel.confirmAction", tableName: "ClubOpsEvent") }
                        .foregroundStyle(.red)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .cySheet(isPresented: Binding(get: { consequenceReview != nil }, set: { if !$0 { consequenceReview = nil } })) {
            if let kind = ClubGovernanceConsequence(route.operation) {
                kind.sheet(locale: locale, name: consequenceObjectName, alternative: transferInsteadAction) {
                    guard let pending = consequenceReview, pending.id == review?.id else { consequenceReview = nil; return }
                    consequenceReview = nil; consequenceAccepted = pending.id; Task { await confirm(pending) }
                }

            }
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            // CLB-apply-09: 关闭 stays in the bar on every step; 上一步 sits in the bottom actions.
            Button {
                if dirty || busy || locked { showDiscard = true } else { dismiss() }
            } label: {
                Text("club.gov.close")
            }
        } }
        .interactiveDismissDisabled(dirty || busy || locked)
        .confirmationDialog(Text(verbatim: appLocalized("club.gov.discardTitle", locale: locale)), isPresented: $showDiscard, titleVisibility: .visible) {
            Button(role: .destructive) {
                showDiscard = false; retirePresentation(); coordinator.cancelReview(); dismiss()
            } label: { Text(verbatim: appLocalized("club.gov.discard", locale: locale)) }
            Button(role: .cancel) { showDiscard = false } label: { Text("action.cancel") }
        } message: {
            Text(verbatim: locked ? appLocalized("club.gov.unknown", locale: locale) : appLocalized("club.gov.discardBody", locale: locale))
        }
        .cySheet(item: $scheduleSession) { session in Group {
            NavigationStack {
                ClubSeriesScheduleEditor(session: session, canApply: { canApplySchedule(session) }, apply: { selection in
                    guard canApplySchedule(session), let next = try? selection.applying(to: draft, now: Date()) else { return false }
                    draft = next; dirty = true; review = nil; failure = nil; coordinator.cancelReview(); scheduleSession = nil
                    return true
                })
            }
        }.cySheet(detents: [.large])
        }
        .onChange(of: access.authorizationGeneration) { _, _ in scheduleSession = nil }
        // CLB-governance-12 (MP governance js:584-605): after the transfer is acknowledged, leave the form after 1.5 s
        // so the governance page re-reads under the new owner.
        .task(id: route.operation == .transferOwner && receipt != nil) {
            guard route.operation == .transferOwner, receipt != nil else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, receipt != nil else { return }
            dismiss()
        }
        // CLB-r11-edit-01 (MP edit/index.js:23-30 onDissolved): 俱乐部已解散, then after 0.5 s leave the form and the
        // edit page (navigateBack).
        .task(id: route.operation == .dissolve && receipt != nil) {
            guard route.operation == .dissolve, receipt != nil else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, receipt != nil else { return }
            if let dissolvedReturn { dissolvedReturn.leave() } else { dismiss() }
        }
        .onChange(of: identity) { _, _ in scheduleSession = nil; retirePresentation(); review = nil; receipt = nil; groupCode = nil; coordinator.cancelReview(); draft = .init(operation: route.operation, scope: route.scope); failure = .staleReview; dismiss() }
        .task(id: rolePickerContext) {
            guard route.operation == .assignRole, let permit = rolePicker.activate(rolePickerContext) else { return }
            await rolePicker.load(permit, access: access)
        }
        .task(id: seriesLeadContext) {
            guard route.operation == .createSeries, let permit = seriesLeadPicker.activate(seriesLeadContext) else { return }
            await seriesLeadPicker.load(permit, access: access)
        }
        .onAppear { audienceVisible = true }
        .onChange(of: presentationContext) { _, _ in retirePresentation(); coordinator.cancelReview() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { notificationAudience.leave(audienceContext) }
        }
        .task(id: AudienceTrigger(context: audienceContext, visible: audienceVisible, active: scenePhase == .active)) {
            guard route.operation == .sendNotification, audienceIsCurrent,
                  let permit = notificationAudience.activate(audienceContext) else { return }
            let expected = audienceContext
            await notificationAudience.load(permit, access: access, isCurrent: { audienceIsCurrent && audienceContext == expected })
        }
        .onChange(of: access.authorizationGeneration) { _, _ in
            groupCode = nil
            if route.operation == .issueGroupCode { receipt = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                groupCode = nil
                if route.operation == .issueGroupCode { receipt = nil }
            }
        }
        // CLB-notify-05 (fix-r3-club-b round 4): MP notify onShow re-reads the campaign silently (index.js:293-326), so
        // counts left at 处理中 catch up on return from the status page or the background. A failed read keeps the
        // numbers already shown; nothing is announced either way.
        .task(id: "\(notifyCampaignID ?? 0)|\(scenePhase == .active)") {
            guard scenePhase == .active else { return }
            await refreshCampaign(silent: true)
        }
        .onChange(of: notifyCampaignID) { _, _ in campaignRefresh = nil; campaignRefreshNotice = nil }
        // CLB-group-code-02 (fix-r3-club-b): MP issues the code as the page opens (index.js:93-135).
        .task {
            guard route.operation == .issueGroupCode, groupCodeCanIssue, review == nil, receipt == nil, groupCode == nil, failure == nil else { return }
            await submitDirectly()
        }
        .onDisappear { groupCode = nil; if route.operation == .issueGroupCode { receipt = nil }; audienceVisible = false; notificationAudience.leave(audienceContext); seriesLeadPicker.leave(seriesLeadContext); scheduleSession = nil; retirePresentation(); coordinator.cancelReview(); rolePicker.leave(rolePickerContext) }
    }
    private var hostMaterialsContext: ClubHostApplicationMaterials.Context {
        ClubHostApplicationMaterials.context(formID: route.id, scope: route.scope, identity: identity, access: access)
    }
    private var hostMaterialsAllowed: Bool {
        route.operation == .hostApply && scenePhase == .active && identity?.isSignedIn == true &&
            identity == access.identity && hostMaterials.context == hostMaterialsContext && !busy && !locked && review == nil
    }
    private var hostMaterialsReady: Bool {
        route.operation != .hostApply || (hostMaterials.isCurrent(hostMaterialsContext, allowed: { hostMaterialsAllowed }) && !hostMaterials.blocksSubmission)
    }
    private func activateHostMaterials(appearing: Bool = false) {
        guard route.operation == .hostApply else { return }
        guard scenePhase == .active, identity?.isSignedIn == true, identity == access.identity else { hostMaterials.retire(); return }
        if appearing { hostMaterials.appear(hostMaterialsContext) } else { hostMaterials.activate(hostMaterialsContext) }
    }
    private struct AudienceTrigger: Hashable {
        let context: ClubNotificationAudienceReadModel.Context
        let visible: Bool
        let active: Bool
    }
    private var audienceContext: ClubNotificationAudienceReadModel.Context {
        ClubNotificationAudienceReadModel.context(scope: route.scope, identity: identity, access: access)
    }
    private var notifyCampaignID: Int? { receipt?["id"].int }
    /// CLB-notify-05: 投递状态 refreshes in place (MP `refreshCampaign`, wxml:76-78); 刷新中… with a system spinner while the read runs.
    @ViewBuilder private var notifyRefreshButton: some View {
        Button {
            Task { await refreshCampaign(silent: false) }
        } label: {
            if campaignRefreshing {
                Label { Text("club.notify.refreshing") } icon: { ProgressView() }
            } else {
                Label("club.notify.refresh", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.borderless)
        .font(.footnote)
        .textCase(nil)
        .disabled(campaignRefreshing || busy)
        .accessibilityIdentifier("club.notify.refreshCampaign")
    }
    /// CLB-r11-notify-01 (MP notify/index.wxml:107-110, js retryFailed): 只重试失败项 under the receipt card while the
    /// campaign has failed recipients, pushing the retry command as the status page does (ClubGovernanceViews `edit(.retryNotification)`).
    @ViewBuilder private var notifyRetryLink: some View {
        if [.sendNotification, .retryNotification].contains(route.operation), let shownReceipt = receipt,
           let campaignID = notifyCampaignID,
           (try? ClubOpsNotifyCampaign(value: refreshedCampaign ?? shownReceipt))?.canRetryFailed == true {
            let retryScope = ClubGovernanceScope(clubID: route.scope.clubID, activityID: route.scope.activityID, campaignID: campaignID)
            NavigationLink {
                ClubGovernanceCommandForm(route: .init(operation: .retryNotification, scope: retryScope),
                                          identity: identity, access: access, coordinator: coordinator)
            } label: { Text("club.gov.action.retryNotification") }
                .disabled(busy || campaignRefreshing)
                .accessibilityIdentifier("club.notify.retryFailed")
        }
    }
    private func endTopicResultText(_ receipt: ClubGovernanceValue) -> String {
        ClubTopicEndSummary.parse(receipt, sentEpoch: draft.anchors["cancellationEpoch"]?.int ?? -1)
            .resultText(chinese: AppLanguage.interfaceIsChinese(locale))
    }
    /// MP notify `refreshCampaign` (js:300-325): one status read at a time; a failed read keeps the numbers shown.
    /// Silent reads (onShow) say nothing; the 刷新 button says 投递状态已更新 or 投递状态没读到.
    private func refreshCampaign(silent: Bool) async {
        guard [.sendNotification, .retryNotification].contains(route.operation), !campaignRefreshing,
              identity == access.identity, let id = notifyCampaignID else { return }
        campaignRefreshing = true
        defer { campaignRefreshing = false }
        if !silent { campaignRefreshNotice = nil }
        let scope = ClubGovernanceScope(clubID: route.scope.clubID, activityID: route.scope.activityID, campaignID: id)
        guard let value = try? await access.read(.notificationStatus, scope: scope, options: [:]).value,
              !Task.isCancelled, value["id"].int == id, notifyCampaignID == id,
              (try? ClubOpsNotifyCampaign(value: value)) != nil else {
            if !silent, !Task.isCancelled { campaignRefreshNotice = "club.notify.refreshFailed" }
            return
        }
        campaignRefresh = value
        if !silent { campaignRefreshNotice = "club.notify.refreshed" }
    }
    /// The silent re-read, only while it belongs to the campaign the receipt names.
    private var refreshedCampaign: ClubGovernanceValue? {
        guard let campaignRefresh, let id = notifyCampaignID, campaignRefresh["id"].int == id else { return nil }
        return campaignRefresh
    }
    private var audienceIsCurrent: Bool { audienceVisible && scenePhase == .active && identity == access.identity }
    private func bindNotificationAudience() {
        if route.operation == .sendNotification { notificationAudience.bind(audienceContext) }
    }
    private var notificationAudienceReady: Bool {
        route.operation != .sendNotification || (audienceIsCurrent && notificationAudience.canPrepare(draft.text["audienceType"] ?? "", context: audienceContext, access: access))
    }
    private var rolePickerContext: ClubGovernanceReadContext {
        ClubRoleAssignmentReadModel.context(scope: route.scope, identity: identity, access: access)
    }
    private func bindRolePicker() {
        if route.operation == .assignRole { rolePicker.bind(rolePickerContext) }
    }
    private var roleAssignmentReady: Bool {
        route.operation != .assignRole || rolePicker.canPrepare(scope: route.scope, identity: identity, access: access,
            memberID: draft.text["targetMemberId"] ?? "", roleCode: draft.text["roleCode"] ?? "")
    }
    private var seriesLeadContext: ClubSeriesLeadReadModel.Context {
        ClubSeriesLeadReadModel.context(scope: route.scope, identity: identity, access: access)
    }
    private func bindSeriesLeadPicker() {
        if route.operation == .createSeries { seriesLeadPicker.bind(seriesLeadContext) }
    }
    private var seriesLeadReady: Bool {
        route.operation != .createSeries || seriesLeadPicker.canPrepare(scope: route.scope, identity: identity, access: access,
            memberID: draft.text["defaultLeadMemberId"] ?? "")
    }
    /// Role / lead pickers, the series schedule and the series notes (the first rows of the command Section).
    @ViewBuilder private var commandLeadRows: some View {
        if route.operation == .assignRole {
            ClubRoleAssignmentPicker(scope: route.scope, identity: identity, access: access, model: rolePicker,
                memberID: textBinding("targetMemberId"), roleCode: textBinding("roleCode"),
                canEdit: { !busy && !locked && review == nil },
                applySelection: { member, role in draft.applyClubRolePicker(memberID: member, roleCode: role) })
            if draft.flags["customerPhoneVisible"] != nil {
                Text("club.rolePicker.phoneVisible.hint").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("club.rolePicker.phoneVisible.hint")
            }
        }
        if route.operation == .createSeries {
            ClubSeriesLeadPicker(scope: route.scope, identity: identity, access: access, model: seriesLeadPicker,
                memberID: textBinding("defaultLeadMemberId"), canEdit: { !busy && !locked && review == nil })
        }
        if isSeries {
            Button("club.schedule.title") {
                scheduleSession = .init(form: draft, identity: identity, access: access, now: Date())
            }.disabled(identity == nil || identity != access.identity || !access.isConfigured).accessibilityIdentifier("club.schedule.open")
            if !(draft.text["startDate"] ?? "").isEmpty {
                ClubGovernanceFactRows(value: .object(draft.text.filter { ClubSeriesScheduleDraft.fieldKeys.contains($0.key) }.mapValues(ClubGovernanceValue.string)),
                    fields: ["recurrenceType", "startDate", "startTime", "occurrenceCount", "customDates"])
                if showsCustomDateConversion {
                    Text("club.schedule.customConversion", tableName: "ClubSeriesSchedule")
                        .accessibilityIdentifier("club.schedule.formConversion")
                }
                if let issue = ClubSeriesScheduleDraft(form: draft, now: Date()).issue(now: Date()) {
                    ClubSeriesScheduleIssueLabel(issue: issue, weeklyHorizon: ClubSeriesScheduleDraft(form: draft, now: Date()).weeklyHorizonMessage(now: Date()))
                }
            } else { Text("club.schedule.choose") }
        }
        if isSeries {
            ClubOpsEventSeriesFields(operation: route.operation, capacity: textBinding("capacity"), waitlist: flagBinding("waitlistEnabled"),
                                     topicFact: eventTopicFact)
        }
    }
    /// The remaining command inputs: offer window, reason, customer, ban, the generic text fields and flags.
    @ViewBuilder private var commandFieldRows: some View {
        if isSeries {
            ClubSeriesOfferWindowField(minutes: textBinding("offerMinutes"))
                .clubOpsEventVisible(showsOfferWindow)
            ClubOpsEventOfferHelp(minutes: draft.text["offerMinutes"] ?? "", visible: showsOfferWindow)
        }
        if route.operation == .saveCustomer {
            ClubOpsCustomerTagRemarkEditor(tagsText: textBinding("tags"), remark: textBinding("remark"))
        }
        if route.operation == .ban { ClubOpsBanDurationPicker(days: textBinding("banDays")) }
        ForEach(Array(draft.text.keys).sorted().filter { key in
            (route.operation != .ban || key != "banDays") && (route.operation != .revokeRole || key != "reason") &&
            (route.operation != .hostApply || key != "certImages") &&
            (route.operation != .assignRole || !["targetMemberId", "roleCode"].contains(key)) &&
            (!isSeries || (!ClubSeriesScheduleDraft.fieldKeys.contains(key) && key != "offerMinutes")) &&
            (route.operation != .createSeries || key != "defaultLeadMemberId") &&
            (!isSeries || key != "capacity") && (route.operation != .updateSeries || key != "defaultLeadMemberId") &&
            (![.cancelOccurrence, .correctAttendance].contains(route.operation) || key != "reason") &&
            (route.operation != .sendNotification || key != "audienceType") &&
            (route.operation != .sendNotification || !["title", "content"].contains(key)) &&
            (route.operation != .saveCustomer || !["tags", "remark"].contains(key)) &&
            // CLB-governance-09 (parity r2): inside a club the report is anchored to that club (MP CU-C-139);
            // the user is never asked for a target type or a raw target id.
            (route.operation != .report || route.scope.clubID == nil || !["targetType", "targetId"].contains(key))
        }, id: \.self) { key in fieldRow(key) }
        ForEach(Array(draft.flags.keys).sorted().filter { !isSeries || $0 != "waitlistEnabled" }, id: \.self) { key in
            flagRow(key)
        }
    }
    private var isSeries: Bool { [.createSeries, .updateSeries].contains(route.operation) }
    private var showsOfferWindow: Bool { route.operation == .createSeries && draft.flags["waitlistEnabled"] == true }
    private var showsCustomDateConversion: Bool {
        route.operation == .updateSeries && draft.text["recurrenceType"] == "CUSTOM_DATES" &&
        route.seed["recurrenceType"]?.string != "CUSTOM_DATES"
    }
    private var seriesScheduleReady: Bool {
        !isSeries || (!(draft.text["startDate"] ?? "").isEmpty && ClubSeriesScheduleDraft(form: draft, now: Date()).issue(now: Date()) == nil)
    }
    private func canApplySchedule(_ session: ClubSeriesScheduleSession) -> Bool {
        !busy && !locked && review == nil && session.isCurrent(activeID: scheduleSession?.id, form: draft, identity: identity, access: access)
    }
    private var gateKey: String {
        switch route.operation.risk { case .administrative: return "club.gov.writeGate"; case .financial: return "club.gov.financialGate"; case .identity: return "club.gov.identityGate"; case .provider: return "club.gov.providerGate" }
    }
    /// CLB-apply-06 (MP apply wxml:15-23): the create wizard's step header: four progress capsules, the 第 n 步 line
    /// and a large headline, on the page rather than in a card.
    @ViewBuilder private func applyStepHeader(_ step: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(step), total: 4)
                .accessibilityHidden(true)
            Text(verbatim: ClubPlayerCopy.progressLabel(step, locale: locale))
                .accessibilityIdentifier("club.player.apply.progress")
            Text(verbatim: ClubPlayerCopy.applyTitle(step: step, locale: locale))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("club.player.apply.stepTitle")
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }
    private var applyReady: Bool {
        applyStep == 0 || ClubHostApplyPort.canAdvance(step: applyStep, text: draft.text)
    }
    /// CLB-r10-nat-apply-03 (MP apply wxml:63-80): which fields are required, the privacy note, then the field
    /// errors, all in the step-1 footer instead of a red `*` and red rows between the inputs.
    @ViewBuilder private var applyContactFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("club.host.requiredFooter")
            Text("club.host.contactPrivate")
            if applyBlocked, (draft.text["leaderName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(verbatim: ClubPlayerCopy.applyNameGap(locale)).foregroundStyle(.red)
                    .accessibilityIdentifier("club.player.apply.nameGap")
            }
            if applyBlocked, (draft.text["phone"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(verbatim: ClubPlayerCopy.applyPhoneGap(locale)).foregroundStyle(.red)
                    .accessibilityIdentifier("club.player.apply.phoneGap")
            }
        }
    }
    private var applyAdvanceButton: some View {
        Button {
            guard applyReady else { applyBlocked = true; return }
            applyBlocked = false
            setApplyStep(applyStep + 1)
        } label: {
            Text(verbatim: applyStep == 0 ? ClubPlayerCopy.applyStart(locale) : ClubPlayerCopy.next(locale))
        }
        .disabled(busy || locked || review != nil)
        .accessibilityIdentifier("club.player.apply.next")
    }
    private func setApplyStep(_ next: Int) {
        if reduceMotion { applyStep = next } else { withAnimation(.easeInOut(duration: 0.2)) { applyStep = next } }
    }
    /// CLB-apply-07 (MP apply wxml:63-113): a persistent label on each input (the optional labels already read （选填）)
    /// and the MP placeholder inside it; the MP `*` became the step footer's required note (nat-apply-03). Choice fields keep `fieldRow`.
    @ViewBuilder private func applyFieldRow(_ key: String) -> some View {
        if key == "experience", let choices = draft.choices(key) {
            // CLB-apply-06 (MP apply wxml:94-101): 组织经验 is one radio card per option (create-wizard kit).
            ForEach(choices, id: \.self) { choice in
                ClubR1OptionCard(title: Text(LocalizedStringKey("club.gov.choice." + choice)),
                                 isSelected: draft.text[key] == choice) { textBinding(key).wrappedValue = choice }
                    .accessibilityIdentifier("club.gov.input.experience.\(choice)")
            }
        } else if draft.choices(key) != nil {
            fieldRow(key)
        } else {
            let required = ClubHostApplyFieldCopy.required.contains(key)
            // CLB-r10-nat-apply-03: a system-labelled row (label leading, field trailing); required-ness is in the footer.
            LabeledContent {
                TextField(text: textBinding(key), prompt: Text(LocalizedStringKey("club.host.placeholder." + key))) {
                    Text(LocalizedStringKey("club.gov.field." + key))
                }
                .keyboardType(["maxEventSize", "avgEventSize"].contains(key) ? .numberPad : .default)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityHint(required ? Text("club.host.requiredHint") : Text("club.host.optionalHint"))
                .accessibilityIdentifier("club.gov.input." + key)
            } label: {
                Text(LocalizedStringKey("club.gov.field." + key)).accessibilityHidden(true)
            }
        }
    }
    @ViewBuilder private func fieldRow(_ key: String) -> some View {
        if let choices = draft.choices(key) {
            Picker(LocalizedStringKey("club.gov.field." + key), selection: textBinding(key)) {
                ForEach(choices, id: \.self) { Text(LocalizedStringKey("club.gov.choice." + $0)).tag($0) }
            }.accessibilityIdentifier("club.gov.input." + key)
        } else {
            TextField(LocalizedStringKey("club.gov.field." + key), text: textBinding(key), axis: ["content", "reason", "remark"].contains(key) ? .vertical : .horizontal)
                .keyboardType(["maxEventSize", "avgEventSize", "actualHours"].contains(key) ? .numberPad : .default)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("club.gov.input." + key)
            // Mini inline "reason required" copy; display only (the command validation still blocks blank reasons).
            if key == "reason", dirty, let mode = Self.reasonMode(route.operation), !ClubGovernanceReportPort.reasonIsValid(draft.text[key] ?? "") {
                Text(LocalizedStringKey(ClubGovernanceReportPort.reasonRequiredKey(mode)), tableName: "ClubOpsGovernance")
                    .font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("club.gov.reasonRequired")
            }
        }
    }
    private static func reasonMode(_ operation: ClubGovernanceMutation) -> ClubGovernanceReportPort.ReasonMode? {
        switch operation {
        case .ban: return .ban
        case .transferOwner: return .transfer
        case .report: return .report
        case .appeal: return .appeal
        default: return nil
        }
    }
    private func flagRow(_ key: String) -> some View {
        Toggle(LocalizedStringKey("club.gov.field." + key), isOn: flagBinding(key)).accessibilityIdentifier("club.gov.input." + key)
    }
    private func textBinding(_ key: String) -> Binding<String> { Binding(get: { draft.text[key] ?? "" }, set: { draft.text[key] = $0; dirty = true; review = nil; coordinator.cancelReview() }) }
    private func flagBinding(_ key: String) -> Binding<Bool> { Binding(get: { draft.flags[key] ?? false }, set: { draft.flags[key] = $0; dirty = true; review = nil; coordinator.cancelReview() }) }
    /// Issuing a group code sends `{activityId}`. A topic-only link never reaches this submit.
    private var groupCodeCanIssue: Bool {
        route.operation != .issueGroupCode || (route.scope.activityID ?? 0) > 0
    }
    /// CLB-governance-03 / CLB-roles-04 (fix-r8-club): commands the MP sends without a fact-review step.
    private static let directOperations: Set<ClubGovernanceMutation> = [.ban, .unban, .transferOwner, .report, .appeal, .assignRole]
    /// 分配 names what is still missing (MP 先选择一位成员 / 先选择一个角色); other direct commands rely on their own validation.
    private var directMissingField: String? {
        guard route.operation == .assignRole else { return nil }
        if (draft.text["targetMemberId"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return "clubR8b.roles.pickMember" }
        if (draft.text["roleCode"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return "clubR8b.roles.pickRole" }
        if !roleAssignmentReady { return "clubR8b.roles.notReady" }
        return nil
    }
    /// One-tap submit for commands whose MP page has no review step (customer 保存, group code 出示).
    private func submitDirectly() async {
        guard groupCodeCanIssue else { return }
        await prepare()
        if let pending = review { await confirm(pending) }
    }
    /// CLB-group-code-03 (fix-r3-club-b): an expired code is re-issued in place with a fresh request id,
    /// so the original (expired) receipt is never replayed.
    private func reissueGroupCode() async {
        guard route.operation == .issueGroupCode, !busy, !locked else { return }
        groupCode = nil; receipt = nil; failure = nil; review = nil
        coordinator.cancelReview()
        draft = .init(operation: route.operation, scope: route.scope)
        await submitDirectly()
    }
    private func prepare() async {
        guard !Task.isCancelled, draft.operation == route.operation, draft.scope == route.scope,
              roleAssignmentReady && seriesScheduleReady && seriesLeadReady && hostMaterialsReady && notificationAudienceReady,
              !locked, review == nil, receipt == nil,
              let activity = presentation.begin(.prepare, in: presentationContext) else { return }
        let revision = generation, expected = identity; failure = nil
        defer { presentation.finish(activity) }
        do {
            if let validateTarget {
                try await validateTarget()
                guard presentation.owns(activity, in: presentationContext), !Task.isCancelled, revision == generation, expected == identity, expected == access.identity else { return }
            }
            let pending = try await coordinator.prepare(draft.command())
            guard presentation.owns(activity, in: presentationContext), !Task.isCancelled, revision == generation, expected == identity, expected == access.identity else { return }
            guard seriesScheduleReady else { coordinator.cancelReview(); throw ClubGovernanceFailure.invalidRequest }
            review = pending
        } catch { if presentation.owns(activity, in: presentationContext), !Task.isCancelled, revision == generation && expected == identity { failure = error as? ClubGovernanceFailure ?? .malformed } }
    }
    private func confirm(_ review: ClubGovernanceReview) async {
        // MC-33: a heavy command stops here once to show its consequences; the sheet's confirm comes back in.
        if ClubGovernanceConsequence(route.operation) != nil, consequenceAccepted != review.id {
            consequenceReview = review; return
        }
        guard !Task.isCancelled, self.review?.id == review.id, review.command.operation == route.operation,
              review.command.scope == route.scope, !locked, coordinator.canDispatch(review.command),
              let activity = presentation.begin(.confirm, in: presentationContext) else { return }
        let revision = generation, expected = identity; failure = nil
        defer { presentation.finish(activity) }
        let submittedRequestID = draft.requestID
        do {
            // A reviewed schedule may have crossed Shanghai midnight while left open.
            guard seriesScheduleReady else { coordinator.cancelReview(); throw ClubGovernanceFailure.invalidRequest }
            if let validateTarget {
                try await validateTarget()
                guard presentation.owns(activity, in: presentationContext), !Task.isCancelled, revision == generation, expected == identity, expected == access.identity else { return }
            }
            guard seriesScheduleReady else { coordinator.cancelReview(); throw ClubGovernanceFailure.invalidRequest }
            if let caseSubmissionReturn, !caseSubmissionReturn.begin(review) { throw ClubGovernanceFailure.staleReview }
            let returnsToRoster = route.operation == .correctAttendance && attendanceReturn?.begin(review) == true
            let returnsToRoles = [ClubGovernanceMutation.assignRole, .revokeRole].contains(route.operation) && roleManagementReturn?.begin(review) == true
            let returnsToTopicSettings = route.operation == .saveTopicSettings && topicSettingsReturn?.begin(review) == true
            let returnsToBans = route.operation == .unban && banRemovalReturn?.begin(review) == true
            if route.operation == .updateSeries, let seriesUpdateReturn {
                guard self.review?.id == review.id, seriesUpdateReturn.begin(review) else { throw ClubGovernanceFailure.staleReview }
            }
            if route.operation == .createSeries, let seriesCreationReturn {
                guard self.review?.id == review.id, seriesCreationReturn.begin(review) else { throw ClubGovernanceFailure.staleReview }
            }
            if route.operation == .cancelOccurrence, let occurrenceCancellationReturn {
                guard self.review?.id == review.id, occurrenceCancellationReturn.begin(review) else { throw ClubGovernanceFailure.staleReview }
            }
            guard presentation.owns(activity, in: presentationContext), !Task.isCancelled else { return }
            let value = try await coordinator.confirm(review)
            guard presentation.owns(activity, in: presentationContext), !Task.isCancelled, revision == generation, expected == identity, expected == access.identity else { return }
            receipt = value; self.review = nil; locked = true
            if route.operation == .endTopic {
                // CLB-r11-topic-detail-01 (MP topic-detail/index.js:1150-1176): failedSessions keeps the form open with
                // 「N 场没能取消：…」; PENDING asks to read the original request back; only DONE shows the result line.
                let summary = ClubTopicEndSummary.parse(value, sentEpoch: review.command.fields["cancellationEpoch"]?.int ?? -1)
                if let message = summary.errorText(chinese: AppLanguage.interfaceIsChinese(locale)) {
                    receipt = nil; locked = coordinator.isLocked(review.command, identity: review.identity)
                    failure = .unknown(message: message)
                }
            }
            if route.operation == .dissolve { profileDraftFlow?.clearAfterConfirmedDissolve() }
            if returnsToRoster { attendanceReturn?.acknowledged(review, value) }
            caseSubmissionReturn?.acknowledged(review)
            if returnsToRoles { roleManagementReturn?.acknowledged(review, value) }
            if returnsToTopicSettings { topicSettingsReturn?.acknowledged(review, value) }
            if returnsToBans { banRemovalReturn?.acknowledged(review, value) }
            if route.operation == .updateSeries, submittedRequestID == draft.requestID, !Task.isCancelled {
                seriesUpdateReturn?.acknowledged(review, value)
            }
            if route.operation == .createSeries, submittedRequestID == draft.requestID, !Task.isCancelled {
                seriesCreationReturn?.acknowledged(review, value)
            }
            if route.operation == .cancelOccurrence, submittedRequestID == draft.requestID, !Task.isCancelled {
                occurrenceCancellationReturn?.acknowledged(review, value)
            }
            if route.operation == .issueGroupCode {
                // CLB-group-code-06 (MP group-code/index.js:44-56, 93-135): the issue body is `{activityId}` only and the
                // MP link carries no clubId, so the receipt is checked by activityId (and by clubId only when known).
                guard let activityID = review.command.scope.activityID,
                      scenePhase == .active, !Task.isCancelled else { throw ClubGovernanceFailure.staleReview }
                groupCode = try ClubGovernanceGroupCode(receipt: value, receivedAt: Date(),
                    expectedClubID: review.command.scope.clubID, expectedActivityID: activityID)
            }
        } catch {
            if presentation.owns(activity, in: presentationContext), !Task.isCancelled, revision == generation && expected == identity {
                // Invalid original QR cannot render an acknowledged success card.
                // This clears ephemeral presentation only, never the durable original request.
                if route.operation == .issueGroupCode { groupCode = nil; receipt = nil }
                failure = error as? ClubGovernanceFailure ?? .unknown(message: nil)
                self.review = nil; locked = coordinator.isLocked(review.command, identity: review.identity)
                if route.operation == .updateSeries, submittedRequestID == draft.requestID, !locked, let definite = failure {
                    seriesUpdateReturn?.conflicted(review, definite)
                }
            }
        }
    }
}
