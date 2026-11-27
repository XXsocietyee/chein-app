import SwiftUI
import UIKit

/// Optional injection only. No AppSession/composition factory supplies this capability.
@MainActor struct ProfileAvatarDependencies {
    let source: ProfileAvatarUploadClient
    let journal: any ProfileAvatarJournaling
    let pickerHost: RetainedImagePickerHost?
    init(source: ProfileAvatarUploadClient, journal: any ProfileAvatarJournaling, pickerHost: RetainedImagePickerHost? = nil) {
        self.source = source; self.journal = journal; self.pickerHost = pickerHost
    }
}
@MainActor private final class ProfileAvatarPresentation: ObservableObject {
    @Published private(set) var flow: ProfileAvatarFlow?
    @Published private(set) var crop: MerchantImageCropDraft?
    @Published private(set) var preview: RetainedSelectedImage?
    @Published private(set) var revision: UInt64 = 0
    @Published private(set) var selecting = false
    private weak var model: ProfileEditModel?
    private let dependencies: ProfileAvatarDependencies
    /// A3-01: the avatar presentation crops 1:1; 探索作品 / 联系二维码 keep the picked frame.
    let kind: ProfileMediaKind
    private var picker: RetainedNativeImagePicker?
    private var selectionTask: Task<Void, Never>?
    init(model: ProfileEditModel, dependencies: ProfileAvatarDependencies, kind: ProfileMediaKind = .avatar) {
        self.model = model; self.dependencies = dependencies; self.kind = kind
        if kind == .avatar { model.observeAvatarRetirement { [weak self] in self?.retire() } }
        else { model.observeMediaRetirement(kind) { [weak self] in self?.retire() } }
    }
    var canOpen: Bool {
        guard flow == nil, dependencies.pickerHost != nil, let model, let target = model.mediaTarget(source: dependencies.source, kind: kind) else { return false }
        return dependencies.source.permitsPicker(target.scope)
    }
    func open() {
        guard canOpen, let model, let target = model.mediaTarget(source: dependencies.source, kind: kind) else { return }
        let kind = kind
        preview = nil; crop = nil
        flow = ProfileAvatarFlow(target: target, source: dependencies.source, journal: dependencies.journal,
            currentSnapshot: { [weak model] in guard let model, !model.busy, !model.coordinator.isBusy else { return nil }; return model.coordinator.snapshot },
            currentDraft: { [weak model] in model?.draft }, currentRevision: { [weak model] in model?.avatarDraftRevision ?? 0 },
            ownerCurrent: { [weak model] in model?.ownsAvatarScope(target.scope) == true },
            kind: kind,
            apply: { [weak model, weak self] replacement in model?.stageMedia(replacement, kind: kind, preview: self?.preview) })
        model.avatarPresentationActive = true; revision &+= 1
    }
    func pick(_ original: ProfileAvatarFlow) {
        guard flow === original, let id = original.beginPicking(), let host = dependencies.pickerHost else { return }
        let source = dependencies.source
        let picker = host.makePicker { [weak original] in
            guard let original else { return false }
            return original.ownsTarget && source.permitsPicker(original.target.scope)
        }
        self.picker = picker; selecting = true
        selectionTask = Task { [weak self, weak original] in
            guard let self, let original else { return }
            let image = try? await picker.select()
            original.endPicking(id)
            guard self.flow === original, original.ownsTarget, !Task.isCancelled else { return }
            self.selecting = false; self.picker = nil; self.selectionTask = nil
            if let image {
                if self.kind == .avatar { self.crop = .init(source: image, aspect: .logo) }
                else { self.preview = image; original.prepare(image) }
            }
            self.revision &+= 1
        }
    }
    func acceptCrop(_ id: UUID, rect: MerchantImageCropRect, flow original: ProfileAvatarFlow) {
        guard flow === original, original.ownsTarget, let crop, crop.id == id,
              let image = try? MerchantImageCropRenderer.render(crop.source, rect: rect), image.width == image.height else { return }
        self.crop = nil; preview = image; original.prepare(image); revision &+= 1
    }
    func cancelCrop() { crop = nil; revision &+= 1 }
    func upload(_ review: ProfileAvatarFlow.Review, flow original: ProfileAvatarFlow) async {
        guard flow === original else { return }; revision &+= 1
        let task = Task { await original.confirm(review) }
        await Task.yield(); revision &+= 1
        await task.value; guard flow === original else { return }; revision &+= 1
    }
    func stage(_ original: ProfileAvatarFlow) {
        guard flow === original else { return }; original.stage(); revision &+= 1
        if original.state == .staged { close(original) }
    }
    func close(_ original: ProfileAvatarFlow) {
        guard flow === original else { return }
        selectionTask?.cancel(); selectionTask = nil; picker?.cancel(); picker = nil
        original.close(); flow = nil; crop = nil; preview = nil; selecting = false
        model?.avatarPresentationActive = false; revision &+= 1
    }
    func retire() { if let flow { close(flow) } }
}

