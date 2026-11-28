import SwiftUI
import PhotosUI
import UIKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// r10 account-publish (lane acct-a): App-side rows for origin/design/handoff-r2:docs/audit/parity-r10/account-publish.md §4.

// MARK: - C-F8b / N-18 topic cover + gallery come from the photo library, not typed URLs

/// r10 C-F8b: MP pages/publish/fabu topic-detail-sheet `chooseMedia` → `app.chooseImage` with a crop ratio, then
/// `getUploadClient().uploadAll` to `api/common/uploadOSS` (chengyinhub-xcx app.js:617-700, :654-683). The cover is one
/// 3:4 image (`image_3_4`), the gallery up to 9 16:9 images (`image_16_9`, chooseImage default count 9) joined with `,`
/// in `imgArr`. Bizes match `RetainedImageScope.Destination.topicCover / .topicGallery`. Rows only: the host owns the `Section`.
/// r11 C-F8c: like MP app.js:681-685 (`cropScale` → pages/crop), the picked photos open `MiniCropView` at that ratio first;
/// the chosen frame is what uploads (使用原图 = the centred frame of the ratio).
@MainActor struct ProjectEditTopicImageField: View {
    /// `resultCard`: MP 结果卡封面 (`theme-runtime-survival.js` `uploadSurvivalCover`, one 1:1 image, `image_1_1`).
    enum Kind { case cover, gallery, resultCard }
    let kind: Kind
    let title: LocalizedStringKey
    @Binding var value: String
    let identifier: String

    @Environment(\.playerContentImageUploader) private var uploader
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var thumbnailSide: CGFloat = 44
    @State private var picks: [PhotosPickerItem] = []
    @State private var uploading = false
    @State private var failedCount = 0
    @State private var failureMessage: String?
    @State private var cropBatch: CropBatch?

    /// r11 C-F8c: the decoded picks waiting for the crop step.
    struct CropBatch: Identifiable {
        let id = UUID()
        let images: [UIImage]
    }

    static let galleryMaximum = 9

    private var urls: [String] {
        value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var single: Bool { kind != .gallery }
    private var maximum: Int { single ? 1 : Self.galleryMaximum }
    /// The cover is replaced by a new pick; the gallery appends until it is full.
    private var selectable: Int { single ? 1 : max(0, maximum - urls.count) }
    private var bizType: String {
        if kind == .resultCard { return "image_1_1" }
        let destination: RetainedImageScope.Destination = kind == .cover ? .topicCover : .topicGallery
        return destination.uploadBizType ?? "image_free"
    }
    private var aspect: (width: Int, height: Int) {
        switch kind {
        case .cover: return (3, 4)
        case .gallery: return (16, 9)
        case .resultCard: return (1, 1)
        }
    }

    var body: some View {
        Group {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                row(index: index, url: url)
            }
            .onDelete { offsets in
                var list = urls
                list.remove(atOffsets: offsets)
                value = list.joined(separator: ",")
            }
            .deleteDisabled(uploading)
            if uploading {
                ProgressView { Text("fixr10.ap.image.uploading") }
            } else if selectable > 0 {
                picker
            }
            if failedCount > 0 {
                Text("fixr10.ap.image.failed \(failedCount) \(failureMessage ?? "")")
                    .font(.footnote).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier(identifier + ".failed")
            } else if uploader == nil {
                Text("fixr10.ap.image.signIn").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var ratioLiteral: String { "\(aspect.width):\(aspect.height)" }

    private func cropSheet(_ batch: CropBatch) -> some View {
        NavigationStack {
            MiniCropView(images: batch.images, ratio: ratioLiteral, onFinish: { results in
                cropBatch = nil
                Task { await upload(batch.images, results: results) }
            }, onCancel: {
                cropBatch = nil
            })
            .accessibilityIdentifier(identifier + ".crop")
        }
        .interactiveDismissDisabled(uploading)
    }

    private var picker: some View {
        PhotosPicker(selection: $picks, maxSelectionCount: selectable, matching: .images) {
            LabeledContent {
                Text(LocalizedStringKey(single && !urls.isEmpty ? "fixr10.ap.cover.replace" : "fixr10.ap.image.choose"))
            } label: {
                Label(title, systemImage: single ? "photo" : "photo.on.rectangle")
            }
        }
        .disabled(!isEnabled || uploader == nil)
        .accessibilityIdentifier(identifier)
        // r11 C-F8c: on the one picker row, not the `Group` (a Group modifier would repeat on every image row).
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task { await prepareCrop(items) }
        }
        .sheet(item: $cropBatch) { batch in
            cropSheet(batch)
        }
    }

    private func row(index: Int, url: String) -> some View {
        HStack {
            AsyncImage(url: URL(string: url)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: thumbnailSide, height: thumbnailSide)
            .clipped()
            .accessibilityHidden(true)
            if single {
                Text(title)
            } else {
                Text("fixr10.ap.image.item \(index + 1)")
            }
        }
        .accessibilityIdentifier(identifier + ".item." + String(index))
    }

    /// r11 C-F8c: decode the picks, then hand them to the crop sheet (MP chooseImage → pages/crop → upload).
    private func prepareCrop(_ items: [PhotosPickerItem]) async {
        guard uploader != nil, !uploading, cropBatch == nil else { picks = []; return }
        var images: [UIImage] = []
        var unreadable = 0
        for item in items.prefix(selectable) {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            } else {
                unreadable += 1
            }
        }
        picks = []
        failedCount = unreadable
        failureMessage = nil
        if !images.isEmpty { cropBatch = CropBatch(images: images) }
    }

    /// MP chooseImage → uploadAll: uploads in order and keeps only the URLs the server returned.
    private func upload(_ images: [UIImage], results: [MiniCropView.Result]) async {
        guard let uploader, !uploading else { return }
        uploading = true
        failedCount = 0
        failureMessage = nil
        var uploaded: [String] = []
        for (offset, image) in images.enumerated() {
            let result = offset < results.count ? results[offset] : .original
            do {
                guard let jpeg = Self.croppedJPEG(image, result: result, aspect: aspect) else {
                    throw PlayerContentImageUploader.Failure.invalidImage
                }
                uploaded.append(try await uploader.upload(jpeg: jpeg, bizType: bizType))
            } catch PlayerContentImageUploader.Failure.rejected(let text) {
                failedCount += 1
                if failureMessage == nil { failureMessage = text }
            } catch {
                failedCount += 1
            }
        }
        if single {
            if let first = uploaded.first { value = first }
        } else {
            value = (urls + uploaded).prefix(maximum).joined(separator: ",")
        }
        uploading = false
    }

    /// Renders the crop frame `MiniCropView` returned (source-pixel rect), downsized like the uploader does.
    /// 使用原图 (`.original`) keeps the centred frame of the ratio, as `PlayerContentImageUploader.jpeg(from:aspect:)` does.
    static func croppedJPEG(_ image: UIImage, result: MiniCropView.Result, aspect: (width: Int, height: Int)) -> Data? {
        guard case .crop(let rect) = result else {
            guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
            return PlayerContentImageUploader.jpeg(from: data, aspect: aspect)
        }
        let source = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        let longest = max(source.width, source.height)
        guard source.width > 0, source.height > 0, longest > 0 else { return nil }
        let scale = min(1, PlayerContentImageUploader.maximumEdge / longest)
        let target = CGSize(width: max(1, (source.width * scale).rounded()), height: max(1, (source.height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(x: -source.minX * scale, y: -source.minY * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }
}
