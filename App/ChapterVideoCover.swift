import AVFoundation
import AVKit
import Combine
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// VIDEO-r11-1: one chapter video to show (MP `pages/play/chapter-video.js` F06). Both the film and the poster are
/// required, as on the MP (`!chapter.videoUrl || !chapter.videoPosterUrl` → no video).
struct ChapterVideoItem: Identifiable, Equatable {
    let id: String
    let video: URL
    let poster: URL
    /// Approved author-media hosts only; http upgrades to https (MP `secureOwnMedia`).
    static func make(chapterID: Int, video: String?, poster: String?, approvedHosts: Set<String>) -> ChapterVideoItem? {
        guard let video = PlayBackgroundMusic.playableURL(video, approvedHosts: approvedHosts),
              let poster = PlayBackgroundMusic.playableURL(poster, approvedHosts: approvedHosts) else { return nil }
        var file = URLComponents(url: video, resolvingAgainstBaseURL: false); file?.query = nil
        return ChapterVideoItem(id: "\(chapterID)|\(file?.url?.absoluteString ?? video.absoluteString)", video: video, poster: poster)
    }
}

/// Once per chapter video per app run (MP `_seenChapterVideos`).
@MainActor enum ChapterVideoSeen {
    private static var seen = Set<String>()
    static func claim(_ id: String) -> Bool { seen.insert(id).inserted }
}

/// Full-screen muted autoplay with 跳过 and 开声音 / 关声音. Closes on end, on a playback error, or when the film is
/// not ready 5 s after opening (MP `_armChapterVideoTimeout`). Muted playback leaves music and narration alone; sound on
/// ducks the play music until the film closes.
@MainActor struct ChapterVideoCover: View {
    let item: ChapterVideoItem
    let onClose: () -> Void
    @State private var player: AVPlayer?
    @State private var muted = true
    @State private var ready = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                ChapterVideoSurface(player: player).ignoresSafeArea()
            }
            if !ready {
                AsyncImage(url: item.poster) { image in
                    image.resizable().scaledToFit()
                } placeholder: { ProgressView().tint(.white) }
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("chapterVideo.skip", action: close)
                .buttonStyle(.borderedProminent)
                .padding()
                .accessibilityIdentifier("chapterVideo.skip")
        }
        .overlay(alignment: .bottomTrailing) {
            Button(muted ? LocalizedStringKey("chapterVideo.soundOn") : LocalizedStringKey("chapterVideo.soundOff"),
                   systemImage: muted ? "speaker.slash" : "speaker.wave.2") {
                muted.toggle()
                player?.isMuted = muted
                PlayBackgroundMusic.shared.duck("chapterVideo", !muted)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .padding()
            .accessibilityIdentifier("chapterVideo.sound")
        }
        .onAppear(perform: start)
        .onDisappear {
            player?.pause()
            PlayBackgroundMusic.shared.duck("chapterVideo", false)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            if let item = note.object as? AVPlayerItem, item === player?.currentItem { close() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)) { note in
            if let item = note.object as? AVPlayerItem, item === player?.currentItem { close() }
        }
        .task {
            // Poll readiness briefly; give up after 5 s like the MP.
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                if player?.currentItem?.status == .readyToPlay { ready = true; return }
                if player?.currentItem?.status == .failed { close(); return }
            }
            close()
        }
    }

    private func start() {
        guard player == nil else { return }
        let next = AVPlayer(url: item.video)
        next.isMuted = true
        player = next
        next.play()
    }

    private func close() {
        player?.pause()
        PlayBackgroundMusic.shared.duck("chapterVideo", false)
        onClose()
    }
}

/// A film without playback controls (the MP `<video controls=false>`).
private struct ChapterVideoSurface: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}
