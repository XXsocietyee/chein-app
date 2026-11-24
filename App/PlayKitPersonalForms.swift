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
            Text("playkit.profile.seal")
                .cyText(.cardTitle).foregroundStyle(CYColor.dangerText)
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).strokeBorder(CYColor.dangerText, lineWidth: 2))
                .rotationEffect(.degrees(-6))
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("playkit.profile.sealLabel"))
                .accessibilityIdentifier("playkit.profile.seal")
            CYPillButton("playkit.profile.registered") {}.disabled(true).accessibilityIdentifier("playkit.submit.profile")
        } else if final {
            Text("playkit.profile.lockNotice").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            let payload: [String: PlayWireValue] = ["answers": .object(answers.mapValues(PlayWireValue.string)), "avatarUrl": .string(avatarURL)]
            Button("playkit.profile.finish") { prepare("SUBMIT_PROFILE", payload) }
                .buttonStyle(.questifyPrimary).disabled(!enabled || !valid("SUBMIT_PROFILE", payload))
                .accessibilityIdentifier("playkit.submit.profile")
        } else {
            CYPillButton("playkit.profile.next") { profileStep = step + 1 }
                .disabled(!enabled || !questions.indices.contains(step) || !profileAnswered(questions[step]))
                .accessibilityIdentifier("playkit.profile.next")
        }
    }
    /// The register card: every question with the answer written so far (option label for picks).
    private func profileSummary(_ questions: [PlayWireValue]) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Group { if projection.title.isEmpty { Text("playkit.profile.formTitle") } else { Text(verbatim: projection.title) } }
                .cyText(.meta).tracking(4).foregroundStyle(CYColor.textTertiary)
                .frame(maxWidth: .infinity)
            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                let key = question["key"].text ?? ""
                let value = answers[key] ?? ""
                let shown = PlayKitOption.read(question["options"], idKey: "key").first { $0.id == value }?.label ?? value
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.lg) {
                    Text(verbatim: question["label"].text ?? key).cyText(.body).foregroundStyle(CYColor.textTertiary)
                    Text(verbatim: shown.isEmpty ? "—" : shown).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, CYSpacing.xs)
                .overlay(alignment: .bottom) { Rectangle().fill(CYColor.borderSubtle).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(CYSpacing.lg)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYColor.bgElevated))
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
                    CYChoiceRow(label: option.label, selected: answers[key] == option.id, enabled: enabled) {
                        answers[key] = option.id; dirty = true
                    }
                }
            } else {
                TextField("playkit.profile.placeholder", text: Binding(get: { answers[key] ?? "" }, set: {
                    answers[key] = PlayKitInputContract.limitText($0, toUTF16: limit); dirty = true
                })).cyField().disabled(!enabled)
                    .accessibilityLabel(Text(verbatim: question["label"].text ?? key))
                    .accessibilityIdentifier("playkit.profile.field." + key)
                Text(verbatim: "\((answers[key] ?? "").utf16.count) / \(limit)")
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
                CYInfoCard {
                    Text(verbatim: value).cyText(.body).foregroundStyle(CYColor.textPrimary)
                    if let at = note["at"].double, at.isFinite { Text(Date(timeIntervalSince1970: at / 1000), style: .date).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                }
            }
        }
        TextField("playkit.note.placeholder", text: textBinding(limit: limit), axis: .vertical).lineLimit(3...8).cyField().disabled(!enabled)
        Text(verbatim: "\(text.utf16.count) / \(limit)").cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textTertiary).frame(maxWidth: .infinity, alignment: .trailing)
        // Preset lines sit under the field as small chips, as in the mini-program.
        let presets = (raw["presets"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !presets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                        Button { text = PlayKitInputContract.limitText(preset, toUTF16: limit); dirty = true } label: { Text(verbatim: preset).cyText(.label) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
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
            if !model.supports(.photo) { Text("playkit.camera.gated").cyText(.bodyCompact) }
            if model.busy { ProgressView("playkit.photo.working") }
            if judging { ProgressView("playkit.photo.judging") }
            if capturedIdentity == identity, let output = model.output, case .photo(let bytes, _) = output {
                if let image = UIImage(data: bytes) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240).accessibilityLabel(Text("playkit.photo.preview")) }
                if bytes.count > 10 * 1024 * 1024 { Text("playkit.photo.tooLarge") }
                CYPillButton(LocalizedStringKey("playkit.photo.upload"), systemImage: "icloud.and.arrow.up") { uploadReview = true }
                    .disabled(!enabled || !model.canUpload || bytes.isEmpty || bytes.count > 10 * 1024 * 1024)
                if !model.canUpload && model.uploadedPhoto == nil && !model.busy { Text("playkit.photo.uploadGate").cyText(.bodyCompact) }
                if model.uploadedPhoto == nil, model.issue != nil {
                    CYNoteBanner(text: Text("playkit.photo.uploadFailedRetake"), symbol: "exclamationmark.triangle", tone: .warning)
                }
                if let evidence = model.reviewedPhoto(), case .photo(let uploadedURL) = evidence {
                    Label("playkit.photo.uploaded", systemImage: "checkmark.circle")
                    if submitFailed {
                        CYNoteBanner(text: Text("playkit.photo.submitFailedKept"), symbol: "arrow.clockwise.circle", tone: .warning)
                    }
                    CYPillButton(LocalizedStringKey(submitFailed ? "playkit.photo.resubmit" : "playkit.photo.use"), systemImage: submitFailed ? "arrow.clockwise" : "checkmark") {
                        if mounted && capturedIdentity == identity && enabled { onURL(uploadedURL) }
                    }
                    .disabled(!enabled || judging)
                }
            }
            if let issue = model.issue {
                PlayExperienceIssueView(issue: issue)
                if issue == .disabled, let settingsURL = Self.settingsURL {
                    CYPillButton("playkit.media.openSettings", style: .secondary, systemImage: "gear") { openURL(settingsURL) }
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
            CYPillButton(LocalizedStringKey("playkit.scan.capture"), systemImage: "qrcode.viewfinder") { purpose = true }.disabled(!enabled || model.busy || !model.supports(.scan))
            if !model.supports(.scan) { Text("playkit.camera.gated") }
            if model.busy { ProgressView("playkit.scan.working") }
            if capturedIdentity == identity, let output = model.output, case .scan(let code) = output {
                Label("playkit.scan.captured", systemImage: "qrcode")
                CYPillButton(LocalizedStringKey("playkit.review"), systemImage: "checkmark") { if mounted && enabled { onCode(code) } }.disabled(!enabled)
            }
            if let issue = model.issue {
                PlayExperienceIssueView(issue: issue)
                if issue == .disabled, let settingsURL = Self.settingsURL {
                    CYPillButton("playkit.media.openSettings", style: .secondary, systemImage: "gear") { openURL(settingsURL) }
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
