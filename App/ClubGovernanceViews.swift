import SwiftUI

/// P044 keyword-only scheduling. The view still owns authorization and response fences.
@MainActor final class ClubCustomerKeywordDebounce {
    static let delayNanoseconds: UInt64 = 300_000_000
    private var pending: Task<Void, Never>?
    private var revision: UInt64 = 0
    private let sleep: @MainActor @Sendable () async throws -> Void
    nonisolated init(sleep: @escaping @MainActor @Sendable () async throws -> Void = {
        try await Task.sleep(nanoseconds: ClubCustomerKeywordDebounce.delayNanoseconds)
    }) { self.sleep = sleep }
    func cancel() {
        revision &+= 1
        pending?.cancel()
        pending = nil
    }
    @discardableResult func schedule(_ action: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        cancel()
        let expected = revision
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do { try await self.sleep() } catch { return }
            guard !Task.isCancelled, self.revision == expected else { return }
            // Release the handle before load() cancels any still-pending timer.
            self.pending = nil
            await action()
        }
        pending = task
        return task
    }
}

/// The customers keyword is the system bar search field (CLB-customers-07); other reads carry no search.
private struct ClubCustomerKeywordSearch: ViewModifier {
    let enabled: Bool
    let text: Binding<String>
    let submit: () -> Void
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content
                .searchable(text: text, prompt: Text("club.gov.keyword"))
                .onSubmit(of: .search) { submit() }
        } else {
            content
        }
    }
}

struct ClubCustomerFilters: Equatable {
    var filter = "all"
    var keyword = ""
    var isFiltered: Bool { filter != "all" || !keyword.isEmpty }

    @discardableResult mutating func clear() -> Bool {
        guard isFiltered else { return false }
        filter = "all"
        keyword = ""
        return true
    }
}

/// Mount independently of legacy isOwner/viewerIsAdmin. access/me decides each row.
struct ClubGovernanceEntryButton: View {
    let clubID: Int
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    var enrollmentProfile: ClubEnrollmentProfileContext? = nil
    var ownerRefund: ClubOwnerRefundCoordinator? = nil
    var opsTimeFactory: ((Int) -> ClubOpsTimeCoordinator?)? = nil
    var customerTopics = ClubCustomerTopicContext()
    var storyTemplates = ClubStoryTemplateContext()
    var terminalSessions = ClubTerminalSessionContext()
    var ownerFunds = ClubOwnerFundsContext()
    /// CLB-detail-23: members without the 管理 tab see 我的治理记录, never a second 管理.
    var titleKey: LocalizedStringKey = "club.gov.workspace"
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            Label(titleKey, systemImage: "person.3.sequence.fill")
        }
            .accessibilityIdentifier("club.gov.open")
            .cySheet(isPresented: $presented) {
                NavigationStack { ClubGovernanceWorkspaceView(clubID: clubID, identity: identity, access: access, coordinator: coordinator) }
                    .environment(\.clubEnrollmentProfile, enrollmentProfile)
                    .environment(\.clubOwnerRefundCoordinator, ownerRefund)
                    .environment(\.clubOpsTimeFactory, opsTimeFactory)
                    .environment(\.clubCustomerTopics, customerTopics)
                    .environment(\.clubStoryTemplates, storyTemplates)
                    .environment(\.clubTerminalSessions, terminalSessions)
                    .environment(\.clubOwnerFunds, ownerFunds)
                    .cyDomainSheet(detents: [.full]) // CLB-topic-detail-13 / CLB-governance-19: dense workspace pages open large
            }
    }
}
struct ClubGovernanceHomeEntries: View {
    var feedContext = ClubGovernanceFeedContext()
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    var body: some View {
        NavigationLink { ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: identity, access: access, coordinator: coordinator) } label: {
            Label("club.gov.hostStatus", systemImage: "person.badge.plus")
        }
            .accessibilityIdentifier("club.gov.openHost")
        NavigationLink { ClubGovernanceReadView(operation: .feed, scope: .init(), identity: identity, access: access, coordinator: coordinator)
                .environment(\.clubGovernanceFeed, feedContext) } label: {
            Label("club.gov.feed", systemImage: "text.bubble")
        }
            .accessibilityIdentifier("club.gov.openFeed")
    }
}
struct ClubGovernanceWorkspaceView: View {
    let clubID: Int
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ClubGovernanceReadView(operation: .access, scope: .init(clubID: clubID), identity: identity, access: access, coordinator: coordinator)
            .accessibilityIdentifier("club.gov.workspace.root")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("club.gov.close") { dismiss() } } }
    }
}

struct ClubGovernanceFormRoute: Identifiable {
    let id = UUID()
    let operation: ClubGovernanceMutation
    let scope: ClubGovernanceScope
    var seed: [String: ClubGovernanceValue] = [:]
}

/// A leaderboard row may open only the existing public profile reader. This
/// ephemeral route never substitutes CRM data or grants profile-read permission.
struct ClubLeaderboardMemberRoute: Hashable, Identifiable {
    let id = UUID()
    let memberID: Int
    let context: ClubGovernanceReadContext
    let snapshotGeneration: UInt64
    private let source: ClubGovernanceSnapshot
    private let profileIdentity: SocialAccountIdentity
    private let profileRevision: UInt64
    private let profileReaderIdentity: ObjectIdentifier
    private let squareReaderIdentity: ObjectIdentifier
    private let squareScope: UUID

