import MediaPlayer
import SwiftUI

/// Native r2 story audio (L5 · P-083 / P-084). App-only seam over the loaded clip: position, length, speed.
/// `PlatformAudioPlayback` (Core) keeps the state machine and consent; this only reads and moves the playhead.
@MainActor protocol PlatformAudioTransporting: AnyObject {
    var elapsed: TimeInterval { get }
    var duration: TimeInterval { get }
    var playbackRate: Float { get }
    func seek(to time: TimeInterval)
    func setPlaybackRate(_ rate: Float)
}

/// The driver that is currently audible. One shared audio session means at most one clip plays; the story player
/// reads it only while its own `PlatformAudioPlayback` is playing or paused, so another view's audio is never moved.
@MainActor enum PlatformAudioTransportRegistry {
    static weak var active: (any PlatformAudioTransporting)?
}

/// Speeds offered by the full player (Podcasts / Books order).
enum NR2StoryAudioSpeed {
    static let all: [Float] = [0.75, 1, 1.25, 1.5, 2]
    static func label(_ rate: Float) -> String {
        let value = (rate * 100).rounded() / 100
        return value == value.rounded() ? String(format: "%.0f×", value) : String(format: "%g×", value)
    }
}

/// Lock Screen / Control Center / headphones (P-083). Installs Now Playing info and remote commands while the story
/// player has a clip loaded, and removes both when it stops. Every handler runs the same actions as the on-screen
/// buttons; nothing here can start a clip the listener has not already started (play needs a paused clip).
@MainActor final class NR2StoryNowPlaying {
    struct Actions {
        var toggle: @MainActor () -> Void
        var next: (@MainActor () -> Void)?
    }
    static let shared = NR2StoryNowPlaying()
    private var targets: [(MPRemoteCommand, Any)] = []
    private var actions: Actions?
    private var isPlaying = false

    /// `state` playing / paused publishes; anything else clears.
    func update(state: PlatformAudioState, title: String?, chapter: String?, actions: Actions) {
        if state == .loading { return } // paused → loading → playing keeps the Lock Screen card in place
        guard state == .playing || state == .paused else { clear(); return }
        self.actions = actions
        isPlaying = state == .playing
        install()
        publish(title: title, chapter: chapter)
    }

    /// After a seek or speed change: refresh elapsed time and rate so the system clock stays right.
    func refreshPosition() {
        guard actions != nil, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        let transport = PlatformAudioTransportRegistry.active
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = transport?.elapsed ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(transport?.playbackRate ?? 1) : 0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = Double(transport?.playbackRate ?? 1)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        guard actions != nil || !targets.isEmpty else { return }
        actions = nil
        isPlaying = false
        for (command, target) in targets { command.removeTarget(target) }
        targets.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    private func publish(title: String?, chapter: String?) {
        let transport = PlatformAudioTransportRegistry.active
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title.flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("platform.audio.title", locale: .current),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: transport?.elapsed ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(transport?.playbackRate ?? 1) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(transport?.playbackRate ?? 1)
        ]
        if let chapter, !chapter.isEmpty { info[MPMediaItemPropertyAlbumTitle] = chapter }
        if let duration = transport?.duration, duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    private func install() {
        guard targets.isEmpty else {
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = actions?.next != nil
            return
        }
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        add(center.playCommand) { owner in
            guard !owner.isPlaying else { return .success }
            owner.actions?.toggle(); return .success
        }
        add(center.pauseCommand) { owner in
            guard owner.isPlaying else { return .success }
            owner.actions?.toggle(); return .success
        }
        add(center.togglePlayPauseCommand) { owner in owner.actions?.toggle(); return .success }
        add(center.nextTrackCommand) { owner in
            guard let next = owner.actions?.next else { return .noActionableNowPlayingItem }
            next(); return .success
        }
        center.nextTrackCommand.isEnabled = actions?.next != nil
        add(center.skipForwardCommand) { owner in owner.skip(by: 15) }
        add(center.skipBackwardCommand) { owner in owner.skip(by: -15) }
        let position = center.changePlaybackPositionCommand
        let target = position.addTarget { event in
            MainActor.assumeIsolated {
                guard let event = event as? MPChangePlaybackPositionCommandEvent,
                      let transport = PlatformAudioTransportRegistry.active else { return .commandFailed }
                transport.seek(to: event.positionTime)
                NR2StoryNowPlaying.shared.refreshPosition()
                return .success
            }
        }
        position.isEnabled = true
        targets.append((position, target))
    }

    private func skip(by seconds: TimeInterval) -> MPRemoteCommandHandlerStatus {
        guard let transport = PlatformAudioTransportRegistry.active else { return .commandFailed }
        transport.seek(to: transport.elapsed + seconds)
        refreshPosition()
        return .success
    }

    private func add(_ command: MPRemoteCommand,
                     handler: @escaping @MainActor (NR2StoryNowPlaying) -> MPRemoteCommandHandlerStatus) {
        command.isEnabled = true
        let target = command.addTarget { _ in
            MainActor.assumeIsolated { handler(NR2StoryNowPlaying.shared) }
        }
        targets.append((command, target))
    }
}

/// `m:ss` / `h:mm:ss` for the scrubber labels; VoiceOver reads the spelled-out duration instead.
enum NR2StoryAudioTime {
    static func text(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.isFinite ? seconds : 0))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
    static func spoken(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .full
        return formatter.string(from: max(0, seconds.isFinite ? seconds : 0)) ?? ""
    }
}

/// Thin playhead under the mini player (Podcasts / Music). Updates twice a second while playing.
@MainActor struct NR2StoryAudioProgress: View {
    let isActive: Bool
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let transport = isActive ? PlatformAudioTransportRegistry.active : nil
            let duration = transport?.duration ?? 0
            ProgressView(value: duration > 0 ? min(transport?.elapsed ?? 0, duration) : 0, total: max(duration, 1))
                .progressViewStyle(.linear)
                .accessibilityHidden(true)
        }
    }
}