@MainActor struct ProfileAvatarDraftSection: View {
    @ObservedObject var model: ProfileEditModel
    let dependencies: ProfileAvatarDependencies?
    var body: some View {
        // Without the picker dependencies (upload grant not composed) say so honestly instead of hiding the row.
        if let dependencies { ProfileAvatarEnabledSection(model: model, dependencies: dependencies) }
        else {
            Section("profile.avatar.title") {
                Text("profile.avatar.notAvailable").foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.avatar.notAvailable")
            }
        }
    }
}
@MainActor private struct ProfileAvatarEnabledSection: View {
    @ObservedObject var model: ProfileEditModel
    @StateObject private var presentation: ProfileAvatarPresentation
    @Environment(\.scenePhase) private var scenePhase
    @State private var discardID: UUID?
    init(model: ProfileEditModel, dependencies: ProfileAvatarDependencies) {
        self.model = model; _presentation = StateObject(wrappedValue: .init(model: model, dependencies: dependencies))
    }
    private var isPresented: Binding<Bool> {
        let original = presentation.flow
        return .init(get: { scenePhase == .active && presentation.flow === original && original != nil },
                     set: { if !$0, let original { presentation.close(original) } })
    }
    var body: some View {
        Section("profile.avatar.title") {
            if let replacement = model.draft.avatarReplacement {
                if let preview = model.avatarPreview, let image = UIImage(data: preview.jpeg) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 120)
                        .accessibilityLabel("profile.avatar.preview")
                }
                Text("profile.avatar.staged").accessibilityIdentifier("profile.avatar.staged")
                Button("profile.avatar.discard", role: .destructive) { discardID = replacement.id }
                    .disabled(model.busy || model.coordinator.isLocked)
            } else {
                Button("profile.avatar.select") { guard scenePhase == .active else { return }; presentation.open() }
                    .disabled(!presentation.canOpen || model.busy || model.coordinator.isLocked || scenePhase != .active)
                    .accessibilityIdentifier("profile.avatar.select")
            }
        }
        .cySheet(isPresented: Binding(get: { discardID != nil }, set: { if !$0 { discardID = nil } })) {
            if let id = discardID {
                MemberProfileDiscardConfirmSheet(kind: .avatarDiscard) {
                    model.discardAvatar(id: id)
                    discardID = nil
                }
            }
        }
        .onChange(of: model.avatarLifetimeID) { _, _ in discardID = nil; presentation.retire() }
        .cySheet(isPresented: isPresented) {
            if let flow = presentation.flow { ProfileMediaFlowSheet(presentation: presentation, flow: flow).cySheet(detents: [.large]) }
        }
    }
}

