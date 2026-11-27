import SwiftUI
import ImageIO

/// G-020 (design P1): a channel image message shows the real photo inside the bubble, not generated art.
/// Privacy rule kept from `NativeChannelAttachmentPreviewFlow`: the image is never fetched automatically (a fetch can
/// disclose the reader), so the bubble shows a system photo placeholder and one 显示图片 button; the same explicit
/// descriptor-checked read as the old preview page then draws the photo in place. Nothing is persisted; leaving the
/// screen, the app going inactive or the account changing clears the bytes, exactly as the preview page did.
@MainActor struct NativeChannelInlineImageView: View {
    @State private var retainedFlow: NativeChannelAttachmentPreviewFlow
    private var flow: NativeChannelAttachmentPreviewFlow { retainedFlow }
    let current: () -> Bool
    init(flow: NativeChannelAttachmentPreviewFlow, current: @escaping () -> Bool) {
        _retainedFlow = State(initialValue: flow); self.current = current
    }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var revision = 0
    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?
    @State private var onScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var placeholderHeight: CGFloat = 140

    var body: some View {
        let _ = revision
        let live = current() && flow.isCurrent
        VStack(alignment: .leading, spacing: 8) {
            if live, flow.visibleState == .displayed, let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
                    .transition(.opacity)
                    .accessibilityLabel(Text("preview.image", tableName: "NativeChannelAttachmentPreview"))
                    .accessibilityIdentifier("attachmentPreview.image")
            } else if live, flow.visibleState == .loading {
                ProgressView { Text("preview.loading", tableName: "NativeChannelAttachmentPreview") }
                    .frame(maxWidth: .infinity, minHeight: placeholderHeight)
                    .background(.fill.tertiary)
                    .accessibilityIdentifier("attachmentPreview.loading")
            } else {
                Button { load() } label: {
                    Label("channel.image.show", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: placeholderHeight)
                }
                .buttonStyle(.bordered)
                .disabled(!live || !flow.enabled)
                .accessibilityHint(Text("channel.image.show.hint"))
                .accessibilityIdentifier("attachmentPreview.load")
                if let key = statusKey(live: live) {
                    Label { Text(LocalizedStringKey(key), tableName: "NativeChannelAttachmentPreview") } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("attachmentPreview.status")
                }
            }
        }
        .animation(reduceMotion ? nil : .default, value: image != nil)
        .onAppear { onScreen = true; flow.onChange = { changed() }; updateImage() }
        .onDisappear { onScreen = false; clear(); flow.onChange = nil }
        .onChange(of: current()) { _, value in if !value { clear() } }
        .onChange(of: flow.isCurrent) { _, value in if !value { clear() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { clear() } }
    }

    /// The preview page's status copy for every state that is not idle, loading or displayed.
    private func statusKey(live: Bool) -> String? {
        guard live else { return "preview.changed" }
        if !flow.enabled { return "preview.notConfigured" }
        switch flow.visibleState {
        case .idle, .loading, .displayed: return nil
        case .pending: return "preview.pending"
        case .rejected: return "preview.rejected"
        case .expired: return "preview.expired"
        case .unsupported: return "preview.unsupported"
        case .sourceUnconfirmed: return "preview.sourceUnconfirmed"
        case .unavailable: return "preview.unavailable"
        case .unknown: return "preview.unknown"
        }
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task {
            guard onScreen, scenePhase == .active, current(), flow.isCurrent, !Task.isCancelled else { return }
            await flow.load()
        }
    }

    private func changed() {
        let wasShown = image != nil
        updateImage()
        revision += 1
        if !wasShown, image != nil {
            AccessibilityNotification.Announcement(appLocalized("channel.image.loaded", locale: locale)).post()
        }
    }

    private func updateImage() {
        guard current(), flow.isCurrent, flow.visibleState == .displayed, let data = flow.bytes else { image = nil; return }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0, width.doubleValue * height.doubleValue <= 32_000_000,
              let decoded = UIImage(data: data) else { image = nil; flow.unsupportedBytes(); return }
        image = decoded
    }

    private func clear() { loadTask?.cancel(); loadTask = nil; image = nil; flow.clear() }
}

