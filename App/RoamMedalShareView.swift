import SwiftUI
import UIKit

/// Share card composer for one saved medal. Local rendering only: sharing never fetches an image,
/// uploads a card or starts a walk. The card carries the medal name, its category and the recorded
/// date; no route, places, photos or account details. Preview and export are the same `CYShareCard`.
@MainActor struct RoamMedalShareView: View {
    let selection: RoamMedalShareSelection
    let reader: any RoamExperienceReading
    private let authority: RoamMedalShareAuthority?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @StateObject private var photoSave: RoamSharePhotoSaveModel
    @StateObject private var presentation: RoamSharePresentationLifetime
    @State private var style = CYShareCardStyle(template: .poster, ratio: .story, tint: .gold)
    @State private var caption = ""
    @State private var image: UIImage?
    @State private var visible = false
    @State private var sourceChanged = false
    @State private var renderFailed = false
    @State private var systemShare: RoamHistorySystemShareRequest?
    @State private var toast: LocalizedStringKey?
    @State private var successTick = 0
    @State private var readyTick = 0
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
                if ownerMatches && !sourceChanged {
                    CYShareComposer(content: cardContent, style: $style, caption: $caption,
                                    captionPlaceholder: appLocalized("roam.share.caption.placeholder", locale: locale),
                                    accessibilityPrefix: "roam.medalShare.composer") {
                        EmptyView()
                    } actions: {
                        actionsSection
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
            .onAppear { presentation.appear(); visible = true; sourceChanged = !sourceIsCurrent }
            .onChange(of: RoamHistoryLiveOwner(reader: reader)) { _, _ in invalidate(); sourceChanged = true }
            .onChange(of: style) { _, _ in invalidate() }
            .onChange(of: caption) { _, _ in invalidate() }
            .onChange(of: photoSave.state.phase) { _, phase in
                if phase == .saved { toast = "roam.share.savedPhotos"; successTick += 1 }
            }
            .cyHaptic(.success, trigger: successTick)
            .cyHaptic(.impactLight, trigger: readyTick)
            .cyToast(message: $toast)
            // Native true-departure ownership also handles removal while a share sheet covers us.
            .sheet(item: $systemShare) { item in
                if sourceIsCurrent, image === item.image,
                   item.selection == .init(record: selection.record, includeRoute: false),
                   item.isCurrent(reader: reader) {
                    RoamMedalSystemShare(request: item, reader: reader) { completed in
                        if completed { toast = "roam.share.sharedToast"; successTick += 1 }
                    }
                } else {
                    Text("roam.share.photoSaveSourceChanged").foregroundStyle(.secondary)
                }
            }
    }
    @ViewBuilder private var actionsSection: some View {
        if let image {
            HStack(spacing: CYSpacing.md) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
                    .accessibilityLabel(Text("roam.medalShare.preview"))
                    .accessibilityIdentifier("roam.medalShare.preview")
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    CYStatusChip("roam.share.ready", tone: .success, systemImage: "checkmark.seal")
                    Text("roam.share.readyHint").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(CYSpacing.md)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            .cyEntrance()
            saveControls(image)
            CYPillButton("roam.share.system", style: .secondary, systemImage: "square.and.arrow.up") {
                guard systemShare == nil, !photoSave.inFlight else { return }
                guard sourceIsCurrent, self.image === image,
                      let request = RoamHistorySystemShareRequest(image: image,
                          selection: .init(record: selection.record, includeRoute: false),
                          owner: .init(reader: reader), reader: reader, presentation: presentation) else {
                    invalidate(); sourceChanged = true; return
                }
                systemShare = request
            }
                .disabled(photoSave.inFlight || systemShare != nil || photoSave.state.phase == .sourceChanged)
                .accessibilityIdentifier("roam.medalShare.system")
        } else {
            if renderFailed { Text("roam.share.renderFailed") }
            CYPillButton("roam.medalShare.prepare", systemImage: "medal") { prepare() }
                .accessibilityIdentifier("roam.medalShare.prepare")
        }
    }
    private func prepare() {
        guard sourceIsCurrent else { invalidate(); sourceChanged = true; return }
        photoSave.invalidate()
        image = RoamMedalShareRenderer.render(content: cardContent, style: style)
        renderFailed = image == nil
        if image != nil { readyTick += 1 }
    }
    private func invalidate() { photoSave.invalidate(); systemShare = nil; image = nil; renderFailed = false }
    @ViewBuilder private func saveControls(_ image: UIImage) -> some View {
        let phase = photoSave.state.phase
        CYPillButton(LocalizedStringKey(saveButtonKey), systemImage: "square.and.arrow.down") {
            photoSave.save(image, selection: .init(record: selection.record, includeRoute: false)) { sourceIsCurrent }
        }
            .disabled(photoSave.inFlight || phase == .saved || phase == .sourceChanged)
            .accessibilityIdentifier("roam.medalShare.savePhotos")
        if photoSave.inFlight { ProgressView("roam.share.savingPhotos") }
        else if let key = saveStatusKey {
            Text(LocalizedStringKey(key)).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("roam.medalShare.saveStatus")
        }
        if phase == .permissionDenied, !photoSave.inFlight {
            CYPillButton("roam.share.openPhotoSettings", style: .secondary) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }.accessibilityIdentifier("roam.medalShare.openPhotoSettings")
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
    /// Default poster (story, gold). `dynamicTypeSize` and `posterHeight` are accepted for source compatibility;
    /// the artboard is fixed, so neither changes the export.
    static func render(_ card: RoamMedalShareSelection.Card, dynamicTypeSize: DynamicTypeSize = .large, posterHeight: CGFloat = 640) -> UIImage? {
        render(content: RoamMedalShareCardContent.make(card, caption: "", locale: .current),
               style: CYShareCardStyle(template: .poster, ratio: .story, tint: .gold))
    }
}