/// One selection → (avatar: 1:1 crop) → upload → use-this-image sheet, shared by the avatar and
/// the A3-01 探索作品 / 联系二维码 uploads. Only the copy and the crop step depend on the kind.
@MainActor private struct ProfileMediaFlowSheet: View {
    @ObservedObject var presentation: ProfileAvatarPresentation
    let flow: ProfileAvatarFlow
    private var kind: ProfileMediaKind { presentation.kind }
    private func key(_ avatar: String, _ casePicture: String, _ contactQR: String) -> LocalizedStringKey {
        switch kind {
        case .avatar: return LocalizedStringKey(avatar)
        case .casePicture: return LocalizedStringKey(casePicture)
        case .contactQR: return LocalizedStringKey(contactQR)
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                if let crop = presentation.crop {
                    ProfileAvatarCropView(draft: crop, confirm: { presentation.acceptCrop($0, rect: $1, flow: flow) }, cancel: presentation.cancelCrop)
                } else {
                    if let preview = presentation.preview, let image = UIImage(data: preview.jpeg) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                            .accessibilityLabel(key("profile.avatar.preview", "profile.case.newPreview", "profile.contactQR.newPreview"))
                    }
                    Text("profile.avatar.uploadDisclosure").cyText(.meta)
                    if let review = flow.review {
                        Button("profile.avatar.upload") { Task { await presentation.upload(review, flow: flow) } }
                            .disabled(!flow.ownsTarget).accessibilityIdentifier("profile.avatar.upload")
                        Button("action.cancel") { flow.cancelReview(review); presentation.cancelCrop() }
                    } else if flow.state == .uploaded {
                        Text(key("profile.avatar.uploaded", "profile.case.uploaded", "profile.contactQR.uploaded"))
                        Button(key("profile.avatar.stage", "profile.case.stage", "profile.contactQR.stage")) { presentation.stage(flow) }
                            .disabled(!flow.canStage)
                            .accessibilityIdentifier("profile.avatar.stage")
                    } else if flow.state == .unknown { Text("profile.avatar.unknown") }
                    else if flow.state == .uploading || presentation.selecting { ProgressView("profile.avatar.working") }
                    else {
                        if flow.state == .failed { Text("profile.avatar.failed") }
                        Button(key("profile.avatar.select", "profile.media.select", "profile.media.select")) { presentation.pick(flow) }
                            .disabled(!flow.canSelect)
                    }
                }
            }
            .appNavigationTitle(key: kind == .avatar ? "profile.avatar.title" : (kind == .casePicture ? "profile.case.add" : "profile.contactQR.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { presentation.close(flow) } } }
        }
    }
}

/// A3-01 (mini-program gerenziliao `uploadCasePic` ≤ 9, `uploadWechat`): staged new 探索作品 pictures or
/// a new 联系二维码, plus the add action. Rows only; the caller owns the section. Without the upload grant
/// the row says so instead of disappearing (never hide a feature).
@MainActor struct ProfileMediaUploadRows: View {
    @ObservedObject var model: ProfileEditModel
    let dependencies: ProfileAvatarDependencies?
    let kind: ProfileMediaKind
    var body: some View {
        if let dependencies, kind != .avatar {
            ProfileMediaUploadEnabledRows(model: model, dependencies: dependencies, kind: kind)
        } else {
            Text("profile.media.notAvailable").font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("profile.media.notAvailable.\(kind.rawValue)")
        }
    }
}
@MainActor private struct ProfileMediaUploadEnabledRows: View {
    @ObservedObject var model: ProfileEditModel
    let kind: ProfileMediaKind
    @StateObject private var presentation: ProfileAvatarPresentation
    @Environment(\.scenePhase) private var scenePhase
    init(model: ProfileEditModel, dependencies: ProfileAvatarDependencies, kind: ProfileMediaKind) {
        self.model = model; self.kind = kind
        _presentation = StateObject(wrappedValue: .init(model: model, dependencies: dependencies, kind: kind))
    }
    private var isPresented: Binding<Bool> {
        let original = presentation.flow
        return .init(get: { scenePhase == .active && presentation.flow === original && original != nil },
                     set: { if !$0, let original { presentation.close(original) } })
    }
    private var staged: [ProfileAvatarReplacement] {
        kind == .casePicture ? model.draft.addedCasePictures : [model.draft.contactQRReplacement].compactMap { $0 }
    }
    private var atLimit: Bool {
        kind == .casePicture && (model.coordinator.snapshot.map { model.draft.casePictureCount(keeping: $0) >= ProfileMediaKind.casePictureLimit } ?? false)
    }
    private var addKey: LocalizedStringKey {
        if kind == .casePicture { return "profile.case.add" }
        return (model.coordinator.snapshot?.wechat.isEmpty ?? true) ? "profile.contactQR.upload" : "profile.contactQR.replace"
    }
    var body: some View {
        Group {
            ForEach(staged, id: \.id) { item in
                HStack {
                    if let preview = model.mediaPreviews[item.id], let image = UIImage(data: preview.jpeg) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipped()
                            .accessibilityLabel(LocalizedStringKey(kind == .casePicture ? "profile.case.newPreview" : "profile.contactQR.newPreview"))
                    }
                    Text(LocalizedStringKey(kind == .casePicture ? "profile.case.newStaged" : "profile.contactQR.newStaged"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button(LocalizedStringKey(kind == .casePicture ? "profile.case.removeNew" : "profile.contactQR.discardNew"), role: .destructive) {
                        model.discardMedia(id: item.id)
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.busy || model.coordinator.isLocked)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("profile.media.staged.\(kind.rawValue)")
            }
            if atLimit {
                Text("profile.case.limit").font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.case.limit")
            } else if kind == .casePicture || staged.isEmpty {
                Button { guard scenePhase == .active else { return }; presentation.open() } label: {
                    // MP gerenziliao.wxml:121/140 upload tile `/pages/gerenziliao/images/d_sctb.png` (works and QR alike).
                    Label { Text(addKey) } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.dSctb, side: 22) }
                }
                .disabled(!presentation.canOpen || model.busy || model.coordinator.isLocked || scenePhase != .active)
                .accessibilityIdentifier("profile.media.add.\(kind.rawValue)")
            }
        }
        .onChange(of: model.avatarLifetimeID) { _, _ in presentation.retire() }
        .cySheet(isPresented: isPresented) {
            if let flow = presentation.flow { ProfileMediaFlowSheet(presentation: presentation, flow: flow).cySheet(detents: [.large]) }
        }
    }
}

