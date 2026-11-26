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
/// Uses the existing `PlatformAudioPlayback` with the same per-source consent review as
/// `PlatformAudioConsumerView`; skip moves to the next clip of this chapter.
@MainActor struct NR2MiniAudioPlayer: View {
    let title: String?
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
    @Environment(\.scenePhase) private var scenePhase

    private var source: PlatformMediaSource? {
        guard let selected, let url = URL(string: selected.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return PlatformMediaSource(url: url, scope: scope)
    }
    private var state: PlatformAudioState { model?.state ?? .gated }
    private var nextURL: String? {
        guard !urls.isEmpty else { return nil }
        guard let selected, let index = urls.firstIndex(of: selected) else { return urls.first }
        return urls.indices.contains(index + 1) ? urls[index + 1] : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let title, !title.isEmpty {
                    Text(verbatim: title).font(.subheadline.weight(.semibold)).lineLimit(1)
                } else {
                    Text("platform.audio.title").font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Text(LocalizedStringKey("platform.audio." + String(describing: state)))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("platform.audio.state")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if state == .loading {
                ProgressView().frame(width: 44, height: 44)
            } else {
                Button(action: playPause) {
                    Image(systemName: state == .playing ? "pause.fill" : "play.fill")
                        .font(.title2)
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
            .disabled(makeAudio == nil || nextURL == nil || (selected == nil && urls.count < 2))
            .accessibilityLabel(Text("play.nr2.reader.audio.skip"))
            .accessibilityIdentifier("play.nr2.reader.audio.skip")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .confirmationDialog("platform.audio.review", isPresented: $review, titleVisibility: .visible) {
            Button("platform.audio.allow") { model?.approveSelectedMedia(); model?.toggle() }
            Button("platform.cancel", role: .cancel) {}
        } message: { Text(verbatim: source?.url.host ?? "") }
        .onAppear {
            if model == nil { model = makeAudio?() }
            model?.select(source)
        }
        .onChange(of: source) { _, next in
            review = false
            model?.select(next)
            if playAfterSelect, next != nil { playAfterSelect = false; startOrReview() }
        }
        .onChange(of: scope) { _, _ in review = false; model?.dispose(); model = makeAudio?(); model?.select(source) }
        .onChange(of: scenePhase) { _, next in if next != .active { review = false; model?.suspend() } }
        .onDisappear { review = false; model?.dispose(); model = nil }
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
    /// Same rule as the r1 consumer view: playing or paused toggles, anything else asks first.
    private func startOrReview() {
        guard let model else { return }
        if model.state == .playing || model.state == .paused { model.toggle() } else { review = true }
    }
    private func skip() {
        guard let nextURL else { return }
        playAfterSelect = true
        select(nextURL)
    }
}
