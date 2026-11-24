import SwiftUI

/// Where 我的消息 reads from and where its rows go. Supplied by the session composition; nil hides the section's
/// conversation and invite legs (events still show), never invents rows.
struct MerchantInboxSources {
    /// Per-account key for the local read marks (source `merchant_inbox_read_<userID>`).
    let accountKey: String
    let conversations: @MainActor () async throws -> [MessagingConversation]
    /// Nil when the account cannot manage cooperation (source `access.canManageCoop`).
    let receivedInvites: (@MainActor () async throws -> [CooperationInvite])?
    /// 全部 → the in-app inbox (source `subpackageB/pages/im/list`).
    let inboxDestination: @MainActor () -> AnyView
    /// A received invite → invite detail (source `pages/coop/invite-detail?box=received`).
    let inviteDestination: @MainActor (Int) -> AnyView
}

private struct MerchantInboxSourcesKey: EnvironmentKey {
    static let defaultValue: MerchantInboxSources? = nil
}

extension EnvironmentValues {
    var merchantInboxSources: MerchantInboxSources? {
        get { self[MerchantInboxSourcesKey.self] }
        set { self[MerchantInboxSourcesKey.self] = newValue }
    }
}

/// Parity merchant/index P1 (我的消息): source `pages/merchant/index` 我的消息 card. Conversations, received
/// cooperation invites and business events merged newest first, three rows. Swipe or × marks one read, 清空
/// (asks once) marks all read, every item read collapses to 都看完了. Before the first load settles the section
/// keeps one row of height and draws nothing, so it never claims 还没有消息 early.
/// Read marks are local per account, like the source for invites and events. The server read of a conversation
/// (`api/im/read`) stays with the inbox, whose write is gated.
@MainActor
struct MerchantInboxPreviewSection: View {
    let sources: MerchantInboxSources?
    /// Events already loaded by the workbench (nil while loading or when the role cannot read them).
    let events: [MerchantEvent]?
    let eventsSettled: Bool
    let eventsFailed: Bool
    let canManageCoop: Bool
    let reloadToken: UInt64
    let eventDestination: (MerchantInboxItem) -> AnyView?

    private enum Leg { case pending, failed, rows }
    @State private var conversations: [MessagingConversation] = []
    @State private var invites: [CooperationInvite] = []
    @State private var conversationsLeg: Leg = .pending
    @State private var invitesLeg: Leg = .pending
    @State private var readMarks: [String: Double] = [:]
    @State private var confirmsClear = false
    @State private var lastItems: [MerchantInboxItem] = []

    private var storeKey: String { "merchant_inbox_read_" + (sources?.accountKey ?? "") }

    private var settled: Bool {
        let conv = sources == nil || conversationsLeg != .pending
        let inv = sources?.receivedInvites == nil || !canManageCoop || invitesLeg != .pending
        return conv && inv && (events != nil || eventsSettled)
    }
    private var allFailed: Bool {
        let convFailed = sources == nil || conversationsLeg == .failed
        let invFailed = sources?.receivedInvites == nil || !canManageCoop || invitesLeg == .failed
        let evFailed = events == nil
        return convFailed && invFailed && evFailed && (sources != nil || eventsFailed)
    }
    private func items(limit: Int, honoursRead: Bool = true, now: Date = Date()) -> [MerchantInboxItem] {
        MerchantInboxPreview.build(conversations: conversations, invites: canManageCoop ? invites : [],
            events: events ?? [], now: now, limit: limit,
            isRead: { honoursRead && readMarks[$0] != nil })
    }

