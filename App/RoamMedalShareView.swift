import SwiftUI
import UIKit

/// Share card composer for one saved medal. Local rendering only: sharing never fetches an image,
/// uploads a card or starts a walk. The card carries the medal name, its category and the recorded
/// date; no route, places, photos or account details. Preview and export are the same `CYShareCard`.
/// Flow state lives in `CYShareComposerMachine` (editing, rendering, ready, exporting, done, renderFailed, stale).
@MainActor struct RoamMedalShareView: View {
    let selection: RoamMedalShareSelection
    let reader: any RoamExperienceReading
    private let authority: RoamMedalShareAuthority?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @QuestifyReduceMotion private var reduceMotion
    @StateObject private var photoSave: RoamSharePhotoSaveModel
    @StateObject private var presentation: RoamSharePresentationLifetime
    @State private var machine = CYShareComposerMachine()
    // 210:10082: the badge on the navy field of 210:10045; no mustard swatch (SR2-08).
    @State private var style = CYShareCardStyle(template: .poster, ratio: .story, tint: .ocean)
    @State private var caption = ""
    @State private var renderedSelection: RoamMedalShareSelection?
    @State private var visible = false
    @State private var systemShare: RoamHistorySystemShareRequest?
    @State private var toast: LocalizedStringKey?
    init(selection: RoamMedalShareSelection, reader: any RoamExperienceReading, photoSaveModel: RoamSharePhotoSaveModel? = nil) {
        let model = photoSaveModel ?? RoamSharePhotoSaveModel()
        _photoSave = StateObject(wrappedValue: model)
        _presentation = StateObject(wrappedValue: .init(photoSave: model))
        self.selection = selection; self.reader = reader
        authority = RoamMedalShareAuthority(selection: selection, reader: reader)
    }
    private var ownerMatches: Bool { authority?.matchesOwner(reader) == true }
    private var sourceIsCurrent: Bool { presentation.isActive && visible && authority?.isCurrent(reader) == true }
    private var cardContent: CYShareCardContent {
        RoamMedalShareCardContent.make(selection.card, caption: caption, locale: locale)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                CYHeroHeader(verbatim: selection.card.name, subtitle: appLocalized("roam.medalShare.privacy", locale: locale))
                if ownerMatches && !machine.state.isStale {
                    CYShareComposer(content: cardContent, style: $style, caption: $caption,
                                    captionPlaceholder: appLocalized("roam.share.caption.placeholder", locale: locale),
                                    accessibilityPrefix: "roam.medalShare.composer") {
                        EmptyView()
                    } actions: {
                        actionsSection
                            .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: machine.state)
                    }
                } else {
                    Text("roam.share.photoSaveSourceChanged").foregroundStyle(.secondary)
                        .accessibilityIdentifier("roam.medalShare.sourceChanged")
                }
            }.padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.xxxl)
        }.background(CYColor.bgPage.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("action.done") { presentation.retire(); visible = false; invalidate(); dismiss() }.accessibilityIdentifier("roam.medalShare.done")
            } }
            .background(RoamShareNativeLifetime(presentation: presentation).frame(width: 0, height: 0))
            .onAppear { presentation.appear(); visible = true; if !sourceIsCurrent { markStale() } }
            .onChange(of: selection) { _, _ in invalidate(); if !sourceIsCurrent { markStale() } }
            .onChange(of: RoamHistoryLiveOwner(reader: reader)) { _, _ in markStale() }
            .onChange(of: style) { _, _ in invalidate(.styleChanged) }
            .onChange(of: caption) { _, _ in invalidate(.captionChanged) }
            .onChange(of: photoSave.state.phase) { _, phase in
                switch phase {
                case .saved: finishExport(success: true, toastKey: "roam.share.savedPhotos")
                case .permissionDenied, .restricted, .unavailable, .sourceChanged, .failed: machine.send(.exportFinished(false))
                default: break
                }
            }
            .onChange(of: machine.readyTick) { _, _ in CYShareAnnouncer.announce(appLocalized("roam.share.ready", locale: locale)) }
            .cyHaptic(.impactLight, trigger: machine.readyTick)
            .cyHaptic(.success, trigger: machine.doneTick)
            .cyToast(message: $toast)
            // Native true-departure ownership also handles removal while a share sheet covers us.
            .cySheet(item: $systemShare, onDismiss: { if machine.state.isExporting { machine.send(.exportFinished(false)) } }) { item in
                if sourceIsCurrent, machine.image === item.image,
                   item.selection == .init(record: selection.record, includeRoute: false),
                   renderedSelection == selection,
                   item.isCurrent(reader: reader) {
                    RoamMedalSystemShare(request: item, reader: reader) { completed in
                        if completed { finishExport(success: true, toastKey: "roam.share.sharedToast") } else { machine.send(.exportFinished(false)) }
                    }
                } else {
                    Text("roam.share.photoSaveSourceChanged").foregroundStyle(.secondary)
                }
            }
    }
    @ViewBuilder private var actionsSection: some View {
        if let image = machine.image, renderedSelection == selection {
            CYShareReadyRow(image: image, title: "roam.share.ready", hint: "roam.share.readyHint",
                            previewLabel: "roam.medalShare.preview", identifier: "roam.medalShare.preview")
            saveControls(image)
            CYPillButton("roam.share.system", style: .secondary, systemImage: "square.and.arrow.up") {
                guard systemShare == nil, !photoSave.inFlight, !machine.state.isExporting else { return }
                guard sourceIsCurrent, renderedSelection == selection, machine.image === image,
                      let request = RoamHistorySystemShareRequest(image: image,
                          selection: .init(record: selection.record, includeRoute: false),
                          owner: .init(reader: reader), reader: reader, presentation: presentation) else {
                    markStale(); return
                }
                systemShare = request
                machine.send(.export(.system))
            }
                .disabled(photoSave.inFlight || systemShare != nil || machine.state.isExporting || photoSave.state.phase == .sourceChanged)
                .accessibilityIdentifier("roam.medalShare.system")
        } else {
            if case .renderFailed = machine.state { Text("roam.share.renderFailed") }
            CYSharePrepareButton(title: "roam.medalShare.prepare", systemImage: "medal", state: machine.state,
                                 identifier: "roam.medalShare.prepare") { prepare() }
        }
    }
    /// Render off the press frame: the state flips to `.rendering` first, the bitmap lands in the next turn.
    private func prepare() {
        guard sourceIsCurrent else { markStale(); return }
        photoSave.invalidate()
        renderedSelection = nil
        machine.send(.prepare)
        let capturedSelection = selection
        let renderContent = cardContent, renderStyle = style, renderCaption = caption
        Task { @MainActor in
            let image = RoamMedalShareRenderer.render(content: renderContent, style: renderStyle)
            guard sourceIsCurrent, capturedSelection == selection, renderStyle == style, renderCaption == caption else {
                invalidate(); return
            }
            renderedSelection = image == nil ? nil : capturedSelection
            machine.send(.rendered(image))
        }
    }
    private func finishExport(success: Bool, toastKey: String) {
        machine.send(.exportFinished(success))
        guard success else { return }
        toast = LocalizedStringKey(toastKey)
        CYShareAnnouncer.announce(appLocalized(String.LocalizationValue(stringLiteral: toastKey), locale: locale))
    }
    private func invalidate(_ event: CYShareComposerEvent = .invalidate) {
        photoSave.invalidate(); systemShare = nil; renderedSelection = nil; machine.send(event)
    }
    private func markStale() { photoSave.invalidate(); systemShare = nil; renderedSelection = nil; machine.send(.sourceChanged) }
    @ViewBuilder private func saveControls(_ image: UIImage) -> some View {
        let phase = photoSave.state.phase
        CYPillButton(LocalizedStringKey(saveButtonKey), systemImage: "square.and.arrow.down") {
            guard renderedSelection == selection, sourceIsCurrent else { markStale(); return }
            let captured = selection
            machine.send(.export(.photos))
            photoSave.save(image, selection: .init(record: captured.record, includeRoute: false)) {
                sourceIsCurrent && selection == captured && renderedSelection == captured
            }
        }
            .disabled(photoSave.inFlight || phase == .saved || phase == .sourceChanged)
            .accessibilityIdentifier("roam.medalShare.savePhotos")
        if photoSave.inFlight { ProgressView("roam.share.savingPhotos") }
        else if let key = saveStatusKey {
            Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("roam.medalShare.saveStatus")
        }
        if phase == .permissionDenied, !photoSave.inFlight {
            CYPillButton("roam.share.openPhotoSettings", style: .secondary) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }.accessibilityIdentifier("roam.medalShare.openPhotoSettings")
                .accessibilityLabel(Text("roam.share.openPhotoSettings"))
                .accessibilityValue(Text("roam.share.photoPermissionDenied"))
                .accessibilityHint(Text("roam.share.openPhotoSettings"))
        }
    }
    private var saveButtonKey: String {
        switch photoSave.state.phase {
        case .permissionDenied, .restricted, .failed: return "roam.share.retrySavePhotos"
        case .saved: return "roam.share.savedPhotos"
        default: return "roam.share.savePhotos"
        }
    }
    private var saveStatusKey: String? {
        switch photoSave.state.phase {
        case .saved: return "roam.share.savedPhotos"
        case .permissionDenied: return "roam.share.photoPermissionDenied"
        case .restricted: return "roam.share.photoPermissionRestricted"
        case .unavailable: return "roam.share.photoSaveUnavailable"
        case .sourceChanged: return "roam.share.photoSaveSourceChanged"
        case .failed: return "roam.share.photoSaveFailed"
        default: return nil
        }
    }
}

