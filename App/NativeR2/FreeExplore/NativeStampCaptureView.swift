import AVFoundation
import SwiftUI
import UIKit

/// Native r2 stamp capture (spec §9, the system Camera capture + "Retake / Use Photo" review). The camera is the
/// existing `RoamNativeStampCamera` (4:5 crop, EXIF stripped) in a full-screen cover; the review is a grouped
/// `Form` with the photo, the optional caption (validation in the footer) and the phase. Toolbar: 重拍 (cancel
/// side) and 存入集邮册 (confirm side). Writes are `RoamStampCaptureCoordinator.upload()` then `create()` with the
/// same idempotency key, and the optional citystamp exchange, exactly as `RoamStampCameraView`.
@MainActor struct NativeStampCaptureView: View {
    var coordinator: RoamStampCaptureCoordinator? = nil
    var cameraEnabled = false
    var album: RoamStampAlbumContinuation? = nil
    var exchange: (@MainActor (Int) async throws -> RoamStampExchangeReceipt)? = nil
    var showsCaption = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyCelebrationCenter) private var celebrations
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @State private var cameraDenied = false
    private enum ExchangePhase: Equatable { case idle, working, failed, done(RoamStampExchangeReceipt) }
    @State private var exchangePhase: ExchangePhase = .idle
    @State private var showingCamera = false
    @State private var cameraIssue = false
    @State private var revision = 0
    @State private var captureGeneration = 0
    @State private var work: Task<Void, Never>?
    @State private var localDraft = RoamCityStampDraft()
    @State private var createdStampTarget: RoamCreatedStampTarget?
    private var pageContract: StampCameraPageContract { StampCameraPageContract(hasAlbumReader: album != nil) }

    var body: some View {
        let _ = revision
        Group {
            if cameraDenied {
                ContentUnavailableView {
                    Label("media.stamp.cameraDenied.title", systemImage: "camera")
                } description: {
                    Text("media.stamp.cameraDenied.message")
                } actions: {
                    Button("roam.poi.location.openSettings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("media.stamp.openSettings")
                    Button("action.back") { dismiss() }
                }
                .accessibilityIdentifier("media.stamp.cameraDenied")
            } else {
                form
            }
        }
        .navigationTitle(Text("media.stamp.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { captureButton }
        .sensoryFeedback(.success, trigger: createdStampID) { _, new in new != nil }
        .navigationDestination(item: $createdStampTarget) { target in
            if let album, target.isCurrent(reader: album.reader) {
                RoamCreatedStampView(target: target, album: album)
            } else {
                ContentUnavailableView("roam.createdStamp.changed", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .cyFullScreenCover(isPresented: $showingCamera) {
            if cameraEnabled {
                let ticket = captureGeneration
                RoamNativeStampCamera { result in
                    guard ticket == captureGeneration, scenePhase == .active, cameraEnabled else { return }
                    showingCamera = false
                    switch result {
                    case .success(let image): if let image { coordinator?.captured(image); revision += 1 }
                    case .failure: cameraIssue = true
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onChange(of: revision) { _, _ in celebrateCreatedStamp() }
        .onAppear {
            coordinator?.changed = { revision += 1 }
            // SCAM-2: the MP page opens the viewfinder on arrival.
            if coordinator?.selection == nil, coordinator?.pending == nil { requestCamera() }
        }
        .onDisappear { if !showingCamera { stop() } }
        .onChange(of: scenePhase) { _, phase in if phase == .background { invalidateCapture() } }
        .onChange(of: cameraEnabled) { _, enabled in if !enabled { invalidateCapture() } }
        .accessibilityIdentifier("nativeR2.stamp.capture")
    }

    private var createdStampID: Int? {
        if case .created(let id)? = coordinator?.phase { return id }
        return nil
    }

    // MARK: Form

    private var form: some View {
        Form {
            if !cameraEnabled || cameraIssue {
                Section {
                    if !cameraEnabled { Label("media.stamp.disabled", systemImage: "camera") }
                    if cameraIssue {
                        Label("media.stamp.cameraIssue", systemImage: "exclamationmark.triangle")
                        // MP sc-err: a camera error that cannot open Settings offers 返回上一页.
                        Button("action.back") { dismiss() }
                            .accessibilityIdentifier("media.stamp.cameraIssue.back")
                    }
                }
            }
            if let coordinator {
                Section {
                    if let bytes = coordinator.selection?.jpeg, let image = UIImage(data: bytes) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 360)
                            .accessibilityLabel(Text("media.stamp.capturedPreview"))
                    }
                    LabeledContent("nativeR2.freeExplore.capture.status") {
                        if isBusy {
                            ProgressView().accessibilityLabel(Text(LocalizedStringKey(phaseKey(coordinator.phase))))
                        } else {
                            Text(LocalizedStringKey(phaseKey(coordinator.phase)))
                        }
                    }
                    if case .created = coordinator.phase {
                        Label("scan.stamp.created", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                } footer: {
                    if !pageContract.showsCreate {
                        Text("media.stamp.createDormant").accessibilityIdentifier("media.stamp.createDormant")
                    } else {
                        Text("media.stamp.purpose")
                    }
                }
            }
            if showsCaption { captionSection }
            if let coordinator {
                if coordinator.pending != nil, pageContract.showsCreate {
                    Section {
                        Button("media.stamp.create") { create(coordinator) }
                            .disabled(!coordinator.canCreate)
                    }
                }
                Section {
                    CYScreenOfflineWriteBanner(routes: ["/api/roam/stamp/create"], session: offlineWriteSession.session)
                }
                if case .created(let stampID) = coordinator.phase, let exchange, pageContract.showsExchange {
                    exchangeSection(stampID: stampID, exchange: exchange)
                }
                if case .created = coordinator.phase, let album {
                    Section {
                        Button {
                            guard createdStampTarget == nil else { return }
                            createdStampTarget = RoamCreatedStampTarget(phase: coordinator.phase, origin: coordinator.scope, reader: album.reader)
                        } label: {
                            Label("roam.createdStamp.open", systemImage: "rectangle.stack")
                        }
                        .disabled(createdStampTarget != nil || RoamCreatedStampTarget(phase: coordinator.phase, origin: coordinator.scope, reader: album.reader) == nil)
                        .accessibilityIdentifier("roam.createdStamp.open")
                    }
                }
            }
        }
    }

    private var captionText: String { coordinator?.caption ?? localDraft.caption }

    private var captionSection: some View {
        Section {
            TextField("roam.experience.caption", text: Binding(get: { captionText }, set: { value in
                if let coordinator { coordinator.updateCaption(value) } else { localDraft.caption = value }
            }), axis: .vertical)
            .lineLimit(2...5)
            .submitLabel(.done)
            .disabled(showingCamera || !(coordinator?.canEditCaption ?? true))
            .accessibilityIdentifier("media.stamp.caption")
        } header: {
            Text("roam.experience.caption")
        } footer: {
            HStack {
                if !RoamExperienceMath.validCaption(captionText) {
                    Text("roam.experience.captionLimit").accessibilityIdentifier("media.stamp.caption.limit")
                }
                Spacer(minLength: 8)
                // Measured UTF-16 length from StampCameraPageReady; an over-limit caption shows its real count.
                let units = StampCameraPageReady.captionUnits(captionText)
                Text(verbatim: "\(units.phase == .ready ? units.text : String(captionText.utf16.count))/30")
                    .monospacedDigit()
                    .accessibilityIdentifier("media.stamp.caption.remaining")
            }
        }
        .accessibilityIdentifier("media.stamp.caption.section")
    }

    // MARK: Exchange (投一张换一张)

    @ViewBuilder private func exchangeSection(stampID: Int, exchange: @escaping @MainActor (Int) async throws -> RoamStampExchangeReceipt) -> some View {
        switch exchangePhase {
        case .done(let receipt):
            let slip = RoamStampSlip(receipt)
            if slip.got {
                if let picture = slip.pictureURL, let url = NativeStampAlbumTile.safeURL(picture) {
                    Section {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFit() } else { ProgressView() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .accessibilityLabel(Text("roam.experience.stampImage"))
                    }
                }
                Section {
                    LabeledContent("roamSub.w208.stamp.departure") { Text("roamSub.w208.stamp.defaultPlace") }
                    LabeledContent("roamSub.w208.stamp.serialLabel") { Text(verbatim: slip.serial).monospacedDigit() }
                    LabeledContent("roamSub.w208.stamp.leftBy") { Text("roamSub.w208.stamp.someone") }
                    LabeledContent("roamSub.w208.stamp.leftAt") { Text(verbatim: slip.leftAt ?? "—").monospacedDigit() }
                }
                Section("roamSub.w208.stamp.forYou") {
                    if let caption = slip.caption { Text(verbatim: caption) } else { Text("roamSub.w208.stamp.noCaption") }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        if let reason = slip.reason {
                            Label { Text(verbatim: reason) } icon: { Image(systemName: "envelope") }
                        } else {
                            Label("roamSub.w208.stamp.noTicket", systemImage: "envelope")
                        }
                    } description: {
                        Text("roamSub.w208.stamp.noTicketHint")
                    }
                    .accessibilityIdentifier("roamSub.w208.stamp.noExchange")
                }
            }
            Section {
                Button { dismiss() } label: { Text("roamSub.w208.stamp.done").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("roamSub.w208.stamp.done")
            }
        case .working:
            Section { ProgressView("roam.stamp.exchange.working") }
        case .idle, .failed:
            Section {
                if exchangePhase == .failed {
                    Label("roam.stamp.exchange.failed", systemImage: "exclamationmark.triangle")
                }
                Button(LocalizedStringKey(exchangePhase == .failed ? "action.retry" : "roam.stamp.exchange.button")) {
                    startExchange(stampID: stampID, exchange: exchange)
                }
                .accessibilityIdentifier("media.stamp.exchange")
            } footer: {
                Text("roam.stamp.exchange.footer")
            }
        }
    }

    // MARK: Toolbar and shutter

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if let coordinator, coordinator.phase == .review {
            ToolbarItem(placement: .cancellationAction) {
                Button("media.stamp.retake") { coordinator.retake(); revision += 1 }
                    .disabled(!coordinator.canCapture)
                    .accessibilityIdentifier("media.stamp.retake")
            }
            ToolbarItem(placement: .confirmationAction) {
                // SCAM-1: upload and create are one 存入集邮册 step (stamp-camera/index/index.js:350-391).
                Button("media.stamp.upload") { save(coordinator) }
                    .disabled(!coordinator.canUpload || (!pageContract.showsCreate && coordinator.pending == nil))
                    .accessibilityIdentifier("media.stamp.upload")
            }
        }
        if isBusy {
            ToolbarItem(placement: .confirmationAction) { ProgressView() }
        }
    }

    @ViewBuilder private var captureButton: some View {
        if cameraEnabled, !cameraDenied, coordinator?.canCapture == true, coordinator?.phase != .review {
            Button { requestCamera() } label: {
                Label("media.stamp.capture", systemImage: "camera.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
            .accessibilityIdentifier("media.stamp.capture")
        }
    }

    // MARK: Actions (unchanged from RoamStampCameraView)

    private var isBusy: Bool { coordinator?.phase == .uploading || coordinator?.phase == .creating }

    private func save(_ coordinator: RoamStampCaptureCoordinator) {
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

    private func create(_ coordinator: RoamStampCaptureCoordinator) {
        run {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/roam/stamp/create"]
            ) {
                await coordinator.create()
            }
        }
    }

    private func invalidateCapture() {
        captureGeneration += 1; showingCamera = false
        work?.cancel(); work = nil; coordinator?.cancel()
    }

    /// iOS asks for camera access itself; `CYPermissionSystemPrompt.precede` keeps the existing one-time primer rule.
    private func requestCamera() {
        guard cameraEnabled, coordinator?.canCapture == true, !showingCamera else { return }
        captureGeneration += 1
        let ticket = captureGeneration
        cameraIssue = false
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
            } else {
                granted = status == .authorized
            }
            guard !Task.isCancelled, ticket == captureGeneration, scenePhase == .active, cameraEnabled else { return }
            showingCamera = granted
            cameraIssue = !granted
        }
    }

    private func celebrateCreatedStamp() {
        guard let celebrations, case .created(let stampID)? = coordinator?.phase else { return }
        celebrations.enqueue(.stamp(CYStampPayload(id: "stamp-\(stampID)", place: nil, passportCount: nil)))
    }

    private func stop() {
        captureGeneration += 1; work?.cancel(); work = nil
        coordinator?.cancel(); coordinator?.changed = nil; localDraft = RoamCityStampDraft()
    }

    /// `api/roam/stamp/exchange {givenStampId}`; a retry reuses the created stamp (MP citystamp/index.js:270).
    private func startExchange(stampID: Int, exchange: @escaping @MainActor (Int) async throws -> RoamStampExchangeReceipt) {
        guard exchangePhase != .working else { return }
        exchangePhase = .working
        Task {
            do { exchangePhase = .done(try await exchange(stampID)) }
            catch is CancellationError { exchangePhase = .idle }
            catch { exchangePhase = .failed }
        }
    }

    private func run(_ action: @escaping @MainActor () async -> Void) {
        work?.cancel()
        work = Task { await action(); revision += 1 }
    }

    private func phaseKey(_ phase: RoamStampCaptureCoordinator.Phase) -> String {
        let suffix: String
        switch phase {
        case .ready: suffix = "ready"
        case .review: suffix = "review"
        case .uploading: suffix = "uploading"
        case .awaitingCreate: suffix = "awaitingCreate"
        case .creating: suffix = "creating"
        case .unknown: suffix = "unknown"
        case .created: suffix = "created"
        case .unavailable: suffix = "unavailable"
        case .failed:
            switch coordinator?.failedStep {
            case .upload?: suffix = "failed.upload"
            case .create?: suffix = "failed.create"
            case nil: suffix = "failed"
            }
        }
        return "media.stamp.phase." + suffix
    }
}
