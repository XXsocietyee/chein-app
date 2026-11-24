import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor struct ClubProfileMediaSection: View {
    @Binding var draft: ClubOperationsDraft
    let snapshot: ClubOperationsSnapshot
    let identity: ClubReadIdentity?
    let service: ClubProfileMediaService?
    @ObservedObject var flow: ClubProfileMediaFlow
    let enabled: Bool
    @Environment(\.locale) private var locale
    @State private var showing = false
    var body: some View {
        Section(String(localized: LocalizedStringResource("media.title", table: "ClubProfileMedia", locale: locale))) {
            ForEach(ClubProfileMediaField.allCases, id: \.rawValue) { field in
                Button(field == .logo ? String(localized: LocalizedStringResource("media.selectLogo", table: "ClubProfileMedia", locale: locale)) : String(localized: LocalizedStringResource("media.selectCover", table: "ClubProfileMedia", locale: locale))) {
                    guard enabled, let identity, let service else { return }
                    showing = flow.open(field: field, snapshot: snapshot, identity: identity, service: service)
                }.disabled(!enabled || service == nil || flow.state == .uploading)
                    .accessibilityIdentifier("club.profile.media." + field.rawValue)
                if (field == .logo ? draft.logoUpload : draft.coverUpload) != nil {
                    Text(String(localized: LocalizedStringResource("media.staged", table: "ClubProfileMedia", locale: locale)))
                    Button(String(localized: LocalizedStringResource("media.discard", table: "ClubProfileMedia", locale: locale)), role: .destructive) { draft.discardMedia(field, original: snapshot.profile) }.disabled(!enabled)
                }
            }
            if service == nil { Text(String(localized: LocalizedStringResource("media.disabled", table: "ClubProfileMedia", locale: locale))).cyText(.bodyCompact) }
        }
        .sheet(isPresented: $showing, onDismiss: { flow.closeSelection() }) { Group {
            NavigationStack { ClubProfileMediaEditor(flow: flow, apply: { receipt in
                guard enabled, identity == receipt.scope.identity else { return }
                try? draft.stageMedia(receipt)
            }) }
        }.cySheet(detents: [.large])
        }
    }
}

