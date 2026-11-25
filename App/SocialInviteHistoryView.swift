import SwiftUI

@MainActor struct SocialInviteHistoryView: View {
    let reader: any SocialAccountReading
    let squareReader: any SquareReading
    var actions: SocialActionCoordinator? = nil
    /// FIN-20-4: MP 登录 on the signed-out state. Nil keeps the state without a button.
    var onSignIn: (() -> Void)? = nil
    @StateObject private var model = SocialInviteHistoryModel()
    @Environment(\.cyPalette) private var palette
    /// A2-03: re-applied on each pushed profile so 发消息 opens the chat in place.
    @Environment(\.socialConversationDestination) private var conversationDestination
    private var groups: [(String, [SocialInvitedMember])] {
        (model.timeline(reader)?.months ?? []).map { ($0.id, $0.members) }
    }
    var body: some View {
        let binding = model.bind(reader)
        let permit = model.permit(reader)
        List {
            if reader.isOfflineExample { CYStatusChip("social.offline", tone: .neutral, systemImage: "wifi.slash") }
            if reader.identity.accountID == nil { ProfileInviteHistoryIssueView(error: APIError.unauthorized) }
            else if !reader.isConfigured { SocialIssueView(error: APIError.notConfigured) }
            else if !model.matches(reader) { CYLoadingStateView(rows: 1).accessibilityLabel(Text("social.loading")) }
            else if model.accessDenied, let error = model.error {
                ProfileInviteHistoryIssueView(error: error)
            }
            else {
                // FIN-20-4: with no rows the failure is the full-page state at the top; a next-page failure sits below the rows.
                if let error = model.error, model.pagination.members.isEmpty {
                    inviteHistoryIssue(error, permit: permit)
                }
                // FIN-20-2: one hero (首购奖励积分 / 已邀请 N 人 · 已到账 M 人); no duplicate 累计邀请 row.
                ProfileInviteRewardReviewSection(review: .init(scan: model.scan), total: model.pagination.total,
                                                 coverageIncomplete: ProfileInviteHistoryPageReady.rewardCoverage(model.scan) != .complete,
                                                 isLoading: model.loading) {
                    model.start(reader, permit: permit, reset: true)
                }
                // R7-MEM-20-1: the latest real first-purchase reward (MP ir-earn), without the scan animation.
                if let latest = latestEarn { ProfileInviteLatestEarnCard(member: latest.0, reward: latest.1) }
                ForEach(groups, id: \.0) { group in
                    Section {
                        ForEach(group.1) { member in
                            NavigationLink {
                                SocialPublicProfileView(memberID: member.id, reader: reader, squareReader: squareReader, actions: actions)
                                    .environment(\.socialConversationDestination, conversationDestination) // A2-03 发消息
                            } label: { memberRow(member) }.accessibilityIdentifier("social.invite.\(member.id)")
                        }
                    } header: {
                        HStack(alignment: .top) {
                            if group.0.isEmpty { Text("social.invites.otherMonth") }
                            else { Text(verbatim: group.0) }
                            Spacer()
                            ProfileInviteMonthReward(month: ProfileInviteRewardReview(scan: model.scan).month(members: group.1))
                        }
                    }
                }
                if !model.loading && model.pagination.members.isEmpty && model.error == nil { ProfileInviteHistoryEmptyView() }
                if model.loading { CYLoadingStateView(rows: 1).accessibilityLabel(Text("social.loading")) }
                if let error = model.error, !model.pagination.members.isEmpty {
                    // MP myinvite wxml:63 `没加载出来 · 重试`, where 加载更多 sits.
                    inviteHistoryIssue(error, permit: permit)
                }
                if model.pagination.continuationInvalid { CYStatusChip("social.invites.continuationInvalid", tone: .danger, systemImage: "exclamationmark.triangle") }
                if model.pagination.hasMore && !model.loading && model.error == nil {
                    CYPillButton("wallet.loadMore", style: .secondary) { model.start(reader, permit: permit, reset: false) }.accessibilityIdentifier("social.invites.more")
                }
            }
        }
            // FIN-20-3: inline bar title, no second title in the content (type-and-chrome §2).
            // FIN-20-4: with no rows the issue view becomes the MP full-page cy-error (登录 / 重试); with rows it stays inline.
            .environment(\.inviteHistoryIssueFullPage, model.pagination.members.isEmpty)
            .environment(\.inviteHistorySignIn, onSignIn)
            .cyPageTitle("social.invites.title").cyPushedChrome(domain: .player).privacySensitive()
            .onAppear { model.appear(reader) }
            .onChange(of: binding) { _, _ in model.replaceReader(reader) }
            .refreshable { await model.refresh(reader, permit: permit) }
            .onDisappear { model.suspend() }
            .accessibilityIdentifier("social.invites")
    }
    /// Retry stays on this page's issue view. Reset only when no row is loaded.
    private func inviteHistoryIssue(_ error: Error, permit: SocialInviteHistoryModel.LoadPermit?) -> some View {
        ProfileInviteHistoryIssueView(error: error) { model.start(reader, permit: permit, reset: model.pagination.members.isEmpty) }
    }
    private var latestEarn: (SocialInvitedMember, SocialInviteReward)? {
        guard let rewards = model.scan?.rewards, !rewards.isEmpty else { return nil }
        let earned = model.pagination.members.compactMap { member in rewards[String(member.id)].map { (member, $0) } }
        return earned.max { ($0.1.createdAt ?? "") < ($1.1.createdAt ?? "") }
    }
    private func memberRow(_ member: SocialInvitedMember) -> some View {
        // Source myinvite row: initial avatar, name over the timeline line, reward chip on the right.
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYAvatarView(url: member.avatar.flatMap { URL(string: $0) }, name: member.nickname ?? "—", size: .md)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let nickname = member.nickname { Text(verbatim: nickname).cyText(.cardTitle).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true) }
                else { Text("profile.inviteHistory.nicknameUnknown").cyText(.cardTitle).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true) }
                ProfileInviteTimelineDates(invitationTime: member.createdAt,
                    reward: model.scan?.rewards[String(member.id)])
            }
            Spacer(minLength: CYSpacing.sm)
            VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                if let reward = model.scan?.rewards[String(member.id)] {
                    // Source reward pill: +N 积分.
                    Text("u9cde.invite.points \(NSDecimalNumber(decimal: reward.points).stringValue)")
                        .cyText(.numericBody).monospacedDigit().foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                        .background(Capsule().fill(palette.actionSecondaryBg))
                    CYStatusChip("social.invites.earned", tone: .success, systemImage: "checkmark")
                } else { CYStatusChip(LocalizedStringKey(model.scan?.isComplete == true ? "social.invites.pending" : "social.invites.synchronizing"), tone: .neutral, systemImage: "clock") }
            }
        }.accessibilityElement(children: .combine)
    }
}

