import Foundation

/// fix-1128b #21 (J-11b/J-11c): the Release evidence source for the in-store (探店日) page. It runs the play
/// device coordinator on the player's tap: the scanner for the store code (MP `scanCode`), or the camera and the
/// `api/common/uploadOSS` upload for the proof photo (MP `takePhoto` → `uploadProof`). The device coordinator is
/// made on first use so opening the page never touches the camera. Each value is read once.
@MainActor final class PlayStoreDayDeviceEvidence: PlayStoreDayCapturingEvidenceSource {
    private let makeDevice: @MainActor () -> PlayDeviceCaptureCoordinator
    private var device: PlayDeviceCaptureCoordinator?
    private var code: String?
    private var pictureURL: String?

    init(makeDevice: @escaping @MainActor () -> PlayDeviceCaptureCoordinator) {
        self.makeDevice = makeDevice
    }

    private func resolvedDevice() -> PlayDeviceCaptureCoordinator {
        if let device { return device }
        let made = makeDevice()
        device = made
        return made
    }

    func storeCode() -> String? {
        let value = code
        code = nil
        return value
    }

    func proofPictureURL() -> String? {
        let value = pictureURL
        pictureURL = nil
        return value
    }

    func captureStoreCode() async -> PlayStoreDayCaptureResult {
        code = nil
        let device = resolvedDevice()
        guard device.supports(.scan) else { return .failed }
        await device.capture(.scan)
        if case .scan(let value)? = device.output {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .failed }
            code = trimmed
            return .captured
        }
        return device.issue == nil ? .cancelled : .failed
    }

    func captureProofPicture() async -> PlayStoreDayCaptureResult {
        pictureURL = nil
        let device = resolvedDevice()
        guard device.supports(.photo) else { return .failed }
        await device.capture(.photo)
        guard case .photo? = device.output else { return device.issue == nil ? .cancelled : .failed }
        await device.uploadPhoto()
        guard case .photo(let uploadedURL)? = device.reviewedPhoto() else { return .failed }
        pictureURL = uploadedURL
        return .captured
    }
}