@MainActor private struct ClubProfileMediaEditor: View {
    @ObservedObject var flow: ClubProfileMediaFlow
    let apply: (ClubProfileMediaReceipt) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var item: PhotosPickerItem?
    @State private var crop: MerchantImageCropDraft?
    @State private var camera = false
    @State private var loading = false
    @State private var issue: String?
    @State private var selectionGeneration = UUID()
    private var canSelect: Bool { scenePhase == .active && flow.current && !loading && flow.state != .uploading && flow.state != .unknown && flow.state != .revoked }
    var body: some View {
        Form {
            if let crop {
                MerchantImageCropView(draft: crop, confirm: { id, rect in
                    guard canSelect, crop.id == id, let image = try? MerchantImageCropRenderer.render(crop.source, rect: rect), flow.accepts(image) else { return }
                    self.crop = nil; flow.prepare(image)
                }, cancel: { self.crop = nil })
            } else {
                if let preview = flow.preview, let image = UIImage(data: preview.jpeg) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                        .accessibilityLabel(Text("media.destination.image"))
                    Text(String(localized: LocalizedStringResource("media.uploadHint", table: "ClubProfileMedia", locale: locale)))
                    Button(String(localized: LocalizedStringResource("media.upload", table: "ClubProfileMedia", locale: locale))) { flow.upload(consume: apply) }.disabled(!canSelect)
                } else if let asset = flow.pendingAsset, let scope = flow.scope, let service = flow.service {
                    Text(verbatim: String(format: String(localized: LocalizedStringResource("media.asset", table: "ClubProfileMedia", locale: locale)), String(asset), flow.reviewState ?? String(localized: LocalizedStringResource("media.pending", table: "ClubProfileMedia", locale: locale))))
                    Button(String(localized: LocalizedStringResource("media.readReview", table: "ClubProfileMedia", locale: locale))) { flow.checkReview(retry: false, consume: apply) }
                        .disabled(flow.state == .uploading || !service.permitsReview(scope, retry: false))
                    if ["REJECTED", "UNAVAILABLE"].contains(flow.reviewState ?? "") {
                        Button(String(localized: LocalizedStringResource("media.retryReview", table: "ClubProfileMedia", locale: locale))) { flow.checkReview(retry: true, consume: apply) }
                            .disabled(flow.state == .uploading || !service.permitsReview(scope, retry: true))
                    }
                    Text(String(localized: LocalizedStringResource("media.reviewHint", table: "ClubProfileMedia", locale: locale)))
                } else if let scope = flow.scope, let service = flow.service {
                    PhotosPicker(selection: $item, matching: .images) { Label(String(localized: LocalizedStringResource("media.album", table: "ClubProfileMedia", locale: locale)), systemImage: "photo") }
                        .disabled(!canSelect || !service.permitsAlbum(scope))
                    Button(String(localized: LocalizedStringResource("media.camera", table: "ClubProfileMedia", locale: locale))) { Task { await openCamera(scope: scope, service: service) } }
                        .disabled(!canSelect || !service.permitsCamera(scope) || !UIImagePickerController.isSourceTypeAvailable(.camera))
                }
                if loading || flow.state == .uploading { ProgressView() }
                if flow.state == .unknown { Text(String(localized: LocalizedStringResource("media.unknown", table: "ClubProfileMedia", locale: locale))) }
                if flow.state == .revoked { Text(String(localized: LocalizedStringResource("media.revoked", table: "ClubProfileMedia", locale: locale))) }
                if flow.state == .notSent { Text(String(localized: LocalizedStringResource("media.notSent", table: "ClubProfileMedia", locale: locale))) }
                if flow.state == .rejected { Text(String(localized: LocalizedStringResource("media.rejected", table: "ClubProfileMedia", locale: locale))) }
                if flow.state == .uploaded { Text(String(localized: LocalizedStringResource("media.uploaded", table: "ClubProfileMedia", locale: locale))) }
                if let issue { Text(verbatim: issue) }
            }
        }
        .cyGroupedSurface()
        .navigationTitle(flow.field == .logo ? String(localized: LocalizedStringResource("media.logo", table: "ClubProfileMedia", locale: locale)) : String(localized: LocalizedStringResource("media.cover", table: "ClubProfileMedia", locale: locale))).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: LocalizedStringResource("media.done", table: "ClubProfileMedia", locale: locale))) { dismiss() }.disabled(flow.state == .uploading) } }
        .interactiveDismissDisabled(flow.state == .uploading)
        .sheet(isPresented: $camera) {
            MerchantEvidenceCameraCapture { bytes in
                camera = false
                guard canSelect, let scope = flow.scope, flow.service?.permitsCamera(scope) == true, let bytes else { return }
                accept(bytes)
            }
        }
        .onChange(of: item) { _, item in
            let stamp = UUID(); selectionGeneration = stamp
            guard canSelect, let item, let scope = flow.scope, flow.service?.permitsAlbum(scope) == true else { return }
            loading = true
            Task {
                defer { if selectionGeneration == stamp { loading = false } }
                let bytes = try? await item.loadTransferable(type: Data.self)
                guard selectionGeneration == stamp, scenePhase == .active, flow.current,
                      flow.service?.permitsAlbum(scope) == true, !Task.isCancelled, let bytes else { return }
                accept(bytes)
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { selectionGeneration = UUID(); crop = nil; item = nil; camera = false; flow.retire(); dismiss() } }
    }
    private func openCamera(scope: ClubProfileMediaScope, service: ClubProfileMediaService) async {
        guard canSelect, service.permitsCamera(scope) else { return }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            guard await CYPermissionSystemPrompt.precede(.camera) else { return }
        }
        camera = true
    }
    private func accept(_ bytes: Data) {
        guard flow.current, let field = flow.field, let image = try? RetainedImageSanitizer.sanitize(bytes) else { issue = String(localized: LocalizedStringResource("media.unreadable", table: "ClubProfileMedia", locale: locale)); return }
        // Existing .gallery geometry is exactly 16:9; merchant .cover is 5:3.
        crop = .init(source: image, aspect: field == .logo ? .logo : .gallery); issue = nil
    }
}
/// Removal of the workspace, not presentation of its sheet, ends the upload/save lease.
@MainActor struct ClubProfileMediaOwnerAnchor: UIViewControllerRepresentable {
    let flow: ClubProfileMediaFlow
    final class Coordinator { let flow: ClubProfileMediaFlow; init(_ flow: ClubProfileMediaFlow) { self.flow = flow } }
    func makeCoordinator() -> Coordinator { Coordinator(flow) }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) { coordinator.flow.retire() }
}