/// Full player (P-084): a medium / large system sheet like Podcasts' Now Playing. Scrubber with elapsed and
/// remaining time, −15 s / play-pause / +15 s, next clip and a speed menu. Same model and actions as the mini player.
@MainActor struct NR2StoryFullAudioPlayer: View {
    let title: String?
    let state: PlatformAudioState
    let canSkip: Bool
    let togglePlay: () -> Void
    let skipClip: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrubbing: TimeInterval?
    @State private var rate: Float = PlatformAudioTransportRegistry.active?.playbackRate ?? 1
    @State private var seekTick = 0

    private var isLoaded: Bool { state == .playing || state == .paused }
    private var transport: (any PlatformAudioTransporting)? { isLoaded ? PlatformAudioTransportRegistry.active : nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: state == .playing && !reduceMotion)
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Group {
                        if let title, !title.isEmpty { Text(verbatim: title) } else { Text("platform.audio.title") }
                    }
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    Text(LocalizedStringKey("platform.audio." + String(describing: state)))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .accessibilityIdentifier("play.nr2.reader.player.state")
                }
                scrubber
                controls
                speedMenu
            }
            .padding()
            .frame(maxWidth: .infinity)
            .navigationTitle(Text("play.nr2.reader.player.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("play.nr2.reader.player.done") { dismiss() }
                        .accessibilityIdentifier("play.nr2.reader.player.done")
                }
            }
            .sensoryFeedback(.selection, trigger: seekTick)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("play.nr2.reader.player")
    }

    private var scrubber: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let duration = transport?.duration ?? 0
            let position = min(scrubbing ?? transport?.elapsed ?? 0, max(duration, 0))
            VStack(spacing: 4) {
                Slider(value: Binding(get: { position }, set: { scrubbing = $0 }),
                       in: 0...max(duration, 1),
                       onEditingChanged: { editing in
                           guard !editing, let target = scrubbing else { return }
                           transport?.seek(to: target)
                           scrubbing = nil
                           seekTick += 1
                           NR2StoryNowPlaying.shared.refreshPosition()
                       })
                .disabled(transport == nil || duration <= 0)
                .accessibilityLabel(Text("play.nr2.reader.player.position"))
                .accessibilityValue(Text(verbatim: NR2StoryAudioTime.spoken(position)))
                .accessibilityIdentifier("play.nr2.reader.player.scrubber")
                HStack {
                    Text(verbatim: NR2StoryAudioTime.text(position))
                        .accessibilityLabel(Text("play.nr2.reader.player.elapsed \(NR2StoryAudioTime.spoken(position))"))
                    Spacer()
                    Text(verbatim: "-" + NR2StoryAudioTime.text(max(0, duration - position)))
                        .accessibilityLabel(Text("play.nr2.reader.player.remaining \(NR2StoryAudioTime.spoken(max(0, duration - position)))"))
                }
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 32) { controlButtons }
            VStack(spacing: 16) { controlButtons }
        }
    }

    @ViewBuilder private var controlButtons: some View {
        Button { jump(-15) } label: {
            Image(systemName: "gobackward.15").font(.title)
        }
        .buttonStyle(.borderless)
        .disabled(transport == nil)
        .accessibilityLabel(Text("play.nr2.reader.player.back15"))
        .accessibilityIdentifier("play.nr2.reader.player.back15")
        Button(action: togglePlay) {
            Image(systemName: state == .playing ? "pause.circle.fill" : "play.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .disabled(state == .loading || state == .disposed)
        .accessibilityLabel(Text(state == .playing ? "platform.audio.pause" : "platform.audio.play"))
        .accessibilityIdentifier("play.nr2.reader.player.toggle")
        Button { jump(15) } label: {
            Image(systemName: "goforward.15").font(.title)
        }
        .buttonStyle(.borderless)
        .disabled(transport == nil)
        .accessibilityLabel(Text("play.nr2.reader.player.forward15"))
        .accessibilityIdentifier("play.nr2.reader.player.forward15")
        Button(action: skipClip) {
            Image(systemName: "forward.end.fill").font(.title2)
        }
        .buttonStyle(.borderless)
        .disabled(!canSkip)
        .accessibilityLabel(Text("play.nr2.reader.audio.skip"))
        .accessibilityIdentifier("play.nr2.reader.player.next")
    }

    private var speedMenu: some View {
        Menu {
            Picker(selection: Binding(get: { rate }, set: { setRate($0) })) {
                ForEach(NR2StoryAudioSpeed.all, id: \.self) { value in
                    Text(verbatim: NR2StoryAudioSpeed.label(value)).tag(value)
                }
            } label: {
                Text("play.nr2.reader.player.speed")
            }
        } label: {
            Label {
                Text("play.nr2.reader.player.speedValue \(NR2StoryAudioSpeed.label(rate))")
            } icon: {
                Image(systemName: "gauge.with.dots.needle.33percent")
            }
            .contentTransition(.numericText())
        }
        .buttonStyle(.bordered)
        .disabled(transport == nil)
        .accessibilityIdentifier("play.nr2.reader.player.speed")
    }

    private func jump(_ seconds: TimeInterval) {
        guard let transport else { return }
        transport.seek(to: transport.elapsed + seconds)
        seekTick += 1
        NR2StoryNowPlaying.shared.refreshPosition()
    }

    private func setRate(_ value: Float) {
        transport?.setPlaybackRate(value)
        if reduceMotion { rate = value } else { withAnimation(.smooth) { rate = value } }
        NR2StoryNowPlaying.shared.refreshPosition()
    }
}
