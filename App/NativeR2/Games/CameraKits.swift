import SwiftUI
import UIKit
import VisionKit

// Native r2 games-b, Template 4: Camera.
// Apple reference: Camera (system `UIImagePickerController` through the existing
// `PlayDeviceCaptureCoordinator`), Photos (system `PHPickerViewController` through the same
// coordinator), Code Scanner (VisionKit `DataScannerViewController` via `NativeQRScanner`).
// Upload, server judging and the purpose / upload-review dialogs are unchanged.

@MainActor private enum CameraKitSettings {
    static var url: URL? { URL(string: UIApplication.openSettingsURLString) }
}

// MARK: - Photo capture (photocheck, objectcard capture)

/// Same flow and coordinator calls as `PlayKitPhotoInput`: purpose dialog -> system camera
/// (or system photo picker) -> preview -> upload-review dialog -> upload -> use.
@MainActor struct CameraPhotoInput: View {
    @Bindable var model: PlayDeviceCaptureCoordinator
    let identity: String
    let enabled: Bool
    var frame: PlayKitPhotoFrame? = nil
    var submitFailed: Bool = false
    var judging: Bool = false
    let onDirty: () -> Void
    let onURL: (String) -> Void
    @State private var capturedIdentity: String?
    @State private var cameraPurpose = false
    @State private var uploadReview = false
    @State private var mounted = false
    @Environment(\.openURL) private var openURL

    private var capturedBytes: Data? {
        guard capturedIdentity == identity, let output = model.output, case .photo(let bytes, _) = output else { return nil }
        return bytes
    }
    private var uploadedURL: String? {
        guard capturedBytes != nil, let evidence = model.reviewedPhoto(), case .photo(let url) = evidence else { return nil }
        return url
    }
    private var step: Int { uploadedURL != nil ? 3 : (capturedBytes != nil ? 2 : 1) }
    private var denied: Bool { model.issue == .disabled }

