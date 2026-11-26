import AVFoundation
import SwiftUI
import UIKit

/// Preparation/review is a pushed destination. Camera capture is full-screen and camera-only;
/// no imported image or illustrative picture is ever treated as a captured stamp.
@MainActor struct RoamStampCameraView: View {
    var coordinator: RoamStampCaptureCoordinator? = nil
    var cameraEnabled = false
    var album: RoamStampAlbumContinuation? = nil
    /// 投一张换一张: exchange the created stamp (idempotent on the server). nil hides the step.
    var exchange: (@MainActor (Int) async throws -> RoamStampExchangeReceipt)? = nil
    /// SCAM-2: the MP stamp-camera page has no caption field; only the citystamp route (sticker / sign) writes one.
    var showsCaption = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyCelebrationCenter) private var celebrations
    @Environment(\.cyPalette) private var palette
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @State private var cameraDenied = false
    @State private var showingPriming = false
    @State private var primingAllowed = false
    private enum ExchangePhase: Equatable { case idle, working, failed, done(RoamStampExchangeReceipt) }
    @State private var exchangePhase: ExchangePhase = .idle
    @State private var exchangeStarted = Date()
    private enum Focus: Hashable { case capture, status }
    @AccessibilityFocusState private var focusedControl: Focus?
    /// SCAM-2 (MP-first, owner 2026-11-25): the MP stamp camera has no consent switch and opens the camera at once
    /// (subpackageP3/pages/stamp-camera/index/index.wxml:9-34); iOS still shows its own camera permission prompt.
    @State private var purposeAccepted = true
    @State private var showingCamera = false
    @State private var cameraIssue = false
    @State private var revision = 0
    @State private var captureGeneration = 0
    @State private var work: Task<Void, Never>?
    @State private var localDraft = RoamCityStampDraft()
    @State private var createdStampTarget: RoamCreatedStampTarget?
    /// subpackageP3/pages/stamp-camera page contract: create and exchange stay hidden while their
    /// capability switches are off; the album list path exists only with an album reader.
    private var pageContract: StampCameraPageContract { StampCameraPageContract(hasAlbumReader: album != nil) }
    var body: some View {
        if NativeR2Flags.freeExplore {
            NativeStampCaptureView(coordinator: coordinator, cameraEnabled: cameraEnabled, album: album,
                                   exchange: exchange, showsCaption: showsCaption)
        } else {
            legacyBody
        }
    }
    @ViewBuilder private var legacyBody: some View {
        let _ = revision
        Form {
            Section {
                if !cameraEnabled { Label("media.stamp.disabled", systemImage: "camera.fill") }
                if cameraDenied {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("media.stamp.cameraDenied.title", systemImage: "camera.badge.ellipsis").cyText(.bodyMedium)
                        Text("media.stamp.cameraDenied.message").cyText(.bodyCompact).foregroundStyle(.secondary)
                        Button("roam.poi.location.openSettings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.frame(minHeight: 44).accessibilityIdentifier("media.stamp.openSettings")
                            .accessibilityLabel(Text("roam.poi.location.openSettings"))
                            .accessibilityValue(Text("media.stamp.cameraDenied.title"))
                            .accessibilityHint(Text("media.stamp.cameraDenied.message"))
                    }.accessibilityIdentifier("media.stamp.cameraDenied")
                } else if cameraIssue {
                    Label("media.stamp.cameraIssue", systemImage: "exclamationmark.triangle").foregroundStyle(palette.warning)
                    // Mini-program sc-err: a camera error that cannot open Settings offers 返回上一页.
                    Button("action.back") { dismiss() }.frame(minHeight: 44)
                        .accessibilityIdentifier("media.stamp.cameraIssue.back")
                }
            } footer: { Text("media.stamp.purpose") }
            if showsCaption { captionSection }
            if let coordinator {
                Section {
                    if let bytes = coordinator.selection?.jpeg, let image = UIImage(data: bytes) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 320)
                            .accessibilityLabel(Text("media.stamp.capturedPreview"))
                    }
                    Group {
                        if isBusy { ProgressView(LocalizedStringKey("media.stamp.phase." + phaseKey(coordinator.phase))) }
                        else { CYStatusChip(LocalizedStringKey("media.stamp.phase." + phaseKey(coordinator.phase)), tone: phaseTone(coordinator.phase)) }
                    }.accessibilityFocused($focusedControl, equals: .status)
                    if coordinator.phase == .review {
                        // SCAM-1 (MP-first, owner 2026-11-25): upload and create are one 存入集邮册 step in the MP
                        // (stamp-camera/index/index.js:350-391): upload, then create with the same idempotency key.
                        // On the citystamp route the MP then exchanges at once (citystamp/index.js:267-300).
                        CYPillButton("media.stamp.upload", style: coordinator.pending == nil ? .primary : .secondary) {
                            run {
                                await coordinator.upload()
                                guard pageContract.showsCreate, coordinator.pending != nil, coordinator.canCreate else { return }
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/roam/stamp/create"]
                                ) {
                                    await coordinator.create()
                                }
                                if showsCaption, pageContract.showsExchange, case .created(let stampID) = coordinator.phase, let exchange {
                                    startExchange(stampID: stampID, exchange: exchange)
                                }
                            }
                        }
                            .disabled(!coordinator.canUpload)
                            .disabled(!pageContract.showsCreate && coordinator.pending == nil)
                        if !pageContract.showsCreate {
                            Text("media.stamp.createDormant").cyText(.meta).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("media.stamp.createDormant")
                        }
                        CYPillButton("media.stamp.retake", style: .secondary) { coordinator.retake(); revision += 1 }
                            .disabled(!coordinator.canCapture)
                    }
                    if coordinator.pending != nil, pageContract.showsCreate {
                        CYPillButton("media.stamp.create") {
                            run {
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/roam/stamp/create"]
                                ) {
                                    await coordinator.create()
                                }
                            }
                        }
                            .disabled(!coordinator.canCreate)
                    }
                    CYScreenOfflineWriteBanner(
                        routes: ["/api/roam/stamp/create"],
                        session: offlineWriteSession.session
                    )
                    if case .created = coordinator.phase {
                        RoamStampCreatedMark()
                    }
                    if case .created(let stampID) = coordinator.phase, let exchange, pageContract.showsExchange { exchangeRows(stampID: stampID, exchange: exchange) }
                    if case .created = coordinator.phase, let album {
                        CYPillButton("roam.createdStamp.open", style: exchange == nil ? .primary : .secondary, systemImage: "rectangle.stack") {
                            guard createdStampTarget == nil else { return }
                            createdStampTarget = RoamCreatedStampTarget(phase: coordinator.phase, origin: coordinator.scope, reader: album.reader)
                        }
                        .disabled(createdStampTarget != nil || RoamCreatedStampTarget(phase: coordinator.phase, origin: coordinator.scope, reader: album.reader) == nil)
                        .accessibilityIdentifier("roam.createdStamp.open")
                    }
                }
            }
        }
        // SCAM-3: the title lives in the bar (inline), not as a hero header in the Form.
        .cyPageTitle("media.stamp.title")
        // Mini-program viewfinder shutter: one round capture button pinned at the bottom.
        .safeAreaInset(edge: .bottom) {
            if cameraEnabled, coordinator?.canCapture == true {
                Button { requestCamera() } label: {
                    ZStack {
                        Circle().strokeBorder(palette.textPrimary.opacity(0.85), lineWidth: 4).frame(width: 76, height: 76)
                        Circle().fill(purposeAccepted ? palette.actionPrimaryBg : palette.bgRaised).frame(width: 62, height: 62)
                        Image(systemName: "camera.fill").font(.title2).foregroundStyle(purposeAccepted ? palette.actionPrimaryFg : palette.textTertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(.bar)
                .disabled(!purposeAccepted)
                .accessibilityLabel(Text("media.stamp.capture"))
                .accessibilityIdentifier("media.stamp.capture")
                .accessibilityFocused($focusedControl, equals: .capture)
            }
        }
            .themeDomain(.player)
            // A stamp that has just been created plays the stamp press once (deduped per stamp id by the queue).
            .onChange(of: revision) { _, _ in celebrateCreatedStamp() }
            .navigationDestination(item: $createdStampTarget) { target in
                if let album, target.isCurrent(reader: album.reader) {
                    RoamCreatedStampView(target: target, album: album)
                } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.createdStamp.changed") }
            }
            .cySheet(isPresented: $showingPriming, onDismiss: {
                if primingAllowed { primingAllowed = false; requestCamera(primed: true) }
            }) { Group {
                CYPermissionPrimerScreen(kind: .camera, onPrimary: {
                    CYPermissionSystemPrompt.notePrimed(.camera)
                    primingAllowed = true
                    showingPriming = false
                }, onSecondary: { showingPriming = false })
            }.cySheet(detents: [.large]) }
            .cyFullScreenCover(isPresented: $showingCamera, onDismiss: {
                guard scenePhase == .active, cameraEnabled else { return }
                focusedControl = coordinator?.selection == nil ? .capture : .status
            }) {
                if cameraEnabled {
                    let ticket = captureGeneration
                    RoamNativeStampCamera { result in
                        guard ticket == captureGeneration, scenePhase == .active, cameraEnabled, purposeAccepted else { return }
                        showingCamera = false
                        switch result {
                        case .success(let image): if let image { coordinator?.captured(image); revision += 1 }
                        case .failure: cameraIssue = true
                        }
                    }.ignoresSafeArea()
                }
            }
            .onAppear {
                coordinator?.changed = { revision += 1 }
                // SCAM-2: open the viewfinder on arrival, as the MP page does.
                if coordinator?.selection == nil, coordinator?.pending == nil { requestCamera() }
            }
            .onDisappear { if !showingCamera { stop() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { invalidateCapture() }
            }
            .onChange(of: cameraEnabled) { _, enabled in if !enabled { invalidateCapture() } }
    }
    @ViewBuilder private func exchangeRows(stampID: Int, exchange: @escaping @MainActor (Int) async throws -> RoamStampExchangeReceipt) -> some View {
        switch exchangePhase {
        case .done(let receipt):
            RoamStampSlipView(slip: RoamStampSlip(receipt), place: Text("roamSub.w208.stamp.defaultPlace"), openedAt: exchangeStarted)
        case .working:
            CYSkeleton()
                .accessibilityLabel(Text("roam.stamp.exchange.working"))
        case .idle, .failed:
            if exchangePhase == .failed {
                Label("roam.stamp.exchange.failed", systemImage: "exclamationmark.triangle").cyText(.bodyCompact).foregroundStyle(palette.danger)
            }
            CYPillButton(LocalizedStringKey(exchangePhase == .failed ? "action.retry" : "roam.stamp.exchange.button")) {
                startExchange(stampID: stampID, exchange: exchange)
            }
            .accessibilityIdentifier("media.stamp.exchange")
            Text("roam.stamp.exchange.footer").cyText(.bodyCompact).foregroundStyle(.secondary)
        }
    }
    private var captionText: String { coordinator?.caption ?? localDraft.caption }
    private var captionSection: some View {
        Section("roam.experience.caption") {
            TextField("roam.experience.caption", text: Binding(get: { captionText }, set: { value in
                if let coordinator { coordinator.updateCaption(value) }
                else { localDraft.caption = value }
            }), axis: .vertical)
                .lineLimit(2...5)
                .disabled(showingCamera || !(coordinator?.canEditCaption ?? true))
                .accessibilityIdentifier("media.stamp.caption")
            HStack {
                if !RoamExperienceMath.validCaption(captionText) {
                    Label("roam.experience.captionLimit", systemImage: "exclamationmark.circle")
                        .cyText(.meta).foregroundStyle(palette.danger).accessibilityIdentifier("media.stamp.caption.limit")
                }
                Spacer(minLength: 8)
                // Measured UTF-16 length from StampCameraPageReady; an over-limit caption still shows its real count.
                let units = StampCameraPageReady.captionUnits(captionText)
                Text(verbatim: "\(units.phase == .ready ? units.text : String(captionText.utf16.count))/30").cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityIdentifier("media.stamp.caption.remaining")
            }
        }.accessibilityIdentifier("media.stamp.caption.section")
    }
    private var isBusy: Bool { coordinator?.phase == .uploading || coordinator?.phase == .creating }
    private func invalidateCapture() {
        captureGeneration += 1; showingCamera = false; focusedControl = nil
        work?.cancel(); work = nil; coordinator?.cancel()
    }
    private func requestCamera(primed: Bool = false) {
        guard cameraEnabled, purposeAccepted, coordinator?.canCapture == true, !showingCamera else { return }
        if !primed, AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined { showingPriming = true; return }
        captureGeneration += 1; let ticket = captureGeneration; cameraIssue = false
        work = Task { @MainActor in
            guard let reason = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String, !reason.isEmpty,
                  UIImagePickerController.isSourceTypeAvailable(.camera) else { cameraIssue = true; return }
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .denied || status == .restricted { cameraDenied = true; cameraIssue = false; return }
            cameraDenied = false
            let granted: Bool
            if status == .notDetermined {
                guard await CYPermissionSystemPrompt.precede(.camera) else { cameraIssue = false; return }
                granted = await AVCaptureDevice.requestAccess(for: .video)
            }
            else { granted = status == .authorized }
            guard !Task.isCancelled, ticket == captureGeneration, scenePhase == .active, cameraEnabled, purposeAccepted else { return }
            showingCamera = granted; cameraIssue = !granted
        }
    }
    private func celebrateCreatedStamp() {
        guard let celebrations, case .created(let stampID)? = coordinator?.phase else { return }
        celebrations.enqueue(.stamp(CYStampPayload(id: "stamp-\(stampID)", place: nil, passportCount: nil)))
    }
    private func stop() { captureGeneration += 1; work?.cancel(); work = nil; coordinator?.cancel(); coordinator?.changed = nil; localDraft = RoamCityStampDraft() }
    /// 投一张换一张: `api/roam/stamp/exchange {givenStampId}`; a retry reuses the created stamp (MP citystamp/index.js:270).
    private func startExchange(stampID: Int, exchange: @escaping @MainActor (Int) async throws -> RoamStampExchangeReceipt) {
        guard exchangePhase != .working else { return }
        exchangePhase = .working; exchangeStarted = Date()
        Task {
            do { exchangePhase = .done(try await exchange(stampID)) }
            catch is CancellationError { exchangePhase = .idle }
            catch { exchangePhase = .failed }
        }
    }
    private func run(_ action: @escaping @MainActor () async -> Void) { work?.cancel(); work = Task { await action(); revision += 1 } }
    private func phaseTone(_ phase: RoamStampCaptureCoordinator.Phase) -> CYStatusTone {
        switch phase {
        case .created: return .success
        case .failed: return .danger
        case .unknown, .unavailable: return .warning
        default: return .neutral
        }
    }
    private func phaseKey(_ phase: RoamStampCaptureCoordinator.Phase) -> String {
        switch phase {
        case .ready: return "ready"
        case .review: return "review"
        case .uploading: return "uploading"
        case .awaitingCreate: return "awaitingCreate"
        case .creating: return "creating"
        case .unknown: return "unknown"
        case .created: return "created"
        case .unavailable: return "unavailable"
        case .failed:
            // RSTAMP-4: name the step that failed (upload / save); the exchange step has its own line below.
            switch coordinator?.failedStep {
            case .upload?: return "failed.upload"
            case .create?: return "failed.create"
            case nil: return "failed"
            }
        }
    }
}

@MainActor struct RoamNativeStampCamera: UIViewControllerRepresentable {
    @Environment(\.locale) private var locale
    let finished: (Result<RetainedSelectedImage?, Error>) -> Void
    func makeUIViewController(context: Context) -> RoamStampFramingCameraController {
        RoamStampFramingCameraController(locale: locale, finished: finished)
    }
    func updateUIViewController(_ controller: RoamStampFramingCameraController, context: Context) { controller.updateLocale(locale) }
    static func dismantleUIViewController(_ controller: RoamStampFramingCameraController, coordinator: ()) { controller.invalidate() }
}
/// Explicit 4:5 center crop is shown for review before upload. Redraw normalizes orientation,
/// resizes to 1600×2000 maximum, and never uploads the camera container's EXIF/GPS metadata.
@MainActor enum RoamStampPixelCrop {
    static func render(_ image: UIImage) throws -> RetainedSelectedImage {
        let size = image.size
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              size.width <= 30000, size.height <= 30000, size.width * size.height <= 100_000_000 else { throw RetainedImageFailure.invalid }
        let cropWidth = min(size.width, size.height * 0.8), cropHeight = cropWidth / 0.8
        let factor = min(1, 1600 / cropWidth)
        let output = CGSize(width: floor(cropWidth * factor), height: floor(cropHeight * factor))
        guard output.width > 0, output.height > 0 else { throw RetainedImageFailure.invalid }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: output, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: output))
            image.draw(in: CGRect(x: -(size.width - cropWidth) / 2 * factor, y: -(size.height - cropHeight) / 2 * factor,
                                  width: size.width * factor, height: size.height * factor))
        }
        guard let jpeg = rendered.jpegData(compressionQuality: 0.9) else { throw RetainedImageFailure.invalid }
        return try RetainedImageSanitizer.sanitize(jpeg)
    }
}

/// Stamp created: the scan-success mark completes with orbit dots; VoiceOver hears the result once.
@MainActor private struct RoamStampCreatedMark: View {
    @State private var landed = false
    var body: some View {
        ZStack {
            CYScanMark(kind: .success, size: 72)
            CYOrbitDots(fire: landed)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .cyHaptic(.success, trigger: landed) { _, new in new }
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            landed = true
            AccessibilityNotification.Announcement(String(localized: LocalizedStringResource("scan.stamp.created"))).post()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("scan.stamp.created"))
        .listRowBackground(Color.clear)
    }
}
