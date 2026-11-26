import SwiftUI

@MainActor struct NativeChannelHistoryView: View {
    @State var model: NativeChannelHistoryModel
    var makeTextCoordinator: ((NativeChannelHistoryModel) -> NativeChannelTextCoordinator?)? = nil
    var makePageActions: ((NativeChannelHistoryModel, NativeChannelTextCoordinator) -> ChannelPageActions?)? = nil
    @State private var textCoordinator: NativeChannelTextCoordinator?
    @State private var channelActions: ChannelPageActions?
    @State private var selectedMessageID: Int?
    @State private var presentsMessage = false
    var mediaReader: (any SocialMessageMediaReading)? = nil
    var expanded: IMExpandedNavigationContext? = nil
    var messageContent: ((MessagingMessage) -> AnyView)? = nil
    var messageVisibility: ((MessagingMessage) -> Bool)? = nil
    var acknowledgementControls: (([MessagingMessage]) -> AnyView)? = nil
    var retainWhileCovered: () -> Bool = { false }
    /// The host's channel tools, shown as the composer's leading `+`.
    var composerAccessory: AnyView? = nil
    @State private var revision = 0
    @State private var task: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var liveRefreshPending = false
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40
    var body: some View {
        let _ = revision
        Group {
            if !model.isCurrent {
                MessagingIssueView(issue: .init(APIError.notConfigured), identifier: "channel.history.unavailable", retry: {})
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    if let error = model.issue {
                        Section {
                            if let operation = model.failedOperation, case .read = operation {
                                Text("channel.receiptUnknown", tableName: "NativeChannel").font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            MessagingIssueView(issue: .init(error), identifier: "channel.history.error") {
                                run(.retry)
                            }
                        }
                    }
                    if model.history.older.hasMore {
                        Button { run(.older) } label: { Text("channel.older", tableName: "NativeChannel").frame(maxWidth: .infinity) }
                            .disabled(model.isLoading).accessibilityIdentifier("channel.history.older")
                            .listRowSeparator(.hidden)
                    }
                    if model.loaded && renderedMessages.isEmpty && !model.isLoading {
                        ContentUnavailableView {
                            Label { Text("channel.noMessages", tableName: "NativeChannel") } icon: { Image(systemName: "bubble.left.and.bubble.right") }
                        }
                        .listRowSeparator(.hidden)
                    }
                    // Same row rules as direct chat: grouped time, avatar and name on received rows only.
                    let dividers = IMInboxTime.dividers(for: renderedMessages, now: Date())
                    ForEach(renderedMessages) { message in
                        let isOwn = message.senderID == model.client.identity?.accountID
                        VStack(spacing: 8) {
                            if let divider = dividers[message.id] {
                                IMChatDividerLabel(divider: divider).font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                            // G-023 (design P1): a tap no longer pushes a page. Like Messages, the bubble's actions live in
                            // its context menu (touch and hold) and in the VoiceOver actions rotor; 详情 opens the same
                            // message detail page as before.
                            HStack(alignment: .bottom, spacing: 8) {
                                if !isOwn {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: avatarSize, height: avatarSize)
                                        .accessibilityHidden(true)
                                }
                                ChatMessageBubble(isOwn: isOwn) {
                                    if !isOwn {
                                        MessagingSenderName(message: message, conversation: model.conversation,
                                                            accountID: model.client.identity?.accountID ?? 0)
                                    }
                                } content: {
                                    if let messageContent { messageContent(message) }
                                    else { MessagingMessageContent(message: message) }
                                }
                            }
                            .contextMenu { messageMenu(message) }
                            .accessibilityElement(children: .contain)
                            .accessibilityAction(named: Text("channel.message.details")) { openDetails(message.id) }
                            .accessibilityIdentifier("channel.message.\(message.id)")
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    if model.loaded {
                        // Only paging through a newer backlog is a button; fresh messages come with pull to refresh.
                        if model.client.canLoadNewer && model.history.hasMoreNewer {
                            Button { run(.newer) } label: { Text("channel.moreNewer", tableName: "NativeChannel").frame(maxWidth: .infinity) }
                                .disabled(model.isLoading).accessibilityIdentifier("channel.history.newer")
                                .listRowSeparator(.hidden)
                        }
                        if acknowledgementControls == nil, model.client.canReadThrough {
                            Button {
                                if let last = renderedMessages.last?.id { model.observed(last) }
                                run(.markSeen)
                            } label: { Text("channel.markSeen", tableName: "NativeChannel").frame(maxWidth: .infinity) }
                            .disabled(model.isLoading || renderedMessages.isEmpty)
                            .accessibilityIdentifier("channel.history.markSeen")
                            .listRowSeparator(.hidden)
                        }
                    }
                    if let acknowledgementControls { acknowledgementControls(renderedMessages).listRowSeparator(.hidden) }
                    if let receipt = model.receipt {
                        LabeledContent {
                            Text(receipt.unread, format: .number).monospacedDigit()
                        } label: { Text("channel.unreadRemaining", tableName: "NativeChannel") }
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("channel.history.readResult")
                            .listRowSeparator(.hidden)
                    }
                    if model.isLoading && renderedMessages.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("messaging.loading"))
                            .listRowSeparator(.hidden)
                    } else if model.isLoading {
                        ProgressView("messaging.loading").frame(maxWidth: .infinity).listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .animation(reduceMotion ? nil : .default, value: renderedMessages.map(\.id))
                // Few messages sit just above the composer and grow upward, as in direct chat.
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .cyText(.body)
        .navigationDestination(isPresented: $presentsMessage) {
            if let selectedMessageID, let message = currentMessage(selectedMessageID) {
                MessagingMessageDetailView(message: message, conversation: model.conversation,
                    reader: model.client.history, identity: model.client.identity,
                    mediaReader: mediaReader, expanded: expanded,
                    currentMessage: { currentMessage(selectedMessageID) })
            } else {
                MessagingIssueView(issue: .init(APIError.notConfigured), identifier: "channel.message.unavailable", retry: {})
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let textCoordinator {
                NativeChannelTextComposer(coordinator: textCoordinator, historyReady: historyReady,
                    onReturnToHistory: { run(.load) }, onReturnToDirectory: { dismiss() },
                    accessory: composerAccessory)
            } else if model.isCurrent, let composerAccessory {
                // No text composer: the `+` still sits where the composer would be.
                HStack { composerAccessory; Spacer(minLength: 0) }
                    .padding(.horizontal).padding(.vertical, 8).background(.bar)
            }
        }
        .navigationTitle(Text("channel.history", tableName: "NativeChannel"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Two-line title like Messages: page name over the conversation name.
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("channel.history", tableName: "NativeChannel").font(.headline)
                    if model.isCurrent {
                        MessagingConversationName(conversation: model.conversation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
        }
        // Pull to refresh replaces the toolbar refresh button; the same guarded run path loads.
        .refreshable {
            guard model.isCurrent else { return }
            run(.load)
            await task?.value
        }
        .onAppear {
            model.onChange = { revision += 1; prepareTextCoordinator() }
            model.activate()
            prepareTextCoordinator()
            if model.failedOperation == nil { run(.load) }
        }
        .onDisappear {
            task?.cancel(); task = nil; textCoordinator?.stop()
            if !retainWhileCovered() { model.stop(); model.onChange = nil }
        }
        // G-021 (design P1): no realtime transport exists, so the screen reads its next page when new messages are
        // announced (an IM push while the app is open) and when the app returns to the foreground. Same guarded
        // `.newer` / `.load` read as the buttons and pull to refresh; no timer, no polling.
        .onReceive(NotificationCenter.default.publisher(for: MPNotificationTapRouter.foregroundMessageArrived)) { _ in
            refreshLive()
        }
        .onChange(of: scenePhase) { old, phase in
            if old == .background, phase == .active { refreshLive() }
        }
        .onChange(of: renderedMessages.last?.id) { old, new in
            // New messages at the bottom are announced, as Messages does; the first load is not.
            guard let old, let new, new != old, liveRefreshPending else { return }
            liveRefreshPending = false
            AccessibilityNotification.Announcement(appLocalized("channel.live.newMessages", locale: locale)).post()
        }
        .onChange(of: model.client.identity) { _, _ in task?.cancel(); textCoordinator?.accessInvalidated(); model.stop(); revision += 1 }
        .onChange(of: model.client.isConfigured) { _, available in
            if !available { task?.cancel(); textCoordinator?.accessInvalidated(); model.stop(); revision += 1 }
        }
        .privacySensitive()
    }
    // A verified hidden receipt is a monotonic veto, never a second history source.
    // Read the observable veto here and in detail closures, including open child sheets.
    private var renderedMessages: [MessagingMessage] {
        model.visibleMessages.filter { ($0.status == .recalled || textCoordinator?.isMessageWithheld($0.id) != true) && messageVisibility?($0) != false }
    }
    private func currentMessage(_ id: Int) -> MessagingMessage? {
        guard let message = model.detailMessage(id), messageVisibility?(message) != false,
              message.status == .recalled || textCoordinator?.isMessageWithheld(id) != true else { return nil }
        return message
    }
    @ViewBuilder private func messageMenu(_ message: MessagingMessage) -> some View {
        if message.isPayloadVisible, message.type == 1, let text = message.content,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                LocalPasteboard.copy(text)
            } label: { Label("channel.message.copy", systemImage: "doc.on.doc") }
        }
        Button { openDetails(message.id) } label: { Label("channel.message.details", systemImage: "info.circle") }
    }
    private func openDetails(_ id: Int) {
        selectedMessageID = id; presentsMessage = true
    }
    /// A live trigger reads the newer page when the backlog supports it, else the latest page. Skipped while another
    /// read runs or before the first load; the model's own `prepare` guards identity and access.
    private func refreshLive() {
        guard model.isCurrent, model.loaded, !model.isLoading else { return }
        liveRefreshPending = true
        run(model.client.canLoadNewer ? .newer : .load)
    }
    private var historyReady: Bool { model.isCurrent && model.loaded && !model.isLoading && model.issue == nil }
    private func prepareTextCoordinator() {
        if model.issue as? APIError == .unauthorized { textCoordinator?.accessInvalidated() }
        // Match the history owner's status precedence. A transient HTTP failure
        // cannot permanently retire text recovery using stale envelope metadata.
        if let failure = model.issue as? MessagingReadFailure,
           (failure.httpStatus == nil || [400, 401, 403, 404, 409].contains(failure.httpStatus ?? 0)),
           failure.isForbidden || failure.isClosed || failure.isUnauthorized || failure.code == 404
            || failure.errorCode == "IM_CONVERSATION_CLOSED" {
            textCoordinator?.accessInvalidated()
        }
        guard historyReady, textCoordinator == nil else { return }
        textCoordinator = makeTextCoordinator?(model)
        if let textCoordinator {
            channelActions = makePageActions?(model, textCoordinator)
            channelActions?.appear()
        }
    }
    private func run(_ action: NativeChannelHistoryModel.Action) {
        let owner = model
        guard let prepared = owner.prepare(action) else { return }
        task?.cancel() // Retire an older queued tap before replacing the tracked Task.
        task = Task {
            guard model === owner else { return }
            await owner.perform(prepared)
        }
    }
}
