import SwiftUI
import UIKit

/// Share card composer for a saved walk. The user can save the rendered card to Photos or choose a
/// system-sheet recipient. No app upload, public-feed post, private URL or tracking token is generated here.
/// Privacy: the neighbourhood name and the clipped route sketch are both opt-in toggles (default off);
/// a missing value is an em dash, never a zero. Preview and export are the same `CYShareCard` view.
/// Flow state lives in `CYShareComposerMachine`; the rendered-receipt fields below are privacy gates, not flow flags.
@MainActor struct RoamHistoryShareView: View {
    let record: RoamHistoryRecord
    let reader: any RoamExperienceReading
    private let presentationOwner: RoamHistoryLiveOwner
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.analyticsEventClient) private var analytics
    @QuestifyReduceMotion private var reduceMotion
    @StateObject private var photoSave: RoamSharePhotoSaveModel
    @StateObject private var presentation: RoamSharePresentationLifetime
    @State private var includeRoute = false
    /// ROAM-r11-9: this share only; not stored (MP `onShareVisibility`).
    @State private var shareVisibility: RoamShareVisibility = .public
    @State private var includePlace = false
    @State private var style = CYShareCardStyle(template: .poster, ratio: .story, tint: .ink)
    @State private var caption = ""
    @State private var channelPolicy = RoamShareChannelPolicy()
    @State private var machine = CYShareComposerMachine()
    @State private var renderedRecord: RoamHistoryRecord?
    @State private var renderedIncludeRoute = false
    @State private var renderedOwner: RoamHistoryLiveOwner?
    @State private var albumGuide = RoamShareAlbumGuideState()
    @State private var guideSourceChanged = false
    @State private var systemShare: RoamHistorySystemShareRequest?
    @State private var toast: LocalizedStringKey?
    /// Channel code waiting for the photo-save outcome (`album` / `moments` / `xhs`).
    @State private var pendingShareCode: String?
    init(record: RoamHistoryRecord, reader: any RoamExperienceReading, photoSaveModel: RoamSharePhotoSaveModel? = nil) {
        let model = photoSaveModel ?? RoamSharePhotoSaveModel()
        _photoSave = StateObject(wrappedValue: model)
        _presentation = StateObject(wrappedValue: .init(photoSave: model))
        self.record = record; self.reader = reader
        presentationOwner = RoamHistoryLiveOwner(reader: reader)
    }
    private var isBusy: Bool { photoSave.inFlight || albumGuide.pending != nil || machine.state.isExporting }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                // RSESS-5: a sheet takes the system inline title; the privacy line stays as body copy.
                Text("roam.share.privacy").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYShareComposer(content: cardContent, style: $style, caption: $caption,
                                captionPlaceholder: appLocalized("roam.share.caption.placeholder", locale: locale),
                                accessibilityPrefix: "roam.share.composer") {
                    privacyControls
                } actions: {
                    actionsSection
                        .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: machine.state)
                }
                RoamShareLinkRow(record: record, includeRoute: includeRoute, routeName: record.meaningfulZone)
                RoamShareRevokeEntry()
            }.padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.xxxl)
        }
            .background(CYColor.bgPage.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .cyPageTitle("roam.share.title")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { presentation.retire(); invalidateImage(); dismiss() }.accessibilityIdentifier("roam.share.done") } }
            .background(RoamShareNativeLifetime(presentation: presentation).frame(width: 0, height: 0))
            .onAppear { presentation.appear() }
            .onChange(of: record) { _, _ in includeRoute = false; includePlace = false; channelPolicy.reset(); invalidateImage() }
            .onChange(of: RoamHistoryLiveOwner(reader: reader)) { _, _ in includeRoute = false; includePlace = false; channelPolicy.reset(); invalidateImage() }
            .onChange(of: includeRoute) { _, _ in invalidateImage() }
            .onChange(of: includePlace) { _, _ in invalidateImage() }
            .onChange(of: style) { _, _ in invalidateImage(.styleChanged) }
            .onChange(of: caption) { _, _ in invalidateImage(.captionChanged) }
            .onChange(of: photoSave.state.phase) { _, phase in
                receiveAlbumGuide(phase)
                switch phase {
                case .saved:
                    finishShare(ok: true)
                    finishExport(success: true, toastKey: "roam.share.savedPhotos")
                case .permissionDenied, .restricted, .unavailable, .sourceChanged, .failed:
                    finishShare(ok: false)
                    machine.send(.exportFinished(false))
                default: break
                }
            }
            .onChange(of: machine.readyTick) { _, _ in CYShareAnnouncer.announce(appLocalized("roam.share.ready", locale: locale)) }
            .cyHaptic(.impactLight, trigger: machine.readyTick)
            .cyHaptic(.success, trigger: machine.doneTick)
            .cyToast(message: $toast)
            .cySheet(item: Binding(get: { albumGuide.guide }, set: { if $0 == nil { albumGuide.dismissGuide() } })) { guide in
                if permitsAlbumGuide(guide.destination) { RoamShareAlbumGuideView(guide: guide) }
            }
            .cySheet(item: $systemShare, onDismiss: { if machine.state.isExporting { machine.send(.exportFinished(false)) } }) { request in
                // Recheck after the tap as well: a local record or owner may have
                // changed before SwiftUI actually presents the system sheet.
                if channelPolicy.permits(.systemShare), machine.image === request.image,
                   preparedSelection == request.selection, request.isCurrent(reader: reader) {
                    RoamHistorySystemShareSheet(request: request, reader: reader) { completed in
                        if completed { finishExport(success: true, toastKey: "roam.share.sharedToast") } else { machine.send(.exportFinished(false)) }
                    }
                } else {
                    Text("roam.share.photoSaveSourceChanged").foregroundStyle(.secondary)
                }
            }
            // Cover/permission alerts are not departures. The native attachment owns true
            // removal even when a guide or system sheet already covers this presenter.
    }

    // MARK: Card content (what the exported image contains, and nothing else)

    private var cardContent: CYShareCardContent {
        let sketch = RoamShareRoutePrivacy.sketch(for: record)
        let stats = [
            CYShareStat(appLocalized("roam.experience.distance", locale: locale), record.distance.map { String(format: "%.1f km", $0) }),
            CYShareStat(appLocalized("roam.experience.duration", locale: locale), record.durationText),
            CYShareStat(appLocalized("roam.experience.shops", locale: locale), record.shops.map(String.init)),
            CYShareStat(appLocalized("roam.experience.explorePct", locale: locale), record.explorePct.map { "\($0)%" }),
        ]
        return CYShareCardContent(
            kind: .walk,
            eyebrow: appLocalized("roam.share.card.eyebrow", locale: locale),
            title: appLocalized("roam.experience.cityWalk", locale: locale),
            subtitle: record.recordedAt.map { $0.formatted(.dateTime.year().month().day().locale(locale)) },
            place: includePlace ? record.meaningfulZone : nil,
            stats: stats,
            silhouette: includeRoute ? sketch.track.map { CGPoint(x: $0.x, y: $0.y) } : [],
            artSeed: "walk-\(record.ts)",
            artSymbol: "figure.walk",
            caption: caption,
            brand: appLocalized("roamSub.w208.share.brand", locale: locale),
            mpRouteArt: true)
    }

    // MARK: Controls

    @ViewBuilder private var privacyControls: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if record.meaningfulZone != nil {
                Toggle("roam.share.includePlace", isOn: $includePlace).tint(.green)
                    .accessibilityIdentifier("roam.share.includePlace")
                Text("roam.share.includePlaceHint").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !record.track.isEmpty {
                Toggle("roam.share.includeRoute", isOn: $includeRoute).tint(.green)
                    .accessibilityIdentifier("roam.share.includeRoute")
            }
            // ROAM-r11-9: 谁能看到 is a gate, not a label (MP pages/roam/index.wxml:1031-1040, index.js:5045-5050).
            Picker("roam.share.visibility.title", selection: $shareVisibility) {
                ForEach(RoamShareVisibility.allCases) { value in
                    Text(LocalizedStringKey("roam.share.visibility." + value.rawValue)).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isBusy)
            .accessibilityIdentifier("roam.share.visibility")
            RoamShareChannelPicker(mode: Binding(get: { channelPolicy.mode }, set: { mode in
                if channelPolicy.select(mode, operationInFlight: isBusy) {
                    // Retire guide callbacks synchronously. The image has not changed, so keep
                    // any completed save receipt rather than writing the same card twice.
                    albumGuide.invalidate(); guideSourceChanged = false
                }
            }), isBusy: isBusy)
        }
        .padding(CYSpacing.lg)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }

    @ViewBuilder private var actionsSection: some View {
        if case .renderFailed = machine.state { Text("roam.share.renderFailed").foregroundStyle(.secondary) }
        if guideSourceChanged { Text("roam.share.photoSaveSourceChanged").foregroundStyle(.secondary) }
        if let image = machine.image, renderedRecord == record, renderedIncludeRoute == includeRoute,
           renderedOwner == RoamHistoryLiveOwner(reader: reader) {
            CYShareReadyRow(image: image, title: "roam.share.ready", hint: "roam.share.readyHint",
                            previewLabel: "roam.share.previewLabel", identifier: "roam.share.preview")
            photoSaveControls(image)
            if !allowedAlbumDestinations.isEmpty { albumGuideControls(image) }
            if channelPolicy.permits(.systemShare) {
                CYPillButton("roam.share.system", style: .secondary, systemImage: "square.and.arrow.up") { beginSystemShare(image) }
                    .disabled(isBusy || systemShare != nil || photoSave.state.phase == .sourceChanged)
                    .accessibilityIdentifier("roam.share.system")
            }
        } else {
            CYSharePrepareButton(title: "roam.share.prepare", state: machine.state, identifier: "roam.share.prepare") { prepare() }
        }
    }

    /// Render off the press frame: `.rendering` commits first, the bitmap and its receipt land in the next main-actor turn.
    private func prepare() {
        guard sourceIsCurrent else { invalidateImage(); return }
        machine.send(.prepare)
        let renderContent = cardContent, renderStyle = style, renderRoute = includeRoute, renderOwner = presentationOwner, renderRecord = record
        Task { @MainActor in
            let rendered = CYShareCardRenderer.render(renderContent, style: renderStyle)
            renderedRecord = rendered == nil ? nil : renderRecord
            renderedIncludeRoute = renderRoute
            renderedOwner = rendered == nil ? nil : renderOwner
            machine.send(.rendered(rendered))
        }
    }
    private func finishExport(success: Bool, toastKey: String) {
        machine.send(.exportFinished(success))
        guard success else { return }
        toast = LocalizedStringKey(toastKey)
        CYShareAnnouncer.announce(appLocalized(String.LocalizationValue(stringLiteral: toastKey), locale: locale))
    }

    // MARK: Export plumbing (unchanged privacy gates)

    private func invalidateImage(_ event: CYShareComposerEvent = .invalidate) {
        photoSave.invalidate()
        albumGuide.invalidate()
        systemShare = nil
        guideSourceChanged = false
        renderedRecord = nil; renderedOwner = nil
        machine.send(event)
    }
    private func beginSystemShare(_ image: UIImage) {
        guard channelPolicy.permits(.systemShare), !photoSave.inFlight,
              albumGuide.pending == nil, albumGuide.guide == nil, systemShare == nil else { return }
        guard machine.image === image, let selection = preparedSelection,
              let request = RoamHistorySystemShareRequest(image: image, selection: selection,
                  owner: presentationOwner, reader: reader, presentation: presentation) else {
            invalidateImage(); guideSourceChanged = true; return
        }
        systemShare = request
        machine.send(.export(.system))
    }
    private var sourceIsCurrent: Bool {
        guard presentation.isActive, presentationOwner == RoamHistoryLiveOwner(reader: reader), presentationOwner.isAuthorized else { return false }
        return (try? reader.history().first { $0.ts == record.ts }) == record
    }
    private var preparedSelection: RoamSharePhotoSaveState.Selection? {
        guard machine.image != nil, renderedRecord == record, renderedIncludeRoute == includeRoute,
              renderedOwner == presentationOwner else { return nil }
        return .init(record: record, includeRoute: includeRoute)
    }
    private func permitsAlbumGuide(_ destination: RoamShareAlbumGuideState.Destination) -> Bool {
        let channel: RoamShareChannelPolicy.Channel = destination == .moments ? .momentsGuide : .xiaohongshuGuide
        return channelPolicy.permits(channel) && shareVisibility.allows(channel)
    }
    private var allowedAlbumDestinations: [RoamShareAlbumGuideState.Destination] {
        RoamShareAlbumGuideState.Destination.allCases.filter(permitsAlbumGuide)
    }
    private func albumGuideControls(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYSectionHeader("roam.albumGuide.choose")
            Text("roam.albumGuide.beforeSave").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            ForEach(allowedAlbumDestinations) { destination in
                CYPillButton(LocalizedStringKey(destination == .moments ? "roam.albumGuide.momentsAction" : "roam.albumGuide.xiaohongshuAction"),
                             style: .secondary, systemImage: "photo.on.rectangle") {
                    beginAlbumGuide(destination, image: image)
                }
                    .disabled(isBusy || photoSave.state.phase == .sourceChanged)
                    .accessibilityIdentifier("roam.albumGuide.open." + destination.rawValue)
            }
        }
    }
    private func beginAlbumGuide(_ destination: RoamShareAlbumGuideState.Destination, image: UIImage) {
        guard permitsAlbumGuide(destination) else { return }
        guard let selection = preparedSelection, sourceIsCurrent else {
            invalidateImage(); guideSourceChanged = true; return
        }
        guard let request = albumGuide.begin(destination: destination, selection: selection, saveInFlight: photoSave.inFlight) else { return }
        let raw = destination == .moments ? "朋友圈" : "小红书"
        let code = destination == .moments ? "moments" : "xhs"
        if photoSave.state.phase == .saved, photoSave.state.selection == selection {
            beginShare(raw: raw, code: code)
            finishShare(ok: true)
            // The identical prepared card was already saved in this presentation.
            // Reuse its receipt rather than writing a duplicate just to show instructions.
            albumGuide.receive(request, phase: .saved, current: selection, sourceIsCurrent: sourceIsCurrent)
            return
        }
        beginShare(raw: raw, code: code)
        machine.send(.export(.albumGuide))
        photoSave.save(image, selection: selection) {
            permitsAlbumGuide(destination) && albumGuide.accepts(request) && preparedSelection == selection && sourceIsCurrent
        }
    }
    private func receiveAlbumGuide(_ phase: RoamSharePhotoSaveState.Phase) {
        guard let request = albumGuide.pending else { return }
        guard permitsAlbumGuide(request.destination) else { albumGuide.invalidate(); return }
        guard let selection = preparedSelection else { albumGuide.invalidate(); return }
        albumGuide.receive(request, phase: phase, current: selection, sourceIsCurrent: sourceIsCurrent)
    }
    @ViewBuilder private func photoSaveControls(_ image: UIImage) -> some View {
        let phase = photoSave.state.phase
        CYPillButton(LocalizedStringKey(saveButtonKey), systemImage: "square.and.arrow.down") {
            beginShare(raw: "保存", code: "album")
            let selection = RoamSharePhotoSaveState.Selection(record: record, includeRoute: includeRoute)
            machine.send(.export(.photos))
            photoSave.save(image, selection: selection) {
                // Read the existing local history again after permission, before writing.
                // A matching timestamp alone does not authorize an edited record.
                guard renderedRecord == record, renderedIncludeRoute == includeRoute,
                      selection.includeRoute == includeRoute, renderedOwner == presentationOwner else { return false }
                return sourceIsCurrent
            }
        }.disabled(photoSave.inFlight || phase == .saved || phase == .sourceChanged)
            .accessibilityIdentifier("roam.share.savePhotos")
        if photoSave.inFlight {
            CYSkeleton().accessibilityLabel(Text("roam.share.savingPhotos")).accessibilityIdentifier("roam.share.savingPhotos")
        } else if let key = saveStatusKey {
            Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("roam.share.photoSaveStatus")
        }
        if phase == .permissionDenied, !photoSave.inFlight {
            CYPillButton("roam.share.openPhotoSettings", style: .secondary) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }.accessibilityIdentifier("roam.share.openPhotoSettings")
                .accessibilityLabel(Text("roam.share.openPhotoSettings"))
                .accessibilityValue(Text("roam.share.photoPermissionDenied"))
                .accessibilityHint(Text("roam.share.openPhotoSettings"))
        }
    }
    private func beginShare(raw: String, code: String) {
        pendingShareCode = code
        MiniProgramAnalytics.track(analytics, "roam_share_channel", bizType: "roam",
            bizID: MiniProgramAnalytics.bizID(record.serverSessionID), pagePath: "/pages/roam/index",
            properties: ["channel": .string(raw)])
    }
    private func finishShare(ok: Bool) {
        guard let code = pendingShareCode else { return }
        pendingShareCode = nil
        let name = ok ? "roam_share_complete" : "roam_share_fail"
        var properties: [String: PlayWireValue] = ["channel": .string(code)]
        if !ok { properties["reason"] = .string("failed") }
        MiniProgramAnalytics.track(analytics, name, bizType: "roam",
            bizID: MiniProgramAnalytics.bizID(record.serverSessionID), pagePath: "/pages/roam/index", properties: properties)
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

/// A system export uses the same prepared image, but not a stale local-history
/// receipt. This is read-only and retains the share surface's existing owner gate.
@MainActor struct RoamHistorySystemShareRequest: Identifiable {
    let id = UUID()
    let image: UIImage
    let selection: RoamSharePhotoSaveState.Selection
    private let owner: RoamHistoryLiveOwner
    private weak var presentation: RoamSharePresentationLifetime?
    private let requiresPresentation: Bool
    private var presentationIsCurrent: Bool { !requiresPresentation || presentation?.isActive == true }

    init?(image: UIImage, selection: RoamSharePhotoSaveState.Selection,
          owner: RoamHistoryLiveOwner, reader: any RoamExperienceReading,
          presentation: RoamSharePresentationLifetime? = nil) {
        self.image = image; self.selection = selection; self.owner = owner
        self.presentation = presentation; requiresPresentation = presentation != nil
        guard isCurrent(reader: reader) else { return nil }
    }
    func isCurrent(reader: any RoamExperienceReading) -> Bool {
        guard presentationIsCurrent, owner.isAuthorized, owner == RoamHistoryLiveOwner(reader: reader),
              let records = try? reader.history(), owner == RoamHistoryLiveOwner(reader: reader), presentationIsCurrent else { return false }
        let matching = records.filter { $0.ts == selection.record.ts }
        return matching.count == 1 && matching.first == selection.record
    }
    func makeActivityController(reader: any RoamExperienceReading) -> UIActivityViewController? {
        // UIKit may create the controller after SwiftUI evaluated the sheet body.
        guard isCurrent(reader: reader) else { return nil }
        return UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
}

@MainActor private struct RoamHistorySystemShareSheet: UIViewControllerRepresentable {
    let request: RoamHistorySystemShareRequest
    let reader: any RoamExperienceReading
    /// Called once the system sheet closes; `true` only when the user completed an activity.
    var onComplete: ((Bool) -> Void)? = nil
    func makeUIViewController(context: Context) -> UIViewController {
        if let controller = request.makeActivityController(reader: reader) {
            let onComplete = self.onComplete
            controller.completionWithItemsHandler = { _, completed, _, _ in onComplete?(completed) }
            return controller
        }
        return UIViewController()
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}

/// ROAM-r11-9: MP `VISIBILITY_CHANNELS` (utils/roam-route-privacy.js:39-43): 公开 = 广场/朋友圈/小红书/保存,
/// 仅好友 = 朋友圈/保存, 仅自己 = 保存. 更多 (system share) follows 保存, as the MP `shareMore` does.
enum RoamShareVisibility: String, CaseIterable, Identifiable {
    case `public`, friends, `private`
    var id: Self { self }
    func allows(_ channel: RoamShareChannelPolicy.Channel) -> Bool {
        switch channel {
        case .savePhoto, .systemShare: return true
        case .momentsGuide: return self != .private
        case .xiaohongshuGuide: return self == .public
        }
    }
}
