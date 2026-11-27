import Foundation
import CryptoKit

// MARK: - W6 Discord-Style Club Channel Directory Models & Projections

/// Last-message preview attached to a channel row in the club channel directory.
public struct DirectoryMessagePreview: Equatable, Sendable {
    public let messageID: Int64
    public let senderName: String
    public let summaryText: String
    public let createdAt: String?

    public init(
        messageID: Int64,
        senderName: String,
        summaryText: String,
        createdAt: String? = nil
    ) {
        self.messageID = messageID
        self.senderName = senderName
        self.summaryText = summaryText
        self.createdAt = createdAt
    }
}

/// Viewer-scoped read/notification state for a club channel (`my_state`).
public struct ChannelDirectoryMyState: Equatable, Sendable {
    public let lastReadMessageID: Int64?
    public let lastReadAt: String?
    /// `0` = all messages, `1` = mentions only, `2` = muted.
    public let notifyPref: Int
    public let unreadCount: Int
    public let readStateAvailable: Bool

    public init(
        lastReadMessageID: Int64?,
        lastReadAt: String?,
        notifyPref: Int,
        unreadCount: Int,
        readStateAvailable: Bool
    ) {
        self.lastReadMessageID = lastReadMessageID
        self.lastReadAt = lastReadAt
        self.notifyPref = notifyPref
        self.unreadCount = unreadCount
        self.readStateAvailable = readStateAvailable
    }
}

/// Category header in a club's channel directory (`api/club/channels`).
public struct ChannelDirectoryCategory: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let clubID: Int64
    public let name: String
    public let position: Int

    public init(id: Int64, clubID: Int64, name: String, position: Int) {
        self.id = id
        self.clubID = clubID
        self.name = name
        self.position = position
    }
}

/// Individual channel entry in a club's channel directory (`api/club/channels`).
public struct ChannelDirectoryEntry: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let clubID: Int64
    public let categoryID: Int64?
    public let name: String
    /// `0` = category node, `1` = text channel, `2` = announcement (read-only for regular members).
    public let kind: Int
    /// `0` = all club members, `>0` = role-restricted channel.
    public let visibility: Int
    public let position: Int
    public let archivedAt: String?
    public let myState: ChannelDirectoryMyState?
    public let lastMessagePreview: DirectoryMessagePreview?

    public init(
        id: Int64,
        clubID: Int64,
        categoryID: Int64?,
        name: String,
        kind: Int,
        visibility: Int,
        position: Int,
        archivedAt: String? = nil,
        myState: ChannelDirectoryMyState? = nil,
        lastMessagePreview: DirectoryMessagePreview? = nil
    ) {
        self.id = id
        self.clubID = clubID
        self.categoryID = categoryID
        self.name = name
        self.kind = kind
        self.visibility = visibility
        self.position = position
        self.archivedAt = archivedAt
        self.myState = myState
        self.lastMessagePreview = lastMessagePreview
    }
}

/// Complete channel directory snapshot for a club.
public struct ChannelDirectoryListing: Equatable, Sendable {
    public let clubID: Int64
    public let categories: [ChannelDirectoryCategory]
    public let channels: [ChannelDirectoryEntry]

    public init(
        clubID: Int64,
        categories: [ChannelDirectoryCategory],
        channels: [ChannelDirectoryEntry]
    ) {
        self.clubID = clubID
        self.categories = categories
        self.channels = channels
    }
}

/// Category-grouped channel item inside a club's Discord-style channel directory.
public struct ChannelDiscordItemProjection: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let clubID: Int64
    public let categoryID: Int64?
    public let name: String
    public let kind: Int
    public let visibility: Int
    public let position: Int
    public let isReadOnlyAnnouncement: Bool
    public let isArchived: Bool
    public let isMuted: Bool
    public let unreadCount: Int?
    public let mentionCount: Int
    public let readStateAvailable: Bool
    public let lastMessagePreview: DirectoryMessagePreview?

    public init(
        id: Int64,
        clubID: Int64,
        categoryID: Int64?,
        name: String,
        kind: Int,
        visibility: Int,
        position: Int,
        isReadOnlyAnnouncement: Bool,
        isArchived: Bool,
        isMuted: Bool,
        unreadCount: Int?,
        mentionCount: Int,
        readStateAvailable: Bool,
        lastMessagePreview: DirectoryMessagePreview?
    ) {
        self.id = id
        self.clubID = clubID
        self.categoryID = categoryID
        self.name = name
        self.kind = kind
        self.visibility = visibility
        self.position = position
        self.isReadOnlyAnnouncement = isReadOnlyAnnouncement
        self.isArchived = isArchived
        self.isMuted = isMuted
        self.unreadCount = unreadCount
        self.mentionCount = mentionCount
        self.readStateAvailable = readStateAvailable
        self.lastMessagePreview = lastMessagePreview
    }

    /// Formatted unread badge ("1"..."99+"), or nil when unread state is unavailable, zero, or muted.
    public var unreadBadgeText: String? {
        guard readStateAvailable, !isMuted, let unreadCount, unreadCount > 0 else {
            return nil
        }
        return IMInboxSummary.badgeText(unreadCount)
    }

    /// Formatted `@mention` badge ("@1"..."@99+"), shown even when the channel is muted.
    public var mentionBadgeText: String? {
        guard readStateAvailable, mentionCount > 0 else {
            return nil
        }
        guard let badge = IMInboxSummary.badgeText(mentionCount) else {
            return nil
        }
        return "@\(badge)"
    }

    /// Leading SF Symbol name representing Discord-style channel semantics.
    public var symbolName: String {
        if isReadOnlyAnnouncement || kind == 2 {
            return "megaphone.fill"
        }
        if visibility > 0 {
            return "lock.fill"
        }
        return "number"
    }
}

/// Category group inside the club channel sidebar.
public struct ChannelDiscordCategoryGroup: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let title: String
    public let position: Int
    public let channels: [ChannelDiscordItemProjection]

    public init(
        id: Int64,
        title: String,
        position: Int,
        channels: [ChannelDiscordItemProjection]
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.channels = channels
    }

    public var totalUnreadCount: Int {
        channels.reduce(0) { partial, channel in
            guard channel.readStateAvailable, !channel.isMuted else { return partial }
            return partial + max(0, channel.unreadCount ?? 0)
        }
    }

    public var totalMentionCount: Int {
        channels.reduce(0) { partial, channel in
            guard channel.readStateAvailable else { return partial }
            return partial + max(0, channel.mentionCount)
        }
    }
}

/// Projects a `ChannelDirectoryListing` + per-channel mention/mute overlays into Discord-style category groups.
public struct ChannelCategoryDirectoryProjection: Equatable, Sendable {
    public let clubID: Int64
    public let groups: [ChannelDiscordCategoryGroup]
    public let totalUnmutedUnreadCount: Int
    public let totalMentionCount: Int
    public let hasUnavailableReadState: Bool

    public init(
        listing: ChannelDirectoryListing,
        mentionCountsByChannelID: [Int64: Int] = [:],
        mutedOverrideByChannelID: [Int64: Bool] = [:],
        unreadOverrideByChannelID: [Int64: Int] = [:],
        uncategorizedTitle: String = "频道",
        locale: Locale = ChannelCopy.defaultLocale
    ) {
        self.clubID = listing.clubID

        let sortedCategories = listing.categories.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.id < $1.id
        }

        let playableChannels = listing.channels.filter { $0.kind != 0 && $0.archivedAt == nil }
        let sortedChannels = playableChannels.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.id < $1.id
        }

        var hasUnavailable = false
        func projectChannel(_ entry: ChannelDirectoryEntry) -> ChannelDiscordItemProjection {
            let stateAvailable = entry.myState?.readStateAvailable == true
            if !stateAvailable {
                hasUnavailable = true
            }
            let baseMuted = (entry.myState?.notifyPref ?? 0) == 2
            let isMuted = mutedOverrideByChannelID[entry.id] ?? baseMuted
            let rawUnread: Int?
            if stateAvailable {
                let value = unreadOverrideByChannelID[entry.id] ?? entry.myState?.unreadCount ?? 0
                rawUnread = max(0, value)
            } else {
                rawUnread = nil
            }
            let mentions = stateAvailable ? max(0, mentionCountsByChannelID[entry.id] ?? 0) : 0
            return ChannelDiscordItemProjection(
                id: entry.id,
                clubID: entry.clubID,
                categoryID: entry.categoryID,
                name: entry.name,
                kind: entry.kind,
                visibility: entry.visibility,
                position: entry.position,
                isReadOnlyAnnouncement: entry.kind == 2,
                isArchived: entry.archivedAt != nil,
                isMuted: isMuted,
                unreadCount: rawUnread,
                mentionCount: mentions,
                readStateAvailable: stateAvailable,
                lastMessagePreview: entry.lastMessagePreview
            )
        }

        let projectedAll = sortedChannels.map(projectChannel)
        let knownCategoryIDs = Set(sortedCategories.map { $0.id })

        var builtGroups: [ChannelDiscordCategoryGroup] = []
        let uncategorized = projectedAll.filter { channel in
            guard let categoryID = channel.categoryID else { return true }
            return !knownCategoryIDs.contains(categoryID)
        }
        if !uncategorized.isEmpty {
            builtGroups.append(
                ChannelDiscordCategoryGroup(
                    id: 0,
                    title: uncategorizedTitle == "频道" ? ChannelCopy.text("频道", "Channels", locale: locale) : uncategorizedTitle,
                    position: -1,
                    channels: uncategorized
                )
            )
        }

        for category in sortedCategories {
            let categoryChannels = projectedAll.filter { $0.categoryID == category.id }
            if !categoryChannels.isEmpty {
                builtGroups.append(
                    ChannelDiscordCategoryGroup(
                        id: category.id,
                        title: category.name,
                        position: category.position,
                        channels: categoryChannels
                    )
                )
            }
        }

        self.groups = builtGroups
        self.totalUnmutedUnreadCount = builtGroups.reduce(0) { $0 + $1.totalUnreadCount }
        self.totalMentionCount = builtGroups.reduce(0) { $0 + $1.totalMentionCount }
        self.hasUnavailableReadState = hasUnavailable
    }

    public var totalUnreadBadgeText: String? {
        IMInboxSummary.badgeText(totalUnmutedUnreadCount)
    }

    /// Returns a new projection after marking `channelID` as read up to the latest message.
    public func markingChannelRead(
        _ channelID: Int64,
        listing: ChannelDirectoryListing,
        mentionCountsByChannelID: [Int64: Int] = [:],
        mutedOverrideByChannelID: [Int64: Bool] = [:],
        unreadOverrideByChannelID: [Int64: Int] = [:]
    ) -> ChannelCategoryDirectoryProjection {
        var nextMentions = mentionCountsByChannelID
        nextMentions[channelID] = 0
        var nextUnreads = unreadOverrideByChannelID
        nextUnreads[channelID] = 0
        return ChannelCategoryDirectoryProjection(
            listing: listing,
            mentionCountsByChannelID: nextMentions,
            mutedOverrideByChannelID: mutedOverrideByChannelID,
            unreadOverrideByChannelID: nextUnreads
        )
    }
}

// MARK: - Discord-Style Message Author/Time Burst Grouping, Replies/Threads, and Attachments

/// Inline reply or thread reference attached to a channel message.
public struct ChannelReplyThreadReference: Equatable, Sendable {
    public let replyToMessageID: Int
    public let replyAuthorName: String
    public let replyPreviewText: String
    public let threadRootMessageID: Int?
    public let threadReplyCount: Int

    public init(
        replyToMessageID: Int,
        replyAuthorName: String,
        replyPreviewText: String,
        threadRootMessageID: Int? = nil,
        threadReplyCount: Int = 0
    ) {
        self.replyToMessageID = replyToMessageID
        self.replyAuthorName = replyAuthorName
        self.replyPreviewText = replyPreviewText
        self.threadRootMessageID = threadRootMessageID
        self.threadReplyCount = max(0, threadReplyCount)
    }
}

/// Attachment/media projection aligned with backend `ImMessage.type` (1=text, 2=image, 3=card/poll, 13=location).
public enum ChannelAttachmentKind: String, Equatable, Sendable {
    case image
    case pollCard
    case routeOrActivityCard
    case locationPin
    case fileDocument
}

public struct ChannelAttachmentProjection: Equatable, Sendable {
    public let kind: ChannelAttachmentKind
    public let url: String?
    public let title: String
    public let subtitle: String?
    public let isOriginApproved: Bool

    public init(
        kind: ChannelAttachmentKind,
        url: String?,
        title: String,
        subtitle: String? = nil,
        isOriginApproved: Bool = true
    ) {
        self.kind = kind
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.isOriginApproved = isOriginApproved
    }
}

/// Wire-compatible helper to construct `MessagingMessage` instances and carry optimistic client metadata.
public struct ChannelTranscriptMessage: Equatable, Identifiable, Sendable {
    public var id: String {
        if let clientMessageID, !clientMessageID.isEmpty, wireMessage.id <= 0 {
            return "client-\(clientMessageID)"
        }
        return "msg-\(wireMessage.id)-\(clientMessageID ?? "")"
    }

    public let wireMessage: MessagingMessage
    public var clientMessageID: String?
    public var sendState: String?
    public var mediaURL: String?

    public init(
        wireMessage: MessagingMessage,
        clientMessageID: String? = nil,
        sendState: String? = nil,
        mediaURL: String? = nil
    ) {
        self.wireMessage = wireMessage
        self.clientMessageID = clientMessageID
        self.sendState = sendState
        self.mediaURL = mediaURL
    }

