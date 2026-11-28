import SwiftUI

@MainActor struct ShopNPCView: View {
    @Bindable var coordinator: ShopNPCCoordinator
    let name: String
    let greeting: String?
    var capture: (any ShopNPCVoiceCapturing)? = nil
    var scriptedGuide: ShopNPCScriptedGuideSource? = nil
    /// WP-07: AI identity is always disclosed on this screen; the shop NPC is a public merchant NPC.
    var safetyPolicy: SafetyDisclosurePolicy? = ShopNPCView.defaultSafetyPolicy
    static let defaultSafetyPolicy = SafetyDisclosurePolicy(surface: .publicMerchantNPC)
    @State private var draft = ""
    @State private var revision = 0
    @State private var recording = false
    @State private var localFailure: ShopNPCFailure?
    // W09.5/W09.6: confirmation bound to exact text + request + account/session scope; memory only.
    @State private var sendGate = AIOutgoingSendGate<ShopNPCScope, UUID?>()
    @State private var sensitiveFindings: Set<AIOutgoingSensitiveKind> = []
    @State private var pendingSend: (current: () -> (String, UUID?)?, run: () -> Void)?
    /// fix/1128c: on-device read-aloud of the reviewed reply text (voice out).
    @State private var voice = AIVoiceOut()
    @FocusState private var typing: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    private var sending: Bool { coordinator.busy }
    private var aiBadge: String { AIStoryContent.text(.npcAIBadge, locale: locale) }
    private var fallbackGreeting: String { AIStoryContent.text(.npcFallbackGreeting, locale: locale) }
    private var showsConversation: Bool { coordinator.active && !coordinator.isSuspended }
    private var canCompose: Bool {
        showsConversation && coordinator.grants.textAllowed && !sending && !recording && coordinator.pending == nil
    }
    var body: some View {
        let _ = revision
        VStack(spacing: 0) {
            // The identity/disclosure stays visible when the transcript scrolls.
            VStack(alignment: .leading, spacing: 4) {
                if showsConversation {
                    HStack(spacing: CYSpacing.md) {
                        AINPCPresenceAvatar(name: name, active: sending || voice.speakingID != nil)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: name).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                            HStack(spacing: CYSpacing.xs) {
                                // fix/1128c: the identity line comes from the owner's script file (Resources/Story).
                                if !aiBadge.isEmpty { CYStatusChip(verbatim: aiBadge, tone: .info, systemImage: "sparkles") }
                                if let relation = coordinator.relation {
                                    CYStatusChip(
                                        LocalizedStringKey("journey.record.relation." + relation.state.rawValue),
                                        tone: relationTone(relation.state),
                                        systemImage: relationSymbol(relation.state)
                                    )
                                    .accessibilityIdentifier("shopNPCRelationBadge.\(relation.state.rawValue)")
                                }
                            }
                        }
                    }.accessibilityElement(children: .combine)
                }
                else if coordinator.isSuspended { Text("shopNPC.paused") }
                else { Text("shopNPC.stale") }
                Text("shopNPC.disclosure").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                SafetyDisclosureBanner(policy: safetyPolicy)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, CYSpacing.lg).padding(.vertical, 8)
            Divider().overlay(CYColor.borderSubtle)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if coordinator.isSuspended { interruptionPanel }
                        if showsConversation {
                            if let scriptedGuide {
                                ShopNPCScriptedGuideView(source: scriptedGuide, coordinator: coordinator, returnToNode: { dismiss() })
                            }
                            if let greeting, !greeting.isEmpty { NPCChatBubble(name: name, isOwn: false) { Text(verbatim: greeting) } }
                            if (greeting ?? "").isEmpty, coordinator.messages.isEmpty, coordinator.grants.textAllowed, !fallbackGreeting.isEmpty {
                                NPCChatBubble(name: name, isOwn: false) { Text(verbatim: fallbackGreeting) }
                            }
                            if !coordinator.grants.textAllowed { Text("shopNPC.disabled").accessibilityIdentifier("shopNPC.disabled") }
                            ForEach(coordinator.messages) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    NPCChatBubble(name: name, isOwn: message.mine) {
                                        if message.voiceTranscriptMissing {
                                            Text("shopNPCQuestionReuse.noTranscript")
                                        } else if message.mine {
                                            Text(verbatim: message.text).textSelection(.enabled)
                                        } else {
                                            AITypingRevealText(text: message.text, animates: message.id == coordinator.messages.last?.id)
                                        }
                                    }
                                    if message.mine, message.source == .voice {
                                        if message.voiceTranscriptMissing { Text("shopNPCQuestionReuse.transcriptUnavailable").font(.footnote).foregroundStyle(.secondary) }
                                    }
                                    if message.hasReusableQuestion {
                                        ShopNPCQuestionReuseButton(coordinator: coordinator, messageID: message.id, draft: $draft, enabled: canCompose)
                                    }
                                    if !message.mine {
                                        if !message.effects.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: CYSpacing.xs) {
                                                    ForEach(message.effects) { effect in
                                                        CYStatusChip(
                                                            verbatim: effectChipText(effect),
                                                            tone: effectTone(effect),
                                                            systemImage: effectSymbol(effect)
                                                        )
                                                        .accessibilityIdentifier("shopNPCEffectReceipt.\(effect.key)")
                                                    }
                                                }
                                            }
                                        }
                                        AIReadAloudButton(id: message.id.uuidString, text: message.text, voice: voice)
                                        Button { typing = false; attempt { try coordinator.reviewRegeneration(answerID: message.id) } } label: {
                                            Label("shopNPC.regenerate", systemImage: "arrow.clockwise").cyText(.label).frame(minHeight: 44).contentShape(Rectangle())
                                        }.buttonStyle(.plain).foregroundStyle(CYColor.textSecondary)
                                            .disabled(recording || !coordinator.canRegenerate(answerID: message.id))
                                            .accessibilityIdentifier("shopNPC.regenerate")
                                    }
                                }.accessibilityElement(children: .contain)
                            }
                            if let notice = coordinator.serviceNotice {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("shopNPCOutcome.serviceNotice").font(.caption).foregroundStyle(.secondary)
                                    Text(verbatim: notice).textSelection(.enabled)
                                }.accessibilityIdentifier("shopNPCOutcome.serviceNotice")
                            }
                            if sending {
                                NPCChatBubble(name: name, isOwn: false) { NPCTypingDots() }
                                    .accessibilityElement(children: .ignore).accessibilityLabel(Text("shopNPC.busy"))
                                    .accessibilityIdentifier("shopNPC.busy")
                                Button("shopNPC.stopWaiting") { coordinator.stopWaiting(); localFailure = nil }
                                    .controlSize(.large).frame(minHeight: 44)
                                    .accessibilityIdentifier("shopNPC.stopWaiting")
                            }
                            if let review = coordinator.pending { reviewPanel(review).id("shopNPC.review") }
                        }
                        CYScreenOfflineWriteBanner(
                            routes: ["/api/ai/npc/chat"],
                            session: offlineWriteSession.session
                        )
                        if !coordinator.isSuspended, let error = localFailure ?? coordinator.failure {
                            Group {
                                if case .server(_, let message) = error, let message, !message.isEmpty { Text(verbatim: message) }
                                else { Text(LocalizedStringKey(error.key)) }
                            }.accessibilityIdentifier("shopNPC.error")
                        }
                        Text("shopNPC.voiceDisclosure").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        if dynamicTypeSize.isAccessibilitySize { composer }
                        Color.clear.frame(height: 1).id("referenceNPC.bottom").accessibilityHidden(true)
                    }.padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: coordinator.pending?.id) { _, id in
                    if id != nil { proxy.scrollTo("shopNPC.review", anchor: .top) }
                }
                .onChange(of: coordinator.messages.count) { _, _ in proxy.scrollTo("referenceNPC.bottom", anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !dynamicTypeSize.isAccessibilitySize { composer }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("action.done") { typing = false }.accessibilityIdentifier("shopNPC.keyboard.done")
            }
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .navigationTitle("shopNPC.title").navigationBarTitleDisplayMode(.inline).privacySensitive()
        .modifier(AIOutgoingSensitiveConfirmation(findings: $sensitiveFindings, send: confirmedSend, cancel: cancelSensitiveConfirmation))
        .onChange(of: draft) { _, _ in cancelSensitiveConfirmation() }
        .onDisappear { cancelSensitiveConfirmation(); voice.stop(); invalidate() }
        .onChange(of: coordinator.active) { _, active in if !active { clearTransient() } }
        .onChange(of: coordinator.scope) { _, _ in clearTransient() }
        .onChange(of: coordinator.grants) { _, _ in clearTransient() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { suspend() }
            else { coordinator.revalidateSuspension() }
        }
    }
    private var interruptionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("shopNPC.pauseNotice")
            Button("shopNPC.resume") { coordinator.resumeAfterInterruption(); localFailure = nil }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(scenePhase != .active).accessibilityIdentifier("shopNPC.resume")
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            NPCQuickQuestionBar(draft: $draft, context: .gameNode(coordinator.scope), enabled: canCompose)
            HStack(alignment: .bottom, spacing: 8) {
                voiceButton
                TextField("shopNPC.question", text: Binding(get: { showsConversation ? draft : "" }, set: { draft = $0 }), axis: .vertical)
                    .lineLimit(1...4).focused($typing)
                    .cyText(.body).foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 14).frame(minHeight: 52)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous).stroke(CYColor.borderSubtle, lineWidth: 1))
                    .disabled(!canCompose).accessibilityIdentifier("shopNPC.input")
                textReviewButton
            }
            if recording {
                Button { capture?.cancel(); recording = false } label: {
                    Text("shopNPC.discard").frame(minHeight: 44).contentShape(Rectangle())
                }
                    .accessibilityIdentifier("shopNPC.discard")
            }
        }.padding(.horizontal, CYSpacing.lg).padding(.top, 10).padding(.bottom, 8)
            .background(.bar) // native-r3-b: system bar material instead of a page colour + custom drop shadow.
    }
    private var textReviewButton: some View {
        let empty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button { typing = false; guardedSend(current: { (draft, nil) }) { attempt { try coordinator.reviewText(draft) } } } label: {
            Image(systemName: "arrow.up").cyText(.button)
                .frame(width: 44, height: 44)
                .foregroundStyle(empty || !canCompose ? CYColor.textDisabled : CYColor.textInverse)
                .background(empty || !canCompose ? CYColor.bgElevated : CYColor.textPrimary, in: Circle())
        }
            .disabled(!canCompose || empty)
            .accessibilityLabel(Text("shopNPC.reviewText"))
            .accessibilityIdentifier("shopNPC.reviewText")
    }
    private var voiceButton: some View {
        Button {
            typing = false
            attempt {
                guard let capture else { throw ShopNPCFailure.disabled }
                if recording { recording = false; try coordinator.reviewVoice(capture.stopForReview()) }
                else { try capture.startAfterExplicitMicrophoneIntent(grants: coordinator.grants, onEnded: { recording = false }); recording = true }
            }
        } label: {
            Image(systemName: recording ? "stop.fill" : "mic.fill").cyText(.button)
                .frame(width: 44, height: 44).foregroundStyle(CYColor.textPrimary)
                .background(CYColor.bgElevated, in: Circle())
        }
            .disabled(sending || coordinator.pending != nil || !showsConversation || capture == nil || !coordinator.grants.voiceAllowed || !coordinator.grants.microphone)
            .accessibilityLabel(Text(recording ? "shopNPC.stopReview" : "shopNPC.record"))
            .accessibilityIdentifier("shopNPC.record")
    }
    private func reviewPanel(_ review: ShopNPCReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("shopNPC.review").font(.headline).accessibilityAddTraits(.isHeader)
            switch review.content {
            case .text(let text): Text(verbatim: text).textSelection(.enabled)
            case .voice(let clip): Label { Text("shopNPC.voiceReview") } icon: { Image(systemName: "waveform") }
                Text(verbatim: "\(Int(clip.duration)) s").cyText(.numericBody).foregroundStyle(.secondary)
            }
            Text("shopNPC.transmissionDisclosure").font(.footnote)
            if coordinator.failure == .unknownOutcome || coordinator.failure == .malformed || coordinator.failure == .replyProcessing || coordinator.failure == .replyRetryable {
                Text("shopNPC.retryNotice").font(.footnote)
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                if coordinator.serverRetrySecondsRemaining > 0 {
                    LabeledContent("shopNPCOutcome.retrySeconds") { Text(verbatim: String(coordinator.serverRetrySecondsRemaining)) }
                        .accessibilityIdentifier("shopNPCOutcome.retrySeconds")
                }
                if coordinator.pendingIsTerminalServiceResponse {
                    Text("shopNPCOutcome.newQuestion").font(.footnote)
                } else if coordinator.pendingIsNonRetryableProcessing {
                    // An unresolved server response is not terminal and does not
                    // authorize retry. Cancel still abandons only this local review.
                    Text("merchantNPCRecovery.abandonConsequences").font(.footnote)
                        .accessibilityIdentifier("shopNPCOutcome.unresolved")
                } else {
                    Button {
                        typing = false; localFailure = nil
        guardedSend(current: { finalText(of: review) }) {
                        attempt {
                            let intent = try coordinator.prepareTransmission(reviewID: review.id)
                            Task {
                                guard scenePhase == .active, showsConversation, coordinator.scope == review.scope else { return }
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/ai/npc/chat"]
                                ) {
                                    await coordinator.transmit(reviewID: review.id, intent: intent)
                                }
                                guard showsConversation, coordinator.scope == review.scope else { return }
                                // Clear only this accepted draft, never on cancel, failure or an uncertain result.
                                if coordinator.pending == nil, coordinator.failure == nil, review.replacing == nil,
                                   case .text(let text) = review.content, draft.trimmingCharacters(in: .whitespacesAndNewlines) == text { draft = "" }
                                revision += 1
                            }
                        }
        }
                    } label: {
                        Text(coordinator.failure == nil ? LocalizedStringKey("shopNPC.confirmSend") : LocalizedStringKey("shopNPC.retry"))
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!coordinator.canConfirmPending || recording || !showsConversation)
                    .accessibilityIdentifier("shopNPC.confirmSend")
                }
            }
            Button(role: .cancel) { coordinator.cancelReview(); revision += 1 } label: {
                Text("shopNPC.cancel").frame(minHeight: 44).contentShape(Rectangle())
            }
                .disabled(sending).accessibilityIdentifier("shopNPC.cancel")
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
    }
    /// The text that would actually leave the device for this review; nil for voice or a stale review.
    private func finalText(of review: ShopNPCReview) -> (String, UUID?)? {
        guard coordinator.pending?.id == review.id, case .text(let text) = review.content else { return nil }
        return (text, review.id)
    }
    /// Screens the final text; clean text runs `run` unchanged, otherwise asks first.
    private func guardedSend(current: @escaping () -> (String, UUID?)?, run: @escaping () -> Void) {
        guard let (text, request) = current() else { run(); return }
        switch sendGate.evaluate(text: text, scope: coordinator.scope, request: request) {
        case .proceed: run()
        case .confirm(let found): pendingSend = (current, run); sensitiveFindings = found
        }
    }
    /// Runs only if the exact text, request and scope still match what the person was shown.
    private func confirmedSend() {
        let held = pendingSend; pendingSend = nil
        guard let held, let (text, request) = held.current(),
              sendGate.confirm(text: text, scope: coordinator.scope, request: request) else { sendGate.cancel(); return }
        held.run()
    }
    private func cancelSensitiveConfirmation() { sendGate.cancel(); pendingSend = nil; sensitiveFindings = [] }
    private func attempt(_ action: () throws -> Void) {
        do { try action(); localFailure = nil } catch { localFailure = error as? ShopNPCFailure ?? .invalid }
        revision += 1
    }
    private func suspend() {
        cancelSensitiveConfirmation(); capture?.cancel(); typing = false; recording = false; localFailure = nil
        coordinator.suspend()
    }
    private func clearTransient() { cancelSensitiveConfirmation(); capture?.cancel(); typing = false; recording = false; draft = ""; localFailure = nil; revision += 1 }
    private func invalidate() { coordinator.invalidate(); clearTransient() }
    private func relationTone(_ state: ShopNPCRelationState) -> CYStatusTone {
        switch state { case .ally: return .success; case .guarded: return .warning; case .neutral: return .info }
    }
    private func relationSymbol(_ state: ShopNPCRelationState) -> String {
        switch state { case .ally: return "heart.fill"; case .guarded: return "shield.fill"; case .neutral: return "person.2" }
    }
    private func effectChipText(_ effect: ShopNPCDialogueEffect) -> String {
        if let label = effect.label, !label.isEmpty {
            switch effect.type {
            case .inc:
                let delta = effect.delta ?? 0
                return delta > 0 ? "\(label) +\(delta)" : "\(label) \(delta)"
            case .addTag:
                return label
            }
        }
        switch effect.type {
        case .inc:
            let delta = effect.delta ?? 0
            return delta > 0 ? "\(effect.key) +\(delta)" : "\(effect.key) \(delta)"
        case .addTag:
            return effect.key
        }
    }
    private func effectTone(_ effect: ShopNPCDialogueEffect) -> CYStatusTone {
        switch effect.type {
        case .inc: return (effect.delta ?? 0) >= 0 ? .success : .warning
        case .addTag: return .info
        }
    }
    private func effectSymbol(_ effect: ShopNPCDialogueEffect) -> String {
        switch effect.type {
        case .inc: return (effect.delta ?? 0) >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
        case .addTag: return "tag.fill"
        }
    }
}

