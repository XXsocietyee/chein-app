import SwiftUI
import UIKit

@MainActor struct MerchantGalleryBatchView: View {
    @ObservedObject var batch: MerchantGalleryBatchModel
    let binding: MerchantGalleryBatchBinding
    let available: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("image.galleryBatch.select") { Task { await batch.select(binding: binding) } }
                .disabled(!available || batch.selecting || batch.blocked || batch.active)
                .accessibilityIdentifier("image.galleryBatch.select")
            if batch.selecting { ProgressView("image.retained.loading") }
            if batch.active && batch.current {
                Text("image.galleryBatch.remaining \(batch.remainingCount)").cyText(.meta)
                if let draft = batch.cropDraft {
                    MerchantImageCropView(draft: draft, confirm: batch.confirmCrop, cancel: batch.skip).id(draft.id)
                }
                if let context = batch.context {
                    switch context.uploads.state {
                    case .reviewing(let review):
                        if let image = UIImage(data: review.selection.jpeg) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240).accessibilityLabel("image.retained.preview")
                        }
                        // MC7-20-2: MP uploads as soon as the crop is confirmed (gallery/index.js:206-217);
                        // no realm / byte-count lines and no separate 确认上传 step.
                        ProgressView("image.retained.loading")
                            .accessibilityIdentifier("image.galleryBatch.confirmUpload")
                    case .uploading: ProgressView("image.retained.loading")
                    case .uploaded:
                        // MC7-20-2: the uploaded photo is appended to the grid automatically.
                        ProgressView("image.retained.loading")
                            .accessibilityIdentifier("image.galleryBatch.use")
                    case .failed: Text("image.retained.failed")
                    case .unknown: Text("image.retained.unknown")
                    case .idle: EmptyView()
                    }
                }
                if batch.canChangeItem {
                    Button("image.galleryBatch.skip") { batch.skip() }
                        .accessibilityIdentifier("image.galleryBatch.skip")
                    Button("image.galleryBatch.replace") { Task { await batch.replace() } }
                        .accessibilityIdentifier("image.galleryBatch.replace")
                }
                Button("image.galleryBatch.cancelAll", role: .cancel) { batch.cancel() }
                    .accessibilityIdentifier("image.galleryBatch.cancelAll")
            }
            if batch.appliedCount > 0 { Text("image.galleryBatch.applied \(batch.appliedCount)").cyText(.meta) }
            if batch.blocked { Text("image.galleryBatch.blocked").accessibilityIdentifier("image.galleryBatch.blocked") }
            if batch.failed { Text("image.retained.failed") }
        }
        .buttonStyle(.borderless)
        .task(id: autoStepKey) { await runAutoStep() }
        .onDisappear { batch.cancel() }
        .onChange(of: batch.current) { _, value in if batch.active && !value { batch.cancel() } }
        .onChange(of: scenePhase) { _, value in if value != .active { batch.cancel() } }
    }

    /// MC7-20-2: one key per pending automatic step (upload the reviewed crop, then append it).
    private var autoStepKey: String {
        guard batch.active, batch.current, let context = batch.context else { return "" }
        switch context.uploads.state {
        case .reviewing(let review): return "upload:\(review.selection.id)"
        case .uploaded(let image): return "use:\(image.id)"
        default: return ""
        }
    }

    private func runAutoStep() async {
        guard !autoStepKey.isEmpty, batch.current, !batch.selecting, let context = batch.context else { return }
        switch context.uploads.state {
        case .reviewing(let review): await batch.confirmUpload(review)
        case .uploaded(let image): batch.use(image)
        default: break
        }
    }
}