    /// Creates a `ChannelTranscriptMessage` backed by a decoded `MessagingMessage`.
    public static func make(
        id: Int,
        conversationID: Int,
        senderID: Int?,
        senderName: String? = nil,
        senderAvatar: String? = nil,
        type: Int = 1,
        content: String? = nil,
        extraJSON: String? = nil,
        mediaURL: String? = nil,
        statusWireValue: Int = 0,
        sendState: String? = nil,
        createdAt: String? = nil,
        clientMessageID: String? = nil
    ) -> ChannelTranscriptMessage {
        let safeID = max(1, id)
        let safeConversationID = max(1, conversationID)
        var payload: [String: Any] = [
            "id": safeID,
            "conversationId": safeConversationID,
            "status": statusWireValue
        ]
        if let senderID { payload["senderId"] = senderID }
        if let senderName { payload["senderName"] = senderName }
        if let senderAvatar { payload["senderAvatar"] = senderAvatar }
        payload["msgType"] = type
        if let content { payload["content"] = content }
        if let extraJSON { payload["extraJson"] = extraJSON }
        if let createdAt { payload["createTime"] = createdAt }

        // Malformed input (for example a negative sender id) degrades to a withheld placeholder, never a crash.
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let decoded = (try? JSONDecoder().decode(MessagingMessage.self, from: data))
            ?? MessagingMessage(withheldID: safeID, conversationID: safeConversationID)
        return ChannelTranscriptMessage(
            wireMessage: decoded,
            clientMessageID: clientMessageID,
            sendState: sendState,
            mediaURL: mediaURL
        )
    }
}

/// Individual message item inside a Discord-style author/time burst group.
public struct ChannelBurstMessageItem: Equatable, Identifiable {
    public let id: String
    public let transcriptMessage: ChannelTranscriptMessage
    public var message: MessagingMessage { transcriptMessage.wireMessage }
    public let isFirstInBurst: Bool
    public let displayBody: String
    public let isFilteredBySafetyHook: Bool
    public let replyReference: ChannelReplyThreadReference?
    public let attachments: [ChannelAttachmentProjection]
    /// Backend `ApiImController` does not expose emoji reaction endpoints; kept false per spec ("reactions only if the backend supports them").
    public let supportsReactions: Bool

    public init(
        transcriptMessage: ChannelTranscriptMessage,
        isFirstInBurst: Bool,
        displayBody: String,
        isFilteredBySafetyHook: Bool = false,
        replyReference: ChannelReplyThreadReference? = nil,
        attachments: [ChannelAttachmentProjection] = [],
        supportsReactions: Bool = false
    ) {
        self.id = transcriptMessage.id
        self.transcriptMessage = transcriptMessage
        self.isFirstInBurst = isFirstInBurst
        self.displayBody = displayBody
        self.isFilteredBySafetyHook = isFilteredBySafetyHook
        self.replyReference = replyReference
        self.attachments = attachments
        self.supportsReactions = supportsReactions
    }
}

/// A group of consecutive messages sent by the same author within a 5-minute window.
public struct ChannelMessageBurstGroup: Equatable, Identifiable {
    public let id: String
    public let senderID: Int
    public let senderName: String
    public let senderAvatar: String
    public let senderRoleBadge: String?
    public let headerTimestampText: String
    public let precedingDividerText: String?
    public let isSystemGroup: Bool
    public let items: [ChannelBurstMessageItem]

    public init(
        id: String,
        senderID: Int,
        senderName: String,
        senderAvatar: String,
        senderRoleBadge: String?,
        headerTimestampText: String,
        precedingDividerText: String?,
        isSystemGroup: Bool,
        items: [ChannelBurstMessageItem]
    ) {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.senderRoleBadge = senderRoleBadge
        self.headerTimestampText = headerTimestampText
        self.precedingDividerText = precedingDividerText
        self.isSystemGroup = isSystemGroup
        self.items = items
    }
}

/// Groups channel messages by author and time window (default 300s / 5 minutes), respecting visibility, content filters, and reply/attachment projections.
public enum ChannelMessageBurstGrouper {
    public static let defaultBurstWindowSeconds: TimeInterval = 5 * 60
    /// Confirmed in `ApiImController.java`: no reaction endpoints exist in backend IM contract.
    public static let backendSupportsReactions: Bool = false

    public static func formatDivider(_ divider: IMInboxTime.DividerText, locale: Locale = ChannelCopy.defaultLocale) -> String {
        switch divider {
        case let .today(clock):
            return ChannelCopy.text("今天 \(clock)", "Today \(clock)", locale: locale)
        case let .yesterday(clock):
            return ChannelCopy.text("昨天 \(clock)", "Yesterday \(clock)", locale: locale)
        case let .date(month, day, clock):
            // MP `MM-dd HH:mm` in Chinese; English reads "Nov 7, 09:00" (a bare "11-07" reads as a range).
            if ChannelCopy.isChinese(locale) { return String(format: "%02d-%02d %@", month, day, clock) }
            let formatter = DateFormatter()
            formatter.locale = locale
            let months: [String] = formatter.shortMonthSymbols ?? []
            let name = months.indices.contains(month - 1) ? months[month - 1] : String(month)
            return "\(name) \(day), \(clock)"
        }
    }

    public static func group(
        messages: [ChannelTranscriptMessage],
        roleBadgeByMemberID: [Int: String] = [:],
        replyReferencesByMessageID: [Int: ChannelReplyThreadReference] = [:],
        contentFilter: ChannelContentFilterHook = .default,
        burstWindowSeconds: TimeInterval = defaultBurstWindowSeconds,
        now: Date = Date()
    ) -> [ChannelMessageBurstGroup] {
        // Filter out messages from blocked senders immediately (App Store 1.2 safety requirement)
        let visibleAfterBlock = messages.filter { item in
            !contentFilter.shouldHideMessageImmediately(item.wireMessage)
        }
        guard !visibleAfterBlock.isEmpty else { return [] }

        let wireMessages = visibleAfterBlock.map(\.wireMessage)
        let dividersByMessageID = IMInboxTime.dividers(for: wireMessages, now: now)

        var groups: [ChannelMessageBurstGroup] = []
        var currentMessages: [ChannelTranscriptMessage] = []
        var currentDividerText: String?
        var currentLastDate: Date?

        func flushCurrentGroup() {
            guard let first = currentMessages.first else { return }
            let firstWire = first.wireMessage
            let firstSenderID = firstWire.senderID ?? 0
            let isSystem = firstWire.isPayloadVisible && (firstSenderID <= 0 || firstWire.type == 99 || firstWire.type == 100)
            let headerTimestamp = firstWire.createdAt.flatMap {
                IMInboxTime.parse($0)
            }.map {
                formatDivider(IMInboxTime.dividerText($0, now: now), locale: contentFilter.locale)
            } ?? (firstWire.createdAt ?? "")

            let burstItems: [ChannelBurstMessageItem] = currentMessages.enumerated().map { index, item in
                let filterResult = contentFilter.evaluate(message: item.wireMessage)
                let attachments = projectAttachments(for: item, locale: contentFilter.locale)
                let replyRef = extractReplyReference(
                    for: item.wireMessage,
                    allMessages: wireMessages,
                    explicitReferences: replyReferencesByMessageID,
                    locale: contentFilter.locale
                )
                return ChannelBurstMessageItem(
                    transcriptMessage: item,
                    isFirstInBurst: index == 0,
                    displayBody: filterResult.displayText,
                    isFilteredBySafetyHook: filterResult.wasModified,
                    replyReference: replyRef,
                    attachments: attachments,
                    supportsReactions: backendSupportsReactions
                )
            }

            let senderName: String
            if let rawName = firstWire.senderName?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty {
                senderName = rawName
            } else if !firstWire.isPayloadVisible {
                senderName = ChannelCopy.text("已撤回/屏蔽消息", "Recalled or hidden message", locale: contentFilter.locale)
            } else if isSystem {
                senderName = ChannelCopy.text("系统通知", "System notice", locale: contentFilter.locale)
            } else {
                senderName = ChannelCopy.text("成员 #\(firstSenderID)", "Member #\(firstSenderID)", locale: contentFilter.locale)
            }

            groups.append(
                ChannelMessageBurstGroup(
                    id: "burst-\(first.id)",
                    senderID: firstSenderID,
                    senderName: senderName,
                    senderAvatar: firstWire.senderAvatar ?? "",
                    senderRoleBadge: roleBadgeByMemberID[firstSenderID],
                    headerTimestampText: headerTimestamp,
                    precedingDividerText: currentDividerText,
                    isSystemGroup: isSystem,
                    items: burstItems
                )
            )
            currentMessages.removeAll(keepingCapacity: true)
            currentDividerText = nil
            currentLastDate = nil
        }

        for (index, item) in visibleAfterBlock.enumerated() {
            let message = item.wireMessage
            let rawDivider = dividersByMessageID[message.id].map { formatDivider($0, locale: contentFilter.locale) }
            // The first message in the transcript always gets a divider in `IMInboxTime.dividers`,
            // while subsequent dividers indicate a >5m gap.
            let gapDivider = index == 0 ? nil : rawDivider
            let parsedDate = IMInboxTime.parse(message.createdAt)
            let senderID = message.senderID ?? 0
            let isSystemOrTombstone = senderID <= 0 || !message.isPayloadVisible

            if let previous = currentMessages.last?.wireMessage {
                let prevSenderID = previous.senderID ?? 0
                let previousIsSystemOrTombstone = prevSenderID <= 0 || !previous.isPayloadVisible
                let sameSender = prevSenderID == senderID && senderID > 0
                let withinWindow: Bool
                if let prevDate = currentLastDate, let currDate = parsedDate {
                    let delta = currDate.timeIntervalSince(prevDate)
                    withinWindow = delta >= 0 && delta < burstWindowSeconds
                } else {
                    withinWindow = gapDivider == nil
                }

                if sameSender && !isSystemOrTombstone && !previousIsSystemOrTombstone && gapDivider == nil && withinWindow {
                    currentMessages.append(item)
                    if let parsedDate {
                        currentLastDate = parsedDate
                    }
                    continue
                } else {
                    flushCurrentGroup()
                }
            }

            currentDividerText = rawDivider
            currentMessages = [item]
            currentLastDate = parsedDate
        }

        flushCurrentGroup()
        return groups
    }

    public static func projectAttachments(for item: ChannelTranscriptMessage, locale: Locale = ChannelCopy.defaultLocale) -> [ChannelAttachmentProjection] {
        let message = item.wireMessage
        guard message.isPayloadVisible else { return [] }
        var result: [ChannelAttachmentProjection] = []

        if message.type == 2 {
            let rawURL = (item.mediaURL?.isEmpty == false ? item.mediaURL : message.content) ?? ""
            result.append(
                ChannelAttachmentProjection(
                    kind: .image,
                    url: rawURL,
                    title: ChannelCopy.text("图片附件", "Image", locale: locale),
                    subtitle: nil,
                    isOriginApproved: isApprovedAttachmentURL(rawURL)
                )
            )
        } else if message.type == 3 {
            let text = message.content ?? ""
            if text.contains("poll_id") || text.contains("投票") {
                result.append(
                    ChannelAttachmentProjection(
                        kind: .pollCard,
                        url: item.mediaURL,
                        title: ChannelCopy.text("频道投票卡片", "Channel poll", locale: locale),
                        subtitle: text
                    )
                )
            } else {
                result.append(
                    ChannelAttachmentProjection(
                        kind: .routeOrActivityCard,
                        url: item.mediaURL,
                        title: message.card?.title ?? ChannelCopy.text("俱乐部活动/路线卡片", "Club event or route", locale: locale),
                        subtitle: message.card?.subtitle ?? text
                    )
                )
            }
        } else if message.type == 13 {
            result.append(
                ChannelAttachmentProjection(
                    kind: .locationPin,
                    url: item.mediaURL,
                    title: ChannelCopy.text("位置分享", "Shared location", locale: locale),
                    subtitle: message.content
                )
            )
        }

        return result
    }

    private static func isApprovedAttachmentURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://127.0.0.1") || trimmed.hasPrefix("http://localhost")
    }

    private static func extractReplyReference(
        for message: MessagingMessage,
        allMessages: [MessagingMessage],
        explicitReferences: [Int: ChannelReplyThreadReference],
        locale: Locale = ChannelCopy.defaultLocale
    ) -> ChannelReplyThreadReference? {
        if let explicit = explicitReferences[message.id] {
            return explicit
        }
        guard let body = message.content, body.hasPrefix("> #") else {
            return nil
        }
        let digits = body.dropFirst(3).prefix { $0.isNumber }
        guard let targetID = Int(digits), targetID > 0 else {
            return nil
        }
        let parent = allMessages.first { $0.id == targetID }
        let author = parent?.senderName ?? ChannelCopy.text("成员 #\(parent?.senderID ?? 0)", "Member #\(parent?.senderID ?? 0)", locale: locale)
        let preview = parent?.isPayloadVisible == true ? (parent?.content ?? "") : ChannelCopy.text("原消息不可用", "Original message unavailable", locale: locale)
        let replyCount = allMessages.filter {
            guard let text = $0.content else { return false }
            return text.hasPrefix("> #\(targetID)")
        }.count
        return ChannelReplyThreadReference(
            replyToMessageID: targetID,
            replyAuthorName: author,
            replyPreviewText: preview,
            threadRootMessageID: targetID,
            threadReplyCount: replyCount
        )
    }
}

// MARK: - Optimistic Send, Send-Receipt Recovery (`POST /api/im/send-receipt`), and Retry State Machine

/// Explicit send state for an outbound channel message.
public enum ChannelOutboundSendPhase: String, Equatable, Sendable {
    case pending
    case sending
    case sent
    case failed
    case verifyingReceipt
}

public struct ChannelOutboundMessageRecord: Equatable, Identifiable {
    public var id: String { clientMessageID }
    public let conversationID: Int
    public let clientMessageID: String
    public let senderID: Int
    public let content: String
    public let messageType: Int
    public let replyToMessageID: Int?
    public let createdAt: String
    public var phase: ChannelOutboundSendPhase
    public var attemptCount: Int
    public var failureReason: String?
    public var confirmedServerMessage: MessagingMessage?

