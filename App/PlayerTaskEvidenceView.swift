import SwiftUI
import UIKit

/// Native task/review ownership. Camera capture remains a sheet owned by the runtime host. The existing device coordinator supplies
/// context-bound capture/upload receipts; no URL field can fabricate a photo receipt.
@MainActor struct PlayerTaskEvidenceView: View {
    let target: PlayerTaskEvidenceTarget
    @Bindable var player: PlayPlayerGameCoordinator
    var device: PlayDeviceCaptureCoordinator?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var manualFocused: Bool
    @StateObject private var reviewOwner: PlayerTaskEvidenceReviewController
    private var sameTarget: Bool { reviewOwner.target.id == target.id }
    private var valid: Bool { sameTarget && reviewOwner.canInteract }
    init(target: PlayerTaskEvidenceTarget, player: PlayPlayerGameCoordinator, device: PlayDeviceCaptureCoordinator? = nil) {
        self.target = target; self.player = player; self.device = device
        _reviewOwner = StateObject(wrappedValue: .init(target: target, player: player, device: device))
    }
    var body: some View {
        let opening = sameTarget ? reviewOwner.captureInput() : nil, outputID = device?.outputID
        Group {
            Form {
                Section {
                    Text(target.kind == .scan ? "playerEvidence.scan.detail" : "playerEvidence.photo.detail")
                    Text("playerEvidence.serverAuthority").cyText(.bodyCompact)
                    if !player.acceptsEvidence(target) { Text("playerEvidence.stale") }
                    if let issue = reviewOwner.issue ?? device?.issue { PlayExperienceIssueView(issue: issue) }
                }
                if target.kind == .scan { scanFields(opening, outputID: outputID) } else { photoFields(opening, outputID: outputID) }
                if sameTarget, let offered = reviewOwner.review {
                    PlayerTaskEvidenceReviewCard(owner: reviewOwner, offered: offered) { clear(); dismiss() }.id(offered.id)
                }
                if reviewOwner.working { CYSkeleton(label: "playerEvidence.working") }
            }.cyGroupedSurface().navigationTitle(target.kind == .scan ? "playerEvidence.scan.title" : "playerEvidence.photo.title").navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("nativeNav.close") { clear(); dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("action.done") { manualFocused = false }.accessibilityIdentifier("playerEvidence.keyboard.done")
                    }
                }
        }.privacySensitive().accessibilityIdentifier("playerEvidence.sheet")
            .background { PlayerTaskEvidenceRoot(owner: reviewOwner).frame(width: 0, height: 0) }
            .onAppear { reviewOwner.appear(active: scenePhase == .active) }
            .onDisappear { reviewOwner.disappear() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { clear(); dismiss() }
                else { reviewOwner.sceneChanged(active: phase == .active) }
            }
            .onChange(of: target.id) { _, _ in clear(); dismiss() }
            .onChange(of: player.hasCurrentProjection) { _, current in if !current { clear() } }
    }
    private func scanFields(_ opening: PlayerTaskEvidenceReviewController.InputTicket?, outputID: UUID?) -> some View {
        Section("playerEvidence.scan.title") {
            CYPillButton("playerEvidence.scan.camera", style: .secondary) { Task { await reviewOwner.captureDevice(.scan, offered: opening) } }
                .listRowBackground(Color.clear)
                .disabled(!valid || device?.supports(.scan) != true || device?.busy == true)
            if device?.supports(.scan) != true { Text("playerEvidence.deviceOff").cyText(.bodyCompact) }
            if case .scan = device?.output {
                CYStatusChip("playerEvidence.scan.captured", tone: .success, systemImage: "checkmark.viewfinder")
                CYPillButton("playx.review") { reviewOwner.prepareCapturedScan(outputID: outputID, offered: opening) }.listRowBackground(Color.clear).disabled(!valid || device?.busy == true)
            }
            TextField("playerEvidence.scan.manual", text: Binding(get: { sameTarget ? reviewOwner.manualText : "" }, set: { reviewOwner.updateManual($0, offered: opening) }), axis: .vertical)
                .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(!valid).focused($manualFocused)
                .accessibilityIdentifier("playerEvidence.manual")
            Text("playerEvidence.scan.manualDetail").cyText(.bodyCompact)
            CYPillButton("playerEvidence.scan.reviewManual", style: .secondary) { manualFocused = false; reviewOwner.prepareManual(reviewOwner.manualText, offered: opening) }
                .listRowBackground(Color.clear)
                .disabled(!valid || reviewOwner.manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("playerEvidence.manual.review")
        }
    }
    private func photoFields(_ opening: PlayerTaskEvidenceReviewController.InputTicket?, outputID: UUID?) -> some View {
        Section("playerEvidence.photo.title") {
            CYPillButton("playerEvidence.photo.capture", style: .secondary) { Task { await reviewOwner.captureDevice(.photo, offered: opening) } }
                .listRowBackground(Color.clear)
                .disabled(!valid || device?.supports(.photo) != true || device?.busy == true)
            CYPillButton("playerEvidence.photo.library", style: .secondary) { Task { await reviewOwner.captureDevice(.photo, library: true, offered: opening) } }
                .listRowBackground(Color.clear)
                .disabled(!valid || device?.supportsLibraryPhotos != true || device?.busy == true)
            if device?.supports(.photo) != true { Text("playerEvidence.deviceOff").cyText(.bodyCompact) }
            if valid, case .photo(let bytes, _) = device?.output, let image = UIImage(data: bytes) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    .accessibilityLabel("playerEvidence.photo.preview")
                CYPillButton("playerEvidence.photo.upload") { reviewOwner.prepareUpload(outputID: outputID, offered: opening) }.listRowBackground(Color.clear).disabled(!valid || device?.canUpload != true)
            }
            if device?.busy == true { CYSkeleton(label: "playerEvidence.working") }
            if valid, device?.reviewedPhoto(expectedOutputID: outputID) != nil {
                CYStatusChip("playerEvidence.photo.uploaded", tone: .success, systemImage: "checkmark.circle")
                CYPillButton("playx.review") { reviewOwner.prepareUploadedPhoto(outputID: outputID, offered: opening) }.listRowBackground(Color.clear).disabled(!valid)
            }
        }
    }
    private func clear() { manualFocused = false; reviewOwner.retire() }
}
