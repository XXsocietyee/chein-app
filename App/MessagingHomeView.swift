import SwiftUI

/// Insert in an existing NavigationStack; root must key the account subtree by session
/// revision. This initializer's identity scopes local navigation/search to one login epoch.
@MainActor
struct MessagingHomeView: View {
    let reader: any MessagingReading
    var mediaReader: (any SocialMessageMediaReading)? = nil
    var senderForConversation: ((Int)->MessageActionCoordinator?)? = nil
    var expanded: IMExpandedNavigationContext? = nil
    var squareDestination: ((@escaping () -> Void) -> AnyView)? = nil
    var predictionEntry: (() -> AnyView)? = nil
    /// R7-PC-D8-3 (MP im/list/index.wxml:1,30-33): the merchant account reads its inbox in merchant chrome.
    var merchantChrome = false
    private let identity: MessagingReadIdentity?
    @Environment(\.imCoopInviteStrip) private var coopInviteStrip
    init(reader:any MessagingReading,mediaReader:(any SocialMessageMediaReading)?=nil,senderForConversation:((Int)->MessageActionCoordinator?)?=nil,expanded:IMExpandedNavigationContext?=nil,squareDestination:((@escaping () -> Void) -> AnyView)?=nil,predictionEntry:(() -> AnyView)?=nil,merchantChrome:Bool=false) { self.reader=reader;self.mediaReader=mediaReader;self.senderForConversation=senderForConversation;self.expanded=expanded;self.squareDestination=squareDestination;self.predictionEntry=predictionEntry;self.merchantChrome=merchantChrome;identity=reader.identity }
    /// R7-PC-D8-1 MP-first (subpackageB/pages/im/list/index.js:268-281, index.wxml:11): one tab row, 收件箱 / 发件箱.
    /// 收件箱 = received invites + every conversation; 发件箱 = only the invites I sent (no conversations).
    @State private var box: MessagingBox = .inbox
    var body: some View {
        VStack(spacing: 0) {
            Picker("messaging.scope", selection: $box) {
                Text("im.list.box.inbox").tag(MessagingBox.inbox)
                Text("im.list.box.outbox").tag(MessagingBox.outbox)
            }
            .cyAdaptiveSegmented()
            .labelsHidden()
            .accessibilityLabel(Text("messaging.scope"))
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityIdentifier("messaging.list.scope")
            .sensoryFeedback(.selection, trigger: box)
            if let predictionEntry { predictionEntry().padding(.horizontal) }
            switch box {
            case .inbox:
                if let coopInviteStrip { coopInviteStrip().environment(\.imCoopInviteDirection, .received).padding(.horizontal) }
                MessagingConversationListView(reader:reader,mediaReader:mediaReader,senderForConversation:senderForConversation,expanded:expanded,squareDestination:squareDestination).id(identity)
            case .outbox:
                // R10-PC-D-N16: outbox is a system List (MP subpackageB/pages/im/list/index.wxml:78-91, 103-108).
                List {
                    if let coopInviteStrip {
                        coopInviteStrip().environment(\.imCoopInviteDirection, .sent)
                    } else {
                        ContentUnavailableView("im.list.box.outboxEmpty", systemImage: "tray")
                            .accessibilityIdentifier("messaging.list.outboxEmpty")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .onChange(of: identity) { _, _ in box = .inbox }
        .cyPageTitle("messaging.title") // PC-D-8-2
        .themeDomain(merchantChrome ? .merchant : .player)
        .cyHideTabBar()
    }
}

@MainActor
private struct MessagingConversationListView: View {
    let reader: any MessagingReading
    var mediaReader: (any SocialMessageMediaReading)? = nil
    var senderForConversation: ((Int)->MessageActionCoordinator?)? = nil
    var expanded: IMExpandedNavigationContext? = nil
    var squareDestination: ((@escaping () -> Void) -> AnyView)? = nil
    @State private var showsSquare = false
    @State private var newConversation: Int?
    @State private var rowAction: IMConversationRowActionPresentation?
    @State private var readAll: IMConversationReadAllPresentation?
    @StateObject private var listModel = MessagingReadScreenModel<[MessagingConversation]>()
    @Environment(\.locale) private var locale
    @State private var query = ""
    /// nil until the reader picks a segment; the list opens on All.
    @State private var selectedTab: MessagingSegment?
    @State private var safety: IMSafetyPresentation?
    @State private var displayLimit = 30
    var body: some View {
        MessagingReadScreen(reader: reader, accessibilityPrefix: "messaging.list", failureTitleKey: "messaging.list.loadFailed", model: listModel, load: {
            try await reader.messagingConversations()
        }) { conversations in
            let summary = IMInboxSummary(conversations: conversations)
            let tab = currentTab
            List {
                // R7-PC-D8-1: the 全部/频道/私信 picker is gone; the MP 收件箱 lists every conversation (`MessagingHomeView.box`).
                let rows = filtered(conversations, tab: tab)
                if tab.rows(conversations).isEmpty {
                    emptyState(tab: tab, conversations: conversations)
                } else if rows.isEmpty {
                    emptyState(title: "messaging.noMatches", identifier: "messaging.list.noMatches")
                } else {
                    let visible = Array(rows.prefix(displayLimit))
                    if tab == .channels {
                        // Channels grouped by the space the server names in bizKey.
                        ForEach(channelSections(visible), id: \.id) { section in
                            Section {
                                ForEach(section.rows) { conversation in conversationRow(conversation) }
                            } header: {
                                if let title = section.title { Text(title).accessibilityAddTraits(.isHeader) }
                            }
                        }
                    } else {
                        // Day groups (today / yesterday / earlier), newest first as the server orders them.
                        ForEach(daySections(visible), id: \.id) { section in
                            Section {
                                ForEach(section.rows) { conversation in conversationRow(conversation) }
                            } header: {
                                Text(verbatim: section.title)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                    if displayLimit < rows.count {
                        Section {
                            Button("messaging.moreConversations") { displayLimit += 30 }
                                .buttonStyle(.borderless)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("messaging.list.more")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                // Leading on the tab root (no Back button here) so the trailing side keeps two actions.
                ToolbarItem(placement: .topBarLeading) {
                    if expanded != nil {
                        Button("im.readAll.title", systemImage: "envelope.open") {
                            presentReadAll(conversations)
                        }
                        .disabled(rowAction != nil || readAll != nil || !summary.hasUnread || !canPresentReadAll(conversations))
                        .accessibilityIdentifier("im.readAll.entryButton")
                    }
                }
            }
        }
        // Function audit P2-6 (MP-first): MP `subpackageB/pages/im/list` has no new-chat entry; a chat starts from a
        // profile's 发消息 (`cy/profile` → `/api/im/start`) or a roam row, never by typing a raw member ID. The
        // `IMStartConversationView` entry is gone from the inbox; `IMConversationStarter` stays for those callers.
        .navigationDestination(item: $newConversation) { id in
            MessagingHistoryView(conversationID: id, reader: reader, sender: senderForConversation?(id), mediaReader: mediaReader, expanded: expanded,
                onConversationMutationAccepted: conversationInvalidation(for: id))
        }
        // mp-nav r3: MP im/list onEmptyCta leaves the inbox for a feed page (switchTab, not a popup): push it with system back.
        .navigationDestination(isPresented: $showsSquare) {
            if let squareDestination { squareDestination { showsSquare = false } }
        }
        .cySheet(item: $rowAction) { presentation in
            let owner = listModel
            IMConversationRowActionsView(actions: presentation.actions) { [weak owner] in
                // The retained list owner validates exact source/account even if
                // this sheet is closed. Invalidation itself never starts a read.
                owner?.invalidate(reader: reader, identity: presentation.actions.identity)
            }
        }
        .cySheet(item: $readAll) { presentation in
            let owner = listModel
            IMConversationReadAllView(batch: presentation.batch) { [weak owner] in
                owner?.invalidate(reader: reader, identity: presentation.batch.identity)
            }
        }
        .cySheet(item: $safety) { presentation in
            let owner = listModel
            IMSafetyReviewView(owner: presentation.owner) { [weak owner] action in
                // Hidden rows leave only through a fresh /conversations reread.
                if case .hide = action { owner?.invalidate(reader: reader, identity: presentation.owner.scope.identity) }
            }
        }
        .onChange(of: reader.identity) { _, _ in rowAction = nil }
        .onChange(of: reader.identity) { _, _ in showsSquare = false; safety = nil; selectedTab = nil }
        .onChange(of: MessagingReadScreenInput(reader: reader, refreshRevision: 0)) { _, _ in retireReviews() }
        .onDisappear { readAll?.batch.stop() }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text("messaging.searchPrompt"))
        .onChange(of: query) { _, _ in displayLimit = 30 }
        .onChange(of: selectedTab) { _, _ in displayLimit = 30 }
        .themeDomain(.player)
    }
    @ViewBuilder private func conversationRow(_ conversation: MessagingConversation) -> some View {
        UGCBlockedFilterContainer(
            memberID: conversation.kind == .direct ? conversation.counterparty?.id : nil,
            authorName: conversation.kind == .direct ? conversation.counterparty?.nickname : nil
        ) {
            NavigationLink {
                MessagingHistoryView(conversationID:conversation.id,conversation:conversation,reader:reader,sender:senderForConversation?(conversation.id),mediaReader:mediaReader,expanded:expanded,
                    directory: messagingHistoryDirectoryRequest(reader: reader, conversation: conversation),
                    onConversationMutationAccepted: conversationInvalidation(for: conversation.id))
            } label: { IMInboxRow(conversation: conversation) }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("messaging.conversation.\(conversation.id)")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                rowActions(for: conversation)
            }
            .contextMenu { rowActions(for: conversation) }
        }
    }
    private struct DaySection { let id: Int; let title: String; let rows: [MessagingConversation] }
    private func daySections(_ rows: [MessagingConversation]) -> [DaySection] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = IMInboxTime.chinaZone
        let now = Date()
        func bucket(_ row: MessagingConversation) -> Int {
            guard let date = IMInboxTime.parse(row.lastMessageAt) else { return 2 }
            if calendar.isDate(date, inSameDayAs: now) { return 0 }
            if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return 1 }
            return 2
        }
        // R7-PC-D8-4: catalog keys, not inline literals.
        let titles = ["messaging.day.today", "messaging.day.yesterday", "messaging.day.earlier"].map { appLocalized(String.LocalizationValue($0), locale: locale) }
        return (0...2).compactMap { b in
            let group = rows.filter { bucket($0) == b }
            return group.isEmpty ? nil : DaySection(id: b, title: titles[b], rows: group)
        }
    }
    private struct ChannelSection { let id: String; let title: LocalizedStringKey?; let rows: [MessagingConversation] }
    /// Presentation grouping only: theme, club, then team spaces in server order;
    /// rows without a recognised space key stay in a final untitled section.
    private func channelSections(_ rows: [MessagingConversation]) -> [ChannelSection] {
        let spaces = NativeChannelSpace.project(rows)
        var placed = Set<Int>()
        var sections: [ChannelSection] = []
        let kinds: [(NativeChannelSpace.Kind, LocalizedStringKey)] = [(.hangout, "messaging.channels.theme"), (.club, "messaging.channels.club"), (.team, "messaging.channels.team")]
        for (kind, title) in kinds {
            let members = spaces.filter { $0.kind == kind }.flatMap(\.channels)
            guard !members.isEmpty else { continue }
            members.forEach { placed.insert($0.id) }
            sections.append(ChannelSection(id: kind.rawValue, title: title, rows: rows.filter { row in members.contains { $0.id == row.id } }))
        }
        let rest = rows.filter { !placed.contains($0.id) }
        if !rest.isEmpty { sections.append(ChannelSection(id: "other", title: nil, rows: rest)) }
        return sections
    }
    private var currentTab: MessagingSegment { selectedTab ?? .all }
    /// Mini-program empty copy; All and Direct offer Square only when the host
    /// grants it (source `communityPostRead`).
    @ViewBuilder private func emptyState(tab: MessagingSegment, conversations: [MessagingConversation]) -> some View {
        switch tab {
        case .all: emptyState(title: "messaging.empty.all", identifier: "messaging.list.empty", tab: tab)
        case .channels: emptyState(title: "im.inbox.emptyGroup", identifier: "messaging.list.empty", tab: tab)
        case .direct: emptyState(title: "im.inbox.emptyDirect", identifier: "messaging.list.empty", tab: tab)
        }
    }
    @ViewBuilder private func emptyState(title: LocalizedStringKey, identifier: String, tab: MessagingSegment? = nil) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "bubble.left.and.bubble.right")
        } actions: {
            // P032: only a successfully loaded, genuinely empty direct-message list
            // offers Square. Search misses, errors and missing grants do not.
            if tab == .direct || tab == .all, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               squareDestination != nil {
                Button("im.inbox.emptySquare", systemImage: "person.2") {
                    guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          listModel.appearance != nil, !showsSquare,
                          reader.isConfigured, reader.identity != nil,
                          listModel.loadedInput == MessagingReadScreenInput(reader: reader, refreshRevision: 0),
                          let conversations = listModel.value,
                          currentTab != .channels, currentTab.rows(conversations).isEmpty,
                          IMInboxSummary(conversations: conversations).rows(for: .direct).isEmpty else { return }
                    showsSquare = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("messaging.list.emptySquare")
            }
        }
        .accessibilityIdentifier(identifier)
    }
    @ViewBuilder private func rowActions(for conversation: MessagingConversation) -> some View {
        if let identity = reader.identity, let coordinator = expanded?.coordinator(conversation.id) {
            let actions = IMConversationRowActions(conversation: conversation, identity: identity,
                coordinator: coordinator, reader: reader)
            ForEach(Array(IMConversationRowAction.available(for: conversation).enumerated()), id: \.offset) { _, action in
                Button {
                    guard readAll == nil else { return }
                    if actions.prepare(action) { rowAction = .init(actions: actions) }
                } label: {
                    Label(LocalizedStringKey(action.titleKey), systemImage: action.symbolName)
                }
                .disabled(!actions.canPrepare)
                .accessibilityIdentifier("im.row.\(conversation.id).\(action == .markRead ? "read" : "mute")")
            }
        }
        if let owner = expanded?.safetyCoordinator?(conversation.id),
           owner.permits(.hide(conversationID: conversation.id)) {
            Button(role: .destructive) {
                guard rowAction == nil, readAll == nil, safety == nil, owner.isCurrent else { return }
                if case .outcomeUnknown = owner.visibleState { safety = .init(owner: owner); return }
                if owner.review(.hide(conversationID: conversation.id)) { safety = .init(owner: owner) }
            } label: { Label("im.safety.hide.rowAction", systemImage: "trash") }
            .accessibilityLabel(Text("im.safety.hide.rowAction"))
            .accessibilityIdentifier("im.row.\(conversation.id).delete")
        }
    }
    private func canPresentReadAll(_ conversations: [MessagingConversation]) -> Bool {
        guard reader.isConfigured, let identity = reader.identity, let expanded else { return false }
        return IMConversationReadAll.eligible(conversations).contains { conversation in
            guard let owner = expanded.coordinator(conversation.id) else { return false }
            return owner.isCurrent && owner.writer.isConfigured && owner.scope.identity == identity
                && owner.scope.conversationID == conversation.id
        }
    }
    private func presentReadAll(_ conversations: [MessagingConversation]) {
        // A toolbar closure may be queued while a newer list is loading. Require
        // the exact currently published source snapshot before freezing this batch.
        guard rowAction == nil, readAll == nil, let identity = reader.identity,
              listModel.value == conversations,
              listModel.loadedInput == MessagingReadScreenInput(reader: reader, refreshRevision: 0),
              listModel.appearance != nil, let expanded else { return }
        let batch = IMConversationReadAll(conversations: conversations, identity: identity,
            reader: reader, coordinator: expanded.coordinator)
        guard !batch.items.isEmpty else { return }
        readAll = .init(batch: batch)
    }
    private func conversationInvalidation(for conversationID: Int) -> (IMScope) -> Void {
        let source = reader, identity = reader.identity, owner = listModel
        return { [weak owner] scope in
            guard scope.conversationID == conversationID, scope.identity == identity else { return }
            // Exact reader/account/epoch validation lives in the retained list owner.
            // Invalidation preserves this view's search, filter and display window.
            owner?.invalidate(reader: source, identity: scope.identity)
        }
    }
    private func retireReviews() {
        readAll?.batch.stop(); readAll = nil; rowAction = nil; safety = nil
    }
    private func filtered(_ conversations: [MessagingConversation], tab: MessagingSegment) -> [MessagingConversation] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return tab.rows(conversations).filter { conversation in
            if keyword.isEmpty { return true }
            // Search covers the conversation names and previews already loaded, not history.
            return searchName(conversation).localizedCaseInsensitiveContains(keyword)
                || searchPreview(conversation).localizedCaseInsensitiveContains(keyword)
        }
    }
    private func searchName(_ conversation: MessagingConversation) -> String {
        // OR-023: the system conversation is always 城瘾小助手, never the counterparty nickname.
        if IMConversationTitlePolicy.usesAssistantTitle(conversation) { return appLocalized("messaging.system", locale: locale) }
        if let name = conversation.counterparty?.nickname, !name.isEmpty { return name }
        switch conversation.kind {
        case .system: return appLocalized("messaging.system",locale:locale)
        case .merchant: return appLocalized("messaging.official",locale:locale)
        case .group: return appLocalized("messaging.group",locale:locale)
        default: return appLocalized("messaging.member",locale:locale)
        }
    }
    private func searchPreview(_ conversation: MessagingConversation) -> String {
        if let text = conversation.lastMessageText, !text.isEmpty { return text }
        if conversation.lastMessageType == 2 { return appLocalized("messaging.image",locale:locale) }
        if conversation.lastMessageType == 4 { return appLocalized("poll.title",locale:locale) }
        if conversation.lastMessageType == 3 { return appLocalized("messaging.card",locale:locale) }
        return ""
    }
}

/// Messages list segments: All, Channels and Direct. System notices travel
/// with Direct under the assistant name; channels are the server's group rows.
/// R7-PC-D8-1: the MP list's two tabs (`im/list/index.js:276-279`).
enum MessagingBox: Hashable { case inbox, outbox }

enum MessagingSegment: String, CaseIterable, Hashable {
    case all, channels, direct

    func rows(_ conversations: [MessagingConversation]) -> [MessagingConversation] {
        switch self {
        case .all: return conversations
        case .channels: return conversations.filter { IMInboxTab.tab(for: $0) == .group }
        case .direct: return conversations.filter { IMInboxTab.tab(for: $0) != .group }
        }
    }
    func badge(_ summary: IMInboxSummary) -> Int {
        switch self {
        case .all: return summary.badge(for: .direct) + summary.badge(for: .system) + summary.badge(for: .group)
        case .channels: return summary.badge(for: .group)
        case .direct: return summary.badge(for: .direct) + summary.badge(for: .system)
        }
    }
    /// Reads IMListPageReady.unreadTotalText per tab: an unknown unread is an em dash, a real 0 shows no badge.
    func badgeText(_ conversations: [MessagingConversation]) -> String? {
        let tabs: [IMInboxTab]
        switch self {
        case .all: tabs = [.direct, .system, .group]
        case .channels: tabs = [.group]
        case .direct: tabs = [.direct, .system]
        }
        let texts = tabs.map { IMListPageReady.unreadTotalText(conversations, tab: $0) }
        if texts.contains(IMListPageReady.unknownMark) { return IMListPageReady.unknownMark }
        return IMInboxSummary.badgeText(texts.compactMap(Int.init).reduce(0, +))
    }
    /// A single Text: segmented pickers only render Text/Image segment labels.
    func label(badgeText text: String?) -> Text {
        let title: Text
        switch self {
        case .all: title = Text("messaging.segment.all")
        case .channels: title = Text("messaging.segment.channels")
        case .direct: title = Text("messaging.segment.direct")
        }
        // Unknown unread: label only, the dash belongs inside rows and stats.
        guard let text, text != IMListPageReady.unknownMark else { return title }
        return title + Text(verbatim: " \(text)")
    }
}

/// Uses the channel and space already on this conversation. Missing guild kind or guild id stays closed.
@MainActor func messagingHistoryDirectoryRequest(reader: any MessagingReading, conversation: MessagingConversation) -> ChannelDirectoryAdmissionRequest? {
    guard let context = conversation.directoryContext,
          let hold = (reader as? MessagingSessionReader)?.directoryTransportHold() else { return nil }
    return ChannelDirectoryTransportInjection.request(
        configuration: hold.configuration, transport: hold.transport, token: hold.token,
        accountID: hold.accountID, epoch: hold.epoch,
        selection: ChannelDirectorySelection(channelID: context.channelID, spaceID: context.spaceID, kind: context.kind))
}
