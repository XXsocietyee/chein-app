import SwiftUI
import AVFoundation
import UIKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// PLAYPOI-1: pages/play/poi-challenge `onShoot` — shoot with the camera, upload (api/common/uploadOSS through the
/// scoped retained-image uploader), and only then count the photo step as done. No URL is ever typed by hand.
/// Without an uploader (writes not approved in this build) the step stays visible but disabled with an honest note.
@MainActor struct ChallengePOIPhotoCapture: View {
    /// MP lead: `photoRequireDesc` ?? 拍下你到达这里的样子.
    let lead: String?
    let uploader: (any RetainedImageUploading)?
    let confirmed: Bool
    let onUploaded: (String) -> Void
    @Environment(\.cyPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingCamera = false
    @State private var uploading = false
    @State private var failure: LocalizedStringKey?
    @State private var cameraDenied = false
    @State private var generation = 0

    private var canShoot: Bool { uploader?.isConfigured == true && uploader?.scope != nil && !uploading }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            // MP cy-playkit-qa shot mode: the lead (photoRequireDesc or 拍下你到达这里的样子) is the big line; no step header.
            Group {
                if let lead, !lead.isEmpty { Text(verbatim: lead) } else { Text("playx.poi.photoLead") }
            }
            .cyText(.sectionTitle)
            .foregroundStyle(palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
            if confirmed {
                Label("playx.poi.photoSaved", systemImage: "checkmark.circle.fill")
                    .cyText(.bodyCompact)
                    .foregroundStyle(palette.success)
                    .accessibilityIdentifier("playx.poi.photoSaved")
            }
            CYPillButton(LocalizedStringKey(uploading ? "playx.poi.photoUploading" : (confirmed ? "playx.poi.photoRetake" : "playx.poi.photoShoot")),
                         style: confirmed ? .secondary : .primary, systemImage: "camera") { requestCamera() }
                .disabled(!canShoot)
                .accessibilityIdentifier("playx.poi.photoShoot")
            if let failure {
                Text(failure).cyText(.bodyCompact).foregroundStyle(palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playx.poi.photoFailed")
            }
            if cameraDenied {
                Text("playx.poi.cameraDenied").cyText(.bodyCompact).foregroundStyle(palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if uploader == nil || uploader?.isConfigured != true {
                Text("playx.poi.photoUnavailable").cyText(.meta).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playx.poi.photoUnavailable")
            }
            Text("playx.poi.photoPrivacy").cyText(.meta).foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cyDomainCard()
        .fullScreenCover(isPresented: $showingCamera) {
            let ticket = generation
            RoamNativeStampCamera { result in
                guard ticket == generation, scenePhase == .active else { return }
                showingCamera = false
                switch result {
                case .success(let image): if let image { Task { await upload(image, ticket: ticket) } }
                case .failure: failure = "playx.poi.cameraFailed"
                }
            }
            .ignoresSafeArea()
        }
        .onDisappear { generation += 1 }
    }

    private func requestCamera() {
        guard canShoot, !showingCamera else { return }
        failure = nil
        generation += 1
        let ticket = generation
        Task { @MainActor in
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { failure = "playx.poi.cameraFailed"; return }
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .denied || status == .restricted { cameraDenied = true; return }
            cameraDenied = false
            var granted = status == .authorized
            if status == .notDetermined {
                guard await CYPermissionSystemPrompt.precede(.camera) else { return }
                granted = await AVCaptureDevice.requestAccess(for: .video)
            }
            guard ticket == generation, scenePhase == .active else { return }
            if granted { showingCamera = true } else { cameraDenied = true }
        }
    }

    private func upload(_ image: RetainedSelectedImage, ticket: Int) async {
        guard let uploader, let scope = uploader.scope, !uploading else { return }
        uploading = true
        defer { uploading = false }
        do {
            let uploaded = try await uploader.upload(RetainedImageUploadReview(scope: scope, selection: image))
            guard ticket == generation else { return }
            onUploaded(uploaded.url.absoluteString)
        } catch {
            guard ticket == generation else { return }
            // MP: 照片没有上传成功，请重拍
            failure = "playx.poi.photoUploadFailed"
        }
    }
}

private struct ChallengePOIPhotoUploaderKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int) -> (any RetainedImageUploading)?)? = nil
}
extension EnvironmentValues {
    /// Host-supplied scoped uploader for a POI challenge photo; nil keeps the photo step disabled.
    var challengePOIPhotoUploader: (@MainActor (Int) -> (any RetainedImageUploading)?)? {
        get { self[ChallengePOIPhotoUploaderKey.self] }
        set { self[ChallengePOIPhotoUploaderKey.self] = newValue }
    }
}

extension AppSession {
    /// PLAYPOI-1 / RPOI-1: a POI photo uses the same reviewed live-write approval as the stamp upload. Callers pass it
    /// only where the matching submit is live, so a photo never uploads for a submit that cannot be sent.
    func makeChallengePOIPhotoUploader(poiID: Int) -> (any RetainedImageUploading)? {
        guard poiID > 0, stampCameraEnabled,
              let mediaScope = roamMediaScope, let configuration = regionalConfiguration?.apiConfiguration,
              let credentials = currentRetainedImageCredentials,
              let scope = try? RetainedImageScope(accountID: mediaScope.accountID, epoch: mediaScope.epoch,
                realm: mediaScope.realm, destination: .roamPoster(poiID: poiID), namespace: mediaScope.namespace),
              let wire = compositionTransport.makeRoamLiveWriteTransport() else { return nil }
        let origins = RetainedImageOrigin.configured(apiBase: configuration.baseURL,
            extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String)
        return RetainedImageHTTPUploader(configuration: configuration, transport: wire, enabled: true, approvedOrigins: origins,
            currentScope: { [weak self] in
                guard let self, self.currentRetainedImageCredentials == credentials, self.roamMediaScope == mediaScope else { return nil }
                return scope
            },
            token: { [weak self] in self?.currentRetainedImageCredentials == credentials ? credentials.token : nil })
    }
}
