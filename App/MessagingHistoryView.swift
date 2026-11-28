import SwiftUI

/// Retained by the history route. Binding is synchronous during rendering and
/// does not publish, launch work or alter SwiftUI state. Old callback closures
/// hold a lease, not the old View's immutable reader/policy as their authority.
@MainActor final class IMConversationReplyAuthority: ObservableObject {
    struct Lease: Equatable { fileprivate let id: UUID }
    private struct Input: Equatable {
        let readerID: ObjectIdentifier
        let identity: MessagingReadIdentity?
        let configured: Bool
        let ready: Bool
        let policy: IMConversationReplyPolicy
    }
    private var input: Input?
    private var lease: Lease?
    private var reader: (any MessagingReading)?

    func bind(reader: any MessagingReading, policy: IMConversationReplyPolicy, ready: Bool) -> Lease {
        let next = Input(readerID: ObjectIdentifier(reader), identity: reader.identity,
            configured: reader.isConfigured, ready: ready, policy: policy)
        if input != next || lease == nil { lease = Lease(id: UUID()) }
        input = next; self.reader = reader
        return lease!
    }
    func invalidate() { lease = nil; input = nil; reader = nil }
    func isCurrent(_ expected: Lease) -> Bool {
        guard lease == expected, let input, let reader else { return false }
        return input.ready && input.configured && input.policy.isValidConversation
            && input.identity != nil && reader.identity == input.identity && reader.isConfigured
            && ObjectIdentifier(reader) == input.readerID
    }
    func permitsReply(_ expected: Lease) -> Bool {
        isCurrent(expected) && input?.policy.permitsReply == true
    }
}

private struct MessagingHistoryLoadKey: Hashable {
    let identity: MessagingReadIdentity?
    let conversationID: Int
    let readerID: ObjectIdentifier
    let configured: Bool
}

@MainActor
struct MessagingHistoryView: View {
    let conversationID: Int
    let conversation: MessagingConversation?
    let reader: any MessagingReading
    let sender: MessageActionCoordinator?
    let mediaReader: (any SocialMessageMediaReading)?
    let expanded: IMExpandedNavigationContext?
    let admission: ChannelAdmissionRoute?
    let directory: ChannelDirectoryAdmissionRequest?
    let onConversationMutationAccepted: (IMScope) -> Void
    @StateObject private var replyAuthority = IMConversationReplyAuthority()
    @State private var history: MessagingHistory
    @State private var loadedIdentity: MessagingReadIdentity?
    @State private var loadedReaderID: ObjectIdentifier?
    /// Two independent fetch lifecycles (docs/release/state-machines/views.md): the transcript and the earlier-page fetch.
    /// Messages live in `history`, so the phases carry no value (`.loaded(())` = last fetch succeeded).
    @State private var phase: CYPhase<Void, MessagingLoadIssue> = .loading
    @State private var earlierPhase: CYPhase<Void, MessagingLoadIssue> = .idle
    private var isLoading: Bool { phase.isLoading }
    private var issue: MessagingLoadIssue? { phase.failure }
    private var isLoadingEarlier: Bool { earlierPhase.isLoading }
    private var earlierIssue: MessagingLoadIssue? { earlierPhase.failure }
    /// Guard: only an in-flight fetch falls back to idle; a failure stays visible.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    private func settleLoadingEarlier() { if earlierPhase.isLoading { earlierPhase = .idle } }
    @State private var generation: UInt64 = 0
    @State private var visibleMessageID: Int?
    @State private var showingPollComposer = false
    /// R7-PC-D9-3: the composer `+` (图片 / 位置 / 路线) pushes the conversation's existing send controls.
    @State private var showingAttachControls = false
    /// R9-PC-D9-1: the `+` item that opened the controls page; the toolbar entry opens it with nil (every control).
    @State private var attachFocus: IMComposerPlusItem?
    @State private var pageBlocked: Bool?
    /// subpackageB/pages/im/chat/index page model for the last first-page read. Unknown stays unknown:
    /// an empty first page that still reports `hasMore` is not shown as "no messages".
    @State private var sessionPage: IMChatSessionPage?
    @State private var pageBlockedByMe: Bool?
    @State private var safety: IMSafetyPresentation?
    /// design-r2-social P13: a card answer tapped in the transcript opens its page from here.
    @State private var cardRoute: MessagingCardRoute?
    /// Session-local quiet lines: the MP button the viewer picked, and the option they voted for (from the poll read).
    @State private var cardChoices: [Int: String] = [:]
    @State private var pollVotes: [Int: String] = [:]
    @Environment(\.dismiss) private var dismissHistory
    @Environment(\.ugcSafetyContext) private var ugcSafety
    /// Continuity (r1 item 9): carries the sent text from the composer into its bubble. Presentation only.
    @StateObject private var sendFlight = IMSendFlight()
    @Namespace private var sendFlightSpace
    @QuestifyReduceMotion private var reduceMotion