    public init(
        conversationID: Int,
        clientMessageID: String,
        senderID: Int,
        content: String,
        messageType: Int = 1,
        replyToMessageID: Int? = nil,
        createdAt: String,
        phase: ChannelOutboundSendPhase = .pending,
        attemptCount: Int = 0,
        failureReason: String? = nil,
        confirmedServerMessage: MessagingMessage? = nil
    ) {
        self.conversationID = conversationID
        self.clientMessageID = clientMessageID
        self.senderID = senderID
        self.content = content
        self.messageType = messageType
        self.replyToMessageID = replyToMessageID
        self.createdAt = createdAt
        self.phase = phase
        self.attemptCount = attemptCount
        self.failureReason = failureReason
        self.confirmedServerMessage = confirmedServerMessage
    }

    public var canRetry: Bool {
        phase == .failed && confirmedServerMessage == nil
    }

    /// Projects this outbound record as a `ChannelTranscriptMessage` for immediate display in the transcript.
    public func asOptimisticTranscriptMessage(
        syntheticID: Int = 999_999,
        senderName: String? = nil,
        senderAvatar: String? = nil
    ) -> ChannelTranscriptMessage {
        if let confirmedServerMessage {
            return ChannelTranscriptMessage(
                wireMessage: confirmedServerMessage,
                clientMessageID: clientMessageID,
                sendState: ChannelOutboundSendPhase.sent.rawValue
            )
        }
        return ChannelTranscriptMessage.make(
            id: syntheticID,
            conversationID: conversationID,
            senderID: senderID,
            senderName: senderName,
            senderAvatar: senderAvatar,
            type: messageType,
            content: content,
            sendState: phase.rawValue,
            createdAt: createdAt,
            clientMessageID: clientMessageID
        )
    }
}

/// Resolution produced when retrying a failed/uncertain send via `OrdinaryIMSendReceiptResult`.
public enum ChannelSendRetryResolution: Equatable {
    /// `POST /api/im/send-receipt` returned `found: true`; reconciled to `.sent` without re-sending `POST /api/im/send`.
    case reconciledFromReceipt(MessagingMessage)
    /// `POST /api/im/send-receipt` returned `found: false`; caller must re-post `POST /api/im/send` using the identical `clientMessageID`.
    case resendRequired(clientMessageID: String, attempt: Int)
    /// Message is not in a retryable state.
    case ignored
}

/// Deterministic state machine for optimistic channel sends, receipt recovery (`POST /api/im/send-receipt`), and deduplicated polling merge.
public struct ChannelSendStateMachine: Equatable {
    public let conversationID: Int
    public let accountEpoch: Int64
    public private(set) var recordsByClientID: [String: ChannelOutboundMessageRecord]
    public private(set) var orderedClientIDs: [String]

    public init(conversationID: Int, accountEpoch: Int64 = 1) {
        self.conversationID = conversationID
        self.accountEpoch = accountEpoch
        self.recordsByClientID = [:]
        self.orderedClientIDs = []
    }

    public var orderedRecords: [ChannelOutboundMessageRecord] {
        orderedClientIDs.compactMap { recordsByClientID[$0] }
    }

    /// Enqueues a new optimistic message in `.pending` state.
    @discardableResult
    public mutating func enqueueOptimistic(
        clientMessageID: String,
        senderID: Int,
        content: String,
        messageType: Int = 1,
        replyToMessageID: Int? = nil,
        createdAt: String = "2026-04-17T12:00:00"
    ) -> ChannelOutboundMessageRecord {
        let normalizedID = clientMessageID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = recordsByClientID[normalizedID] {
            return existing
        }
        let record = ChannelOutboundMessageRecord(
            conversationID: conversationID,
            clientMessageID: normalizedID,
            senderID: senderID,
            content: content,
            messageType: messageType,
            replyToMessageID: replyToMessageID,
            createdAt: createdAt,
            phase: .pending,
            attemptCount: 0
        )
        recordsByClientID[normalizedID] = record
        orderedClientIDs.append(normalizedID)
        return record
    }

    /// Transitions a `.pending` or `.failed` message into `.sending`.
    @discardableResult
    public mutating func markSending(clientMessageID: String) -> ChannelOutboundMessageRecord? {
        guard var record = recordsByClientID[clientMessageID] else { return nil }
        guard record.phase == .pending || record.phase == .failed || record.phase == .verifyingReceipt else {
            return record
        }
        record.phase = .sending
        record.attemptCount += 1
        record.failureReason = nil
        recordsByClientID[clientMessageID] = record
        return record
    }

    /// Marks an outbound message as `.sent` when `POST /api/im/send` returns the persisted message.
    @discardableResult
    public mutating func markSent(
        clientMessageID: String,
        serverMessage: MessagingMessage
    ) -> ChannelOutboundMessageRecord? {
        guard var record = recordsByClientID[clientMessageID] else { return nil }
        record.phase = .sent
        record.failureReason = nil
        record.confirmedServerMessage = serverMessage
        recordsByClientID[clientMessageID] = record
        return record
    }

    /// Marks an outbound message as `.failed` so the user can retry or inspect the failure.
    @discardableResult
    public mutating func markFailed(
        clientMessageID: String,
        reason: String
    ) -> ChannelOutboundMessageRecord? {
        guard var record = recordsByClientID[clientMessageID] else { return nil }
        guard record.phase != .sent else { return record }
        record.phase = .failed
        record.failureReason = reason
        recordsByClientID[clientMessageID] = record
        return record
    }

    /// Begins a retry by transitioning `.failed` -> `.verifyingReceipt` before calling `POST /api/im/send-receipt`.
    @discardableResult
    public mutating func beginRetryWithReceiptCheck(clientMessageID: String) -> Bool {
        guard var record = recordsByClientID[clientMessageID], record.canRetry else {
            return false
        }
        record.phase = .verifyingReceipt
        recordsByClientID[clientMessageID] = record
        return true
    }

    /// Applies the `OrdinaryIMSendReceiptResult` from `POST /api/im/send-receipt` before deciding whether to resend `POST /api/im/send`.
    public mutating func resolveRetryAfterReceiptCheck(
        clientMessageID: String,
        receiptResult: OrdinaryIMSendReceiptResult
    ) -> ChannelSendRetryResolution {
        guard var record = recordsByClientID[clientMessageID] else {
            return .ignored
        }
        guard record.phase == .verifyingReceipt || record.phase == .failed else {
            return .ignored
        }
        switch receiptResult {
        case let .found(serverMessage):
            record.phase = .sent
            record.failureReason = nil
            record.confirmedServerMessage = serverMessage
            recordsByClientID[clientMessageID] = record
            return .reconciledFromReceipt(serverMessage)
        case .notFound:
            record.phase = .sending
            record.attemptCount += 1
            record.failureReason = nil
            recordsByClientID[clientMessageID] = record
            return .resendRequired(clientMessageID: record.clientMessageID, attempt: record.attemptCount)
        }
    }

    /// Merges confirmed server transcript messages with any still-unconfirmed optimistic records, deduplicating by `clientMessageID` and `id`.
    public mutating func mergedTranscript(
        serverMessages: [ChannelTranscriptMessage],
        senderName: String? = nil,
        senderAvatar: String? = nil
    ) -> [ChannelTranscriptMessage] {
        let serverByClientID = Dictionary(
            serverMessages.compactMap { msg -> (String, ChannelTranscriptMessage)? in
                guard let cid = msg.clientMessageID, !cid.isEmpty else { return nil }
                return (cid, msg)
            },
            uniquingKeysWith: { _, latest in latest }
        )
        let serverIDs = Set(serverMessages.map { $0.wireMessage.id })

        for (cid, var record) in recordsByClientID {
            if let matched = serverByClientID[cid] {
                record.phase = .sent
                record.failureReason = nil
                record.confirmedServerMessage = matched.wireMessage
                recordsByClientID[cid] = record
            } else if let confirmedID = record.confirmedServerMessage?.id, serverIDs.contains(confirmedID) {
                record.phase = .sent
                recordsByClientID[cid] = record
            }
        }

        var combined = serverMessages
        for (idx, cid) in orderedClientIDs.enumerated() {
            guard let record = recordsByClientID[cid] else { continue }
            if serverByClientID[cid] != nil {
                continue
            }
            if let confirmedID = record.confirmedServerMessage?.id, serverIDs.contains(confirmedID) {
                continue
            }
            combined.append(
                record.asOptimisticTranscriptMessage(
                    syntheticID: 900_000 + idx,
                    senderName: senderName,
                    senderAvatar: senderAvatar
                )
            )
        }
        return combined
    }
}

// MARK: - Paging Up, New-Message Jump, and Real-Time Polling with Backoff (`POLL_MS = 8000`)

/// Exponential backoff schedule for channel polling, matching the mini-program's 8-second real-time poll (`subpackageB/pages/im/chat/index.js`).
public struct ChannelPollingBackoffSchedule: Equatable, Sendable {
    public static let baseIntervalMilliseconds: Int = 8_000
    public static let maxIntervalMilliseconds: Int = 60_000

    public private(set) var consecutiveFailures: Int = 0
    public private(set) var isStoppedForTerminalError: Bool = false
    public private(set) var terminalErrorCode: String?

    public init() {}

    public var nextDelayMilliseconds: Int? {
        guard !isStoppedForTerminalError else { return nil }
        guard consecutiveFailures > 0 else { return Self.baseIntervalMilliseconds }
        let shift = min(consecutiveFailures, 4)
        let multiplied = Self.baseIntervalMilliseconds * (1 << shift)
        return min(multiplied, Self.maxIntervalMilliseconds)
    }

    public mutating func recordSuccess() {
        guard !isStoppedForTerminalError else { return }
        consecutiveFailures = 0
    }

    public mutating func recordFailure(errorCode: String? = nil, httpStatus: Int? = nil) {
        if let errorCode,
           ["IM_HISTORY_ACCESS_DENIED", "IM_CONVERSATION_CLOSED", "HANGOUT_CLOSED"].contains(errorCode) {
            isStoppedForTerminalError = true
            terminalErrorCode = errorCode
            return
        }
        if let httpStatus, [401, 403, 409].contains(httpStatus) {
            isStoppedForTerminalError = true
            terminalErrorCode = errorCode ?? "HTTP_\(httpStatus)"
            return
        }
        consecutiveFailures += 1
    }
}

/// Manages transcript scroll position, upward pagination anchor, and the "Jump to new messages" pill.
public struct ChannelTranscriptViewportState: Equatable {
    public static let nearBottomThresholdPoints: Double = 120.0

    public private(set) var messages: [ChannelTranscriptMessage]
    public private(set) var oldestCursorID: Int?
    public private(set) var hasMoreOlderPages: Bool
    public private(set) var isNearBottom: Bool
    public private(set) var pendingNewMessageCount: Int
    public private(set) var firstUnreadNewMessageID: Int?
    public private(set) var preservedScrollAnchorMessageID: Int?
    public private(set) var watermarkMessageID: Int

    public init(
        initialMessages: [ChannelTranscriptMessage] = [],
        hasMoreOlderPages: Bool = false
    ) {
        let sorted = initialMessages.sorted { $0.wireMessage.id < $1.wireMessage.id }
        self.messages = sorted
        self.oldestCursorID = sorted.first?.wireMessage.id
        self.hasMoreOlderPages = hasMoreOlderPages
        self.isNearBottom = true
        self.pendingNewMessageCount = 0
        self.firstUnreadNewMessageID = nil
        self.preservedScrollAnchorMessageID = nil
        self.watermarkMessageID = sorted.map { $0.wireMessage.id }.max() ?? 0
    }

    public var showNewMessageJumpBanner: Bool {
        !isNearBottom && pendingNewMessageCount > 0
    }

    public mutating func updateScrollDistanceFromBottom(_ distancePoints: Double) {
        let near = distancePoints <= Self.nearBottomThresholdPoints
        isNearBottom = near
        if near {
            pendingNewMessageCount = 0
            firstUnreadNewMessageID = nil
        }
    }

    /// Prepends an older page fetched via `cursor_id`, preserving the top visible message ID so scroll position does not jump.
    public mutating func prependOlderPage(
        _ olderMessages: [ChannelTranscriptMessage],
        hasMore: Bool,
        currentTopVisibleMessageID: Int?
    ) {
        preservedScrollAnchorMessageID = currentTopVisibleMessageID ?? messages.first?.wireMessage.id
        var byID: [Int: ChannelTranscriptMessage] = [:]
        for msg in olderMessages {
            byID[msg.wireMessage.id] = msg
        }
        for msg in messages {
            byID[msg.wireMessage.id] = msg
        }
        messages = byID.values.sorted { $0.wireMessage.id < $1.wireMessage.id }
        oldestCursorID = messages.first?.wireMessage.id
        hasMoreOlderPages = hasMore
    }

    /// Merges polled messages (`POST /api/im/messages`); auto-scrolls when near bottom or increments the new-message jump counter when scrolled up.
    public mutating func applyPolledMessages(
        _ polled: [ChannelTranscriptMessage],
        viewerAccountID: Int
    ) {
        let existingIDs = Set(messages.map { $0.wireMessage.id })
        let genuinelyNew = polled.filter { msg in
            let id = msg.wireMessage.id
            guard id > watermarkMessageID else { return false }
            return !existingIDs.contains(id)
        }

        var byID: [Int: ChannelTranscriptMessage] = [:]
        for msg in messages {
            byID[msg.wireMessage.id] = msg
        }
        for msg in polled {
            byID[msg.wireMessage.id] = msg
        }
        messages = byID.values.sorted { $0.wireMessage.id < $1.wireMessage.id }
        if let maxID = messages.map({ $0.wireMessage.id }).max(), maxID > watermarkMessageID {
            watermarkMessageID = maxID
        }

        let newFromOthers = genuinelyNew.filter { ($0.wireMessage.senderID ?? 0) != viewerAccountID }
        guard !newFromOthers.isEmpty else { return }

        if isNearBottom {
            pendingNewMessageCount = 0
            firstUnreadNewMessageID = nil
        } else {
            if firstUnreadNewMessageID == nil {
                firstUnreadNewMessageID = newFromOthers.map { $0.wireMessage.id }.min()
            }
            pendingNewMessageCount += newFromOthers.count
        }
    }

