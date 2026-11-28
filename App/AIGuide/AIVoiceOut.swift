import Foundation
import AVFoundation
import Observation

/// Voice out for NPC replies and guide lines: on-device `AVSpeechSynthesizer`, only after the player taps "Read aloud".
/// The text is the reviewed text already on screen; nothing is sent anywhere. Server TTS (`NpcChatResp.audioUrl`)
/// belongs to the deferred merchant voice clone and is not used here.
@MainActor @Observable final class AIVoiceOut: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var speakingID: String?
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(id: String, text: String) {
        if speakingID == id { stop(); return }
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLanguage(for: trimmed))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        speakingID = id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        finish()
    }

    private func finish() {
        speakingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Chinese characters read with a Mandarin voice, everything else with English.
    nonisolated static func voiceLanguage(for text: String) -> String {
        let han = text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        return han ? "zh-CN" : "en-US"
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
