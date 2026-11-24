import SwiftUI
import UIKit

@MainActor protocol OwnedTopicCoverSelecting: AnyObject {
    func select() async throws -> RetainedSelectedImage?
    func cancel()
}
extension RetainedNativeImagePicker: OwnedTopicCoverSelecting {}

@MainActor final class OwnedTopicCoverAuthorModel: ObservableObject {
    let original: OwnedTopicCoverAuthorPresentation.Presentation
    let pickerHost = RetainedImagePickerHost()
    @Published private(set) var revision = 0
    @Published private(set) var image: UIImage?
    @Published private(set) var renderedAsset: OwnedTopicCoverAsset?
    private let selected: (OwnedTopicCoverAuthorPresentation.Presentation) -> Void
    private let injectedPicker: (any OwnedTopicCoverSelecting)?
    private lazy var nativePicker = pickerHost.makePicker(selectionApproval: { [weak self] in
        guard let self, let id = self.pickerID else { return false }
        return self.flow.canContinuePicking(id)
    })
    private var picker: any OwnedTopicCoverSelecting { injectedPicker ?? nativePicker }
    private var pickerTask: Task<Void,Never>?
    private var pickerID: UUID?
    var flow: OwnedTopicCoverAuthorFlow { original.flow }
    init(original: OwnedTopicCoverAuthorPresentation.Presentation, picker: (any OwnedTopicCoverSelecting)? = nil,
         selected: @escaping (OwnedTopicCoverAuthorPresentation.Presentation) -> Void) {
        self.original = original; injectedPicker = picker; self.selected = selected
    }
    func load() async { await flow.load(); revision += 1 }
    func loadCurrentDetails() async { guard flow.canReadCurrentDetails else { return }; await load() }
    func choose() async {
        guard pickerTask == nil, let id = flow.beginPicking() else { return }; pickerID = id; revision += 1
        let selectedPicker = picker
        let task = Task { [weak self] in
            guard let self else { return }
            defer { if self.pickerID == id { self.pickerTask = nil; self.pickerID = nil; self.revision += 1 } }
            guard self.flow.canContinuePicking(id) else { self.flow.finishPicking(nil, original: id); return }
            do {
                let picked = try await selectedPicker.select()
                guard self.pickerID == id, !Task.isCancelled, self.flow.isCurrent else { return }
                self.flow.finishPicking(picked,original:id); self.image = nil; self.renderedAsset = nil
            } catch { guard self.pickerID == id else { return }; self.flow.finishPicking(nil,original:id) }
        }
        pickerTask = task
        await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
    }
    func cancelPicked(_ original: OwnedTopicCoverAuthorFlow.Review) { flow.cancelPicked(original); revision += 1 }
    func upload(_ original: OwnedTopicCoverAuthorFlow.Review) {
        guard pickerTask == nil, let claim = flow.claimUpload(original) else { return }; image = nil; renderedAsset = nil; revision += 1
        Task { [weak self,flow] in await flow.upload(claim); self?.revision += 1 }
    }
    func persistReceipt() { flow.persistUploadReceipt(); revision += 1 }
    func persistSelectionReceipt() { flow.persistSelectionReceipt(); revision += 1; finishIfSelected() }
    func read(_ asset: OwnedTopicCoverAsset) async {
        image = nil; renderedAsset = nil; revision += 1; await flow.readImage(asset)
        guard flow.isCurrent, flow.checkedAsset == asset, let bytes = flow.checkedImage else { revision += 1; return }
        if let safe = try? RetainedImageSanitizer.sanitize(bytes), let decoded = UIImage(data:safe.jpeg), flow.isCurrent {
            image = decoded; renderedAsset = asset
        }
        revision += 1
    }
    func review(_ asset: OwnedTopicCoverAsset) {
        guard image != nil, renderedAsset == asset else { return }; _ = flow.reviewSelection(asset); revision += 1
    }
    func cancel(_ original: OwnedTopicCoverAuthorFlow.SelectionReview) { flow.cancelSelection(original); revision += 1 }
    func confirm(_ review: OwnedTopicCoverAuthorFlow.SelectionReview) {
        guard image != nil, renderedAsset == review.command.asset, let claim = flow.claimSelection(review) else { return }; revision += 1
        Task { [weak self,flow] in await flow.select(claim); self?.revision += 1; self?.finishIfSelected() }
    }
    private func finishIfSelected() { if case .selected = flow.state { selected(original) } }
    func check(_ snapshot: OwnedTopicCoverJournal.Snapshot) {
        guard !flow.isBusy, !flow.hasUnstoredReceipt else { return }; revision += 1
        Task { [weak self,flow] in await flow.checkSelection(snapshot); self?.revision += 1; self?.finishIfSelected() }
    }
    func retry(_ snapshot: OwnedTopicCoverJournal.Snapshot) {
        guard !flow.isBusy, !flow.hasUnstoredReceipt else { return }; revision += 1
        Task { [weak self,flow] in await flow.retrySelection(snapshot); self?.revision += 1; self?.finishIfSelected() }
    }
    func binding(_ original: OwnedTopicCoverAuthorFlow.SelectionReview?) -> Binding<OwnedTopicCoverAuthorFlow.SelectionReview?> {
        .init(get:{ guard let original,self.flow.isCurrent,self.flow.selectionReview?.id == original.id else { return nil };return original },set:{ next in
            guard next == nil,let original else { return };self.cancel(original)
        })
    }
    func close() { pickerTask?.cancel(); pickerTask = nil; pickerID = nil; picker.cancel(); flow.close(); image = nil; renderedAsset = nil; revision += 1 }
}

