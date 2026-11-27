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
/// `unknownAsDash` (conversation rows, IMListPageReady.rowUnreadBadge): an absent unread is a quiet
/// em dash, a real 0 shows no badge. Entry badges keep hiding an unknown total.
struct IMUnreadBadge: View {
    let count: Int?
    var muted = false
    var unknownAsDash = false
    @QuestifyReduceMotion private var reduceMotion
    private var text: String? {
        unknownAsDash ? IMListPageReady.rowUnreadBadge(count) : IMInboxSummary.badgeText(count)
    }
    var body: some View {
        if let text {
            let quiet = muted || text == IMListPageReady.unknownMark
            // Native r2: the count reads like a List `.badge` (system text, no drawn capsule); unread is tinted.
            Text(verbatim: text)
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(quiet ? Color.secondary : Color.accentColor)
                .accessibilityLabel(Text("messaging.unread"))
                .accessibilityValue(text == IMListPageReady.unknownMark ? Text("im.list.unread.unknown") : Text(verbatim: text))
                // C5 social: drive the numericText roll when the count changes (instant under Reduce Motion).
                .animation(reduceMotion ? nil : .snappy, value: text)
        }
    }
}

/// Source conversation row: 56pt round avatar (bell for system), bold name,
/// 官方 tag (type 3), mute mark, time top-right, preview line and unread badge
/// bottom-right. R7-PC-D8-2 (MP im/list/index.wxml:141): a person's https avatar is shown; the system row and a
/// missing or failed avatar keep the generated symbol art.
struct IMInboxRow: View {
    let conversation: MessagingConversation
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .center) {
            IMRemoteAvatar(url: conversation.kind == .system ? nil : IMRemoteAvatar<EmptyView>.url(conversation.counterparty?.avatar)) {
                // MP im/list/index.wxml:138-141: the system row keeps its glyph; a person falls back to `/images/d_profile.png`.
                if conversation.kind == .system || conversation.kind == .group {
                    CYIMCoverArt(seed: "\(conversation.id)", systemImage: symbol, symbolSize: avatarSize * 0.4)
                } else {
                    MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                }
            }
                .frame(width: typeSize.isAccessibilitySize ? 44 : avatarSize, height: typeSize.isAccessibilitySize ? 44 : avatarSize)
                .clipShape(Circle())
                .overlay(alignment: .topTrailing) {
                    // Unread dot on the avatar; the count badge stays on the preview line.
                    if (conversation.unread ?? 0) > 0 && conversation.muted != true {
                        Circle().fill(Color.accentColor).frame(width: 12, height: 12).offset(x: 2, y: -2)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                if typeSize >= .xxLarge {
                    MessagingConversationName(conversation: conversation)
                        .font(.headline)
                    HStack {
                        officialChip; muteMark
                        IMInboxTimeLabel(raw: conversation.lastMessageAt)
                            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        MessagingConversationName(conversation: conversation)
                            .font(.headline)
                        officialChip.fixedSize()
                        muteMark
                        Spacer(minLength: 4)
                        IMInboxTimeLabel(raw: conversation.lastMessageAt)
                            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                            .fixedSize().layoutPriority(1)
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    MessagingPreview(conversation: conversation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    IMUnreadBadge(count: conversation.unread, muted: conversation.muted == true, unknownAsDash: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var officialChip: some View {
        if conversation.kind == .merchant {
            Text("im.inbox.officialTag")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            QuestWidgetBoardPublisher.unread(value)
            // Native r2 M4: the same read going up while the app is open pops a message island (no extra request).
            IslandUnreadBridge.observe(source: "imTotal", total: value, title: { .localized("island.message.new \($0)") }) {
                MPNotificationTapRouter.shared.open(pagePath: IslandRoutes.messageCenter)
            }
        } catch { if reader.identity == identity { total = nil } }
    }
}

/// Neutral plate for a conversation that has no photo. Seed stays on the row so identity does not flicker.
/// Decorative: hidden from VoiceOver.
struct CYIMCoverArt: View {
    let seed: String
    var systemImage: String = "person.3.fill"
    var symbolSize: CGFloat = 36

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemFill)
            if symbolSize > 0 {
                Image(systemName: systemImage)
                    .font(symbolSize >= 28 ? Font.title : Font.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("im.cover.\(seed)")
        .accessibilityHidden(true)
    }
}


// MARK: - Chat continuity (composer to bubble)

/// Carries a just-sent text from the composer field into its transcript bubble (continuity r1, item 9). Presentation
/// only: it never decides what was sent or accepted. The history page read stays the only source of bubbles; the
/// ghost is the field's own text, drawn where it was typed until the acknowledged message lands.
@MainActor final class IMSendFlight: ObservableObject {
    /// The text the user just sent, kept in the field while the send is in flight.
    @Published private(set) var ghost: String?
    /// The server message the ghost lands on, once the send is acknowledged.
    @Published private(set) var landingID: Int?
    /// The history's namespace; nil under Reduce Motion, so the ghost and the bubble only cross-fade.
    var namespace: Namespace.ID?

    func launch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        landingID = nil
        ghost = trimmed.isEmpty ? nil : trimmed
    }
    /// Only a ghost that is still in the field can land; a retry or a second tap has none.
    func land(on messageID: Int) { if ghost != nil { landingID = messageID } }
    /// Call inside the transaction that inserts the bubble, so the ghost leaving and the bubble arriving are matched.
    func settle() { ghost = nil }
    func cancel() { ghost = nil; landingID = nil }
    /// Matched-geometry key of the ghost: the landing message id, or a key no bubble uses (ids are positive).
    var ghostKey: Int { landingID ?? -1 }
}

extension View {
    /// Shares one position (never the size) between the composer ghost and the transcript bubble with the same id,
    /// pinned at the trailing bottom corner where Send sits. Without a namespace it does nothing.
    func imSendFlight(_ id: Int, in namespace: Namespace.ID?) -> some View {
        modifier(IMSendFlightMatch(id: id, namespace: namespace))
    }
    /// Transcript row insert/remove. A new incoming (or refreshed) row settles in place with the list insert
    /// (scale from 0.96 and fade); the landing bubble is the moving element itself, so it stays opaque and lets the
    /// matched position carry it. Reduce Motion: fade only.
    func imChatRowTransition(landing: Bool) -> some View { modifier(IMChatRowTransition(landing: landing)) }
}

private struct IMSendFlightMatch: ViewModifier {
    let id: Int
    let namespace: Namespace.ID?
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace, properties: .position, anchor: .bottomTrailing)
        } else {
            content
        }
    }
}

private struct IMChatRowTransition: ViewModifier {
    let landing: Bool
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        let transition: AnyTransition = reduceMotion ? .opacity
            : landing ? .identity
            : .asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity)
        return content.transition(transition)
    }
}