/// Every request belongs to one model, one visible presentation, one reader and
/// one request generation. Cancellation is useful but never the only fence.
@MainActor final class SocialInviteHistoryModel: ObservableObject {
    struct ReaderBinding: Equatable {
        let id = UUID()
        let key: SocialReadPresentationKey
    }
    struct LoadPermit: Equatable {
        let owner: UUID
        let presentation: UUID
        let binding: ReaderBinding
    }
    @Published private(set) var pagination = SocialInvitePagination()
    @Published private(set) var scan: SocialRewardScan?
    @Published private(set) var loading = false
    @Published private(set) var error: Error?
    var accessDenied: Bool {
        guard let error else { return false }
        let kind = ProfileInviteHistoryIssueKind(error)
        return kind == .signIn || kind == .denied
    }
    @Published private var presentation: LoadPermit?
    @Published private var loadedBinding: ReaderBinding?
    private var boundReader: ReaderBinding?
    private let owner = UUID()
    private var requestID: UUID?
    private var task: Task<Void, Never>?

    static func key(_ reader: any SocialAccountReading) -> SocialReadPresentationKey {
        .init(reader: reader, request: "invitation-history", requiresSignIn: true)
    }
    /// Bind during body evaluation, before onChange or old async completions can
    /// run. Only non-published fencing state changes here; UI state reloads later.
    /// A new ID also retires an observed reader A-B-A before lifecycle callbacks.
    @discardableResult
    func bind(_ reader: any SocialAccountReading) -> ReaderBinding {
        let key = Self.key(reader)
        if let boundReader, boundReader.key == key { return boundReader }
        let current = ReaderBinding(key: key)
        boundReader = current
        task?.cancel()
        return current
    }
    func matches(_ reader: any SocialAccountReading) -> Bool {
        reader.identity.accountID != nil && reader.isConfigured && loadedBinding == boundReader
            && loadedBinding?.key == Self.key(reader)
    }
    /// Never project the retained rows into a replacement reader's visible timeline.
    func timeline(_ reader: any SocialAccountReading) -> ProfileInviteTimeline? {
        guard matches(reader) else { return nil }
        return .init(members: pagination.members)
    }
    func permit(_ reader: any SocialAccountReading) -> LoadPermit? {
        guard let presentation, presentation.owner == owner, presentation.binding == boundReader,
              presentation.binding.key == Self.key(reader), reader.identity.accountID != nil, reader.isConfigured else { return nil }
        return presentation
    }
    /// Called synchronously by appearance, not by a potentially queued Task.
    @discardableResult
    func appear(_ reader: any SocialAccountReading) -> Task<Void, Never>? {
        let key = Self.key(reader)
        if boundReader == nil { bind(reader) }
        guard let binding = boundReader, binding.key == key, presentation?.binding != binding else { return nil }
        suspend()
        let current = LoadPermit(owner: owner, presentation: UUID(), binding: binding)
        presentation = current; loadedBinding = binding
        pagination = SocialInvitePagination(); scan = nil; error = nil
        return start(reader, permit: current, reset: true)
    }
    @discardableResult
    func replaceReader(_ reader: any SocialAccountReading) -> Task<Void, Never>? {
        guard presentation != nil else { return nil } // A covered/closed screen cannot restart itself.
        return appear(reader)
    }
    /// Keep scoped rows that own pushed NavigationLinks. Reappearance starts a
    /// new presentation and resets them; hidden work has no right to change them.
    func suspend() {
        presentation = nil; requestID = nil
        task?.cancel(); task = nil; loading = false
    }
    @discardableResult
    func start(_ reader: any SocialAccountReading, permit: LoadPermit?, reset: Bool) -> Task<Void, Never>? {
        guard let permit, self.permit(reader) == permit, !loading || reset,
              reset || pagination.hasMore else { return nil }
        task?.cancel()
        let request = UUID(); requestID = request
        if reset { pagination = SocialInvitePagination(); scan = nil }
        error = nil; loading = true
        let page = pagination.nextPage
        let work = Task { [weak self] in
            guard let self else { return }
            await self.load(reader, permit: permit, request: request, page: page)
        }
        task = work
        return work
    }
    func refresh(_ reader: any SocialAccountReading, permit: LoadPermit?) async {
        guard !Task.isCancelled, let work = start(reader, permit: permit, reset: true) else { return }
        await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
    }
    private func owns(_ reader: any SocialAccountReading, permit: LoadPermit, request: UUID) -> Bool {
        self.permit(reader) == permit && requestID == request
    }
    private func load(_ reader: any SocialAccountReading, permit: LoadPermit, request: UUID, page: Int) async {
        defer {
            if owns(reader, permit: permit, request: request) {
                loading = false; requestID = nil; task = nil
            }
        }
        do {
            try Task.checkCancellation()
            guard owns(reader, permit: permit, request: request) else { return }
            let value = try await reader.invitationHistory(page: page)
            try Task.checkCancellation()
            guard owns(reader, permit: permit, request: request) else { return }
            try pagination.accept(value.page); scan = value.rewardScan
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled, owns(reader, permit: permit, request: request) else { return }
            let kind = ProfileInviteHistoryIssueKind(error)
            if kind == .signIn || kind == .denied { pagination = SocialInvitePagination(); scan = nil }
            self.error = error
        }
    }
}