/// Actual owner removal retires upload/save leases even if a modal was covering the
/// profile. Merely presenting a picker or review sheet does not dismantle this anchor.
@MainActor struct ProfileAvatarOwnerAnchor: UIViewControllerRepresentable {
    let model: ProfileEditModel
    final class Coordinator {
        weak var model: ProfileEditModel?
        init(_ model: ProfileEditModel) { self.model = model }
    }
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) { coordinator.model?.retireAvatar() }
}

/// r8 A7-02 (MP app.js:617-700 → pages/crop?ratio=1:1&shape=circle): the avatar goes through the shared MiniCropView
/// (pinch / pan, dimmed mask, circle, 还原). Its source rectangle maps onto the existing square-rect + redraw primitives.
@MainActor private struct ProfileAvatarCropView: View {
    let draft: MerchantImageCropDraft
    let confirm: (UUID, MerchantImageCropRect) -> Void
    let cancel: () -> Void
    var body: some View {
        if let image = UIImage(data: draft.source.jpeg) {
            MiniCropView(images: [image], ratio: "1:1", shape: .circle, onFinish: { results in
                guard let rect = Self.rect(results.first, source: draft.source) else { cancel(); return }
                confirm(draft.id, rect)
            }, onCancel: cancel)
            .frame(minHeight: 420)
            .listRowInsets(EdgeInsets())
            .accessibilityIdentifier("profile.avatar.crop")
        } else {
            Text("profile.avatar.failed")
            Button("action.cancel", role: .cancel, action: cancel)
        }
    }

    /// Inverse of `MerchantImageCropRect(aspect: .logo, horizontal:vertical:zoom:)`; 使用原图 is the centred full square.
    static func rect(_ result: MiniCropView.Result?, source: RetainedSelectedImage) -> MerchantImageCropRect? {
        let w = source.width, h = source.height
        guard case .crop(let picked)? = result else {
            return try? .init(sourceWidth: w, sourceHeight: h, aspect: .logo)
        }
        let available = Double(min(w, h))
        let side = max(1, min(picked.width, picked.height))
        let zoom = min(4, max(1, available / side))
        let units = max(1, Int((available / zoom).rounded(.down)))
        let travelX = Double(w - units), travelY = Double(h - units)
        let horizontal = travelX > 0 ? min(1, max(0, picked.x / travelX)) : 0.5
        let vertical = travelY > 0 ? min(1, max(0, picked.y / travelY)) : 0.5
        return try? .init(sourceWidth: w, sourceHeight: h, aspect: .logo, horizontal: horizontal, vertical: vertical, zoom: zoom)
    }
}