    init(conversationID: Int, conversation: MessagingConversation? = nil, reader: any MessagingReading, sender:MessageActionCoordinator?=nil,mediaReader:(any SocialMessageMediaReading)?=nil,expanded:IMExpandedNavigationContext?=nil, admission: ChannelAdmissionRoute? = nil, directory: ChannelDirectoryAdmissionRequest? = nil, onConversationMutationAccepted: @escaping (IMScope) -> Void = { _ in }) {
        self.conversationID = conversationID; self.conversation = conversation; self.reader = reader;self.sender=sender;self.mediaReader=mediaReader;self.expanded=expanded
        self.admission = admission
        self.directory = directory
        self.onConversationMutationAccepted = onConversationMutationAccepted
        _history = State(initialValue: MessagingHistory(conversationID: conversationID))
    }
    /// One builder for the toolbar entry and the composer `+` destination.
    private func conversationControls(_ owner: IMExpandedCoordinator, lease: IMConversationReplyAuthority.Lease) -> some View {
        let authority = replyAuthority
        return IMConversationControlsView(coordinator: owner, identity: reader.identity,
            uploadOwner: replyPolicy.permitsReply && replyBlock == nil ? expanded?.uploadCoordinator(conversationID) : nil,
            topicReader: expanded?.topicReader, replyPolicy: replyPolicy,
            isConversationCurrent: { authority.isCurrent(lease) },
            readCursor: channelReadCursor,
            admission: admission,
            directory: directory,
            showsAdmissionEntry: directory != nil || conversation?.kind == .group,
            isMuted: conversation?.muted, focus: attachFocus,
            onConversationMutationAccepted: onConversationMutationAccepted) { _ in Task { await reload() } }
    }
    private func openAttach(_ item: IMComposerPlusItem) { attachFocus = item; showingAttachControls = true }
    private var replyBlock: IMReplyBlock? {
        IMReplyBlock.from(conversation: conversation, page: pageBlocked, blockedByMe: pageBlockedByMe)
    }
    /// Type 5 only, and only after this page has loaded. Appearance does not send it.
    private var channelReadCursor: Int? {
        guard conversation?.type == 5, currentHistoryReady else { return nil }
        if let id = history.messages.last?.id, id > 0 { return id }
        return history.messages.isEmpty ? 0 : nil
    }
    private var canCreatePoll: Bool { conversation?.supportsGroupPolls == true && currentHistoryReady }
    /// Mirrors the bottom inset branches: the composer shows only when no notice replaces it.
    private var showsComposer: Bool {
        if replyPolicy.isSystemNotice, currentHistoryReady { return false }
        if let block = replyBlock, block != .systemNotice, currentHistoryReady { return false }
        return replyPolicy.permitsReply && sender != nil
    }
    private var replyPolicy: IMConversationReplyPolicy {
        .init(conversationID: conversationID, conversation: conversation)
    }
    private var currentHistoryReady: Bool {
        loadedIdentity != nil && loadedIdentity == reader.identity
            && loadedReaderID == ObjectIdentifier(reader) && reader.isConfigured
            && history.conversationID == conversationID && replyPolicy.isValidConversation
            && !isLoading && issue == nil
    }
    @Environment(\.imRecipientPreviewLeases) private var previewLeases
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// E2E-20261113b N1. The lease's conversation is server-provided only: the decoded conversation record, else the
    /// decoded messages' own conversation. The route's `conversationID` is never used; `issue` re-checks each message.
    private var recipientPreviewInput: IMRecipientPreviewInput {
        guard let previewLeases, let serverConversationID = conversation?.id ?? history.messages.first?.conversationID,
              serverConversationID > 0 else { return .closed }
        if isLoading { return IMRecipientPreviewInput(phase: .loading, leases: [], now: Date()) }
        if issue != nil { return IMRecipientPreviewInput(phase: .error, leases: [], now: Date()) }
        return IMRecipientPreviewInput(phase: .ready, leases: previewLeases(Int64(serverConversationID)), now: Date())
    }