    var body: some View {
        // One row carries the dialogs and lifecycle: modifiers on a multi-row Section or Group
        // would be applied to every row inside the List (repeated `model.cancel()` on appear).
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if denied {
                        ContentUnavailableView {
                            Label("nativeR2.gamesB.camera.denied.title", systemImage: "camera.slash")
                        } description: {
                            Text("nativeR2.gamesB.camera.denied.hint")
                        } actions: {
                            if let url = CameraKitSettings.url {
                                Button("playkit.media.openSettings") { openURL(url) }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("playkit.photo.openSettings")
                            }
                            if model.supportsLibraryPhotos {
                                Button("playkitCamera.choosePhoto") { pickFromLibrary() }
                                    .buttonStyle(.bordered)
                                    .disabled(!enabled || model.busy)
                            }
                        }
                }
                if let bytes = capturedBytes {
                    if let image = UIImage(data: bytes) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: CYRadius.card))
                            .accessibilityLabel(Text("playkit.photo.preview"))
                    }
                    if bytes.count > 10 * 1024 * 1024 { Label("playkit.photo.tooLarge", systemImage: "exclamationmark.triangle") }
                } else if !denied {
                    // i18n r1: stacks "Take a photo" / "Choose a photo" when they don't fit side by side.
                    CYAdaptiveButtonRow(spacing: 12) {
                        Button {
                            cameraPurpose = true
                        } label: {
                            Label("playkit.photo.capture", systemImage: "camera").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!enabled || model.busy || !model.supports(.photo))
                        .accessibilityIdentifier("playkit.photo.capture")
                        if model.supportsLibraryPhotos {
                            Button {
                                pickFromLibrary()
                            } label: {
                                Label("playkitCamera.choosePhoto", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!enabled || model.busy)
                            .accessibilityIdentifier("playkit.photo.library")
                        }
                    }
                    .controlSize(.large)
                    if !model.supports(.photo) { Label("playkit.camera.gated", systemImage: "camera") }
                }
                if model.busy { ProgressView("playkit.photo.working") }
                if judging { ProgressView("playkit.photo.judging") }
                if let bytes = capturedBytes {
                    if let url = uploadedURL {
                        Label("playkit.photo.uploaded", systemImage: "checkmark.circle")
                        Button {
                            if mounted && capturedIdentity == identity && enabled { onURL(url) }
                        } label: {
                            Label(LocalizedStringKey(submitFailed ? "playkit.photo.resubmit" : "playkit.photo.use"),
                                  systemImage: submitFailed ? "arrow.clockwise" : "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!enabled || judging)
                        .accessibilityIdentifier("playkit.photo.use")
                    } else {
                        Button {
                            uploadReview = true
                        } label: {
                            Label("nativeR2.gamesB.camera.uploadSubmit", systemImage: "icloud.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!enabled || !model.canUpload || bytes.isEmpty || bytes.count > 10 * 1024 * 1024)
                        .accessibilityIdentifier("playkit.photo.upload")
                    }
                    Button {
                        cameraPurpose = true
                    } label: {
                        Label("nativeR2.gamesB.camera.retake", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!enabled || model.busy || judging || !model.supports(.photo))
                    .accessibilityIdentifier("playkit.photo.retake")
                }
                if let issue = model.issue, !denied { PlayExperienceIssueView(issue: issue) }
            }
            .confirmationDialog("playkit.camera.purpose", isPresented: $cameraPurpose, titleVisibility: .visible) {
                Button("playkit.photo.capture") { takePhoto() }
                Button("playkit.cancel", role: .cancel) {}
            } message: { Text("playkit.camera.photoPurpose") }
            .confirmationDialog("playkit.photo.uploadReview", isPresented: $uploadReview, titleVisibility: .visible) {
                Button("playkit.photo.upload") {
                    guard capturedIdentity == identity, enabled else { return }
                    let expected = identity
                    Task { await model.uploadPhoto(); if !mounted || identity != expected { model.cancel() } }
                }
                Button("playkit.cancel", role: .cancel) {}
            } message: { Text("playkit.photo.uploadBoundary") }
            .sensoryFeedback(.success, trigger: uploadedURL != nil) { _, next in next }
            .onAppear { mounted = true; model.cancel() }
            .onChange(of: identity) { _, _ in capturedIdentity = nil; cameraPurpose = false; uploadReview = false; model.cancel() }
            .onDisappear { mounted = false; capturedIdentity = nil; model.cancel() }
        } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("nativeR2.gamesB.camera.step \(step) \(3)")
                    if capturedBytes != nil, !model.canUpload, model.uploadedPhoto == nil, !model.busy {
                        Text("playkit.photo.uploadGate")
                    }
                    if capturedBytes != nil, model.uploadedPhoto == nil, model.issue != nil, !denied {
                        Label("playkit.photo.uploadFailedRetake", systemImage: "exclamationmark.triangle")
                    }
                    if uploadedURL != nil, submitFailed {
                        Label("playkit.photo.submitFailedKept", systemImage: "arrow.clockwise.circle")
                    }
                    if model.busy, capturedBytes != nil { Text("nativeR2.gamesB.camera.uploading") }
                }
        }
    }
    private func takePhoto() {
        let expected = identity
        capturedIdentity = expected
        Task {
            await model.capture(.photo, cameraFrame: frame)
            if !mounted || identity != expected { model.cancel() }
            else if let output = model.output, case .photo = output { onDirty() }
        }
    }
    private func pickFromLibrary() {
        let expected = identity
        capturedIdentity = expected
        Task {
            await model.capture(.photo, usePhotoLibrary: true)
            if !mounted || identity != expected { model.cancel() }
            else if let output = model.output, case .photo = output { onDirty() }
        }
    }
}

// MARK: - Scan

