import AVFoundation
import Foundation

/// MP theme-cast.js `_castRecorder` / `toggleCastRecord` / `_onCastRecStop` for 编辑角色 用自己的声音录:
/// one mono take of at most 60 s (`REC_MAX_MS`); under 0.5 s is 录音太短; a call, a route loss or leaving the app
/// stops the take and keeps it (MP L03-203 `onInterruptionBegin` → stop). Starting while a take runs drops that take
/// and does not start a new one (MP L03-203). Nothing records until the person taps the row.
@MainActor final class ProjectEditCastVoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum Failure: Error, Equatable {
        /// MP 录音没有开始，请检查麦克风权限
        case notStarted
        /// MP 录音太短，请再录一次
        case tooShort
        case unreadable
    }
    static let maxSeconds: TimeInterval = 60
    static let minSeconds: TimeInterval = 0.5

    @Published private(set) var isRecording = false
    private let lifecycle = NativeAudioLifecycleObservation(notifications: .default)
    private var recorder: AVAudioRecorder?
    private var url: URL?
    private var discard = false
    private var starting = false
    private var active = false
    private var finished: ((Result<ProjectStorySelectedAudio, Failure>) -> Void)?

    func start(finished: @escaping (Result<ProjectStorySelectedAudio, Failure>) -> Void) async {
        if recorder != nil || starting {
            stop(discard: true)
            return
        }
        starting = true
        defer { starting = false }
        let allowed: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted: allowed = true
        case .denied: allowed = false
        default:
            allowed = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
        guard allowed, !Task.isCancelled else {
            finished(.failure(.notStarted))
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            active = true
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("cast-voice-" + UUID().uuidString + ".m4a")
            let value = try AVAudioRecorder(url: target, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
                                                                   AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96_000])
            url = target
            recorder = value
            value.delegate = self
            discard = false
            self.finished = finished
            lifecycle.observe { [weak self] signal in
                guard let self else { return }
                let owns = AVAudioSession.sharedInstance().category == .playAndRecord
                guard PlatformAudioLifecyclePolicy.action(for: signal, ownsConfiguration: owns) == .stop else { return }
                self.stop(discard: false)
            }
            guard value.record(forDuration: Self.maxSeconds) else { throw Failure.notStarted }
            isRecording = true
        } catch {
            reset()
            finished(.failure(.notStarted))
        }
    }

    /// Tap while recording (keep the take) or close / cancel the sheet (`discard`, MP `_stopCastRecording(true)`).
    func stop(discard: Bool) {
        guard let recorder else { return }
        if discard { self.discard = true }
        recorder.delegate = nil
        recorder.stop()
        complete()
    }

    private func complete() {
        let callback = finished
        var result: Result<ProjectStorySelectedAudio, Failure>?
        if !discard, let url { result = Self.read(url) }
        reset()
        if let result { callback?(result) }
    }

    private static func read(_ file: URL) -> Result<ProjectStorySelectedAudio, Failure> {
        guard let audio = try? AVAudioFile(forReading: file), audio.fileFormat.sampleRate > 0 else { return .failure(.tooShort) }
        let duration = Double(audio.length) / audio.fileFormat.sampleRate
        guard duration >= minSeconds else { return .failure(.tooShort) }
        guard let bytes = try? Data(contentsOf: file), !bytes.isEmpty else { return .failure(.unreadable) }
        var offset = 0
        do {
            let picked = try ProjectStoryAudioCapture.read(filename: "voice.m4a", reportedByteCount: bytes.count, checkCancellation: {},
                readChunk: { count in
                    let end = min(offset + count, bytes.count)
                    defer { offset = end }
                    return bytes.subdata(in: offset..<end)
                })
            return .success(picked)
        } catch {
            return .failure(.unreadable)
        }
    }

    private func reset() {
        lifecycle.invalidate()
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
        finished = nil
        discard = false
        isRecording = false
        if active {
            active = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// The 60 s limit ends the take the same way as a tap (MP `duration: REC_MAX_MS` → onStop).
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            recorder.delegate = nil
            if flag {
                self.complete()
            } else {
                let callback = self.finished
                self.reset()
                callback?(.failure(.notStarted))
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            let callback = self.finished
            self.reset()
            callback?(.failure(.unreadable))
        }
    }
}

/// MP theme-cast.js `_onCastRecStop` upload: the take → the editor's approved `api/common/uploadOSS`
/// (`ProjectStoryAudioUploading`, the same path as chapter narration) → the reference for `voice.url`.
public struct ProjectEditCastVoiceUpload {
    public let upload: @MainActor (ProjectStorySelectedAudio) async throws -> String

    public init(upload: @escaping @MainActor (ProjectStorySelectedAudio) async throws -> String) {
        self.upload = upload
    }

    /// nil when the editor cannot upload audio (read-only, no session, upload off): 用自己的声音录 is not shown.
    @MainActor static func make(_ model: ProjectEditModel) -> ProjectEditCastVoiceUpload? {
        guard !model.coordinator.isReadOnly, let source = model.coordinator.storyAudioSource,
              let session = model.coordinator.session,
              source.isCurrent(session: session), source.permitsPicker(session: session) else { return nil }
        return ProjectEditCastVoiceUpload { audio in
            guard source.isCurrent(session: session) else { throw ProjectStoryImageFailure.changedContext }
            return try await source.upload(audio, attemptID: UUID(), session: session).reference
        }
    }
}