    var body: some View {
        let authority = replyAuthority
        let lease = authority.bind(reader: reader, policy: replyPolicy, ready: currentHistoryReady)
        ZStack {
            if !reader.isConfigured {
                ChatHistoryStatus(issue: .init(APIError.notConfigured), identifier: "messaging.history.unconfigured", retry: {})
            } else if reader.identity == nil {
                ChatHistoryStatus(issue: .init(APIError.unauthorized), identifier: "messaging.history.signedOut", retry: {})
            } else if conversationID <= 0 || (conversation != nil && conversation?.id != conversationID) {
                ChatHistoryStatus(issue: .init(APIError.invalidRequest), identifier: "messaging.history.missing", retry: {})
            } else if isLoading {
                ChatHistoryLoading(labelKey: "messaging.loading", identifier: "messaging.history.loading")
            } else if let issue {
                VStack(spacing: CYSpacing.lg) {
                    ChatHistoryStatus(issue: issue, identifier: "messaging.history.error") { Task { await reload() } }
                    // Source closed hangout: 「返回消息列表」 instead of a dead end.
                    // This is the one primary action on the closed screen. Retry stays secondary.
                    if issue.titleKey == "messaging.closed" {
                        Button("im.chat.returnToList") { dismissHistory() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("im.chat.returnToList")
                    }
                }
                .padding(.horizontal, CYSpacing.lg)
            } else if currentHistoryReady {
                transcript
            } else {
                ChatHistoryLoading(labelKey: "messaging.loading", identifier: "messaging.history.loading")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // System assistant (type 2): 「我的举报」 above the transcript, as in the mini-program chat page.
            if replyPolicy.isSystemNotice, currentHistoryReady { IMReportProgressEntry() }
        }
        .safeAreaInset(edge:.bottom) {
            if replyPolicy.isSystemNotice, currentHistoryReady {
                Label("im.reply.systemNotice", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.bar)
                    .accessibilityIdentifier("im.reply.systemNotice")
            } else if let block = replyBlock, block != .systemNotice, currentHistoryReady {
                Label(LocalizedStringKey(block == .blockedByMe ? "im.chat.blockedByMe" : "im.chat.peerUnavailable"),
                      systemImage: "hand.raised")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.bar)
                    .accessibilityIdentifier("im.chat.replyBlocked")
            } else if replyPolicy.permitsReply, let sender {
                MessageActionComposer(coordinator: sender, identity: reader.identity,
                    conversationReady: currentHistoryReady,
                    canReply: { authority.permitsReply(lease) },
                    createPoll: canCreatePoll ? { showingPollComposer = true } : nil,
                    flight: sendFlight,
                    attach: currentHistoryReady && expanded?.coordinator(conversationID) != nil ? { item in openAttach(item) } : nil) { receipt in
                    // The ghost lands on the acknowledged message only if its bubble is not on screen yet.
                    if history.messages.contains(where: { $0.id == receipt.id }) { sendFlight.cancel() }
                    else { sendFlight.land(on: receipt.id) }
                    Task { await refreshInPlace() }
                }
            }
        }
        .cySheet(isPresented: $showingPollComposer) { Group {
            NavigationStack {
                if let owner = expanded?.pollCoordinator?(conversationID, nil) { GroupPollView(owner: owner, creating: true) }
                else { GroupPollUnavailableView().toolbar { Button("action.cancel") { showingPollComposer = false } } }
            }
            .themeDomain(.player)
        }.cySheet(detents: [.large])
        }
        .navigationDestination(isPresented: $showingAttachControls) {
            if let owner = expanded?.coordinator(conversationID) { conversationControls(owner, lease: lease) }
        }
        .navigationDestination(item: $cardRoute) { route in cardRouteDestination(route) }
        .onChange(of: cardRoute) { old, new in
            if new == nil, case .poll(let messageID) = old { readPollVote(messageID) }
        }
        .onChange(of: loadedIdentity) { _, _ in cardRoute = nil; cardChoices = [:]; pollVotes = [:] }
        .privacySensitive()
        .appNavigationTitle("messaging.history.title")
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if currentHistoryReady,
                   let owner = expanded?.coordinator(conversationID) {
                    NavigationLink {
                        conversationControls(owner, lease: lease)
                    } label: { Label("im.full.title", systemImage: "info.circle") }
                    .accessibilityIdentifier("im.full.controlsEntry")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                // With a composer the poll entry is its leading `+`; otherwise it joins the … menu.
                let createPoll: (() -> Void)? = canCreatePoll && !showsComposer ? { showingPollComposer = true } : nil
                if currentHistoryReady, let owner = expanded?.safetyCoordinator?(conversationID), owner.isCurrent {
                    IMChatMoreMenu(owner: owner, conversation: conversation, blockedByMe: pageBlockedByMe,
                                   messages: history.messages, accountID: loadedIdentity?.accountID ?? 0, createPoll: createPoll) { safety = .init(owner: owner) }
                } else if let createPoll {
                    Button("poll.create", systemImage: "chart.bar.xaxis", action: createPoll)
                        .accessibilityIdentifier("poll.createEntry")
                }
            }
            ToolbarItem(placement: .principal) {
                if conversation != nil {
                    HStack(spacing: CYSpacing.sm) {
                        // R7-PC-D9-4 (MP im/chat/index.wxml:68): the counterparty's avatar, generated art as fallback.
                        IMRemoteAvatar(url: conversation?.kind == .system || conversation?.kind == .group ? nil : IMRemoteAvatar<EmptyView>.url(conversation?.counterparty?.avatar)) {
                            if conversation?.kind == .system || conversation?.kind == .group {
                                Image(systemName: conversation?.kind == .group ? "person.3.fill" : "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.quaternary)
                                    .accessibilityHidden(true)
                            } else {
                                MPAsset.AvatarDefault.dProfile.resizable().scaledToFill() // MP `/images/d_profile.png`
                            }
                        }
                            .frame(width: 28, height: 28).clipShape(Circle())
                        if !dynamicTypeSize.isAccessibilitySize {
                            MessagingConversationName(conversation: conversation).font(.headline).cyWrapText()
                        }
                    }
                    .accessibilityElement(children: .combine)
                } else { Text("messaging.history.title").font(.headline) }
            }
        }
        .cySheet(item: $safety) { presentation in
            ChatSafetySheet(owner: presentation.owner) { action in
                switch action {
                case .hide: dismissHistory()                       // source navigateBack after hide
                case .block, .unblock: Task { await reload() }     // blockedByMe is read back, not assumed
                case .report, .reportWithReason: break
                }
            }
        }
        .themeDomain(.player)
        .onChange(of: reader.identity) { _, _ in showingPollComposer = false; safety = nil }
        .refreshable { if issue?.isTerminal != true { await refreshInPlace() } }
        .onAppear { sendFlight.namespace = reduceMotion ? nil : sendFlightSpace }
        .onChange(of: reduceMotion) { _, reduced in sendFlight.namespace = reduced ? nil : sendFlightSpace }
        .task(id: MessagingHistoryLoadKey(identity: reader.identity, conversationID: conversationID,
            readerID: ObjectIdentifier(reader), configured: reader.isConfigured)) {
            // Returning from a message detail keeps earlier pages and the visible anchor.
            // Only a new account epoch or an unfinished first load starts an automatic read.
            if !currentHistoryReady { await reload() }
        }
        .onDisappear { generation &+= 1; settleLoadingEarlier() }
    }
    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.sm) {
                // Mini-program chat-hero: the conversation name sits large under the bar.
                if conversation != nil {
                    MessagingConversationName(conversation: conversation)
                        .font(.title3.weight(.semibold)).foregroundStyle(.primary)
                        .cyWrapText().padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("messaging.history.hero")
                }
                if history.hasMore {
                    if isLoadingEarlier {
                        ChatHistoryLoading(labelKey: "messaging.loadingEarlier", identifier: "messaging.history.loadingEarlier", fills: false)
                    } else {
                        if let earlierIssue {
                            // mp-states r3: MP im/chat cy-inline-error 更早消息没有加载 · sub · 重试 — one titled state
                            // with the reason once and the retry inside it.
                            ChatEarlierFailure(issue: earlierIssue) { Task { await loadEarlier() } }
                        } else {
                            Button { Task { await loadEarlier() } } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Label("messaging.earlier", systemImage: "clock.arrow.circlepath")
                                    Spacer(minLength: 8)
                                    if let earlierValue {
                                        Text(verbatim: earlierValue).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("messaging.history.earlier")
                        }
                    }
                }
                if history.messages.isEmpty {
                    if sessionPage?.phase == .unknown {
                        ChatHistoryUnknown()
                    } else {
                        ChatHistoryEmpty(hint: emptyHintKey)
                    }
                }
                let dividers = IMInboxTime.dividers(for: history.messages, now: Date())
                let accountID = loadedIdentity?.accountID ?? 0
                let positions = ChatGrouping.positions(history.messages)
                ForEach(history.messages) { message in
                    let blockedSenderID = message.senderID == accountID ? nil : message.senderID
                    let blockedSenderName = message.senderID == accountID ? nil : message.senderName
                    UGCBlockedFilterContainer(memberID: blockedSenderID, authorName: blockedSenderName) {
                        VStack(spacing: CYSpacing.sm) {
                            // Time is grouped: one divider per burst, not a stamp on every bubble.
                            if let divider = dividers[message.id] {
                                IMChatDividerLabel(divider: divider).font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).accessibilityIdentifier("im.chat.divider.\(message.id)")
                            }
                            let answersInline = expanded != nil && MessagingInlineCardAnswers.hasAnswers(message)
                            messageRowLink(message, accountID: accountID, position: positions[message.id] ?? .single,
                                           answersInline: answersInline)
                            // design-r2-social P13: the card's answers sit in the transcript, outside the row link,
                            // as the MP chat draws `genericButtons` inside the card.
                            let isOwnRow = message.senderID == accountID && accountID > 0
                            let isNoticeRow = (conversation?.kind == .system || message.senderID == 0) && !isOwnRow
                            if answersInline {
                                MessagingInlineCardAnswers(message: message, isOwn: isOwnRow, isNotice: isNoticeRow,
                                                           chosenLabel: cardChoices[message.id]) { action in
                                    answerCard(action, messageID: message.id)
                                }
                            } else if expanded?.pollCoordinator != nil, message.isPayloadVisible, message.type == 4, message.pollReference != nil {
                                MessagingInlinePollAnswer(message: message, isOwn: isOwnRow, isNotice: isNoticeRow,
                                                          votedOption: pollVotes[message.id]) {
                                    cardRoute = .poll(messageID: message.id)
                                }
                            }
                        }
                        .padding(.top, [.middle, .last].contains(positions[message.id] ?? .single) ? -CYSpacing.xs - 1 : 0)
                        .id(message.id)
                    }
                    .imChatRowTransition(landing: message.id == sendFlight.landingID)
                }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scrollTargetLayout()
        }
        // Few messages sit just above the composer and grow upward, as in native chat.
        .defaultScrollAnchor(.bottom)
        .scrollPosition(id: $visibleMessageID, anchor: .top)
        .scrollDismissesKeyboard(.interactively)
    }
    private func reload() async {
        // Revoke old callbacks before state changes and before the next render.
        replyAuthority.invalidate()
        generation &+= 1
        let request = generation, identity = reader.identity, source = ObjectIdentifier(reader)
        history = MessagingHistory(conversationID: conversationID)
        loadedIdentity = nil; loadedReaderID = nil; phase = .loading; earlierPhase = .idle
        pageBlocked = nil; pageBlockedByMe = nil; sessionPage = nil
        guard reader.isConfigured, identity != nil, conversationID > 0,
              conversation == nil || conversation?.id == conversationID else { phase = .idle; return }
        defer { if generation == request { settleLoading() } }
        do {
            let page = try await reader.messagingMessages(conversationID: conversationID, cursor: 0)
            guard isCurrent(request, identity, source: source) else { return }
            try history.replace(with: page)
            pageBlocked = page.blocked; pageBlockedByMe = page.blockedByMe
            if page.blockedByMe == true, let peerID = conversation?.counterparty?.id, peerID > 0 {
                ugcSafety?.blockedStore.recordLocalBlock(memberID: peerID, authorName: conversation?.counterparty?.nickname)
            }
            sessionPage = IMChatSessionWire.fromReader(conversation: conversation, page: page)
            loadedIdentity = identity; loadedReaderID = source; visibleMessageID = history.messages.last?.id
            phase = .loaded(())
            markReadAfterFirstPage(request, identity, source: source)
        } catch is CancellationError {} catch {
            guard isCurrent(request, identity, source: source) else { return }
            sessionPage = IMChatSessionWire.failed(error, conversation: conversation)
            phase = .failed(MessagingLoadIssue(error), retry: nil)
        }
    }
    /// Same read and end state as `reload()` (first page, scrolled to the newest), but the transcript stays on screen
    /// while it loads and the new page lands in one animated step: new messages insert in place and a sent message
    /// takes over its ghost's position. Anything but a ready transcript takes the full `reload()`.
    private func refreshInPlace() async {
        guard currentHistoryReady else { sendFlight.cancel(); await reload(); return }
        generation &+= 1
        let request = generation, identity = reader.identity, source = ObjectIdentifier(reader)
        do {
            let page = try await reader.messagingMessages(conversationID: conversationID, cursor: 0)
            guard isCurrent(request, identity, source: source) else { return }
            var next = MessagingHistory(conversationID: conversationID)
            try next.replace(with: page)
            // Same rebinding as reload(): old callbacks lose their lease before the state changes.
            replyAuthority.invalidate()
            if page.blockedByMe == true, let peerID = conversation?.counterparty?.id, peerID > 0 {
                ugcSafety?.blockedStore.recordLocalBlock(memberID: peerID, authorName: conversation?.counterparty?.nickname)
            }
            // An earlier-page read started meanwhile would prepend onto the old cursor: drop it, as reload() does.
            if isLoadingEarlier { generation &+= 1 }
            withAnimation(CYMotion.resolve(.easeInOut(duration: CYMotion.Duration.standard), reduceMotion: reduceMotion)) {
                history = next
                pageBlocked = page.blocked; pageBlockedByMe = page.blockedByMe
                sessionPage = IMChatSessionWire.fromReader(conversation: conversation, page: page)
                earlierPhase = .idle
                visibleMessageID = history.messages.last?.id
                sendFlight.settle()
            }
            loadedIdentity = identity; loadedReaderID = source
            phase = .loaded(())
        } catch is CancellationError {
            if generation == request { sendFlight.cancel(); settleLoadingEarlier() }
        } catch {
            guard isCurrent(request, identity, source: source) else { return }
            replyAuthority.invalidate()
            sendFlight.cancel()
            history = MessagingHistory(conversationID: conversationID)
            loadedIdentity = nil; loadedReaderID = nil; earlierPhase = .idle
            pageBlocked = nil; pageBlockedByMe = nil
            sessionPage = IMChatSessionWire.failed(error, conversation: conversation)
            phase = .failed(MessagingLoadIssue(error), retry: nil)
        }
    }
    private func loadEarlier() async {
        guard !isLoading, !isLoadingEarlier, history.conversationID == conversationID, history.hasMore, let cursor = history.nextCursor,
              loadedIdentity != nil, loadedIdentity == reader.identity else { return }
        let request = generation, identity = loadedIdentity, source = ObjectIdentifier(reader), startAnchor = visibleMessageID
        earlierPhase = .loading
        defer { if generation == request { settleLoadingEarlier() } }
        do {
            let page = try await reader.messagingMessages(conversationID: conversationID, cursor: cursor)
            guard isCurrent(request, identity, source: source) else { return }
            // Keep the message the reader is looking at now (they may have scrolled while it loaded) pinned at the top,
            // and apply the older rows in one unanimated step so nothing slides under the finger.
            let anchor = visibleMessageID ?? startAnchor
            var still = Transaction(); still.disablesAnimations = true
            try withTransaction(still) {
                try history.prepend(page, requestedCursor: cursor)
                visibleMessageID = anchor
            }
        } catch is CancellationError {} catch {
            guard isCurrent(request, identity, source: source) else { return }
            let failure = MessagingLoadIssue(error)
            if failure.isTerminal {
                // Closed/unauthorized conversations stop showing their prior transcript.
                replyAuthority.invalidate()
                history = MessagingHistory(conversationID: conversationID); phase = .failed(failure, retry: nil)
            } else { earlierPhase = .failed(failure, retry: nil) }
        }
    }
    /// R7-PC-D9-1 (MP im/chat: `api/im/read` after the first page). With the reviewed ordinary-read grant on
    /// (`canReviewOrdinaryRead`) and the row reporting unread messages, it goes through
    /// the coordinator's own review → confirm, so the frozen cursor, journal and recovery are the explicit path's.
    private func markReadAfterFirstPage(_ request: UInt64, _ identity: MessagingReadIdentity?, source: ObjectIdentifier) {
        guard let owner = expanded?.coordinator(conversationID), owner.isCurrent else { return }
        // MP-first (chat/index.js:861-867 `markRead`): without the reviewed read-receipt/read-state reads, the chat still
        // posts the MP's plain `api/im/read` once the first page is on screen. The server decides; failures stay silent
        // like the MP (`hideLoading`, no toast).
        if !owner.canReviewOrdinaryRead {
            guard conversation?.unread != 0, let writer = owner.writer as? IMExpandedWriter, writer.canWriteInboxConversationRead else { return }
            let id = conversationID
            Task {
                guard isCurrent(request, identity, source: source) else { return }
                try? await writer.markInboxConversationRead(conversationID: id)
            }
            return
        }
        let policy = IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted(imReadGranted: owner.canReviewOrdinaryRead)
        guard policy.shouldAutoMarkRead(unreadCount: conversation?.unread), owner.reviewOrdinaryRead() else { return }
        Task { await owner.confirm(stillAuthorized: { isCurrent(request, identity, source: source) }) }
    }
    private func isCurrent(_ request: UInt64, _ identity: MessagingReadIdentity?, source: ObjectIdentifier) -> Bool {
        generation == request && !Task.isCancelled && identity != nil && reader.identity == identity
            && ObjectIdentifier(reader) == source && reader.isConfigured
            && history.conversationID == conversationID
    }
    private var emptyHintKey: LocalizedStringKey {
        if replyPolicy.isSystemNotice { return "im.chat.emptySystemHint" }
        if sender != nil && replyBlock == nil { return "im.chat.emptyReplyHint" }
        return "messaging.history.emptyHint"
    }
    /// A missing earlier failure message is unknown, so the row shows an em dash.
    private var earlierValue: String? {
        guard let earlierIssue else { return nil }
        if let message = earlierIssue.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        return ChatDisplay.unknown
    }
    /// design-r2-social P13: the same checks and destinations as the detail page's `IMCardActionsView` handler.
    private func answerCard(_ action: IMCardAction, messageID: Int) {
        guard currentHistoryReady, let message = history.messages.first(where: { $0.id == messageID }),
              message.isPayloadVisible, IMCardAction.displayed(for: message).contains(action) else { return }
        if let id = message.card?.broadcastID {
            let sender = reader as? MessagingSessionReader
            Task { await sender?.reportBroadcastClick(id: id) }
        }
        switch action.destination {
        case .topic(let id):
            if let label = MessagingInlineCardAnswers.choiceLabel(action, in: message) { cardChoices[messageID] = label }
            cardRoute = .topic(id)
        case .activity(let id):
            if let label = MessagingInlineCardAnswers.choiceLabel(action, in: message) { cardChoices[messageID] = label }
            cardRoute = .activity(id)
        case .squarePost(let id):
            if let label = MessagingInlineCardAnswers.choiceLabel(action, in: message) { cardChoices[messageID] = label }
            cardRoute = .squarePost(id)
        case .review:
            cardRoute = .detail(messageID: messageID)
        case .unsupported:
            break
        }
    }
    /// After the poll page closes, read the viewer's vote from the poll the coordinator already holds (no request).
    private func readPollVote(_ messageID: Int) {
        guard currentHistoryReady, let message = history.messages.first(where: { $0.id == messageID }),
              message.isPayloadVisible, let reference = message.pollReference,
              let owner = expanded?.pollCoordinator?(message.conversationID, reference),
              let poll = owner.visiblePoll, let mine = poll.myOptionId,
              let option = poll.options.first(where: { $0.id == mine }) else { return }
        pollVotes[messageID] = option.content
    }
    /// mp-nav r3 (MP im/chat index.js:1077-1094 `onLocationTap` / `onRouteTap`): a route / signup card opens its
    /// topic and a location card opens Maps in one tap; every other message keeps the message detail push.
    @ViewBuilder private func messageRowLink(_ message: MessagingMessage, accountID: Int, position: ChatGroupPosition,
                                             answersInline: Bool) -> some View {
        let bubble = MessagingBubble(message: message, conversation: conversation, accountID: accountID, position: position,
                                     answersInline: answersInline)
            .environment(\.imRecipientPreview, recipientPreviewInput)
            .imSendFlight(message.id, in: sendFlight.namespace)
        if !answersInline, expanded != nil, let topicID = MessagingCardTap.topicID(message) {
            Button { openCardTopic(topicID, signup: MessagingCardTap.isSignup(message)) } label: { bubble }
                .buttonStyle(.plain)
                .accessibilityIdentifier("messaging.message.\(message.id)")
        } else if !answersInline, let place = MessagingCardTap.mapItem(message) {
            Button { place.openInMaps(launchOptions: nil) } label: { bubble }
                .buttonStyle(.plain)
                .accessibilityHint(Text("accountCollection.coupon.openInMaps"))
                .accessibilityIdentifier("messaging.message.\(message.id)")
        } else {
            NavigationLink {
                MessagingMessageDetailView(message: message, conversation: conversation,
                    reader: reader, identity: loadedIdentity, mediaReader: mediaReader, expanded: expanded,
                    currentMessage: { history.messages.first { $0.id == message.id } })
            } label: { bubble }
            .buttonStyle(.plain)
            .accessibilityIdentifier("messaging.message.\(message.id)")
        }
    }
    private func openCardTopic(_ id: Int, signup: Bool) {
        guard currentHistoryReady else { return }
        cardRoute = signup ? .signupTopic(id) : .topic(id)
    }
    @ViewBuilder private func cardRouteDestination(_ route: MessagingCardRoute) -> some View {
        switch route {
        case .topic(let id):
            if currentHistoryReady, let expanded { TopicDetailView(id: id, reader: expanded.topicReader) }
        case .signupTopic(let id):
            if currentHistoryReady, let expanded {
                TopicDetailView(id: id, reader: expanded.topicReader,
                                unavailableWallet: expanded.pageDestination?("subpackageMember/signup/index", id))
            }
        case .activity(let id):
            if currentHistoryReady, let page = expanded?.pageDestination?("pages/activity/detail/index", id) { page }
        case .squarePost(let id):
            if currentHistoryReady, let page = expanded?.pageDestination?("pages/square/detail/index", id) { page }
        case .detail(let messageID):
            if let message = history.messages.first(where: { $0.id == messageID }) {
                MessagingMessageDetailView(message: message, conversation: conversation,
                    reader: reader, identity: loadedIdentity, mediaReader: mediaReader, expanded: expanded,
                    currentMessage: { history.messages.first { $0.id == messageID } })
            }
        case .poll(let messageID):
            if currentHistoryReady, let message = history.messages.first(where: { $0.id == messageID }),
               message.isPayloadVisible, let reference = message.pollReference,
               let owner = expanded?.pollCoordinator?(message.conversationID, reference) {
                GroupPollView(owner: owner, current: {
                    reader.identity == loadedIdentity && history.messages.first(where: { $0.id == messageID }) == message
                        && owner.reference == reference && owner.scope.conversationID == message.conversationID
                })
            } else {
                GroupPollUnavailableView()
            }
        }
    }
    private func rowTitle(_ message: MessagingMessage, accountID: Int) -> LocalizedStringKey {
        if !message.isPayloadVisible {
            return message.status == .recalled ? "messaging.message.recalled" : "messaging.message.withheld"
        }
        if message.senderID == accountID && accountID > 0 { return "messaging.you" }
        if message.senderID == 0 { return "messaging.system" }
        return "messaging.member"
    }
    private func rowSymbol(_ message: MessagingMessage, accountID: Int) -> String {
        if !message.isPayloadVisible { return "eye.slash" }
        if message.senderID == accountID && accountID > 0 { return "person.fill" }
        return "bubble.left"
    }
}