@MainActor struct OwnedTopicCoverAuthorView: View {
    let original: OwnedTopicCoverAuthorPresentation.Presentation
    let mayChange: () -> Bool
    let close: () -> Void
    @StateObject private var model: OwnedTopicCoverAuthorModel
    @Environment(\.locale) private var locale
    init(original: OwnedTopicCoverAuthorPresentation.Presentation, mayChange: @escaping () -> Bool,
         selected: @escaping (OwnedTopicCoverAuthorPresentation.Presentation) -> Void, close: @escaping () -> Void, picker: (any OwnedTopicCoverSelecting)? = nil) {
        self.original = original; self.mayChange = mayChange; self.close = close
        _model = StateObject(wrappedValue:.init(original:original,picker:picker,selected:selected))
    }
    private func text(_ key:StaticString,_ english:String.LocalizationValue) -> String { String(localized:LocalizedStringResource(key,defaultValue:english,locale:locale)) }
    var body: some View {
        let flow = original.flow, local = flow.localReview, selection = flow.selectionReview, saved = flow.snapshot
        NavigationStack {
            Form {
                Section {
                    Text(text("ownedCover.scope","Choose a cover for a future reviewed release. Picking a photo stays local. Uploading and selecting are separate explicit actions; existing releases keep their original image."))
                        .accessibilityIdentifier("ownedCover.scope")
                    if let current = flow.current {
                        LabeledContent(text("ownedCover.topic","Saved topic"),value:String(current.topicID))
                        LabeledContent(text("ownedCover.config","Current content revision"),value:String(current.configVersion))
                        LabeledContent(text("ownedCover.selectionRevision","Current cover revision"),value:String(current.selectionVersion))
                        if let asset = current.asset { assetFields(asset,prefix:"ownedCover.saved") }
                        if current.selection == .stale { Text(text("ownedCover.stale","The saved cover selection belongs to an earlier content or ownership revision. Review an explicit replacement before applying it.")) }
                        if current.availability == .unavailable { Text(text("ownedCover.savedUnavailable","The current cover bytes are unavailable. The saved selection has not been cleared.")) }
                        if let asset = current.asset {
                            CYPillButton(verbatim: text("ownedCover.readSaved","Read the saved cover image"), style: .secondary) { Task { await model.read(asset) } }
                                .disabled(flow.isBusy).accessibilityIdentifier("ownedCover.readSaved").e1ActionRow()
                        }
                    }
                    CYPillButton(verbatim: text("ownedCover.reload","Read current cover details"), style: .secondary) { Task { await model.loadCurrentDetails() } }
                        .disabled(!flow.canReadCurrentDetails).accessibilityIdentifier("ownedCover.reload").e1ActionRow()
                }
                if !mayChange() {
                    Text(text("ownedCover.editBeforeChange","An unresolved review or release must be recovered first. After requesting review, continue editing and save a new server version before changing its cover."))
                        .accessibilityIdentifier("ownedCover.editBeforeChange")
                }
                Section {
                    CYPillButton(verbatim: text("ownedCover.choose","Choose an image")) { Task { await model.choose() } }
                        .disabled(!flow.canPick).accessibilityIdentifier("ownedCover.choose").e1ActionRow()
                    if let local {
                        if let image = UIImage(data:local.image.jpeg) { Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)).accessibilityLabel(Text("image.retained.preview")).accessibilityIdentifier("ownedCover.localPreview") }
                        Text(text("ownedCover.localOnly","This preview uses only the selected, sanitized image on this device. It has not been uploaded."))
                            .accessibilityIdentifier("ownedCover.localOnly")
                        CYPillButton(verbatim: text("ownedCover.upload","Upload this image for checks"), style: .secondary) { model.upload(local) }
                            .disabled(!flow.canUpload(local)).accessibilityIdentifier("ownedCover.upload").e1ActionRow()
                        CYPillButton(verbatim: text("ownedCover.cancelLocal","Cancel this local image"), style: .secondary) { model.cancelPicked(local) }
                            .disabled(flow.isBusy).accessibilityIdentifier("ownedCover.cancelLocal").e1ActionRow()
                    }
                    if let count = saved?.unresolvedUploadCount, count > 0, !flow.hasUnstoredUploadReceipt {
                        Text(text("ownedCover.uploadUnknown","An upload has no saved asset receipt. It may have reached the server, and no upload-status API is available. Choosing and uploading another image creates a separate upload; no automatic retry will occur."))
                            .accessibilityIdentifier("ownedCover.uploadUnknown")
                    }
                    if flow.hasUnstoredUploadReceipt {
                        Text(text("ownedCover.receiptUnstored","The server returned an asset receipt, but this device could not save it. Keep this screen open and retry saving the receipt before selecting the cover."))
                        CYPillButton(verbatim: text("ownedCover.saveReceipt","Save the received asset receipt"), style: .secondary) { model.persistReceipt() }
                            .disabled(!flow.canPersistUploadReceipt).accessibilityIdentifier("ownedCover.saveReceipt").e1ActionRow()
                    }
                    if let asset = flow.uploadedAsset {
                        assetFields(asset,prefix:"ownedCover.uploaded")
                        CYPillButton(verbatim: text("ownedCover.readUploaded","Read the checked uploaded image"), style: .secondary) { Task { await model.read(asset) } }
                            .disabled(flow.isBusy).accessibilityIdentifier("ownedCover.readUploaded").e1ActionRow()
                    }
                }
                if let image = model.image, let asset = model.renderedAsset, flow.isCurrent {
                    Section {
                        Image(uiImage:image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)).accessibilityLabel(Text("ownedCover.authorImage")).accessibilityIdentifier("ownedCover.serverPreview")
                        Text(text("ownedCover.verifiedBytes","These bytes were read through this account's exact asset reference and matched its SHA-256. This does not approve or publish the topic."))
                        if flow.current == nil {
                            if flow.hasUnstoredReceipt {
                                Text(text("ownedCover.receiptBeforeCurrent","Save the received receipt on this device before reading current cover details."))
                                    .accessibilityIdentifier("ownedCover.receiptBeforeCurrent")
                            } else {
                                Text(text("ownedCover.currentRequired","Read current cover details before reviewing this image. No content or ownership revision has been inferred."))
                                    .accessibilityIdentifier("ownedCover.currentRequired")
                            }
                            CYPillButton(verbatim: text("ownedCover.reload","Read current cover details"), style: .secondary) { Task { await model.loadCurrentDetails() } }
                                .disabled(!flow.canReadCurrentDetails).accessibilityIdentifier("ownedCover.readForSelection").e1ActionRow()
                        }
                        CYPillButton(verbatim: text("ownedCover.reviewSelection","Review this cover selection")) { model.review(asset) }
                            .disabled(!flow.canReviewSelection(asset)).accessibilityIdentifier("ownedCover.reviewSelection").e1ActionRow()
                    }
                }
                if flow.hasUnstoredSelectionReceipt {
                    Section {
                        Text(text("ownedCover.selectionReceiptUnstored","The server confirmed this selection, but its receipt could not be saved on this device. Save that exact receipt before continuing to review."))
                        CYPillButton(verbatim: text("ownedCover.saveSelectionReceipt","Save the received selection receipt"), style: .secondary) { model.persistSelectionReceipt() }
                            .disabled(!flow.canPersistSelectionReceipt).accessibilityIdentifier("ownedCover.saveSelectionReceipt").e1ActionRow()
                    }
                } else if !flow.hasUnstoredReceipt, flow.hasUnknownSelection, let saved {
                    Section {
                        Text(text("ownedCover.selectionUnknown","The cover selection is unconfirmed. Its original request is saved. A different current revision does not prove it failed."))
                            .accessibilityIdentifier("ownedCover.selectionUnknown")
                        CYPillButton(verbatim: text("ownedCover.checkSelection","Check the original selection request"), style: .secondary) { model.check(saved) }
                            .disabled(flow.isBusy).accessibilityIdentifier("ownedCover.checkSelection").e1ActionRow()
                        CYPillButton(verbatim: text("ownedCover.retrySelection","Retry exactly the original selection"), style: .secondary) { model.retry(saved) }
                            .disabled(flow.isBusy || !mayChange()).accessibilityIdentifier("ownedCover.retrySelection").e1ActionRow()
                    }
                }
                if flow.isWorking { CYSkeletonBlock(height: 18).accessibilityLabel(Text("cy.state.loading")).accessibilityIdentifier("ownedCover.working") }
                if case .failed = flow.state { Text(text("ownedCover.failed","The action could not be verified. Existing cover and submission records are retained.")) }
                if flow.state == .unauthorized { Text(text("ownedCover.unauthorized","Sign in again before reading or changing the cover.")) }
            }
            .formStyle(.grouped).cyGroupedSurface().navigationTitle(Text(verbatim: text("ownedCover.title","Author cover"))).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) {
                Button(text("ownedCover.close","Close")) { model.close();close() }.accessibilityIdentifier("ownedCover.close")
            } }
        }
        .background(RetainedImagePresenterHost(host:model.pickerHost).frame(width:0,height:0))
        .task(id:original.id) { await model.load() }
        .sheet(item:model.binding(selection)) { captured in Group { selectionConfirmation(captured) }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
        .onDisappear { model.close();close() }
        .cyDomainScreen(.topicEditor)
    }
    @ViewBuilder private func assetFields(_ asset:OwnedTopicCoverAsset,prefix:String) -> some View {
        Text(verbatim:asset.assetID).textSelection(.enabled).accessibilityIdentifier(prefix + ".asset")
        Text(verbatim:asset.sourceVersion).textSelection(.enabled).accessibilityIdentifier(prefix + ".version")
        Text(verbatim:asset.contentHash).textSelection(.enabled).accessibilityIdentifier(prefix + ".hash")
    }
    private func selectionConfirmation(_ captured:OwnedTopicCoverAuthorFlow.SelectionReview) -> some View {
        NavigationStack {
            Form {
                Text(text("ownedCover.confirmScope","Apply exactly this asset to the captured topic, content revision and CONTENT ownership record. This changes the next review input, not existing releases."))
                assetFields(captured.command.asset,prefix:"ownedCover.confirm")
                LabeledContent(text("ownedCover.topic","Saved topic"),value:String(captured.command.topicID))
                LabeledContent(text("ownedCover.contentSlot","Captured CONTENT ownership record"),value:String(captured.command.expectedContentSlotID))
                LabeledContent(text("ownedCover.config","Current content revision"),value:String(captured.command.expectedConfigVersion))
                LabeledContent(text("ownedCover.selectionRevision","Current cover revision"),value:String(captured.command.expectedSelectionVersion))
                CYPillButton(verbatim: text("ownedCover.confirm","Apply this exact cover selection")) { model.confirm(captured) }
                    .accessibilityIdentifier("ownedCover.confirm").e1ActionRow()
            }
            .formStyle(.grouped).cyGroupedSurface().navigationTitle(Text(verbatim: text("ownedCover.confirmTitle","Confirm cover selection"))).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) {
                Button(text("ownedCover.cancel","Cancel")) { model.cancel(captured) }.accessibilityIdentifier("ownedCover.cancel")
            } }
        }.onDisappear { model.cancel(captured) }
    }
}
