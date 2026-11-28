import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension PlayKitScreen {
    /// Mini-program 出生登记: the register card on top, then one question at a time with
    /// 上一题 / "i / n", the avatar as the last step, and 下一题 → 完成建档. Submit stays one write.
    @ViewBuilder var profileForm: some View {
        let questions = (raw["questions"].array ?? []).filter { ($0["key"].text ?? "").isEmpty == false }
        let avatarEnabled = raw["avatar"]["enabled"].bool == true
        let total = questions.count + (avatarEnabled ? 1 : 0)
        let step = min(profileStep, max(0, total - 1))
        let done = projection.complete
        let final = step >= total - 1
        profileSummary(questions)
        if !done && total > 0 {
            HStack {
                if step > 0 {
                    Button("playkit.profile.previous") { profileStep = step - 1 }
                        .cyText(.label).foregroundStyle(CYColor.textSecondary)
                        .disabled(!enabled)
                        .accessibilityIdentifier("playkit.profile.previous")
                }
                Spacer()
                Text(verbatim: "\(step + 1) / \(total)").cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textTertiary)
                    .accessibilityLabel(Text("playkit.profile.stepCount \(step + 1) \(total)"))
                    .accessibilityIdentifier("playkit.profile.step")
            }
        }
        if !done, questions.indices.contains(step) { profileQuestion(questions[step]) }
        if avatarEnabled && ((!done && step == questions.count) || (done && !avatarURL.isEmpty)) {
            VStack(spacing: CYSpacing.sm) {
                if !avatarURL.isEmpty { artwork(avatarURL).frame(maxWidth: 160); Label("playkit.profile.avatarReady", systemImage: "person.crop.circle.badge.checkmark") }
                else {
                    HStack(spacing: CYSpacing.xxs) {
                        Text(LocalizedStringKey(raw["avatar"]["required"].bool == true ? "playkit.profile.avatarRequired" : "playkit.profile.avatarOptional"))
                        if raw["avatar"]["required"].bool == true { Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true) }
                    }.cyText(.label)
                }
                if !done { photoInput { url in avatarURL = url; dirty = true } }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("playkit.profile.avatar")
        }
        if done {
            // N-KIT-FORMS: a system label instead of the rotated stamp.
            Label("playkit.profile.seal", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("playkit.profile.sealLabel"))
                .accessibilityIdentifier("playkit.profile.seal")
            Button("playkit.profile.registered") {}.buttonStyle(.bordered).disabled(true)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("playkit.submit.profile")
        } else if final {
            Text("playkit.profile.lockNotice").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            let payload: [String: PlayWireValue] = ["answers": .object(answers.mapValues(PlayWireValue.string)), "avatarUrl": .string(avatarURL)]
            Button("playkit.profile.finish") { prepare("SUBMIT_PROFILE", payload) }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).disabled(!enabled || !valid("SUBMIT_PROFILE", payload))
                .accessibilityIdentifier("playkit.submit.profile")
        } else {
            Button("playkit.profile.next") { profileStep = step + 1 }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                .disabled(!enabled || !questions.indices.contains(step) || !profileAnswered(questions[step]))
                .accessibilityIdentifier("playkit.profile.next")
        }
    }
    /// The register card: every question with the answer written so far (option label for picks).
    /// N-KIT-FORMS: a system `GroupBox` of `LabeledContent` rows instead of a custom card.
    private func profileSummary(_ questions: [PlayWireValue]) -> some View {
        GroupBox {
            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                let key = question["key"].text ?? ""
                let value = answers[key] ?? ""
                let shown = PlayKitOption.read(question["options"], idKey: "key").first { $0.id == value }?.label ?? value
                LabeledContent {
                    Text(verbatim: shown.isEmpty ? "—" : shown)
                } label: {
                    Text(verbatim: question["label"].text ?? key)
                }
                .accessibilityElement(children: .combine)
            }
        } label: {
            if projection.title.isEmpty { Text("playkit.profile.formTitle") } else { Text(verbatim: projection.title) }
        }
        .accessibilityIdentifier("playkit.profile.summary")
    }
    @ViewBuilder private func profileQuestion(_ question: PlayWireValue) -> some View {
        let key = question["key"].text ?? ""
        let limit = profileLimit(question)
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.xxs) {
                Text(verbatim: question["label"].text ?? key).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(Text("playkit.profile.required"))
            if question["kind"].text == "pick" {
                ForEach(PlayKitOption.read(question["options"], idKey: "key")) { option in
                    let selected = answers[key] == option.id
                    Button { answers[key] = option.id; dirty = true } label: {
                        HStack {
                            Text(verbatim: option.label)
                            Spacer()
                            if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!enabled)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            } else {
                TextField("playkit.profile.placeholder", text: Binding(get: { answers[key] ?? "" }, set: {
                    answers[key] = PlayKitInputContract.limitText($0, toUTF16: limit); dirty = true
                }), axis: .vertical).textFieldStyle(.roundedBorder).disabled(!enabled)
                    .accessibilityLabel(Text(verbatim: question["label"].text ?? key))
                    .accessibilityIdentifier("playkit.profile.field." + key)
                Text(verbatim: "\((answers[key] ?? "").utf16.count) / \(limit)").accessibilityLabel(Text("a11y.value.characters \(Int((answers[key] ?? "").utf16.count)) \(Int(limit))"))
                    .cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .id(key)
        .accessibilityIdentifier("playkit.profile.question." + key)
    }
    /// Mini-program default is 12 characters when the merchant set no limit.
    private func profileLimit(_ question: PlayWireValue) -> Int {
        let configured = question["maxLength"].integer ?? 0
        return configured > 0 ? configured : 12
    }
    private func profileAnswered(_ question: PlayWireValue) -> Bool {
        let value = (answers[question["key"].text ?? ""] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        if question["kind"].text == "pick" { return PlayKitOption.read(question["options"], idKey: "key").contains { $0.id == value } }
        return value.utf16.count <= profileLimit(question)
    }
    @ViewBuilder var noteForm: some View {
        let limit = PlayKitShortMessageLimit.resolve(raw["maxLength"])
        if (raw["previous"].array ?? []).contains(where: { !($0["text"].text ?? "").isEmpty }) {
            Text("playkit.note.previousLabel").cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        ForEach(Array((raw["previous"].array ?? []).enumerated()), id: \.offset) { _, note in
            if let value = note["text"].text, !value.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: value)
                        if let at = note["at"].double, at.isFinite { Text(Date(timeIntervalSince1970: at / 1000), style: .date).font(.footnote).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        TextField("playkit.note.placeholder", text: textBinding(limit: limit), axis: .vertical).lineLimit(3...8).textFieldStyle(.roundedBorder).disabled(!enabled)
        Text(verbatim: "\(text.utf16.count) / \(limit)").accessibilityLabel(Text("a11y.value.characters \(Int(text.utf16.count)) \(Int(limit))")).cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity, alignment: .trailing)
        // Preset lines sit under the field as small chips, as in the mini-program.
        let presets = (raw["presets"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !presets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                        Button { text = PlayKitInputContract.limitText(preset, toUTF16: limit); dirty = true } label: { Text(verbatim: preset) }
                            .buttonStyle(.bordered).controlSize(.small)
                            .disabled(!enabled)
                            .accessibilityAddTraits(text == preset ? .isSelected : [])
                    }
                }
            }.frame(maxWidth: .infinity)
        }
        Text("playkit.note.audience").cyText(.meta).foregroundStyle(CYColor.textSecondary)
        submitButton("SUBMIT_NOTE", payload: ["text": .string(text)], valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    @ViewBuilder var photoCheckForm: some View {
        if raw["mode"].text == "CARD" { objectCardForm }
        else { ordinaryPhotoCheckForm }
    }
    @ViewBuilder var ordinaryPhotoCheckForm: some View {
        if let note = raw["shotNote"].text, !note.isEmpty { Text(verbatim: note).cyText(.sectionTitle) }
        if let frame = raw["frameUrl"].text, !frame.isEmpty { artwork(frame) }
        if let prior = raw["lastUrl"].text, !prior.isEmpty { artwork(prior) }
        if raw["degraded"].bool != true, raw["passed"].bool != true, raw["flagged"].bool != true, (raw["tries"].integer ?? 0) > 0 {
            // Mini-program retry state: a short headline, then the reviewer's reason.
            Text("playkit.photo.retryTitle").cyText(.cardTitle).frame(maxWidth: .infinity)
            if let reason = raw["lastReason"].text, !reason.isEmpty { Text(verbatim: reason).cyText(.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
        }
        if let used = raw["tries"].integer, let cap = raw["maxTries"].integer, cap > 0 {
            LabeledContent("playkit.photo.remaining") { Text(verbatim: String(max(0, cap - used))) }
        }
        if raw["flagged"].bool == true { Text("playkit.photo.fallbackRecorded") }
        photoInput(frame: PlayKitPhotoFrame(source: raw["frameUrl"].text, opacityPercent: raw["frameOpacity"].double, approvedHosts: approvedArtworkHosts)) { url in prepare("SUBMIT_PHOTO_CHECK", ["imageUrl": .string(url)]) }
    }
    @ViewBuilder var scanForm: some View {
        if projection.complete {
            if let reply = raw["reply"].text, !reply.isEmpty { Text(verbatim: reply).cyText(.sectionTitle) }
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
            Text("playkit.scan.scopeLine").cyText(.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            PlayKitScanInput(model: device, identity: evidenceIdentity, enabled: enabled, onDirty: { dirty = true }) { code in prepare("SUBMIT_SCAN", ["code": .string(code)]) }
        } else { Label("playkit.camera.gated", systemImage: "camera") }
    }
    func photoInput(frame: PlayKitPhotoFrame? = nil, onURL: @escaping (String) -> Void) -> some View {
        Group {
            if let device {
                PlayKitPhotoInput(
                    model: device,
                    identity: evidenceIdentity,
                    enabled: enabled,
                    frame: frame,
                    submitFailed: kind == .photoCheck && model.phase != "submitting" && model.issue != nil,
                    judging: kind == .photoCheck && model.phase == "submitting",
                    onDirty: { dirty = true },
                    onURL: onURL
                )
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
    let identity: String; let enabled: Bool; var frame: PlayKitPhotoFrame? = nil
    var submitFailed: Bool = false
    var judging: Bool = false
    let onDirty: () -> Void; let onURL: (String) -> Void
    @State private var capturedIdentity: String?
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @State private var cameraPurpose = false
    @State private var uploadReview = false
    @State private var mounted = false
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            // N-KIT-FORMS: system buttons; the one prominent button is the current step (capture → upload → use).
            Button { cameraPurpose = true } label: { Label("playkit.photo.capture", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                .modifier(PlayKitStepButtonStyle(prominent: photoStep == 0))
                .disabled(!enabled || model.busy || !model.supports(.photo))
            Button {
                let expected = identity; capturedIdentity = expected
                Task {
                    await model.capture(.photo, usePhotoLibrary: true)
                    if !mounted || identity != expected { model.cancel() }
                    else if let output = model.output, case .photo = output { onDirty() }
                }
            } label: { Label("playkitCamera.choosePhoto", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
            .disabled(!enabled || model.busy || !model.supportsLibraryPhotos)
            if !model.supports(.photo) { Text("playkit.camera.gated").cyText(.bodyCompact) }
            if model.busy { ProgressView("playkit.photo.working") }
            if judging { ProgressView("playkit.photo.judging") }
            if capturedIdentity == identity, let output = model.output, case .photo(let bytes, _) = output {
                if let image = UIImage(data: bytes) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240).accessibilityLabel(Text("playkit.photo.preview")) }
                if bytes.count > 10 * 1024 * 1024 { Text("playkit.photo.tooLarge") }
                Button { uploadReview = true } label: { Label("playkit.photo.upload", systemImage: "icloud.and.arrow.up").frame(maxWidth: .infinity) }
                    .modifier(PlayKitStepButtonStyle(prominent: photoStep == 1))
                    .disabled(!enabled || !model.canUpload || bytes.isEmpty || bytes.count > 10 * 1024 * 1024)
                if !model.canUpload && model.uploadedPhoto == nil && !model.busy { Text("playkit.photo.uploadGate").cyText(.bodyCompact) }
                if model.uploadedPhoto == nil, model.issue != nil {
                    Label("playkit.photo.uploadFailedRetake", systemImage: "exclamationmark.triangle").foregroundStyle(CYColor.warningText)
                }
                if let evidence = model.reviewedPhoto(), case .photo(let uploadedURL) = evidence {
                    Label("playkit.photo.uploaded", systemImage: "checkmark.circle")
                    if submitFailed {
                        Label("playkit.photo.submitFailedKept", systemImage: "arrow.clockwise.circle").foregroundStyle(CYColor.warningText)
                    }
                    Button {
                        if mounted && capturedIdentity == identity && enabled { onURL(uploadedURL) }
                    } label: {
                        Label(LocalizedStringKey(submitFailed ? "playkit.photo.resubmit" : "playkit.photo.use"),
                              systemImage: submitFailed ? "arrow.clockwise" : "checkmark").frame(maxWidth: .infinity)
                    }
                    .modifier(PlayKitStepButtonStyle(prominent: photoStep == 2))
                    .disabled(!enabled || judging)
                }
            }
            if let issue = model.issue {
                PlayExperienceIssueView(issue: issue)
                if issue == .disabled, let settingsURL = Self.settingsURL {
                    Button { openURL(settingsURL) } label: { Label("playkit.media.openSettings", systemImage: "gear") }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("playkit.photo.openSettings")
                }
            }
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

    /// 0 capture, 1 upload, 2 use (the old step indicator's current index).
    private var photoStep: Int { model.reviewedPhoto() != nil ? 2 : (capturedIdentity == identity && model.output != nil) ? 1 : 0 }

    private static var settingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}

@MainActor struct PlayKitScanInput: View {
    @Bindable var model: PlayDeviceCaptureCoordinator
    let identity: String; let enabled: Bool; let onDirty: () -> Void; let onCode: (String) -> Void
    @Environment(\.openURL) private var openURL
    @State private var purpose = false
    @State private var capturedIdentity: String?
    @State private var mounted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // r10 N-KIT-FORMS: MP playkit-photo/-scan use one primary button per step (pages/playkit/components/playkit-photo).
            Button { purpose = true } label: { Label("playkit.scan.capture", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity) }
                .modifier(PlayKitStepButtonStyle(prominent: !(capturedIdentity == identity && model.output != nil)))
                .disabled(!enabled || model.busy || !model.supports(.scan))
            if !model.supports(.scan) { Text("playkit.camera.gated") }
            if model.busy { ProgressView("playkit.scan.working") }
            if capturedIdentity == identity, let output = model.output, case .scan(let code) = output {
                Label("playkit.scan.captured", systemImage: "qrcode")
                Button { if mounted && enabled { onCode(code) } } label: { Label("playkit.review", systemImage: "checkmark").frame(maxWidth: .infinity) }
                    .modifier(PlayKitStepButtonStyle(prominent: true))
                    .disabled(!enabled)
            }
            if let issue = model.issue {
                PlayExperienceIssueView(issue: issue)
                if issue == .disabled, let settingsURL = Self.settingsURL {
                    Button { openURL(settingsURL) } label: { Label("playkit.media.openSettings", systemImage: "gear") }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("playkit.scan.openSettings")
                }
            }
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

    private static var settingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}

/// N-KIT-FORMS: `.borderedProminent` for the current step's button, `.bordered` otherwise.
struct PlayKitStepButtonStyle: ViewModifier {
    let prominent: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if prominent { content.buttonStyle(.borderedProminent).controlSize(.large) } else { content.buttonStyle(.bordered).controlSize(.large) }
    }
}
