import AVFoundation
import SwiftUI

/// Live `AVAudioRecorder` driver backing `audio_clip` node sensors.
@MainActor final class PlayNativeAudioClipCapturer: NSObject, PlayAudioClipCapturing, AVAudioRecorderDelegate {
    private let lifecycle = NativeAudioLifecycleObservation(notifications: .default)
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var sessionActive = false
    private var onInterruption: (() -> Void)?

    func startRecording(onInterruption: @escaping () -> Void) async throws {
        cancelRecording()
        let session = AVAudioSession.sharedInstance()
        let allowed: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted: allowed = true
        case .denied: allowed = false
        default:
            allowed = await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
        guard allowed else { throw PlayExperienceError.disabled }
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)
        sessionActive = true
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("play-audio-clip", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        let target = directory.appendingPathComponent(UUID().uuidString + ".m4a")
        recordingURL = target
        let value = try AVAudioRecorder(
            url: target,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 48_000,
            ]
        )
        value.delegate = self
        guard value.record(forDuration: 60) else {
            cancelRecording()
            throw PlayExperienceError.invalidAction
        }
        recorder = value
        self.onInterruption = onInterruption
        lifecycle.observe { [weak self] signal in
            guard let self else { return }
            if PlatformAudioLifecyclePolicy.action(for: signal, ownsConfiguration: AVAudioSession.sharedInstance().category == .playAndRecord) == .stop {
                self.onInterruption?()
            }
        }
    }

    func stopRecording() async throws -> PlayRecordedAudioClip {
        guard let recorder, let url = recordingURL else { throw PlayExperienceError.invalidAction }
        recorder.delegate = nil
        recorder.stop()
        lifecycle.invalidate()
        let audio = try AVAudioFile(forReading: url)
        let sampleRate = max(1, audio.fileFormat.sampleRate)
        let seconds = max(1, min(60, Int((Double(audio.length) / sampleRate).rounded())))
        let data = try Data(contentsOf: url)
        cleanupFilesAndSession()
        return try PlayRecordedAudioClip(bytes: data, mimeType: "audio/m4a", durationSeconds: seconds)
    }

    func cancelRecording() {
        recorder?.delegate = nil
        recorder?.stop()
        lifecycle.invalidate()
        onInterruption = nil
        cleanupFilesAndSession()
    }

    private func cleanupFilesAndSession() {
        recorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        if sessionActive {
            sessionActive = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            self?.onInterruption?()
        }
    }
}

/// Interactive audio-clip sensor recorder view for `node.sensorType == "audio_clip"`.
@MainActor struct PlayAudioClipStreamView: View {
    @State private var model: PlayAudioClipModel
    let canWrite: Bool
    let uploadAudio: (Data, String) async throws -> String
    let onSubmit: ([String: PlayWireValue]) -> Void

    init(
        configuration: PlayAudioClipConfiguration,
        canWrite: Bool,
        uploadAudio: @escaping (Data, String) async throws -> String,
        onSubmit: @escaping ([String: PlayWireValue]) -> Void
    ) {
        self._model = State(initialValue: PlayAudioClipModel(configuration: configuration, capturer: PlayNativeAudioClipCapturer()))
        self.canWrite = canWrite
        self.uploadAudio = uploadAudio
        self.onSubmit = onSubmit
    }

    var body: some View {
        Form {
            Section("playx.audioClip.title") {
                LabeledContent("playx.audioClip.minimum") {
                    Text(verbatim: "\(model.configuration.minDurationSeconds) s")
                }
                .accessibilityIdentifier("playx.audioClip.minimum")
                LabeledContent("playx.audioClip.elapsed") {
                    Text(verbatim: "\(model.elapsedSeconds) s")
                }
                .accessibilityIdentifier("playx.audioClip.elapsed")
                CYStatusChip(
                    LocalizedStringKey(phaseKey),
                    tone: statusTone,
                    systemImage: statusIcon
                )
                .accessibilityIdentifier("playx.audioClip.phase")
            }

            Section {
                switch model.phase {
                case .idle, .failed:
                    if model.phase == .failed {
                        Text("playx.audioClip.retryHint")
                            .cyText(.meta)
                            .accessibilityIdentifier("playx.audioClip.retryHint")
                    }
                    CYPillButton("playx.audioClip.start") {
                        Task { await model.start() }
                    }
                    .disabled(!canWrite)
                    .accessibilityLabel(Text("playx.audioClip.start"))
                    .accessibilityHint(Text("playx.audioClip.start.hint"))
                    .accessibilityIdentifier("playx.audioClip.start")
                case .recording:
                    CYPillButton("playx.audioClip.stopAndUpload") {
                        Task { await model.stopAndUpload(using: uploadAudio) }
                    }
                    .disabled(!canWrite || !model.meetsMinimumDuration)
                    .accessibilityLabel(Text("playx.audioClip.stopAndUpload"))
                    .accessibilityHint(Text("playx.audioClip.stop.hint"))
                    .accessibilityIdentifier("playx.audioClip.stop")
                    Button("playx.audioClip.cancel", role: .cancel) {
                        model.reset()
                    }
                    .accessibilityLabel(Text("playx.audioClip.cancel"))
                    .accessibilityIdentifier("playx.audioClip.cancel")
                case .uploading:
                    CYSkeleton(label: "playx.loading")
                        .accessibilityIdentifier("playx.audioClip.uploading")
                case .completed:
                    if let payload = model.sourcePayload {
                        CYPillButton("playx.review") {
                            onSubmit(payload)
                        }
                        .disabled(!canWrite)
                        .accessibilityLabel(Text("playx.review"))
                        .accessibilityIdentifier("playx.audioClip.review")
                    }
                }
            }
        }
        .cyPageTitle("playx.audioClip.title")
        .onChange(of: model.phase) { _, phase in
            UIKitHapticsDriver.ensureInstalled()
            switch phase {
            case .recording:
                HapticsService.shared.play(.selection)
            case .completed:
                HapticsService.shared.play(.sensorShoutComplete)
            case .failed:
                HapticsService.shared.play(.wrongAnswer)
            case .idle, .uploading:
                break
            }
        }
        .onDisappear { model.reset() }
    }

    private var statusTone: CYStatusTone {
        switch model.phase {
        case .completed: return .success
        case .failed: return .danger
        case .recording, .uploading: return .info
        case .idle: return .neutral
        }
    }

    private var phaseKey: String {
        switch model.phase {
        case .idle: return "playx.audioClip.phase.idle"
        case .recording: return "playx.audioClip.phase.recording"
        case .uploading: return "playx.audioClip.phase.uploading"
        case .completed: return "playx.audioClip.phase.completed"
        case .failed: return "playx.audioClip.phase.failed"
        }
    }

    private var statusIcon: String {
        switch model.phase {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .recording: return "mic.fill"
        case .uploading: return "arrow.up.circle.fill"
        case .idle: return "waveform"
        }
    }
}
