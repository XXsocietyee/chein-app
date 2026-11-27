import SwiftUI

/// Host injects its retained coordinator and publishes account/epoch changes via identity.
/// No cached ClubRecord or role chooser authorizes a management operation.
struct ClubManagementView: View {
    let clubID: Int
    let identity: ClubReadIdentity?
    let access: any ClubManagementAccess
    let coordinator: ClubManagementCoordinator
    var viewerRevision: UInt64 = 0
    var onMembershipChanged: (() -> Void)? = nil
    /// CLB-join-requests-01 (fix-r3-club-b round 3): the MP `pages/club/join-requests` page is titled 入会申请 and
    /// lists only the pending requests; the owner's member list lives on 成员 / 管理. The club 管理 tab and the
    /// r1 fixture keep the combined page (members + requests), so their UI tests are unchanged.
    var joinRequestsOnly = false
    @State private var selection: DetailSelection?
    private enum DetailSelection: Hashable, Identifiable {
        case request(Int), member(Int)
        var id: Self { self }
    }
    @State private var snapshot: ClubManagementSnapshot?
    @StateObject private var reviewOwner = ClubManagementReviewOwner()
    @State private var detailHostVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var state: ClubManagementState = .idle
    @State private var loading = false
    @State private var stale = false
    @State private var screenRevision: UInt64?
    private struct ReadContext: Hashable {
        let identity: ClubReadIdentity?
        let revision: UInt64
        let access: ObjectIdentifier
        let coordinator: ObjectIdentifier
    }
    @State private var screenContext: ReadContext?
    private var readContext: ReadContext {
        .init(identity: identity, revision: viewerRevision, access: ObjectIdentifier(access), coordinator: ObjectIdentifier(coordinator))
    }
    private var reviewContext: ClubManagementReviewOwner.Context {
        .init(clubID: clubID, identity: identity, revision: viewerRevision, access: ObjectIdentifier(access), coordinator: ObjectIdentifier(coordinator))
    }
    private var contextMatches: Bool { screenContext == readContext && screenIdentity == identity && access.identity == identity && screenRevision == viewerRevision }
    @State private var failed = false
    @State private var serverReadMessage: String?
    /// CLB-join-requests-06: network vs service failure of the last list read (nil while it succeeds).
    @State private var loadFailureKind: ClubOpsNetworkFailureClassifier.Kind?
    @State private var denied = false
    @State private var readbackUnavailable = false
    @State private var generation: UInt64 = 0
    @State private var ownerID = UUID()
    @State private var screenIdentity: ClubReadIdentity?
    @State private var reviewReasonDraft = ""
    /// CLB-join-requests-05 (fix-r3-club-b): the last acknowledged action, for the MP toast 已通过 / 已拒绝.
    @State private var acknowledgedAction: ClubManagementAction?
    /// CLB-r8-join-requests-01 (fix-r8-club): the row whose last 通过 / 拒绝 was rejected; its card carries the failure.
    @State private var failedRow: (action: ClubManagementAction, memberID: Int)?

