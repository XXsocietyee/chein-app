import SwiftUI

/// Native r2 story flow, S6: pieces of the Books-style reader used by `ChapterStoryView`
/// when `NativeR2Flags.storyFlow` is on. System fonts and semantic colours only.

/// Chapter opener at the top of the scroll (replaces the r1 gate overlay and hero header).
@MainActor struct NR2ChapterOpener: View {
    let number: Int?
    let total: Int?
    let title: String?
    let opening: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let number, let total {
                Text("play.nr2.reader.chapter \(number) \(total)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let title, !title.isEmpty {
                Text(verbatim: title).font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            if let opening, !opening.isEmpty {
                Text(verbatim: opening).font(.body).italic().foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chapterFlip.gate")
    }
}

/// Narration paragraph: body text, readable line spacing, selectable.
@MainActor struct NR2NarrationText: View {
    let text: String
    var body: some View {
        Text(verbatim: text)
            .font(.body)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Role line: 32 pt avatar (button to the cast card), the speaker's name, then the line.
@MainActor struct NR2RoleLineRow: View {
    let name: String?
    let text: String
    let member: CastMember?
    var openCard: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let member {
                Button { openCard?() } label: { NR2CastAvatar(member: member, size: 32) }
                    .buttonStyle(.plain)
                    .disabled(openCard == nil)
                    .accessibilityLabel(Text(verbatim: member.name))
            } else if name != nil {
                Image(systemName: "person.crop.circle")
                    .font(.title2).foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let name, !name.isEmpty {
                    Text(verbatim: name).font(.subheadline.bold())
                }
                Text(verbatim: text).font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .contextMenu {
            if let openCard, member != nil {
                Button("play.nr2.reader.viewRole", systemImage: "person.text.rectangle", action: openCard)
            }
        }
    }
}

/// Inner voice / voice-over: italic, secondary. No card.
@MainActor struct NR2VoiceText: View {
    let speaker: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !speaker.isEmpty { Text(verbatim: speaker).font(.caption).foregroundStyle(.secondary) }
            Text(verbatim: text).font(.body).italic()
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// End of chapter: closing line, stops done, the next-stage row and one prominent continue.
@MainActor struct NR2ChapterFooter: View {
    let closing: String?
    let done: Int
    let total: Int
    let nextTitle: String?
    let onContinue: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let closing, !closing.isEmpty {
                Text(verbatim: closing).font(.body).italic().foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chapterStory.closingLine")
            }
            Divider()
            LabeledContent("play.nr2.reader.stopsDone") {
                Text("play.nr2.route.progressValue \(done) \(total)").monospacedDigit()
            }
            if let nextTitle, !nextTitle.isEmpty {
                LabeledContent {
                    Text(verbatim: nextTitle).multilineTextAlignment(.trailing)
                } label: {
                    Label("play.nr2.reader.nextStage", systemImage: "arrow.right.circle")
                }
                .accessibilityIdentifier("play.nr2.reader.nextStage")
            }
            Button(action: onContinue) {
                Text(nextTitle == nil ? "play.nr2.reader.finish" : "play.nr2.reader.next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("chapterFlip.end.continue")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chapterFlip.end")
    }
}

/// Podcasts-style mini player pinned to the bottom of the reader.
/// Uses the existing `PlatformAudioPlayback`; skip moves to the next clip of this chapter.
/// P-083: keeps playing in the background (the reader keeps it mounted) and drives Now Playing / remote commands.
/// P-084: playhead line + elapsed time; tapping the bar opens the full player sheet (scrubber, ±15 s, speed).
/// P-085: hosts are pre-approved by the media policy; the listener answers one plain question once
/// ("play story audio?") and later clips start straight away (the per-clip Core approval is given for them).
@MainActor struct NR2MiniAudioPlayer: View {
    let title: String?
    /// The story (route) title for Now Playing's second line; nil leaves it out.
    var chapterTitle: String? = nil
    /// This chapter's clips in reading order (narration / guide first, then audio blocks).
    let urls: [String]
    /// The clip the reader selected. Nil until the first play.
    let selected: String?
    let scope: UUID
    let makeAudio: (@MainActor () -> PlatformAudioPlayback)?
    /// The reader's guarded selection (identity / presentation checks live there).
    let select: (String) -> Void
    @State private var model: PlatformAudioPlayback?
    @State private var review = false
    @State private var playAfterSelect = false
    @State private var showsPlayer = false
    @AppStorage("play.nr2.storyAudio.consented") private var consented = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var source: PlatformMediaSource? {
        guard let selected, let url = URL(string: selected.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return PlatformMediaSource(url: url, scope: scope)
    }
    private var state: PlatformAudioState { model?.state ?? .gated }
    private var isLoaded: Bool { state == .playing || state == .paused }
    private var nextURL: String? {
        guard !urls.isEmpty else { return nil }
        guard let selected, let index = urls.firstIndex(of: selected) else { return urls.first }
        return urls.indices.contains(index + 1) ? urls[index + 1] : nil
    }
    private var canSkip: Bool { makeAudio != nil && nextURL != nil && !(selected == nil && urls.count < 2) }

    var body: some View {
        VStack(spacing: 0) {
            NR2StoryAudioProgress(isActive: isLoaded)
                .opacity(isLoaded ? 1 : 0)
            HStack(spacing: 12) {
                Button { showsPlayer = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: state == .playing && !reduceMotion)
                            .frame(width: 40, height: 40)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            if let title, !title.isEmpty {
                                Text(verbatim: title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            } else {
                                Text("platform.audio.title").font(.subheadline.weight(.semibold)).lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                Text(LocalizedStringKey("platform.audio." + String(describing: state)))
                                    .contentTransition(.opacity)
                                    .accessibilityIdentifier("platform.audio.state")
                                if isLoaded {
                                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                                        Text(verbatim: NR2StoryAudioTime.text(PlatformAudioTransportRegistry.active?.elapsed ?? 0))
                                            .monospacedDigit()
                                    }
                                    .accessibilityHidden(true)
                                }
                            }
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(makeAudio == nil || urls.isEmpty)
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("play.nr2.reader.player.openHint"))
                .accessibilityIdentifier("play.nr2.reader.audio.open")
                if state == .loading {
                    ProgressView().frame(width: 44, height: 44)
                } else {
                    Button(action: playPause) {
                        Image(systemName: state == .playing ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(makeAudio == nil || urls.isEmpty || state == .disposed)
                    .accessibilityLabel(Text(state == .playing ? "platform.audio.pause" : "platform.audio.play"))
                    .accessibilityIdentifier("platform.audio.toggle")
                }
                Button(action: skip) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .disabled(!canSkip)
                .accessibilityLabel(Text("play.nr2.reader.audio.skip"))
                .accessibilityIdentifier("play.nr2.reader.audio.skip")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .sensoryFeedback(.impact(weight: .light), trigger: state == .playing)
        .confirmationDialog("play.nr2.audio.consent.title", isPresented: $review, titleVisibility: .visible) {
            Button("play.nr2.audio.consent.allow") { consented = true; model?.approveSelectedMedia(); model?.toggle() }
                .accessibilityIdentifier("play.nr2.audio.consent.allow")
            Button("platform.cancel", role: .cancel) {}
        } message: { Text("play.nr2.audio.consent.message") }
        .cySheet(isPresented: $showsPlayer) {
            NR2StoryFullAudioPlayer(title: title, state: state, canSkip: canSkip,
                                    togglePlay: playPause, skipClip: skip)
        }
        .onAppear {
            if model == nil { model = makeAudio?() }
            model?.select(source)
        }
        .onChange(of: source) { _, next in
            review = false
            model?.select(next)
            if playAfterSelect, next != nil { playAfterSelect = false; startOrReview() }
        }
        .onChange(of: scope) { _, _ in review = false; showsPlayer = false; model?.dispose(); model = makeAudio?(); model?.select(source) }
        // P-083: a clip that is playing or paused keeps going in the background (Lock Screen controls it);
        // anything not started yet still drops its question and approval, as before.
        .onChange(of: scenePhase) { _, next in
            guard next != .active else { return }
            review = false
            if !isLoaded { model?.suspend() }
        }
        .onDisappear {
            review = false; showsPlayer = false; model?.dispose(); model = nil
            NR2StoryNowPlaying.shared.clear()
            IslandMediaBridge.stateChanged(.disposed, title: title, toggle: {})
        }
        // Native r2 M4: playing / paused → media island (play / pause there runs the same toggle) and the
        // story-audio Live Activity; ended / failed / disposed removes both. P-083: and Now Playing.
        .onChange(of: state) { old, next in
            IslandMediaBridge.stateChanged(next, title: title) { startOrReview() }
            var remote = NR2StoryNowPlaying.Actions(toggle: { startOrReview() }, next: nil)
            if canSkip { remote.next = { skip() } }
            NR2StoryNowPlaying.shared.update(state: next, title: title, chapter: chapterTitle, actions: remote)
            announce(from: old, to: next)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("play.nr2.reader.miniPlayer")
    }

    private func playPause() {
        if selected == nil, let first = urls.first {
            playAfterSelect = true
            select(first)
            return
        }
        startOrReview()
    }
    /// Playing or paused toggles. Otherwise: asked once already → approve this clip and start; first time → ask.
    private func startOrReview() {
        guard let model else { return }
        if model.state == .playing || model.state == .paused { model.toggle(); return }
        guard model.state == .idle || model.state == .ended || model.state == .failed else { return }
        if consented {
            model.approveSelectedMedia(); model.toggle()
        } else {
            review = true
        }
    }
    private func skip() {
        guard let nextURL else { return }
        playAfterSelect = true
        select(nextURL)
    }
    /// VoiceOver hears failures and the end of a clip (the button label already says play / pause).
    private func announce(from old: PlatformAudioState, to next: PlatformAudioState) {
        guard old != next else { return }
        let key: String.LocalizationValue
        switch next {
        case .failed: key = "platform.audio.failed"
        case .ended: key = "platform.audio.ended"
        default: return
        }
        AccessibilityNotification.Announcement(appLocalized(key, locale: .current)).post()
    }
}