/// Live VisionKit scanning when the device supports it; otherwise the existing still photo
/// plus Vision barcode path in `PlayDeviceCaptureCoordinator.capture(.scan)`.
/// Either way the code goes to the same `SUBMIT_SCAN` review.
@MainActor struct CameraScanInput: View {
    @Bindable var model: PlayDeviceCaptureCoordinator
    let identity: String
    let enabled: Bool
    let onDirty: () -> Void
    let onCode: (String) -> Void
    @State private var purpose = false
    @State private var scanning = false
    @State private var liveCode: (identity: String, code: String)?
    @State private var capturedIdentity: String?
    @State private var mounted = false
    @Environment(\.openURL) private var openURL

    private var liveScannerAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        #endif
    }
    private var code: String? {
        if let live = liveCode, live.identity == identity { return live.code }
        if capturedIdentity == identity, let output = model.output, case .scan(let code) = output { return code }
        return nil
    }
    private var scanButton: some View {
        Button {
            if liveScannerAvailable { scanning = true } else { purpose = true }
        } label: {
            Label("nativeR2.gamesB.scan.start", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(!enabled || model.busy || (!liveScannerAvailable && !model.supports(.scan)))
        .accessibilityIdentifier("playkit.scan.capture")
    }
    var body: some View {
        // One row carries the cover, dialog and lifecycle (see `CameraPhotoInput`).
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if code == nil {
                    scanButton.buttonStyle(.borderedProminent)
                } else {
                    scanButton.buttonStyle(.bordered)
                }
                if !liveScannerAvailable, !model.supports(.scan) { Label("playkit.camera.gated", systemImage: "camera") }
                if model.busy { ProgressView("playkit.scan.working") }
                if let code {
                    Label("playkit.scan.captured", systemImage: "qrcode")
                    Button {
                        if mounted && enabled { onCode(code) }
                    } label: {
                        Text("playkit.review").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!enabled)
                    .accessibilityIdentifier("playkit.scan.submit")
                }
                if let issue = model.issue {
                    PlayExperienceIssueView(issue: issue)
                    if issue == .disabled, let url = CameraKitSettings.url {
                        Button("playkit.media.openSettings") { openURL(url) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("playkit.scan.openSettings")
                    }
                }
            }
            .sensoryFeedback(.success, trigger: code) { _, next in next != nil }
            .cyFullScreenCover(isPresented: $scanning) {
                NativeQRScanner { scanned in
                    guard mounted, enabled else { return }
                    liveCode = (identity, scanned)
                    onDirty()
                }
            }
            .confirmationDialog("playkit.camera.purpose", isPresented: $purpose, titleVisibility: .visible) {
                Button("playkit.scan.capture") {
                    let expected = identity
                    capturedIdentity = expected
                    Task {
                        await model.capture(.scan)
                        if !mounted || identity != expected { model.cancel() }
                        else if let output = model.output, case .scan = output { onDirty() }
                    }
                }
                Button("playkit.cancel", role: .cancel) {}
            } message: { Text("playkit.camera.scanPurpose") }
            .onAppear { mounted = true; model.cancel() }
            .onChange(of: identity) { _, _ in capturedIdentity = nil; liveCode = nil; purpose = false; scanning = false; model.cancel() }
            .onDisappear { mounted = false; capturedIdentity = nil; liveCode = nil; model.cancel() }
        } footer: {
            Text("playkit.scan.scopeLine")
        }
    }
}

// MARK: - Album

