import PhotosUI
import SwiftUI

@MainActor struct ContextualReviewComposer: View {
    @Environment(\.dismiss) private var dismiss
    let target: ContextualReviewTarget
    let owner: ContextualReviewCoordinator?
    let onAcknowledged: () -> Void
    @State private var draft = ContextualReviewDraft()
    @State private var review: ContextualReviewDraft?
    @State private var captured: ContextualReviewSession?
    @State private var busy = false
    @State private var revision = 0
    @State private var confirmDiscard = false
    @FocusState private var typing: Bool
    /// R7-PC-B1-7 / R7-PC-C1-6: MP review sheets add ≤9 photos through `app.chooseImage` and send them in `img_arr`
    /// (pages/topic/index/index.wxml:441-460, index.js:1256; scene-play-activity-detail/index.wxml:138-139, index.js:590-605, 644).
    @Environment(\.playerContentImageUploader) private var imageUploader
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var uploadingPhotos = false
    @State private var photoUploadFailure: String?
    private static let maximumPhotos = 9
    /// MP topic / activity review textarea maxlength (300); Core still accepts up to 500.
    static let maximumContents = 300
    /// Round 4 copy (MP topic/index.wxml:438/448): the topic sheet is 评价路线 with 请输入您的评价内容...
    private var isTopic: Bool { if case .topic = target { return true } else { return false } }
    @ScaledMetric(relativeTo: .body) private var photoSide: CGFloat = 72
    /// R9-PC-BN-3 / R9-PC-CN-3: the MP star size follows Dynamic Type.
    @ScaledMetric(relativeTo: .title2) private var starSide: CGFloat = 32
    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        guard let imageUploader, !uploadingPhotos else { photoItems = []; return }
        let batch = Array(items.prefix(max(0, Self.maximumPhotos - draft.imageURLs.count)))
        guard !batch.isEmpty else { photoItems = []; return }
        uploadingPhotos = true; photoUploadFailure = nil
        Task { @MainActor in
            let result = await imageUploader.upload(items: batch)
            draft.imageURLs = Array((draft.imageURLs + result.urls).prefix(Self.maximumPhotos))
            if result.failed > 0 { photoUploadFailure = result.message ?? appLocalized("merchantApply.pic.uploadFailed", locale: .current) }
            uploadingPhotos = false; photoItems = []
        }
    }
    private var state: ContextualReviewState { let _ = revision; return owner?.state ?? .idle }
    var body: some View {
        Form {
            Section("context.review.rating") {
                // R7-PC-B1-7 / R7-PC-C1-6 + round 4 (MP topic/index.wxml:441-446): five MP stars, icon_star2 filled / icon_star1 empty; text cap is the MP 300.
                HStack(spacing: CYSpacing.sm) {
                    ForEach(1...5, id: \.self) { star in
                        Button { draft.rating = star } label: {
                            (star <= draft.rating ? MPAsset.FeatureIcon.iconStar2 : MPAsset.FeatureIcon.iconStar1)
                                .resizable().scaledToFit()
                                .accessibilityHidden(true)
                                .frame(width: starSide, height: starSide)
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("context.review.starLabel \(star)"))
                        .accessibilityAddTraits(star <= draft.rating ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("context.review.rating"))
                .accessibilityIdentifier("context.review.rating")
                TextField(LocalizedStringKey(isTopic ? "context.review.topicContents" : "context.review.contents"), text: $draft.contents, axis: .vertical)
                    .lineLimit(4...10).focused($typing).accessibilityIdentifier("context.review.contents")
                    .onChange(of: draft.contents) { _, value in
                        if value.count > Self.maximumContents { draft.contents = String(value.prefix(Self.maximumContents)) }
                    }
                Text(verbatim: "\(draft.contents.count)/\(Self.maximumContents)").cyText(.meta)
            }.disabled(busy || state == .unknown || state == .acknowledged)
            if imageUploader != nil {
                Section {
                    if !draft.imageURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: CYSpacing.sm) {
                                ForEach(Array(draft.imageURLs.enumerated()), id: \.offset) { index, url in
                                    ZStack(alignment: .topTrailing) {
                                        CYCachedAsyncImage(url, role: .shelf)
                                            .frame(width: photoSide, height: photoSide)
                                            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                                            .accessibilityLabel(Text("context.review.photo \(index + 1)"))
                                        Button {
                                            if draft.imageURLs.indices.contains(index) { draft.imageURLs.remove(at: index) }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical)
                                        }
                                        .accessibilityLabel(Text("context.review.removePhoto \(index + 1)"))
                                    }
                                }
                            }
                        }
                    }
                    PhotosPicker(selection: $photoItems,
                                 maxSelectionCount: max(1, Self.maximumPhotos - draft.imageURLs.count),
                                 matching: .images) {
                        Label("context.review.addPhotos", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(uploadingPhotos || draft.imageURLs.count >= Self.maximumPhotos)
                    .onChange(of: photoItems) { _, items in uploadPhotos(items) }
                    if uploadingPhotos { ProgressView("merchantApply.pic.uploading") }
                    if let photoUploadFailure {
                        Text(verbatim: photoUploadFailure).foregroundStyle(CYColor.dangerText)
                    }
                } header: {
                    Text("context.review.photos")
                } footer: {
                    Text(verbatim: "\(draft.imageURLs.count)/\(Self.maximumPhotos)").monospacedDigit()
                }
                .disabled(busy || state == .unknown || state == .acknowledged)
            }
            if owner?.writer.isConfigured != true { Section { Text("context.review.disabled") } }
            Section {
                switch state {
                case .submitting: ProgressView("context.review.submitting")
                case .acknowledged: Text("context.review.acknowledged")
                case .unknown: Text("context.review.unknown")
                case .rejected: Text("context.review.rejected")
                case .notSent: Text("context.review.notSent")
                case .idle: EmptyView()
                }
                Button("context.review.preview") { typing = false; captured = owner?.writer.session; review = draft }
                    .disabled(!draft.isValid || busy || uploadingPhotos || state == .unknown || state == .acknowledged)
                    .accessibilityIdentifier("context.review.preview")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text(LocalizedStringKey(isTopic ? "context.review.topicTitle" : "context.review.title"))).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("action.cancel") {
                if draft != ContextualReviewDraft(), state != .acknowledged { confirmDiscard = true } else { dismiss() }
            }.disabled(busy) }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("action.done") { typing = false } }
        }
        .interactiveDismissDisabled(busy || draft != ContextualReviewDraft())
        .cyModalConfirm(
            isPresented: confirmDiscard,
            title: appLocalized("context.review.discard", locale: .current),
            cancelTitle: appLocalized("action.cancel", locale: .current),
            confirmTitle: appLocalized("context.review.discard", locale: .current),
            isDestructive: true,
            onCancel: { confirmDiscard = false },
            onConfirm: { confirmDiscard = false; draft = .init(); dismiss() }
        )
        .sheet(isPresented: Binding(get: { review != nil }, set: { if !$0 { review = nil; captured = nil } })) {
            NavigationStack {
                Form {
                    if let review {
                        LabeledContent("context.review.rating", value: String(review.rating))
                        Text(verbatim: review.contents)
                        if owner?.writer.isConfigured != true { Text("context.review.disabled") }
                        Button("context.review.submit") { Task { await submit(review) } }
                            .disabled(owner?.canSubmit != true || captured == nil || busy)
                            .accessibilityIdentifier("context.review.submit")
                    }
                }.navigationTitle("context.review.preview").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { review = nil; captured = nil }.disabled(busy) } }
            }.interactiveDismissDisabled(busy)
            .cyPlayerSheetGlass()
            .cyDomainSheet(detents: [.half, .full])
        }
        .cyDomainScreen(.player)
        .onChange(of: owner?.writer.session) { _, _ in draft = .init(); review = nil; captured = nil; busy = false; revision += 1 }
    }
    private func submit(_ value: ContextualReviewDraft) async {
        guard let owner, let captured, owner.target == target, owner.writer.session == captured else { return }
        busy = true
        await owner.submit(value, expected: captured)
        busy = false; review = nil; revision += 1
        guard owner.writer.session == captured else { draft = .init(); return }
        if owner.state == .acknowledged { draft = .init(); onAcknowledged(); dismiss() }
    }
}
