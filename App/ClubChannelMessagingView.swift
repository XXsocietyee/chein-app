import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - W6 / G2 Apple-Native Discord-Style Club Channel Messaging, Safety (1.2), and Club Admin Views

/// Embedded Discord-style channel messaging view inside Club Detail (Deliverables 2 & 3, App Store Guideline 1.2).
public struct ClubChannelMessagingView: View {
    public let club: ClubRecord
    public let viewerMemberID: Int
    public let viewerRoleTier: ChannelMemberRoleTier
    public let capabilities: ChannelModerationCapabilities
    @StateObject private var moderationCoordinator: ClubChannelModerationCoordinator
    @State private var directoryProjection: ChannelCategoryDirectoryProjection
    @State private var selectedChannelID: Int64
    @State private var messagesByChannelID: [Int64: [ChannelTranscriptMessage]]
    @State private var viewportState: ChannelTranscriptViewportState
    @State private var sendStateMachine: ChannelSendStateMachine
    @State private var contentFilter: ChannelContentFilterHook
    @State private var pollingSchedule = ChannelPollingBackoffSchedule()
    @State private var memberRoster: [ChannelMemberRoleItem]
    @State private var replyReferences: [Int: ChannelReplyThreadReference] = [:]
    @State private var activeReplyTarget: MessagingMessage?
    @State private var composerText: String = ""
    @State private var showChannelList: Bool
    @State private var showRulesSheet: Bool = false
    @State private var showMemberRosterSheet: Bool = false
    @State private var showReportChannelDialog: Bool = false
    @State private var unreadByChannelID: [Int64: Int] = [:]
    @State private var mentionByChannelID: [Int64: Int] = [:]
    @Environment(\.locale) private var locale
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ugcSafetyContext) private var ugcSafety

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private let rawListing: ChannelDirectoryListing
    private let roleBadgesByMemberID: [Int: String]
    private let safetyService: (any ClubChannelSafetyServing)?

    public init(
        club: ClubRecord,
        viewerMemberID: Int,
        viewerRoleTier: ChannelMemberRoleTier = .member,
        capabilities: ChannelModerationCapabilities = ChannelModerationCapabilities(),
        listing: ChannelDirectoryListing,
        startsInChannelList: Bool = true,
        initialMessages: [ChannelTranscriptMessage] = [],
        initialMessagesByChannelID: [Int64: [ChannelTranscriptMessage]] = [:],
        memberRoster: [ChannelMemberRoleItem] = [],
        mentionCountsByChannelID: [Int64: Int] = [:],
        blockedSenderIDs: Set<Int> = [],
        activeBans: [ChannelModerationBanRecord] = [],
        rulesVersion: Int = 1,
        rulesStore: any ChannelRulesAcceptanceStoring = UserDefaultsChannelRulesAcceptanceStore(),
        blockedUsersStore: any ChannelBlockedUsersStoring = UserDefaultsChannelBlockedUsersStore(),
        safetyService: (any ClubChannelSafetyServing)? = nil
    ) {
        self.club = club
        _showChannelList = State(initialValue: startsInChannelList)
        self.viewerMemberID = viewerMemberID
        self.viewerRoleTier = viewerRoleTier
        self.capabilities = capabilities
        self.rawListing = listing
        self.memberRoster = memberRoster
        self.safetyService = safetyService

        for senderID in blockedSenderIDs where senderID > 0 {
            blockedUsersStore.addBlockedUser(
                targetMemberID: senderID,
                clubID: club.id,
                viewerMemberID: viewerMemberID
            )
        }
        let persistedBlocked = blockedUsersStore.blockedUserIDs(
            clubID: club.id,
            viewerMemberID: viewerMemberID
        ).union(blockedSenderIDs)

        let badges = Dictionary(
            uniqueKeysWithValues: memberRoster.map { ($0.memberID, $0.badgeLabel) }
        )
        self.roleBadgesByMemberID = badges
        let initialProjection = ChannelCategoryDirectoryProjection(
            listing: listing,
            mentionCountsByChannelID: mentionCountsByChannelID
        )
        _directoryProjection = State(initialValue: initialProjection)
        let firstChannelID = initialProjection.groups.first?.channels.first?.id ?? listing.channels.first?.id ?? 1
        _selectedChannelID = State(initialValue: firstChannelID)

        var mergedByChannel = initialMessagesByChannelID
        if mergedByChannel[firstChannelID] == nil && !initialMessages.isEmpty {
            mergedByChannel[firstChannelID] = initialMessages
        }
        _messagesByChannelID = State(initialValue: mergedByChannel)
        let startingMessages = mergedByChannel[firstChannelID] ?? initialMessages
        _viewportState = State(initialValue: ChannelTranscriptViewportState(initialMessages: startingMessages, hasMoreOlderPages: true))
        _sendStateMachine = State(initialValue: ChannelSendStateMachine(conversationID: Int(firstChannelID)))
        _contentFilter = State(initialValue: ChannelContentFilterHook(blockedSenderIDs: persistedBlocked))
        _mentionByChannelID = State(initialValue: mentionCountsByChannelID)

        let initialMuted = Set(
            listing.channels.compactMap { entry in
                entry.myState?.notifyPref == 2 ? entry.id : nil
            }
        )
        _moderationCoordinator = StateObject(
            wrappedValue: ClubChannelModerationCoordinator(
                clubID: club.id,
                viewerMemberID: viewerMemberID,
                viewerRoleTier: viewerRoleTier,
                capabilities: capabilities,
                isChannelAccessRevoked: false,
                rulesVersion: rulesVersion,
                rulesStore: rulesStore,
                blockedUsersStore: blockedUsersStore,
                service: safetyService,
                initialMutedChannelIDs: initialMuted,
                initialActiveBans: activeBans
            )
        )
    }

    private var selectedChannel: ChannelDiscordItemProjection? {
        for group in directoryProjection.groups {
            if let match = group.channels.first(where: { $0.id == selectedChannelID }) {
                return match
            }
        }
        return directoryProjection.groups.first?.channels.first
    }

    private var safetyPolicy: ChannelSafetyModerationPolicy {
        moderationCoordinator.policy
    }

    private var effectiveMemberRoster: [ChannelMemberRoleItem] {
        memberRoster.filter { !moderationCoordinator.removedMemberIDs.contains($0.memberID) }
    }

    private var burstGroups: [ChannelMessageBurstGroup] {
        var machine = sendStateMachine
        let visibleServerMessages = viewportState.messages.filter { item in
            !moderationCoordinator.deletedMessageIDs.contains(item.wireMessage.id)
        }
        let combined = machine.mergedTranscript(serverMessages: visibleServerMessages)
        return ChannelMessageBurstGrouper.group(
            messages: combined,
            roleBadgeByMemberID: roleBadgesByMemberID,
            replyReferencesByMessageID: replyReferences,
            contentFilter: localizedFilter
        )
    }

    private var localizedFilter: ChannelContentFilterHook {
        let globalBlocked = ugcSafety?.blockedStore.blockedMemberIDs ?? []
        return ChannelContentFilterHook(
            blockedSenderIDs: moderationCoordinator.blockedSenderIDs
                .union(contentFilter.blockedSenderIDs)
                .union(globalBlocked),
            mutedKeywords: contentFilter.mutedKeywords,
            maskObjectionableContent: contentFilter.maskObjectionableContent,
            locale: locale
        )
    }

    private var mutedByChannelID: [Int64: Bool] {
        var map: [Int64: Bool] = [:]
        for channel in rawListing.channels {
            map[channel.id] = moderationCoordinator.mutedChannelIDs.contains(channel.id)
        }
        return map
    }

    private var isCompact: Bool { sizeClass != .regular }

    public var body: some View {
        VStack(spacing: 0) {
            if let banner = moderationCoordinator.feedbackBanner {
                moderationBannerView(banner)
            }
            if directoryProjection.groups.isEmpty {
                let emptyTitle = copy("暂无频道", "No channels yet")
                let emptyDesc = copy("主理人创建频道后，这里会显示频道列表。", "Channels will appear here once the club owner creates them.")
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "number",
                    description: Text(verbatim: emptyDesc)
                )
                .frame(maxHeight: .infinity)
            } else if isCompact && showChannelList {
                // iPhone: the channel list is its own screen; the conversation is full width.
                channelCategorySidebar
            } else {
                channelTopBar
                Divider()
                if !moderationCoordinator.hasAcceptedRules && !isReadOnlyForViewer {
                    channelRulesGateRow
                    Divider()
                }
                if isCompact {
                    channelTranscriptColumn
                } else {
                    HStack(spacing: 0) {
                        channelCategorySidebar
                            .frame(width: 260)
                        Divider()
                        channelTranscriptColumn
                    }
                }
            }
        }
        .confirmationDialog(
            copy("举报频道「#\(selectedChannelName)」", "Report channel #\(selectedChannelName)"),
            isPresented: $showReportChannelDialog,
            titleVisibility: .visible
        ) {
            Button(appLocalized("club.channel.report.spam", locale: locale), role: .destructive) {
                submitChannelReport(reasonCode: "SPAM_SCAM", detail: "Spam or scam content in channel")
            }
            Button(appLocalized("club.channel.report.harassment", locale: locale), role: .destructive) {
                submitChannelReport(reasonCode: "HARASSMENT", detail: "Harassment or abusive content in channel")
            }
            Button(appLocalized("club.channel.report.illegal", locale: locale), role: .destructive) {
                submitChannelReport(reasonCode: "OBJECT_CONTENT", detail: "Illegal or objectionable content in channel")
            }
            Button("action.cancel", role: .cancel) {}
        }
        .cySheet(isPresented: $showRulesSheet) {
            NavigationStack {
                List {
                    Section {
                        Text(verbatim: rulesFullText)
                    }
                }
                .navigationTitle(copy("俱乐部频道公约与安全守则", "Club Channel Rules & Safety EULA"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.cancel") { showRulesSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copy("同意", "Accept")) {
                            moderationCoordinator.acceptChannelRules(locale: locale)
                            showRulesSheet = false
                        }
                        .accessibilityLabel(Text(verbatim: copy("我已阅读并同意频道公约", "Accept Channel Rules & EULA")))
                        .accessibilityIdentifier("club.channel.rulesGate.accept")
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .cySheet(isPresented: $showMemberRosterSheet) {
            ClubChannelMemberRosterSheet(
                clubName: club.name,
                sections: ChannelMemberRoleRoster.buildSections(from: effectiveMemberRoster, locale: locale),
                activeChannelID: Int(selectedChannelID),
                coordinator: moderationCoordinator
            )
        }
    }

    @ViewBuilder
    private func moderationBannerView(_ banner: ChannelModerationFeedbackBanner) -> some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                .accessibilityHidden(true)
                .foregroundStyle(banner.isError ? CYColor.dangerText : CYColor.successText)
            Text(banner.message)
                .font(.footnote)
            Spacer()
            if banner.canRetry {
                Button(copy("重试", "Retry")) {
                    Task {
                        _ = await moderationCoordinator.retryLastFailedAction(locale: locale)
                        refreshDirectoryProjection()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("club.channel.moderation.retryButton")
            }
            Button(copy("关闭", "Dismiss")) {
                moderationCoordinator.clearBanner()
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, CYSpacing.sm)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.channel.moderation.banner")
    }

    private var selectedChannelName: String { selectedChannel?.name ?? "" }

    /// mp-club r3 pass 27 (sweep ad55acd94, d4-channel-chat): in a read-only announcement channel a member cannot post,
    /// so the rules gate (which only unlocks posting) is not asked twice; the composer says who can post instead.
    private var isReadOnlyForViewer: Bool {
        selectedChannel?.isReadOnlyAnnouncement == true && !safetyPolicy.canModerateMessages
    }

    private var composerPlaceholder: String {
        guard let name = selectedChannel?.name else { return copy("发送消息…", "Message…") }
        return copy("在 #\(name) 发送消息…", "Message #\(name)…")
    }

    private func replyLine(_ target: MessagingMessage) -> String {
        let id = target.senderID ?? 0
        let name = target.senderName ?? copy("成员 #\(id)", "Member #\(id)")
        let body = target.content ?? ""
        return copy("回复 \(name)：\(body)", "Replying to \(name): \(body)")
    }

    private var rulesFullText: String {
        copy(
            "参与频道发言与治理前，请确认遵守社区安全准则：严禁发布违法违规、骚扰辱骂、欺诈广告及令人反感的内容。被举报内容将在 24 小时内由安全团队审核并处理，违规成员将被删帖并移出或封禁。", "Before posting or moderating, you must agree to our zero-tolerance policy against objectionable content, harassment, and spam. Reported content is reviewed within 24 hours and violators will be removed or banned."
        )
    }

    /// One compact row; the full EULA text opens in a sheet. Accepting stays mandatory before posting.
    private var channelRulesGateRow: some View {
        ViewThatFits(in: .horizontal) {
            rulesRowContent(horizontal: true)
            rulesRowContent(horizontal: false)
        }
        .padding(.horizontal)
        .padding(.vertical, CYSpacing.sm)
        .background(.bar)
        .accessibilityIdentifier("club.channel.rulesGate")
    }

    @ViewBuilder private func rulesRowContent(horizontal: Bool) -> some View {
        let label = Label {
            Text(copy("发言前请先阅读频道公约", "Review the channel rules to post"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(horizontal ? 1 : nil)
                .fixedSize(horizontal: !horizontal ? false : true, vertical: true)
        } icon: {
            Image(systemName: "hand.raised.shield.fill").foregroundStyle(.orange)
        }
        let button = Button {
            showRulesSheet = true
        } label: {
            Text(copy("查看公约", "Review rules"))
                .frame(maxWidth: horizontal ? nil : .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(horizontal ? .small : .regular)
        .accessibilityIdentifier("club.channel.rulesGate.review")
        if horizontal {
            HStack(spacing: CYSpacing.sm) { label; Spacer(minLength: CYSpacing.sm); button }
        } else {
            VStack(alignment: .leading, spacing: CYSpacing.sm) { label; button }
        }
    }

    // MARK: - Top Header Bar

    private var channelTopBar: some View {
        HStack(spacing: CYSpacing.sm) {
            if isCompact {
                Button {
                    showChannelList = true
                } label: {
                    Image(systemName: "list.bullet")
                        .imageScale(.large)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(copy("频道列表", "Channel list"))
                .accessibilityIdentifier("club.channel.backToList")
            }

            if let channel = selectedChannel {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: channel.symbolName)
                            .accessibilityHidden(true)
                            .foregroundStyle(.secondary)
                        Text(channel.name)
                            .font(.headline)
                            .cyWrapText()
                    }
                    if channel.isReadOnlyAnnouncement {
                        Text(copy("公告 · 只读", "Announcement · read only"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if channel.isMuted {
                        Text(copy("已开启免打扰", "Muted"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .cyWrapText()
                    }
                }
            }

            Spacer(minLength: CYSpacing.sm)

            Menu {
                Button {
                    guard let channel = selectedChannel else { return }
                    let nextMuted = !channel.isMuted
                    Task {
                        let ok = await moderationCoordinator.muteChannel(
                            conversationID: Int(channel.id),
                            muted: nextMuted,
                            locale: locale
                        )
                        if ok { refreshDirectoryProjection() }
                    }
                } label: {
                    Label(selectedChannel?.isMuted == true ? copy("取消频道免打扰", "Unmute channel") : copy("频道免打扰", "Mute channel"),
                          systemImage: selectedChannel?.isMuted == true ? "bell.slash.fill" : "bell")
                }
                .accessibilityIdentifier("club.channel.muteButton")

                Button {
                    showMemberRosterSheet = true
                } label: {
                    Label(copy("频道成员与身份组 · \(effectiveMemberRoster.count)", "Members & roles · \(effectiveMemberRoster.count)"),
                          systemImage: "person.2")
                }
                .accessibilityIdentifier("club.channel.memberRosterButton")

                Button(role: .destructive) {
                    showReportChannelDialog = true
                } label: {
                    Label(copy("举报当前频道", "Report channel"), systemImage: "flag")
                }
                .accessibilityLabel(Text(verbatim: copy("举报当前频道", "Report channel")))
                .accessibilityIdentifier("club.channel.reportChannelButton")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(copy("更多", "More"))
            .accessibilityIdentifier("club.channel.overflowMenu")
        }
        .padding(.horizontal)
        .padding(.vertical, CYSpacing.xs)
        .background(.bar)
    }

    // MARK: - Category-Grouped Sidebar

    private var channelCategorySidebar: some View {
        List {
            ForEach(directoryProjection.groups) { group in
                Section {
                    ForEach(group.channels) { channel in
                        channelSidebarRow(channel)
                    }
                } header: {
                    HStack {
                        Text(group.title)
                        Spacer()
                        if group.totalMentionCount > 0 {
                            Text(verbatim: "@\(group.totalMentionCount)")
                                .monospacedDigit()
                                .foregroundStyle(CYColor.dangerText)
                        }
                    }
                }
            }
        }
    }

    private func channelSidebarRow(_ channel: ChannelDiscordItemProjection) -> some View {
        let isSelected = channel.id == selectedChannelID
        let isUnread = (channel.unreadCount ?? 0) > 0 && !channel.isMuted
        let badgeText = channel.mentionBadgeText ?? channel.unreadBadgeText
        return Button {
            selectChannel(channel.id)
        } label: {
            HStack {
                Label {
                    Text(channel.name)
                        .fontWeight(isUnread ? .semibold : .regular)
                        .cyWrapText()
                } icon: {
                    Image(systemName: channel.symbolName)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .foregroundStyle(.primary)
                Spacer()
                if badgeText == nil && channel.isMuted {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .badge(badgeText.map { Text(verbatim: $0) })
        .listRowBackground(isSelected ? Color(uiColor: .tertiarySystemFill) : nil)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    _ = await moderationCoordinator.reportChannel(
                        channelID: Int(channel.id),
                        channelName: channel.name,
                        reasonCode: "OBJECT_CONTENT",
                        detail: "Reported channel #\(channel.name)",
                        locale: locale
                    )
                }
            } label: {
                Label(copy("举报该频道", "Report channel"), systemImage: "flag")
            }
            .accessibilityLabel(Text(verbatim: copy("举报该频道", "Report channel")))
            .accessibilityIdentifier("club.channel.report")
        }
    }

    // MARK: - Transcript + Paging Up + New-Message Jump + Composer

    private var channelTranscriptColumn: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: CYSpacing.xl) {
                            if viewportState.hasMoreOlderPages {
                                Button {
                                    viewportState.prependOlderPage([], hasMore: false, currentTopVisibleMessageID: viewportState.oldestCursorID)
                                } label: {
                                    Label(copy("加载更早的频道消息", "Load earlier messages"), systemImage: "arrow.up.circle")
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity)
                                    .frame(minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.borderless)
                            }

                            if burstGroups.isEmpty {
                                let emptyTitle = copy("还没有消息", "No messages yet")
                                let emptyDesc = copy("发送第一条消息，开启这个频道的讨论。", "Send the first message to start the conversation.")
                                ContentUnavailableView(
                                    emptyTitle,
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text(verbatim: emptyDesc)
                                )
                                .frame(maxWidth: .infinity, minHeight: 200)
                            }

                            ForEach(burstGroups) { group in
                                ChannelBurstGroupCard(
                                    group: group,
                                    viewerMemberID: viewerMemberID,
                                    policy: safetyPolicy,
                                    onReply: { target in
                                        activeReplyTarget = target
                                    },
                                    onRetrySend: { clientMessageID in
                                        retryFailedMessage(clientMessageID: clientMessageID)
                                    },
                                    onReportMessage: { msg in
                                        Task {
                                            _ = await moderationCoordinator.reportMessage(
                                                message: msg,
                                                reason: "Objectionable content",
                                                activeChannelID: Int(selectedChannelID),
                                                locale: locale
                                            )
                                        }
                                    },
                                    onBlockAuthor: { authorID in
                                        let nickname = effectiveMemberRoster.first(where: { $0.memberID == authorID })?.nickname
                                            ?? copy("成员 #\(authorID)", "Member #\(authorID)")
                                        Task {
                                            let didBlock = await moderationCoordinator.blockUser(
                                                targetMemberID: authorID,
                                                nickname: nickname,
                                                shouldBlock: true,
                                                activeChannelID: Int(selectedChannelID),
                                                locale: locale
                                            )
                                            if didBlock {
                                                ugcSafety?.blockedStore.recordLocalBlock(memberID: authorID, authorName: nickname)
                                            }
                                        }
                                    },
                                    onDeleteMessage: { msg in
                                        Task {
                                            _ = await moderationCoordinator.deleteMessage(
                                                channelID: Int(selectedChannelID),
                                                message: msg,
                                                locale: locale
                                            )
                                        }
                                    }
                                )
                            }
                        }
                        .padding(CYSpacing.lg)
                    }
                    .onChange(of: viewportState.pendingNewMessageCount) { _, _ in
                        if viewportState.isNearBottom, let lastID = burstGroups.last?.items.last?.id {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                if viewportState.showNewMessageJumpBanner {
                    Button {
                        _ = viewportState.jumpToBottomClearingNewMessages()
                    } label: {
                        Label(
                            copy("\(viewportState.pendingNewMessageCount) 条新消息 · 点击跳转到底部", "\(viewportState.pendingNewMessageCount) new messages · Jump to present"),
                            systemImage: "arrow.down.circle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .frame(minHeight: 44)
                    .padding(.bottom, 10)
                }
            }

            Divider()
            channelComposerBar
                .background(.bar)
        }
    }

    private var channelComposerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let replyTarget = activeReplyTarget {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .accessibilityHidden(true).font(.caption)
                        .foregroundStyle(.tint)
                    Text(replyLine(replyTarget))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button {
                        activeReplyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(copy("取消回复", "Cancel reply"))
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }

            if !moderationCoordinator.hasAcceptedRules && !isReadOnlyForViewer {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .accessibilityHidden(true).foregroundStyle(.orange)
                    Text(copy("请先在上方阅读并同意《俱乐部频道公约》后再发言。", "Please accept the Channel Rules & EULA above before sending messages."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .accessibilityIdentifier("club.channel.composer.rulesLocked")
            } else if isReadOnlyForViewer {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone")
                        .accessibilityHidden(true).foregroundStyle(.secondary)
                    Text(copy("当前为公告频道，仅主理人与管理员可发布通知", "This is an announcement channel. Only club owners and admins can post notices."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 8) {
                    TextField(composerPlaceholder, text: $composerText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        sendOptimisticChannelMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(copy("发送", "Send"))
                    .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Actions

    private func submitChannelReport(reasonCode: String, detail: String) {
        guard let channel = selectedChannel else { return }
        Task {
            _ = await moderationCoordinator.reportChannel(
                channelID: Int(channel.id),
                channelName: channel.name,
                reasonCode: reasonCode,
                detail: detail,
                locale: locale
            )
        }
    }

    private func selectChannel(_ channelID: Int64) {
        showChannelList = false
        messagesByChannelID[selectedChannelID] = viewportState.messages
        selectedChannelID = channelID
        unreadByChannelID[channelID] = 0
        mentionByChannelID[channelID] = 0
        let nextMessages = messagesByChannelID[channelID] ?? []
        viewportState = ChannelTranscriptViewportState(initialMessages: nextMessages, hasMoreOlderPages: true)
        sendStateMachine = ChannelSendStateMachine(conversationID: Int(channelID))
        refreshDirectoryProjection()
    }

    private func refreshDirectoryProjection() {
        directoryProjection = ChannelCategoryDirectoryProjection(
            listing: rawListing,
            mentionCountsByChannelID: mentionByChannelID,
            mutedOverrideByChannelID: mutedByChannelID,
            unreadOverrideByChannelID: unreadByChannelID,
            locale: locale
        )
    }

    private func sendOptimisticChannelMessage() {
        guard moderationCoordinator.hasAcceptedRules else { return }
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let replyID = activeReplyTarget?.id
        let body: String
        if let reply = activeReplyTarget {
            body = "> #\(reply.id) \(trimmed)"
        } else {
            body = trimmed
        }
        let channelID = Int(selectedChannelID)
        // One stable 32-hex idempotency id per draft; retries reuse it (see CoreClubChannelSafetyService.sendChannelMessage).
        let clientID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        _ = sendStateMachine.enqueueOptimistic(
            clientMessageID: clientID,
            senderID: viewerMemberID,
            content: body,
            replyToMessageID: replyID
        )
        _ = sendStateMachine.markSending(clientMessageID: clientID)
        composerText = ""
        activeReplyTarget = nil

        Task {
            await dispatchOutboundMessage(
                channelID: channelID,
                clientMessageID: clientID,
                content: body,
                replyToMessageID: replyID
            )
        }
    }

    private func retryFailedMessage(clientMessageID: String) {
        guard let existing = sendStateMachine.recordsByClientID[clientMessageID] else { return }
        guard sendStateMachine.beginRetryWithReceiptCheck(clientMessageID: clientMessageID) else { return }
        _ = sendStateMachine.resolveRetryAfterReceiptCheck(
            clientMessageID: clientMessageID,
            receiptResult: .notFound
        )
        let channelID = Int(selectedChannelID)
        Task {
            await dispatchOutboundMessage(
                channelID: channelID,
                clientMessageID: clientMessageID,
                content: existing.content,
                replyToMessageID: existing.replyToMessageID
            )
        }
    }

    private func dispatchOutboundMessage(
        channelID: Int,
        clientMessageID: String,
        content: String,
        replyToMessageID: Int?
    ) async {
        guard let safetyService else {
            _ = sendStateMachine.markFailed(
                clientMessageID: clientMessageID,
                reason: copy("发信服务不可用", "Send service unavailable")
            )
            return
        }
        do {
            let serverID = try await safetyService.sendChannelMessage(
                clubID: club.id,
                channelID: channelID,
                clientMessageID: clientMessageID,
                content: content,
                replyToMessageID: replyToMessageID
            )
            let serverMessage = ChannelTranscriptMessage.make(
                id: max(serverID, 1),
                conversationID: max(channelID, 1),
                senderID: viewerMemberID,
                type: 1,
                content: content,
                clientMessageID: clientMessageID
            ).wireMessage
            _ = sendStateMachine.markSent(clientMessageID: clientMessageID, serverMessage: serverMessage)
        } catch {
            _ = sendStateMachine.markFailed(
                clientMessageID: clientMessageID,
                reason: copy("发送失败，请重试", "Send failed, please retry")
            )
        }
    }
}

// MARK: - Author/Time Burst Card

private struct ChannelBurstGroupCard: View {
    let group: ChannelMessageBurstGroup
    let viewerMemberID: Int
    let policy: ChannelSafetyModerationPolicy
    let onReply: (MessagingMessage) -> Void
    let onRetrySend: (String) -> Void
    let onReportMessage: (MessagingMessage) -> Void
    let onBlockAuthor: (Int) -> Void
    let onDeleteMessage: (MessagingMessage) -> Void
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .subheadline) private var initialSide: CGFloat = 28

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dividerText = group.precedingDividerText {
                HStack {
                    VStack { Divider() }
                    Text(dividerText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(spacing: CYSpacing.sm) {
                    Circle()
                        .fill(group.isSystemGroup ? Color.orange.opacity(0.2) : Color(uiColor: .systemGray5))
                        .frame(width: min(initialSide, 48), height: min(initialSide, 48))
                        .overlay(
                            Text(String(group.senderName.prefix(1)))
                                .font(.subheadline.weight(.medium))
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(group.isSystemGroup ? Color.orange : Color.primary)
                        )
                        .accessibilityHidden(true)
                    Text(group.senderName)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge = group.senderRoleBadge, !badge.isEmpty {
                        Text(badge)
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                    Text(group.headerTimestampText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .cyWrapText()
                }

                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(group.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            if let reply = item.replyReference {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrowshape.turn.up.left")
                                        .accessibilityHidden(true).font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(verbatim: "\(reply.replyAuthorName): \(reply.replyPreviewText)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if reply.threadReplyCount > 1 {
                                        Text(copy("\(reply.threadReplyCount) 条串内回复", "\(reply.threadReplyCount) thread replies"))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }

                            Text(item.displayBody)
                                .font(.body)
                                .foregroundStyle(item.message.isPayloadVisible ? Color.primary : Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(Array(item.attachments.enumerated()), id: \.offset) { _, attachment in
                                HStack(spacing: 6) {
                                    Image(systemName: attachment.kind == .image ? "photo" : "link")
                                        .accessibilityHidden(true).font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(attachment.title)
                                        .font(.subheadline)
                                        .cyWrapText()
                                    if let sub = attachment.subtitle, !sub.isEmpty {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

                            if let sendState = item.transcriptMessage.sendState {
                                HStack(spacing: 6) {
                                    switch sendState {
                                    case ChannelOutboundSendPhase.pending.rawValue,
                                         ChannelOutboundSendPhase.sending.rawValue,
                                         ChannelOutboundSendPhase.verifyingReceipt.rawValue:
                                        ProgressView()
                                            .controlSize(.mini)
                                        Text(sendState == ChannelOutboundSendPhase.verifyingReceipt.rawValue ? copy("正在校验发送回执…", "Verifying send receipt…") : copy("发送中…", "Sending…"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    case ChannelOutboundSendPhase.failed.rawValue:
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .accessibilityHidden(true).foregroundStyle(.red)
                                            .font(.caption)
                                        Text(copy("发送失败", "Failed to send"))
                                            .font(.caption)
                                            .foregroundStyle(CYColor.dangerText)
                                        if let cid = item.transcriptMessage.clientMessageID {
                                            Button(copy("重试（先核对回执）", "Retry (check receipt first)")) {
                                                onRetrySend(cid)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .buttonStyle(.borderless)
                                        }
                                    default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        .id(item.id)
                        .contextMenu {
                            Button {
                                onReply(item.message)
                            } label: {
                                Label(copy("回复 / 串联讨论", "Reply / Start thread"), systemImage: "arrowshape.turn.up.left")
                            }

                            let senderID = item.message.senderID ?? 0
                            if senderID != viewerMemberID && senderID > 0 {
                                Button(role: .destructive) {
                                    onReportMessage(item.message)
                                } label: {
                                    Label(copy("举报该消息", "Report message"), systemImage: "exclamationmark.bubble")
                                }
                                .accessibilityLabel(Text(verbatim: copy("举报该消息", "Report message")))
                                .accessibilityIdentifier("club.channel.message.report")

                                Button(role: .destructive) {
                                    onBlockAuthor(senderID)
                                } label: {
                                    Label(copy("拉黑该用户", "Block user"), systemImage: "hand.raised.fill")
                                }
                                .accessibilityLabel(Text(verbatim: copy("拉黑该用户", "Block user")))
                                .accessibilityIdentifier("club.channel.message.block")
                            }

                            if senderID == viewerMemberID || policy.canModerateMessages {
                                Button(role: .destructive) {
                                    onDeleteMessage(item.message)
                                } label: {
                                    Label(senderID == viewerMemberID ? copy("撤回消息", "Recall message") : copy("管理员删除消息", "Delete message (admin)"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Member List with Roles & Safety/Moderation Sheet

public struct ClubChannelMemberRosterSheet: View {
    public let clubName: String
    public let sections: [ChannelMemberRoleSection]
    public let activeChannelID: Int
    @ObservedObject public var coordinator: ClubChannelModerationCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .subheadline) private var initialSide: CGFloat = 32

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    public init(
        clubName: String,
        sections: [ChannelMemberRoleSection],
        activeChannelID: Int,
        coordinator: ClubChannelModerationCoordinator
    ) {
        self.clubName = clubName
        self.sections = sections
        self.activeChannelID = activeChannelID
        self.coordinator = coordinator
    }

    public var body: some View {
        let policy = coordinator.policy
        NavigationStack {
                List {
                    if let banner = coordinator.feedbackBanner {
                        Section {
                            Label {
                                Text(banner.message)
                            } icon: {
                                Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                                    .foregroundStyle(banner.isError ? CYColor.dangerText : CYColor.successText)
                            }
                            if banner.canRetry {
                                Button(copy("重试", "Retry")) {
                                    Task {
                                        _ = await coordinator.retryLastFailedAction(locale: locale)
                                    }
                                }
                                .accessibilityIdentifier("club.channel.roster.retryButton")
                            }
                            Button(copy("关闭", "Dismiss")) {
                                coordinator.clearBanner()
                            }
                        }
                    }

                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.members) { member in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color(uiColor: .systemGray5))
                                        .frame(width: min(initialSide, 52), height: min(initialSide, 52))
                                        .overlay(
                                            Text(String(member.nickname.prefix(1)))
                                                .font(.subheadline.weight(.semibold))
                                                .minimumScaleFactor(0.5)
                                        )
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(member.nickname)
                                            Text(member.badgeLabel)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if coordinator.blockedSenderIDs.contains(member.memberID) {
                                                Text(copy("已拉黑", "Blocked"))
                                                    .font(.caption)
                                                    .foregroundStyle(CYColor.dangerText)
                                            }
                                        }
                                        if let expires = member.expiresText, !expires.isEmpty {
                                            Text(copy("角色有效期至 \(expires)", "Role valid until \(expires)"))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if member.memberID != policy.viewerMemberID {
                                        let isBlocked = coordinator.blockedSenderIDs.contains(member.memberID)
                                        Button(isBlocked ? copy("取消拉黑", "Unblock") : copy("拉黑", "Block")) {
                                            Task {
                                                _ = await coordinator.blockUser(
                                                    targetMemberID: member.memberID,
                                                    nickname: member.nickname,
                                                    shouldBlock: !isBlocked,
                                                    activeChannelID: activeChannelID,
                                                    locale: locale
                                                )
                                            }
                                        }
                                        .tint(.orange)
                                        .accessibilityLabel(Text(verbatim: isBlocked ? copy("取消拉黑", "Unblock") : copy("拉黑", "Block")))
                                        .accessibilityIdentifier("club.channel.roster.block")

                                        Button(copy("举报", "Report")) {
                                            Task {
                                                _ = await coordinator.reportUser(
                                                    targetMemberID: member.memberID,
                                                    nickname: member.nickname,
                                                    reasonCode: "HARASSMENT",
                                                    detail: "Channel member report",
                                                    activeChannelID: activeChannelID,
                                                    locale: locale
                                                )
                                            }
                                        }
                                        .tint(.yellow)
                                        .accessibilityLabel(Text(verbatim: copy("举报", "Report")))
                                        .accessibilityIdentifier("club.channel.roster.report")

                                        if policy.canRemoveOrBanMembers {
                                            Button(copy("移除", "Remove"), role: .destructive) {
                                                Task {
                                                    _ = await coordinator.removeMember(
                                                        target: member,
                                                        activeChannelID: activeChannelID,
                                                        locale: locale
                                                    )
                                                }
                                            }

                                            Button(copy("封禁", "Ban"), role: .destructive) {
                                                Task {
                                                    _ = await coordinator.banMember(
                                                        target: member,
                                                        reasonCode: "HARASSMENT",
                                                        reasonText: "Banned by club administrator for violating channel safety rules",
                                                        activeChannelID: activeChannelID,
                                                        locale: locale
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if policy.canRemoveOrBanMembers && !coordinator.activeBans.isEmpty {
                        Section(copy("封禁名单（管理员）", "Active Bans (Admin)")) {
                            ForEach(coordinator.activeBans) { ban in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(ban.nickname)
                                            Text(ban.platformOnly ? copy("平台封禁", "Platform Ban") : copy("俱乐部封禁", "Club Ban"))
                                                .font(.caption)
                                                .foregroundStyle(CYColor.dangerText)
                                        }
                                        Text(verbatim: "\(ban.reasonCode): \(ban.reasonText)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(copy("解除封禁", "Unban")) {
                                        Task {
                                            _ = await coordinator.unbanMember(
                                                banRow: ban,
                                                reason: "Unbanned by club admin",
                                                activeChannelID: activeChannelID,
                                                locale: locale
                                            )
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(ban.platformOnly)
                                }
                            }
                        }
                    }
                }
            .navigationTitle(copy("\(clubName) · 成员与身份组", "\(clubName) · Members & Roles"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy("完成", "Done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Club Detail Host Entry (`ClubChannelMessagingHostView`)

/// Loads club member roster and real channel directory via `ClubReading` and injected `ClubChannelSafetyServing`,
/// with loading, empty, and error-with-retry states built on `App/DesignSystem`.
@MainActor
public struct ClubChannelMessagingHostView<Reader: ClubReading>: View {
    public let club: ClubRecord
    public let reader: Reader
    public let manageGrant: ClubDetailManageGrant?
    public let safetyService: (any ClubChannelSafetyServing)?
    public let rulesStore: any ChannelRulesAcceptanceStoring
    public let blockedUsersStore: any ChannelBlockedUsersStoring
    public var onSignIn: (() -> Void)?

    private struct LoadedContext {
        let workspace: ClubChannelWorkspacePayload
        let roster: [ChannelMemberRoleItem]
        let viewerMemberID: Int
        let viewerTier: ChannelMemberRoleTier
        let capabilities: ChannelModerationCapabilities
    }

    @State private var phase: CYPhase<LoadedContext, String> = .loading
    @State private var reloadRevision: UInt64 = 0
    @Environment(\.locale) private var locale

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    public init(
        club: ClubRecord,
        reader: Reader,
        manageGrant: ClubDetailManageGrant? = nil,
        safetyService: (any ClubChannelSafetyServing)? = nil,
        rulesStore: any ChannelRulesAcceptanceStoring = UserDefaultsChannelRulesAcceptanceStore(),
        blockedUsersStore: any ChannelBlockedUsersStoring = UserDefaultsChannelBlockedUsersStore(),
        onSignIn: (() -> Void)? = nil
    ) {
        self.club = club
        self.reader = reader
        self.manageGrant = manageGrant
        self.safetyService = safetyService
        self.rulesStore = rulesStore
        self.blockedUsersStore = blockedUsersStore
        self.onSignIn = onSignIn
    }

    public var body: some View {
        Group {
            switch phase {
            case .idle, .loading, .empty:
                ProgressView {
                    Text(copy("正在加载俱乐部频道…", "Loading club channels…"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("club.channels.loading")

            case let .failed(message, _):
                let titleText = copy("暂时无法加载频道", "Couldn't load channels")
                let retryText = copy("重试", "Retry")
                ContentUnavailableView {
                    Label(titleText, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(verbatim: message)
                } actions: {
                    Button(retryText) { reloadRevision &+= 1 }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("club.channels.error")

            case let .loaded(context):
                let workspace = context.workspace, roster = context.roster, viewerMemberID = context.viewerMemberID
                let viewerTier = context.viewerTier, capabilities = context.capabilities
                let firstChannelID = workspace.listing.channels.first?.id ?? 1
                ClubChannelMessagingView(
                    club: club,
                    viewerMemberID: viewerMemberID,
                    viewerRoleTier: viewerTier,
                    capabilities: capabilities,
                    listing: workspace.listing,
                    initialMessages: workspace.initialMessagesByChannelID[firstChannelID] ?? [],
                    initialMessagesByChannelID: workspace.initialMessagesByChannelID,
                    memberRoster: roster,
                    activeBans: workspace.activeBans,
                    rulesVersion: workspace.rulesVersion,
                    rulesStore: rulesStore,
                    blockedUsersStore: blockedUsersStore,
                    safetyService: safetyService
                )
                .accessibilityIdentifier("club.channels.ready")
            }
        }
        .navigationTitle(copy("\(club.name) · 频道", "\(club.name) · Channels"))
        .navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome()
        .task(id: reloadRevision) {
            await loadChannelContext()
        }
    }

    private func loadChannelContext() async {
        phase = .loading
        let identity = reader.clubIdentity
        guard identity.isSignedIn, (club.isOwner || club.isJoined) else {
            phase = .failed(copy("加入俱乐部后即可访问频道消息。", "Join the club to access channel messages."), retry: nil)
            return
        }
        let viewerID = max(1, identity.accountID ?? 1)
        let viewerTier: ChannelMemberRoleTier
        let capabilities: ChannelModerationCapabilities
        if club.isOwner {
            viewerTier = .owner
            capabilities = ChannelModerationCapabilities(
                canManageMembers: true,
                canManageBans: true,
                canManageContent: true,
                canManageRoles: true
            )
        } else if club.viewerIsAdmin || manageGrant?.allowsManage == true {
            viewerTier = .operatorAdmin
            capabilities = ChannelModerationCapabilities(
                canManageMembers: true,
                canManageBans: true,
                canManageContent: true,
                canManageRoles: false
            )
        } else {
            viewerTier = .member
            capabilities = ChannelModerationCapabilities()
        }

        var mappedRoster: [ChannelMemberRoleItem] = []
        do {
            let memberDir = try await reader.clubMembers(id: club.id) { [weak reader] in
                reader?.clubIdentity == identity
            }
            guard !Task.isCancelled, reader.clubIdentity == identity else { return }
            mappedRoster = memberDir.members.map { member in
                let tier: ChannelMemberRoleTier
                let code: String
                let badge: String
                if member.isOwner {
                    tier = .owner
                    code = "CLUB_OWNER"
                    badge = copy("主理人", "Owner")
                } else if member.isAdmin {
                    tier = .operatorAdmin
                    code = "CLUB_OPERATOR"
                    badge = copy("管理员", "Admin")
                } else {
                    tier = .member
                    code = "MEMBER"
                    badge = copy("成员", "Member")
                }
                return ChannelMemberRoleItem(
                    memberID: member.memberId,
                    nickname: member.trimmedNickname ?? copy("成员 #\(member.memberId)", "Member #\(member.memberId)"),
                    avatar: member.avatar ?? "",
                    tier: tier,
                    roleCode: code,
                    badgeLabel: badge
                )
            }
        } catch is CancellationError {
            return
        } catch let failure as ClubReadFailure where failure.isUnauthorized {
            onSignIn?()
            phase = .failed(copy("登录状态已失效，请重新登录后重试。", "Your session expired. Please sign in again."), retry: nil)
            return
        } catch {
            mappedRoster = [
                ChannelMemberRoleItem(
                    memberID: viewerID,
                    nickname: club.isOwner ? (club.leaderName ?? copy("主理人", "Owner")) : copy("成员 #\(viewerID)", "Member #\(viewerID)"),
                    tier: viewerTier,
                    roleCode: viewerTier == .owner ? "CLUB_OWNER" : (viewerTier == .operatorAdmin ? "CLUB_OPERATOR" : "MEMBER"),
                    badgeLabel: viewerTier.sectionTitle(locale: locale)
                )
            ]
        }

        guard let safetyService else {
            phase = .failed(
                ChannelSafetyServiceError.channelDirectoryUnavailable.localizedDescription(locale: locale), retry: nil
            )
            return
        }

        do {
            let workspace = try await safetyService.loadChannelWorkspace(club: club, viewerMemberID: viewerID)
            guard !Task.isCancelled, reader.clubIdentity == identity else { return }
            phase = .loaded(LoadedContext(
                workspace: workspace,
                roster: mappedRoster,
                viewerMemberID: viewerID,
                viewerTier: viewerTier,
                capabilities: capabilities
            ))
        } catch is CancellationError {
            return
        } catch let serviceError as ChannelSafetyServiceError {
            phase = .failed(serviceError.localizedDescription(locale: locale), retry: nil)
        } catch {
            phase = .failed(copy("无法加载俱乐部频道列表，请点击重试。", "Failed to load club channels. Tap Retry to try again."), retry: nil)
        }
    }
}