/// Native replacement for `PlayKitAlbumView` (same inputs). Photos one-up pager instead of the 3D ring.
@MainActor struct CameraAlbumView: View {
    let projection: PlayKitAlbumProjection
    var approvedHosts: Set<String> = []
    var complete: (() -> Void)? = nil
    var close: () -> Void
    @State private var current = 0
    var body: some View {
        VStack(spacing: 16) {
            Group {
                if projection.title.isEmpty { Text("playkit.album.title") } else { Text(verbatim: projection.title) }
            }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("playkit.album.title")
            if projection.photos.isEmpty {
                ContentUnavailableView("playkit.album.title", systemImage: "photo.on.rectangle")
            } else {
                TabView(selection: $current) {
                    ForEach(Array(projection.photos.enumerated()), id: \.element.id) { index, photo in
                        PlayKitArtwork(source: photo.url, approvedHosts: approvedHosts)
                            .accessibilityLabel(photo.line.isEmpty ? Text("playkit.image") : Text(verbatim: photo.line))
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(minHeight: 320)
                .accessibilityLabel(Text("playkit.album.carousel"))
                .accessibilityIdentifier("playkit.album.ring")
                let index = min(current, projection.photos.count - 1)
                Text(verbatim: projection.photos[index].line)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("playkit.album.line")
                Text(verbatim: "\(index + 1) / \(projection.photos.count)")
                    .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityIdentifier("playkit.album.count")
            }
            if projection.completionEnabled && projection.done {
                Label("playkit.album.locked", systemImage: "lock")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("playkit.album.locked")
            }
            if projection.completionEnabled && !projection.done, let complete {
                Button(action: complete) {
                    Label("playkit.album.complete", systemImage: "camera").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("playkit.album.complete")
            }
            Button("playkit.album.close", action: close)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("playkit.album.close")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("playkit.album.view")
        .cyDomainScreen(.game)
    }
}

// MARK: - Object card

/// Native replacement for `PlayObjectCardRevealView` (same inputs, same bounded image loader).
/// No foil, no tilt; the reveal is a plain fade plus success haptic.
@MainActor struct CameraObjectCardRevealView: View {
    let receipt: PlayObjectCardReceipt
    let approvedHosts: Set<String>
    let isCurrent: () -> Bool
    @State private var frame = 0
    @State private var scope = UUID()
    @State private var appeared = false
    private var card: ObjectCard { receipt.card }
    private var media: (any ObjectCardImageLoading)? {
        let origins = Set(approvedHosts.compactMap { host -> String? in
            let origin = "https://" + host
            return ObjectCardMediaPolicy.origin(origin) == origin ? origin : nil
        })
        return origins.isEmpty ? nil : ObjectCardBoundedImageLoader(policy: .init(approvedOrigins: origins))
    }
    var body: some View {
        Section {
            if isCurrent() {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        ObjectCardArtwork(url: card.frame(at: frame).isEmpty ? card.thumbnail : card.frame(at: frame), label: card.title,
                                          media: media, expectedScope: scope, currentScope: { isCurrent() ? scope : UUID() })
                            .frame(maxWidth: .infinity, minHeight: 240)
                            .accessibilityAdjustableAction { direction in
                                guard isCurrent(), card.hasRotationFrames else { return }
                                switch direction { case .increment: move(1); case .decrement: move(-1); @unknown default: break }
                            }
                        if card.hasRotationFrames {
                            HStack {
                                Button("objects.previous", systemImage: "chevron.backward") { move(-1) }
                                    .labelStyle(.iconOnly)
                                    .accessibilityIdentifier("playCard.previous")
                                Spacer()
                                Text(verbatim: "\(frame + 1) / \(card.frames.count)").monospacedDigit().foregroundStyle(.secondary)
                                Spacer()
                                Button("objects.next", systemImage: "chevron.forward") { move(1) }
                                    .labelStyle(.iconOnly)
                                    .accessibilityIdentifier("playCard.next")
                            }
                            .buttonStyle(.bordered)
                        }
                        Text(verbatim: card.title).font(.headline).accessibilityIdentifier("playCard.title")
                        if !card.caption.isEmpty { Text(verbatim: card.caption).foregroundStyle(.secondary) }
                        if !card.place.isEmpty { LabeledContent("objects.place", value: card.place) }
                        LabeledContent("objects.style") { Text(card.cardStyle == "plain" ? "objects.plain" : "objects.foil") }
                        if card.generating { Label("objects.generating", systemImage: "hourglass") }
                        if card.generationStatus == "FAILED" { Text("playCard.framesUnavailable").foregroundStyle(.secondary) }
                    }
                } label: {
                    Label("playCard.received", systemImage: "rectangle.portrait.on.rectangle.portrait")
                        .accessibilityIdentifier("playCard.received")
                }
                .opacity(appeared ? 1 : 0)
            } else {
                Text("objects.sessionChanged")
            }
        } footer: {
            Text("playCard.collectionHint")
        }
        .privacySensitive()
        .accessibilityIdentifier("playCard.reveal")
        .sensoryFeedback(.success, trigger: appeared) { _, next in next }
        .onAppear { withAnimation(.easeOut) { appeared = true } }
        .onDisappear { scope = UUID(); frame = 0 }
    }
    private func move(_ delta: Int) {
        guard isCurrent(), card.hasRotationFrames else { return }
        frame = ((frame + delta) % card.frames.count + card.frames.count) % card.frames.count
    }
}

// MARK: - PlayKitScreen hosts (same actions and payloads as the forms they replace)

extension PlayKitScreen {
    private var cameraEvidenceIdentity: String {
        "\(model.state?.sessionID ?? -1):\(model.state?.version ?? -1):\(kind.rawValue)"
    }
    /// Replaces `photoCheckForm` (`SUBMIT_PHOTO_CHECK` with `imageUrl`).
    @ViewBuilder var cameraPhotoCheckForm: some View {
        if raw["mode"].text == "CARD" { cameraObjectCardForm } else { cameraOrdinaryPhotoCheck }
    }
    /// MP `playkit-photocheck` under the shell kicker (title, default 拍一张): shotNote → last photo → verdict → reason →
    /// 照片已核验 → reward note → 还能重拍 N 次 (only while there is no verdict) → capture flow. The framing outline is used
    /// only inside the camera (MP `pcv`), never drawn on the page.
    @ViewBuilder private var cameraOrdinaryPhotoCheck: some View {
        let passed = raw["passed"].bool == true
        let used = raw["tries"].integer ?? 0
        let cap = raw["maxTries"].integer ?? 0
        let verdict = cameraPhotoVerdict
        let reason = cameraPhotoReason
        Section {
            if let note = raw["shotNote"].text, !note.isEmpty { Text(verbatim: note).font(.headline) }
            if let prior = raw["lastUrl"].text, !prior.isEmpty {
                artwork(prior).accessibilityLabel(Text("playkit.photo.lastShot"))
            }
            if let verdict {
                Label { Text(verdict.text) } icon: {
                    Image(systemName: verdict.ok ? "checkmark.circle.fill" : (verdict.no ? "xmark.circle.fill" : "questionmark.circle"))
                }
                .font(.headline)
                .foregroundStyle(verdict.ok ? Color.green : (verdict.no ? Color.orange : Color.secondary))
                .accessibilityIdentifier("playkit.photo.verdict")
            }
            if let reason { Text(verbatim: reason).foregroundStyle(.secondary) }
            if passed, raw["photoVerified"].bool == true {
                Text("playkit.photo.verified").font(.footnote).foregroundStyle(.secondary)
            }
            if passed, raw["rewardCeiling"].text == "XP_BADGE_ONLY" {
                Text("playkit.rewardNote.xpBadgeOnly").font(.footnote).foregroundStyle(.secondary)
            }
            if verdict == nil, reason == nil, cap > 0, raw["recordOnly"].bool != true {
                Text("playkit.photo.triesLeft \(max(0, cap - used))").font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        cameraPhotoInput(frame: PlayKitPhotoFrame(source: raw["frameUrl"].text, opacityPercent: raw["frameOpacity"].double,
                                                  approvedHosts: approvedArtworkHosts)) { url in
            prepare("SUBMIT_PHOTO_CHECK", ["imageUrl": .string(url)])
        }
    }
    /// MP verdict ladder: degraded (no conclusion) → record-only → fallback pass → pass → retake after a try.
    private var cameraPhotoVerdict: (text: LocalizedStringKey, ok: Bool, no: Bool)? {
        let passed = raw["passed"].bool == true
        if raw["degraded"].bool == true {
            return (passed ? "playkit.photo.verdict.degradedPass" : "playkit.photo.verdict.degradedRetry", false, false)
        }
        if passed, raw["recordOnly"].bool == true { return ("playkit.photo.verdict.recorded", true, false) }
        if passed, raw["flagged"].bool == true { return ("playkit.photo.verdict.fallback", true, false) }
        if passed { return ("playkit.photo.verdict.passed", true, false) }
        if (raw["tries"].integer ?? 0) > 0 { return ("playkit.photo.retryTitle", false, true) }
        return nil
    }
    /// The server's real reason, only after a failed try or an unjudged retake.
    private var cameraPhotoReason: String? {
        guard raw["passed"].bool != true else { return nil }
        guard raw["degraded"].bool == true || (raw["tries"].integer ?? 0) > 0 else { return nil }
        let reason = raw["lastReason"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reason.isEmpty ? nil : reason
    }
    @ViewBuilder private var cameraObjectCardForm: some View {
        if let receipt = model.objectCardReceipt {
            CameraObjectCardRevealView(receipt: receipt, approvedHosts: approvedArtworkHosts,
                isCurrent: { model.isCurrent && model.objectCardReceipt == receipt })
                .id("\(receipt.sessionID):\(receipt.nodeID):\(receipt.version):\(receipt.card.id)")
        } else if model.phase == "submitting" {
            Section {
                ProgressView("nativeR2.gamesB.objectCard.processing")
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("playCard.processing"))
                    .accessibilityIdentifier("playCard.processing")
            }
        } else if raw["passed"].bool == true || raw["flagged"].bool == true {
            // Completion and minting are different server facts; never fake a reveal.
            Section {
                Label("playCard.noReceipt", systemImage: "rectangle.badge.questionmark")
                    .accessibilityIdentifier("playCard.noReceipt")
            } footer: {
                Text("playCard.noReceiptDetail")
            }
        } else {
            Section {
                if raw["degraded"].bool == true { Text("playCard.degraded").accessibilityIdentifier("playCard.degraded") }
            } header: {
                Text("playCard.capture")
            }
            cameraOrdinaryPhotoCheck
        }
    }
    /// Replaces `scanForm` (`SUBMIT_SCAN` with `code`).
    @ViewBuilder var cameraScanForm: some View {
        if projection.complete {
            Section {
                if let reply = raw["reply"].text, !reply.isEmpty { Text(verbatim: reply).font(.headline) }
                artwork(raw["imageUrl"].text)
                PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
            }
            if raw["kind"].text == "OVERLAY" || raw["overlayUrl"].text?.isEmpty == false {
                Section {
                    if let overlay = PlayKitScanOverlay(segment: raw, approvedHosts: approvedArtworkHosts) {
                        PlayKitCameraOverlayButton(overlay: overlay, identity: runtimeIdentity,
                            cameraEnabled: device?.supports(.scan) == true, active: model.isCurrent)
                    }
                    artwork(raw["overlayUrl"].text)
                    if ["PLANE", "MARKER"].contains(raw["arMode"].text ?? "") {
                        PlayKitSpatialRevealButton(segment: raw, approval: spatialApproval, identity: runtimeIdentity, active: model.isCurrent)
                    }
                }
            }
        } else if let device {
            CameraScanInput(model: device, identity: cameraEvidenceIdentity, enabled: enabled, onDirty: { dirty = true }) { code in
                prepare("SUBMIT_SCAN", ["code": .string(code)])
            }
        } else {
            Section { Label("playkit.camera.gated", systemImage: "camera") }
        }
    }
    @ViewBuilder private func cameraPhotoInput(frame: PlayKitPhotoFrame? = nil, onURL: @escaping (String) -> Void) -> some View {
        if let device {
            CameraPhotoInput(
                model: device,
                identity: cameraEvidenceIdentity,
                enabled: enabled,
                frame: frame,
                submitFailed: kind == .photoCheck && model.phase != "submitting" && model.issue != nil,
                judging: kind == .photoCheck && model.phase == "submitting",
                onDirty: { dirty = true },
                onURL: onURL
            )
        } else {
            Section { Label("playkit.camera.gated", systemImage: "camera") }
        }
    }
}