/// Add to the authoritative free-explore node's detail. Host supplies fresh scoped bindings.
/// Missing/unnamed NPCs never offer an entrance. This is not a merchant-row bridge.
@MainActor struct ShopNPCNodeEntrance: View {
    let name: String?
    let makeCoordinator: (() -> ShopNPCCoordinator)?
    var greeting: String? = nil
    var makeScriptedGuide: ((ShopNPCScope) -> ShopNPCScriptedGuideSource?)? = nil
    var body: some View {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let makeCoordinator {
            NavigationLink("shopNPC.open") { ShopNPCOwnedDestination(makeCoordinator: makeCoordinator, name: name, greeting: greeting, makeScriptedGuide: makeScriptedGuide) }
                .accessibilityIdentifier("shopNPC.open")
        }
    }
}


/// iMessage-style bubble: NPC replies carry the avatar and a tail corner on the leading side; own messages sit trailing.
/// Presentation only; sender truth comes from the caller. Spoken as "<sender>: <text>" for VoiceOver.
struct NPCChatBubble<Content: View>: View {
    let name: String
    let isOwn: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.themeDomain) private var domain
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwn { Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 56) }
            else { CYAvatarView(name: name, size: .sm) }
            content()
                .cyText(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(isOwn ? Theme.Color.actionPrimaryForeground(in: domain) : CYColor.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isOwn ? Theme.Color.actionPrimaryBackground(in: domain) : CYColor.bgElevated,
                            in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: isOwn ? 20 : 6,
                                                       bottomTrailingRadius: isOwn ? 6 : 20, topTrailingRadius: 20, style: .continuous))
            if !isOwn { Spacer(minLength: typeSize.isAccessibilitySize ? 0 : 40) }
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }
}

/// Three pulsing dots inside an NPC bubble while a reply is pending. Static under Reduce Motion.
struct NPCTypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.3, paused: reduceMotion)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.3) % 3
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle().fill(CYColor.textSecondary).frame(width: 8, height: 8)
                        .opacity(reduceMotion || index == step ? 1 : 0.35)
                }
            }.padding(.vertical, 6)
        }
    }
}
