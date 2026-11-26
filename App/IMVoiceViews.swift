import SwiftUI

/// Voice compose and playback. State, uploads, and playback authorization are unchanged.
@MainActor struct IMVoiceComposeView: View {
    let owner: IMVoiceCoordinator
    let current: () -> Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @QuestifyReduceMotion private var reduceMotion
    @State private var device: IMVoiceDevice?
    @State private var recording = false
    @State private var error = false
    @State private var revision = 0
    private var available: Bool { current() && owner.isCurrent }

    private enum Commit { case record, upload, continueSend, send }
    /// One filled action. Send review wins, then continue, then upload, then record.
    private var commit: Commit? {
        if case .reviewing(.send(let intent)) = owner.expanded.visibleState, case .voice = intent.payload { return .send }
        if case .ready = owner.visibleState, owner.expanded.writer.canSendVoice && owner.canRecoverOriginalSend { return .continueSend }
        if owner.canUpload {
            if case .draft = owner.visibleState { return .upload }
            if case .empty = owner.visibleState { return .record }
        }
        return nil
    }

    var body: some View {
        // Observe revisions without replacing the recording/upload presentation identity.
        let _ = revision
        Form {
            if !available {
                ContentUnavailableView("d7.imCompose.unavailable", systemImage: "lock")
            } else {
                Section { composeBody }
                Section { sendRecovery }
            }
        }
        .imFlowForm()
        .navigationTitle(Text("d7.imVoice.title"))
        .themeDomain(.player)
        .privacySensitive()
        .sensoryFeedback(.selection, trigger: recording)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { dismiss() } } }
        .onAppear {
            device = IMVoiceDevice(enabled: { available })
            owner.onChange = { revision += 1 }; owner.expanded.onChange = { revision += 1 }
        }
        .onDisappear { stop(); owner.onChange = nil; owner.expanded.onChange = nil }
        .onChange(of: available) { _, value in if !value { stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
    }

    @ViewBuilder private var composeBody: some View {
        switch owner.visibleState {
        case .empty, .draft:
            if owner.canUpload {
                if recording {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                }
                pill(recording ? "d7.imVoice.stopRecording" : "d7.imVoice.record",
                     image: recording ? "stop.circle.fill" : "mic",
                     primary: commit == .record) {
                    if recording { device?.finish(); recording = false }
                    else { beginRecording() }
                }
                .accessibilityLabel(Text(recording ? "d7.imVoice.stopRecording" : "d7.imVoice.record"))
                if case .draft(let clip) = owner.visibleState {
                    LabeledContent("d7.imSummary.duration") { IMDurationText(milliseconds: clip.durationMS) }
                    pill("d7.imVoice.play", image: "play", primary: false) {
                        do { try device?.play(clip.bytes, interrupted: {}) } catch { self.error = true }
                    }
                    pill("d7.imCompose.upload", image: "arrow.up.circle.fill", primary: commit == .upload) {
                        Task { if available { await owner.confirmUpload() } }
                    }
                    destructive("d7.imCompose.discard") { device?.cancel(); owner.discardDraft() }
                }
            } else {
                ContentUnavailableView("d7.imVoice.unavailable", systemImage: "mic.slash")
            }
        case .uploading:
            status("d7.imCompose.uploading", symbol: "arrow.up.circle", color: .secondary)
            ProgressView().frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(Text("d7.imCompose.uploading"))
        case .unknown:
            status("d7.imCompose.uploadUnknown", symbol: "clock.arrow.circlepath", color: .secondary)
            if owner.canRecover { pill("d7.imCompose.checkStatus", image: "arrow.clockwise", primary: false) { Task { await owner.recover() } } }
            if owner.canUpload { pill("d7.chatInfo.tryAgain", image: "arrow.clockwise", primary: false) { Task { if available { await owner.uploadUnchanged() } } } }
        case .held:
            status("d7.imCompose.inReview", symbol: "clock", color: .secondary)
            if owner.canRecover { pill("d7.imCompose.refresh", image: "arrow.clockwise", primary: false) { Task { await owner.recover() } } }
        case .rejected:
            status("d7.imVoice.rejected", symbol: "xmark.octagon", color: .red)
            if owner.canRecover { pill("d7.imCompose.refresh", image: "arrow.clockwise", primary: false) { Task { await owner.recover() } } }
            destructive("d7.imCompose.discard") { owner.discardRejected() }
        case .ready(let reference):
            Label("d7.imCompose.approved", systemImage: "checkmark.seal").foregroundStyle(.green)
            LabeledContent("d7.imSummary.duration") { IMDurationText(milliseconds: reference.durationMS) }
            if owner.expanded.writer.canSendVoice && owner.canRecoverOriginalSend {
                pill("d7.imCompose.continue", image: "arrow.right.circle", primary: commit == .continueSend) {
                    Task { if available { await owner.reviewSend() } }
                }
            }
        case .closed:
            ContentUnavailableView("d7.imCompose.unavailable", systemImage: "lock")
        }
        if error { status("d7.imVoice.deviceError", symbol: "exclamationmark.circle", color: .red) }
    }

    @ViewBuilder private var sendRecovery: some View {
        if owner.canRecoverOriginalSend {
            pill("d7.imCompose.checkSent", image: "paperplane", primary: false) {
                Task { if available { await owner.recoverOriginalSend() } }
            }
        }
        switch owner.originalSendState {
        case .reading:
            status("d7.imCompose.checking", symbol: "clock", color: .secondary)
            ProgressView().frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(Text("d7.imCompose.checking"))
        case .notFound: status("d7.imCompose.notFound", symbol: "questionmark.circle", color: .secondary)
        case .unknown: status("d7.imCompose.stillUnknown", symbol: "clock.arrow.circlepath", color: .secondary)
        case .found:
            Label("d7.imVoice.sent", systemImage: "checkmark.circle").foregroundStyle(.green)
            pill("d7.imCompose.done", image: "checkmark", primary: false) { owner.finishAcknowledged() }
        case .unchecked: EmptyView()
        }
        switch owner.expanded.visibleState {
        case .reviewing(.send(let intent)):
            if case .voice = intent.payload {
                IMMutationSummary(mutation: .send(intent))
                pill("d7.imVoice.send", image: "paperplane.fill", primary: commit == .send) {
                    Task { if available { await owner.expanded.confirm() } }
                }
                Button("action.cancel", role: .cancel) { owner.expanded.cancelReview() }
            }
        case .submitting:
            status("d7.imCompose.sending", symbol: "paperplane", color: .secondary)
            ProgressView().frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel(Text("d7.imCompose.sending"))
        case .outcomeUnknown(.send(let intent)), .rejected(.send(let intent)):
            if case .voice = intent.payload {
                status("d7.imCompose.sendUnknown", symbol: "clock.arrow.circlepath", color: .secondary)
                // Retry reads the original receipt first, then retries the same message.
                if owner.canRecoverOriginalSend {
                    pill("d7.chatInfo.tryAgain", image: "arrow.clockwise", primary: false) {
                        Task { if available { await owner.retryOriginalSend() } }
                    }
                }
            }
        case .acknowledged(.sent(let message)):
            if IMVoiceReference.read(message) != nil, !hasRecoveredSend {
                Label("d7.imVoice.sent", systemImage: "checkmark.circle").foregroundStyle(.green)
                if owner.canRecoverOriginalSend {
                    pill("d7.imCompose.done", image: "checkmark", primary: false) {
                        Task { if available { await owner.recoverAndFinishAcknowledged() } }
                    }
                }
            }
        default: EmptyView()
        }
    }

    private var hasRecoveredSend: Bool {
        if case .found = owner.originalSendState { return true }; return false
    }
    private func beginRecording() {
        guard available, owner.canUpload else { return }; error = false
        Task { @MainActor in
            do {
                try await device?.record(finished: { result in
                    recording = false
                    guard available else { return }
                    switch result { case .success(let clip): do { try owner.select(clip) } catch { self.error = true }; case .failure: error = true }
                }, interrupted: { recording = false; error = true })
                if available { recording = true } else { stop() }
            } catch { self.error = true; recording = false }
        }
    }
    private func stop() { device?.cancel(); recording = false; owner.invalidate() }

    /// System button: the one filled action is `.borderedProminent`, the rest `.bordered`.
    @ViewBuilder private func pill(_ title: LocalizedStringKey, image: String, primary: Bool, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) { Label(title, systemImage: image).frame(maxWidth: .infinity) }
        if primary {
            button.buttonStyle(.borderedProminent).controlSize(.large)
        } else {
            button.buttonStyle(.bordered).controlSize(.large)
        }
    }
    private func destructive(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, role: .destructive, action: action)
    }
    private func status(_ key: LocalizedStringKey, symbol: String, color: Color) -> some View {
        Label(key, systemImage: symbol)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

@MainActor struct IMVoicePlaybackView: View {
    let message: MessagingMessage
    let owner: IMVoiceCoordinator
    let current: () -> Bool
    @Environment(\.scenePhase) private var scenePhase
    @QuestifyReduceMotion private var reduceMotion
    @State private var device: IMVoiceDevice?
    @State private var generation = UUID()
    @State private var loading = false
    @State private var authorizationTask: Task<Void, Never>?
    @State private var failed = false
    private var available: Bool { current() && owner.isCurrent && message.conversationID == owner.scope.conversationID && IMVoiceReference.read(message) != nil }
    private var canPlay: Bool { owner.service.playbackEnabled && owner.service.playbackStatusEnabled }
    var body: some View {
        Form {
            if let voice = IMVoiceReference.read(message), available {
                Section {
                    LabeledContent {
                        IMDurationText(milliseconds: voice.durationMS)
                    } label: { Label("d7.imVoice.message", systemImage: "waveform") }
                    if loading {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                            .accessibilityHidden(true)
                    }
                    if canPlay {
                        Button {
                            guard available, !loading else { return }
                            stop(); let stamp = generation; loading = true; failed = false
                            Task { @MainActor in
                                do {
                                    try await owner.service.authorizePlayback(message: message, scope: owner.scope)
                                    let bytes = try await owner.service.audio(messageID: message.id, scope: owner.scope)
                                    guard available, generation == stamp, !Task.isCancelled else { return }
                                    try await owner.service.authorizePlayback(message: message, scope: owner.scope)
                                    guard available, generation == stamp, !Task.isCancelled else { return }
                                    try device?.play(bytes, interrupted: { stop() }); loading = false
                                    monitorPlayback(stamp: stamp, durationMS: voice.durationMS)
                                } catch { if generation == stamp { failPlayback(error) } }
                            }
                        } label: {
                            Label("d7.imVoice.play", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(loading)
                        .accessibilityLabel(Text("d7.imVoice.play"))
                    }
                    Group {
                        let stopButton = Button { stop() } label: {
                            Label("d7.imVoice.stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                        }
                        if canPlay {
                            stopButton.buttonStyle(.bordered).controlSize(.large)
                        } else {
                            stopButton.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }
                    .accessibilityLabel(Text("d7.imVoice.stop"))
                }
            } else {
                ContentUnavailableView("d7.imVoice.messageUnavailable", systemImage: "lock")
            }
            if loading {
                HStack(spacing: 8) {
                    ProgressView().accessibilityHidden(true)
                    Text("d7.imCompose.loading")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if failed {
                Label("d7.imVoice.playFailed", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .imFlowForm()
        .navigationTitle(Text("d7.imVoice.message"))
        .themeDomain(.player)
        .privacySensitive()
        .onReceive(NotificationCenter.default.publisher(for: IMVoiceCoordinator.consumptionRetiredNotification)) { event in
            if let retired = event.object as? IMVoiceCoordinator, retired === owner { stop() }
        }
        .onAppear { device = IMVoiceDevice(enabled: { available }) }
        .onDisappear { stop() }
        .onChange(of: available) { _, value in if !value { stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
    }
    private func monitorPlayback(stamp: UUID, durationMS: Int) {
        authorizationTask?.cancel()
        authorizationTask = Task { @MainActor in
            // A polling cadence, not a new retention TTL or cached authorization period.
            let end = ContinuousClock.now.advanced(by: .milliseconds(durationMS))
            while !Task.isCancelled, generation == stamp, ContinuousClock.now < end {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    guard generation == stamp else { return }
                    guard available, !Task.isCancelled else { stop(); return }
                    try await owner.service.authorizePlayback(message: message, scope: owner.scope)
                    guard generation == stamp else { return }
                    guard available, !Task.isCancelled else { stop(); return }
                } catch {
                    guard generation == stamp else { return }
                    failPlayback(error); return
                }
            }
            if generation == stamp { stop() }
        }
    }
    private func failPlayback(_ error: Error) {
        stop(); failed = true
        if let failure = error as? MessagingReadFailure,
           failure.isUnauthorized || failure.isForbidden || failure.isClosed { owner.retireConsumption() }
    }
    private func stop() {
        generation = UUID(); authorizationTask?.cancel(); authorizationTask = nil
        device?.cancel(); loading = false
    }
}
