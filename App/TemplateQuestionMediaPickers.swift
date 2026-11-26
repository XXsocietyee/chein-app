import SwiftUI

// Screens r4 · verify-r1 2.10 (CF-49 "media is picked, not typed"): 题目图片 and 题目音频 in the gameplay editor are
// picker tiles, not raw URL fields. The image reuses the cover's picker → 16:9 crop → upload → 使用 flow
// (`ActivityCoverAuthoringOwner`, its own `.templateQuestionImage` target); 清空 lives in the tile's "⋯" and can be
// undone. Audio has no upload pipeline in the app: its tile opens the existing local audio check
// (`TemplateMediaReviewController`) and says plainly that the file is not uploaded.

private struct TemplateQuestionImageOwnerKey: EnvironmentKey {
    static let defaultValue: ActivityCoverAuthoringOwner? = nil
}
private struct TemplateMediaReviewControllerKey: EnvironmentKey {
    static let defaultValue: TemplateMediaReviewController? = nil
}

extension EnvironmentValues {
    /// The page-retained owner for 题目图片 (nil when the page has no cover upload service).
    var templateQuestionImageOwner: ActivityCoverAuthoringOwner? {
        get { self[TemplateQuestionImageOwnerKey.self] }
        set { self[TemplateQuestionImageOwnerKey.self] = newValue }
    }
    /// The page's local media check (image / audio inspection; never uploads).
    var templateMediaReviewController: TemplateMediaReviewController? {
        get { self[TemplateMediaReviewControllerKey.self] }
        set { self[TemplateMediaReviewControllerKey.self] = newValue }
    }
}

/// 题目图片 + 题目音频 for 文字作答 / 选项问答.
@MainActor struct TemplateQuestionMediaFields: View {
    @ObservedObject var model: TemplateAuthoringModel
    @Environment(\.templateQuestionImageOwner) private var imageOwner
    @Environment(\.templateMediaReviewController) private var media

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            if let imageOwner {
                TemplateQuestionImageTile(model: model, owner: imageOwner)
            } else {
                TemplateQuestionMediaStatusTile(model: model, kind: .image, media: media)
            }
            TemplateQuestionMediaStatusTile(model: model, kind: .audio, media: media)
        }
        .padding(.vertical, CYSpacing.xs)
    }
}

enum TemplateQuestionMediaKind {
    case image, audio
    var labelKey: String { self == .image ? "config.qimage.label" : "config.qaudio.label" }
    var clearField: TemplateBasicClearField { self == .image ? .questionImage : .questionAudio }
    var mediaField: TemplateAuthoringMediaField { self == .image ? .questionImage : .questionAudio }
    var identifier: String { self == .image ? "questionImage" : "questionAudio" }
}

private extension TemplateAuthoringModel {
    func questionMedia(_ kind: TemplateQuestionMediaKind) -> String? { kind == .image ? draft.questionImg : draft.questionAudio }
    func restoreQuestionMedia(_ kind: TemplateQuestionMediaKind, _ value: String?) -> Bool {
        guard canEdit else { return false }
        mediaReferencesWillChange()
        if kind == .image { draft.questionImg = value } else { draft.questionAudio = value }
        changed(); return true
    }
}

/// Label row shared by both tiles: field label left, "⋯" right (extra items, then 清空 in red, last). The clear
/// controller lives here, outside the menu, so its visibility fence follows the row (menu items have no lifecycle).
@MainActor private struct TemplateQuestionMediaHeader<MenuItems: View>: View {
    @ObservedObject var model: TemplateAuthoringModel
    let kind: TemplateQuestionMediaKind
    @ViewBuilder let menu: () -> MenuItems
    /// The editor's existing clear rule (session, identity and media generation fenced), then 撤销.
    @StateObject private var clearing: TemplateBasicFieldClearController
    @Environment(\.configUndoCenter) private var undoCenter
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cyPalette) private var palette

    init(model: TemplateAuthoringModel, kind: TemplateQuestionMediaKind, @ViewBuilder menu: @escaping () -> MenuItems) {
        self.model = model; self.kind = kind; self.menu = menu
        _clearing = StateObject(wrappedValue: TemplateBasicFieldClearController(model: model, field: kind.clearField))
    }

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            ConfigR4Text.text(kind.labelKey).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: CYSpacing.sm)
            Menu {
                menu()
                Divider()
                Button(role: .destructive) { clear() } label: {
                    Label { ConfigR4Text.text("config.media.clear") } icon: { Image(systemName: "trash") }
                }
                .disabled(!clearing.canClear)
                .accessibilityIdentifier("templateBasicClear." + kind.identifier)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .editorHitTarget()
            }
            .accessibilityLabel(ConfigR4Text.text("config.media.more"))
            .accessibilityIdentifier("config.media.menu." + kind.identifier)
        }
        .onAppear { clearing.appear(sceneIsActive: scenePhase == .active) }
        .onDisappear { clearing.disappear() }
        .onChange(of: scenePhase) { _, phase in clearing.sceneChanged(isActive: phase == .active) }
    }

    private func clear() {
        let previous = model.questionMedia(kind)
        clearing.clearAction()()
        guard model.questionMedia(kind) != previous, let undoCenter else { return }
        let target = model, field = kind
        let name = ConfigR4Text.string(field.labelKey, locale: locale)
        undoCenter.recordDelete(message: String(format: OpsR3Text.string("editor.deleted.item", locale: locale), name),
                                actionName: ConfigR4Text.string("config.media.clear", locale: locale)) {
            target.restoreQuestionMedia(field, previous)
        }
    }
}