    /// Handles tapping the "Jump to new messages" banner.
    @discardableResult
    public mutating func jumpToBottomClearingNewMessages() -> Int? {
        let targetID = firstUnreadNewMessageID ?? messages.last?.wireMessage.id
        isNearBottom = true
        pendingNewMessageCount = 0
        firstUnreadNewMessageID = nil
        return targetID
    }
}

// MARK: - Member List with Roles (`ChannelMemberRoleRoster`)

public enum ChannelMemberRoleTier: Int, Comparable, Equatable, Sendable, CaseIterable {
    case owner = 0
    case coOwner = 1
    case operatorAdmin = 2
    case eventStaff = 3
    case member = 4

    public static func < (lhs: ChannelMemberRoleTier, rhs: ChannelMemberRoleTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var sectionTitle: String { sectionTitle(locale: ChannelCopy.defaultLocale) }

    public func sectionTitle(locale: Locale) -> String {
        switch self {
        case .owner: return ChannelCopy.text("主理人", "Owner", locale: locale)
        case .coOwner: return ChannelCopy.text("联席主理人", "Co-owner", locale: locale)
        case .operatorAdmin: return ChannelCopy.text("运营管理员", "Operations admin", locale: locale)
        case .eventStaff: return ChannelCopy.text("活动领队与核销", "Event lead & check-in", locale: locale)
        case .member: return ChannelCopy.text("俱乐部成员", "Club members", locale: locale)
        }
    }
}

public struct ChannelMemberRoleItem: Equatable, Sendable, Identifiable {
    public var id: Int { memberID }
    public let memberID: Int
    public let nickname: String
    public let avatar: String
    public let tier: ChannelMemberRoleTier
    public let roleCode: String
    public let badgeLabel: String
    public let holdsActiveRoleAssignment: Bool
    public let expiresText: String?

    public init(
        memberID: Int,
        nickname: String,
        avatar: String = "",
        tier: ChannelMemberRoleTier,
        roleCode: String,
        badgeLabel: String,
        holdsActiveRoleAssignment: Bool = false,
        expiresText: String? = nil
    ) {
        self.memberID = memberID
        self.nickname = nickname
        self.avatar = avatar
        self.tier = tier
        self.roleCode = roleCode
        self.badgeLabel = badgeLabel
        self.holdsActiveRoleAssignment = holdsActiveRoleAssignment
        self.expiresText = expiresText
    }
}

public struct ChannelMemberRoleSection: Equatable, Sendable, Identifiable {
    public var id: Int { tier.rawValue }
    public let tier: ChannelMemberRoleTier
    public let title: String
    public let members: [ChannelMemberRoleItem]

    public init(tier: ChannelMemberRoleTier, members: [ChannelMemberRoleItem], locale: Locale = ChannelCopy.defaultLocale) {
        self.tier = tier
        self.title = "\(tier.sectionTitle(locale: locale)) — \(members.count)"
        self.members = members
    }
}

public enum ChannelMemberRoleRoster {
    public static func buildSections(from members: [ChannelMemberRoleItem], locale: Locale = ChannelCopy.defaultLocale) -> [ChannelMemberRoleSection] {
        let sorted = members.sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            return $0.memberID < $1.memberID
        }
        return ChannelMemberRoleTier.allCases.compactMap { tier in
            let matching = sorted.filter { $0.tier == tier }
            guard !matching.isEmpty else { return nil }
            return ChannelMemberRoleSection(tier: tier, members: matching, locale: locale)
        }
    }

    public static func tier(forRoleCode roleCode: String) -> ChannelMemberRoleTier {
        switch roleCode.uppercased() {
        case "CLUB_OWNER", "OWNER":
            return .owner
        case "CLUB_CO_OWNER", "CO_OWNER":
            return .coOwner
        case "CLUB_OPERATOR", "OPERATOR", "ADMIN":
            return .operatorAdmin
        case "EVENT_LEAD", "EVENT_CHECKIN":
            return .eventStaff
        default:
            return .member
        }
    }
}

// MARK: - Safety (App Store Guideline 1.2) & Admin Moderation Controller

public struct ChannelContentFilterEvaluation: Equatable, Sendable {
    public let displayText: String
    public let wasModified: Bool
    public let matchedTerms: [String]

    public init(displayText: String, wasModified: Bool, matchedTerms: [String] = []) {
        self.displayText = displayText
        self.wasModified = wasModified
        self.matchedTerms = matchedTerms
    }
}

/// Pluggable content filtering hook required by App Store Review Guideline 1.2 for UGC channel messaging.
public struct ChannelContentFilterHook: Equatable, Sendable {
    public static let defaultObjectionableTerms: [String] = [
        "赌博", "诈骗", "洗钱", "外挂", "代刷", "色情", "微信号加我领奖"
    ]

    public let blockedSenderIDs: Set<Int>
    public let mutedKeywords: [String]
    public let maskObjectionableContent: Bool
    public let locale: Locale

    public init(
        blockedSenderIDs: Set<Int> = [],
        mutedKeywords: [String] = Self.defaultObjectionableTerms,
        maskObjectionableContent: Bool = true,
        locale: Locale = ChannelCopy.defaultLocale
    ) {
        self.locale = locale
        self.blockedSenderIDs = blockedSenderIDs
        self.mutedKeywords = mutedKeywords
        self.maskObjectionableContent = maskObjectionableContent
    }

    public static let `default` = ChannelContentFilterHook()

    /// Immediately hides any message authored by a blocked user (`hidesBlockedSenderMessagesImmediately`).
    public func shouldHideMessageImmediately(_ message: MessagingMessage) -> Bool {
        guard let senderID = message.senderID, senderID > 0 else { return false }
        return blockedSenderIDs.contains(senderID)
    }

    /// Evaluates message visibility (`recalled`/`blocked`/`unknown` fail-closed) and masks objectionable terms.
    public func evaluate(message: MessagingMessage) -> ChannelContentFilterEvaluation {
        guard message.isPayloadVisible else {
            let placeholder: String
            switch message.status {
            case .recalled:
                placeholder = ChannelCopy.text("该消息已撤回", "This message was recalled", locale: locale)
            case .blocked:
                placeholder = ChannelCopy.text("该消息因违反社区安全规范已被屏蔽", "This message was hidden by community safety filters.", locale: locale)
            case .unknown, .normal:
                placeholder = ChannelCopy.text("消息不可用", "Message unavailable", locale: locale)
            }
            return ChannelContentFilterEvaluation(displayText: placeholder, wasModified: true)
        }

        let rawText = message.content ?? ""
        guard maskObjectionableContent, !rawText.isEmpty else {
            return ChannelContentFilterEvaluation(displayText: rawText, wasModified: false)
        }

        var masked = rawText
        var matched: [String] = []
        for term in mutedKeywords where !term.isEmpty {
            if masked.localizedCaseInsensitiveContains(term) {
                matched.append(term)
                masked = masked.replacingOccurrences(
                    of: term,
                    with: String(repeating: "＊", count: max(2, term.count)),
                    options: [.caseInsensitive]
                )
            }
        }

        return ChannelContentFilterEvaluation(
            displayText: masked,
            wasModified: !matched.isEmpty,
            matchedTerms: matched
        )
    }
}

/// Moderation & safety action descriptors wired to the exact mini-program and backend endpoints.
public enum ChannelSafetyModerationEndpoint: Equatable, Sendable {
    /// `POST /api/im/report` (`message_id`, `reason`)
    case reportMessage(messageID: Int, reason: String)
    /// `POST /api/club/governance/cases/report` (`club_id`, `target_type`, `target_id`, `reason_code`, `detail`)
    case reportClubUser(clubID: Int, targetMemberID: Int, reasonCode: String, detail: String)
    /// `POST /api/club/governance/cases/report` or `POST /api/im/report` (`club_id`, `channel_id`, `reason_code`, `detail`)
    case reportChannel(clubID: Int, channelID: Int, reasonCode: String, detail: String)
    /// `POST /api/im/block` (`target_member_id`)
    case blockUser(targetMemberID: Int)
    /// `POST /api/im/unblock` (`target_member_id`)
    case unblockUser(targetMemberID: Int)
    /// `POST /api/im/mute` (`conversation_id`, `muted`)
    case muteChannel(conversationID: Int, muted: Bool)
    /// Admin/author message deletion or moderation recall inside club channel/community
    case deleteMessage(clubID: Int, channelID: Int, messageID: Int)
    /// `POST /api/club/remove-member` (`club_id`, `member_id`)
    case removeMember(clubID: Int, targetMemberID: Int)
    /// `POST /api/club/governance/ban` (`club_id`, `member_id`, `reason_code`, `reason_text`, `expires_at`)
    case banMember(clubID: Int, targetMemberID: Int, reasonCode: String, reasonText: String)
    /// `POST /api/club/governance/unban` (`club_id`, `ban_id`, `reason`)
    case unbanMember(clubID: Int, banID: Int, reason: String)

    public var apiPath: String {
        switch self {
        case .reportMessage:
            return "api/im/report"
        case .reportClubUser, .reportChannel:
            return "api/club/governance/cases/report"
        case .blockUser:
            return "api/im/block"
        case .unblockUser:
            return "api/im/unblock"
        case .muteChannel:
            return "api/im/mute"
        case .deleteMessage:
            return "api/club/post/delete"
        case .removeMember:
            return "api/club/remove-member"
        case .banMember:
            return "api/club/governance/ban"
        case .unbanMember:
            return "api/club/governance/unban"
        }
    }
}

public enum ChannelModerationDenialReason: String, Error, Equatable, Sendable {
    case unauthenticated
    case channelAdmissionRequired
    case channelRevokedOrBanned
    case cannotTargetSelf
    case cannotTargetClubOwner
    case targetHoldsActiveRoleAssignment
    case insufficientModerationPermission
    case platformBanCannotBeUnbannedByClubAdmin
    case invalidMessageOrReason
}

/// Represents an active ban record evaluated by club channel moderation (`POST /api/club/governance/unban`).
public struct ChannelModerationBanRecord: Equatable, Sendable, Identifiable {
    public let id: Int
    public let targetMemberID: Int
    public let nickname: String
    /// `"CLUB"` or `"PLATFORM"`. Platform bans cannot be lifted by club admins.
    public let source: String
    public let status: String
    public let reasonCode: String
    public let reasonText: String

    public init(
        id: Int,
        targetMemberID: Int,
        nickname: String,
        source: String,
        status: String = "ACTIVE",
        reasonCode: String,
        reasonText: String
    ) {
        self.id = id
        self.targetMemberID = targetMemberID
        self.nickname = nickname
        self.source = source
        self.status = status
        self.reasonCode = reasonCode
        self.reasonText = reasonText
    }

    public var platformOnly: Bool {
        source.uppercased() == "PLATFORM"
    }
}

/// Capabilities projected from `ClubGovernancePermissions` or role assignments.
public struct ChannelModerationCapabilities: Equatable, Sendable {
    public let canManageMembers: Bool
    public let canManageBans: Bool
    public let canManageContent: Bool
    public let canManageRoles: Bool

    public init(
        canManageMembers: Bool = false,
        canManageBans: Bool = false,
        canManageContent: Bool = false,
        canManageRoles: Bool = false
    ) {
        self.canManageMembers = canManageMembers
        self.canManageBans = canManageBans
        self.canManageContent = canManageContent
        self.canManageRoles = canManageRoles
    }

    public init(governancePermissions: ClubGovernancePermissions, scope: ClubGovernanceScope) {
        let isOwner = governancePermissions.allows("OWNER", scope: scope)
        let hasWrite = governancePermissions.allows("club:write", scope: scope)
        self.canManageMembers = isOwner || hasWrite || governancePermissions.allows("club:members:manage", scope: scope)
        self.canManageBans = isOwner || hasWrite || governancePermissions.allows("club:bans:manage", scope: scope)
        self.canManageContent = isOwner || hasWrite || governancePermissions.allows("club:content:manage", scope: scope)
        self.canManageRoles = governancePermissions.canManageRoles
    }
}

/// Evaluates user safety (Guideline 1.2) and club admin moderation permissions while preserving `ChannelRulesAdmission` and `ChannelRevokeIsolation`.
public struct ChannelSafetyModerationPolicy: Equatable, Sendable {
    public let clubID: Int
    public let viewerMemberID: Int
    public let viewerRoleTier: ChannelMemberRoleTier
    public let capabilities: ChannelModerationCapabilities
    public let hasAcceptedChannelRules: Bool
    public let isChannelAccessRevoked: Bool

    public init(
        clubID: Int,
        viewerMemberID: Int,
        viewerRoleTier: ChannelMemberRoleTier,
        capabilities: ChannelModerationCapabilities = ChannelModerationCapabilities(),
        hasAcceptedChannelRules: Bool = false,
        isChannelAccessRevoked: Bool = false
    ) {
        self.clubID = clubID
        self.viewerMemberID = viewerMemberID
        self.viewerRoleTier = viewerRoleTier
        self.capabilities = capabilities
        self.hasAcceptedChannelRules = hasAcceptedChannelRules
        self.isChannelAccessRevoked = isChannelAccessRevoked
    }

    public var canModerateMessages: Bool {
        guard viewerMemberID > 0, !isChannelAccessRevoked else { return false }
        return viewerRoleTier == .owner
            || viewerRoleTier == .coOwner
            || viewerRoleTier == .operatorAdmin
            || capabilities.canManageMembers
            || capabilities.canManageContent
    }

    public var canRemoveOrBanMembers: Bool {
        guard viewerMemberID > 0, !isChannelAccessRevoked else { return false }
        return viewerRoleTier == .owner
            || viewerRoleTier == .coOwner
            || viewerRoleTier == .operatorAdmin
            || capabilities.canManageMembers
            || capabilities.canManageBans
    }

