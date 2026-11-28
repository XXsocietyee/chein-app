import Foundation
import AVFoundation

/// fix/1128c: the Release voice path for the shop NPC (MP pages/play/index.js:2328 records, then POSTs
/// `api/ai/npc/voice-chat`). The system microphone prompt appears only after the player taps the mic button;
/// recording starts once permission is granted, and a denial ends the recording state without sending anything.
@MainActor final class ShopNPCPermissionedCapture: ShopNPCVoiceCapturing {
    private let inner: ShopNPCAVCapture
    private var waiting = false
    private var cancelled = false

    init(inner: ShopNPCAVCapture) {
        self.inner = inner
    }

    convenience init() { self.init(inner: ShopNPCAVCapture()) }

    func startAfterExplicitMicrophoneIntent(grants: ShopNPCGrants, onEnded: @escaping () -> Void) throws {
        guard grants.voiceAllowed, grants.microphone, !waiting else { throw ShopNPCFailure.disabled }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            try inner.startAfterExplicitMicrophoneIntent(grants: grants, onEnded: onEnded)
        case .undetermined:
            waiting = true
            cancelled = false
            // Copy the value out of the main-actor parameter before the Sendable permission callback.
            let capturedGrants = grants
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                Task { @MainActor in
                    self?.resume(allowed: allowed, grants: capturedGrants, onEnded: onEnded)
                }
            }
        default:
            throw ShopNPCFailure.disabled
        }
    }

    private func resume(allowed: Bool, grants: ShopNPCGrants, onEnded: @escaping () -> Void) {
        waiting = false
        guard allowed, !cancelled else { onEnded(); return }
        do { try inner.startAfterExplicitMicrophoneIntent(grants: grants, onEnded: onEnded) }
        catch { onEnded() }
    }

    func stopForReview() throws -> ShopNPCVoiceClip {
        guard !waiting else { cancel(); throw ShopNPCFailure.invalid }
        return try inner.stopForReview()
    }

    func cancel() {
        cancelled = true
        inner.cancel()
    }
}

enum ShopNPCVoiceCaptureFactory {
    /// A capture only when the composition granted voice; otherwise the mic button stays disabled.
    @MainActor static func make(for grants: ShopNPCGrants) -> (any ShopNPCVoiceCapturing)? {
        guard grants.voiceAllowed, grants.microphone else { return nil }
        return ShopNPCPermissionedCapture()
    }
}