/// G-024 (design P1): a voice message plays inside its bubble, as in Messages: one play / stop button, the duration,
/// and a waveform that animates while playing (static under Reduce Motion). The same authorize → read → re-authorize
/// sequence and per-second authorization check as `IMVoicePlaybackView`; no new request.
@MainActor struct NativeChannelInlineVoiceView: View {
    let message: MessagingMessage
    let owner: IMVoiceCoordinator
    let current: () -> Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var device: IMVoiceDevice?
    @State private var generation = UUID()
    @State private var loading = false
    @State private var playing = false
    @State private var failed = false
    @State private var monitor: Task<Void, Never>?
    @State private var playStart: Date?
    private var available: Bool {
        current() && owner.isCurrent && message.conversationID == owner.scope.conversationID && IMVoiceReference.read(message) != nil
    }
    /// Idle: the clip length. Playing: the time left, counting down (system timer text, no per-second state).
    @ViewBuilder private func remaining(_ voice: IMVoiceReference) -> some View {
        if playing, let playStart {
            Text(timerInterval: playStart...playStart.addingTimeInterval(Double(voice.durationMS) / 1000), countsDown: true)
                .monospacedDigit()
        } else {
            IMDurationText(milliseconds: voice.durationMS)
        }
    }
    private var canPlay: Bool { owner.service.playbackEnabled && owner.service.playbackStatusEnabled }
    private var toggleSymbol: String {
        // Base names; `.symbolVariant(.circle.fill)` draws the filled circle forms.
        if playing || loading { return "stop" }
        return "play"
    }

    var body: some View {
        if let voice = IMVoiceReference.read(message), available {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Button { playing || loading ? stop() : play(voice) } label: {
                        Image(systemName: toggleSymbol)
                            .symbolVariant(.circle.fill)
                            .font(.largeTitle)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canPlay)
                    .accessibilityLabel(Text(LocalizedStringKey(playing || loading ? "d7.imVoice.stop" : "d7.imVoice.play")))
                    .accessibilityIdentifier("channel.voice.toggle")
                    // C5 social: bar waveform fills as the clip plays (1 s steps under Reduce Motion).
                    TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 15, paused: !playing)) { context in
                        CYSocialVoiceWaveform(seed: message.id, samples: Data(base64Encoded: voice.waveform),
                            progress: playing ? CYSocialVoiceProgress.fraction(start: playStart, durationMS: voice.durationMS, at: context.date) : 0)
                    }
                    if loading { ProgressView().accessibilityHidden(true) }
                    remaining(voice)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("d7.imVoice.message"))
                }
                if failed {
                    Label("d7.imVoice.playFailed", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .sensoryFeedback(.start, trigger: playing) { _, now in now }
            .sensoryFeedback(.error, trigger: failed) { _, now in now }
            .onReceive(NotificationCenter.default.publisher(for: IMVoiceCoordinator.consumptionRetiredNotification)) { event in
                if let retired = event.object as? IMVoiceCoordinator, retired === owner { stop() }
            }
            .onAppear { if device == nil { device = IMVoiceDevice(enabled: { available }) } }
            .onDisappear { stop() }
            .onChange(of: available) { _, value in if !value { stop() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        } else {
            Label("d7.imVoice.messageUnavailable", systemImage: "lock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func play(_ voice: IMVoiceReference) {
        guard available, canPlay, !loading else { return }
        stop(); let stamp = generation; loading = true; failed = false
        Task { @MainActor in
            do {
                try await owner.service.authorizePlayback(message: message, scope: owner.scope)
                let bytes = try await owner.service.audio(messageID: message.id, scope: owner.scope)
                guard available, generation == stamp, !Task.isCancelled else { return }
                try await owner.service.authorizePlayback(message: message, scope: owner.scope)
                guard available, generation == stamp, !Task.isCancelled else { return }
                try device?.play(bytes, interrupted: { stop() })
                loading = false; playStart = Date(); playing = true
                watch(stamp: stamp, durationMS: voice.durationMS)
            } catch { if generation == stamp { fail(error) } }
        }
    }

    /// Same cadence as the playback page: the authorization is re-checked every second until the clip ends.
    private func watch(stamp: UUID, durationMS: Int) {
        monitor?.cancel()
        monitor = Task { @MainActor in
            let end = ContinuousClock.now.advanced(by: .milliseconds(durationMS))
            while !Task.isCancelled, generation == stamp, ContinuousClock.now < end {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    guard generation == stamp else { return }
                    guard available, !Task.isCancelled else { stop(); return }
                    try await owner.service.authorizePlayback(message: message, scope: owner.scope)
                    guard generation == stamp else { return }
                } catch {
                    guard generation == stamp else { return }
                    fail(error); return
                }
            }
            if generation == stamp { stop() }
        }
    }

    private func fail(_ error: Error) {
        stop(); failed = true
        AccessibilityNotification.Announcement(appLocalized("d7.imVoice.playFailed", locale: locale)).post()
        if let failure = error as? MessagingReadFailure,
           failure.isUnauthorized || failure.isForbidden || failure.isClosed { owner.retireConsumption() }
    }

    private func stop() {
        generation = UUID(); monitor?.cancel(); monitor = nil
        device?.cancel(); loading = false; playing = false; playStart = nil
    }
}