@MainActor struct RoamMedalSystemShare: UIViewControllerRepresentable {
    let request: RoamHistorySystemShareRequest
    let reader: any RoamExperienceReading
    /// Called once the system sheet closes; `true` only when the user completed an activity.
    var onComplete: ((Bool) -> Void)? = nil
    func makeUIViewController(context: Context) -> UIViewController { makeController() }
    func makeController() -> UIViewController {
        // The local record/owner can change after SwiftUI evaluated the sheet body.
        // Reuse the history export's existing last creation gate, not a second authority.
        if let controller = request.makeActivityController(reader: reader) {
            let onComplete = self.onComplete
            controller.completionWithItemsHandler = { _, completed, _, _ in onComplete?(completed) }
            return controller
        }
        return UIViewController()
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

/// The medal card's content: name, category, recorded date, generated art seeded by the name.
/// Deliberately no route, POI, photo, account or server identifier.
enum RoamMedalShareCardContent {
    static func make(_ card: RoamMedalShareSelection.Card, caption: String, locale: Locale) -> CYShareCardContent {
        let kind = appLocalized(card.kind == .journey ? "roam.medalShare.journey" : "roam.medalShare.shop", locale: locale)
        let date = card.recordedAt.map { $0.formatted(.dateTime.year().month().day().locale(locale)) }
        return CYShareCardContent(
            kind: .medal,
            eyebrow: appLocalized("roam.medalShare.earned", locale: locale),
            title: card.name,
            subtitle: [kind, date].compactMap { $0 }.joined(separator: " · "),
            place: nil,
            showsPlace: false,
            stats: [],
            silhouette: [],
            artSeed: "medal-" + card.name,
            artSymbol: card.kind == .journey ? "medal.fill" : "storefront.fill",
            caption: caption,
            brand: appLocalized("roam.medalShare.brand", locale: locale))
    }
}

/// Preview and both export actions use this same image. No asset URL or mutable live result.
@MainActor enum RoamMedalShareRenderer {
    static func render(content: CYShareCardContent, style: CYShareCardStyle) -> UIImage? {
        CYShareCardRenderer.render(content, style: style)
    }
    /// Default poster (story, navy field). `dynamicTypeSize` and `posterHeight` are accepted for source compatibility;
    /// the artboard is fixed, so neither changes the export.
    static func render(_ card: RoamMedalShareSelection.Card, dynamicTypeSize: DynamicTypeSize = .large, posterHeight: CGFloat = 640) -> UIImage? {
        render(content: RoamMedalShareCardContent.make(card, caption: "", locale: .current),
               style: CYShareCardStyle(template: .poster, ratio: .story, tint: .ocean))
    }
}