    /// Evaluates whether the viewer can report a message (`POST /api/im/report`).
    public func validateReportMessage(
        message: MessagingMessage,
        reason: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard message.id > 0, message.isPayloadVisible else {
            return .failure(.invalidMessageOrReason)
        }
        guard (message.senderID ?? 0) != viewerMemberID else {
            return .failure(.cannotTargetSelf)
        }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else {
            return .failure(.invalidMessageOrReason)
        }
        return .success(.reportMessage(messageID: message.id, reason: trimmed))
    }

    /// Evaluates whether the viewer can report a user in the club (`POST /api/club/governance/cases/report`, enforces `CU-C-52` no self-report).
    public func validateReportUser(
        targetMemberID: Int,
        reasonCode: String,
        detail: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard targetMemberID > 0, targetMemberID != viewerMemberID else {
            return .failure(.cannotTargetSelf)
        }
        let code = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .failure(.invalidMessageOrReason) }
        return .success(
            .reportClubUser(
                clubID: clubID,
                targetMemberID: targetMemberID,
                reasonCode: code,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    /// Evaluates whether the viewer can block or unblock a user (`POST /api/im/block`, `POST /api/im/unblock`).
    public func validateBlockUser(
        targetMemberID: Int,
        shouldBlock: Bool
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard targetMemberID > 0, targetMemberID != viewerMemberID else {
            return .failure(.cannotTargetSelf)
        }
        return .success(shouldBlock ? .blockUser(targetMemberID: targetMemberID) : .unblockUser(targetMemberID: targetMemberID))
    }

    /// Evaluates whether the viewer can delete/recall a message in a channel.
    public func validateDeleteMessage(
        channelID: Int,
        message: MessagingMessage
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard message.id > 0, message.isPayloadVisible else {
            return .failure(.invalidMessageOrReason)
        }
        let isAuthor = (message.senderID ?? 0) == viewerMemberID
        guard isAuthor || canModerateMessages else {
            return .failure(.insufficientModerationPermission)
        }
        return .success(.deleteMessage(clubID: clubID, channelID: channelID, messageID: message.id))
    }

    /// Evaluates whether an admin can remove a member (`POST /api/club/remove-member`), respecting `ApiClubController.holdsActiveRoleAssignment`.
    public func validateRemoveMember(
        target: ChannelMemberRoleItem
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard canRemoveOrBanMembers else { return .failure(.insufficientModerationPermission) }
        guard target.memberID != viewerMemberID else { return .failure(.cannotTargetSelf) }
        guard target.tier != .owner else { return .failure(.cannotTargetClubOwner) }
        if target.holdsActiveRoleAssignment {
            return .failure(.targetHoldsActiveRoleAssignment)
        }
        return .success(.removeMember(clubID: clubID, targetMemberID: target.memberID))
    }

    /// Evaluates whether an admin can ban a member (`POST /api/club/governance/ban`).
    public func validateBanMember(
        target: ChannelMemberRoleItem,
        reasonCode: String,
        reasonText: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard capabilities.canManageBans || viewerRoleTier == .owner || viewerRoleTier == .coOwner else {
            return .failure(.insufficientModerationPermission)
        }
        guard target.memberID != viewerMemberID else { return .failure(.cannotTargetSelf) }
        guard target.tier != .owner else { return .failure(.cannotTargetClubOwner) }
        let code = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .failure(.invalidMessageOrReason) }
        return .success(
            .banMember(
                clubID: clubID,
                targetMemberID: target.memberID,
                reasonCode: code,
                reasonText: reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    /// Evaluates whether an admin can lift a ban (`POST /api/club/governance/unban`), enforcing `platformOnly`.
    public func validateUnbanMember(
        banRow: ChannelModerationBanRecord,
        reason: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard capabilities.canManageBans || viewerRoleTier == .owner || viewerRoleTier == .coOwner else {
            return .failure(.insufficientModerationPermission)
        }
        if banRow.platformOnly {
            return .failure(.platformBanCannotBeUnbannedByClubAdmin)
        }
        return .success(
            .unbanMember(
                clubID: clubID,
                banID: banRow.id,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    /// Evaluates whether the viewer can report a channel (`POST /api/club/governance/cases/report` or `POST /api/im/report`).
    public func validateReportChannel(
        channelID: Int,
        reasonCode: String,
        detail: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard clubID > 0, channelID > 0 else { return .failure(.invalidMessageOrReason) }
        let code = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, trimmedDetail.count <= 500 else {
            return .failure(.invalidMessageOrReason)
        }
        return .success(
            .reportChannel(
                clubID: clubID,
                channelID: channelID,
                reasonCode: code,
                detail: trimmedDetail
            )
        )
    }

    /// Evaluates whether the viewer can mute or unmute a channel (`POST /api/im/mute`).
    public func validateMuteChannel(
        conversationID: Int,
        muted: Bool
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard conversationID > 0 else { return .failure(.invalidMessageOrReason) }
        return .success(.muteChannel(conversationID: conversationID, muted: muted))
    }
}

// MARK: - Persistent Channel Rules / EULA Gate & Blocked Users Stores (App Store 1.2)

public protocol ChannelRulesAcceptanceStoring: Sendable {
    func hasAcceptedRules(clubID: Int, viewerMemberID: Int, rulesVersion: Int) -> Bool
    func recordAcceptedRules(clubID: Int, viewerMemberID: Int, rulesVersion: Int)
    func revokeAcceptedRules(clubID: Int, viewerMemberID: Int)
}

public final class UserDefaultsChannelRulesAcceptanceStore: ChannelRulesAcceptanceStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let namespace: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, namespace: String = "default") {
        self.defaults = defaults
        self.namespace = namespace
    }

    private func storageKey(clubID: Int, viewerMemberID: Int) -> String {
        "questify.channel.rules.accepted.\(namespace).club.\(clubID).member.\(viewerMemberID)"
    }

    public func hasAcceptedRules(clubID: Int, viewerMemberID: Int, rulesVersion: Int) -> Bool {
        guard clubID > 0, viewerMemberID > 0, rulesVersion > 0 else { return false }
        lock.lock()
        defer { lock.unlock() }
        let acceptedVersion = defaults.integer(forKey: storageKey(clubID: clubID, viewerMemberID: viewerMemberID))
        return acceptedVersion >= rulesVersion
    }

    public func recordAcceptedRules(clubID: Int, viewerMemberID: Int, rulesVersion: Int) {
        guard clubID > 0, viewerMemberID > 0, rulesVersion > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        defaults.set(rulesVersion, forKey: storageKey(clubID: clubID, viewerMemberID: viewerMemberID))
    }

    public func revokeAcceptedRules(clubID: Int, viewerMemberID: Int) {
        guard clubID > 0, viewerMemberID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: storageKey(clubID: clubID, viewerMemberID: viewerMemberID))
    }
}

public final class InMemoryChannelRulesAcceptanceStore: ChannelRulesAcceptanceStoring, @unchecked Sendable {
    private var acceptedVersionsByScope: [String: Int] = [:]
    private let lock = NSLock()

    public init(initialAcceptedVersions: [String: Int] = [:]) {
        self.acceptedVersionsByScope = initialAcceptedVersions
    }

    private func storageKey(clubID: Int, viewerMemberID: Int) -> String {
        "\(clubID):\(viewerMemberID)"
    }

    public func hasAcceptedRules(clubID: Int, viewerMemberID: Int, rulesVersion: Int) -> Bool {
        guard clubID > 0, viewerMemberID > 0, rulesVersion > 0 else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard let version = acceptedVersionsByScope[storageKey(clubID: clubID, viewerMemberID: viewerMemberID)] else {
            return false
        }
        return version >= rulesVersion
    }

    public func recordAcceptedRules(clubID: Int, viewerMemberID: Int, rulesVersion: Int) {
        guard clubID > 0, viewerMemberID > 0, rulesVersion > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        acceptedVersionsByScope[storageKey(clubID: clubID, viewerMemberID: viewerMemberID)] = rulesVersion
    }

    public func revokeAcceptedRules(clubID: Int, viewerMemberID: Int) {
        guard clubID > 0, viewerMemberID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        acceptedVersionsByScope.removeValue(forKey: storageKey(clubID: clubID, viewerMemberID: viewerMemberID))
    }
}

public protocol ChannelBlockedUsersStoring: Sendable {
    func blockedUserIDs(clubID: Int, viewerMemberID: Int) -> Set<Int>
    func addBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int)
    func removeBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int)
}

public final class UserDefaultsChannelBlockedUsersStore: ChannelBlockedUsersStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let namespace: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, namespace: String = "default") {
        self.defaults = defaults
        self.namespace = namespace
    }

    private func storageKey(clubID: Int, viewerMemberID: Int) -> String {
        "questify.channel.blocked.users.\(namespace).club.\(clubID).member.\(viewerMemberID)"
    }

    public func blockedUserIDs(clubID: Int, viewerMemberID: Int) -> Set<Int> {
        guard clubID > 0, viewerMemberID > 0 else { return [] }
        lock.lock()
        defer { lock.unlock() }
        let raw = defaults.array(forKey: storageKey(clubID: clubID, viewerMemberID: viewerMemberID)) as? [Int] ?? []
        return Set(raw.filter { $0 > 0 })
    }

    public func addBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int) {
        guard targetMemberID > 0, clubID > 0, viewerMemberID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        let key = storageKey(clubID: clubID, viewerMemberID: viewerMemberID)
        var current = Set((defaults.array(forKey: key) as? [Int] ?? []).filter { $0 > 0 })
        current.insert(targetMemberID)
        defaults.set(Array(current).sorted(), forKey: key)
    }

    public func removeBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int) {
        guard targetMemberID > 0, clubID > 0, viewerMemberID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        let key = storageKey(clubID: clubID, viewerMemberID: viewerMemberID)
        var current = Set((defaults.array(forKey: key) as? [Int] ?? []).filter { $0 > 0 })
        current.remove(targetMemberID)
        defaults.set(Array(current).sorted(), forKey: key)
    }
}

public final class InMemoryChannelBlockedUsersStore: ChannelBlockedUsersStoring, @unchecked Sendable {
    private var blockedByScope: [String: Set<Int>] = [:]
    private let lock = NSLock()

    public init(initialBlockedByScope: [String: Set<Int>] = [:]) {
        self.blockedByScope = initialBlockedByScope
    }

    private func storageKey(clubID: Int, viewerMemberID: Int) -> String {
        "\(clubID):\(viewerMemberID)"
    }

    public func blockedUserIDs(clubID: Int, viewerMemberID: Int) -> Set<Int> {
        guard clubID > 0, viewerMemberID > 0 else { return [] }
        lock.lock()
        defer { lock.unlock() }
        return blockedByScope[storageKey(clubID: clubID, viewerMemberID: viewerMemberID)] ?? []
    }

    public func addBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int) {
        guard targetMemberID > 0, clubID > 0, viewerMemberID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        let key = storageKey(clubID: clubID, viewerMemberID: viewerMemberID)
        var set = blockedByScope[key] ?? []
        set.insert(targetMemberID)
        blockedByScope[key] = set
    }

    public func removeBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int) {
        guard targetMemberID > 0, clubID > 0, viewerMemberID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        let key = storageKey(clubID: clubID, viewerMemberID: viewerMemberID)
        var set = blockedByScope[key] ?? []
        set.remove(targetMemberID)
        blockedByScope[key] = set
    }
}

// MARK: - Core Club Channel Safety & Directory Service Bridge

public struct ClubChannelWorkspacePayload: Equatable, Sendable {
    public let listing: ChannelDirectoryListing
    public let initialMessagesByChannelID: [Int64: [ChannelTranscriptMessage]]
    public let activeBans: [ChannelModerationBanRecord]
    public let rulesVersion: Int

    public init(
        listing: ChannelDirectoryListing,
        initialMessagesByChannelID: [Int64: [ChannelTranscriptMessage]],
        activeBans: [ChannelModerationBanRecord] = [],
        rulesVersion: Int = 1
    ) {
        self.listing = listing
        self.initialMessagesByChannelID = initialMessagesByChannelID
        self.activeBans = activeBans
        self.rulesVersion = max(1, rulesVersion)
    }
}

public enum ChannelSafetyServiceError: Error, Equatable, Sendable {
    case unauthenticated
    case channelDirectoryUnavailable
    case serviceUnavailable(endpoint: ChannelSafetyModerationEndpoint)
    case messageSendUnavailable
    /// The backend contract has no safe route for this action; it is refused rather than approximated.
    case unsupported(endpoint: ChannelSafetyModerationEndpoint)
    case operationFailed(reason: String)

    public func localizedDescription(locale: Locale) -> String {
        switch self {
        case .unauthenticated:
            return ChannelCopy.text("请先登录后再执行该操作。", "Please sign in before performing this action.", locale: locale)
        case .channelDirectoryUnavailable:
            return ChannelCopy.text("该俱乐部暂未开通频道列表或频道读取服务不可用。", "Channel directory is unavailable for this club.", locale: locale)
        case .serviceUnavailable(let endpoint):
            return ChannelCopy.text("安全治理服务暂不可用（\(endpoint.apiPath)），请稍后重试。", "Safety moderation service is unavailable (\(endpoint.apiPath)). Please retry.", locale: locale)
        case .unsupported(let endpoint):
            if case .deleteMessage = endpoint {
                return ChannelCopy.text("暂不支持删除单条消息，该消息未被删除。你可以举报该消息。", "Deleting a single message isn't supported yet, and the message was not deleted. You can report it instead.", locale: locale)
            }
            return ChannelCopy.text("该操作暂不支持，未执行任何更改。", "This action isn't supported yet. Nothing was changed.", locale: locale)
        case .messageSendUnavailable:
            return ChannelCopy.text("频道发信服务暂不可用，请检查网络或重试。", "Channel message sending service is unavailable. Please retry.", locale: locale)
        case .operationFailed(let reason):
            return reason.isEmpty
                ? ChannelCopy.text("操作请求失败，请重试。", "Operation failed. Please retry.", locale: locale)
                : reason
        }
    }
}

