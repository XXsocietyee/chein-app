import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - W6 Apple-Native Discord-Style Club Channel Messaging, Safety (1.2), and Club Admin Views

/// Embedded Discord-style channel messaging view inside Club Detail (Deliverables 2 & 3, no new top-level pages).
public struct ClubChannelMessagingView: View {
    public let club: ClubRecord
    public let viewerMemberID: Int
    public let viewerRoleTier: ChannelMemberRoleTier
    public let capabilities: ChannelModerationCapabilities
    @State private var directoryProjection: ChannelCategoryDirectoryProjection
    @State private var selectedChannelID: Int64
    @State private var viewportState: ChannelTranscriptViewportState
    @State private var sendStateMachine: ChannelSendStateMachine
    @State private var contentFilter: ChannelContentFilterHook
    @State private var pollingSchedule = ChannelPollingBackoffSchedule()
    @State private var memberRoster: [ChannelMemberRoleItem]
    @State private var replyReferences: [Int: ChannelReplyThreadReference] = [:]
    @State private var activeReplyTarget: MessagingMessage?
    @State private var composerText: String = ""
    @State private var showChannelSidebar: Bool = true
    @State private var showMemberRosterSheet: Bool = false
    @State private var activeSafetyBanner: String?
    @State private var mutedByChannelID: [Int64: Bool] = [:]
    @State private var unreadByChannelID: [Int64: Int] = [:]
    @State private var mentionByChannelID: [Int64: Int] = [:]
    @Environment(\.locale) private var locale

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private let rawListing: ChannelDirectoryListing
    private let roleBadgesByMemberID: [Int: String]

    public init(
        club: ClubRecord,
        viewerMemberID: Int,
        viewerRoleTier: ChannelMemberRoleTier = .member,
        capabilities: ChannelModerationCapabilities = ChannelModerationCapabilities(),
        listing: ChannelDirectoryListing,
        initialMessages: [ChannelTranscriptMessage] = [],
        memberRoster: [ChannelMemberRoleItem] = [],
        mentionCountsByChannelID: [Int64: Int] = [:],
        blockedSenderIDs: Set<Int> = []
    ) {
        self.club = club
        self.viewerMemberID = viewerMemberID
        self.viewerRoleTier = viewerRoleTier
        self.capabilities = capabilities
        self.rawListing = listing
        self.memberRoster = memberRoster
        let badges = Dictionary(
            uniqueKeysWithValues: memberRoster.map { ($0.memberID, $0.badgeLabel) }
        )
        self.roleBadgesByMemberID = badges
        let initialProjection = ChannelCategoryDirectoryProjection(
            listing: listing,
            mentionCountsByChannelID: mentionCountsByChannelID
        )
        _directoryProjection = State(initialValue: initialProjection)
        let firstChannelID = initialProjection.groups.first?.channels.first?.id ?? 1
        _selectedChannelID = State(initialValue: firstChannelID)
        _viewportState = State(initialValue: ChannelTranscriptViewportState(initialMessages: initialMessages, hasMoreOlderPages: true))
        _sendStateMachine = State(initialValue: ChannelSendStateMachine(conversationID: Int(firstChannelID)))
        _contentFilter = State(initialValue: ChannelContentFilterHook(blockedSenderIDs: blockedSenderIDs))
        _mentionByChannelID = State(initialValue: mentionCountsByChannelID)
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
        ChannelSafetyModerationPolicy(
            clubID: club.id,
            viewerMemberID: viewerMemberID,
            viewerRoleTier: viewerRoleTier,
            capabilities: capabilities
        )
    }

    private var burstGroups: [ChannelMessageBurstGroup] {
        var machine = sendStateMachine
        let combined = machine.mergedTranscript(serverMessages: viewportState.messages)
        return ChannelMessageBurstGrouper.group(
            messages: combined,
            roleBadgeByMemberID: roleBadgesByMemberID,
            replyReferencesByMessageID: replyReferences,
            contentFilter: localizedFilter
        )
    }

