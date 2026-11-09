import SwiftUI

/// Source im/list cy-tabs label: 私信 / 系统 (+ native-only 群聊) with a count badge.
struct IMInboxTabLabel: View {
    let tab: IMInboxTab
    let badge: Int
    /// A single Text: segmented pickers only render Text/Image segment labels.
    var body: Text {
        guard let text = IMInboxSummary.badgeText(badge) else { return Text(title) }
        return Text(title) + Text(verbatim: " \(text)")
    }
    private var title: LocalizedStringKey {
        switch tab {
        case .direct: return "im.inbox.tab.direct"
        case .system: return "im.inbox.tab.system"
        case .group: return "im.inbox.tab.group"
        }
    }
}

/// Source list time text (`fmtTime`), China-anchored; unparseable stays hidden.
struct IMInboxTimeLabel: View {
    let raw: String?
    var now = Date()
    var body: some View {
        switch IMInboxTime.listText(raw, now: now) {
        case .justNow?: Text("im.time.justNow")
        case .minutesAgo(let minutes)?: Text("im.time.minutesAgo \(minutes)")
        case .clock(let value)?: Text(verbatim: value)
        case .yesterday?: Text("im.time.yesterday")
        case .weekday(let day)?: Text(Self.weekdayKey(day))
        case .monthDay(let month, let day)?: Text("im.time.monthDay \(month) \(day)")
        case nil: EmptyView()
        }
    }
    static func weekdayKey(_ day: Int) -> LocalizedStringKey {
        switch day {
        case 0: return "im.time.weekday.0"
        case 1: return "im.time.weekday.1"
        case 2: return "im.time.weekday.2"
        case 3: return "im.time.weekday.3"
        case 4: return "im.time.weekday.4"
        case 5: return "im.time.weekday.5"
        default: return "im.time.weekday.6"
        }
    }
}

/// Source chat `fmtAbs` divider text.
struct IMChatDividerLabel: View {
    let divider: IMInboxTime.DividerText
    var body: some View {
        switch divider {
        case .today(let clock): Text(verbatim: clock)
        case .yesterday(let clock): Text("im.time.yesterdayAt \(clock)")
        case .date(let month, let day, let clock): Text("im.time.monthDayAt \(month) \(day) \(clock)")
        }
    }
}

/// Source unread badge: `unread > 99 ? '99+' : unread`, muted rows use the quiet style.
struct IMUnreadBadge: View {
    let count: Int?
    var muted = false
    var body: some View {
        if let text = IMInboxSummary.badgeText(count) {
            Text(verbatim: text)
                .font(.caption2.weight(.semibold)).monospacedDigit()
                .padding(.horizontal, 6).padding(.vertical, 2)
                .foregroundStyle(muted ? CYColor.textSecondary : CYColor.textOnAccent)
                .background(Capsule().fill(muted ? CYColor.textSecondary.opacity(0.25) : CYColor.dangerSolid))
                .accessibilityLabel(Text("messaging.unread"))
                .accessibilityValue(Text(verbatim: text))
        }
    }
}

/// Source conversation row: 56pt round avatar (bell for system), bold name,
/// 官方 tag (type 3), mute mark, time top-right, preview line and unread badge
/// bottom-right. Messaging never loads remote avatars, so the avatar is a clean
/// symbol placeholder.
struct IMInboxRow: View {
    let conversation: MessagingConversation
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CYCoverArt(seed: "\(conversation.id)", systemImage: symbol, symbolSize: avatarSize * 0.4)
                .frame(width: typeSize.isAccessibilitySize ? 44 : avatarSize, height: typeSize.isAccessibilitySize ? 44 : avatarSize)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if typeSize.isAccessibilitySize {
                    MessagingConversationName(conversation: conversation)
                        .font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        officialChip; muteMark
                        IMInboxTimeLabel(raw: conversation.lastMessageAt)
                            .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        MessagingConversationName(conversation: conversation)
                            .font(.body.weight(.semibold)).lineLimit(1)
                        officialChip.fixedSize()
                        muteMark
                        Spacer(minLength: 4)
                        IMInboxTimeLabel(raw: conversation.lastMessageAt)
                            .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                            .fixedSize().layoutPriority(1)
                    }
                }
                HStack(alignment: .center, spacing: 6) {
                    MessagingPreview(conversation: conversation).font(.subheadline).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    Spacer(minLength: 4)
                    IMUnreadBadge(count: conversation.unread, muted: conversation.muted == true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var officialChip: some View {
        if conversation.kind == .merchant {
            CYStatusChip("im.inbox.officialTag", tone: .neutral)
                .accessibilityIdentifier("im.inbox.official.\(conversation.id)")
        }
    }
    @ViewBuilder private var muteMark: some View {
        if conversation.muted == true {
            Image(systemName: "bell.slash").font(.caption).foregroundStyle(.secondary)
                .accessibilityLabel(Text("im.inbox.mutedLabel"))
        }
    }
    private var symbol: String {
        switch conversation.kind {
        case .system: return "bell.fill"
        case .group: return "person.3.fill"
        default: return "person.fill"
        }
    }
}

/// Entry-point badge for "消息" rows/icons (source talent/list `imUnread`). The
/// read is optional: unconfigured, signed out or failed reads show no badge.
@MainActor struct IMUnreadEntryBadge: View {
    let reader: (any IMUnreadTotalReading)?
    @State private var total: Int?
    @State private var loadedFor: MessagingReadIdentity?
    var body: some View {
        IMUnreadBadge(count: total)
            .accessibilityIdentifier("im.entry.unreadBadge")
            .task(id: reader?.identity) { await load() }
    }
    private func load() async {
        guard let reader, reader.isConfigured, let identity = reader.identity else { total = nil; loadedFor = nil; return }
        if loadedFor != identity { total = nil }
        do {
            let value = try await reader.unreadTotal()
            guard !Task.isCancelled, reader.identity == identity else { return }
            total = value; loadedFor = identity
        } catch { if reader.identity == identity { total = nil } }
    }
}

/// Deterministic generated cover art for entities that have no photo (club, conversation, group).
/// Same seed => same colours, so a row never flickers between renders. Decorative: hidden from VoiceOver.
struct CYCoverArt: View {
    let seed: String
    var systemImage: String = "person.3.fill"
    var symbolSize: CGFloat = 36

    private var hue: Double {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Double(h % 360) / 360
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.62),
                                    Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: .topTrailing, startRadius: 4, endRadius: 160)
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .accessibilityHidden(true)
    }
}