private struct MessagingBubble: View {
    let message: MessagingMessage
    let conversation: MessagingConversation?
    let accountID: Int
    var position: ChatGroupPosition = .single
    /// design-r2-social: when the answers sit under the card, the bubble drops its 「点开即可回应」 hint.
    var answersInline = false
    @Environment(\.imRecipientPreview) private var recipientPreview
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var noticeIconSide: CGFloat = 36
    private var isOwn: Bool { message.senderID == accountID && accountID > 0 }
    /// Received messages show a small avatar beside the bubble; only groups add the sender name.
    private var isGroup: Bool { conversation?.kind == .group }
    var body: some View {
        if (conversation?.kind == .system || message.senderID == 0) && !isOwn { noticeCard } else { bubbleRow }
    }
    /// Mini-program system notice: full-width card (icon, title, body, time) instead of a narrow bubble.
    private var noticeCard: some View {
        HStack(alignment: .top, spacing: Theme.Space.s3) {
            Image(systemName: "bell.fill").font(.body).foregroundStyle(.secondary)
                .frame(width: min(noticeIconSide, 60), height: min(noticeIconSide, 60))
                .background(.quaternary, in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                HStack(alignment: .firstTextBaseline) {
                    Text("messaging.system").font(.headline).foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    let stamp = ChatDisplay.stamp(message.createdAt)
                    Text(verbatim: stamp).font(.caption).foregroundStyle(.secondary)
                }
                MessagingMessageContent(message: message, inTranscript: !answersInline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                IMRecipientPreviewRow(message: message, input: recipientPreview)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Messages-style notice: system grouped fill in the system bubble shape (no tinted card).
        .background(.quaternary, in: .rect(cornerRadius: CYRadius.bubble, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("messaging.openDetail"))
    }
    private var bubbleRow: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.s2) {
            if !isOwn {
                // Avatar sits beside the last bubble of a run; earlier ones keep the column empty.
                if position.showsTail {
                    // R7-PC-D9-4 (MP im/chat/index.wxml:160 `senderAvatar`): generated art as fallback.
                    // MP im/chat/index.wxml:160: `senderAvatar || avatar || '/images/d_profile.png'`.
                    IMRemoteAvatar(url: IMRemoteAvatar<EmptyView>.url(message.senderAvatar) ?? (isGroup ? nil : IMRemoteAvatar<EmptyView>.url(conversation?.counterparty?.avatar))) {
                        MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                    }
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } else { Color.clear.frame(width: avatarSize, height: 1) }
            }
            ChatMessageBubble(isOwn: isOwn, timestamp: position.showsTail && ChatDisplay.stamp(message.createdAt) != "—" ? ChatDisplay.stamp(message.createdAt) : nil, position: position) {
                if isGroup && !isOwn && (position == .first || position == .single) {
                    MessagingSenderName(message: message, conversation: conversation, accountID: accountID)
                }
            } content: {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    MessagingMessageContent(message: message, inTranscript: !answersInline)
                    IMRecipientPreviewRow(message: message, input: recipientPreview)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("messaging.openDetail"))
    }
}

/// Source chat 「更多」 option sheet. Entries are offered only when the reviewed
/// runtime grants the exact path; selection opens an explicit review sheet.
@MainActor private struct IMChatMoreMenu: View {
    let owner: IMSafetyCoordinator
    let conversation: MessagingConversation?
    let blockedByMe: Bool?
    let messages: [MessagingMessage]
    /// R8-PC-D9-1: the viewer, so 举报对方 can pick the peer like MP `doReportPeer` (index.js:961-968).
    var accountID: Int = 0
    var createPoll: (() -> Void)? = nil
    let present: () -> Void
    @Environment(\.locale) private var locale
    @State private var pendingSelection: Choice?
    @State private var peerReportClosed = false
    @State private var peerReportMemberID = 0
    @State private var showPeerReport = false
    @Environment(\.communityMemberReportContext) private var memberReportContext
    /// R8-PC-D9-1: 举报对方 is only offered when a live `CommunityMemberReportClient` (writesEnabled) is on the
    /// session, so the row is never a dead-end 「举报对方暂未开放」 alert. The app root injects
    /// `communityMemberReportContext` (writes on, MP-first: the MP mounts `<cy-report-sheet target-type="MEMBER">`
    /// for every signed-in member, `subpackageB/pages/im/chat/index.wxml:250`), which turns it on.
    var peerReportWritesEnabled: Bool = false

    private var offersPeerReport: Bool {
        (peerReportWritesEnabled || memberReportContext != nil) && IMSafetyMenu.offersPeerReport(conversation: conversation)
    }

    private enum Choice: Hashable {
        case poll
        case safety(IMSafetyMenu.Item)
        /// 举报对方. Not an `IMSafetyMenu.Item`: that switch stays the message/conversation grants.
        case peerReport
    }

    private var conversationID: Int { owner.scope.conversationID }

    var body: some View {
        let menu = IMSafetyMenu(conversation: conversation, blockedByMe: blockedByMe)
        let items = menu.items.filter(granted)
        if !items.isEmpty || createPoll != nil || offersPeerReport {
            // System toolbar `Menu` (Messages / Mail pattern) instead of a drawn option sheet. A choice runs after the menu closes.
            Menu {
                ForEach(buildOptionItems(from: items)) { item in
                    Button(role: item.isDanger ? .destructive : nil) {
                        pendingSelection = item.id
                        performPendingSelection()
                    } label: {
                        if let systemImage = item.systemImage {
                            Label(item.title, systemImage: systemImage)
                        } else {
                            Text(verbatim: item.title)
                        }
                    }
                    .accessibilityIdentifier(item.identifier ?? ("im.chat.more" + ".item"))
                }
            } label: {
                Label("im.chat.more", systemImage: "ellipsis.circle")
            }
            .accessibilityLabel(Text("im.chat.more"))
            .accessibilityIdentifier("im.chat.more")
            .alert(Text("im.reportPeer.noPeerMessage"), isPresented: $peerReportClosed) {
                Button("d7.channelChat.ok", role: .cancel) {}
            }
            .cySheet(isPresented: $showPeerReport) {
                CommunityMemberReportSheet(memberID: peerReportMemberID)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func buildOptionItems(from items: [IMSafetyMenu.Item]) -> [CYOptionSheetItem<Choice>] {
        var result: [CYOptionSheetItem<Choice>] = []
        if createPoll != nil {
            result.append(CYOptionSheetItem(
                id: .poll,
                title: appLocalized("poll.create", locale: locale),
                systemImage: "chart.bar.xaxis",
                identifier: "poll.createEntry"
            ))
        }
        for item in items {
            result.append(CYOptionSheetItem(
                id: .safety(item),
                title: titleString(item),
                systemImage: symbol(item),
                isDanger: item == .hide || item == .block,
                identifier: "im.chat.more.\(identifier(item))"
            ))
        }
        if offersPeerReport {
            result.append(CYOptionSheetItem(
                id: .peerReport,
                title: appLocalized("im.chat.more.reportPeer", locale: locale),
                systemImage: "exclamationmark.bubble",
                isDanger: true,
                identifier: "im.chat.more.reportPeer"
            ))
        }
        return result
    }

    private func performPendingSelection() {
        guard let choice = pendingSelection else { return }
        pendingSelection = nil
        switch choice {
        case .poll:
            createPoll?()
        case .safety(let item):
            select(item)
        case .peerReport:
            // MP `doReportPeer`: the peer is the sender of the latest message that is not mine; none → toast
            // 对方还没发过消息，暂不能举报. Then the shared MEMBER report sheet (index.wxml:250).
            if let peer = messages.last(where: { ($0.senderID ?? 0) > 0 && $0.senderID != accountID })?.senderID {
                peerReportMemberID = peer
                showPeerReport = true
            } else {
                peerReportClosed = true
            }
        }
    }

    private func granted(_ item: IMSafetyMenu.Item) -> Bool {
        switch item {
        case .report: return owner.permits(.report(conversationID: conversationID, messageID: 1))
        case .block: return owner.permits(.block(conversationID: conversationID, targetMemberID: 1))
        case .unblock: return owner.permits(.unblock(conversationID: conversationID, targetMemberID: 1))
        case .hide: return owner.permits(.hide(conversationID: conversationID))
        }
    }
    private func select(_ item: IMSafetyMenu.Item) {
        if case .outcomeUnknown = owner.visibleState { present(); return }
        switch item {
        case .report: owner.reviewReport(messages: messages); present()
        case .hide: if owner.review(.hide(conversationID: conversationID)) { present() }
        case .block, .unblock:
            present()
            Task { await owner.reviewBlock(unblock: item == .unblock) }
        }
    }
    private func titleString(_ item: IMSafetyMenu.Item) -> String {
        switch item {
        case .report: return appLocalized("im.chat.more.report", locale: locale)
        case .block: return appLocalized("im.chat.more.block", locale: locale)
        case .unblock: return appLocalized("im.chat.more.unblock", locale: locale)
        case .hide: return appLocalized("im.chat.more.hide", locale: locale)
        }
    }
    private func symbol(_ item: IMSafetyMenu.Item) -> String {
        switch item { case .report: return "exclamationmark.bubble"; case .block: return "hand.raised"; case .unblock: return "hand.raised.slash"; case .hide: return "eye.slash" }
    }
    private func identifier(_ item: IMSafetyMenu.Item) -> String {
        switch item { case .report: return "report"; case .block: return "block"; case .unblock: return "unblock"; case .hide: return "hide" }
    }
}

/// Unknown chat values render as an em dash. A blank server string is unknown, not zero.
private enum ChatGrouping {
    /// Consecutive messages from one sender form a run: first / middle / last.
    static func positions(_ messages: [MessagingMessage]) -> [Int: ChatGroupPosition] {
        var out: [Int: ChatGroupPosition] = [:]
        for (i, m) in messages.enumerated() {
            let prev = i > 0 && messages[i - 1].senderID == m.senderID
            let next = i + 1 < messages.count && messages[i + 1].senderID == m.senderID
            out[m.id] = prev ? (next ? .middle : .last) : (next ? .first : .single)
        }
        return out
    }
}

private enum ChatDisplay {
    static let unknown = "—"
    static func stamp(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? unknown : trimmed
    }
}

/// Layout-shaped loading. The visible label keeps the existing localization key.
private struct ChatHistoryLoading: View {
    let labelKey: LocalizedStringKey
    let identifier: String
    var fills = true
    var body: some View {
        if fills {
            row.frame(maxHeight: .infinity, alignment: .top)
        } else {
            row
        }
    }
    private var row: some View {
        ProgressView(labelKey)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .top)
            .accessibilityIdentifier(identifier)
    }
}

/// Empty transcript. Title and hint keys stay; the hint is the second line.
private struct ChatHistoryEmpty: View {
    let hint: LocalizedStringKey
    var body: some View {
        ContentUnavailableView {
            Label("messaging.history.empty", systemImage: "tray")
        } description: {
            Text(hint)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("messaging.history.empty")
    }
}

/// IMChatSessionPhase.unknown: the read answered, but the page cannot prove the chat is empty.
/// The "load earlier" row above stays the way forward; nothing is shown as zero.
private struct ChatHistoryUnknown: View {
    var body: some View {
        ContentUnavailableView {
            Label("im.chat.unknown.title", systemImage: "questionmark.bubble")
        } description: {
            Text("im.chat.unknown.hint")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(IMChatSessionPage.unknownAccessibilityIdentifier)
    }
}

/// Issue copy stays on the existing keys. Retry is secondary so a closed chat has one primary.
/// mp-states r3 (MP im/chat wxml:39-42): a closed or refused chat reads 这个组局已结束 / 这个会话无法打开 with
/// 返回消息列表 and no sub line; a missing link gets 返回; a failed read keeps 消息加载失败 · reason · 重试.
private struct ChatHistoryStatus: View {
    let issue: MessagingLoadIssue
    let identifier: String
    let retry: () -> Void
    @Environment(\.dismiss) private var dismiss
    private var titleKey: String {
        issue.titleKey == "messaging.accessDenied" ? "im.chat.denied" : issue.titleKey
    }
    private var backKey: String? {
        switch issue.titleKey {
        case "messaging.closed", "messaging.accessDenied": return "im.chat.backToList"
        case "messaging.missing": return "action.back"
        default: return nil
        }
    }
    var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey(titleKey), systemImage: issue.canRetry ? "exclamationmark.triangle" : "lock")
        } description: {
            if let message = issue.message {
                Text(verbatim: message)
            } else if backKey == nil {
                Text(LocalizedStringKey(issue.detailKey))
            }
        } actions: {
            if issue.canRetry {
                Button("messaging.retry", action: retry)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier(identifier + ".retry")
            } else if let backKey {
                Button(LocalizedStringKey(backKey)) { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier(identifier + ".back")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

/// Same safety owner calls as the shared review sheet. The reviewing step is the native `MemberConfirmSheet`.
@MainActor private struct ChatSafetySheet: View {
    @StateObject private var model: IMSafetyModel
    let onSettled: (IMSafetyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var task: Task<Void, Never>?

    init(owner: IMSafetyCoordinator, onSettled: @escaping (IMSafetyAction) -> Void) {
        _model = StateObject(wrappedValue: IMSafetyModel(owner: owner))
        self.onSettled = onSettled
    }

    var body: some View {
        Group {
            if case .reviewing(let action) = model.state {
                reviewing(action)
            } else {
                statusForm
            }
        }
        .themeDomain(.player)
        .accessibilityIdentifier("im.safety.sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isInFlight)
        .onDisappear {
            if case .acknowledged(let action) = model.state { onSettled(action) }
            model.owner.cancelReview()
        }
    }

    private var isInFlight: Bool {
        switch model.state { case .submitting, .verifying, .resolving: return true; default: return false }
    }

    private func reviewing(_ action: IMSafetyAction) -> some View {
        let copy = IMSafetyCopy(action)
        let extraKeys: [String] = switch action {
        case .unblock: ["im.safety.unblock.c1", "im.safety.unblock.c2"]
        case .report, .reportWithReason: ["im.safety.report.c1"]
        default: []
        }
        let allKeys = copy.consequenceKeys + extraKeys
        let consequences = Array(allKeys.enumerated()).map { index, key in
            CYConfirmConsequence(
                systemImage: (confirmsDestructively(action) && index == allKeys.count - 1) ? "exclamationmark.triangle" : "info.circle",
                text: appLocalized(String.LocalizationValue(key), locale: locale)
            )
        }
        return MemberConfirmSheet(
            title: appLocalized(String.LocalizationValue(copy.titleKey), locale: locale),
            message: confirmationMessage(copy),
            confirmTitle: appLocalized(String.LocalizationValue(copy.confirmKey), locale: locale),
            isDestructive: confirmsDestructively(action),
            confirmIdentifier: "im.safety." + "confirm",
            cancelIdentifier: "im.safety." + "cancel",
            titleIdentifier: "im.safety." + "reviewTitle",
            consequences: consequences,
            onCancel: { dismiss() }
        ) {
            run { await model.owner.confirm() }
        }
    }

    /// Every non-review state stays reachable. Confirm, retry, and verify still call the owner.
    private var statusForm: some View {
        NavigationStack {
            Form { statusContent }
                .navigationTitle(Text("im.safety.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.close") { dismiss() }
                            .disabled(isInFlight)
                            .accessibilityIdentifier("im.safety.close")
                    }
                }
        }
    }

    @ViewBuilder private var statusContent: some View {
        switch model.state {
        case .idle:
            Text("im.safety.idle").accessibilityIdentifier("im.safety.idle")
        case .resolving:
            ProgressView("im.safety.resolving").accessibilityIdentifier("im.safety.resolving")
        case .unavailable(let message):
            Section {
                Label("im.safety.unavailable", systemImage: "exclamationmark.circle").accessibilityIdentifier("im.safety.unavailable")
                if let message, !message.isEmpty { Text(verbatim: message) }
            }
        case .reviewing(_):
            EmptyView()
        case .submitting:
            ProgressView("im.safety.submitting").accessibilityIdentifier("im.safety.submitting")
        case .verifying:
            ProgressView("im.safety.verifying").accessibilityIdentifier("im.safety.verifying")
        case .acknowledged(let action):
            let copy = IMSafetyCopy(action)
            Section {
                Label(LocalizedStringKey(copy.doneKey), systemImage: "checkmark.circle").accessibilityIdentifier("im.safety.done")
                if let key = copy.doneDetailKey { Text(LocalizedStringKey(key)) }
            }
            Button("action.close") { dismiss() }.accessibilityIdentifier("im.safety.doneClose")
        case .rejected(let action, let message):
            Section {
                Label(LocalizedStringKey(IMSafetyCopy(action).failureKey), systemImage: "xmark.octagon").accessibilityIdentifier("im.safety.rejected")
                if let message, !message.isEmpty { Text(verbatim: message) }
                Button("im.safety.retrySame") { run { await model.owner.retryUnchanged() } }.accessibilityIdentifier("im.safety.retry")
            }
        case .outcomeUnknown(let action):
            Section {
                Label("im.safety.unknown", systemImage: "questionmark.circle").accessibilityIdentifier("im.safety.unknown")
                if case .report = action {
                    Text("im.safety.unknownReport")
                } else if case .reportWithReason = action {
                    Text("im.safety.unknownReport")
                } else {
                    Text("im.safety.unknownHint")
                    Button("im.safety.verify") { run { await model.owner.verify() } }.accessibilityIdentifier("im.safety.verify")
                }
                Button("im.safety.retrySame") { run { await model.owner.retryUnchanged() } }.accessibilityIdentifier("im.safety.retry")
            }
        case .notApplied:
            Section {
                Label("im.safety.notApplied", systemImage: "arrow.uturn.backward.circle").accessibilityIdentifier("im.safety.notApplied")
                Button("im.safety.retrySame") { run { await model.owner.retryUnchanged() } }.accessibilityIdentifier("im.safety.retry")
            }
        }
    }

    private func confirmationMessage(_ copy: IMSafetyCopy) -> String {
        var lines: [String] = []
        if let key = copy.contentKey {
            lines.append(appLocalized(String.LocalizationValue(key), locale: locale))
        }
        for key in copy.consequenceKeys {
            lines.append(appLocalized(String.LocalizationValue(key), locale: locale))
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? ChatDisplay.unknown : text
    }

    /// Hide and block stay destructive. Report and unblock keep one primary confirm.
    private func confirmsDestructively(_ action: IMSafetyAction) -> Bool {
        switch action {
        case .hide, .block: return true
        case .report, .reportWithReason, .unblock: return false
        }
    }

    private func run(_ body: @escaping @MainActor () async -> Void) {
        guard task == nil else { return }
        task = Task { @MainActor in await body(); task = nil }
    }
}

/// mp-states r3: MP `subpackageB/pages/im/chat/index.wxml:31` cy-inline-error load-failure
/// 更早消息没有加载 · sub loadMoreError · 重试.
private struct ChatEarlierFailure: View {
    let issue: MessagingLoadIssue
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label("messaging.earlierFailed", systemImage: "wifi.exclamationmark")
                .font(.headline)
                .foregroundStyle(.primary)
            detail
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Text("messaging.retry")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("messaging.history.earlier")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.md)
        .background(.background.secondary, in: .rect(cornerRadius: CYRadius.inner))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("messaging.history.earlierError")
    }

    @ViewBuilder private var detail: some View {
        if let message = issue.message {
            Text(verbatim: message)
        } else {
            Text(LocalizedStringKey(issue.detailKey))
        }
    }
}
