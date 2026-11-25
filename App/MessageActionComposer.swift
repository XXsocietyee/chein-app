import SwiftUI

/// A token is created by the visible button, never by its queued Task.
struct MessageComposerSubmission: Equatable {
    enum Operation: Equatable { case send(String), retry(String) }
    let id: UUID
    let appearance: UUID
    let identity: MessagingReadIdentity
    let operation: Operation
}

@MainActor final class MessageComposerModel: ObservableObject {
    @Published var draft = ""
    @Published private(set) var state: MessageSendState
    @Published private(set) var appearance: UUID?
    let coordinator: MessageActionCoordinator
    private var queued: MessageComposerSubmission?
    private var executing: MessageComposerSubmission?
    init(_ coordinator: MessageActionCoordinator) {
        self.coordinator = coordinator; state = coordinator.visibleState
    }
    func observe() {
        appearance = UUID()
        coordinator.onStateChange = { [weak self] in self?.update() }
        update()
    }
    func update() {
        state = coordinator.visibleState
        if state == .sending, let executing, appearance == executing.appearance,
           case .send = executing.operation { draft = "" }
    }
    /// Typing never waits for the history read, keyboard focus or the reply lease: those gate
    /// Send only. A field disabled while the first page loads drops what the user types (F-09).
    /// Only an owner that cannot take a new text (sending, unknown outcome, closed, another
    /// account, no writer) locks the field.
    var acceptsTyping: Bool {
        appearance != nil && coordinator.isConfigured && coordinator.isCurrentAccount
            && state != .sending && state != .outcomeUnknown && state != .closed
    }
    func retire() { appearance = nil; queued = nil; executing = nil; draft = "" }
    func invalidateQueued() { queued = nil }
    func prepare(_ operation: MessageComposerSubmission.Operation,
                 identity: MessagingReadIdentity?, canReply: Bool) -> MessageComposerSubmission? {
        guard let appearance, let identity, canReply, queued == nil, executing == nil,
              coordinator.isConfigured, coordinator.isCurrentAccount,
              identity.accountID == coordinator.accountID else { return nil }
        switch operation {
        case .send(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  state != .sending, state != .outcomeUnknown, state != .closed else { return nil }
        case .retry(let clientID):
            guard state == .outcomeUnknown || state == .rejected,
                  coordinator.pendingClientMessageID == clientID else { return nil }
        }
        let token = MessageComposerSubmission(id: UUID(), appearance: appearance,
            identity: identity, operation: operation)
        queued = token; return token
    }
    @discardableResult func perform(_ token: MessageComposerSubmission,
                                    canReply: () -> Bool) async -> Bool {
        guard queued == token else { return false }
        // Consume even a denied token. Restored authority needs a new user action.
        queued = nil
        guard appearance == token.appearance, !Task.isCancelled, canReply(),
              coordinator.isConfigured, coordinator.isCurrentAccount else { return false }
        executing = token
        defer { if executing == token { executing = nil } }
        let accepted: Bool
        switch token.operation {
        case .send(let text):
            accepted = await coordinator.sendNew(text, conversationReady: true, expectedIdentity: token.identity)
        case .retry(let clientID):
            guard coordinator.pendingClientMessageID == clientID else { return false }
            accepted = await coordinator.retry(conversationReady: true, expectedIdentity: token.identity)
        }
        guard appearance == token.appearance, executing == token, canReply(), !Task.isCancelled else { return false }
        if case .send(let text) = token.operation,
           coordinator.pendingText == text.trimmingCharacters(in: .whitespacesAndNewlines) { draft = "" }
        update(); return accepted
    }
}

@MainActor struct MessageActionComposer:View {
    @StateObject private var model:MessageComposerModel
    let identity:MessagingReadIdentity?
    let conversationReady:Bool
    let canReply: () -> Bool
    let onAcknowledged:(MessagingMessage)->Void
    /// The view's existing poll entry, shown as the leading `+` when the history offers it.
    let createPoll:(() -> Void)?
    /// R7-PC-D9-3 (MP im/chat composer `+`): 图片 / 位置 / 路线 open the host's existing send flows; 投票 stays `createPoll`.
    /// nil keeps the poll-only `+`.
    var attach:((IMComposerPlusItem) -> Void)? = nil
    /// Continuity (r1 item 9): the history's flight that carries the sent text into its bubble. nil keeps the composer as before.
    let flight:IMSendFlight?
    @Environment(\.themeDomain) private var domain
    @QuestifyReduceMotion private var reduceMotion
    /// Never launched: stands in for `flight` when the host passes none, so the slot below always has one to observe.
    @StateObject private var idleFlight = IMSendFlight()
    @Environment(\.locale) private var locale
    @State private var confirmsRetry=false
    @FocusState private var typing:Bool
    init(coordinator:MessageActionCoordinator,identity:MessagingReadIdentity?,conversationReady:Bool,
         canReply: @escaping () -> Bool = { true },
         createPoll: (() -> Void)? = nil,
         flight: IMSendFlight? = nil,
         attach: ((IMComposerPlusItem) -> Void)? = nil,
         onAcknowledged:@escaping (MessagingMessage)->Void) {
        self.createPoll=createPoll;self.flight=flight;self.attach=attach
        _model=StateObject(wrappedValue:MessageComposerModel(coordinator))
        self.identity=identity;self.conversationReady=conversationReady;self.canReply=canReply;self.onAcknowledged=onAcknowledged
    }
    private var ready:Bool { conversationReady && canReply() && model.appearance != nil && model.coordinator.isConfigured && model.coordinator.isCurrentAccount }
    private var canCompose:Bool {
        ready && model.state != .sending && model.state != .outcomeUnknown && model.state != .closed
    }
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            switch model.state {
            // Sending and the receipt stay in place: the spinner is the send button itself and the receipt sits in the
            // empty field, so the composer never grows a status row (continuity r1: no toast).
            case .sending: EmptyView()
            case .outcomeUnknown,.rejected:
                Text(LocalizedStringKey(model.state == .outcomeUnknown ? "message.send.unknown" : "message.send.rejected"))
                    .cyText(.bodyCompact).accessibilityIdentifier("message.send.issue")
                if let row = RequestReferenceRow(pathFragment: "/api/im/") { row }
                if let text=model.coordinator.pendingText { Text(verbatim:text).cyText(.bodyCompact).lineLimit(3) }
                Button("message.send.retry") { confirmsRetry=true }.disabled(!ready)
                    .accessibilityIdentifier("message.send.retry")
            case .closed: Text("message.send.closed").cyText(.bodyCompact)
            case .acknowledged: EmptyView()
            case .idle: EmptyView()
            }
            // `+` on the left, then a rounded field with the send control inside it.
            HStack(alignment:.bottom,spacing:Theme.Space.s2) {
                if let attach {
                    Menu {
                        ForEach(IMComposerPlusItem.allCases) { item in
                            if item != .poll || createPoll != nil {
                                Button {
                                    if item == .poll { createPoll?() } else { attach(item) }
                                } label: {
                                    Label(LocalizedStringKey("im.composer.plus." + item.rawValue), systemImage: item.systemImage)
                                }
                                .accessibilityIdentifier("im.composer.plus." + item.rawValue)
                            }
                        }
                    } label: {
                        Label("im.composer.plus", systemImage: "plus").labelStyle(.iconOnly)
                            .cyText(.sectionTitle, weight: .medium).frame(minWidth:44,minHeight:44).contentShape(Rectangle())
                    }
                    .disabled(!canCompose)
                    .accessibilityIdentifier("im.composer.plus")
                } else if let createPoll {
                    Button(action: createPoll) {
                        Label("poll.create",systemImage:"plus").labelStyle(.iconOnly)
                            .cyText(.sectionTitle, weight: .medium).frame(minWidth:44,minHeight:44).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("poll.createEntry")
                }
                HStack(alignment:.bottom,spacing:4) {
                    ZStack(alignment:.topLeading) {
                        TextField("message.send.placeholder",text:$model.draft,axis:.vertical)
                            .lineLimit(1...5).textFieldStyle(.plain).padding(.vertical,11).padding(.leading,16).padding(.trailing,0).focused($typing).disabled(!model.acceptsTyping)
                            .accessibilityIdentifier("message.send.input")
                        MessageComposerFieldSlot(flight: flight ?? idleFlight, fieldIsEmpty: model.draft.isEmpty,
                            showsReceipt: model.state.isAcknowledged && !typing, fill: Theme.Color.bgRaised(in:domain))
                    }
                    .cyAnimation(.easeInOut(duration:CYMotion.Duration.quick),value:model.state == .sending)
                    let draftIsEmpty = model.draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
                    Button {
                        typing=false
                        guard let token = model.prepare(.send(model.draft), identity: identity, canReply: ready) else { return }
                        flight?.launch(model.draft)
                        let flight = flight
                        Task {
                            let accepted = await model.perform(token, canReply: { ready })
                            if !accepted { flight?.cancel() }
                        }
                    } label: {
                        let live = !(draftIsEmpty || !canCompose)
                        let sending = model.state == .sending
                        // The button itself morphs: the arrow scales down and blurs out as a spinner scales in on the
                        // same accent circle, then reverses when the send settles.
                        let filled = live || sending
                        ZStack {
                            Label("message.send.button",systemImage:"arrow.up").labelStyle(.iconOnly)
                                .cyText(.bodyMedium)
                                .opacity(sending ? 0 : 1)
                                .scaleEffect(sending && !reduceMotion ? 0.25 : 1)
                                .blur(radius: sending && !reduceMotion ? 4 : 0)
                            ProgressView().controlSize(.small).tint(CYChat.onSent)
                                .opacity(sending ? 1 : 0)
                                .scaleEffect(sending || reduceMotion ? 1 : 0.25)
                                .blur(radius: sending || reduceMotion ? 0 : 4)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(filled ? CYChat.onSent : Color.secondary)
                        .frame(width:32,height:32)
                        // Quiet grey while there is nothing to send; the accent fills in with text and holds while sending.
                        .background(filled ? CYChat.sent : Color.secondary.opacity(0.25),in:Circle())
                        .frame(minWidth:44,minHeight:44).contentShape(Rectangle())
                        .animation(.snappy(duration:0.2),value:live)
                        .cyAnimation(CYMotion.standard,value:sending)
                    }
                    // The arrow is transparent while sending, so the button names itself rather than reading its label.
                    .accessibilityLabel(Text("message.send.button"))
                    .accessibilityValue(model.state == .sending ? Text("message.send.sending") : Text(verbatim:""))
                    .sensoryFeedback(.impact(weight:.light),trigger:model.draft.isEmpty)
                    .buttonStyle(.borderless)
                    .disabled(!canCompose || draftIsEmpty)
                    .accessibilityIdentifier("message.send.button")
                }
                .frame(minHeight:44)
                .background(Theme.Color.bgRaised(in:domain),in:RoundedRectangle(cornerRadius: CYRadius.card, style:.continuous))
            }
            if !conversationReady { Text("message.send.historyRequired").cyText(.meta).foregroundStyle(.secondary) }
        }
        // Same surface as the page, so the composer doesn't read as a separate band.
        .padding(.horizontal,Theme.Space.pageX).padding(.vertical,Theme.Space.s2).background(.background).privacySensitive()
        // No keyboard toolbar: on iOS 26+ its floating 完成 pill sits on top of the send arrow (F-10).
        // The host pins this composer with `.safeAreaInset(edge: .bottom)`, so it rides above the
        // keyboard; the transcript's `.scrollDismissesKeyboard(.interactively)` and Send itself
        // dismiss the keyboard.
        .onAppear { model.observe() }
        .onChange(of:model.state) { _,state in
            // The currently visible history owns readback, even after dismiss/reopen.
            if ready, case .acknowledged(let receipt)=state { onAcknowledged(receipt) }
        }
        .onChange(of:identity) { _,_ in let visible = model.appearance != nil; model.retire(); model.draft="";confirmsRetry=false; if visible { model.observe() } }
        .onChange(of:canReply()) { _, allowed in if !allowed { model.invalidateQueued(); confirmsRetry=false } }
        .onChange(of:model.state) { _,state in
            // A send that does not land here (rejected, unknown, closed, or acknowledged while this history is not
            // ready) drops its ghost; the issue row keeps showing the pending text as before.
            switch state {
            case .sending: break
            case .acknowledged: if !ready { flight?.cancel() }
            default: flight?.cancel()
            }
        }
        .onDisappear { model.retire(); confirmsRetry=false; typing=false }
        .onDisappear { flight?.cancel() }
        .sheet(isPresented: $confirmsRetry) {
            CYConfirmSheet(
                title: appLocalized("message.send.retryTitle", locale: locale),
                message: appLocalized("message.send.retryHint", locale: locale),
                confirmTitle: appLocalized("message.send.retry", locale: locale)
            ) {
                guard let clientID = model.coordinator.pendingClientMessageID,
                      let token = model.prepare(.retry(clientID), identity: identity, canReply: ready) else { return }
                Task { await model.perform(token, canReply: { ready }) }
            }
            .cyDomainSheet(detents: [.peek, .half])
        }
    }
}

private extension MessageSendState {
    var isAcknowledged: Bool { if case .acknowledged = self { return true } else { return false } }
}

/// The empty field's overlay: the sent text while it travels to its bubble, then the server receipt in place of a
/// status row. Observes the flight so the ghost leaves in the same transaction that inserts the bubble.
private struct MessageComposerFieldSlot: View {
    @ObservedObject var flight: IMSendFlight
    let fieldIsEmpty: Bool
    let showsReceipt: Bool
    let fill: Color
    var body: some View {
        if let ghost = flight.ghost, fieldIsEmpty {
            IMSendGhost(text: ghost, key: flight.ghostKey, namespace: flight.namespace, fill: fill)
        } else if showsReceipt, fieldIsEmpty {
            MessageComposerReceipt(fill: fill)
        }
    }
}

/// Server receipt, not a read receipt. Same words and identifier as the former status row. Its ground is opaque from
/// the first frame (the field's placeholder never shows through); only the words fade in, from the middle of the
/// bubble's move (end-only content). It leaves at once when typing starts.
private struct MessageComposerReceipt: View {
    let fill: Color
    @State private var wordsIn = false
    var body: some View {
        Text("message.send.accepted").cyText(.bodyCompact).foregroundStyle(.secondary)
            .opacity(wordsIn ? 1 : 0)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 11).padding(.leading, 16).padding(.trailing, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityIdentifier("message.send.receipt")
            .transition(.asymmetric(insertion: .identity,
                                    removal: AnyTransition.opacity.animation(.easeOut(duration: CYMotion.Duration.instant))))
            .onAppear {
                withAnimation(.easeOut(duration: CYMotion.Duration.quick).delay(CYMotion.Duration.standard * 0.5)) { wordsIn = true }
            }
    }
}