    var body: some View {
        List {
            // X1 (parity r2): inline bar title, no hero in the content.
            if identity == nil {
                ContentUnavailableView("club.management.signin", systemImage: "person.crop.circle.badge.exclamationmark")
            } else if !access.isConfigured {
                ContentUnavailableView("club.management.unconfigured", systemImage: "network.slash")
            } else {
                if loading && snapshot == nil {
                    ProgressView { Text("club.management.loading") }
                        .frame(maxWidth: .infinity)
                }
                let loadIssue = ClubOpsJoinRequestCopy.loadIssue(failed: failed, denied: denied, stale: stale, hasSnapshot: contextMatches && snapshot != nil)
                if let issue = loadIssue {
                    ClubOpsJoinRequestLoadIssue(issue: issue, literalTitle: loadFailureKind.map { ClubOpsNetworkFailureClassifier.title(for: .joinRequests, kind: $0) }, disabled: loading || state == .checking || state == .awaitingConfirmation || state == .submitting) { Task { await refresh() } }
                }
                if failed {
                    // The mini page title replaces the generic unavailable line; denial keeps its own copy.
                    if denied || loadIssue == nil {
                        Text(LocalizedStringKey(denied ? "club.management.denied" : "club.management.unavailable"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let serverReadMessage { serverMessage(serverReadMessage) }
                }
                status
                if contextMatches, let snapshot {
                    // Mini-program club/join-requests: title, the 「N 条待审 · 可直接通过或拒绝」 line, then the cards.
                    Section {
                        if snapshot.requests.isEmpty {
                            ContentUnavailableView(
                                "club.management.empty",
                                systemImage: "person.badge.clock",
                                description: Text("club.management.emptyHint")
                            )
                        }
                        ForEach(snapshot.requests) { request in
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                Button { selection = .request(request.id) } label: {
                                    requestRow(request)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("club.management.request.\(request.id)")
                                // CLB-join-requests-02 (parity r2), MC-21: visible 拒绝 / 通过 on the row; the swipe stays.
                                if snapshot.allows(.approve, memberID: request.id) {
                                    requestRowActions(request)
                                }
                                if let failure = rowFailure(request.id) { rowFailureBlock(failure, request: request) }
                            }
                            // HANDOFF-R1 MC-21: approve / reject also work by swipe; both still open the review sheet.
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if snapshot.allows(.approve, memberID: request.id) {
                                    let attachment = reviewOwner.attachment, source = reviewContext
                                    Button {
                                        Task { await prepare(.approve, memberID: request.id, attachment: attachment, source: source) }
                                    } label: { Label { Text(verbatim: clubR1("request.approve", locale)) } icon: { Image(systemName: "checkmark") } }
                                    .tint(.green)
                                    Button {
                                        Task { await prepare(.reject, memberID: request.id, attachment: attachment, source: source) }
                                    } label: { Label { Text(verbatim: clubR1("request.reject", locale)) } icon: { Image(systemName: "xmark") } }
                                    // CLB-join-requests-08 (fix-r3-club-b): a legible danger tint for 拒绝.
                                    .tint(.red)
                                }
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            // The requests-only page already carries 入会申请 as its bar title.
                            if !joinRequestsOnly {
                                Text("club.management.requests")
                                    .accessibilityAddTraits(.isHeader)
                            }
                            if !snapshot.requests.isEmpty,
                               let pendingText = ClubJoinRequestsPageReady.pendingCountText(
                                visibility: .init(reviewCapabilityPresent: contextMatches, canGovern: snapshot.club.isOwner || snapshot.club.viewerIsAdmin, playerFirstEntry: false),
                                count: snapshot.requests.count) {
                                ClubOpsJoinRequestsIntro(count: snapshot.requests.count).textCase(nil)
                                    .accessibilityValue(Text(verbatim: pendingText))
                            }
                        }
                    }
                    if snapshot.club.isOwner, !joinRequestsOnly {
                        Section {
                            if snapshot.members.isEmpty {
                                ContentUnavailableView(
                                    LocalizedStringKey(snapshot.club.memberCount > 0 ? "club.management.members_unavailable" : "club.management.members_empty"),
                                    systemImage: "person.2"
                                )
                            }
                            ForEach(snapshot.members) { member in
                                Button { selection = .member(member.id) } label: {
                                    managementMemberRow(member)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("club.management.member.\(member.id)")
                            }
                        } header: {
                            Text("club.management.members")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
                // CLB-join-requests-06 (fix-r3-club-b): pull to refresh is the main path; this stays a secondary pill.
                // fix-r8-club: the MP join-requests page (requests only) has no bottom 刷新 at all; the full management
                // list keeps the pill its UI tests drive.
                if !joinRequestsOnly {
                    Section {
                        Button("club.management.refresh") { Task { await refresh() } }
                            .disabled(loading || state == .checking || state == .awaitingConfirmation || state == .submitting)
                            .accessibilityIdentifier("club.management.refresh")
                    }
                }
            }
        }
        .cyPageTitle(joinRequestsOnly ? "club.management.requests" : "club.management.title")
        .refreshable { await refresh() }
        // CLB-join-requests-05 (fix-r3-club-b), MC-21: a handled card slides out when the readback replaces the list.
        .animation(.easeOut(duration: 0.16), value: snapshot?.requests.map(\.id))
        .navigationDestination(item: $selection) { selected in detail(selected) }
        .task(id: readContext) {
            guard screenContext != readContext || snapshot == nil && state == .idle else { return }
            leaveScreen()
            generation &+= 1
            cancel(); selection = nil; snapshot = nil; stale = false; state = .idle; loading = false
            screenIdentity = identity; screenRevision = viewerRevision; screenContext = readContext
            coordinator.synchronizeSession()
            await refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { leaveScreen() }
            else if detailHostVisible { reviewOwner.appear(reviewContext) }
        }
        .onDisappear { if selection == nil { leaveScreen() } }
    }
    @ViewBuilder private func detail(_ selected: DetailSelection) -> some View {
        let presentedAttachment = reviewOwner.attachment
        let detailTitle: String.LocalizationValue = {
            switch selected { case .request: return "club.management.request"; case .member: return "club.management.member" }
        }()
        Form {
            // X1 (parity r2): inline bar title, no hero in the content.
            if loading { ProgressView().accessibilityIdentifier("club.management.detail.loading").accessibilityLabel(Text("club.management.loading")) }
            status
            if contextMatches, access.identity == identity, let snapshot {
                switch selected {
                case .request(let id):
                    if let request = snapshot.requests.first(where: { $0.id == id }) {
                        requestDetail(request)
                        if snapshot.allows(.approve, memberID: id) {
                            // HANDOFF-R1 MC-21: 拒绝 · 通过 side by side, 44 pt each, 12 pt apart (stacked at XXL).
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: CYSpacing.md) {
                                    action(.reject, memberID: id)
                                    action(.approve, memberID: id)
                                }
                                VStack(spacing: CYSpacing.md) {
                                    action(.approve, memberID: id)
                                    action(.reject, memberID: id)
                                }
                            }
                        }
                    }
                case .member(let id):
                    if let member = snapshot.members.first(where: { $0.id == id }) {
                        managementMemberRow(member, showsChevron: false)
                            .accessibilityElement(children: .combine)
                        if snapshot.allows(.remove, memberID: id) { action(.remove, memberID: id) }
                    }
                }
            }
            if failed {
                Text(LocalizedStringKey(denied ? "club.management.denied" : "club.management.unavailable"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let serverReadMessage { serverMessage(serverReadMessage) }
            }
            Section {
                Button("club.management.refresh") { Task { await refresh() } }
                    .disabled(loading || state == .checking || state == .awaitingConfirmation || state == .submitting)
                    .accessibilityIdentifier("club.management.detail.refresh")
            }
        }
        .cyPageTitle(detailTitle)
        // The root List's task is suspended while this destination is pushed.
        // Invalidate its selection here, where viewer changes are still observed.
        .onChange(of: readContext) { _, _ in invalidateDetailContext() }
        .background {
            if let attachment = reviewOwner.attachment {
                ClubManagementReviewLifetime(covered: { reviewOwner.cover(attachment) }, departed: {
                    if reviewOwner.depart(attachment) { detailHostVisible = false; leaveScreen() }
                }).id(attachment)
            }
            if let item = reviewOwner.item {
                ClubManagementReviewPresentation(item: item, owner: reviewOwner, context: { reviewContext },
                    active: { scenePhase == .active && contextMatches }, cancelled: cancelReview) {
                    confirmationContent(item)
                }.id(item.id)
            }
        }
        .onAppear {
            detailHostVisible = true
            if scenePhase == .active { reviewOwner.appear(reviewContext) }
        }
        .onDisappear {
            if let presentedAttachment, reviewOwner.attachment == presentedAttachment {
                detailHostVisible = false; reviewOwner.hide(presentedAttachment)
            }
        }
    }
    /// A blank name is unknown. CLB-join-requests-04 / X10: internal ids are never shown to people.
    private static func namedID(_ name: String, _ id: Int) -> String {
        let shown = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return shown.isEmpty ? "—" : shown
    }
    private func personAvatar(raw: String?, fallback: String) -> some View {
        // MP join-requests `item.avatar || '/images/d_profile.png'` (round 2 MP asset).
        ClubMPAvatar(url: QuestifyCardArtwork.safeURL(raw), name: fallback, size: .md)
            .accessibilityHidden(true)
    }
    private func rowFailure(_ memberID: Int) -> ClubActionResponseFailure? {
        guard let row = failedRow, row.memberID == memberID, case .rejected(let failure) = state else { return nil }
        return failure
    }
    /// CLB-r8-join-requests-01 (fix-r8-club): MP join-requests row error 这次处理没有完成 + reason + 重试 (same action again).
    private func rowFailureBlock(_ failure: ClubActionResponseFailure, request: ClubManagementRequest) -> some View {
        let attachment = reviewOwner.attachment, source = reviewContext
        let busy = loading || state == .checking || state == .awaitingConfirmation || state == .submitting
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("clubR8b.join.rowFailed").font(.body.weight(.semibold)).foregroundStyle(.red)
            if let message = failure.message { Text(verbatim: message).font(.footnote).foregroundStyle(.secondary) }
            if let row = failedRow {
                Button("clubR8b.retry") { Task { await prepare(row.action, memberID: request.id, attachment: attachment, source: source) } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(busy)
                    .accessibilityIdentifier("club.management.row.retry.\(request.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.management.row.failed.\(request.id)")
    }
    /// MC-21 row buttons: 拒绝 (secondary) and 通过 (primary), 12 pt apart, 44 pt targets. Both open the same review.
    private func requestRowActions(_ request: ClubManagementRequest) -> some View {
        let attachment = reviewOwner.attachment, source = reviewContext
        let busy = loading || state == .checking || state == .awaitingConfirmation || state == .submitting
        return HStack(spacing: CYSpacing.md) {
            Spacer(minLength: 0)
            Button {
                Task { await prepare(.reject, memberID: request.id, attachment: attachment, source: source) }
            } label: { Text(verbatim: clubR1("request.reject", locale)) }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("club.management.row.reject.\(request.id)")
            Button {
                Task { await prepare(.approve, memberID: request.id, attachment: attachment, source: source) }
            } label: { Text(verbatim: clubR1("request.approve", locale)) }
            // CLB-r10-nat-join-requests-01 (MP join-requests wxml: 通过 is the primary action): small `.borderedProminent`.
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("club.management.row.approve.\(request.id)")
        }
        .disabled(busy)
    }
    private func requestRow(_ request: ClubManagementRequest) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            personAvatar(raw: request.avatar, fallback: ClubOpsJoinRequestPresentation.displayName(request.nickname) ?? "\(request.id)")
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                ClubOpsJoinRequestRowText(request: request)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if let time = request.requestTimeText { Text("club.management.requestedAt \(time)") }
                    else { Text("club.management.timeUnknown") }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                // CLB-join-requests-03 (parity r2): the applicant's join message on the row (MP wxml:43).
                if let message = request.joinMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                    Text(verbatim: message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
    }
    private func requestDetail(_ request: ClubManagementRequest) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                personAvatar(raw: request.avatar, fallback: ClubOpsJoinRequestPresentation.displayName(request.nickname) ?? "\(request.id)")
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if let name = ClubOpsJoinRequestPresentation.displayName(request.nickname) {
                        Text(verbatim: name).font(.headline).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("clubOpsJN.join.playerFallback", tableName: "ClubOpsJoinNotify")
                            .font(.headline).fixedSize(horizontal: false, vertical: true)
                    }
                    if let time = request.requestTimeText {
                        Text("club.management.requestedAt \(time)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let message = request.joinMessage, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("club.application.messageReceived")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: message)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("club.management.joinMessage")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func managementMemberRow(_ member: ClubMember, showsChevron: Bool = true) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            personAvatar(raw: member.avatar, fallback: ClubOpsJoinRequestPresentation.displayName(member.nickname) ?? "\(member.id)")
            if let name = ClubOpsJoinRequestPresentation.displayName(member.nickname) {
                Text(verbatim: name).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("clubOpsJN.join.playerFallback", tableName: "ClubOpsJoinNotify")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: CYSpacing.sm)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
    }
    private func invalidateDetailContext() {
        guard screenContext != readContext else { return }
        // Fence cancellation-ignoring completions and cancel only undispatched review.
        // leaveScreen preserves dispatched/unknown coordinator journal entries.
        leaveScreen()
        selection = nil; snapshot = nil; stale = false
        failed = false; denied = false; serverReadMessage = nil; readbackUnavailable = false
        // Do not mark the new context as read. The returning root must fetch it.
        screenRevision = nil
    }
    private func leaveScreen() {
        generation &+= 1
        loading = false
        if let screenIdentity { coordinator.leaveScreen(clubID: clubID, expectedIdentity: screenIdentity, ownerID: ownerID) }
        cancel(); reviewOwner.retire()
    }
    @ViewBuilder private var status: some View {
        if stale { statusLine("club.management.stale", symbol: "clock.arrow.circlepath", identifier: "club.management.stale") }
        switch state {
        case .checking, .submitting: ProgressView { Text("club.management.loading") }
        case .notSent: statusLine("club.management.not_sent", symbol: "paperplane")
        case .acknowledged(let receipt):
            if let message = receipt.message { serverMessage(message) }
            else if !readbackUnavailable, let action = acknowledgedAction, action != .remove {
                // CLB-join-requests-05: the row has already left (readback); MP toast 已通过 / 已拒绝.
                statusLine(action == .approve ? "clubR3b.join.approved" : "clubR3b.join.rejected", symbol: "checkmark.circle")
            } else { statusLine("club.management.acknowledged", symbol: "checkmark.circle") }
        case .rejected(let failure):
            if let row = failedRow, contextMatches, snapshot?.requests.contains(where: { $0.id == row.memberID }) == true {
                EmptyView() // CLB-r8-join-requests-01: shown on the row instead.
            } else if let message = failure.message { serverMessage(message) } else { statusLine("club.management.rejected", symbol: "xmark.circle") }
            if let row = RequestReferenceRow(pathFragment: "/api/club/") { row }
        case .outcomeUnknown:
            statusLine("club.management.unknown", symbol: "questionmark.circle", identifier: "club.management.unknown")
            if let row = RequestReferenceRow(pathFragment: "/api/club/") { row }
        default: EmptyView()
        }
        if readbackUnavailable {
            statusLine("club.management.readback_unavailable", symbol: "arrow.triangle.2.circlepath", identifier: "club.management.readbackUnavailable")
            if let row = RequestReferenceRow(pathFragment: "/api/club/") { row }
        }
    }
    /// Status copy stays a `Text` so existing UI tests can find the static text by identifier.
    private func statusLine(_ key: LocalizedStringKey, symbol: String, identifier: String? = nil) -> some View {
        Label {
            Text(key)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(CYOptionalAccessibilityIdentifier(identifier: identifier))
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
    private func serverMessage(_ message: String) -> some View {
        let shown = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return Text(verbatim: shown.isEmpty ? "—" : shown)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
    @ViewBuilder private func action(_ action: ClubManagementAction, memberID: Int) -> some View {
        let attachment = reviewOwner.attachment, source = reviewContext
        if action == .approve {
            Button {
                Task { await prepare(action, memberID: memberID, attachment: attachment, source: source) }
            } label: {
                ClubOpsJoinRequestActionLabel(action: action, progressKey: progressKey(action, memberID: memberID))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(loading || stale || !contextMatches || state.preventsNewAction)
            .accessibilityIdentifier("club.management.\(action.rawValue).\(memberID)")
        } else {
            // HANDOFF-R1 MC-21: 拒绝 is the quiet secondary beside 通过; 移除 keeps the red style.
            Group {
                if action == .remove {
                    // A Settings-style destructive row in the detail Form.
                    Button(role: .destructive) {
                        Task { await prepare(action, memberID: memberID, attachment: attachment, source: source) }
                    } label: { ClubOpsJoinRequestActionLabel(action: action, progressKey: progressKey(action, memberID: memberID)) }
                } else {
                    Button(role: .destructive) {
                        Task { await prepare(action, memberID: memberID, attachment: attachment, source: source) }
                    } label: {
                        ClubOpsJoinRequestActionLabel(action: action, progressKey: progressKey(action, memberID: memberID))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .disabled(loading || stale || !contextMatches || state.preventsNewAction)
            .accessibilityIdentifier("club.management.\(action.rawValue).\(memberID)")
        }
    }
    @ViewBuilder private func confirmControl(_ pending: ClubManagementConfirmation, item: ClubManagementReviewOwner.Item) -> some View {
        if pending.action == .approve {
            Button {
                guard reviewOwner.claim(item, context: reviewContext, active: scenePhase == .active) else { return }
                state = .submitting
                Task { await confirm(pending, item: item) }
            } label: {
                ClubOpsJoinRequestActionLabel(action: pending.action, progressKey: progressKey(pending.action, memberID: pending.memberID))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(pending.action == .reject && !ClubOpsJoinReviewReason.isValid(reviewReasonDraft))
            .accessibilityIdentifier("club.management.confirm")
        } else {
            Button(role: .destructive) {
                guard reviewOwner.claim(item, context: reviewContext, active: scenePhase == .active) else { return }
                state = .submitting
                Task { await confirm(pending, item: item) }
            } label: {
                ClubOpsJoinRequestActionLabel(action: pending.action, progressKey: progressKey(pending.action, memberID: pending.memberID))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(pending.action == .reject && !ClubOpsJoinReviewReason.isValid(reviewReasonDraft))
            .accessibilityIdentifier("club.management.confirm")
        }
    }
    private func progressKey(_ action: ClubManagementAction, memberID: Int) -> String? {
        let acting = reviewOwner.item?.confirmation
        return ClubOpsJoinRequestCopy.progressKey(action, submitting: state == .submitting, actingAction: acting?.action,
                                                  actingMemberID: acting?.memberID, memberID: memberID)
    }
    private func cancel() {
        if let item = reviewOwner.item, reviewOwner.cancel(item) { coordinator.cancel(item.confirmation) }
        state = coordinator.state(clubID: clubID)
    }
    private func cancelReview(_ item: ClubManagementReviewOwner.Item) {
        coordinator.cancel(item.confirmation)
        if item.context == reviewContext { state = coordinator.state(clubID: clubID) }
    }
    @ViewBuilder private func confirmationContent(_ item: ClubManagementReviewOwner.Item) -> some View {
        // Reject freezes the reviewer's optional reason into this same review (same id and target).
        let pending = item.confirmation.reviewing(reason: reviewReasonDraft)
        if contextMatches, reviewOwner.current(item, context: reviewContext, active: scenePhase == .active) {
            NavigationStack {
                Form {
                    if pending.action == .remove {
                        Text(LocalizedStringKey("club.management." + String(pending.action.rawValue) + ".body"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else { ClubOpsJoinReviewNotes(action: pending.action) }
                    LabeledContent("club.management.club") { Text(verbatim: Self.namedID(pending.clubName, pending.clubID)) }
                    LabeledContent("club.management.target") { Text(verbatim: Self.namedID(pending.memberName, pending.memberID)) }
                    if pending.action == .reject { ClubOpsJoinRejectReasonField(text: $reviewReasonDraft).disabled(state == .submitting || state.preventsNewAction) }
                    confirmControl(pending, item: item)
                        .cyHaptic(.impactMedium, trigger: state) { old, new in
                            if case .submitting = new {
                                if case .submitting = old { return false }
                                return true
                            }
                            return false
                        }
                }
                // CLB-join-requests-09 (fix-r3-club-b): a sheet title, not a 34 pt hero.
                .navigationTitle(Text(LocalizedStringKey("club.management." + pending.action.rawValue)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("club.management.cancel") {
                        if reviewOwner.cancel(item) { cancelReview(item) }
                    }
                    .accessibilityLabel(Text("club.management.cancel"))
                } }
            }
            .accessibilityIdentifier("club.management.confirmation")
        }
    }
    @MainActor private func refresh() async {
        guard identity != nil, access.isConfigured, contextMatches, !loading,
              state != .checking, state != .awaitingConfirmation, state != .submitting else { return }
        generation &+= 1; let run = generation; let captured = identity; let revision = viewerRevision
        let source = readContext
        loading = true; failed = false; serverReadMessage = nil; denied = false; loadFailureKind = nil
        stale = snapshot != nil
        state = coordinator.state(clubID: clubID)
        do {
            let result = try await access.snapshot(clubID: clubID)
            guard source == readContext, screenContext == source, run == generation, identity == captured, access.identity == captured, viewerRevision == revision, screenRevision == revision, !Task.isCancelled else { return }
            guard result.club.id == clubID, result.club.canGovern else { throw ClubReadFailure.forbidden(message: nil) }
            snapshot = result; stale = false; loading = false; readbackUnavailable = false
        } catch {
            guard source == readContext, screenContext == source, run == generation, identity == captured, access.identity == captured, viewerRevision == revision, screenRevision == revision, !Task.isCancelled else { return }
            if let snapshot, let failure = error as? ClubManagementListConnectionFailure, failure.canRetain(snapshot) {
                stale = true
            } else { snapshot = nil; stale = false }
            failed = true; loading = false
            loadFailureKind = ClubOpsNetworkFailureClassifier.classify(error)
            serverReadMessage = (error as? ClubReadFailure)?.message
            denied = (error as? ClubReadFailure)?.isForbidden == true
        }
    }
    @MainActor private func prepare(_ action: ClubManagementAction, memberID: Int,
                                    attachment: UUID?, source: ClubManagementReviewOwner.Context) async {
        guard let identity, contextMatches, !stale, !state.preventsNewAction, !loading, reviewOwner.item == nil,
              let attachment, source == reviewContext,
              reviewOwner.isAttached(attachment, context: source, active: scenePhase == .active) else { return }
        generation &+= 1; let run = generation; let revision = viewerRevision
        state = .checking; reviewReasonDraft = ""
        do {
            let pending = try await coordinator.prepare(clubID: clubID, action: action, memberID: memberID, expectedIdentity: identity, ownerID: ownerID)
            guard run == generation, access.identity == identity, viewerRevision == revision, screenRevision == revision, !Task.isCancelled else { coordinator.cancel(pending); return }
            guard source == reviewContext,
                  reviewOwner.stage(pending, attachment: attachment, context: source, active: scenePhase == .active) else {
                coordinator.cancel(pending)
                if run == generation, source == reviewContext { state = coordinator.state(clubID: clubID) }
                return
            }
            state = coordinator.state(clubID: clubID)
        } catch {
            guard run == generation, access.identity == identity, viewerRevision == revision, screenRevision == revision,
                  source == reviewContext,
                  reviewOwner.isAttached(attachment, context: source, active: scenePhase == .active) else { return }
            snapshot = nil; stale = false; failed = true; state = coordinator.state(clubID: clubID)
            serverReadMessage = (error as? ClubReadFailure)?.message
            denied = (error as? ClubReadFailure)?.isForbidden == true
        }
    }
    @MainActor private func confirm(_ pending: ClubManagementConfirmation, item: ClubManagementReviewOwner.Item) async {
        guard contextMatches, !stale, pending.identity == identity,
              reviewOwner.permitsDispatch(item, context: reviewContext, active: scenePhase == .active) else {
            coordinator.cancel(pending); return
        }
        generation &+= 1; let run = generation; let revision = viewerRevision
        snapshot = nil; stale = false
        _ = await coordinator.confirm(pending)
        guard run == generation, access.identity == pending.identity, !Task.isCancelled, viewerRevision == revision, screenRevision == revision,
              reviewOwner.permitsDispatch(item, context: reviewContext, active: scenePhase == .active) else { return }
        state = coordinator.state(clubID: clubID)
        if case .rejected = state { failedRow = (pending.action, pending.memberID) } else { failedRow = nil }
        switch coordinator.readback(clubID: clubID) {
        case .received(let result): snapshot = result
        case .unavailable: readbackUnavailable = true
        default: break
        }
        if case .acknowledged = state {
            acknowledgedAction = pending.action
            CYHaptics.success.play()
            // Navigate back only after a definite server acknowledgement. A failed
            // readback remains visible on the list; it never fabricates new rows.
            selection = nil
            onMembershipChanged?()
        }
    }
}