@MainActor
public protocol ClubChannelSafetyServing: AnyObject {
    func loadChannelWorkspace(club: ClubRecord, viewerMemberID: Int) async throws -> ClubChannelWorkspacePayload
    func performModeration(_ endpoint: ChannelSafetyModerationEndpoint, activeChannelID: Int) async throws
    func sendChannelMessage(
        clubID: Int,
        channelID: Int,
        clientMessageID: String,
        content: String,
        replyToMessageID: Int?
    ) async throws -> Int
}

/// Routes club channel directory loading and all safety/moderation endpoints through the existing Core services:
/// - `IMSafetyWriting` (`api/im/report`, `api/im/block`, `api/im/unblock`, `api/im/delete`)
/// - `IMExpandedWriting` (`api/im/mute`, `api/im/send`)
/// - `ClubManagementAccess` (`api/club/remove-member`)
/// - `ClubGovernanceAccess` / `ClubGovernanceCoordinator` (`api/club/governance/cases/report`, `api/club/governance/ban`, `api/club/governance/unban`)
/// - `NativeChannelManagementCoordinator` (`GET api/guilds/1/{clubID}/channels`) & `MessagingReading` (`NativeChannelSpace.project`)
@MainActor
public final class CoreClubChannelSafetyService: ClubChannelSafetyServing {
    private let imSafetyWriterProvider: () -> (any IMSafetyWriting)?
    private let imExpandedWriterProvider: () -> (any IMExpandedWriting)?
    private let messageWriterProvider: () -> (any MessageActionWriting)?
    private let messagingReaderProvider: () -> (any MessagingReading)?
    private let clubManagementAccessProvider: () -> (any ClubManagementAccess)?
    private let clubGovernanceAccessProvider: () -> (any ClubGovernanceAccess)?
    private let clubGovernanceCoordinatorProvider: () -> ClubGovernanceCoordinator?
    private let nativeChannelDirectoryLoader: ((Int) async throws -> NativeChannelManagementDirectory?)?
    private let messageDeleteDispatcher: ((Int, Int, Int) async throws -> Void)?

    public init(
        imSafetyWriter: @escaping () -> (any IMSafetyWriting)? = { nil },
        imExpandedWriter: @escaping () -> (any IMExpandedWriting)? = { nil },
        messageWriter: @escaping () -> (any MessageActionWriting)? = { nil },
        messagingReader: @escaping () -> (any MessagingReading)? = { nil },
        clubManagementAccess: @escaping () -> (any ClubManagementAccess)? = { nil },
        clubGovernanceAccess: @escaping () -> (any ClubGovernanceAccess)? = { nil },
        clubGovernanceCoordinator: @escaping () -> ClubGovernanceCoordinator? = { nil },
        nativeChannelDirectoryLoader: ((Int) async throws -> NativeChannelManagementDirectory?)? = nil,
        messageDeleteDispatcher: ((Int) async throws -> Void)? = nil
    ) {
        self.imSafetyWriterProvider = imSafetyWriter
        self.imExpandedWriterProvider = imExpandedWriter
        self.messageWriterProvider = messageWriter
        self.messagingReaderProvider = messagingReader
        self.clubManagementAccessProvider = clubManagementAccess
        self.clubGovernanceAccessProvider = clubGovernanceAccess
        self.clubGovernanceCoordinatorProvider = clubGovernanceCoordinator
        self.nativeChannelDirectoryLoader = nativeChannelDirectoryLoader
        if let messageDeleteDispatcher {
            self.messageDeleteDispatcher = { _, channelID, _ in try await messageDeleteDispatcher(channelID) }
        } else {
            self.messageDeleteDispatcher = nil
        }
    }

    public init(
        imSafetyWriter: @escaping () -> (any IMSafetyWriting)? = { nil },
        imExpandedWriter: @escaping () -> (any IMExpandedWriting)? = { nil },
        messageWriter: @escaping () -> (any MessageActionWriting)? = { nil },
        messagingReader: @escaping () -> (any MessagingReading)? = { nil },
        clubManagementAccess: @escaping () -> (any ClubManagementAccess)? = { nil },
        clubGovernanceAccess: @escaping () -> (any ClubGovernanceAccess)? = { nil },
        clubGovernanceCoordinator: @escaping () -> ClubGovernanceCoordinator? = { nil },
        nativeChannelDirectoryLoader: ((Int) async throws -> NativeChannelManagementDirectory?)? = nil,
        channelMessageDeleteDispatcher: ((Int, Int, Int) async throws -> Void)?
    ) {
        self.imSafetyWriterProvider = imSafetyWriter
        self.imExpandedWriterProvider = imExpandedWriter
        self.messageWriterProvider = messageWriter
        self.messagingReaderProvider = messagingReader
        self.clubManagementAccessProvider = clubManagementAccess
        self.clubGovernanceAccessProvider = clubGovernanceAccess
        self.clubGovernanceCoordinatorProvider = clubGovernanceCoordinator
        self.nativeChannelDirectoryLoader = nativeChannelDirectoryLoader
        self.messageDeleteDispatcher = channelMessageDeleteDispatcher
    }

    public func loadChannelWorkspace(club: ClubRecord, viewerMemberID: Int) async throws -> ClubChannelWorkspacePayload {
        guard club.id > 0, viewerMemberID > 0 else {
            throw ChannelSafetyServiceError.unauthenticated
        }

        var resolvedListing: ChannelDirectoryListing?
        var messagesByChannelID: [Int64: [ChannelTranscriptMessage]] = [:]

        if let loader = nativeChannelDirectoryLoader,
           let nativeDirectory = try await loader(club.id) {
            resolvedListing = Self.projectNativeDirectory(nativeDirectory, clubID: club.id)
        }

        if let reader = messagingReaderProvider(), reader.isConfigured {
            let conversations = try await reader.messagingConversations()
            let clubSpaces = NativeChannelSpace.project(conversations).filter {
                $0.kind == .club && $0.spaceID == club.id
            }
            let directClubConversations = conversations.filter { conv in
                conv.kind == .group && (
                    conv.directoryContext?.spaceID == Int64(club.id)
                    || conv.counterparty?.bizKey == "club_\(club.id)"
                )
            }
            let mergedConversations: [MessagingConversation]
            if let firstSpace = clubSpaces.first, !firstSpace.channels.isEmpty {
                mergedConversations = firstSpace.channels
            } else {
                mergedConversations = directClubConversations
            }

            if resolvedListing == nil, !mergedConversations.isEmpty {
                resolvedListing = Self.projectMessagingConversations(mergedConversations, club: club)
            }

            if let listing = resolvedListing {
                for channel in listing.channels {
                    let page = try? await reader.messagingMessages(
                        conversationID: Int(channel.id),
                        cursor: 0
                    )
                    let items = (page?.messages ?? []).map { ChannelTranscriptMessage(wireMessage: $0) }
                    messagesByChannelID[channel.id] = items
                }
            }
        }

        guard let listing = resolvedListing, !listing.channels.isEmpty else {
            throw ChannelSafetyServiceError.channelDirectoryUnavailable
        }

        var loadedBans: [ChannelModerationBanRecord] = []
        if let governance = clubGovernanceAccessProvider(), governance.isConfigured {
            if let snapshot = try? await governance.read(.bans, scope: .init(clubID: club.id), options: [:]) {
                loadedBans = Self.projectBanRecords(from: snapshot)
            }
        }

        for ch in listing.channels where messagesByChannelID[ch.id] == nil {
            messagesByChannelID[ch.id] = []
        }

        return ClubChannelWorkspacePayload(
            listing: listing,
            initialMessagesByChannelID: messagesByChannelID,
            activeBans: loadedBans,
            rulesVersion: 1
        )
    }

    public func performModeration(_ endpoint: ChannelSafetyModerationEndpoint, activeChannelID: Int) async throws {
        let conversationID = max(activeChannelID, 1)
        switch endpoint {
        case .reportMessage(let messageID, let reason):
            let action = IMSafetyAction.reportWithReason(conversationID: conversationID, messageID: messageID, reason: reason)
            guard let writer = imSafetyWriterProvider(), writer.permits(action), let identity = writer.identity else {
                throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)
            }
            try await writer.perform(action, expectedIdentity: identity)

        case .reportClubUser(let clubID, let targetMemberID, let reasonCode, let detail):
            let formattedReason = detail.isEmpty ? reasonCode : "\(reasonCode): \(detail)"
            if try await dispatchGovernanceReportIfAvailable(
                clubID: clubID,
                targetType: "MEMBER",
                targetID: targetMemberID,
                reason: formattedReason
            ) {
                return
            }
            // api/im/report takes a message id; a member id must never be sent as one. Governance route only.
            throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)