/// The sent text in the field's own type and inset while it is on its way to the bubble. It leaves with a quick fade
/// (about the first third of the move) while the bubble takes over its position.
struct IMSendGhost: View {
    let text: String
    let key: Int
    let namespace: Namespace.ID?
    /// The field's own ground, so the field's placeholder never shows through the ghost (integ: the two texts
    /// overlapped while sending). Applied after the matched position, so it stays in the field while the text flies.
    var fill: Color = .clear
    var body: some View {
        Text(verbatim: text)
            .lineLimit(1...5)
            .foregroundStyle(.secondary)
            .padding(.vertical, 11).padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .imSendFlight(key, in: namespace)
            .background(fill, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(leaving)
    }
    private var leaving: AnyTransition {
        .asymmetric(insertion: .identity, removal: AnyTransition.opacity.animation(.easeOut(duration: CYMotion.Duration.instant)))
    }
}

/// R7-PC-D8-2 / D9-4: an IM avatar from the server (`counterparty.avatar`, `senderAvatar`), https only; the
/// generated art stays as placeholder and failure fallback (MP falls back to its default profile image).
struct IMRemoteAvatar<Fallback: View>: View {
    let url: URL?
    @ViewBuilder let fallback: () -> Fallback
    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else { return nil }
        return url
    }
    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() } else { fallback() }
            }
        } else {
            fallback()
        }
    }
}