    private var localizedFilter: ChannelContentFilterHook {
        ChannelContentFilterHook(
            blockedSenderIDs: contentFilter.blockedSenderIDs,
            mutedKeywords: contentFilter.mutedKeywords,
            maskObjectionableContent: contentFilter.maskObjectionableContent,
            locale: locale
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            channelTopBar
            Divider()
            if let activeSafetyBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text(activeSafetyBanner)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(copy("关闭", "Dismiss")) {
                        self.activeSafetyBanner = nil
                    }
                    .frame(minHeight: 44)
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.12))
                .accessibilityElement(children: .combine)
            }
            if directoryProjection.groups.isEmpty {
                ContentUnavailableView(
                    copy("暂无频道", "No channels yet"),
                    systemImage: "number",
                    description: Text(copy("主理人创建频道后，这里会显示频道列表。", "Channels will appear here once the club owner creates them."))
                )
                .frame(maxHeight: .infinity)
            } else {
            HStack(spacing: 0) {
                if showChannelSidebar {
                    channelCategorySidebar
                        .frame(width: 210)
                    Divider()
                }
                channelTranscriptColumn
            }
            }
        }
        .sheet(isPresented: $showMemberRosterSheet) {
            ClubChannelMemberRosterSheet(
                clubName: club.name,
                sections: ChannelMemberRoleRoster.buildSections(from: memberRoster, locale: locale),
                policy: safetyPolicy,
                blockedSenderIDs: contentFilter.blockedSenderIDs,
                onSafetyActionFeedback: { message in
                    activeSafetyBanner = message
                },
                onToggleBlockMember: { targetID, shouldBlock in
                    var nextBlocked = contentFilter.blockedSenderIDs
                    if shouldBlock {
                        nextBlocked.insert(targetID)
                    } else {
                        nextBlocked.remove(targetID)
                    }
                    contentFilter = ChannelContentFilterHook(
                        blockedSenderIDs: nextBlocked,
                        mutedKeywords: contentFilter.mutedKeywords,
                        maskObjectionableContent: contentFilter.maskObjectionableContent
                    )
                },
                onRemoveMember: { removedID in
                    memberRoster.removeAll { $0.memberID == removedID }
                }
            )
        }
    }

    // MARK: - Top Header Bar

    private var channelTopBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChannelSidebar.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sidebar.left")
                    if let badge = directoryProjection.totalUnreadBadgeText {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(copy("切换频道列表", "Toggle channel list"))

            if let channel = selectedChannel {
                HStack(spacing: 6) {
                    Image(systemName: channel.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(channel.name)
                        .font(.headline)
                        .lineLimit(1)
                    if channel.isReadOnlyAnnouncement {
                        Text(copy("公告只读", "Announcement · Read only"))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    if channel.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                guard let channel = selectedChannel else { return }
                let nextMuted = !channel.isMuted
                mutedByChannelID[channel.id] = nextMuted
                refreshDirectoryProjection()
                activeSafetyBanner = nextMuted
                    ? copy("已开启「#\(channel.name)」免打扰", "Muted #\(channel.name)")
                    : copy("已恢复「#\(channel.name)」消息提醒", "Unmuted #\(channel.name)")
            } label: {
                Image(systemName: selectedChannel?.isMuted == true ? "bell.slash.fill" : "bell")
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(selectedChannel?.isMuted == true ? copy("取消频道免打扰", "Unmute channel") : copy("频道免打扰", "Mute channel"))

            Button {
                showMemberRosterSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                    Text("\(memberRoster.count)")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(copy("频道成员与身份组", "Channel members and roles"))

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Category-Grouped Sidebar

    private var channelCategorySidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(directoryProjection.groups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(group.title.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if group.totalMentionCount > 0 {
                                Text("@\(group.totalMentionCount)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.red, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 10)

                        ForEach(group.channels) { channel in
                            channelSidebarRow(channel)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func channelSidebarRow(_ channel: ChannelDiscordItemProjection) -> some View {
        let isSelected = channel.id == selectedChannelID
        return Button {
            selectChannel(channel.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: channel.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(channel.name)
                    .font(.subheadline.weight((channel.unreadCount ?? 0) > 0 && !channel.isMuted ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
                if let mentionBadge = channel.mentionBadgeText {
                    Text(mentionBadge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                } else if let unreadBadge = channel.unreadBadgeText {
                    Text(unreadBadge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                } else if channel.isMuted {
                    Image(systemName: "bell.slash")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    // MARK: - Transcript + Paging Up + New-Message Jump + Composer

    private var channelTranscriptColumn: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if viewportState.hasMoreOlderPages {
                                Button {
                                    viewportState.prependOlderPage([], hasMore: false, currentTopVisibleMessageID: viewportState.oldestCursorID)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.circle")
                                        Text(copy("加载更早的频道消息", "Load earlier messages"))
                                    }
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                            }

                            if burstGroups.isEmpty {
                                ContentUnavailableView(
                                    copy("还没有消息", "No messages yet"),
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text(copy("发送第一条消息，开启这个频道的讨论。", "Send the first message to start the conversation."))
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
                                        switch safetyPolicy.validateReportMessage(message: msg, reason: "Objectionable content") {
                                        case let .success(endpoint):
                                            _ = endpoint
                                            activeSafetyBanner = copy("举报已提交，安全团队将在 24 小时内处理。", "Report submitted. Our safety team will review it within 24 hours.")
                                        case let .failure(reason):
                                            _ = reason
                                            activeSafetyBanner = copy("无法举报该消息，请稍后重试。", "Couldn't report this message. Please try again later.")
                                        }
                                    },
                                    onBlockAuthor: { authorID in
                                        switch safetyPolicy.validateBlockUser(targetMemberID: authorID, shouldBlock: true) {
                                        case let .success(endpoint):
                                            var next = contentFilter.blockedSenderIDs
                                            next.insert(authorID)
                                            _ = endpoint
                                            contentFilter = ChannelContentFilterHook(
                                                blockedSenderIDs: next,
                                                mutedKeywords: contentFilter.mutedKeywords,
                                                maskObjectionableContent: contentFilter.maskObjectionableContent
                                            )
                                            activeSafetyBanner = copy("已拉黑成员 #\(authorID)，其消息已隐藏。", "Blocked member #\(authorID). Their messages are hidden.")
                                        case let .failure(reason):
                                            _ = reason
                                            activeSafetyBanner = copy("无法拉黑该用户。", "Couldn't block this user.")
                                        }
                                    },
                                    onDeleteMessage: { msg in
                                        switch safetyPolicy.validateDeleteMessage(channelID: Int(selectedChannelID), message: msg) {
                                        case let .success(endpoint):
                                            _ = endpoint
                                            activeSafetyBanner = copy("消息 #\(msg.id) 已撤回/删除。", "Message #\(msg.id) was recalled or deleted.")
                                        case let .failure(reason):
                                            _ = reason
                                            activeSafetyBanner = copy("你没有权限删除该消息。", "You don't have permission to delete this message.")
                                        }
                                    }
                                )
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: viewportState.pendingNewMessageCount) { _ in
                        if viewportState.isNearBottom, let lastID = burstGroups.last?.items.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                if viewportState.showNewMessageJumpBanner {
                    Button {
                        _ = viewportState.jumpToBottomClearingNewMessages()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(copy("\(viewportState.pendingNewMessageCount) 条新消息 · 点击跳转到底部", "\(viewportState.pendingNewMessageCount) new messages · Jump to present"))
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                    }
                    .frame(minHeight: 44)
                    .padding(.bottom, 10)
                }
            }

            Divider()
            channelComposerBar
        }
    }

    private var channelComposerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let replyTarget = activeReplyTarget {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Text(copy("回复 \(replyTarget.senderName ?? "成员 #\(replyTarget.senderID ?? 0)")：\(replyTarget.content ?? "")", "Replying to \(replyTarget.senderName ?? "Member #\(replyTarget.senderID ?? 0)"): \(replyTarget.content ?? "")"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

            if selectedChannel?.isReadOnlyAnnouncement == true && !safetyPolicy.canModerateMessages {
                HStack(spacing: 6) {
                    Image(systemName: "megaphone")
                        .foregroundStyle(.secondary)
                    Text(copy("当前为公告频道，仅主理人与管理员可发布通知", "This is an announcement channel. Only club owners and admins can post notices."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 8) {
                    TextField(copy("在 #\(selectedChannel?.name ?? "频道") 发送消息…", "Message #\(selectedChannel?.name ?? "channel")…"), text: $composerText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        sendOptimisticChannelMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
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

    private func selectChannel(_ channelID: Int64) {
        selectedChannelID = channelID
        unreadByChannelID[channelID] = 0
        mentionByChannelID[channelID] = 0
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
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let body: String
        if let reply = activeReplyTarget {
            body = "> #\(reply.id) \(trimmed)"
        } else {
            body = trimmed
        }
        let clientID = "w6-\(selectedChannelID)-\(UUID().uuidString.lowercased())"
        _ = sendStateMachine.enqueueOptimistic(
            clientMessageID: clientID,
            senderID: viewerMemberID,
            content: body,
            replyToMessageID: activeReplyTarget?.id
        )
        _ = sendStateMachine.markSending(clientMessageID: clientID)
        composerText = ""
        activeReplyTarget = nil
    }

    private func retryFailedMessage(clientMessageID: String) {
        guard sendStateMachine.beginRetryWithReceiptCheck(clientMessageID: clientMessageID) else { return }
        _ = sendStateMachine.resolveRetryAfterReceiptCheck(
            clientMessageID: clientMessageID,
            receiptResult: .notFound
        )
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

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dividerText = group.precedingDividerText {
                HStack {
                    VStack { Divider() }
                    Text(dividerText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                .padding(.vertical, 4)
            }

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(group.isSystemGroup ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(String(group.senderName.prefix(1)))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(group.isSystemGroup ? .orange : Color.accentColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.senderName)
                            .font(.subheadline.weight(.semibold))
                        if let badge = group.senderRoleBadge, !badge.isEmpty {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(group.headerTimestampText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(group.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            if let reply = item.replyReference {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrowshape.turn.up.left")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(reply.replyAuthorName): \(reply.replyPreviewText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if reply.threadReplyCount > 1 {
                                        Text(copy("\(reply.threadReplyCount) 条串内回复", "\(reply.threadReplyCount) thread replies"))
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            }

                            Text(item.displayBody)
                                .font(.body)
                                .foregroundStyle(item.message.isPayloadVisible ? .primary : .secondary)

                            ForEach(Array(item.attachments.enumerated()), id: \.offset) { _, attachment in
                                HStack(spacing: 6) {
                                    Image(systemName: attachment.kind == .image ? "photo" : "link")
                                        .font(.caption)
                                    Text(attachment.title)
                                        .font(.caption.weight(.medium))
                                    if let sub = attachment.subtitle, !sub.isEmpty {
                                        Text(sub)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(6)
                                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
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
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    case ChannelOutboundSendPhase.failed.rawValue:
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.caption2)
                                        Text(copy("发送失败", "Failed to send"))
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                        if let cid = item.transcriptMessage.clientMessageID {
                                            Button(copy("重试（先核对回执）", "Retry (check receipt first)")) {
                                                onRetrySend(cid)
                                            }
                                            .font(.caption2.weight(.semibold))
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

                                Button(role: .destructive) {
                                    onBlockAuthor(senderID)
                                } label: {
                                    Label(copy("拉黑该用户", "Block user"), systemImage: "hand.raised.fill")
                                }
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
    public let policy: ChannelSafetyModerationPolicy
    public let blockedSenderIDs: Set<Int>
    public let onSafetyActionFeedback: (String) -> Void
    public let onToggleBlockMember: (Int, Bool) -> Void
    public let onRemoveMember: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.members) { member in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.16))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(member.nickname.prefix(1)))
                                            .font(.caption.weight(.bold))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(member.nickname)
                                            .font(.subheadline.weight(.medium))
                                        Text(member.badgeLabel)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                                            .foregroundStyle(Color.accentColor)
                                        if blockedSenderIDs.contains(member.memberID) {
                                            Text(copy("已拉黑", "Blocked"))
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    if let expires = member.expiresText, !expires.isEmpty {
                                        Text(copy("角色有效期至 \(expires)", "Role valid until \(expires)"))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if member.memberID != policy.viewerMemberID {
                                    let isBlocked = blockedSenderIDs.contains(member.memberID)
                                    Button(isBlocked ? copy("取消拉黑", "Unblock") : copy("拉黑", "Block")) {
                                        onToggleBlockMember(member.memberID, !isBlocked)
                                        onSafetyActionFeedback(
                                            isBlocked
                                                ? copy("已取消拉黑 \(member.nickname)", "Unblocked \(member.nickname)")
                                                : copy("已拉黑 \(member.nickname)", "Blocked \(member.nickname)")
                                        )
                                    }
                                    .tint(.orange)

                                    Button(copy("举报", "Report")) {
                                        switch policy.validateReportUser(
                                            targetMemberID: member.memberID,
                                            reasonCode: "HARASSMENT",
                                            detail: "Channel member report"
                                        ) {
                                        case let .success(endpoint):
                                            _ = endpoint
                                            onSafetyActionFeedback(copy("已提交对 \(member.nickname) 的举报", "Report on \(member.nickname) submitted"))
                                        case let .failure(denial):
                                            _ = denial
                                            onSafetyActionFeedback(copy("举报失败，请稍后重试。", "Couldn't submit the report. Please try again later."))
                                        }
                                    }
                                    .tint(.yellow)

                                    if policy.canRemoveOrBanMembers {
                                        Button(copy("移除", "Remove"), role: .destructive) {
                                            switch policy.validateRemoveMember(target: member) {
                                            case let .success(endpoint):
                                                onRemoveMember(member.memberID)
                                                _ = endpoint
                                                onSafetyActionFeedback(copy("已移除成员 \(member.nickname)", "Removed \(member.nickname)"))
                                            case let .failure(denial):
                                                _ = denial
                                                onSafetyActionFeedback(copy("无法移除成员。", "Couldn't remove this member."))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(copy("\(clubName) · 成员与身份组", "\(clubName) · Members & Roles"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy("完成", "Done")) { dismiss() }
                }
            }
        }
    }
}
