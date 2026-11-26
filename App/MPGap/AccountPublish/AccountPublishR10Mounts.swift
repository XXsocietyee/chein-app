import SwiftUI
import PhotosUI

// r10 account-publish (lane acct-a): App-side rows for origin/design/handoff-r2:docs/audit/parity-r10/account-publish.md §4.

// MARK: - C-F8b / N-18 topic cover + gallery come from the photo library, not typed URLs

/// r10 C-F8b: MP pages/publish/fabu topic-detail-sheet `chooseMedia` → `app.chooseImage` with a crop ratio, then
/// `getUploadClient().uploadAll` to `api/common/uploadOSS` (chengyinhub-xcx app.js:617-700, :654-683). The cover is one
/// 3:4 image (`image_3_4`), the gallery up to 9 16:9 images (`image_16_9`, chooseImage default count 9) joined with `,`
/// in `imgArr`. Bizes match `RetainedImageScope.Destination.topicCover / .topicGallery`. The picked photo is
/// centre-cropped to that ratio (the interactive crop page is not wired here). Rows only: the host owns the `Section`.
@MainActor struct ProjectEditTopicImageField: View {
    enum Kind { case cover, gallery }
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

    static let galleryMaximum = 9

    private var urls: [String] {
        value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var maximum: Int { kind == .cover ? 1 : Self.galleryMaximum }
    /// The cover is replaced by a new pick; the gallery appends until it is full.
    private var selectable: Int { kind == .cover ? 1 : max(0, maximum - urls.count) }
    private var bizType: String {
        let destination: RetainedImageScope.Destination = kind == .cover ? .topicCover : .topicGallery
        return destination.uploadBizType ?? "image_free"
    }
    private var aspect: (width: Int, height: Int) { kind == .cover ? (3, 4) : (16, 9) }

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
                    .font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier(identifier + ".failed")
            } else if uploader == nil {
                Text("fixr10.ap.image.signIn").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task { await upload(items) }
        }
    }

    private var picker: some View {
        PhotosPicker(selection: $picks, maxSelectionCount: selectable, matching: .images) {
            LabeledContent {
                Text(LocalizedStringKey(kind == .cover && !urls.isEmpty ? "fixr10.ap.cover.replace" : "fixr10.ap.image.choose"))
            } label: {
                Label(title, systemImage: kind == .cover ? "photo" : "photo.on.rectangle")
            }
        }
        .disabled(!isEnabled || uploader == nil)
        .accessibilityIdentifier(identifier)
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
            if kind == .cover {
                Text(title)
            } else {
                Text("fixr10.ap.image.item \(index + 1)")
            }
        }
        .accessibilityIdentifier(identifier + ".item." + String(index))
    }

    /// MP chooseImage → uploadAll: uploads in order and keeps only the URLs the server returned.
    private func upload(_ items: [PhotosPickerItem]) async {
        guard let uploader, !uploading else { picks = []; return }
        uploading = true
        failedCount = 0
        failureMessage = nil
        let result = await uploader.upload(items: Array(items.prefix(selectable)), bizType: bizType, aspect: aspect)
        if kind == .cover {
            if let first = result.urls.first { value = first }
        } else {
            value = (urls + result.urls).prefix(maximum).joined(separator: ",")
        }
        failedCount = result.failed
        failureMessage = result.message
        uploading = false
        picks = []
    }
}