    @MainActor init?(row: ClubGovernanceValue, snapshot: ClubGovernanceSnapshot,
          context: ClubGovernanceReadContext, snapshotGeneration: UInt64,
          profile: ClubEnrollmentProfileContext) {
        guard context.operation == .leaderboard, context.accepts(snapshot),
              let viewer = context.identity, viewer.isSignedIn,
              let clubID = context.scope.clubID, clubID > 0,
              snapshot.permissions?.allows(ClubGovernanceRead.leaderboard.permission, scope: context.scope) == true,
              profile.reader.isConfigured,
              profile.reader.identity.accountID == viewer.accountID,
              profile.reader.identity.epoch == viewer.epoch,
              let memberID = row["memberId"].int, (1...9_007_199_254_740_991).contains(memberID),
              row["clubId"] == .null || row["clubId"].int == clubID,
              let rows = snapshot.value.array, rows.contains(row),
              rows.filter({ $0["memberId"].int == memberID }).count == 1 else { return nil }
        self.memberID = memberID; self.context = context; self.snapshotGeneration = snapshotGeneration
        source = snapshot; profileIdentity = profile.reader.identity
        profileRevision = profile.reader.presentationRevision
        profileReaderIdentity = ObjectIdentifier(profile.reader)
        squareReaderIdentity = ObjectIdentifier(profile.squareReader); squareScope = profile.squareReader.scope
    }
    @MainActor func isCurrent(snapshot: ClubGovernanceSnapshot?, context: ClubGovernanceReadContext,
                   snapshotGeneration: UInt64, profile: ClubEnrollmentProfileContext) -> Bool {
        self.context == context && self.snapshotGeneration == snapshotGeneration && snapshot == source &&
        profile.reader.isConfigured && profile.reader.identity == profileIdentity &&
        profile.reader.presentationRevision == profileRevision &&
        ObjectIdentifier(profile.reader) == profileReaderIdentity &&
        ObjectIdentifier(profile.squareReader) == squareReaderIdentity && profile.squareReader.scope == squareScope
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ClubGovernanceReadView: View {
    @Environment(\.clubEnrollmentProfile) private var leaderboardProfile
    @Environment(\.clubOpsTimeFactory) private var opsTimeFactory
    @Environment(\.clubCustomerTopics) private var customerTopics
    @Environment(\.clubGovernanceFeed) private var feedContext
    @Environment(\.clubStoryTemplates) private var storyTemplates
    @Environment(\.clubTerminalSessions) private var terminalSessions
    @Environment(\.clubOwnerFunds) private var ownerFunds
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismissPage
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    let operation: ClubGovernanceRead
    let scope: ClubGovernanceScope
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    var expectedCreatedSeries: ClubCreatedSeriesReceipt? = nil
    /// CLB-topic-story-01: `pages/club/topic-story/index` opens the story directly. The topic overview stays the
    /// host that owns the read; once it has loaded, the story is pushed one time.
    var opensStoryOnLoad = false
    @State private var storyAutoOpen = false
    @State private var storyAutoOpened = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var customerPager = ClubOpsCustomerPager()
    @StateObject private var attendanceReturn = ClubAttendanceCorrectionReturn()
    @StateObject private var attendanceReads = ClubAttendanceRosterRead()
    @StateObject private var roleManagementReturn = ClubRoleManagementReturn()
    @StateObject private var roleReads = ClubRoleListRead()
    @StateObject private var topicSettingsReturn = ClubTopicSettingsReturn()
    @StateObject private var topicSettingsReads = ClubTopicSettingsRead()
    @StateObject private var banRemovalReturn = ClubBanRemovalReturn()
    @StateObject private var banReads = ClubBanListRead()
    @StateObject private var terminalPresentation = ClubTerminalSessionPresentation()
    @StateObject private var seriesUpdateReturn = ClubSeriesUpdateReturn()
    @StateObject private var seriesCreationReturn = ClubSeriesCreationReturn()
    @StateObject private var occurrenceCancellationReturn = ClubOccurrenceCancellationReturn()
    @State private var seriesHostVisible = false
    @StateObject private var seriesOccurrences = ClubSeriesOccurrenceHost()
    @StateObject private var seriesTopicNames = ClubOpsEventTopicNameReads()
    @StateObject private var settlementReturn = ClubSettlementReturnOwner()
    @StateObject private var ownerFundsParent = ClubOwnerFundsParent()
    @StateObject private var caseSubmissionReturn = ClubCaseSubmissionReturn()
    @State private var caseHostVisible = false
    @State private var snapshot: ClubGovernanceSnapshot?
    @State private var snapshotContext: ClubGovernanceReadContext?
    @State private var snapshotGeneration: UInt64 = 0
    @State private var customerTopic: ClubCustomerHistoryTopicRoute?
    @State private var leaderboardMember: ClubLeaderboardMemberRoute?
    @State private var feedClub: ClubFeedClubRoute?
    /// CLB-topic-detail-07 (MP CU-C-79, wxml:684-700): 去选一场 opens a 选择场次 sheet; the picked session opens its event ops.
    @State private var sessionPickerVisible = false
    @State private var pickedSession: ClubGovernanceScope?
    /// CLB-topic-detail-04: /api/club/crm/topic-manage-stats read beside the topic overview (MP loadManageStats).
    @State private var topicStats: ClubGovernanceValue?
    /// CLB-G12: the reviewed MP page the topic 更多 menu opens.
    @State private var topicMoreRoute: ClubTopicMoreRoute?
    /// CLB-topic-detail-05: the half sheet a topic round action opened.
    @State private var topicQuickSheet: ClubTopicQuickSheet?
    /// CLB-G13b (MP topic-detail wxml:340-345 `cy-club-director-end-confirm`): 结束这场活动？
    @State private var directorEndConfirm = false
    /// CLB-G13b: 更多 → 结束活动 opens the confirm once the half sheet has gone.
    @State private var directorEndAfterSheet = false
    /// CLB-r9-topic-detail-02: a 更多 row's route, pushed once the half sheet has gone.
    @State private var topicMoreAfterSheet: ClubTopicMoreRoute?
    /// CLB-topic-detail-10: 定向广播 opens the director page, which owns the broadcast composer.
    @State private var opensDirectorBroadcast = false
    @Environment(\.clubTopicDirectorHost) private var directorHost
    /// CLB-r7-C-03 (MP roles/index.js:266-272): a failed reread after a role action keeps the list and toasts.
    @State private var roleRereadToast: LocalizedStringKey?
    @State private var feedMediaScope = UUID()
    private var readContext: ClubGovernanceReadContext {
        .init(operation: operation, scope: scope, identity: identity, viewerRevision: operation == .feed ? feedContext.viewerRevision : (operation == .topicOverview ? storyTemplates.viewerRevision : max(customerTopics.viewerRevision, storyTemplates.viewerRevision)),
              authorizationGeneration: access.authorizationGeneration,
              readerIdentity: operation == .feed ? feedContext.readerIdentity : (operation == .topicOverview ? storyTemplates.readerIdentity : nil), accessIdentity: ObjectIdentifier(access))
    }
    @State private var failure: ClubGovernanceFailure?
    @State private var loading = false
    @State private var generation: UInt64 = 0
    @State private var filter = "all"
    @State private var topicCustomerFilter: ClubTopicCustomerFilter = .all
    @State private var customerFilters = ClubCustomerFilters()
    @State private var snapshotCustomerFilters: ClubCustomerFilters?
    @State private var customerKeywordDebounce = ClubCustomerKeywordDebounce()
    @State private var sort = "composite"
    @State private var page = 1
    @State private var editor: ClubGovernanceFormRoute?
    private var title: LocalizedStringKey { LocalizedStringKey("club.gov." + operation.rawValue) }
    /// The failure's reason line: the server sentence when it sent one, else the generic key.
    private func failureReason(_ failure: ClubGovernanceFailure) -> Text {
        if let message = failure.message { return Text(verbatim: message) }
        return Text(LocalizedStringKey(failure.localizationKey))
    }
    // Split into stages so the type checker handles the long modifier chain;
    // the modifiers apply in exactly the same order as one chain.

    private func checkinRowsValue(_ value: ClubGovernanceValue, _ page: ClubCheckinDetailPage) -> ClubGovernanceValue {
        guard case .ready(let facts) = page.phase, case .object(var fields) = value else { return value }
        fields["registrationId"] = .string(facts.registrationIDText)
        fields["paidAmountText"] = .string(facts.paidAmountText)
        return .object(fields)
    }

    var body: some View {
        bodyMain
            .navigationDestination(isPresented: $storyAutoOpen) { storyDestination }
            .onChange(of: snapshot != nil && snapshotContext == readContext && !loading, initial: true) { _, ready in
                guard ready, opensStoryOnLoad, operation == .topicOverview, !storyAutoOpened, scenePhase == .active else { return }
                storyAutoOpened = true
                storyAutoOpen = true
            }
    }
    private var storyDestination: some View {
        ClubGovernanceStoryView(snapshot: $snapshot, snapshotContext: $snapshotContext, snapshotGeneration: $snapshotGeneration,
                                loading: $loading, failure: $failure, context: readContext, identity: identity, access: access,
                                coordinator: coordinator, reload: { await load() })
    }
    private var bodyMain: some View {
        bodyReturnOwners
        .task(id: readContext) { await synchronizeReadContext() }
        .background {
            if let item = caseSubmissionReturn.item {
                ClubCaseSubmissionPresentationOwner(item: item, owner: caseSubmissionReturn,
                    source: { caseSubmissionSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishCaseSubmissionReturn).id(item.id)
            }
        }
        .onAppear { caseHostVisible = true; finishCaseSubmissionReturn() }
        .onChange(of: caseSubmissionSource) { _, source in
            caseSubmissionReturn.invalidateUnlessCurrent(source: source, active: scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            guard operation == .cases else { return }
            if phase != .active { caseSubmissionReturn.retire(); generation &+= 1 }
            else { finishCaseSubmissionReturn() }
        }
        .task(id: CaseReadTrigger(context: readContext, visible: caseHostVisible, active: scenePhase == .active)) { await refreshVisibleCases() }
        .onDisappear {
            if operation == .customers {
                customerKeywordDebounce.cancel()
                generation &+= 1
            }
        }
        .onDisappear { leaveReadHost() }
        .refreshable { await load() }
    }
    private var bodyReturnOwnersStage1: some View {
        bodyNavigation
        .background {
            if let item = terminalPresentation.presented {
                ClubTerminalSessionOwner(item: item, presentation: terminalPresentation,
                    access: access, coordinator: coordinator).id(item.id)
            }
        }
        .background {
            if operation == .roster, let attachment = attendanceReturn.attachment {
                ClubAttendanceReturnLifetime {
                    attendanceReturn.depart(attachment, reads: attendanceReads) { generation &+= 1; loading = false }
                }.id(attachment)
            }
            if let item = attendanceReturn.item {
                ClubAttendanceCorrectionPresentationOwner(item: item, owner: attendanceReturn,
                    source: { attendanceSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishAttendanceReturn).id(item.id)
            }
        }
        .onAppear {
            if operation == .roster {
                attendanceReturn.appear()
                finishAttendanceReturn()
                Task { await loadRosterIfNeeded() }
            }
        }
        .onChange(of: attendanceSource) { _, source in
            attendanceReturn.invalidateUnlessCurrent(source: source, active: scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            if operation == .roster {
                if phase != .active { attendanceReturn.retire(); attendanceReads.retire(); generation &+= 1; loading = false }
                else { Task { await loadRosterIfNeeded() } }
            }
        }
        .background {
            if operation == .roles, let attachment = roleManagementReturn.attachment {
                ClubRoleReturnLifetime {
                    roleManagementReturn.depart(attachment, reads: roleReads) { generation &+= 1; loading = false }
                }.id(attachment)
            }
            if let item = roleManagementReturn.item {
                ClubRoleManagementPresentationOwner(item: item, owner: roleManagementReturn,
                    source: { roleManagementSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishRoleManagementReturn).id(item.id)
            }
        }
        .onAppear {
            if operation == .roles {
                roleManagementReturn.appear()
                finishRoleManagementReturn()
                Task { await loadRolesIfNeeded() }
            }
        }
        .onChange(of: roleManagementSource) { _, source in
            roleManagementReturn.invalidateUnlessCurrent(source: source, active: scenePhase == .active)
        }
        .clubIslandStatus(message: $roleRereadToast, tone: .warning, surface: "governance-roles")
        .onChange(of: scenePhase) { _, phase in
            if operation == .roles {
                if phase != .active { roleManagementReturn.retire(); roleReads.retire(); generation &+= 1; loading = false }
                else { Task { await loadRolesIfNeeded() } }
            }
        }
        .background {
            if operation == .topicSettings, let attachment = topicSettingsReturn.attachment {
                ClubTopicSettingsReturnLifetime {
                    topicSettingsReturn.depart(attachment, reads: topicSettingsReads) { generation &+= 1; loading = false }
                }.id(attachment)
            }
            if let item = topicSettingsReturn.item {
                ClubTopicSettingsPresentationOwner(item: item, owner: topicSettingsReturn,
                    source: { topicSettingsSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishTopicSettingsReturn).id(item.id)
            }
        }
        .onAppear {
            if operation == .topicSettings {
                topicSettingsReturn.appear()
                finishTopicSettingsReturn()
                Task { await loadTopicSettingsIfNeeded() }
            }
        }
        .onChange(of: topicSettingsSource) { _, source in
            topicSettingsReturn.invalidateUnlessCurrent(source: source, active: scenePhase == .active)
        }
    }
    private var bodyReturnOwnersStage2: some View {
        bodyReturnOwnersStage1
        .onChange(of: scenePhase) { _, phase in
            if operation == .topicSettings {
                if phase != .active { topicSettingsReturn.retire(); topicSettingsReads.retire(); generation &+= 1; loading = false }
                else { Task { await loadTopicSettingsIfNeeded() } }
            }
        }
        .background {
            if operation == .series, let attachment = seriesOccurrences.attachment {
                ClubSeriesOccurrenceLifetime {
                    if seriesOccurrences.depart(attachment) { generation &+= 1; loading = false }
                }.id(attachment)
            }
            if let item = seriesOccurrences.selected {
                ClubSeriesOccurrencePresentationOwner(item: item, host: seriesOccurrences,
                    access: access, coordinator: coordinator, current: { currentOccurrenceSource },
                    active: { scenePhase == .active }, returned: {
                        Task { await loadSeriesOccurrencesIfNeeded() }
                    }).id(item.id)
            }
        }
        .onAppear {
            if operation == .series { seriesOccurrences.appear(); Task { await loadSeriesOccurrencesIfNeeded() } }
        }
        .onChange(of: currentOccurrenceSource) { _, source in seriesOccurrences.invalidateUnlessCurrent(source) }
        .onChange(of: scenePhase) { _, phase in
            if operation == .series {
                if phase != .active { seriesOccurrences.background() }
                else { Task { await loadSeriesOccurrencesIfNeeded() } }
            }
        }
        .task(id: seriesOccurrences.source) { await loadSeriesOccurrencesIfNeeded() }
        .background {
            if operation == .bans, let attachment = banRemovalReturn.attachment {
                ClubBanRemovalLifetime {
                    banRemovalReturn.depart(attachment, reads: banReads) { generation &+= 1; loading = false }
                }.id(attachment)
            }
            if let item = banRemovalReturn.item {
                ClubBanRemovalPresentationOwner(item: item, owner: banRemovalReturn,
                    source: { banRemovalSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishBanRemovalReturn).id(item.id)
            }
        }
        .onAppear {
            if operation == .bans {
                banRemovalReturn.appear()
                finishBanRemovalReturn()
                Task { await loadBansIfNeeded() }
            }
        }
        .onChange(of: banRemovalSource) { _, source in
            banRemovalReturn.invalidateUnlessCurrent(source: source, active: scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            if operation == .bans {
                if phase != .active { banRemovalReturn.retire(); banReads.retire(); generation &+= 1; loading = false }
                else { Task { await loadBansIfNeeded() } }
            }
        }
        .background {
            if operation == .settlement, let attachment = settlementReturn.attachment {
                ClubSettlementParentLifetime {
                    if settlementReturn.depart(attachment) { generation &+= 1; loading = false }
                }.id(attachment)
            }
            if let item = settlementReturn.item {
                ClubSettlementPresentationOwner(item: item, owner: settlementReturn, source: { settlementSource },
                    active: { scenePhase == .active }, access: access,
                    returned: { Task { await loadSettlementIfNeeded() } }).id(item.id)
            }
        }
        .onAppear {
            if operation == .settlement {
                activateSettlementParent()
                Task { await loadSettlementIfNeeded() }
            }
        }
    }
    private var bodyReturnOwnersStage3: some View {
        bodyReturnOwnersStage2
        .onChange(of: settlementSource) { _, source in settlementReturn.invalidate(source: source, active: scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in
            if operation == .settlement {
                if phase != .active { settlementReturn.background(); generation &+= 1; loading = false }
                else { Task { await loadSettlementIfNeeded() } }
            }
        }
        .task(id: settlementReadKey) {
            guard operation == .settlement else { return }
            if settlementReturn.synchronize(readContext, namespace: access.storageNamespace) { invalidateRead(); loading = false }
            await loadSettlementIfNeeded()
        }
    }
    // Further split for the type checker; modifier order is unchanged.
    private var bodyReturnOwnersStage4: some View {
        bodyReturnOwnersStage3
        .background {
            if operation == .settlement, let attachment = ownerFundsParent.attachment {
                ClubSettlementParentLifetime { ownerFundsParent.depart(attachment) }.id(attachment)
            }
            if let item = ownerFundsParent.contact {
                ClubOwnerFundsContactOwner(item: item, owner: ownerFundsParent, context: ownerFunds,
                    current: { ownerFundsSource }, active: { scenePhase == .active },
                    returned: { Task { await loadOwnerFundsIfNeeded() } }).id(item.id)
            }
        }
        .onAppear {
            if operation == .settlement { ownerFundsParent.appear(); Task { await loadOwnerFundsIfNeeded() } }
        }
        .task(id: ownerFundsSource) {
            ownerFundsParent.synchronize(ownerFundsSource)
            await loadOwnerFundsIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if operation == .settlement {
                if phase != .active { ownerFundsParent.background() }
                else { Task { await loadOwnerFundsIfNeeded() } }
            }
        }
    }
    private var bodyReturnOwners: some View {
        bodyReturnOwnersStage4
        .onAppear { terminalPresentation.bind(terminalSource) }
        .onChange(of: terminalSource, initial: true) { _, source in terminalPresentation.bind(source) }
        // A covering child owns dismissal; recycling content rows cannot retire it.
        .onDisappear { if terminalPresentation.presented == nil { terminalPresentation.leave() } }
        // One owner clears the previous account and starts its replacement read.
        // Separate onChange invalidations can run after a fast forbidden response
        // and erase its error. Context checks still hide old PII synchronously.
        .task(id: ClubOccurrenceCancellationReturn.ReadTrigger(context: readContext,
                    visible: seriesHostVisible, active: scenePhase == .active)) { await refreshOccurrenceStatus() }
    }
    // Kept outside the body's modifier chain so the view type-checks in bounded time.
    @MainActor private func synchronizeReadContext() async {
        if operation == .occurrenceStatus { return }
        guard operation != .cases, operation != .settlement else { return }
        if operation == .seriesDetail, snapshotContext == readContext, snapshot != nil, generation == snapshotGeneration { return }
        if operation == .eventTopics, seriesCreationReturn.holdsSource,
           seriesCreationReturn.isBound(context: readContext, access: access) { return }
        if operation == .series {
            if snapshotContext != readContext || snapshotGeneration != generation {
                seriesOccurrences.retire(); invalidateRead(); loading = false; await load()
            }
            await loadSeriesOccurrencesIfNeeded()
        } else if operation == .roster {
            if attendanceReads.synchronize(readContext) {
                attendanceReturn.retire(); invalidateRead(); loading = false
            }
            attendanceReturn.invalidateUnlessCurrent(source: attendanceSource, active: scenePhase == .active)
            if let ticket = attendanceReturn.readTicket, ticket.source.context != readContext { attendanceReturn.retire() }
            await loadRosterIfNeeded()
        } else if operation == .roles {
            if roleReads.synchronize(readContext) {
                roleManagementReturn.retire(); invalidateRead(); loading = false
            }
            roleManagementReturn.invalidateUnlessCurrent(source: roleManagementSource, active: scenePhase == .active)
            if let ticket = roleManagementReturn.readTicket, ticket.source.context != readContext { roleManagementReturn.retire() }
            await loadRolesIfNeeded()
        } else if operation == .topicSettings {
            if topicSettingsReads.synchronize(readContext) {
                topicSettingsReturn.retire(); invalidateRead(); loading = false
            }
            topicSettingsReturn.invalidateUnlessCurrent(source: topicSettingsSource, active: scenePhase == .active)
            if let ticket = topicSettingsReturn.readTicket, ticket.source.context != readContext { topicSettingsReturn.retire() }
            await loadTopicSettingsIfNeeded()
        } else if operation == .bans {
            if banReads.synchronize(readContext) {
                banRemovalReturn.retire(); invalidateRead(); loading = false
            }
            banRemovalReturn.invalidateUnlessCurrent(source: banRemovalSource, active: scenePhase == .active)
            if let ticket = banRemovalReturn.readTicket, ticket.source.context != readContext { banRemovalReturn.retire() }
            await loadBansIfNeeded()
        } else { invalidateRead(); await load() }
    }
    // Kept outside the body's modifier chain so the view type-checks in bounded time.
    @MainActor private func refreshVisibleCases() async {
        guard operation == .cases, caseHostVisible, scenePhase == .active else { return }
        if caseSubmissionReturn.item != nil || caseSubmissionReturn.readID != nil { return }
        if snapshotContext == readContext, generation == snapshotGeneration { return }
        invalidateRead(); await load()
    }
    // Kept outside the body's modifier chain so the view type-checks in bounded time.
    @MainActor private func leaveReadHost() {
        caseHostVisible = false
        if operation == .settlement {
            settlementReturn.hide()
            ownerFundsParent.hide()
            if !settlementReturn.retainsChild, let attachment = settlementReturn.attachment {
                if !ownerFundsParent.retainsContact {
                    if settlementReturn.depart(attachment) { generation &+= 1; loading = false }
                }
            }
        } else if operation == .series {
            seriesOccurrences.hide()
            if !seriesOccurrences.retainsDestination { seriesOccurrences.retire(); generation &+= 1; loading = false }
        } else if operation == .roster {
            attendanceReturn.hide()
            if !attendanceReturn.retainsReturn { attendanceReads.retire(); generation &+= 1; loading = false }
        } else if operation == .roles {
            roleManagementReturn.hide()
            if !roleManagementReturn.retainsReturn { roleReads.retire(); generation &+= 1; loading = false }
        } else if operation == .topicSettings {
            topicSettingsReturn.hide()
            if !topicSettingsReturn.retainsReturn { topicSettingsReads.retire(); generation &+= 1; loading = false }
        } else if operation == .bans {
            banRemovalReturn.hide()
            if !banRemovalReturn.retainsReturn { banReads.retire(); generation &+= 1; loading = false }
        } else if operation != .cases || caseSubmissionReturn.item == nil {
            if operation == .cases { caseSubmissionReturn.retire() }
            if operation != .occurrenceStatus || occurrenceCancellationReturn.item == nil {
            if operation != .eventTopics || !seriesCreationReturn.holdsSource {
                if operation != .seriesDetail || seriesUpdateReturn.item == nil { generation &+= 1 }
            }
            }
        }
    }
    // Kept outside the body's modifier chain so the view type-checks in bounded time.
    @MainActor private func refreshOccurrenceStatus() async {
        guard operation == .occurrenceStatus, seriesHostVisible, scenePhase == .active else { return }
        if let item = occurrenceCancellationReturn.item,
           item.source.live(context: readContext, access: access) { return }
        if snapshotContext == readContext, snapshot != nil, generation == snapshotGeneration { return }
        if let readback = occurrenceCancellationReturn.readback,
           readback.source.live(context: readContext, access: access) {
            await load()
        } else { invalidateRead(); await load() }
    }
    private var bodyNavigation: some View {
        List {
            // X1 / CLB-governance-13 (parity r2): the page-type title is the inline bar title, not a hero in the content.
            if loading, operation == .nodeAnswer {
                // CLB-topic-story-03 (MP topic-story wxml:115-142): the answer sheet says 正在取答案….
                ProgressView { Text("club.story.answer.loading") }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("club.gov.loading")
            } else if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("club.loading"))
                    .accessibilityIdentifier("club.gov.loading")
            }
            if operation == .occurrenceStatus, let readback = occurrenceCancellationReturn.readback,
               readback.source.live(context: readContext, access: access) {
                Section {
                    if !occurrenceCancellationReturn.confirmed {
                        Text("club.gov.unknown").accessibilityIdentifier("club.cancel.readback.unconfirmed")
                    }
                    ClubOpsEventCancellationReceipt(receipt: readback.receipt, confirmed: occurrenceCancellationReturn.confirmed,
                                                    reread: { Task { await load() } }).disabled(loading)
                    ClubGovernanceFactRows(value: readback.receipt, fields: ["refundStatus"])
                }
            }
            // X3 (parity r2): one failure block per read. Page copy when the page has it, else the page's denial note,
            // else the generic reason; the reason line keeps the `club.gov.error` id the UI tests read.
            if operation == .hostStatus, failure == .signedOut {
                // CLB-apply-08 (MP apply wxml:27-28): the guest state is 登录后申请成为主理人 + 登录.
                ContentUnavailableView {
                    Label { Text("club.host.signIn.title").accessibilityIdentifier("club.host.signIn") } icon: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                } actions: {
                    if rootTabSwitch.isAvailable {
                        Button { dismissPage(); rootTabSwitch(.mine) } label: { Text("club.host.signIn.action") }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("club.host.signIn.action")
                    }
                }
            } else if operation == .nodeAnswer, let failure, failure != .forbidden, failure != .signedOut {
                // CLB-topic-story-03: 答案没取到 + 重试, with the server reason when it sent one.
                ContentUnavailableView {
                    Label { Text("club.story.answer.failed").accessibilityIdentifier("club.story.answer.failed") } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    if let message = failure.message {
                        Text(verbatim: message).accessibilityIdentifier("club.story.answer.reason")
                    }
                } actions: {
                    if !loading {
                        Button("action.retry") { Task { await load() } }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("club.gov.refresh")
                    }
                }
            } else if case .checkin = operation, let failure, failure != .signedOut {
                // Round 4 (CLB-checkin-detail-03): a failed read clears the snapshot, so the MP full-page states
                // (核销记录不可见 / the server sentence + 返回 / 核销凭证加载失败 + 重新加载) are drawn here, not the generic block.
                ClubCheckinRailView(rail: .init(railStep: .null, statusCode: .null),
                                    stateKind: ClubCheckinRail.stateKind(for: failure) ?? .error,
                                    onReload: loading ? nil : { Task { await load() } }, reason: failure.message)
            } else if let failure, let copy = ClubOpsFailureCopy(operation: operation, failure: failure) {
                ClubOpsFailureSection(copy: copy, reason: failureReason(failure)) { Task { await load() } }
            } else if let failure, let copy = ClubOpsPageFailureCopy(operation: operation, failure: failure) {
                ClubOpsPageFailureSection(copy: copy, reason: failureReason(failure)) { Task { await load() } }.disabled(loading)
            } else if let failure, failure == .forbidden, ClubOpsGovernanceDeniedNote.covers(operation) {
                ClubOpsGovernanceDeniedNote(operation: operation, cases: scope.clubID == nil ? nil : AnyView(link(.cases)))
            } else if let failure {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(failure.localizationKey)).font(.headline).accessibilityIdentifier("club.gov.error")
                        if let message = failure.message {
                            Text(verbatim: message).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    // X2: pull-to-refresh already reloads; a button is offered only to retry a failed read.
                    if !loading, failure != .forbidden {
                        Button("action.retry") { Task { await load() } }
                            .accessibilityIdentifier("club.gov.refresh")
                    }
                }
                if failure == .forbidden { ClubOpsGovernanceDeniedNote(operation: operation, cases: scope.clubID == nil ? nil : AnyView(link(.cases))) }
            }
            if operation == .customers {
                Section {
                    // Mini-program club/customers: filter chips, then search (typing already re-reads).
                    // CLB-customers-07: the MP chip row is the system segmented control; the keyword is the bar search field.
                    Picker("club.gov.filter", selection: customerFilterBinding) {
                        ForEach(["all", "repeat", "new", "remark"], id: \.self) { value in
                            Text(LocalizedStringKey("club.gov.filter." + value))
                                .tag(value)
                                .accessibilityIdentifier("club.gov.customers.filter." + value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            if operation == .topicCustomers {
                Section {
                    Picker("club.gov.filter", selection: $topicCustomerFilter) {
                        ForEach(ClubTopicCustomerFilter.allCases, id: \.rawValue) { item in
                            Text(LocalizedStringKey(item.localizationKey)).tag(item)
                        }
                    }.accessibilityIdentifier("club.gov.topicCustomers.filter")
                        .onChange(of: topicCustomerFilter) { _, _ in Task { await load() } }
                    Text("club.gov.topicCustomers.countScope").font(.footnote).foregroundStyle(.secondary)
                }
                if let clubID = scope.clubID, let topicID = scope.topicID {
                    ClubParticipationTrendSection(clubID: clubID, topicID: topicID, identity: identity, viewerRevision: readContext.viewerRevision, access: access)
                }
            }
            if operation == .leaderboard {
                Picker("club.gov.sort", selection: $sort) { ForEach(["composite", "mileage", "pace", "duration"], id: \.self) { Text(LocalizedStringKey("club.gov.sort." + $0)).tag($0) } }
                    .onChange(of: sort) { _, _ in Task { await load() } }
            }
            if let snapshot, snapshotContext == readContext, identity == access.identity { content(snapshot) }
            if operation == .posts, snapshot != nil {
                Section {
                    HStack {
                        Button("club.gov.previous") { page -= 1; Task { await load() } }
                            .buttonStyle(.borderless)
                            .disabled(page <= 1 || loading)
                            .accessibilityIdentifier("club.gov.previous")
                        Spacer()
                        Text(page, format: .number).monospacedDigit()
                        Spacer()
                        Button("club.gov.next") { page += 1; Task { await load() } }
                            .buttonStyle(.borderless)
                            .disabled(loading || (snapshot?.value.array ?? snapshot?.value["rows"].array ?? []).count < 20)
                            .accessibilityIdentifier("club.gov.next")
                    }
                }
            }
        }
        .modifier(ClubCustomerKeywordSearch(enabled: operation == .customers, text: customerKeywordBinding,
                                            submit: { loadCustomersNow() }))
        .safeAreaInset(edge: .bottom) { topicPrimaryFooter }
        // CLB-G13b (MP wxml:340-345): centred confirm with 再想想 / 结束活动, then FINISH.
        .alert(Text("club.topic.directorEnd.title"), isPresented: $directorEndConfirm) {
            Button("club.topic.directorEnd.cancel", role: .cancel) {}
            Button("club.topic.primary.running", role: .destructive) { sendDirector(.finish) }
        } message: {
            Text("club.topic.directorEnd.message")
        }
        .navigationDestination(isPresented: $opensDirectorBroadcast) {
            if let activityID = scope.activityID, let directorHost { directorHost.destination(activityID) }
        }
        .cySheet(isPresented: $sessionPickerVisible) { topicSessionPicker }
        .navigationDestination(item: $pickedSession) { target in
            ClubOpsEventView(scope: target, identity: identity, access: access, coordinator: coordinator)
        }
        // Round 4 copy: MP customer-detail bar title is 客户 (wxml:8); the member action sheet keeps 客户详情.
        .cyPageTitle(String.LocalizationValue(stringLiteral: operation == .customer ? "clubR3b.customer.title" : "club.gov." + operation.rawValue))
        .cyHaptic(.impactMedium, trigger: editor?.id) { _, opened in opened != nil }
        // CLB-r7-D-02 (fix-r3-club-b): MP customers onShow re-reads the list, so a tag/remark saved on the
        // customer page shows when the owner comes back.
        .onAppear { rereadCustomersOnReturn() }
        .cySheet(item: $editor, onDismiss: { rereadCustomerAfterEditor() }) { route in
            NavigationStack { ClubGovernanceCommandForm(route: route, identity: identity, access: access, coordinator: coordinator)
                // CLB-group-code-04 (MP group-code wxml:38-39): the topic-detail 出示团码 carries its session label.
                .environment(\.clubRoleActivityLabel, groupCodeSessionLabel(route)) }
                .cyDomainSheet(detents: [.full])
        }
        .background {
            if let item = seriesUpdateReturn.item {
                ClubSeriesUpdatePresentationOwner(item: item, owner: seriesUpdateReturn,
                    source: { seriesUpdateSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishSeriesUpdateReturn)
                    .id(item.id)
            }
        }
        .background {
            if let item = seriesCreationReturn.item {
                ClubSeriesCreationPresentationOwner(item: item, owner: seriesCreationReturn,
                    source: { seriesCreationSource(topicID: item.route.scope.topicID) },
                    active: { scenePhase == .active }, access: access, coordinator: coordinator,
                    didDismiss: finishSeriesCreationReturn).id(item.id)
            }
            if let target = seriesCreationReturn.destination {
                ClubCreatedSeriesDestinationOwner(target: target, owner: seriesCreationReturn,
                    current: { seriesCreationReturn.destinationIsCurrent(target, context: readContext, access: access) },
                    access: access, coordinator: coordinator).id(target.id)
            }
        }
        .background {
            if let item = occurrenceCancellationReturn.item {
                ClubOccurrenceCancellationPresentationOwner(item: item, owner: occurrenceCancellationReturn,
                    source: { occurrenceCancellationSource }, active: { scenePhase == .active },
                    access: access, coordinator: coordinator, didDismiss: finishOccurrenceCancellationReturn)
                    .id(item.id)
            }
        }
        .onAppear { seriesHostVisible = true; finishSeriesUpdateReturn() }
        .onAppear { finishOccurrenceCancellationReturn() }
        .onChange(of: occurrenceCancellationSource) { _, source in
            occurrenceCancellationReturn.invalidateForm(source: source, active: scenePhase == .active)
        }
        .onAppear { finishSeriesCreationReturn() }
        .onDisappear { seriesHostVisible = false }
        .onChange(of: seriesUpdateSource) { _, source in
            seriesUpdateReturn.invalidateUnlessCurrent(source: source, active: scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { seriesUpdateReturn.retire() }
            if phase != .active { seriesCreationReturn.retire() }
            if phase != .active { occurrenceCancellationReturn.retire() }
        }
        .navigationDestination(item: $leaderboardMember) { target in
            Group {
                if let profile = leaderboardProfile, current(target) {
                    SocialPublicProfileView(memberID: target.memberID, reader: profile.reader,
                        squareReader: profile.squareReader, actions: profile.actions,
                        isCurrent: { current(target) })
                        .id(target.id)
                } else { Color.clear }
            }
            // This destination remains active while the leaderboard is covered.
            // Retire the route here as well, instead of leaving an empty pushed page.
            .onChange(of: current(target), initial: true) { _, valid in
                if !valid, leaderboardMember?.id == target.id { leaderboardMember = nil }
            }
        }
        .navigationDestination(item: $customerTopic) { target in
            if let destination = customerTopics.destination, current(target) {
                destination(target.topicID).id(target.id)
            }
        }
        .navigationDestination(item: $feedClub) { target in
            if let destination = feedContext.destination, current(target) {
                destination(target.clubID).id(target.id)
            } else {
                // The read screen is offscreen while its destination is pushed.
                // Retire the invalid route here too, so account changes cannot
                // leave an empty detail on top of the refreshed feed.
                Color.clear.onAppear {
                    if feedClub?.id == target.id { feedClub = nil }
                }
            }
        }
    }
    private struct CaseReadTrigger: Equatable {
        let context: ClubGovernanceReadContext
        let visible: Bool
        let active: Bool
    }
    private var caseSubmissionSource: ClubCaseSubmissionReturn.Source? {
        guard operation == .cases, !loading, failure == nil,
              let snapshot, snapshotContext == readContext, generation == snapshotGeneration else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: snapshotGeneration, access: access)
    }
    private func finishCaseSubmissionReturn() {
        guard let item = caseSubmissionReturn.item else { return }
        Task { @MainActor in
            guard !Task.isCancelled, operation == .cases, caseHostVisible, scenePhase == .active,
                  caseSubmissionReturn.item?.id == item.id,
                  caseSubmissionReturn.consume(source: caseSubmissionSource,
                      visible: caseHostVisible, active: scenePhase == .active) != nil,
                  let readID = caseSubmissionReturn.readID else { return }
            await load()
            caseSubmissionReturn.finishRead(readID)
        }
    }
    @MainActor private var attendanceSource: ClubAttendanceCorrectionReturn.Source? {
        guard operation == .roster, !loading, failure == nil, let snapshot,
              snapshotContext == readContext, snapshotGeneration == generation else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: generation,
                     bucket: ClubRosterBucket(rawValue: filter) ?? .registered, access: access)
    }
    @MainActor private func loadRosterIfNeeded() async {
        guard operation == .roster, attendanceReturn.visible, scenePhase == .active,
              !attendanceReturn.retainsReturn, !attendanceReads.loading,
              snapshotContext != readContext || snapshotGeneration != generation else { return }
        invalidateRead(); await load()
    }
    @MainActor private func finishAttendanceReturn() {
        guard operation == .roster,
              let ticket = attendanceReturn.consume(source: attendanceSource, active: scenePhase == .active) else { return }
        Task {
            defer { attendanceReturn.finishRead(ticket) }
            guard attendanceReturn.isReading(ticket, context: readContext, active: scenePhase == .active),
                  attendanceSource == ticket.source, !Task.isCancelled else { return }
            await load()
        }
    }
    @MainActor private func rosterReadIsCurrent(_ attachment: UUID?) -> Bool {
        operation != .roster || (attachment != nil && attendanceReturn.attachment == attachment &&
            attendanceReturn.visible && scenePhase == .active)
    }
    @MainActor private var roleManagementSource: ClubRoleManagementReturn.Source? {
        guard operation == .roles, !loading, failure == nil, let snapshot,
              snapshotContext == readContext, snapshotGeneration == generation else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: generation, access: access)
    }
    @MainActor private func loadRolesIfNeeded() async {
        guard operation == .roles, roleManagementReturn.visible, scenePhase == .active,
              !roleManagementReturn.retainsReturn, !roleReads.loading,
              snapshotContext != readContext || snapshotGeneration != generation else { return }
        invalidateRead(); await load()
    }
    @MainActor private func finishRoleManagementReturn() {
        guard operation == .roles,
              let ticket = roleManagementReturn.consume(source: roleManagementSource, active: scenePhase == .active) else { return }
        Task {
            defer { roleManagementReturn.finishRead(ticket) }
            guard roleManagementReturn.isReading(ticket, context: readContext, active: scenePhase == .active),
                  roleManagementSource == ticket.source, !Task.isCancelled else { return }
            let kept = ticket.source
            await load()
            // CLB-r7-C-03 (MP roles/index.js:266-272 failWith afterAction): the list that was on screen stays, and
            // 列表没刷新成功，下拉重试 shows; the first load still lands on the error state.
            if failure != nil, failure != .signedOut, snapshot == nil, !loading, kept.context == readContext,
               identity == access.identity, scenePhase == .active {
                failure = nil; snapshotContext = kept.context; snapshotGeneration = generation; snapshot = kept.snapshot
                roleRereadToast = "club.roles.rereadFailed"
            }
        }
    }
    @MainActor private func roleReadIsCurrent(_ attachment: UUID?) -> Bool {
        operation != .roles || (attachment != nil && roleManagementReturn.attachment == attachment &&
            roleManagementReturn.visible && scenePhase == .active)
    }
    @MainActor private var topicSettingsSource: ClubTopicSettingsReturn.Source? {
        guard operation == .topicSettings, !loading, failure == nil, let snapshot,
              snapshotContext == readContext, snapshotGeneration == generation else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: generation, access: access)
    }
    @MainActor private func loadTopicSettingsIfNeeded() async {
        guard operation == .topicSettings, topicSettingsReturn.visible, scenePhase == .active,
              !topicSettingsReturn.retainsReturn, !topicSettingsReads.loading,
              snapshotContext != readContext || snapshotGeneration != generation else { return }
        invalidateRead(); await load()
    }
    @MainActor private func finishTopicSettingsReturn() {
        guard operation == .topicSettings,
              let ticket = topicSettingsReturn.consume(source: topicSettingsSource, active: scenePhase == .active) else { return }
        Task {
            defer { topicSettingsReturn.finishRead(ticket) }
            guard topicSettingsReturn.isReading(ticket, context: readContext, active: scenePhase == .active),
                  topicSettingsSource == ticket.source, !Task.isCancelled else { return }
            await load()
        }
    }
    @MainActor private func topicSettingsReadIsCurrent(_ attachment: UUID?) -> Bool {
        operation != .topicSettings || (attachment != nil && topicSettingsReturn.attachment == attachment &&
            topicSettingsReturn.visible && scenePhase == .active)
    }
    private struct SettlementReadKey: Hashable { let context: ClubGovernanceReadContext; let namespace: String }
    private var settlementReadKey: SettlementReadKey { .init(context: readContext, namespace: access.storageNamespace) }
    @MainActor private var settlementSource: ClubSettlementReturnOwner.Source? {
        guard operation == .settlement, !loading, failure == nil, let snapshot,
              settlementReturn.context == readContext, settlementReturn.namespace == access.storageNamespace,
              snapshotContext == readContext, snapshotGeneration == generation,
              let presentation = try? ClubSettlementDetailPresentation(snapshot: snapshot, context: readContext) else { return nil }
        return .init(presentation: presentation, context: readContext, generation: snapshotGeneration, namespace: access.storageNamespace)
    }
    @MainActor private var ownerFundsSource: ClubOwnerFundsParent.Source? {
        guard scenePhase == .active, settlementSource != nil, let snapshot,
              identity == access.identity, ownerFunds.isCurrent(),
              let target = ClubOwnerFundsTarget(snapshot: snapshot, context: readContext) else { return nil }
        return .init(target: target, readerID: ownerFunds.reader.map { ObjectIdentifier($0) },
            walletScope: ownerFunds.reader?.scope, generation: snapshotGeneration, namespace: access.storageNamespace)
    }
    @MainActor private func loadOwnerFundsIfNeeded() async {
        guard operation == .settlement else { return }
        ownerFundsParent.synchronize(ownerFundsSource)
        guard let ticket = ownerFundsParent.ticket(current: ownerFundsSource, active: scenePhase == .active,
            otherPresented: settlementReturn.retainsChild) else { return }
        await ownerFundsParent.load(ticket, access: access, context: ownerFunds, current: { ownerFundsSource },
            active: { scenePhase == .active }, otherPresented: { settlementReturn.retainsChild })
    }
    @MainActor private func activateSettlementParent() {
        if settlementReturn.synchronize(readContext, namespace: access.storageNamespace) { invalidateRead(); loading = false }
        settlementReturn.appear(readContext, namespace: access.storageNamespace)
    }
    @MainActor private func settlementReadIsCurrent(_ attachment: UUID?) -> Bool {
        operation != .settlement || settlementReturn.acceptsRead(attachment, context: readContext,
            namespace: access.storageNamespace, active: scenePhase == .active && !ownerFundsParent.retainsContact)
    }
    @MainActor private func loadSettlementIfNeeded() async {
        guard operation == .settlement, let attachment = settlementReturn.attachment,
              settlementReadIsCurrent(attachment), !loading,
              settlementReturn.needsRefresh || snapshotContext != readContext || snapshotGeneration != generation else { return }
        let context = readContext, namespace = access.storageNamespace, before = generation
        await load()
        guard generation != before else { return }
        settlementReturn.finishedRead(attachment, context: context, namespace: namespace, active: scenePhase == .active,
            succeeded: failure == nil && snapshot != nil && snapshotContext == context && snapshotGeneration == generation)
    }
    @MainActor private func occurrenceSource(seriesID: Int) -> ClubSeriesOccurrenceHost.Source? {
        guard operation == .series, !loading, failure == nil, let snapshot,
              snapshotContext == readContext, snapshotGeneration == generation else { return nil }
        return .init(snapshot: snapshot, context: readContext, generation: generation, seriesID: seriesID, access: access)
    }
    @MainActor private var currentOccurrenceSource: ClubSeriesOccurrenceHost.Source? {
        guard let id = seriesOccurrences.source?.scope.seriesID else { return nil }
        return occurrenceSource(seriesID: id)
    }
    @MainActor private func loadSeriesOccurrencesIfNeeded() async {
        guard operation == .series else { return }
        await seriesOccurrences.loadIfNeeded(access: access, current: { currentOccurrenceSource }, active: { scenePhase == .active })
    }
    @MainActor private var banRemovalSource: ClubBanRemovalReturn.Source? {
        guard operation == .bans, !loading, failure == nil, let snapshot,
              snapshotContext == readContext, snapshotGeneration == generation else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: generation, access: access)
    }
    @MainActor private func loadBansIfNeeded() async {
        guard operation == .bans, banRemovalReturn.visible, scenePhase == .active,
              !banRemovalReturn.retainsReturn, !banReads.loading,
              snapshotContext != readContext || snapshotGeneration != generation else { return }
        invalidateRead(); await load()
    }
    @MainActor private func finishBanRemovalReturn() {
        guard operation == .bans,
              let ticket = banRemovalReturn.consume(source: banRemovalSource, active: scenePhase == .active) else { return }
        Task {
            defer { banRemovalReturn.finishRead(ticket) }
            guard banRemovalReturn.isReading(ticket, context: readContext, active: scenePhase == .active),
                  banRemovalSource == ticket.source, !Task.isCancelled else { return }
            await load()
        }
    }
    @MainActor private func banReadIsCurrent(_ attachment: UUID?) -> Bool {
        operation != .bans || (attachment != nil && banRemovalReturn.attachment == attachment &&
            banRemovalReturn.visible && scenePhase == .active)
    }
    private var occurrenceCancellationSource: ClubOccurrenceCancellationReturn.Source? {
        guard operation == .occurrenceStatus, !loading, failure == nil, let snapshot,
              snapshotContext == readContext, generation == snapshotGeneration else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: snapshotGeneration, access: access)
    }
    private func finishOccurrenceCancellationReturn() {
        guard let item = occurrenceCancellationReturn.item else { return }
        Task { @MainActor in
            guard !Task.isCancelled, seriesHostVisible, scenePhase == .active,
                  occurrenceCancellationReturn.item?.id == item.id,
                  occurrenceCancellationReturn.consume(source: occurrenceCancellationSource,
                      visible: seriesHostVisible, active: scenePhase == .active) != nil else { return }
            await load()
        }
    }
    private func seriesCreationSource(topicID: Int?) -> ClubSeriesCreationReturn.Source? {
        guard operation == .eventTopics, !loading, failure == nil, let topicID,
              let snapshot, snapshotContext == readContext, generation == snapshotGeneration else { return nil }
        return .topics(context: readContext, snapshot: snapshot, generation: snapshotGeneration,
                       topicID: topicID, access: access)
    }
    private func finishSeriesCreationReturn() {
        guard let item = seriesCreationReturn.item else { return }
        Task { @MainActor in
            guard !Task.isCancelled, seriesHostVisible, scenePhase == .active,
                  seriesCreationReturn.item?.id == item.id else { return }
            seriesCreationReturn.consume(source: seriesCreationSource(topicID: item.route.scope.topicID),
                                         visible: seriesHostVisible, active: scenePhase == .active)
        }
    }
    private var seriesUpdateSource: ClubSeriesUpdateReturn.Source? {
        guard operation == .seriesDetail, !loading, failure == nil,
              let snapshot, snapshotContext == readContext, generation == snapshotGeneration else { return nil }
        return .init(context: readContext, snapshot: snapshot, generation: snapshotGeneration, access: access)
    }
    private func finishSeriesUpdateReturn() {
        // Both onAppear-before-onDismiss and onDismiss-before-onAppear arrive
        // here. The concrete owner retains its ticket until it is visible.
        Task { @MainActor in
            guard !Task.isCancelled, seriesHostVisible, scenePhase == .active,
                  seriesUpdateReturn.consume(source: seriesUpdateSource, visible: seriesHostVisible,
                                             active: scenePhase == .active) != nil else { return }
            await load()
        }
        // Mini handleSeriesConflict: a definite 409 only re-reads; nothing is re-sent.
        Task { @MainActor in
            guard !Task.isCancelled, seriesHostVisible, scenePhase == .active,
                  seriesUpdateReturn.consumeConflict(source: seriesUpdateSource, visible: seriesHostVisible,
                                                     active: scenePhase == .active) != nil else { return }
            await load()
        }
    }
    private var terminalSource: ClubTerminalSessionPresentation.Source? {
        guard operation == .topicOverview, !loading, scenePhase == .active,
              let snapshot, snapshotContext == readContext, identity == access.identity else { return nil }
        return .init(context: readContext, generation: snapshotGeneration, snapshot: snapshot,
                     approvalID: terminalSessions.approvalID, viewerRevision: terminalSessions.viewerRevision)
    }
    private var customerFilterBinding: Binding<String> {
        Binding(get: { customerFilters.filter }, set: { value in
            guard customerFilters.filter != value else { return }
            customerFilters.filter = value
            loadCustomersNow()
        })
    }
    private var customerKeywordBinding: Binding<String> {
        Binding(get: { customerFilters.keyword }, set: { value in
            guard customerFilters.keyword != value else { return }
            customerFilters.keyword = value
            scheduleCustomerKeywordRead()
        })
    }
    @MainActor private func clearCustomerFilters(source: ClubGovernanceSnapshot,
                                                 context: ClubGovernanceReadContext,
                                                 sourceGeneration: UInt64,
                                                 filters: ClubCustomerFilters) {
        guard operation == .customers, !loading, failure == nil,
              identity?.isSignedIn == true, identity == access.identity,
              scenePhase == .active, readContext == context, snapshotContext == context,
              snapshot == source, snapshotGeneration == sourceGeneration,
              generation == sourceGeneration, customerFilters == filters,
              snapshotCustomerFilters == filters,
              filters.isFiltered, source.value["items"].array?.isEmpty == true else { return }
        customerKeywordDebounce.cancel()
        guard customerFilters.clear() else { return }
        // Programmatic reset bypasses the input bindings and retires old results
        // before scheduling exactly one immediate, context-bound replacement read.
        generation &+= 1
        snapshot = nil; snapshotContext = nil; failure = nil; loading = false
        let revision = generation
        let expected = identity
        Task {
            guard revision == generation, readContext == context, identity == expected,
                  access.identity == expected, customerFilters == ClubCustomerFilters(),
                  scenePhase == .active, !Task.isCancelled else { return }
            await load()
        }
    }
    @MainActor private func loadCustomersNow() {
        customerKeywordDebounce.cancel()
        Task { await load() }
    }
    @MainActor private func scheduleCustomerKeywordRead() {
        guard operation == .customers else { return }
        let context = readContext; let expected = identity
        let expectedFilter = customerFilters.filter; let expectedKeyword = customerFilters.keyword
        // Invalidate an older response immediately, including the 300ms wait.
        generation &+= 1
        snapshot = nil; snapshotContext = nil; failure = nil; loading = false
        let keywordRevision = generation
        customerKeywordDebounce.schedule {
            guard operation == .customers, context == readContext, expected == identity,
                  access.identity == expected, keywordRevision == generation,
                  customerFilters.filter == expectedFilter, customerFilters.keyword == expectedKeyword,
                  !Task.isCancelled else { return }
            await load()
        }
    }
    /// Shared read. A failed roles re-read keeps the previous list in finishRoleManagementReturn (CLB-r7-C-03).
    @MainActor private func load() async {
        let cancellationTicket = occurrenceCancellationReturn.readback
        let cancellationCurrent = {
            operation != .occurrenceStatus || (seriesHostVisible && scenePhase == .active &&
                (cancellationTicket.map {
                    occurrenceCancellationReturn.readIsCurrent($0, context: readContext, access: access,
                        visible: seriesHostVisible, active: scenePhase == .active)
                } ?? (occurrenceCancellationReturn.readback == nil)))
        }
        guard cancellationCurrent() else { return }
        let caseReadIsCurrent = { operation != .cases || (caseHostVisible && scenePhase == .active) }
        guard caseReadIsCurrent() else { return }
        let rosterAttachment = attendanceReturn.attachment
        guard rosterReadIsCurrent(rosterAttachment), operation != .roster || !attendanceReads.loading else { return }
        let roleAttachment = roleManagementReturn.attachment
        guard roleReadIsCurrent(roleAttachment), operation != .roles || !roleReads.loading else { return }
        let topicSettingsAttachment = topicSettingsReturn.attachment
        guard topicSettingsReadIsCurrent(topicSettingsAttachment), operation != .topicSettings || !topicSettingsReads.loading else { return }
        let banAttachment = banRemovalReturn.attachment
        guard banReadIsCurrent(banAttachment), operation != .bans || !banReads.loading else { return }
        let settlementAttachment = settlementReturn.attachment
        guard settlementReadIsCurrent(settlementAttachment), operation != .settlement || !loading else { return }
        if operation == .customers { customerKeywordDebounce.cancel() }
        generation &+= 1; let revision = generation; let expected = identity; let context = readContext
        let customerQuery = customerFilters
        snapshot = nil; failure = nil; loading = true
        snapshotContext = nil; customerTopic = nil; feedClub = nil; feedMediaScope = UUID()
        leaderboardMember = nil
        guard expected?.isSignedIn == true else { loading = false; failure = .signedOut; return }
        var options: [String: ClubGovernanceValue] = [:]
        if operation == .customers { options = ["filter": .string(customerQuery.filter), "keyword": .string(customerQuery.keyword)] }
        if operation == .topicCustomers { options = topicCustomerFilter.options }
        if operation == .leaderboard { options = ["sortBy": .string(sort)] }
        if operation == .feed { options = ["limit": .integer(20)] }
        if operation == .posts { options = ["pageNum": .integer(page), "pageSize": .integer(20)] }
        do {
            let check: @MainActor () throws -> Void = {
                guard cancellationCurrent(), revision == generation else { throw CancellationError() }
                guard caseReadIsCurrent(), revision == generation, context == readContext, expected == identity,
                      rosterReadIsCurrent(rosterAttachment), roleReadIsCurrent(roleAttachment), topicSettingsReadIsCurrent(topicSettingsAttachment), banReadIsCurrent(banAttachment), settlementReadIsCurrent(settlementAttachment), access.identity == expected, !Task.isCancelled else { throw CancellationError() }
            }
            let result: ClubGovernanceSnapshot
            if operation == .roster {
                result = try await attendanceReads.load(context: context, access: access, check: check)
            } else if operation == .roles {
                result = try await roleReads.load(context: context, access: access, check: check)
            } else if operation == .topicSettings {
                result = try await topicSettingsReads.load(context: context, access: access, check: check)
            } else if operation == .bans {
                result = try await banReads.load(context: context, access: access, check: check)
            } else {
                result = try await access.read(operation, scope: scope, options: options, check: check)
            }
            guard cancellationCurrent(), revision == generation else { return }
            guard caseReadIsCurrent(), revision == generation, context == readContext, expected == identity, rosterReadIsCurrent(rosterAttachment), roleReadIsCurrent(roleAttachment), topicSettingsReadIsCurrent(topicSettingsAttachment), banReadIsCurrent(banAttachment), settlementReadIsCurrent(settlementAttachment), access.identity == expected, !Task.isCancelled else { return }
            guard context.accepts(result) else { throw ClubGovernanceFailure.targetChanged }
            if let expectedCreatedSeries, !expectedCreatedSeries.accepts(result) { throw ClubGovernanceFailure.targetChanged }
            if let cancellationTicket {
                occurrenceCancellationReturn.observe(result, for: cancellationTicket, context: context, access: access,
                    visible: seriesHostVisible, active: scenePhase == .active)
            }
            snapshotContext = context; snapshotGeneration = revision; snapshot = result
            snapshotCustomerFilters = operation == .customers ? customerQuery : nil
        } catch {
            guard cancellationCurrent(), revision == generation else { return }
            guard caseReadIsCurrent(), revision == generation, context == readContext, expected == identity, rosterReadIsCurrent(rosterAttachment), roleReadIsCurrent(roleAttachment), topicSettingsReadIsCurrent(topicSettingsAttachment), banReadIsCurrent(banAttachment), settlementReadIsCurrent(settlementAttachment), access.identity == expected, !Task.isCancelled else { return }
            failure = error as? ClubGovernanceFailure ?? .malformed
        }
        if revision == generation { loading = false }
    }
    @MainActor private func invalidateRead() {
        seriesUpdateReturn.retire(); seriesCreationReturn.retire()
        occurrenceCancellationReturn.retire()
        caseSubmissionReturn.retire()
        if operation == .roster { attendanceReads.retire() }
        if operation == .roles { roleReads.retire() }
        if operation == .topicSettings { topicSettingsReads.retire() }
        if operation == .bans { banReads.retire() }
        if operation == .customers { customerKeywordDebounce.cancel() }
        generation &+= 1; snapshot = nil; snapshotContext = nil; failure = nil; editor = nil; customerTopic = nil; feedClub = nil; feedMediaScope = UUID(); coordinator.cancelReview()
        leaderboardMember = nil
    }
    /// Customer detail re-reads its server tags/remark when the reviewed editor closes; the read keeps every existing fence.
    @MainActor private func rereadCustomersOnReturn() {
        guard operation == .customers, scenePhase == .active, snapshot != nil, snapshotContext == readContext,
              identity == access.identity, !loading else { return }
        Task { await load() }
    }
    @MainActor private func rereadCustomerAfterEditor() {
        guard operation == .customer, scenePhase == .active, snapshot != nil, snapshotContext == readContext,
              identity == access.identity, !loading else { return }
        Task { await load() }
    }
    private func current(_ target: ClubLeaderboardMemberRoute) -> Bool {
        guard operation == .leaderboard, identity == access.identity, access.isConfigured,
              snapshotContext == readContext, let profile = leaderboardProfile else { return false }
        return target.isCurrent(snapshot: snapshot, context: readContext,
            snapshotGeneration: snapshotGeneration, profile: profile)
    }
    private func leaderboardMemberRoute(_ row: ClubGovernanceValue) -> ClubLeaderboardMemberRoute? {
        guard operation == .leaderboard, let snapshot, snapshotContext == readContext,
              identity == access.identity, access.isConfigured, let profile = leaderboardProfile else { return nil }
        return .init(row: row, snapshot: snapshot, context: readContext,
            snapshotGeneration: snapshotGeneration, profile: profile)
    }
    private func selectLeaderboardMember(_ target: ClubLeaderboardMemberRoute) {
        // A queued tap from a covered/retired source cannot start a new push.
        // Once pushed, the immutable accepted snapshot keeps the destination alive.
        guard leaderboardMember == nil, snapshotGeneration == generation, current(target) else { return }
        leaderboardMember = target
    }
    private func current(_ target: ClubFeedClubRoute) -> Bool {
        identity == access.identity && access.isConfigured && snapshotContext == readContext &&
        feedContext.destination != nil &&
        target.isCurrent(snapshot: snapshot, context: readContext, snapshotGeneration: snapshotGeneration)
    }
    private func feedClubRoute(_ post: ClubFeedPost) -> ClubFeedClubRoute? {
        guard let snapshot, snapshotContext == readContext, identity == access.identity,
              access.isConfigured, feedContext.destination != nil else { return nil }
        return .init(post: post, snapshot: snapshot, context: readContext, snapshotGeneration: snapshotGeneration)
    }
    private func selectFeedClub(_ target: ClubFeedClubRoute) {
        guard feedClub == nil, current(target) else { return }
        feedClub = target
    }
    private func current(_ target: ClubCustomerHistoryTopicRoute) -> Bool {
        identity == access.identity && access.isConfigured && snapshotContext == readContext &&
        target.isCurrent(snapshot: snapshot, context: readContext, snapshotGeneration: snapshotGeneration)
    }
    private func customerTopicRoute(_ row: ClubGovernanceValue) -> ClubCustomerHistoryTopicRoute? {
        guard operation == .customer, let snapshot, snapshotContext == readContext,
              customerTopics.destination != nil, identity == access.identity, access.isConfigured else { return nil }
        return .init(record: row, snapshot: snapshot, context: readContext, snapshotGeneration: snapshotGeneration)
    }
    private func selectCustomerTopic(_ target: ClubCustomerHistoryTopicRoute) {
        guard customerTopic == nil, current(target) else { return }
        customerTopic = target
    }
    /// CLB-group-code-04: the 「活动名 · 开始时间」 label of the topic session an 出示团码 route targets, from the loaded topic.
    private func groupCodeSessionLabel(_ route: ClubGovernanceFormRoute) -> String? {
        guard route.operation == .issueGroupCode, operation == .topicOverview, let id = route.scope.activityID,
              let row = (snapshot?.value["activityList"].array ?? []).first(where: { $0["id"].int == id }),
              let name = row["name"].string else { return nil }
        return ClubGroupCodePort.sessionLabel(id: id, name: name, startDate: row["startDate"].string, startTime: row["startTime"].string)
    }
    /// CLB-notify-01: in-app 通知 entries open the composer (ClubGovernanceCommandForm .sendNotification) directly, like the
    /// MP notify link (MPReviewedPageScreen), instead of a counts page with a second step.
    private func notifyComposerLink(_ target: ClubGovernanceScope) -> some View {
        NavigationLink {
            ClubGovernanceCommandForm(route: .init(operation: .sendNotification, scope: .init(clubID: target.clubID, activityID: target.activityID)),
                                      identity: identity, access: access, coordinator: coordinator)
        } label: {
            routeLabel(.audienceCounts)
        }
        .accessibilityIdentifier("club.gov.route." + ClubGovernanceRead.audienceCounts.rawValue)
    }
    private func link(_ target: ClubGovernanceRead, _ targetScope: ClubGovernanceScope? = nil) -> some View {
        NavigationLink { ClubGovernanceReadView(operation: target, scope: targetScope ?? scope, identity: identity, access: access, coordinator: coordinator) } label: {
            routeLabel(target)
        }
            .accessibilityIdentifier("club.gov.route." + target.rawValue)
    }
    /// Settings-style row: icon, title, and on the workspace list the MP one-line description under it.
    private func routeLabel(_ target: ClubGovernanceRead) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("club.gov." + target.rawValue))
                if operation == .access, let meta = Self.subline(target) {
                    Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } icon: { Image(systemName: Self.symbol(target)) }
    }
    /// Mini-program settings-sheet rows carry a one-line description under the title (workspace list only).
    static func subline(_ read: ClubGovernanceRead) -> String? {
        switch read {
        case .customers, .stats, .settlement, .eventTopics, .series, .topics, .editions, .leaderboard,
             .posts, .roles, .bans, .cases, .audienceCounts, .dissolutionBlockers:
            return String(localized: String.LocalizationValue("club.gov.sub." + read.rawValue))
        default: return nil
        }
    }
    /// One meaningful icon per workspace entry instead of the same chevron on every row.
    static func symbol(_ read: ClubGovernanceRead) -> String {
        switch read {
        case .stats, .topicStats: return "chart.bar"
        case .customers, .topicCustomers, .customer: return "person.2"
        case .settlement: return "yensign.circle"
        case .eventTopics, .series, .occurrences: return "calendar"
        case .bans, .members: return "hand.raised"
        case .cases: return "exclamationmark.bubble"
        case .roles: return "person.badge.key"
        case .audienceCounts: return "megaphone"
        case .topics, .topicOverview: return "map"
        case .editions: return "square.stack"
        case .dissolutionBlockers: return "trash"
        case .leaderboard: return "trophy"
        case .posts, .feed: return "text.bubble"
        case .topicSettings: return "gearshape"
        case .recruit: return "storefront"
        default: return "chevron.right.circle"
        }
    }
    @ViewBuilder private func enrollmentLink(focusTopicID: Int? = nil) -> some View {
        if let clubID = scope.clubID {
            NavigationLink {
                ClubEnrollmentView(clubID: clubID, focusTopicID: focusTopicID, identity: identity, access: access, coordinator: coordinator)
            } label: { Label("club.enroll.title", systemImage: "list.bullet.clipboard") }
                .accessibilityIdentifier("club.enroll.open")
        }
    }
    private func edit(_ operation: ClubGovernanceMutation, scope: ClubGovernanceScope? = nil, seed: [String: ClubGovernanceValue] = [:], role: ClubGovActionRole = .secondary) -> some View {
        let source = roleManagementSource
        let settingsSource = topicSettingsSource
        let bansSource = banRemovalSource
        // Round 4 copy: MP customer-detail button reads 编辑 (wxml:96); 编辑标签与备注 stays its VoiceOver label and the editor title.
        let titleKey = LocalizedStringKey(operation == .saveCustomer ? "clubR3b.customer.edit" : "club.gov.action." + operation.rawValue)
        return Button(role: role == .destructive || role == .inlineDestructive ? .destructive : nil) {
            if operation == .updateSeries, self.operation == .seriesDetail {
                seriesUpdateReturn.open(seriesUpdateSource, visible: seriesHostVisible, active: scenePhase == .active)
            } else if operation == .createSeries, self.operation == .eventTopics {
                seriesCreationReturn.open(seriesCreationSource(topicID: scope?.topicID),
                                          visible: seriesHostVisible, active: scenePhase == .active)
            } else if operation == .cancelOccurrence, self.operation == .occurrenceStatus {
                occurrenceCancellationReturn.open(occurrenceCancellationSource,
                    visible: seriesHostVisible, active: scenePhase == .active)
            } else if self.operation == .bans, operation == .unban {
                guard editor == nil, bansSource == banRemovalSource, scope == nil || scope == self.scope else { return }
                banRemovalReturn.open(seed: seed, source: bansSource, active: scenePhase == .active)
            } else if self.operation == .topicSettings, operation == .saveTopicSettings {
                let source = settingsSource
                guard editor == nil, source == topicSettingsSource, scope == nil || scope == self.scope else { return }
                topicSettingsReturn.open(seed: seed, source: source, active: scenePhase == .active)
            } else if self.operation == .roles, [.assignRole, .revokeRole].contains(operation) {
                guard editor == nil, source == roleManagementSource, scope == nil || scope == self.scope else { return }
                roleManagementReturn.open(operation, seed: seed, source: source, active: scenePhase == .active)
            } else if self.operation == .cases, [.report, .appeal].contains(operation) {
                caseSubmissionReturn.open(operation, source: caseSubmissionSource,
                                          visible: caseHostVisible, active: scenePhase == .active)
            } else { editor = .init(operation: operation, scope: scope ?? self.scope, seed: seed) }
        } label: {
            // The one prominent action fills the row width; every other command reads as a plain list row action.
            Text(titleKey).frame(maxWidth: role == .primary ? .infinity : nil)
        }
        .modifier(ClubGovActionChrome(role: role))
        .disabled((self.operation == .roles && roleManagementReturn.retainsReturn) ||
                  (self.operation == .topicSettings && topicSettingsReturn.retainsReturn) ||
                  (self.operation == .bans && banRemovalReturn.retainsReturn))
        .accessibilityIdentifier("club.gov.action." + operation.rawValue)
    }
    @ViewBuilder private func content(_ snapshot: ClubGovernanceSnapshot) -> some View {
        let value = snapshot.value
        if operation == .access {
            // Viewer's own roles, by name. Unrecognised internal codes are not shown.
            let knownRoles = (snapshot.permissions?.roleCodes ?? []).filter { ["CLUB_OWNER", "CLUB_CO_OWNER", "CLUB_OPERATOR", "CLUB_MEMBER", "EVENT_LEAD", "EVENT_CHECKIN"].contains($0) }
            if !knownRoles.isEmpty {
                Section("club.gov.yourRoles") {
                    ForEach(knownRoles, id: \.self) { code in
                        Label(LocalizedStringKey("club.gov.role." + code), systemImage: "person.badge.key")
                    }
                }
            }
            // Mini-program club settings sheet order: 客户与项目, then 成员与权限.
            Section("club.gov.section.customers") {
                if snapshot.permissions?.allows("club:member:list:read", scope: scope) == true { enrollmentLink() }
                ForEach([ClubGovernanceRead.customers, .stats, .settlement, .eventTopics, .series, .topics, .editions, .leaderboard, .posts], id: \.rawValue) { read in
                    if snapshot.permissions?.allows(read.permission, scope: scope) == true { link(read) }
                    if read == .series, ClubOpsEventAccess(permissions: snapshot.permissions, scope: scope).permitted {
                        NavigationLink { ClubOpsEventView(scope: scope, identity: identity, access: access, coordinator: coordinator) } label: {
                            Label { Text("clubOpsEvent.title", tableName: "ClubOpsEvent") } icon: { Image(systemName: "calendar.badge.clock") }
                        }.accessibilityIdentifier("clubOpsEvent.open")
                    }
                }
            }
            Section("club.gov.section.members") {
                ForEach([ClubGovernanceRead.roles, .bans, .cases, .audienceCounts, .dissolutionBlockers], id: \.rawValue) { read in
                    if read == .bans {
                        if snapshot.permissions?.canGovernMembers == true { link(read) }
                    } else if read == .audienceCounts {
                        // CLB-notify-01 (MP notify wxml:44-114): the workspace entry opens the one composer, as the MP link does.
                        if snapshot.permissions?.allows(read.permission, scope: scope) == true { notifyComposerLink(scope) }
                    } else if snapshot.permissions?.allows(read.permission, scope: scope) == true { link(read) }
                }
                if snapshot.permissions?.permissions.contains("club:member:manage") == true,
                   snapshot.permissions?.canGovernMembers != true {
                    Text(verbatim: ClubGovernancePermissions.memberGovernanceDenial)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("club.memberGovernance.denied")
                }
            }
            if let events = snapshot.permissions?.eventAccesses, !events.isEmpty {
                Section("club.gov.delegatedEvents") {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        if let activityID = event["activityId"].int, let topicID = event["topicId"].int {
                            let target = ClubGovernanceScope(clubID: scope.clubID, topicID: topicID, activityID: activityID)
                            NavigationLink { ClubGovernanceEventView(scope: target, identity: identity, access: access, coordinator: coordinator) } label: { Text("club.gov.eventID \(activityID)") }
                        }
                    }
                }
            }
        } else if operation == .hostStatus {
            // Mini-program club/apply: intro → form; merchant accounts get a blocked state; hosts see the done card.
            if value["accountRole"] == .string("merchant") {
                // CLB-apply-04 (r9, MP apply js:94-96, 108, 159-163): a merchant-role account is an active merchant
                // (MP isMerchantAccount → merchantActive: true) unless the read says otherwise. Active → 切换到商家端
                // (reLaunch pages/merchant/index/index); otherwise 查看商家入驻 (pages/merchant/apply/index).
                let merchantActive = value["merchantActive"].bool ?? true
                ContentUnavailableView("club.host.merchant.title", systemImage: "storefront",
                                       description: Text(LocalizedStringKey(merchantActive ? "club.host.merchant.activeSub" : "club.gov.hostMerchantBlocked")))
                // CLB-apply-04 (MP apply wxml:30-33, js:157-162): the way out is the merchant side, plus 返回.
                Section {
                    if PlayerLaunch.merchantCenterEnabled { // Lane G: 切换到商家端 / 查看商家入驻 hidden in Release
                    NavigationLink {
                        MPReviewedPageScreen(page: merchantActive ? "pages/merchant/index/index" : "pages/merchant/apply/index", query: [:])
                    } label: {
                        Text(LocalizedStringKey(merchantActive ? "club.host.merchant.switch" : "club.host.merchant.viewApply"))
                    }
                    .accessibilityIdentifier(merchantActive ? "club.host.merchant.switch" : "club.host.merchant.viewApply")
                    }
                    Button("action.back") { dismissPage() }
                        .accessibilityIdentifier("club.host.merchant.back")
                }
            } else if value["accountRole"] == .string("club") {
                // Source club/apply done card: page title 成为主理人, an 已生效 chip, then the 可建俱乐部 row.
                Section {
                    Label { Text("club.host.done.active") } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("club.host.done.status")).accessibilityValue(Text("club.host.done.active"))
                    // CLB-apply-11 (MP apply wxml:177): 主理人 <leaderName> when the status read carries it.
                    if let leader = value["leaderName"].string?.trimmingCharacters(in: .whitespacesAndNewlines), !leader.isEmpty {
                        LabeledContent("club.host.done.leaderLabel") { Text(verbatim: leader) }
                            .accessibilityIdentifier("club.host.done.leader")
                    }
                    LabeledContent("club.host.done.limitLabel") {
                        Text(verbatim: ClubHostApplyPageModel(loading: false, snapshot: snapshot, capabilityGranted: access.isConfigured,
                                                              allowance: value["allowance"]).allowance.displayText)
                    }
                }
                Section { ClubCreateMyClubLink(identity: identity) }
            } else {
                // Source club/apply intro: one large two-line title over the 成为主理人 CTA, nothing else.
                Section {
                    Text("club.host.intro.title").font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                }
                Section {
                    edit(.hostApply, role: .primary)
                }
            }
        } else if operation == .roster {
            if let roster = try? ClubRosterPresentation(snapshot: snapshot, context: readContext) {
                let source = attendanceSource
                ClubRosterBucketContent(roster: roster, context: readContext, snapshotGeneration: snapshotGeneration,
                    namespace: access.storageNamespace,
                    selected: Binding(get: { ClubRosterBucket(rawValue: filter) ?? .registered }, set: { filter = $0.rawValue })) { target in
                    guard editor == nil, source == attendanceSource else { return }
                    attendanceReturn.open(target, source: source, access: access, active: scenePhase == .active)
                }.disabled(attendanceReturn.retainsReturn)
            } else { Text("club.gov.malformed").accessibilityIdentifier("club.roster.malformed") }
        } else if operation == .roles {
            ClubOpsRoleSection(roles: snapshot, context: readContext, access: access, assign: AnyView(edit(.assignRole))) { row in
                AnyView(edit(.revokeRole, seed: row.revokeSeed, role: .inlineDestructive))
            }
            ClubRoleRevocationRecoverySection(recovery: coordinator.roleRevocation, context: readContext, access: access) { Task { await load() } }
            ClubRoleAssignmentRecoverySection(recovery: coordinator.roleAssignment, context: readContext, access: access) { Task { await load() } }
            // CLB-roles-05: the MP roles page has no 可委派角色 list; the role choice lives in the assign picker.
        } else if operation == .bans, let bans = try? ClubOpsBanList(snapshot: snapshot) {
            ClubOpsBanSection(list: bans, scope: scope, capability: .init(permissions: snapshot.permissions, scope: scope), document: snapshot.value) { row in AnyView(edit(.unban, seed: row.unbanSeed ?? [:], role: .inlineLink)) }
            // CLB-governance-01 (MP governance wxml:61-122): records, then the 对成员执行 card on the same page.
            ClubOpsMemberActionCard(clubID: scope.clubID, identity: identity, access: access,
                ban: { member, days in
                    var seed = member.seed
                    seed["banDays"] = .string(String(days))
                    return AnyView(edit(.ban, seed: seed, role: .inlineDestructive))
                },
                transfer: { AnyView(edit(.transferOwner, seed: $0.seed, role: .inlineDestructive)) },
                fallback: AnyView(link(.members)))
        } else if operation == .members, let members = try? ClubOpsGovernanceMembers(snapshot: snapshot) {
            ClubOpsGovernanceMembersSection(roster: members, ban: { AnyView(edit(.ban, seed: $0.seed, role: .inlineDestructive)) }, transfer: { AnyView(edit(.transferOwner, seed: $0.seed, role: .inlineDestructive)) },
                scope: scope, capability: .init(permissions: snapshot.permissions, scope: scope), document: snapshot.value,
                showsBan: snapshot.permissions?.canGovernMembers == true,
                memberGovernanceDenial: snapshot.permissions?.permissions.contains("club:member:manage") == true && snapshot.permissions?.canGovernMembers != true
                    ? ClubGovernancePermissions.memberGovernanceDenial : nil)
        } else if operation == .cases, let cases = try? ClubOpsCaseList(snapshot: snapshot) {
            ClubOpsCaseSection(list: cases, report: cases.canReport ? AnyView(edit(.report)) : nil, appeal: cases.canAppeal ? AnyView(edit(.appeal)) : nil,
                scope: scope, capability: .init(permissions: snapshot.permissions, scope: scope), document: snapshot.value)
        } else if operation == .recruit {
            ClubTopicMerchantContent(snapshot: snapshot, context: readContext, snapshotGeneration: snapshotGeneration, readGeneration: generation, access: access)
        } else if operation == .topicOverview {
            let terminalContext = readContext, terminalGeneration = snapshotGeneration
            // Mini-program club/topic-detail order: title + status → quick entries → 未通过原因 →
            // 剧情与玩法 → 接下来 (sessions) → director (terminal sessions) → rules.
            // CLB-topic-detail-04: MP resolveStateKey on the numeric cms_topic.status, then the manage stats'
            // sessionStatus for viewers without the director (MP applyVerifyVisibility).
            let stats = topicStats ?? .null
            let topicState = ClubTopicDetailPort.stateKey(value)
            let canDirect = stats["canDirect"] == .bool(true)
            let topicDisplay = canDirect ? ClubTopicDetailPort.Display(state: topicState, cancelled: false)
                : ClubTopicDetailPort.display(audit: topicState, sessionStatus: stats["sessionStatus"].string)
            Section {
                // CLB-topic-detail-08 (MP wxml:28-61): cover (none → no block), merchant logo, status, the name as the
                // page title, one date-range line and the verify-mode line.
                let coverURL = QuestifyCardArtwork.safeURL(
                    (value["imgUrl"].string?.split(separator: ",").first.map(String.init)) ?? value["cover"].string ?? value["coverUrl"].string)
                let logoURL = QuestifyCardArtwork.safeURL(value["merchantLogo"].string)
                if let coverURL {
                    AsyncImage(url: coverURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color(uiColor: .secondarySystemFill) }
                    }
                    .frame(height: 160).frame(maxWidth: .infinity).clipped()
                    .listRowInsets(EdgeInsets())
                    .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let logoURL {
                        AsyncImage(url: logoURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Color(uiColor: .secondarySystemFill) }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel(Text("club.topic.merchantLogo"))
                    }
                    Text(verbatim: value["name"].string ?? value["title"].string ?? "—")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 8) {
                        let chipState = topicDisplay.state == .selfrun ? ClubTopicDetailPort.State.running : topicDisplay.state
                        Label {
                            Text(LocalizedStringKey(topicDisplay.cancelled ? "club.topic.status.cancelled" : "club.topic.status." + chipState.rawValue))
                        } icon: {
                            Image(systemName: chipState == .rejected ? "xmark.circle.fill" : "circle.fill")
                                .imageScale(.small)
                                .foregroundStyle(chipState == .rejected ? Color.red : (chipState == .running ? Color.green : Color.secondary))
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("club.topic.status")
                        if let notOnSale = ClubTopicDetailPort.notOnSaleKey(lifecycle: value["lifecycle"].int) {
                            Text(LocalizedStringKey(notOnSale)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    let dateRange = [value["startDate"].text, value["endDate"].text].compactMap { $0?.isEmpty == false ? $0 : nil }
                    if !dateRange.isEmpty {
                        Label { Text(verbatim: dateRange.joined(separator: " ~ ")) } icon: { Image(systemName: "calendar") }
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let verifyMode = value["verifyModeText"].text, !verifyMode.isEmpty {
                        Label { Text(verbatim: verifyMode) } icon: { Image(systemName: "clock") }
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else if logoURL != nil {
                        Label { Text("club.topic.verifyAtStore") } icon: { Image(systemName: "clock") }
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.accessibilityElement(children: .combine)
                // CLB-topic-detail-08 residual (MP wxml:57-59, js:740-747 buildChips): playModeText, then 本场 N 人 only when
                // the page is bound to one session (an activityId) and the stats count is positive.
                let headcount = stats["sessionHeadcount"].int ?? 0
                let playMode = value["playModeText"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !playMode.isEmpty || (scope.activityID != nil && headcount > 0) {
                    HStack(spacing: 12) {
                        if !playMode.isEmpty { Text(verbatim: playMode) }
                        if scope.activityID != nil, headcount > 0 { Text("club.topic.chip.sessionHeadcount \(headcount)") }
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("club.topic.chips")
                }
            }
            .task(id: snapshotGeneration) {
                guard scope.clubID != nil, scope.topicID != nil else { topicStats = nil; return }
                let expected = readContext
                let read = try? await access.read(.topicStats, scope: scope, options: [:]).value
                guard expected == readContext, !Task.isCancelled else { return }
                topicStats = read
            }
            // CLB-G12 rows (编辑主题内容 / 确认终价 / 承接审核) live in the 更多 sheet (CLB-r9-topic-detail-02: one 更多 entry).
            .navigationDestination(item: $topicMoreRoute) { route in MPReviewedPageScreen(page: route.page, query: route.query) }
            // CLB-topic-detail-05 (MP wxml:63-80): 商家 · 报名参与者 · 团码 · 更多 as round actions that open half sheets.
            // 商家 goes to the merchantinfo recruit layer when the stats grant canReviewChapterApplications (MP ROUND4).
            Section {
                ClubTopicQuickActionRow(items: [
                    .init(id: "merchant", titleKey: "club.gov.recruit", systemImage: "storefront") {
                        if PlayerLaunch.merchantCenterEnabled, let topicID = scope.topicID, stats["canReviewChapterApplications"] == .bool(true) { // Lane G
                            topicMoreRoute = .init(page: "pages/topic/merchantinfo/merchantinfo", query: ["topicId": String(topicID), "scope": "CLUB", "open": "merchant"])
                        } else { topicQuickSheet = .merchants }
                    },
                    .init(id: "customer", titleKey: "club.gov.topicCustomers", systemImage: "person.2") { topicQuickSheet = .customers },
                    .init(id: "groupcode", titleKey: "club.topic.quick.groupCode", systemImage: "qrcode") {
                        guard let topicID = scope.topicID else { return }
                        var query = ["topicId": String(topicID)]
                        if let clubID = scope.clubID { query["clubId"] = String(clubID) }
                        if let activityID = scope.activityID { query["activityId"] = String(activityID) }
                        topicMoreRoute = .init(page: "pages/club/group-code/index", query: query)
                    },
                    .init(id: "more", titleKey: "club.topic.quick.more", systemImage: "ellipsis") { topicQuickSheet = .more },
                ])
            }
            .cySheet(item: $topicQuickSheet, onDismiss: {
                if directorEndAfterSheet { directorEndAfterSheet = false; directorEndConfirm = true }
                if let route = topicMoreAfterSheet { topicMoreAfterSheet = nil; topicMoreRoute = route }
            }) { sheet in
                NavigationStack {
                    Group {
                        switch sheet {
                        case .merchants:
                            ClubGovernanceReadView(operation: .recruit, scope: scope, identity: identity, access: access, coordinator: coordinator)
                        case .customers:
                            ClubGovernanceReadView(operation: .topicCustomers, scope: scope, identity: identity, access: access, coordinator: coordinator)
                        case .more:
                            List {
                                Section { link(.topicStats); link(.topicSettings); enrollmentLink(focusTopicID: scope.topicID) }
                                // CLB-topic-detail-05 (MP wxml:454-470): 场次管理 for canManageSessions, then 退出与暂停规则.
                                Section {
                                    if stats["canManageSessions"] == .bool(true), scope.clubID != nil {
                                        NavigationLink {
                                            ClubOpsEventView(scope: .init(clubID: scope.clubID, topicID: scope.topicID), identity: identity, access: access, coordinator: coordinator)
                                        } label: { Label("club.topic.more.sessions", systemImage: "calendar") }
                                            .accessibilityIdentifier("club.topic.more.sessions")
                                    }
                                    NavigationLink { ClubOperatingRulesView() } label: { Label("club.topic.more.rules", systemImage: "list.bullet.rectangle") }
                                        .accessibilityIdentifier("club.topic.more.rules")
                                }
                                // CLB-r9-topic-detail-02 / CLB-G12 (MP topic-detail wxml:426-500): one 更多; 编辑主题内容 (fabu ?id),
                                // 确认终价 while pricing (lifecycle 2, organiser's canDirect), 承接审核 with canReviewChapterApplications.
                                if let topicID = scope.topicID, scope.clubID != nil, canDirect || stats["canReviewChapterApplications"] == .bool(true) {
                                    Section {
                                        if canDirect {
                                            Button("club.director.editTopic") {
                                                openAfterMoreSheet(.init(page: "pages/publish/fabu/index", query: ["id": String(topicID)]))
                                            }
                                        }
                                        if canDirect, value["lifecycle"].int == 2 {
                                            Button("club.director.confirmFinalPrice") {
                                                openAfterMoreSheet(.init(page: "pages/topic/pricing/index", query: ["topicId": String(topicID), "club": "1"]))
                                            }
                                        }
                                        if PlayerLaunch.merchantCenterEnabled, stats["canReviewChapterApplications"] == .bool(true) { // Lane G
                                            Button("club.director.reviewUndertake") {
                                                openAfterMoreSheet(.init(page: "pages/topic/merchantinfo/merchantinfo", query: ["topicId": String(topicID), "scope": "CLUB"]))
                                            }
                                        }
                                    }
                                    .accessibilityIdentifier("club.topic.more")
                                }
                                // CLB-G13b (MP wxml:436-442): 结束活动 for a self-run session the director has taken over.
                                if ClubTopicDetailPort.stateKey(value) == .selfrun, directorActive {
                                    Section {
                                        Button("club.topic.primary.running", role: .destructive) {
                                            directorEndAfterSheet = true
                                            topicQuickSheet = nil
                                        }
                                        .accessibilityIdentifier("club.topic.more.endSession")
                                    }
                                }
                            }
                            .cyPageTitle("club.topic.quick.more")
                        }
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("club.gov.close") { topicQuickSheet = nil } } }
                }
                .cyDomainSheet(detents: [.half, .full])
            }
            // Mini 核销 card: only for running/ended, uncancelled sessions the server granted `canViewVerify`;
            // the counts come from topic-manage-stats. Missing counts render as an em dash.
            if ClubTopicDetailPort.showsVerify(topicDisplay, canViewVerify: stats["canViewVerify"].bool) {
                ClubTopicVerifySummarySection(metrics: ClubTopicDetailPort.verifyMetrics(
                    pending: stats["pendingVerifyCount"].int, verifiedByMe: stats["verifiedByMeCount"].int, headcount: stats["sessionHeadcount"].int),
                    ledger: topicLedger)
            }
            if let reason = value["rejectReason"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                Section("club.topic.rejectReason") { Text(verbatim: reason).foregroundStyle(.red) }
            }
            // CLB-r8-topic-detail-01 (MP wxml:106-125): the 主题 card (cover when present, name, 「N 章 · N 站 · 玩法」, the
            // 剧情已写 chip, 打开剧情与玩法) is the story entry.
            Section {
                NavigationLink { ClubGovernanceStoryView(snapshot: $snapshot, snapshotContext: $snapshotContext, snapshotGeneration: $snapshotGeneration, loading: $loading, failure: $failure, context: readContext, identity: identity, access: access, coordinator: coordinator, reload: { await load() }) } label: {
                    ClubTopicStoryCard(value: value, nodeCount: stats["nodeCount"].int)
                }.accessibilityIdentifier("club.gov.openStory")
            } header: { Text("club.topic.card.title") }
            Section("club.topic.upcoming") {
                let sessions = value["activityList"].array ?? []
                let groupCodePage = ClubGroupCodePage.project(value: value, scope: scope, capability: .init(permissions: snapshot.permissions, scope: scope))
                if sessions.isEmpty { ContentUnavailableView("club.topic.noSessions", systemImage: "calendar") }
                // CLB-topic-detail-07: 接下来 links to event ops (MP 管理场次 → pages/club/event-ops), only when the
                // manage stats grant `canManageSessions` (MP wxml:684-700).
                if scope.clubID != nil, stats["canManageSessions"] == .bool(true) {
                    NavigationLink { ClubOpsEventView(scope: .init(clubID: scope.clubID, topicID: scope.topicID), identity: identity, access: access, coordinator: coordinator) } label: {
                        Label("club.topic.manageSessions", systemImage: "calendar.badge.plus")
                    }.accessibilityIdentifier("club.topic.manageSessions")
                }
                ForEach(Array(sessions.enumerated()), id: \.offset) { _, row in
                    if let id = row["id"].int {
                        let target = ClubGovernanceScope(clubID: scope.clubID, topicID: scope.topicID, activityID: id)
                        let issued = groupCodePage.hidden ? nil : groupCodePage.sessions?.first(where: { $0.id == id })
                        NavigationLink { ClubGovernanceEventView(scope: target, identity: identity, access: access, coordinator: coordinator, groupCodePage: groupCodePage,
                                                                 activityLabel: row["name"].string.map { ClubGroupCodePort.sessionLabel(id: id, name: $0, startDate: row["startDate"].string, startTime: row["startTime"].string) }) } label: {
                            // CLB-topic-detail-15 (MP wxml:134-152): when over who, the headcount as a trailing chip.
                            let when = ClubGroupCodePort.formatStart(date: row["startDate"].string, time: row["startTime"].string)
                            let who = row["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    if !when.isEmpty { Text(verbatim: when).monospacedDigit() }
                                    if !who.isEmpty { Text(verbatim: who).font(when.isEmpty ? .body : .subheadline).foregroundStyle(when.isEmpty ? Color.primary : Color.secondary) }
                                    // CLB-r8-topic-detail-02 (MP wxml:142-148, js:783-785): the eta line is the session's addressName;
                                    // the kind chip stays out because the server sends no session kind (MP kindText '').
                                    if let eta = row["addressName"].string?.trimmingCharacters(in: .whitespacesAndNewlines), !eta.isEmpty {
                                        Text(verbatim: eta).font(.subheadline).foregroundStyle(.tertiary)
                                    }
                                    if when.isEmpty && who.isEmpty { Text("club.gov.eventID \(id)") }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if let issued { Text(verbatim: issued.headcount.displayText).foregroundStyle(.secondary).monospacedDigit() }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        // Mini-program club/group-code: pick the session, then issue. One tap here; the reviewed
                        // command still checks check-in permission and the provider gate before any request.
                        if let issued { edit(.issueGroupCode, scope: target).accessibilityValue(Text(verbatim: issued.headcount.displayText)) }
                        SharedRunControlEntry(activityID: id)
                        if let startDate = row["startDate"].string, ClubOpsTimeRequest.date(startDate) != nil {
                            NavigationLink("context.ops.title") {
                                ClubOpsTimeView(activityID: id, original: startDate, owner: opsTimeFactory?(id)) { Task { await load() } }
                            }.accessibilityIdentifier("club.context.editOps.\(id)")
                        }
                    }
                }
            }
            ClubTerminalSessionEntry(snapshot: snapshot, context: terminalContext, snapshotGeneration: terminalGeneration,
                host: terminalSessions, access: access, sourceIsCurrent: {
                    !loading && self.snapshot == snapshot && snapshotContext == terminalContext && readContext == terminalContext &&
                    snapshotGeneration == terminalGeneration && identity == access.identity && scenePhase == .active
                }, presentation: terminalPresentation)
            // CLB-G13 (MP topic-detail wxml:160-500): with an activityId the topic detail carries the director block
            // (K8 banner, 准备总览, director tools, 排行榜), only where topic-manage-stats grants canDirect.
            if let activityID = scope.activityID, canDirect { ClubTopicDirectorEmbeddedMount(activityID: activityID, topicID: scope.topicID) }
            Section { NavigationLink("context.rules.title") { ClubOperatingRulesView() }.accessibilityIdentifier("club.context.openRules") }
            // CLB-topic-detail-02: the phase primary is the pinned footer (`topicPrimaryFooter`), not the last row.
        } else if operation == .audienceCounts {
            let notifyPage = ClubNotifyPage.project(value: value, capability: .init(permissions: snapshot.permissions, scope: scope))
            Section {
                if let rows = try? ClubOpsNotifyPresentation.audienceRows(value) { ClubOpsNotifyAudienceRows(rows: rows) }
                else { ClubGovernanceFactRows(value: value["counts"], fields: ["ALL_MEMBERS", "ADMINS", "REGISTERED", "WAITLIST", "NO_SHOW", "INACTIVE"], showUnknown: true) }
                if !notifyPage.hidden, notifyPage.broadcastOffered { edit(.sendNotification) }
            } header: { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.audience.title") }
            .accessibilityValue(Text(verbatim: notifyPage.hidden ? ClubNotifyPage.unknownDisplay : (notifyPage.rows?.map(\.count.displayText).joined(separator: " ") ?? ClubNotifyPage.unknownDisplay)))
        } else if operation == .dissolutionBlockers {
            Section("club.gov.deposits") { dataRows(value["deposits"].array ?? []) }
            Section("club.gov.settlements") { dataRows(value["settlements"].array ?? []) }
            edit(.dissolve, role: .destructive)
        } else if operation == .settlement {
            let settlementSummary = try? ClubOpsSettlementSummary(value: value, scope: scope)
            if let settlementSummary, settlementSummary.hasTopics { ClubOpsSettlementSummaryCard(summary: settlementSummary) }
            // CLB-settlement-01: the same /settlement/summary carries F-16 sessions; show 各场次结算 here too.
            if let sessions = ClubSettlementSummaryView(governanceValue: value)?.sessions { ClubSettlementSessionsSection(sessions: sessions) }
            // WP-01: cy-club-direct-ledger and the owner's 个人收款 entry (mini-program openPayoutReceiver).
            if let clubID = scope.clubID, clubID > 0 {
                ClubDirectLedgerSection(scope: .club(clubID: clubID, topicID: nil))
                if settlementSummary?.isOwner == true { ClubPayoutReceiverLink(clubID: clubID) }
            }
            if let target = ClubOwnerFundsTarget(snapshot: snapshot, context: readContext) {
                let sourceContext = readContext, sourceGeneration = snapshotGeneration, sourceNamespace = access.storageNamespace
                ClubOwnerFundsSection(target: target, access: access, context: ownerFunds, sourceGeneration: sourceGeneration,
                    sourceIsCurrent: {
                        snapshotContext == sourceContext && readContext == sourceContext && snapshotGeneration == sourceGeneration &&
                        generation == sourceGeneration && identity == access.identity && sourceNamespace == access.storageNamespace
                    }, workflow: ownerFundsParent.workflow, parent: ownerFundsParent,
                    currentSource: { ownerFundsSource }, otherPresented: { settlementReturn.retainsChild }).id(sourceContext)
            } else if let settlementSummary, !settlementSummary.isOwner, settlementSummary.hasTopics {
                ClubOpsSettlementOwnerOnlyWithdraw()
            }
            if let presentation = try? ClubSettlementDetailPresentation(snapshot: snapshot, context: readContext) {
                let sourceContext = readContext, sourceGeneration = snapshotGeneration, sourceNamespace = access.storageNamespace
                let source = ClubSettlementReturnOwner.Source(presentation: presentation, context: sourceContext,
                    generation: sourceGeneration, namespace: sourceNamespace)
                Section {
                ClubSettlementRows(presentation: presentation, context: sourceContext, snapshotGeneration: sourceGeneration,
                    namespace: sourceNamespace, identity: identity, access: access,
                    sourceIsCurrent: {
                        snapshotContext == sourceContext && readContext == sourceContext && snapshotGeneration == sourceGeneration &&
                        generation == sourceGeneration && identity == access.identity && sourceNamespace == access.storageNamespace
                    }, source: source, owner: settlementReturn, currentSource: { settlementSource }, active: { scenePhase == .active })
                    .disabled(ownerFundsParent.retainsContact || ownerFundsParent.workflow.loading)
                } header: { Text("clubOps.settlement.topicsHeader", tableName: "ClubOpsCustomer") } footer: { if !presentation.records.isEmpty { ClubOpsSettlementFootnote() } }
            } else { Text("club.gov.malformed").accessibilityIdentifier("club.settlementDetail.malformed") }
        } else if operation == .feed {
            if let feed = try? ClubFeedPresentation(snapshot: snapshot) {
                if feed.posts.isEmpty {
                    if feed.clubCount == 0 {
                        Text("club.gov.noJoinedClubs").accessibilityIdentifier("club.feed.emptyNoClubs")
                    } else {
                        Text("club.gov.empty").accessibilityIdentifier("club.feed.emptyPosts")
                    }
                }
                ForEach(feed.posts) { post in
                    let target = feedClubRoute(post)
                    ClubGovernanceFeedPostView(post: post, mediaScope: feedMediaScope, imageReader: feedContext.imageReader ?? RetainedPublicImageReader(),
                        openClub: target.map { route in { selectFeedClub(route) } })
                }
            } else { Text("club.gov.malformed").accessibilityIdentifier("club.feed.malformed") }
        } else if operation == .nodeAnswer {
            ClubNodeAnswerContent(value: value)
        } else if operation == .customer {
            let customerPage = ClubCustomerDetailPage.project(value: value, memberID: scope.memberID, capability: .init(permissions: snapshot.permissions, scope: scope))
            if let detail = customerPage.detail ?? (try? ClubOpsCustomerDetailPresentation(value: value, memberID: scope.memberID)) {
                ClubOpsCustomerDetailContent(detail: detail, page: customerPage, topicAction: { record in
                    customerTopicRoute(record.source).map { target in (id: target.topicID, open: { selectCustomerTopic(target) }) }
                }, editButton: detail.canEdit ? AnyView(edit(.saveCustomer, seed: ["remark": value["remark"], "tags": value["tags"]]).accessibilityLabel(Text("club.gov.action.saveCustomer"))) : nil)
            } else if !customerPage.hidden, let metrics = customerPage.metrics {
                Section {
                    ClubOpsCustomerMetricTile(value: metrics.arrived, label: "clubOps.customer.arrived")
                    ClubOpsCustomerMetricTile(value: metrics.pending, label: "clubOps.customer.pending")
                    ClubOpsCustomerMetricTile(value: metrics.refunded, label: "clubOps.customer.refunded")
                    if let paid = customerPage.paidAmount?.displayText {
                        Text(verbatim: paid).monospacedDigit().accessibilityIdentifier(ClubCustomerDetailPage.Accessibility.paidAmount)
                    }
                }
            } else { Text("club.gov.malformed").accessibilityIdentifier("clubOps.customer.malformed") }
        } else if operation == .notificationStatus, let campaign = try? ClubOpsNotifyCampaign(value: value) {
            let delivery = ClubNotifyDeliveryPage.project(value: value, capability: .init(permissions: snapshot.permissions, scope: scope))
            Section { ClubOpsNotifyCampaignRows(campaign: campaign, delivery: delivery.hidden ? nil : delivery) } header: { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.status.title") }
            if campaign.canRetryFailed {
                // CLB-notify-09/-10 (fix-r3-club-b): the retry button itself reads 只重试失败项 (fragment value of
                // club.gov.action.retryNotification), so the separate footnote is gone.
                Text("club.gov.deliveryPending").cyText(.meta).foregroundStyle(.secondary)
                if delivery.retryOffered { edit(.retryNotification) }
            }
        } else {
            if operation == .customers {
                if let list = try? ClubOpsCustomerListPresentation(value: value) {
                    let pageFilters = snapshotCustomerFilters ?? customerFilters
                    ClubOpsCustomerListContent(first: list, filtered: snapshotCustomerFilters?.isFiltered == true, pager: customerPager,
                        readPage: { pageNum in
                            try await access.read(.customers, scope: scope, options: [
                                "filter": .string(pageFilters.filter), "keyword": .string(pageFilters.keyword),
                                "pageNum": .integer(pageNum), "pageSize": .integer(ClubOpsCustomerListPresentation.pageSize)]).value
                        }) { id in
                        AnyView(ClubGovernanceReadView(operation: .customer, scope: .init(clubID: scope.clubID, memberID: id), identity: identity, access: access, coordinator: coordinator))
                    }
                } else { Text("club.gov.malformed").accessibilityIdentifier("clubOps.customers.malformed") }
            } else if operation == .checkin {
                let page = ClubCheckinDetailPage.bind(clientCapabilityPresent: access.isConfigured, loading: loading, failure: failure, value: value)
                // CLB-checkin-detail-03 (fix-r3-club-b): an error phase is one full-page state (drawn by the rail view), no rows.
                let isErrorPhase: Bool = { if case .error(_)? = page.phase { return true }; return false }()
                if page.showsContent, !isErrorPhase { ClubCheckinDetailRows(value: checkinRowsValue(value, page)) }
            } else {
                ClubGovernanceFactRows(value: value, fields: ClubGovernanceFactRows.summaryFields)
                if operation == .series {
                    ClubOpsEventSeriesHeader(empty: (value.array ?? []).isEmpty, namesKey: readContext) { context in
                        await seriesTopicNames.load(context: context, access: access)
                    }
                }
                if operation != .series || !(value.array ?? []).isEmpty {
                    dataRows(ClubOpsEventAccess.focusFirst(value.array ?? value["items"].array ?? value["rows"].array ?? value["topics"].array ?? value["nodes"].array ?? [],
                                                           topicID: operation == .eventTopics ? scope.topicID : nil))
                }
            }
            if operation == .customers, !loading, failure == nil,
               value["items"].array?.isEmpty == true, customerFilters.isFiltered,
               snapshotCustomerFilters == customerFilters {
                let sourceContext = readContext, sourceGeneration = snapshotGeneration
                let sourceFilters = customerFilters
                Button("club.gov.customers.showAll") {
                    clearCustomerFilters(source: snapshot, context: sourceContext,
                                         sourceGeneration: sourceGeneration, filters: sourceFilters)
                }.buttonStyle(.borderless)
                    .accessibilityIdentifier("club.gov.customers.clearFilters")
            }
            if operation == .topicSettings {
                if value["canManage"] == .bool(true) { edit(.saveTopicSettings, seed: ["coopOpen": value["coopOpen"], "pinned": value["pinned"], "memberOnly": value["memberOnly"]]); edit(.endTopic) }
                Section("club.gov.chapters") { ForEach(Array((value["chapters"].array ?? []).enumerated()), id: \.offset) { _, row in
                    ClubGovernanceFactRows(value: row, fields: ["name", "category", "recruiting", "merchantCount", "finishTime"])
                    if let id = row["chapterId"].int, value["canManage"] == .bool(true) {
                        let target = ClubGovernanceScope(clubID: scope.clubID, topicID: scope.topicID, chapterID: id)
                        edit(.chapterRecruit, scope: target); edit(.chapterFinish, scope: target)
                    }
                } }
            }
            if operation == .topicCustomers {
                ClubGovernanceFactRows(value: value, fields: ["soldCount", "pendingCount", "verifiedCount"], showUnknown: true)
                ForEach(Array((value["sessions"].array ?? []).enumerated()), id: \.offset) { _, session in
                ClubGovernanceFactRows(value: session, fields: ["timeText", "name"])
                // CLB-topic-detail-10: MP cli-row (avatar initial, masked phone, 拨号 when callable, status chip).
                let rows = session["rows"].array ?? []
                if rows.isEmpty { ContentUnavailableView("club.gov.empty", systemImage: "tray") }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    ClubTopicCustomerRow(row: row, sessionTime: session["timeText"].string)
                }
            } }
            // CLB-topic-detail-10 (MP topic-detail wxml:609-625, js:1094-1100): 定向广播 under the participants when the
            // director runs this session; the projection offers BROADCAST or the row is dimmed with the reason.
            // r10: the disabled row stays visible and dimmed; MP `broadcastDisabledText` (wxml:621-624) sits in the footer.
            if operation == .topicCustomers, let projection = sessionDirector?.projection {
                let canBroadcast = projection.availableActions.contains(PlayDirectorAction.broadcast.rawValue)
                Section {
                    Button { opensDirectorBroadcast = true } label: {
                        Label("club.topic.broadcast", systemImage: "megaphone")
                    }
                    .disabled(!canBroadcast)
                    .accessibilityIdentifier("club.topic.broadcast")
                } footer: {
                    if !canBroadcast {
                        Text("club.topic.broadcast.disabled \(appLocalized(String.LocalizationValue(stringLiteral: Self.sessionStatusKey(projection.status)), locale: locale))")
                            .accessibilityIdentifier("club.topic.broadcast.disabledReason")
                    }
                }
            }
            if operation == .checkin, let clubID = scope.clubID, let registrationID = scope.registrationID,
               let target = try? ClubOwnerRefundTarget(clubID: clubID, registrationID: registrationID) {
                let checkinPage = ClubCheckinDetailPage.bind(clientCapabilityPresent: access.isConfigured, loading: loading, failure: failure, value: value)
                let checkinKind: ClubCheckinRail.StateKind? = {
                    if case .error(let kind) = checkinPage.phase { return kind }
                    return nil
                }()
                if checkinPage.showsContent {
                    ClubCheckinRailView(rail: .init(railStep: value["railStep"], statusCode: value["statusCode"]), stateKind: checkinKind,
                                        onReload: { Task { await load() } })
                }
                // CLB-checkin-detail-01: the entry follows server canRefund; dispatch stays behind the coordinator's TEST-only gate.
                Section {
                    ClubOwnerRefundPanel(target: target, identity: identity, sourceCanRefund: checkinPage.showsRefundAction && value["canRefund"] == .bool(true), onReadback: { Task { await load() } })
                }
            }
            if operation == .registrations { enrollmentLink(focusTopicID: scope.topicID) }
            if operation == .seriesDetail, seriesUpdateReturn.conflictNotice == readContext { ClubOpsEventSeriesConflictNotice() }
            if operation == .seriesDetail { edit(.updateSeries, seed: value.object ?? [:]); link(.occurrences) }
            if operation == .occurrenceStatus {
                ClubOpsEventOccurrenceStatusRows(value: value, activityID: scope.activityID)
                if let status = value["occurrenceStatus"].string {
                    LabeledContent("club.gov.field.status") { Text(verbatim: status) }
                        .accessibilityIdentifier("club.cancel.readback.status")
                }
                if value["activityCancelled"] == .bool(false), occurrenceCancellationReturn.readback == nil { edit(.cancelOccurrence) }
            }
            if operation == .cases { edit(.report); edit(.appeal) }
            if operation == .bans { link(.members) }
            if operation == .notificationStatus && (value["failedCount"].int ?? 0) > 0 { Text("club.gov.deliveryPending"); edit(.retryNotification) }
        }
    }
    /// CLB-topic-detail-02 (MP wxml:322-341 `cy-bottom-bar`): the topic page's one primary stays pinned above the
    /// home indicator on a system bar material while the page scrolls. Only a loaded, current topic overview shows it.
    @ViewBuilder private var topicPrimaryFooter: some View {
        if operation == .topicOverview, let snapshot, snapshotContext == readContext, identity == access.identity {
            let stats = topicStats ?? .null
            let sessions = snapshot.value["activityList"].array ?? []
            let state = ClubTopicDetailPort.stateKey(snapshot.value)
            if topicPrimaryPlan(state: state, stats: stats, sessions: sessions) != ClubTopicDetailPort.Primary.none {
                // CLB-r10-nat-topic-detail-03: a `.borderedProminent` primary in the safe-area inset on the system bar
                // material; no drawn Divider overlay.
                topicPrimary(state: state, stats: stats, sessions: sessions)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
    }
    /// CLB-topic-detail-07 (MP topic-detail wxml:684-700): 选择场次, one row per session (when over who); a pick closes
    /// the sheet and opens that session's event ops (MP event-ops?activityId=).
    @ViewBuilder private var topicSessionPicker: some View {
        let sessions = (snapshot?.value["activityList"].array ?? []).filter { $0["id"].int != nil }
        NavigationStack {
            List(Array(sessions.enumerated()), id: \.offset) { _, row in
                if let id = row["id"].int {
                    let when = ClubGroupCodePort.formatStart(date: row["startDate"].string, time: row["startTime"].string)
                    let who = row["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    Button {
                        sessionPickerVisible = false
                        pickedSession = ClubGovernanceScope(clubID: scope.clubID, topicID: scope.topicID, activityID: id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            if !when.isEmpty { Text(verbatim: when).monospacedDigit() }
                            if !who.isEmpty { Text(verbatim: who).font(.subheadline).foregroundStyle(.secondary) }
                            if when.isEmpty && who.isEmpty { Text("club.gov.eventID \(id)") }
                        }
                        .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel(Text("club.topic.sessionPicker.a11y \(when.isEmpty ? who : when)"))
                    .accessibilityIdentifier("club.topic.sessionPicker.\(id)")
                }
            }
            .navigationTitle(Text("club.topic.sessionPicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { sessionPickerVisible = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    /// CLB-topic-detail-05 (MP `goLedger` js:870-873): 台账 / 核销记录 open the club's 报名名册 focused on this topic.
    private var topicLedger: AnyView? {
        guard let clubID = scope.clubID, let topicID = scope.topicID else { return nil }
        return AnyView(ClubEnrollmentView(clubID: clubID, focusTopicID: topicID, identity: identity, access: access, coordinator: coordinator))
    }
    private func openAfterMoreSheet(_ route: ClubTopicMoreRoute) {
        topicMoreAfterSheet = route
        topicQuickSheet = nil
    }
    /// CLB-G13b: the director coordinator for this page's `activityId`, when the host is mounted.
    private var directorModel: PlayDirectorCoordinator? {
        guard operation == .topicOverview else { return nil }
        return sessionDirector
    }
    /// CLB-topic-detail-10: the same retained coordinator, read from the 报名参与者 sheet too.
    private var sessionDirector: PlayDirectorCoordinator? {
        guard let activityID = scope.activityID, let directorHost else { return nil }
        return directorHost.coordinator(activityID)
    }
    /// MP director.js `statusText`: session status → its label key (unknown codes → 状态待确认).
    static func sessionStatusKey(_ status: String) -> String {
        let code = status.uppercased()
        let known: Set<String> = ["NOT_PREPARED", "DRAFT", "PREPARING", "READY", "RUNNING", "FINISHED", "CANCELLED"]
        return "club.director.sessionStatus." + (known.contains(code) ? code : "unknown")
    }
    /// MP `_directorActivityId` (topic-detail js:587-592): the page was opened on one session and the director runs it.
    private var directorActive: Bool { directorModel != nil }
    /// MP `onPrepareSession` / `onStartSession` / `onFinishSession` (director.js:1431-1438): one command at the
    /// projection's revision; the projection refuses what the server does not offer (当前不能结束活动).
    private func sendDirector(_ action: PlayDirectorAction) {
        guard let model = directorModel, let projection = model.projection,
              let command = try? PlayDirectorCommand(activityID: model.activityID, nodeID: nil,
                                                     expectedRevision: projection.revision, action: action, payload: [:]) else { return }
        Task {
            await model.submit(command)
            await load()
        }
    }
    private func topicPrimaryPlan(state: ClubTopicDetailPort.State, stats: ClubGovernanceValue, sessions: [ClubGovernanceValue]) -> ClubTopicDetailPort.Primary {
        let single = sessions.count == 1 ? sessions[0]["id"].int : nil
        return ClubTopicDetailPort.primary(state: state, directorActive: directorActive, canDirect: stats["canDirect"] == .bool(true),
            canManageSessions: stats["canManageSessions"] == .bool(true), hasClub: scope.clubID != nil,
            sessionCount: sessions.count, singleSessionHasValidID: single != nil)
    }
    /// CLB-topic-detail-02: one primary per phase (MP topic-detail onPrimary / resolvePrimary). Each phase
    /// opens the native screen that already owns it; the director itself stays in the session screen.
    @ViewBuilder private func topicPrimary(state: ClubTopicDetailPort.State, stats: ClubGovernanceValue, sessions: [ClubGovernanceValue]) -> some View {
        let single = sessions.count == 1 ? sessions[0]["id"].int : nil
        let plan = topicPrimaryPlan(state: state, stats: stats, sessions: sessions)
        let sessionScope = single.map { ClubGovernanceScope(clubID: scope.clubID, topicID: scope.topicID, activityID: $0) }
        let opsScope = ClubGovernanceScope(clubID: scope.clubID, topicID: scope.topicID)
        Group {
            switch plan {
            case .none:
                EmptyView()
            case .chooseSession where sessions.compactMap({ $0["id"].int }).count > 1:
                // CLB-topic-detail-07: several sessions → pick one first (MP sessionPick sheet), then its event ops.
                Button { sessionPickerVisible = true } label: { Text("club.topic.primary.chooseSession").frame(maxWidth: .infinity) }
                    .accessibilityIdentifier("club.topic.primary")
            case .chooseSession, .openSession:
                NavigationLink { ClubOpsEventView(scope: opsScope, identity: identity, access: access, coordinator: coordinator) } label: {
                    Text(plan == .chooseSession ? "club.topic.primary.chooseSession" : "club.topic.primary.openSession").frame(maxWidth: .infinity)
                }.accessibilityIdentifier("club.topic.primary")
            case .action(let phase):
                switch phase {
                case .reviewing:
                    Button {} label: { Text(LocalizedStringKey(phase.primaryKey)).frame(maxWidth: .infinity) }.disabled(true)
                        .accessibilityIdentifier("club.topic.primary")
                case .ended:
                    if let clubID = scope.clubID {
                        NavigationLink { ClubGovernanceReadView(operation: .settlement, scope: .init(clubID: clubID), identity: identity, access: access, coordinator: coordinator) } label: {
                            Text(LocalizedStringKey(phase.primaryKey)).frame(maxWidth: .infinity)
                        }.accessibilityIdentifier("club.topic.primary")
                    }
                case .confirmed, .preparing, .running:
                    if directorActive, let model = directorModel {
                        // CLB-G13b (MP onPrimary js:880-897): 开始准备 → PREPARE, 开始活动 → START, 结束活动 → the confirm.
                        Button(LocalizedStringKey(phase.primaryKey)) {
                            if phase == .running { directorEndConfirm = true } else { sendDirector(phase == .confirmed ? .prepare : .start) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.phase != "ready")
                        .accessibilityIdentifier("club.topic.primary")
                    } else if let sessionScope {
                        NavigationLink { ClubGovernanceEventView(scope: sessionScope, identity: identity, access: access, coordinator: coordinator) } label: {
                            Text(LocalizedStringKey(phase.primaryKey))
                        }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("club.topic.primary")
                    } else {
                        NavigationLink { ClubOpsEventView(scope: opsScope, identity: identity, access: access, coordinator: coordinator) } label: {
                            Text(LocalizedStringKey(phase.primaryKey))
                        }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("club.topic.primary")
                    }
                case .selfrun:
                    if let sessionScope {
                        NavigationLink { ClubGovernanceEventView(scope: sessionScope, identity: identity, access: access, coordinator: coordinator) } label: {
                            Text(LocalizedStringKey(phase.primaryKey)).frame(maxWidth: .infinity)
                        }.accessibilityIdentifier("club.topic.primary")
                    } else {
                        NavigationLink { ClubOpsEventView(scope: opsScope, identity: identity, access: access, coordinator: coordinator) } label: {
                            Text(LocalizedStringKey(phase.primaryKey)).frame(maxWidth: .infinity)
                        }.accessibilityIdentifier("club.topic.primary")
                    }
                case .rejected:
                    // CLB-topic-detail-02 (MP onPrimary → goEditTopic, js:886, 1303): 修改并重新提交 opens the topic
                    // editor by id (pages/publish/fabu?id=), the native ProjectEditView behind the MP route.
                    if let topicID = scope.topicID {
                        NavigationLink { MPReviewedPageScreen(page: "pages/publish/fabu/index", query: ["id": String(topicID)]) } label: {
                            Text(LocalizedStringKey(phase.primaryKey)).frame(maxWidth: .infinity)
                        }.accessibilityIdentifier("club.topic.primary")
                    }
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    @ViewBuilder private func dataRows(_ rows: [ClubGovernanceValue]) -> some View {
        if rows.isEmpty {
            // WP-02: an empty editions list asks the server why (`edition-empty-reason.js`).
            if operation == .editions, let clubID = scope.clubID, clubID > 0 { ClubEditionEmptyReasonView(clubID: clubID, reload: { Task { await load() } }) }
            else { ContentUnavailableView("club.gov.empty", systemImage: "tray") }
        }
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            Section {
                if let target = customerTopicRoute(row) {
                    Button { selectCustomerTopic(target) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ClubGovernanceFactRows(value: row, fields: ClubGovernanceFactRows.summaryFields)
                            Label("topic.detail", systemImage: "chevron.right.circle")
                        }
                    }.accessibilityIdentifier("club.gov.customer.topic.\(target.topicID)")
                } else if let target = leaderboardMemberRoute(row) {
                    // Round 4 image parity (MP detail wxml:323 `item.avatar || d_profile.png`): the member's avatar.
                    ClubMPAvatar(url: QuestifyCardArtwork.safeURL(row["avatar"].string), name: row["nickname"].string ?? "", size: .sm)
                    ClubGovernanceFactRows(value: row, fields: ClubGovernanceFactRows.summaryFields, showUnknown: true)
                    Button { selectLeaderboardMember(target) } label: {
                        Label("social.profile", systemImage: "person.crop.circle")
                    }.buttonStyle(.borderless)
                        .accessibilityIdentifier("club.gov.leaderboard.profile.\(target.memberID)")
                } else if operation == .series, let id = row["id"].int,
                          let item = snapshot.map({ ClubOpsEventSeriesList(value: $0.value, topicNames: seriesTopicNames.names(readContext)) })?.rows.first(where: { $0.id == id }) {
                    ClubOpsEventSeriesRowView(row: item)
                } else {
                    ClubGovernanceFactRows(value: row, fields: ClubGovernanceFactRows.summaryFields, showUnknown: operation == .leaderboard || operation == .occurrences)
                }
                if [.topics, .eventTopics].contains(operation), let id = row["id"].int {
                    let target = ClubGovernanceScope(clubID: scope.clubID, topicID: id)
                    link(.topicOverview, target)
                    if operation == .eventTopics { edit(.createSeries, scope: target) }
                }
                if operation == .series, let id = row["id"].int {
                    let target = ClubGovernanceScope(clubID: scope.clubID, topicID: row["topicId"].int, seriesID: id)
                    link(.seriesDetail, target)
                    if let source = occurrenceSource(seriesID: id) {
                        ClubSeriesOccurrenceBrowser(source: source, access: access, host: seriesOccurrences, model: seriesOccurrences.model,
                            currentSource: { occurrenceSource(seriesID: id) }, active: { scenePhase == .active },
                            reload: { Task { await loadSeriesOccurrencesIfNeeded() } })
                    }
                }
                if operation == .occurrences, let id = row["activityId"].int {
                    NavigationLink { ClubGovernanceEventView(scope: .init(clubID: scope.clubID, topicID: scope.topicID, activityID: id), identity: identity, access: access, coordinator: coordinator) } label: { Text("club.gov.eventID \(id)") }
                }
                if operation == .members, let id = row["memberId"].int, row["isOwner"] == .bool(false) {
                    if snapshot?.permissions?.canGovernMembers == true { edit(.ban, seed: ["targetMemberId": .integer(id)]) }
                    if snapshot?.permissions?.roleCodes.contains("CLUB_OWNER") == true { edit(.transferOwner, seed: ["targetMemberId": .integer(id)]) }
                }
                if operation == .bans, row["sourceType"] == .string("CLUB"), row["status"] == .string("ACTIVE") { edit(.unban, seed: ["banId": row["id"], "version": row["version"]]) }
                if operation == .editions, let topicID = row["topicId"].int {
                    let target = ClubGovernanceScope(clubID: scope.clubID, topicID: topicID)
                    edit(.reportHours, scope: target); edit(.submitEvidence, scope: target); Text("club.gov.compensationGate")
                }
            }
        }
    }
}

struct ClubGovernanceEventView: View {
    let scope: ClubGovernanceScope
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    var groupCodePage: ClubGroupCodePage? = nil
    /// CLB-roles-02: 「活动名 · 开始时间」 for the session role page; nil shows 未命名.
    var activityLabel: String? = nil
    var body: some View {
        List {
            NavigationLink { ClubOpsEventView(scope: scope, identity: identity, access: access, coordinator: coordinator) } label: {
                Label {
                    Text("clubOpsEvent.entry.event", tableName: "ClubOpsEvent")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: { Image(systemName: "person.crop.circle.badge.checkmark") }
            }.accessibilityIdentifier("clubOpsEvent.open.event")
            ForEach([ClubGovernanceRead.roster, .occurrenceStatus, .roles, .audienceCounts, .topicStats], id: \.rawValue) { operation in
                // Original role approval and journal own exactly club + optional activity.
                let target = operation == .roles ? ClubGovernanceScope(clubID: scope.clubID, activityID: scope.activityID) : scope
                NavigationLink {
                    if operation == .audienceCounts {
                        // CLB-notify-01: 通知本场成员 opens the composer for this session (MP notify?clubId&activityId).
                        ClubGovernanceCommandForm(route: .init(operation: .sendNotification, scope: .init(clubID: scope.clubID, activityID: scope.activityID)),
                                                  identity: identity, access: access, coordinator: coordinator)
                    } else {
                        ClubGovernanceReadView(operation: operation, scope: target, identity: identity, access: access, coordinator: coordinator)
                            .environment(\.clubRoleActivityLabel, activityLabel)
                    }
                } label: {
                    Label(LocalizedStringKey("club.gov." + operation.rawValue), systemImage: "calendar")
                }
            }
            if let activity = scope.activityID, activity > 0,
               groupCodePage.map({ !$0.hidden && $0.sessions?.contains(where: { $0.id == activity }) == true }) ?? true {
                // CLB-group-code-04 (fix-r3-club-b round 3): the session label rides in the environment, not the command.
                NavigationLink { ClubGovernanceCommandForm(route: .init(operation: .issueGroupCode, scope: scope), identity: identity, access: access, coordinator: coordinator)
                    .environment(\.clubRoleActivityLabel, activityLabel) } label: {
                    Label("club.gov.action.issueGroupCode", systemImage: "qrcode")
                }
            }
        }
        .cyPageTitle("club.gov.events")
    }
}

/// Route/play display is sourced only from the already-authorized topic projection.
/// cmsMemberTemplate IDs remain personal-template IDs; answers keep their own .nodeAnswer read.
@MainActor struct ClubGovernanceStoryView: View {
    @Binding var snapshot: ClubGovernanceSnapshot?
    @Binding var snapshotContext: ClubGovernanceReadContext?
    @Binding var snapshotGeneration: UInt64
    @Binding var loading: Bool
    @Binding var failure: ClubGovernanceFailure?
    let context: ClubGovernanceReadContext
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator
    let reload: () async -> Void
    @Environment(\.clubStoryTemplates) private var templates
    /// CLB-topic-story-05: set only on a merchant link (scope, no clubId).
    @Environment(\.clubStoryHostAnswer) private var hostAnswer
    @Environment(\.locale) private var locale
    @State private var tab: ClubStoryTab = .route
    @State private var selectedChapter = 0
    @State private var storyExpanded = false
    @State private var selectedTemplate: ClubStoryTemplateSelection?
    @State private var selectedAnswer: ClubStoryAnswerRoute?
    @State private var answerSheetTarget: ClubStoryAnswerRoute?
    /// CLB-topic-story-03: the answer sheet is titled 答案 · <node name>.
    @State private var answerSheetName: String?
    @State private var hostAnswerTarget: ClubStoryHostAnswerTarget?
    @State private var storyToastMessage: String?
    @State private var mediaScope = UUID()

    private var sourceIsCurrent: Bool {
        identity?.isSignedIn == true && identity == access.identity && access.isConfigured &&
        snapshotContext == context && context.viewerRevision == templates.viewerRevision &&
        context.authorizationGeneration == access.authorizationGeneration &&
        context.accessIdentity == ObjectIdentifier(access) && context.readerIdentity == templates.readerIdentity
    }
    private var presentation: ClubStoryPresentation? {
        guard sourceIsCurrent, let snapshot else { return nil }
        // A club snapshot ignores the host scope; a clubless (merchant) snapshot needs it (CLB-topic-story-05).
        return try? ClubStoryPresentation(snapshot: snapshot, hostScope: snapshot.scope.clubID == nil ? hostAnswer.scope : nil)
    }
    private var sourceRevision: ClubStorySourceRevision {
        .init(snapshot: snapshot, context: context, snapshotGeneration: snapshotGeneration,
              sourceIsCurrent: sourceIsCurrent, viewerRevision: templates.viewerRevision,
              readerScope: templates.readerScope, destinationAvailable: templates.isAvailable)
    }
    private var reloadContext: ClubGovernanceReadContext {
        .init(operation: context.operation, scope: context.scope, identity: context.identity,
              viewerRevision: templates.viewerRevision, authorizationGeneration: context.authorizationGeneration,
              readerIdentity: context.readerIdentity, accessIdentity: context.accessIdentity)
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        List {
            // CLB-topic-story-07 (parity r2): inline bar title (MP nav-bar title), no hero in the content.
            if identity?.isSignedIn != true || identity != access.identity {
                Text("club.gov.signedOut").accessibilityIdentifier("club.story.signedOut")
            } else if loading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("club.story.loading"))
                    .accessibilityIdentifier("club.story.loading")
            } else if let failure {
                // CLB-topic-story-07: one failure state with its own 重试; pull-to-refresh covers the rest.
                ContentUnavailableView {
                    Label { Text("club.story.failed").accessibilityIdentifier("club.story.failure") } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(LocalizedStringKey(failure.localizationKey))
                } actions: {
                    Button("action.retry") { Task { await reload() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("club.story.refresh")
                }
                    .disabled(loading)
            } else if let presentation {
                Picker("club.story.sections", selection: $tab) {
                    Text("club.story.route").tag(ClubStoryTab.route).accessibilityIdentifier("club.story.tab.route")
                    Text("club.story.play").tag(ClubStoryTab.play).accessibilityIdentifier("club.story.tab.play")
                }.pickerStyle(.segmented).labelsHidden().accessibilityIdentifier("club.story.tabs")
                // Mini topic-story `story-aigc` (P0-14): explicit generative-AI label when publishMode is ai_simple.
                if snapshot?.value["publishMode"].string?.trimmingCharacters(in: .whitespaces).lowercased() == "ai_simple" {
                    Label { Text("story.aigc", tableName: "SocialParity") } icon: { Image(systemName: "sparkles") }
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("club.story.aigc")
                }
                if presentation.chapters.isEmpty {
                    // CLB-topic-story-06 (MP topic-story wxml:56): no chapters reads 暂无路线.
                    ClubStoryEmptyState(title: "club.story.noRoute", detail: "club.story.noChapters")
                } else if tab == .route {
                    ForEach(presentation.chapters) { chapter in
                        Section {
                            if chapter.stops.isEmpty {
                                ClubStoryEmptyState(title: "club.story.noStops", detail: "club.story.awaitingStops")
                            } else {
                                ForEach(chapter.stops) { stop in
                                    ClubStoryStopCard(stop: stop, imageReader: templates.imageReader)
                                        .id("\(mediaScope).\(stop.id)")
                                }
                            }
                        } header: { ClubStoryChapterHeader(chapter: chapter) }
                    }
                } else {
                    chapterPicker(presentation.chapters)
                    if let chapter = presentation.chapters.first(where: { $0.id == selectedChapter }) ?? presentation.chapters.first {
                        playContent(chapter)
                    }
                }
            } else {
                Text("club.story.sourceUnavailable").accessibilityIdentifier("club.story.sourceUnavailable")
            }
        }
        .cyPageTitle("club.gov.story")
        .accessibilityIdentifier("club.gov.story")
        .navigationDestination(item: $selectedTemplate) { selection in
            Group {
                if current(selection), let destination = templates.destination {
                    destination(selection.route.templateID).id(selection.id)
                } else { Text("club.story.templateUnavailable").accessibilityIdentifier("club.story.destinationUnavailable") }
            }
            // The covered List may not receive its change callback while this
            // destination is visible. Retire from the active destination too.
            .onChange(of: sourceRevision, initial: true) { _, _ in
                guard selectedTemplate?.id == selection.id, !current(selection) else { return }
                selectedTemplate = nil
            }
        }
        .navigationDestination(item: $selectedAnswer) { target in
            Group {
                if current(target) {
                    ClubGovernanceReadView(operation: .nodeAnswer, scope: target.scope, identity: identity, access: access, coordinator: coordinator)
                        .id(target.id)
                } else { Text("club.story.sourceUnavailable") }
            }
            .onChange(of: sourceRevision, initial: true) { _, _ in
                guard selectedAnswer?.id == target.id, !current(target) else { return }
                selectedAnswer = nil
            }
        }
        .cySheet(item: $answerSheetTarget) { target in
            PlayCloseSheetHost(
                title: [appLocalized("club.story.answerTitle", locale: locale), answerSheetName].compactMap { $0 }.joined(separator: " · "),
                detents: [.half, .full],
                onClose: { answerSheetTarget = nil }
            ) {
                if current(target) {
                    ClubGovernanceReadView(operation: .nodeAnswer, scope: target.scope, identity: identity, access: access, coordinator: coordinator)
                        .id(target.id)
                } else {
                    Text("club.story.sourceUnavailable")
                        .padding()
                }
            }
        }
        .cySheet(item: $hostAnswerTarget) { target in
            PlayCloseSheetHost(
                title: [appLocalized("club.story.answerTitle", locale: locale), target.name].compactMap { $0 }.joined(separator: " · "),
                detents: [.half, .full],
                onClose: { hostAnswerTarget = nil }
            ) {
                ClubStoryHostAnswerSheetContent(topicID: target.topicID, nodeID: target.nodeID, context: hostAnswer)
                    .id(target.id)
            }
        }
        .clubIslandStatus(verbatimMessage: $storyToastMessage, surface: "governance-story")
        .task(id: reloadContext) {
            // The overview is also covered. On return, obtain a fresh source
            // through its original scoped loader, rather than reuse old cards.
            if !sourceIsCurrent { await reload() }
        }
        .onChange(of: sourceRevision) { _, _ in invalidateSelection(resetChapter: true) }
        .onChange(of: tab) { _, _ in invalidateSelection() }
        .refreshable { await reload() }
    }
    /// CLB-topic-story-10: at accessibility sizes the chapter chips would scroll off; a menu picker keeps every
    /// chapter one tap away.
    @ViewBuilder private func chapterPicker(_ chapters: [ClubStoryChapter]) -> some View {
        if typeSize.isAccessibilitySize {
            Picker(selection: Binding(get: { selectedChapter }, set: { id in
                guard let chapter = chapters.first(where: { $0.id == id }), presentation?.chapters.contains(chapter) == true else { return }
                selectedChapter = id; invalidateSelection()
            })) {
                ForEach(chapters) { chapter in ClubStoryChapterTitle(chapter: chapter).tag(chapter.id) }
            } label: { Text("club.story.sections") }
            .pickerStyle(.menu)
            .accessibilityIdentifier("club.story.chapterMenu")
            .cyHaptic(.selection, trigger: selectedChapter)
        } else {
            chapterChips(chapters)
        }
    }
    private func chapterChips(_ chapters: [ClubStoryChapter]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(chapters) { chapter in
                    let selected = selectedChapter == chapter.id
                    Button {
                        // Display selection uses the unique local ordinal. Backend IDs
                        // authorize no chapter content; only template/answer routes need them.
                        guard presentation?.chapters.contains(chapter) == true else { return }
                        selectedChapter = chapter.id; invalidateSelection()
                    } label: {
                        ClubStoryChapterTitle(chapter: chapter)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(selected ? Color.accentColor : Color.secondary)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("club.story.chapter.\(chapter.id)")
                }
            }
        }.scrollIndicators(.hidden)
        .cyHaptic(.selection, trigger: selectedChapter)
    }
    @ViewBuilder private func playContent(_ chapter: ClubStoryChapter) -> some View {
        Section {
            if let story = chapter.description {
                Text(verbatim: story)
                    .lineLimit(typeSize.isAccessibilitySize || storyExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("club.story.description")
                Button(LocalizedStringKey(storyExpanded ? "club.story.collapse" : "club.story.expand")) { storyExpanded.toggle() }
                    .accessibilityIdentifier("club.story.expand")
            } else { Text("club.story.noStory").foregroundStyle(.secondary) }
        } header: {
            VStack(alignment: .leading) { Text("club.story.chapterStory"); ClubStoryChapterTitle(chapter: chapter) }
        }
        Section {
            if chapter.gameplay.isEmpty {
                ClubStoryEmptyState(title: "club.story.noPlays", detail: "club.story.awaitingPlays")
            }
            ForEach(chapter.gameplay) { play in
                VStack(alignment: .leading, spacing: 12) {
                    ClubStoryGameplayCard(play: play, imageReader: templates.imageReader,
                                          order: (chapter.gameplay.firstIndex(of: play) ?? 0) + 1)
                    // CLB-topic-story-02 (MP wxml:97-104): one row of borderless actions; 查看答案 opens one sheet.
                    HStack(spacing: 16) {
                        if let selection = templateSelection(play) {
                            Button("club.story.viewTemplate") {
                                guard selectedTemplate == nil, selectedAnswer == nil, sourceIsCurrent,
                                      selection.isCurrent(snapshot: snapshot, context: context,
                                          snapshotGeneration: snapshotGeneration, templates: templates) else { return }
                                selectedTemplate = selection
                            }
                            .accessibilityIdentifier("club.story.template.\(play.id)")
                        } else {
                            Text("club.story.templateUnavailable").font(.subheadline).foregroundStyle(.secondary)
                                .accessibilityIdentifier("club.story.templateUnavailable.\(play.id)")
                        }
                        if let target = answerRoute(play) {
                            Button("club.gov.nodeAnswer") {
                                guard selectedAnswer == nil, selectedTemplate == nil, current(target) else {
                                    storyToastMessage = appLocalized("club.story.sourceUnavailable", locale: locale)
                                    return
                                }
                                answerSheetName = play.nodeName ?? play.title
                                answerSheetTarget = target
                            }
                            .accessibilityIdentifier("club.story.answer.\(play.id)")
                        } else if let target = hostAnswerTarget(play) {
                            // CLB-topic-story-05: merchant entry posts api/topic/host-node-answer {topicId, nodeId, scope}.
                            Button("club.gov.nodeAnswer") {
                                guard hostAnswerTarget == nil, selectedTemplate == nil, sourceIsCurrent else {
                                    storyToastMessage = appLocalized("club.story.sourceUnavailable", locale: locale)
                                    return
                                }
                                hostAnswerTarget = target
                            }
                            .accessibilityIdentifier("club.story.answer.\(play.id)")
                        }
                    }
                    .buttonStyle(.borderless)
                }.id("\(mediaScope).play.\(play.id)")
            }
        } header: { Text("club.story.chapterPlays \(chapter.gameplay.count)") }
    }
    private func templateSelection(_ play: ClubStoryGameplay) -> ClubStoryTemplateSelection? {
        guard sourceIsCurrent, let snapshot else { return nil }
        return .init(gameplay: play, snapshot: snapshot, context: context,
                     snapshotGeneration: snapshotGeneration, templates: templates)
    }
    private func answerRoute(_ play: ClubStoryGameplay) -> ClubStoryAnswerRoute? {
        guard sourceIsCurrent, let snapshot else { return nil }
        return .init(gameplay: play, snapshot: snapshot, context: context, snapshotGeneration: snapshotGeneration)
    }
    /// Host entry only: the presentation has no club id, the link carried a scope, and the play is answerable.
    private func hostAnswerTarget(_ play: ClubStoryGameplay) -> ClubStoryHostAnswerTarget? {
        guard sourceIsCurrent, hostAnswer.isAvailable, let presentation, presentation.clubID == nil,
              presentation.hostScope != nil, play.isAnswerable, let nodeID = play.nodeID else { return nil }
        return .init(topicID: presentation.topicID, nodeID: nodeID, name: play.nodeName ?? play.title)
    }
    private func current(_ selection: ClubStoryTemplateSelection) -> Bool {
        sourceIsCurrent && selection.isCurrent(snapshot: snapshot, context: context,
            snapshotGeneration: snapshotGeneration, templates: templates)
    }
    private func current(_ route: ClubStoryAnswerRoute) -> Bool {
        sourceIsCurrent && route.isCurrent(snapshot: snapshot, context: context, snapshotGeneration: snapshotGeneration)
    }
    private func invalidateSelection(resetChapter: Bool = false) {
        selectedTemplate = nil; selectedAnswer = nil; answerSheetTarget = nil; hostAnswerTarget = nil; storyExpanded = false
        if resetChapter { selectedChapter = 0; mediaScope = UUID() }
    }
}

struct ClubGovernanceFactRows: View {
    let value: ClubGovernanceValue
    let fields: [String]
    var showUnknown = false
    /// Only the write review turns this on; read pages keep their current values.
    var localizesEnums = false
    @Environment(\.locale) private var locale
    /// CLB-notify-02 (parity r2): a server enum (ALL_MEMBERS, IN_APP, AVAILABLE…) reads as its catalog word
    /// (`club.gov.choice.*`) instead of the raw constant; an enum the catalog does not know stays as sent.
    private func shown(_ text: String, key: String = "") -> String {
        // Owner decision 9 (fix-r3-club-b round 2): money facts read ¥12.50 through `MoneyDisplay`.
        if ClubMoneyText.amountKeys.contains(key) { return ClubMoneyText.display(text) }
        guard localizesEnums, text.range(of: "^[A-Z][A-Z0-9_]+$", options: .regularExpression) != nil else { return text }
        let key = "club.gov.choice." + text
        let word = appLocalized(String.LocalizationValue(stringLiteral: key), locale: locale)
        return word == key ? text : word
    }
    static let summaryFields = ["name", "title", "topicName", "merchantName", "displayName", "nickname", "memberName", "content", "remark", "status", "statusCode", "statusText", "state", "occurrenceAt", "startDate", "signupCount", "refundedCount", "lockReason", "recurrenceType", "defaultLeadMemberId", "defaultCapacity", "offerMinutes", "waitlistEnabled", "version", "banReason", "sourceType", "expiresAt", "reason", "decisionReason", "roleCode", "topicId", "registrationId", "memberId", "total", "monthNew", "verifiedCount", "pendingCount", "score", "clearCount", "mileage", "durationMin", "hostedCount", "pace", "completionDuration", "settledAmountText", "amountText", "amountStatus", "originalAmountText", "executedAdjustmentText", "netAmountText", "arrivedText", "paidText", "depositStatus", "amount", "direction", "retryable", "orderNo", "ticketText", "orderTimeText", "paidAmountText", "verifyTimeText", "storeName", "operatorName", "railStep", "phoneText", "coopOpen", "pinned", "memberOnly", "canManage", "nodeCount", "sessionHeadcount", "pendingVerifyCount", "verifiedByMeCount", "totalCount", "successCount", "failedCount", "question", "answerReveal", "feedbackText"]
    var body: some View {
        ForEach(fields, id: \.self) { key in
            if let text = value[key].text, !text.isEmpty {
                LabeledContent(LocalizedStringKey("club.gov.field." + key)) { Text(verbatim: shown(text, key: key)).textSelection(.enabled) }.accessibilityIdentifier("club.gov.fact." + key)
            } else if let flag = value[key].bool {
                LabeledContent(LocalizedStringKey("club.gov.field." + key)) { Text(flag ? "club.gov.yes" : "club.gov.no") }
            } else if let values = value[key].array, values.allSatisfy({ $0.text != nil }) {
                LabeledContent(LocalizedStringKey("club.gov.field." + key)) { Text(verbatim: values.compactMap(\.text).joined(separator: ", ")).textSelection(.enabled) }
            } else if showUnknown && value.object?.keys.contains(key) == true && value[key] == .null {
                LabeledContent(LocalizedStringKey("club.gov.field." + key)) {
                    Text(verbatim: "—").accessibilityLabel(Text("club.gov.unknownValue"))
                }
                .accessibilityIdentifier("club.gov.fact." + key)
            }
        }
        if let hints = value["hints"].array { ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in if let text = hint.string { Text(verbatim: text).fixedSize(horizontal: false, vertical: true) } } }
    }
}

private enum ClubGovActionRole { case primary, secondary, destructive, inlineDestructive, inlineLink }

/// One prominent action per screen. Other commands are plain Settings-style row buttons; dissolve keeps the
/// destructive role (red, set on the Button itself).
private struct ClubGovActionChrome: ViewModifier {
    var role: ClubGovActionRole
    @ViewBuilder func body(content: Content) -> some View {
        switch role {
        case .primary:
            content.buttonStyle(.borderedProminent).controlSize(.large)
        case .secondary, .destructive:
            content
        case .inlineLink, .inlineDestructive:
            // CLB-governance-02 / CLB-roles-08: row-level 解封 / 撤销 / 封禁 / 转让 stay inline borderless actions
            // (destructive ones red through the Button role), so a row's other controls keep their own taps.
            content.buttonStyle(.borderless)
        }
    }
}
