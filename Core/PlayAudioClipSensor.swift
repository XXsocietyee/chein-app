import Foundation
import Observation

/// Configuration for the backend `audio_clip` sensor task (`minDurationSec` in 1...60).
public struct PlayAudioClipConfiguration: Equatable {
    public let minDurationSeconds: Int

    public init(minDurationSeconds: Int) throws {
        guard (1...60).contains(minDurationSeconds) else { throw PlayExperienceError.invalidAction }
        self.minDurationSeconds = minDurationSeconds
    }

    public init(raw: PlayWireValue) throws {
        guard let duration = raw["minDurationSec"].tolerantInteger else { throw PlayExperienceError.invalidAction }
        try self.init(minDurationSeconds: duration)
    }
}

/// Recorded audio artifact ready for OSS upload and `/api/play/sensor-result` submission.
public struct PlayRecordedAudioClip: Equatable {
    public let bytes: Data
    public let mimeType: String
    public let durationSeconds: Int

    public init(bytes: Data, mimeType: String, durationSeconds: Int) throws {
        guard !bytes.isEmpty, bytes.count <= 20 * 1024 * 1024, (1...60).contains(durationSeconds) else {
            throw PlayExperienceError.invalidAction
        }
        self.bytes = bytes
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
    }
}

@MainActor public protocol PlayAudioClipCapturing: AnyObject {
    func startRecording(onInterruption: @escaping () -> Void) async throws
    func stopRecording() async throws -> PlayRecordedAudioClip
    func cancelRecording()
}

/// Pure-Foundation state machine driving an `audio_clip` sensor challenge capture + upload.
@Observable @MainActor public final class PlayAudioClipModel {
    public enum Phase: String, Equatable {
        case idle, recording, uploading, completed, failed
    }

    public let configuration: PlayAudioClipConfiguration
    public private(set) var phase: Phase = .idle
    public private(set) var elapsedSeconds: Int = 0
    public private(set) var recordedClip: PlayRecordedAudioClip?
    public private(set) var uploadedURL: String?
    public private(set) var failureReason: String?

    private let capturer: any PlayAudioClipCapturing
    private var timerTask: Task<Void, Never>?

    public init(configuration: PlayAudioClipConfiguration, capturer: any PlayAudioClipCapturing) {
        self.configuration = configuration
        self.capturer = capturer
    }

    public var meetsMinimumDuration: Bool {
        (recordedClip?.durationSeconds ?? elapsedSeconds) >= configuration.minDurationSeconds
    }

    public var sourcePayload: [String: PlayWireValue]? {
        guard phase == .completed,
              let clip = recordedClip,
              clip.durationSeconds >= configuration.minDurationSeconds,
              clip.durationSeconds <= 60,
              let url = uploadedURL,
              PlayExperienceService.validHTTPS(url) else { return nil }
        return [
            "durationSec": .int(clip.durationSeconds),
            "mediaUrl": .string(url),
        ]
    }

    public func start() async {
        guard phase == .idle || phase == .failed else { return }
        elapsedSeconds = 0
        recordedClip = nil
        uploadedURL = nil
        failureReason = nil
        do {
            try await capturer.startRecording { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleInterruption()
                }
            }
            phase = .recording
            startTimer()
        } catch {
            capturer.cancelRecording()
            phase = .failed
            failureReason = error.localizedDescription
        }
    }

    /// Exposed for deterministic unit-test timing progression without real clock sleeps.
    public func advanceElapsed(to seconds: Int) {
        guard phase == .recording else { return }
        elapsedSeconds = max(0, min(60, seconds))
    }

    public func stopAndUpload(using upload: @escaping (Data, String) async throws -> String) async {
        guard phase == .recording else { return }
        timerTask?.cancel()
        timerTask = nil
        do {
            let clip = try await capturer.stopRecording()
            recordedClip = clip
            elapsedSeconds = clip.durationSeconds
            guard clip.durationSeconds >= configuration.minDurationSeconds else {
                phase = .failed
                failureReason = "duration_below_minimum"
                return
            }
            phase = .uploading
            let url = try await upload(clip.bytes, clip.mimeType)
            guard PlayExperienceService.validHTTPS(url) else {
                phase = .failed
                failureReason = "invalid_media_url"
                return
            }
            uploadedURL = url
            phase = .completed
        } catch {
            capturer.cancelRecording()
            phase = .failed
            failureReason = error.localizedDescription
        }
    }

    public func reset() {
        timerTask?.cancel()
        timerTask = nil
        capturer.cancelRecording()
        phase = .idle
        elapsedSeconds = 0
        recordedClip = nil
        uploadedURL = nil
        failureReason = nil
    }

    private func handleInterruption() {
        guard phase == .recording else { return }
        timerTask?.cancel()
        timerTask = nil
        capturer.cancelRecording()
        phase = .failed
        failureReason = "interrupted"
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self, self.phase == .recording else { return }
                if self.elapsedSeconds < 60 {
                    self.elapsedSeconds += 1
                }
            }
        }
    }
}