        case .reportChannel(let clubID, let channelID, let reasonCode, let detail):
            let formattedReason = detail.isEmpty ? reasonCode : "\(reasonCode): \(detail)"
            // api/im/report takes a message id; a channel id must never be sent as one. Governance route only.
            if try await dispatchGovernanceReportIfAvailable(
                clubID: clubID,
                targetType: "CLUB",
                targetID: clubID,
                reason: "[Channel #\(channelID)] \(formattedReason)"
            ) {
                return
            }
            throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)

        case .blockUser(let targetMemberID):
            let action = IMSafetyAction.block(conversationID: conversationID, targetMemberID: targetMemberID)
            guard let writer = imSafetyWriterProvider(), writer.permits(action), let identity = writer.identity else {
                throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)
            }
            try await writer.perform(action, expectedIdentity: identity)

        case .unblockUser(let targetMemberID):
            let action = IMSafetyAction.unblock(conversationID: conversationID, targetMemberID: targetMemberID)
            guard let writer = imSafetyWriterProvider(), writer.permits(action), let identity = writer.identity else {
                throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)
            }
            try await writer.perform(action, expectedIdentity: identity)

        case .muteChannel(let channelConversationID, let muted):
            guard let writer = imExpandedWriterProvider(), writer.isConfigured, let identity = writer.identity else {
                throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)
            }
            _ = try await writer.perform(.mute(conversationID: channelConversationID, muted: muted), expectedIdentity: identity)

        case .deleteMessage(let clubID, let channelID, let messageID):
            // Never fall back to api/im/delete: that hides the whole conversation, not one message.
            guard let deleteDispatcher = messageDeleteDispatcher else {
                throw ChannelSafetyServiceError.unsupported(endpoint: endpoint)
            }
            try await deleteDispatcher(clubID, channelID, messageID)

        case .removeMember(let clubID, let targetMemberID):
            guard let access = clubManagementAccessProvider(), access.isConfigured, let identity = access.identity else {
                throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)
            }
            _ = try await access.perform(.remove, clubID: clubID, memberID: targetMemberID, expectedIdentity: identity)

        case .banMember(let clubID, let targetMemberID, let reasonCode, let reasonText):
            let formattedReason = reasonText.isEmpty ? reasonCode : "\(reasonCode): \(reasonText)"
            let nowMs = Int((Date().timeIntervalSince1970 * 1000).rounded(.down))
            let expiryMs = nowMs + (30 * 86_400_000)
            let command = try ClubGovernanceCommand(
                operation: .ban,
                scope: .init(clubID: clubID),
                values: [
                    "targetMemberId": .integer(targetMemberID),
                    "reason": .string(formattedReason),
                    "requestId": .string("channel-ban-\(clubID)-\(targetMemberID)-\(UUID().uuidString.prefix(8))"),
                    "expiresAtEpochMs": .integer(expiryMs)
                ]
            )
            try await dispatchGovernanceCommand(command, endpoint: endpoint)

        case .unbanMember(let clubID, let banID, let reason):
            let command = try ClubGovernanceCommand(
                operation: .unban,
                scope: .init(clubID: clubID),
                values: [
                    "banId": .integer(banID),
                    "version": .integer(1),
                    "reason": .string(reason),
                    "requestId": .string("channel-unban-\(clubID)-\(banID)-\(UUID().uuidString.prefix(8))")
                ]
            )
            try await dispatchGovernanceCommand(command, endpoint: endpoint)
        }
    }

    public func sendChannelMessage(
        clubID: Int,
        channelID: Int,
        clientMessageID: String,
        content: String,
        replyToMessageID: Int?
    ) async throws -> Int {
        guard let writer = messageWriterProvider(), writer.isConfigured, let identity = writer.identity else {
            throw ChannelSafetyServiceError.messageSendUnavailable
        }
        let hexID = Self.stableIdempotencyID(for: clientMessageID)
        let intent = try MessageTextIntent(
            conversationID: channelID,
            content: content,
            clientMessageID: hexID
        )
        let sentMessage = try await writer.send(intent, expectedIdentity: identity)
        return sentMessage.id
    }

    /// One draft, one idempotency id: a 32-hex client id is used as-is; anything else is hashed deterministically
    /// so every retry of the same draft sends the same id (never a fresh random UUID).
    public static func stableIdempotencyID(for clientMessageID: String) -> String {
        let lowered = clientMessageID.lowercased()
        if lowered.count == 32, lowered.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) }) { return lowered }
        let digest = SHA256.hash(data: Data(clientMessageID.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func dispatchGovernanceReportIfAvailable(
        clubID: Int,
        targetType: String,
        targetID: Int,
        reason: String
    ) async throws -> Bool {
        let command = try ClubGovernanceCommand(
            operation: .report,
            scope: .init(clubID: clubID),
            values: [
                "targetType": .string(targetType),
                "targetId": .integer(targetID),
                "reason": .string(reason),
                "requestId": .string("channel-report-\(clubID)-\(targetID)-\(UUID().uuidString.prefix(8))")
            ]
        )
        if let coordinator = clubGovernanceCoordinatorProvider(), coordinator.canDispatch(command) {
            let review = try await coordinator.prepare(command)
            _ = try await coordinator.confirm(review)
            return true
        }
        if let access = clubGovernanceAccessProvider(), access.isConfigured, access.canDispatch(command) {
            let coordinator = ClubGovernanceCoordinator(access: access)
            let review = try await coordinator.prepare(command)
            _ = try await coordinator.confirm(review)
            return true
        }
        return false
    }

    private func dispatchGovernanceCommand(
        _ command: ClubGovernanceCommand,
        endpoint: ChannelSafetyModerationEndpoint
    ) async throws {
        if let coordinator = clubGovernanceCoordinatorProvider(), coordinator.canDispatch(command) {
            let review = try await coordinator.prepare(command)
            _ = try await coordinator.confirm(review)
            return
        }
        if let access = clubGovernanceAccessProvider(), access.isConfigured, access.canDispatch(command) {
            let coordinator = ClubGovernanceCoordinator(access: access)
            let review = try await coordinator.prepare(command)
            _ = try await coordinator.confirm(review)
            return
        }
        throw ChannelSafetyServiceError.serviceUnavailable(endpoint: endpoint)
    }

    public static func projectNativeDirectory(
        _ directory: NativeChannelManagementDirectory,
        clubID: Int
    ) -> ChannelDirectoryListing {
        let clubID64 = Int64(max(1, clubID))
        var categories: [ChannelDirectoryCategory] = []
        var channels: [ChannelDirectoryEntry] = []

        for (index, group) in directory.groups.enumerated() {
            let catID = Int64(group.category.id.rawValue) ?? Int64(index + 1)
            categories.append(
                ChannelDirectoryCategory(
                    id: catID,
                    clubID: clubID64,
                    name: group.category.name,
                    position: (index + 1) * 10
                )
            )
            for ch in group.channels {
                guard let chID = Int64(ch.id.rawValue) else { continue }
                let resolvedKind = ch.kind == 2 ? 2 : 1
                let resolvedVisibility = max(0, ch.visibility - 1)
                channels.append(
                    ChannelDirectoryEntry(
                        id: chID,
                        clubID: clubID64,
                        categoryID: catID,
                        name: ch.name,
                        kind: resolvedKind,
                        visibility: resolvedVisibility,
                        position: ch.position,
                        archivedAt: ch.status >= 2 ? (ch.purgeAt ?? "archived") : nil,
                        myState: ChannelDirectoryMyState(
                            lastReadMessageID: nil,
                            lastReadAt: nil,
                            notifyPref: 0,
                            unreadCount: 0,
                            readStateAvailable: true
                        ),
                        lastMessagePreview: nil
                    )
                )
            }
        }

        for ch in directory.ungrouped {
            guard let chID = Int64(ch.id.rawValue) else { continue }
            let resolvedKind = ch.kind == 2 ? 2 : 1
            let resolvedVisibility = max(0, ch.visibility - 1)
            channels.append(
                ChannelDirectoryEntry(
                    id: chID,
                    clubID: clubID64,
                    categoryID: nil,
                    name: ch.name,
                    kind: resolvedKind,
                    visibility: resolvedVisibility,
                    position: ch.position,
                    archivedAt: ch.status >= 2 ? (ch.purgeAt ?? "archived") : nil,
                    myState: ChannelDirectoryMyState(
                        lastReadMessageID: nil,
                        lastReadAt: nil,
                        notifyPref: 0,
                        unreadCount: 0,
                        readStateAvailable: true
                    ),
                    lastMessagePreview: nil
                )
            )
        }

        return ChannelDirectoryListing(
            clubID: clubID64,
            categories: categories,
            channels: channels
        )
    }

    public static func projectMessagingConversations(
        _ conversations: [MessagingConversation],
        club: ClubRecord
    ) -> ChannelDirectoryListing {
        let clubID64 = Int64(max(1, club.id))
        let categoryID: Int64 = 1
        let category = ChannelDirectoryCategory(
            id: categoryID,
            clubID: clubID64,
            name: club.name.isEmpty ? "俱乐部频道" : club.name,
            position: 10
        )
        let channels: [ChannelDirectoryEntry] = conversations.enumerated().map { index, conv in
            let channelID = Int64(conv.directoryContext?.channelID ?? conv.id)
            let rawName = conv.counterparty?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let displayName = rawName.isEmpty ? "channel-\(channelID)" : rawName
            return ChannelDirectoryEntry(
                id: channelID,
                clubID: clubID64,
                categoryID: categoryID,
                name: displayName,
                kind: 1,
                visibility: 0,
                position: (index + 1) * 10,
                archivedAt: nil,
                myState: ChannelDirectoryMyState(
                    lastReadMessageID: nil,
                    lastReadAt: conv.lastMessageAt,
                    notifyPref: conv.muted == true ? 2 : 0,
                    unreadCount: max(0, conv.unread ?? 0),
                    readStateAvailable: true
                ),
                lastMessagePreview: nil
            )
        }
        return ChannelDirectoryListing(
            clubID: clubID64,
            categories: channels.isEmpty ? [] : [category],
            channels: channels
        )
    }

    public static func projectBanRecords(from snapshot: ClubGovernanceSnapshot) -> [ChannelModerationBanRecord] {
        guard let rows = snapshot.value.array else { return [] }
        return rows.compactMap { row -> ChannelModerationBanRecord? in
            guard let id = row["id"].int ?? row["banId"].int, id > 0,
                  let memberID = row["memberId"].int ?? row["targetMemberId"].int, memberID > 0 else {
                return nil
            }
            let nickname = row["nickname"].string ?? "用户#\(memberID)"
            let source = row["source"].string ?? (row["platformOnly"].bool == true ? "PLATFORM" : "CLUB")
            let status = row["status"].string ?? "ACTIVE"
            let reasonCode = row["reasonCode"].string ?? "VIOLATION"
            let reasonText = row["reason"].string ?? row["reasonText"].string ?? ""
            return ChannelModerationBanRecord(
                id: id,
                targetMemberID: memberID,
                nickname: nickname,
                source: source,
                status: status,
                reasonCode: reasonCode,
                reasonText: reasonText
            )
        }
    }
}

// MARK: - Stateful Club Channel Moderation Coordinator (Success / Failure / Retry + Rules Gate)

public enum ChannelModerationFeedbackBanner: Equatable, Sendable {
    case success(message: String)
    case error(message: String, canRetry: Bool)

    public var message: String {
        switch self {
        case .success(let message), .error(let message, _):
            return message
        }
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    public var canRetry: Bool {
        if case .error(_, let canRetry) = self { return canRetry }
        return false
    }
}

public struct ChannelModerationRetryableAction: Equatable, Sendable {
    public let endpoint: ChannelSafetyModerationEndpoint
    public let activeChannelID: Int
    public let targetNickname: String?
    public let channelName: String?

    public init(
        endpoint: ChannelSafetyModerationEndpoint,
        activeChannelID: Int,
        targetNickname: String? = nil,
        channelName: String? = nil
    ) {
        self.endpoint = endpoint
        self.activeChannelID = activeChannelID
        self.targetNickname = targetNickname
        self.channelName = channelName
    }
}

@MainActor
public final class ClubChannelModerationCoordinator: ObservableObject {
    public let clubID: Int
    public let viewerMemberID: Int
    public let viewerRoleTier: ChannelMemberRoleTier
    public let capabilities: ChannelModerationCapabilities
    public let isChannelAccessRevoked: Bool
    public let rulesVersion: Int
    public let rulesStore: any ChannelRulesAcceptanceStoring
    public let blockedUsersStore: any ChannelBlockedUsersStoring
    public let service: (any ClubChannelSafetyServing)?

    @Published public private(set) var hasAcceptedRules: Bool
    @Published public private(set) var blockedSenderIDs: Set<Int>
    @Published public private(set) var mutedChannelIDs: Set<Int64>
    @Published public private(set) var deletedMessageIDs: Set<Int> = []
    @Published public private(set) var removedMemberIDs: Set<Int> = []
    @Published public private(set) var activeBans: [ChannelModerationBanRecord]
    @Published public private(set) var isSubmitting: Bool = false
    @Published public private(set) var feedbackBanner: ChannelModerationFeedbackBanner? = nil
    @Published public private(set) var lastFailedAction: ChannelModerationRetryableAction? = nil

    public init(
        clubID: Int,
        viewerMemberID: Int,
        viewerRoleTier: ChannelMemberRoleTier,
        capabilities: ChannelModerationCapabilities = ChannelModerationCapabilities(),
        isChannelAccessRevoked: Bool = false,
        rulesVersion: Int = 1,
        rulesStore: any ChannelRulesAcceptanceStoring = UserDefaultsChannelRulesAcceptanceStore(),
        blockedUsersStore: any ChannelBlockedUsersStoring = UserDefaultsChannelBlockedUsersStore(),
        service: (any ClubChannelSafetyServing)? = nil,
        initialMutedChannelIDs: Set<Int64> = [],
        initialActiveBans: [ChannelModerationBanRecord] = []
    ) {
        let normalizedRulesVersion = max(1, rulesVersion)
        self.clubID = clubID
        self.viewerMemberID = viewerMemberID
        self.viewerRoleTier = viewerRoleTier
        self.capabilities = capabilities
        self.isChannelAccessRevoked = isChannelAccessRevoked
        self.rulesVersion = normalizedRulesVersion
        self.rulesStore = rulesStore
        self.blockedUsersStore = blockedUsersStore
        self.service = service
        self.hasAcceptedRules = rulesStore.hasAcceptedRules(
            clubID: clubID,
            viewerMemberID: viewerMemberID,
            rulesVersion: normalizedRulesVersion
        )
        self.blockedSenderIDs = blockedUsersStore.blockedUserIDs(
            clubID: clubID,
            viewerMemberID: viewerMemberID
        )
        self.mutedChannelIDs = initialMutedChannelIDs
        self.activeBans = initialActiveBans
    }

    public var policy: ChannelSafetyModerationPolicy {
        ChannelSafetyModerationPolicy(
            clubID: clubID,
            viewerMemberID: viewerMemberID,
            viewerRoleTier: viewerRoleTier,
            capabilities: capabilities,
            hasAcceptedChannelRules: hasAcceptedRules,
            isChannelAccessRevoked: isChannelAccessRevoked
        )
    }

    public func acceptChannelRules(locale: Locale = ChannelCopy.defaultLocale) {
        guard clubID > 0, viewerMemberID > 0 else { return }
        rulesStore.recordAcceptedRules(
            clubID: clubID,
            viewerMemberID: viewerMemberID,
            rulesVersion: rulesVersion
        )
        hasAcceptedRules = rulesStore.hasAcceptedRules(
            clubID: clubID,
            viewerMemberID: viewerMemberID,
            rulesVersion: rulesVersion
        )
        feedbackBanner = .success(
            message: ChannelCopy.text(
                "已同意俱乐部频道公约与安全守则，现在可以发言与参与互动。",
                "Channel rules and safety guidelines accepted. You may now post and participate.",
                locale: locale
            )
        )
    }

    public func clearBanner() {
        feedbackBanner = nil
    }

    public func updateActiveBans(_ bans: [ChannelModerationBanRecord]) {
        activeBans = bans
    }

    @discardableResult
    public func reportMessage(
        message: MessagingMessage,
        reason: String,
        activeChannelID: Int,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateReportMessage(message: message, reason: reason) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(endpoint: endpoint, activeChannelID: activeChannelID),
                locale: locale
            )
        }
    }

    @discardableResult
    public func reportUser(
        targetMemberID: Int,
        nickname: String,
        reasonCode: String,
        detail: String,
        activeChannelID: Int,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateReportUser(targetMemberID: targetMemberID, reasonCode: reasonCode, detail: detail) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(
                    endpoint: endpoint,
                    activeChannelID: activeChannelID,
                    targetNickname: nickname
                ),
                locale: locale
            )
        }
    }

    @discardableResult
    public func reportChannel(
        channelID: Int,
        channelName: String,
        reasonCode: String,
        detail: String,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateReportChannel(channelID: channelID, reasonCode: reasonCode, detail: detail) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(
                    endpoint: endpoint,
                    activeChannelID: channelID,
                    channelName: channelName
                ),
                locale: locale
            )
        }
    }

    @discardableResult
    public func blockUser(
        targetMemberID: Int,
        nickname: String,
        shouldBlock: Bool,
        activeChannelID: Int,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateBlockUser(targetMemberID: targetMemberID, shouldBlock: shouldBlock) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(
                    endpoint: endpoint,
                    activeChannelID: activeChannelID,
                    targetNickname: nickname
                ),
                locale: locale
            )
        }
    }

    @discardableResult
    public func muteChannel(
        conversationID: Int,
        muted: Bool,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateMuteChannel(conversationID: conversationID, muted: muted) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(endpoint: endpoint, activeChannelID: conversationID),
                locale: locale
            )
        }
    }

    @discardableResult
    public func deleteMessage(
        channelID: Int,
        message: MessagingMessage,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateDeleteMessage(channelID: channelID, message: message) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(endpoint: endpoint, activeChannelID: channelID),
                locale: locale
            )
        }
    }

    @discardableResult
    public func removeMember(
        target: ChannelMemberRoleItem,
        activeChannelID: Int,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateRemoveMember(target: target) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(
                    endpoint: endpoint,
                    activeChannelID: activeChannelID,
                    targetNickname: target.nickname
                ),
                locale: locale
            )
        }
    }

    @discardableResult
    public func banMember(
        target: ChannelMemberRoleItem,
        reasonCode: String,
        reasonText: String,
        activeChannelID: Int,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateBanMember(target: target, reasonCode: reasonCode, reasonText: reasonText) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(
                    endpoint: endpoint,
                    activeChannelID: activeChannelID,
                    targetNickname: target.nickname
                ),
                locale: locale
            )
        }
    }

    @discardableResult
    public func unbanMember(
        banRow: ChannelModerationBanRecord,
        reason: String,
        activeChannelID: Int,
        locale: Locale = ChannelCopy.defaultLocale
    ) async -> Bool {
        switch policy.validateUnbanMember(banRow: banRow, reason: reason) {
        case .failure(let denial):
            recordValidationFailure(denial, locale: locale)
            return false
        case .success(let endpoint):
            return await executeModeration(
                ChannelModerationRetryableAction(
                    endpoint: endpoint,
                    activeChannelID: activeChannelID,
                    targetNickname: banRow.nickname
                ),
                locale: locale
            )
        }
    }

    @discardableResult
    public func retryLastFailedAction(locale: Locale = ChannelCopy.defaultLocale) async -> Bool {
        guard let action = lastFailedAction else { return false }
        return await executeModeration(action, locale: locale)
    }

    private func executeModeration(
        _ action: ChannelModerationRetryableAction,
        locale: Locale
    ) async -> Bool {
        guard let service else {
            lastFailedAction = action
            let err = ChannelSafetyServiceError.serviceUnavailable(endpoint: action.endpoint)
            feedbackBanner = .error(message: err.localizedDescription(locale: locale), canRetry: true)
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await service.performModeration(action.endpoint, activeChannelID: action.activeChannelID)
            lastFailedAction = nil
            applyConfirmedMutation(action)
            feedbackBanner = .success(message: successMessage(for: action, locale: locale))
            return true
        } catch let error as ChannelSafetyServiceError {
            if case .unsupported = error {
                lastFailedAction = nil
                feedbackBanner = .error(message: error.localizedDescription(locale: locale), canRetry: false)
                return false
            }
            lastFailedAction = action
            feedbackBanner = .error(message: error.localizedDescription(locale: locale), canRetry: true)
            return false
        } catch {
            lastFailedAction = action
            let fallback = ChannelCopy.text(
                "操作未完成（\(action.endpoint.apiPath)），请点击重试。",
                "Action failed (\(action.endpoint.apiPath)). Tap Retry to try again.",
                locale: locale
            )
            feedbackBanner = .error(message: fallback, canRetry: true)
            return false
        }
    }

    private func applyConfirmedMutation(_ action: ChannelModerationRetryableAction) {
        switch action.endpoint {
        case .blockUser(let targetMemberID):
            blockedUsersStore.addBlockedUser(
                targetMemberID: targetMemberID,
                clubID: clubID,
                viewerMemberID: viewerMemberID
            )
            blockedSenderIDs = blockedUsersStore.blockedUserIDs(
                clubID: clubID,
                viewerMemberID: viewerMemberID
            )
        case .unblockUser(let targetMemberID):
            blockedUsersStore.removeBlockedUser(
                targetMemberID: targetMemberID,
                clubID: clubID,
                viewerMemberID: viewerMemberID
            )
            blockedSenderIDs = blockedUsersStore.blockedUserIDs(
                clubID: clubID,
                viewerMemberID: viewerMemberID
            )
        case .muteChannel(let conversationID, let muted):
            let channelKey = Int64(conversationID)
            if muted {
                mutedChannelIDs.insert(channelKey)
            } else {
                mutedChannelIDs.remove(channelKey)
            }
        case .deleteMessage(_, _, let messageID):
            deletedMessageIDs.insert(messageID)
        case .removeMember(_, let targetMemberID):
            removedMemberIDs.insert(targetMemberID)
        case .banMember(_, let targetMemberID, let reasonCode, let reasonText):
            removedMemberIDs.insert(targetMemberID)
            let nextBanID = (activeBans.map(\.id).max() ?? 1000) + 1
            let nickname = action.targetNickname ?? "用户#\(targetMemberID)"
            activeBans.removeAll { $0.targetMemberID == targetMemberID }
            activeBans.append(
                ChannelModerationBanRecord(
                    id: nextBanID,
                    targetMemberID: targetMemberID,
                    nickname: nickname,
                    source: "CLUB",
                    status: "ACTIVE",
                    reasonCode: reasonCode,
                    reasonText: reasonText
                )
            )
        case .unbanMember(_, let banID, _):
            activeBans.removeAll { $0.id == banID }
        case .reportMessage, .reportClubUser, .reportChannel:
            break
        }
    }

    private func successMessage(for action: ChannelModerationRetryableAction, locale: Locale) -> String {
        let name = action.targetNickname ?? ""
        switch action.endpoint {
        case .reportMessage:
            return ChannelCopy.text(
                "举报已提交，安全团队将在 24 小时内审核处理。",
                "Report submitted. Our safety team will review it within 24 hours.",
                locale: locale
            )
        case .reportClubUser:
            return ChannelCopy.text(
                "已提交对「\(name)」的举报，安全与治理团队将在 24 小时内处理。",
                "Report for \(name) submitted. Our safety team will review it within 24 hours.",
                locale: locale
            )
        case .reportChannel(_, let channelID, _, _):
            let label = action.channelName ?? "#\(channelID)"
            return ChannelCopy.text(
                "已提交对频道「\(label)」的举报，安全团队将在 24 小时内审核处理。",
                "Report for channel \(label) submitted. Our safety team will review it within 24 hours.",
                locale: locale
            )
        case .blockUser:
            return ChannelCopy.text(
                "已屏蔽「\(name)」，该用户的消息已从当前会话立即隐藏。",
                "Blocked \(name). Messages from this user are immediately hidden.",
                locale: locale
            )
        case .unblockUser:
            return ChannelCopy.text(
                "已取消屏蔽「\(name)」。",
                "Unblocked \(name).",
                locale: locale
            )
        case .muteChannel(_, let muted):
            return muted
                ? ChannelCopy.text("已开启该频道免打扰。", "Channel notifications muted.", locale: locale)
                : ChannelCopy.text("已恢复该频道消息提醒。", "Channel notifications unmuted.", locale: locale)
        case .deleteMessage(_, _, let messageID):
            return ChannelCopy.text(
                "消息 #\(messageID) 已撤回并移除。",
                "Message #\(messageID) has been deleted.",
                locale: locale
            )
        case .removeMember:
            return ChannelCopy.text(
                "已将「\(name)」移出俱乐部。",
                "Removed \(name) from the club.",
                locale: locale
            )
        case .banMember:
            return ChannelCopy.text(
                "已封禁成员「\(name)」并撤回其频道访问权限。",
                "Banned \(name) and revoked channel access.",
                locale: locale
            )
        case .unbanMember:
            return ChannelCopy.text(
                "已解除对「\(name)」的俱乐部封禁。",
                "Unbanned \(name).",
                locale: locale
            )
        }
    }

    private func recordValidationFailure(_ reason: ChannelModerationDenialReason, locale: Locale) {
        lastFailedAction = nil
        feedbackBanner = .error(message: Self.denialMessage(for: reason, locale: locale), canRetry: false)
    }

    public static func denialMessage(for reason: ChannelModerationDenialReason, locale: Locale) -> String {
        switch reason {
        case .unauthenticated:
            return ChannelCopy.text("请先登录后再操作。", "Please sign in first.", locale: locale)
        case .channelAdmissionRequired:
            return ChannelCopy.text("请先阅读并同意俱乐部频道公约与用户协议（EULA）后再执行此操作。", "Please review and accept the channel rules & EULA before performing this action.", locale: locale)
        case .channelRevokedOrBanned:
            return ChannelCopy.text("当前账号在该俱乐部已被限制发言或移除权限。", "Your channel access has been revoked or restricted in this club.", locale: locale)
        case .cannotTargetSelf:
            return ChannelCopy.text("不能对自己执行该操作。", "You cannot target yourself with this action.", locale: locale)
        case .cannotTargetClubOwner:
            return ChannelCopy.text("不能对俱乐部主理人执行移除或封禁。", "The club owner cannot be removed or banned.", locale: locale)
        case .targetHoldsActiveRoleAssignment:
            return ChannelCopy.text("该成员仍持有生效中的管理职务，请先撤销职务后再移除。", "This member holds an active role assignment. Revoke the role before removing them.", locale: locale)
        case .insufficientModerationPermission:
            return ChannelCopy.text("当前账号缺少执行该管理操作的权限。", "You do not have permission to perform this moderation action.", locale: locale)
        case .platformBanCannotBeUnbannedByClubAdmin:
            return ChannelCopy.text("平台级封禁不可由俱乐部管理员解除。", "Platform-level bans cannot be lifted by club administrators.", locale: locale)
        case .invalidMessageOrReason:
            return ChannelCopy.text("操作目标或原因无效，请补充后重试。", "Invalid target or empty reason.", locale: locale)
        }
    }
}

