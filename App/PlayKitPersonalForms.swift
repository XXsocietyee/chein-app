import SwiftUI

extension PlayKitScreen {
    @ViewBuilder var profileForm: some View {
        if raw["avatar"]["enabled"].bool == true {
            if !avatarURL.isEmpty { artwork(avatarURL); Label("playkit.profile.avatarReady", systemImage: "person.crop.circle.badge.checkmark") }
            photoInput { url in avatarURL = url; dirty = true }
        }
        let questions = (raw["questions"].array ?? []).filter { ($0["key"].text ?? "").isEmpty == false }
        if questions.count > 1 {
            let answered = questions.filter { !(answers[$0["key"].text ?? ""] ?? "").isEmpty }.count
            CYStepIndicator(titles: questions.map { $0["label"].text ?? "" }, current: min(answered, questions.count - 1))
        }
        ForEach(Array((raw["questions"].array ?? []).enumerated()), id: \.offset) { _, question in
            if let key = question["key"].text, !key.isEmpty {
                CYInfoCard {
                    Text(verbatim: question["label"].text ?? key).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if question["kind"].text == "pick" {
                        ForEach(PlayKitOption.read(question["options"], idKey: "key")) { option in
                            CYChoiceRow(label: option.label, selected: answers[key] == option.id, enabled: enabled) {
                                answers[key] = option.id; dirty = true
                            }
                        }
                    } else {
                        TextField("playkit.profile.answer", text: Binding(get: { answers[key] ?? "" }, set: {
                            let maxLength = question["maxLength"].integer ?? 0
                            answers[key] = PlayKitInputContract.limitText($0, toUTF16: maxLength > 0 ? maxLength : 4096); dirty = true
                        }), axis: .vertical).cyField().disabled(!enabled)
                    }
                }
            }
        }
        Text("playkit.profile.lockNotice").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
        let payload: [String: PlayWireValue] = ["answers": .object(answers.mapValues(PlayWireValue.string)), "avatarUrl": .string(avatarURL)]
        submitButton("SUBMIT_PROFILE", payload: payload, valid: valid("SUBMIT_PROFILE", payload))
    }
    @ViewBuilder var noteForm: some View {
        let limit = PlayKitShortMessageLimit.resolve(raw["maxLength"])
        if (raw["previous"].array ?? []).contains(where: { !($0["text"].text ?? "").isEmpty }) {
            Text("playkit.note.previousLabel").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        }
        ForEach(Array((raw["previous"].array ?? []).enumerated()), id: \.offset) { _, note in
            if let value = note["text"].text, !value.isEmpty {
                CYInfoCard {
                    Text(verbatim: value).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                    if let at = note["at"].double, at.isFinite { Text(Date(timeIntervalSince1970: at / 1000), style: .date).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                }
            }
        }
        TextField("playkit.note.placeholder", text: textBinding(limit: limit), axis: .vertical).lineLimit(3...8).cyField().disabled(!enabled)
        Text(verbatim: "\(text.utf16.count) / \(limit)").font(CYTypography.meta.monospacedDigit()).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity, alignment: .trailing)
        // Preset lines sit under the field as small chips, as in the mini-program.
        let presets = (raw["presets"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !presets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                        Button { text = PlayKitInputContract.limitText(preset, toUTF16: limit); dirty = true } label: { Text(verbatim: preset).font(CYTypography.label) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            .disabled(!enabled)
                            .accessibilityAddTraits(text == preset ? .isSelected : [])
                    }
                }
            }.frame(maxWidth: .infinity)
        }
        Text("playkit.note.audience").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
        submitButton("SUBMIT_NOTE", payload: ["text": .string(text)], valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    @ViewBuilder var photoCheckForm: some View {
        if raw["mode"].text == "CARD" { objectCardForm }
        else { ordinaryPhotoCheckForm }
    }
    @ViewBuilder var ordinaryPhotoCheckForm: some View {
        if let note = raw["shotNote"].text, !note.isEmpty { Text(verbatim: note).font(.title3) }
        if let frame = raw["frameUrl"].text, !frame.isEmpty { artwork(frame) }
        if let prior = raw["lastUrl"].text, !prior.isEmpty { artwork(prior) }
        if raw["degraded"].bool != true, raw["passed"].bool != true, raw["flagged"].bool != true, (raw["tries"].integer ?? 0) > 0 {
            // Mini-program retry state: a short headline, then the reviewer's reason.
            Text("playkit.photo.retryTitle").font(CYTypography.cardTitle).frame(maxWidth: .infinity)
            if let reason = raw["lastReason"].text, !reason.isEmpty { Text(verbatim: reason).font(CYTypography.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
        }
        if let used = raw["tries"].integer, let cap = raw["maxTries"].integer, cap > 0 {
            LabeledContent("playkit.photo.remaining") { Text(verbatim: String(max(0, cap - used))) }
        }
        if raw["flagged"].bool == true { Text("playkit.photo.fallbackRecorded") }
        photoInput(frame: PlayKitPhotoFrame(source: raw["frameUrl"].text, opacityPercent: raw["frameOpacity"].double, approvedHosts: approvedArtworkHosts)) { url in prepare("SUBMIT_PHOTO_CHECK", ["imageUrl": .string(url)]) }
    }
    @ViewBuilder var scanForm: some View {
        if projection.complete {
            if let reply = raw["reply"].text, !reply.isEmpty { Text(verbatim: reply).font(.title3) }
            artwork(raw["imageUrl"].text)
            PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
            if raw["kind"].text == "OVERLAY" || raw["overlayUrl"].text?.isEmpty == false {
                if let overlay = PlayKitScanOverlay(segment: raw, approvedHosts: approvedArtworkHosts) {
                    PlayKitCameraOverlayButton(overlay: overlay, identity: runtimeIdentity,
                        cameraEnabled: device?.supports(.scan) == true, active: model.isCurrent)
                }
                artwork(raw["overlayUrl"].text)
                if ["PLANE", "MARKER"].contains(raw["arMode"].text ?? "") {
                    PlayKitSpatialRevealButton(segment: raw, approval: spatialApproval, identity: runtimeIdentity, active: model.isCurrent)
                }
            }
        } else if let device {
            Text("playkit.scan.scopeLine").font(CYTypography.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            PlayKitScanInput(model: device, identity: evidenceIdentity, enabled: enabled, onDirty: { dirty = true }) { code in prepare("SUBMIT_SCAN", ["code": .string(code)]) }
        } else { Label("playkit.camera.gated", systemImage: "camera") }
    }
    func photoInput(frame: PlayKitPhotoFrame? = nil, onURL: @escaping (String) -> Void) -> some View {
        Group {
            if let device {
                PlayKitPhotoInput(model: device, identity: evidenceIdentity, enabled: enabled, frame: frame, onDirty: { dirty = true }, onURL: onURL)
            } else { Label("playkit.camera.gated", systemImage: "camera") }
        }
    }
    private var evidenceIdentity: String { "\(model.state?.sessionID ?? -1):\(model.state?.version ?? -1):\(kind.rawValue)" }
    private func valid(_ action: String, _ payload: [String: PlayWireValue]) -> Bool {
        (try? PlayKitInputContract.validate(kind: kind.rawValue, action: action, payload: payload, segment: raw)) != nil
    }
}

@MainActor struct PlayKitPhotoInput: View {
    @Bindable var model: PlayDeviceCaptureCoordinator
    let identity: String; let enabled: Bool; var frame: PlayKitPhotoFrame? = nil; let onDirty: () -> Void; let onURL: (String) -> Void
    @State private var capturedIdentity: String?
    @Environment(\.locale) private var locale
    @State private var cameraPurpose = false
    @State private var uploadReview = false
    @State private var mounted = false
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYStepIndicator(titles: [ChannelCopy.text("拍摄", "Capture", locale: locale), ChannelCopy.text("上传", "Upload", locale: locale),
                                     ChannelCopy.text("使用", "Use", locale: locale)],
                            current: model.reviewedPhoto() != nil ? 2 : (capturedIdentity == identity && model.output != nil) ? 1 : 0)
            CYPillButton(LocalizedStringKey("playkit.photo.capture"), systemImage: "camera.fill") { cameraPurpose = true }
                .disabled(!enabled || model.busy || !model.supports(.photo))
            CYPillButton(LocalizedStringKey("playkitCamera.choosePhoto"), style: .tertiary, systemImage: "photo.on.rectangle") {
                let expected = identity; capturedIdentity = expected
                Task {
                    await model.capture(.photo, usePhotoLibrary: true)
                    if !mounted || identity != expected { model.cancel() }
                    else if let output = model.output, case .photo = output { onDirty() }
                }
            }.disabled(!enabled || model.busy || !model.supportsLibraryPhotos)
            if !model.supports(.photo) { Text("playkit.camera.gated").font(.footnote) }
            if model.busy { ProgressView("playkit.photo.working") }
            if capturedIdentity == identity, let output = model.output, case .photo(let bytes, _) = output {
                if let image = UIImage(data: bytes) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240).accessibilityLabel(Text("playkit.photo.preview")) }
                if bytes.count > 10 * 1024 * 1024 { Text("playkit.photo.tooLarge") }
                CYPillButton(LocalizedStringKey("playkit.photo.upload"), systemImage: "icloud.and.arrow.up") { uploadReview = true }
                    .disabled(!enabled || !model.canUpload || bytes.isEmpty || bytes.count > 10 * 1024 * 1024)
                if !model.canUpload && model.uploadedPhoto == nil && !model.busy { Text("playkit.photo.uploadGate").font(.footnote) }
                if let evidence = model.reviewedPhoto(), case .photo(let uploadedURL) = evidence {
                    Label("playkit.photo.uploaded", systemImage: "checkmark.circle")
                    CYPillButton(LocalizedStringKey("playkit.photo.use"), systemImage: "checkmark") { if mounted && capturedIdentity == identity && enabled { onURL(uploadedURL) } }.disabled(!enabled)
                }
            }
            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
        }
        .confirmationDialog("playkit.camera.purpose", isPresented: $cameraPurpose, titleVisibility: .visible) {
            Button("playkit.photo.capture") {
                let expected = identity; capturedIdentity = expected
                Task {
                    await model.capture(.photo, cameraFrame: frame)
                    if !mounted || identity != expected { model.cancel() }
                    else if let output = model.output, case .photo = output { onDirty() }
                }
            }
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
        .onAppear { mounted = true; model.cancel() }
        .onChange(of: identity) { _, _ in capturedIdentity = nil; cameraPurpose = false; uploadReview = false; model.cancel() }
        .onDisappear { mounted = false; capturedIdentity = nil; model.cancel() }
    }
}

@MainActor struct PlayKitScanInput: View {
    @Bindable var model: PlayDeviceCaptureCoordinator
    let identity: String; let enabled: Bool; let onDirty: () -> Void; let onCode: (String) -> Void
    @State private var purpose = false
    @State private var capturedIdentity: String?
    @State private var mounted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CYPillButton(LocalizedStringKey("playkit.scan.capture"), systemImage: "qrcode.viewfinder") { purpose = true }.disabled(!enabled || model.busy || !model.supports(.scan))
            if !model.supports(.scan) { Text("playkit.camera.gated") }
            if model.busy { ProgressView("playkit.scan.working") }
            if capturedIdentity == identity, let output = model.output, case .scan(let code) = output {
                Label("playkit.scan.captured", systemImage: "qrcode")
                CYPillButton(LocalizedStringKey("playkit.review"), systemImage: "checkmark") { if mounted && enabled { onCode(code) } }.disabled(!enabled)
            }
            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
        }
        .confirmationDialog("playkit.camera.purpose", isPresented: $purpose, titleVisibility: .visible) {
            Button("playkit.scan.capture") {
                let expected = identity; capturedIdentity = expected
                Task {
                    await model.capture(.scan)
                    if !mounted || identity != expected { model.cancel() }
                    else if let output = model.output, case .scan = output { onDirty() }
                }
            }
            Button("playkit.cancel", role: .cancel) {}
        } message: { Text("playkit.camera.scanPurpose") }
        .onAppear { mounted = true; model.cancel() }
        .onChange(of: identity) { _, _ in capturedIdentity = nil; purpose = false; model.cancel() }
        .onDisappear { mounted = false; model.cancel() }
    }
}