    var body: some View {
        Section {
            if !settled && lastItems.isEmpty {
                Color.clear.frame(height: CYSpacing.minTouchTarget)
                    .accessibilityHidden(true)
                    .listRowBackground(Color.clear)
            } else {
                let visible = settled ? items(limit: MerchantInboxPreview.previewLimit) : lastItems
                if visible.isEmpty {
                    emptyRow(allRead: settled && !items(limit: 1, honoursRead: false).isEmpty)
                } else {
                    ForEach(visible) { item in row(item) }
                    clearRow(visible)
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("merchant.inbox.title")
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CYSpacing.sm)
                if let sources {
                    NavigationLink { sources.inboxDestination().cyPushedChrome() } label: {
                        HStack(spacing: CYSpacing.xs) {
                            Text("merchant.inbox.all").cyText(.label)
                            Image(systemName: "chevron.right").imageScale(.small)
                        }
                        .foregroundStyle(CYColor.textSecondary)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("merchant.inbox.allA11y"))
                    .accessibilityIdentifier("merchant.inbox.all")
                }
            }
            .textCase(nil)
            // On the single header view: modifiers on a List Section are applied to every row.
            .task(id: "\(storeKey):\(reloadToken)") { await load() }
            .onChange(of: settled) { _, done in if done { lastItems = items(limit: MerchantInboxPreview.previewLimit) } }
            .confirmationDialog(Text("merchant.inbox.clear.confirmTitle"), isPresented: $confirmsClear, titleVisibility: .visible) {
                Button("merchant.inbox.clear.confirm", role: .destructive) {
                    withAnimation(.easeOut(duration: 0.2)) { markRead(items(limit: 50)) }
                }
                Button("action.cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder private func emptyRow(allRead: Bool) -> some View {
        let label: LocalizedStringKey = allRead ? "merchant.inbox.allRead" : (allFailed ? "merchant.inbox.failed" : "merchant.inbox.empty")
        let content = HStack(spacing: CYSpacing.md) {
            Image(systemName: allRead ? "checkmark" : "bell")
                .foregroundStyle(CYColor.textSecondary)
                .frame(width: 28)
            Text(label).cyText(.body).foregroundStyle(CYColor.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
        if let sources {
            NavigationLink { sources.inboxDestination().cyPushedChrome() } label: { content }
                .accessibilityIdentifier("merchant.inbox.empty")
        } else {
            content.accessibilityIdentifier("merchant.inbox.empty")
        }
    }

    @ViewBuilder private func row(_ item: MerchantInboxItem) -> some View {
        let label = rowLabel(item)
        Group {
            if let destination = destination(for: item) {
                NavigationLink { destination } label: { label }
            } else {
                label
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { withAnimation(.easeOut(duration: 0.2)) { markRead([item]) } } label: {
                Label("merchant.inbox.markRead", systemImage: "envelope.open")
            }
            .tint(CYColor.textSecondary)
        }
        .accessibilityAction(named: Text("merchant.inbox.markRead")) { markRead([item]) }
        .accessibilityIdentifier("merchant.inbox.row." + item.id)
    }

    private func rowLabel(_ item: MerchantInboxItem) -> some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: item.systemImage)
                .foregroundStyle(CYColor.textPrimary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                title(item).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                if let sub = subtitle(item) {
                    sub.cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            Group {
                if let raw = item.rawTime {
                    Text(verbatim: raw)
                } else if let date = item.date {
                    IMInboxTimeLabel(raw: String(Int64(date.timeIntervalSince1970 * 1000)))
                }
            }
            .cyText(.meta)
            .monospacedDigit()
            .foregroundStyle(CYColor.textSecondary)
            if item.unread, case .conversation = item.kind {
                Circle().fill(CYColor.dangerText).frame(width: 8, height: 8)
                    .accessibilityLabel(Text("merchant.inbox.unread"))
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func title(_ item: MerchantInboxItem) -> Text {
        switch item.kind {
        case .conversation(_, let type):
            if type == 2 { return Text("merchant.inbox.assistant") }
            return item.title.map { Text(verbatim: $0) } ?? Text("merchant.inbox.conversationFallback")
        case .invite:
            if let partner = item.invitePartner { return Text("merchant.inbox.invite.partner \(partner)") }
            return Text("merchant.inbox.invite")
        case .event:
            return item.title.map { Text(verbatim: $0) } ?? Text("merchant.inbox.eventFallback")
        }
    }

    private func subtitle(_ item: MerchantInboxItem) -> Text? {
        switch item.kind {
        case .conversation:
            if item.subtitle == nil, conversations.first(where: { "conv-\($0.id)" == item.id })?.lastMessageType == 2 {
                return Text("merchant.inbox.image")
            }
            return item.subtitle.map { Text(verbatim: $0) }
        case .invite:
            let status = item.inviteStatus.flatMap(Self.inviteStatusText)
            switch (item.subtitle, status) {
            case let (topic?, status?): return Text(verbatim: topic + " · ") + status
            case let (topic?, nil): return Text(verbatim: topic)
            case let (nil, status?): return status
            default: return nil
            }
        case .event:
            return item.subtitle.map { Text(verbatim: $0) }
        }
    }

    /// Source `coop-invite-status` labels; an unknown code shows nothing.
    private static func inviteStatusText(_ code: Int) -> Text? {
        switch code {
        case 0: return Text("merchant.inbox.inviteStatus.0")
        case 1: return Text("merchant.inbox.inviteStatus.1")
        case 2: return Text("merchant.inbox.inviteStatus.2")
        case 3: return Text("merchant.inbox.inviteStatus.3")
        case 4: return Text("merchant.inbox.inviteStatus.4")
        case 5: return Text("merchant.inbox.inviteStatus.5")
        default: return nil
        }
    }

    private func destination(for item: MerchantInboxItem) -> AnyView? {
        switch item.kind {
        case .conversation:
            // The chat needs the inbox's sender wiring; the row opens the inbox, where the conversation is first.
            return sources.map { AnyView($0.inboxDestination().cyPushedChrome()) }
        case .invite(let id):
            return sources.map { AnyView($0.inviteDestination(id).cyPushedChrome(domain: .merchant)) }
        case .event:
            return eventDestination(item)
        }
    }

    @ViewBuilder private func clearRow(_ visible: [MerchantInboxItem]) -> some View {
        Button { confirmsClear = true } label: {
            Label("merchant.inbox.clear", systemImage: "trash")
                .cyText(.label)
                .foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("merchant.inbox.clear.confirmTitle"))
        .accessibilityIdentifier("merchant.inbox.clear")
    }

    private func load() async {
        readMarks = Self.loadMarks(storeKey)
        guard let sources else { return }
        let c = await loadConversations(sources)
        let i = await loadInvites(sources)
        guard !Task.isCancelled else { return }
        conversationsLeg = c
        invitesLeg = i
        if settled { lastItems = items(limit: MerchantInboxPreview.previewLimit) }
    }
    private func loadConversations(_ sources: MerchantInboxSources) async -> Leg {
        do { conversations = try await sources.conversations(); return .rows } catch { return .failed }
    }
    private func loadInvites(_ sources: MerchantInboxSources) async -> Leg {
        guard canManageCoop, let read = sources.receivedInvites else { return .failed }
        do { invites = try await read(); return .rows } catch { return .failed }
    }

    private func markRead(_ rows: [MerchantInboxItem]) {
        let at = Date().timeIntervalSince1970 * 1000
        for item in rows { readMarks[item.readKey] = at }
        readMarks = MerchantInboxPreview.trimmedReadMarks(readMarks)
        lastItems = items(limit: MerchantInboxPreview.previewLimit)
        Self.saveMarks(readMarks, storeKey)
    }

    private static func loadMarks(_ key: String) -> [String: Double] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Double]) ?? [:]
    }
    private static func saveMarks(_ marks: [String: Double], _ key: String) {
        UserDefaults.standard.set(marks, forKey: key)
    }
}