// MARK: - Clubs Tab & Club Admin Parity Summary (Deliverables 1 & 4)

public struct ClubAdminSurfaceContractStatus: Equatable, Sendable, Identifiable {
    public var id: String { surfaceKey }
    public let surfaceKey: String
    public let miniProgramRoute: String
    public let title: String
    /// Routes verified to exist on the backend (AN-1 route table, MATCH only).
    public let backendEndpoints: [String]
    /// Mini-program names the backend has no route for. Documentation only; nothing may dispatch these
    /// (FP-E6). The surface stays gated until the backend ships a route.
    public let nativeOnlyEndpoints: [String]
    public let isReadOnlyFallback: Bool
    public let flaggedOffFeatureNote: String?

    public init(
        surfaceKey: String,
        miniProgramRoute: String,
        title: String,
        backendEndpoints: [String],
        nativeOnlyEndpoints: [String] = [],
        isReadOnlyFallback: Bool = false,
        flaggedOffFeatureNote: String? = nil
    ) {
        self.surfaceKey = surfaceKey
        self.miniProgramRoute = miniProgramRoute
        self.title = title
        self.backendEndpoints = backendEndpoints
        self.nativeOnlyEndpoints = nativeOnlyEndpoints
        self.isReadOnlyFallback = isReadOnlyFallback
        self.flaggedOffFeatureNote = flaggedOffFeatureNote
    }
}

public enum ClubTabAndAdminParityCatalog {
    /// Deliverable 1: Clubs tab (`pages/talent/list` + `pages/club/*`) parity surfaces.
    public static let clubsTabSurfaces: [ClubAdminSurfaceContractStatus] = [
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.list",
            miniProgramRoute: "pages/talent/list/index",
            title: "俱乐部发现与列表",
            backendEndpoints: ["api/club/list", "api/club/my"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.detail",
            miniProgramRoute: "pages/club/detail/index",
            title: "俱乐部主页与内嵌频道",
            backendEndpoints: ["api/club/detail"],
            nativeOnlyEndpoints: ["api/club/channels"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.apply_join",
            miniProgramRoute: "pages/club/apply/index",
            title: "加入/申请加入俱乐部",
            backendEndpoints: ["api/club/join", "api/club/quit"],
            nativeOnlyEndpoints: ["api/club/join-requests/apply"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.enroll",
            miniProgramRoute: "pages/club/enroll/index",
            title: "俱乐部活动报名与候补",
            backendEndpoints: [],
            nativeOnlyEndpoints: ["api/club/activity/join", "api/club/activity/cancel", "api/club/activity/detail"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.create_edit",
            miniProgramRoute: "pages/club/create/index",
            title: "创建与编辑俱乐部",
            backendEndpoints: ["api/club/create"],
            nativeOnlyEndpoints: ["api/club/update"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.roles",
            miniProgramRoute: "pages/club/roles/index",
            title: "角色与权限委派",
            backendEndpoints: ["api/club/roles/list", "api/club/roles/assign", "api/club/roles/revoke"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.badges",
            miniProgramRoute: "pages/club/badges/index",
            title: "俱乐部徽章与成长体系",
            backendEndpoints: ["api/club/badge/list", "api/club/badge/create", "api/club/badge/grant"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.notices",
            miniProgramRoute: "pages/club/notify/index",
            title: "俱乐部公告与通知历史",
            backendEndpoints: [],
            nativeOnlyEndpoints: ["api/club/notices", "api/club/notices/send"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.group_code",
            miniProgramRoute: "pages/club/group-code/index",
            title: "俱乐部入群码配置",
            backendEndpoints: [],
            nativeOnlyEndpoints: ["api/club/group-code", "api/club/group-code/save"]
        )
    ]

    /// Deliverable 4: Club Admin (`workbench`, `customers`, `event-ops`, `join-requests`, `settlement` read-only with bank withdrawal flagged off).
    public static let clubAdminSurfaces: [ClubAdminSurfaceContractStatus] = [
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.workbench",
            miniProgramRoute: "pages/club/workbench/index",
            title: "主理人工作台（统一收敛至俱乐部管理 Tab）",
            backendEndpoints: ["api/club/detail"],
            nativeOnlyEndpoints: ["api/club/workbench"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.customers",
            miniProgramRoute: "pages/club/customers/index",
            title: "客户资产与精细化CRM画像（只读视图）",
            backendEndpoints: ["api/club/crm/customers/list", "api/club/crm/customers/count"],
            isReadOnlyFallback: true
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.event_ops",
            miniProgramRoute: "pages/club/event-ops/index",
            title: "赛事/活动排期、核销与代报",
            backendEndpoints: [],
            nativeOnlyEndpoints: [
                "api/club/events",
                "api/club/events/save",
                "api/club/events/Checkin",
                "api/club/events/proxy-enroll"
            ]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.join_requests",
            miniProgramRoute: "pages/club/join-requests/index",
            title: "入会申请审批队列",
            backendEndpoints: ["api/club/join-requests", "api/club/join-request/approve", "api/club/join-request/reject"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.settlement",
            miniProgramRoute: "pages/club/settlement/index",
            title: "俱乐部收支与结算流水（只读对账）",
            backendEndpoints: [],
            nativeOnlyEndpoints: ["api/club/settlements", "api/club/settlements/export"],
            isReadOnlyFallback: true,
            flaggedOffFeatureNote: "pages/coop/withdraw 银行卡提现已按规范 Flagged Off，仅保留俱乐部结算单与订单分成只读核对。"
        )
    ]
}


// MARK: - Bilingual copy

/// Locale-aware zh-Hans / en copy for strings produced in Core. The default locale stays
/// Simplified Chinese so existing fixtures keep their original-service wording; views pass
/// their environment locale.
public enum ChannelCopy {
    public static let defaultLocale = Locale(identifier: "zh-Hans")
    public static func isChinese(_ locale: Locale) -> Bool { AppLanguage.interfaceIsChinese(locale) }
    public static func text(_ zh: String, _ en: String, locale: Locale) -> String { isChinese(locale) ? zh : en }
}