/// 题目图片: a 16:9 tile. Empty → a dashed slot 选择图片 that opens the photo picker at once; the crop, the explicit
/// upload and 使用这张图片 follow in place (the cover's flow and its replay lock). Filled → the image (or 已设置) with
/// 更换 in the "⋯" next to 预览 and 清空.
@MainActor struct TemplateQuestionImageTile: View {
    @ObservedObject var model: TemplateAuthoringModel
    @ObservedObject var owner: ActivityCoverAuthoringOwner
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    private var reference: String { model.draft.questionImg ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            TemplateQuestionMediaHeader(model: model, kind: .image) {
                if !reference.isEmpty {
                    Button(action: start) {
                        Label { ConfigR4Text.text("config.qimage.replace") } icon: { Image(systemName: "photo.on.rectangle") }
                    }
                    .disabled(!owner.canOpen)
                    Button(action: owner.previewAction()) {
                        Label { ConfigR4Text.text("config.qimage.preview") } icon: { Image(systemName: "eye") }
                    }
                }
            }
            if owner.isOpen { openFlow.transition(.opacity) } else { slot.transition(.opacity) }
        }
        .animation(reduceMotion ? nil : .default, value: owner.isOpen)
        .buttonStyle(.borderless)
    }

    /// Open and choose in one tap: the empty slot is the picker.
    private func start() {
        let open = owner.openAction()
        open()
        owner.chooseAction()()
    }

    @ViewBuilder private var slot: some View {
        if let preview = owner.visiblePreviewReference {
            DiscoveryArtwork(source: preview)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(.rect(cornerRadius: EditorKitMetric.cardRadius, style: .continuous)) // image crop only
                .accessibilityIdentifier("config.qimage.preview")
        } else {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Button(action: start) {
                    Label {
                        ConfigR4Text.text(reference.isEmpty ? "config.qimage.choose" : "config.qimage.set")
                    } icon: {
                        Image(systemName: reference.isEmpty ? "photo.badge.plus" : "photo")
                    }
                }
                .disabled(!owner.canOpen)
                .accessibilityIdentifier("config.qimage.choose")
                ConfigR4Text.text("config.qimage.boundary")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var openFlow: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ConfigR4Text.text(owner.current ? "config.qimage.status." + owner.status : "config.qimage.status.changed")
                .font(.subheadline)
                .foregroundStyle(owner.status == "rejected" || owner.status == "unknown" ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("config.qimage.status")
            if let crop = owner.crop, owner.current {
                MerchantImageCropView(draft: crop, confirm: owner.confirmCrop, cancel: { owner.cancelCrop(crop.id) }).id(crop.id)
            }
            if let image = owner.preview, owner.current {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityLabel(Text("media.destination.image"))
                    .accessibilityIdentifier("config.qimage.localPreview")
            }
            HStack(spacing: CYSpacing.sm) {
                Button(action: owner.closeAction()) { ConfigR4Text.text("config.qimage.cancel") }
                    .buttonStyle(.bordered)
                    .disabled(owner.busy)
                    .accessibilityIdentifier("config.qimage.cancel")
                Spacer(minLength: 0)
                if let review = owner.review, owner.current {
                    Button(action: owner.uploadAction(review)) {
                        ConfigR4Text.text(owner.status == "rejected" ? "config.qimage.retry" : "config.qimage.upload")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(owner.busy)
                    .accessibilityIdentifier("config.qimage.upload")
                } else if let receipt = owner.receipt, owner.current {
                    Button(action: owner.applyAction(receipt)) { ConfigR4Text.text("config.qimage.apply") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("config.qimage.apply")
                } else if owner.canChoose {
                    Button(action: owner.chooseAction()) { ConfigR4Text.text("config.qimage.choose") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("config.qimage.chooseAgain")
                }
            }
        }
        .sensoryFeedback(.success, trigger: owner.status) { _, new in new == "uploaded" }
    }
}

/// 题目音频 (and 题目图片 on a page without the upload service): the current state, 选择 opens the local check, and a
/// plain footnote that nothing is uploaded. TEST has no media storage for audio, so this is the whole flow for now.
@MainActor struct TemplateQuestionMediaStatusTile: View {
    @ObservedObject var model: TemplateAuthoringModel
    let kind: TemplateQuestionMediaKind
    let media: TemplateMediaReviewController?
    @Environment(\.cyPalette) private var palette

    private var isSet: Bool { !(model.questionMedia(kind) ?? "").isEmpty }
    private var row: TemplateMediaReviewController.Row? { media?.rows.first { $0.field == kind.mediaField } }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            TemplateQuestionMediaHeader(model: model, kind: kind) { EmptyView() }
            Button {
                if let row { media?.open(row) }
            } label: {
                HStack(spacing: CYSpacing.md) {
                    Label {
                        ConfigR4Text.text(isSet ? (kind == .audio ? "config.qaudio.set" : "config.qimage.set")
                                                : (kind == .audio ? "config.qaudio.empty" : "config.qimage.empty"))
                        ConfigR4Text.text(kind == .audio ? "config.qaudio.choose" : "config.qimage.checkLocal")
                    } icon: {
                        Image(systemName: kind == .audio ? "waveform" : "photo")
                    }
                    Spacer(minLength: CYSpacing.sm)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(row == nil || media?.canOpen != true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("config.media.open." + kind.identifier)
            EditorFieldFootnote(help: ConfigR4Text.text(kind == .audio ? "config.qaudio.noStorage" : "config.qimage.noStorage"))
        }
    }
}
