import SwiftUI
import PhotosUI

// r11 account-publish (lane acct): App-side rows for origin/audit/parity-r11-account-publish:docs/audit/parity-r11/account-publish.md §5.

// MARK: - C-F18 story image / album / gallery cells come from the photo library, not typed URLs

/// r11 C-F18: MP pages/publish/fabu/index.js:1515-1540 `insertStoryImageAt` → `app.chooseImage(cb, 1)` (no crop ratio →
/// bizType `image_free`, chengyinhub-xcx app.js:654-685), :1733 `addStoryDreamImage` (album photo) and :2104
/// `fillStoryGalleryCell` all pick one photo, upload it through `getUploadClient().uploadAll` and only then write the
/// returned url into the block. Same upload path as `ProjectEditTopicImageField` (AccountPublishR10Mounts.swift).
/// One url per field; a new pick replaces it. The accessibility id stays on the picker row.
@MainActor struct ProjectEditStoryImageField: View {
    let title: LocalizedStringKey
    @Binding var value: String
    let identifier: String

    @Environment(\.playerContentImageUploader) private var uploader
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var thumbnailSide: CGFloat = 44
    @State private var pick: PhotosPickerItem?
    @State private var uploading = false
    @State private var failedCount = 0
    @State private var failureMessage: String?

    private var trimmed: String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Group {
            if !trimmed.isEmpty { thumbnail }
            if uploading {
                ProgressView { Text("fixr10.ap.image.uploading") }
            } else {
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
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private var picker: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            LabeledContent {
                Text(LocalizedStringKey(trimmed.isEmpty ? "fixr10.ap.image.choose" : "fixr10.ap.cover.replace"))
            } label: {
                Label(title, systemImage: "photo")
            }
        }
        .disabled(!isEnabled || uploader == nil)
        .accessibilityIdentifier(identifier)
    }

    private var thumbnail: some View {
        HStack {
            AsyncImage(url: URL(string: trimmed)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: thumbnailSide, height: thumbnailSide)
            .clipped()
            .accessibilityHidden(true)
            Text(title)
        }
        .accessibilityIdentifier(identifier + ".preview")
    }

    /// MP: upload first, then write the url (fabu/index.js:1512-1514: a failed upload must not leave an empty block).
    private func upload(_ item: PhotosPickerItem) async {
        guard let uploader, !uploading else { pick = nil; return }
        uploading = true
        failedCount = 0
        failureMessage = nil
        let result = await uploader.upload(items: [item], bizType: "image_free")
        if let first = result.urls.first { value = first }
        failedCount = result.failed
        failureMessage = result.message
        uploading = false
        pick = nil
    }
}
