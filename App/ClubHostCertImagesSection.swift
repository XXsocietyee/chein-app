import SwiftUI
import PhotosUI

/// CLB-apply-05 (MP pages/club/apply/index.wxml:149-152, index.js:275-360, 401): 资质 / 案例图 on step 4.
/// Up to 9 photos, picked with the system `PhotosPicker`, each uploaded through the shared MP `chooseImage`
/// path (`api/common/uploadOSS`, bizType `image_free`). `certImages` carries the uploaded URLs joined with `,`, as the MP
/// sends `d.certImages.join(',')`. A failed upload is counted in the footer and leaves nothing behind; swipe to remove.
@MainActor struct ClubHostCertImagesSection: View {
    @Binding var urlsText: String
    let disabled: Bool

    @Environment(\.playerContentImageUploader) private var uploader
    @ScaledMetric(relativeTo: .body) private var thumbnailSide: CGFloat = 44
    @State private var picks: [PhotosPickerItem] = []
    @State private var uploading = false
    @State private var failedCount = 0
    @State private var failureMessage: String?

    static let maximumCount = 9

    private var urls: [String] {
        urlsText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private var remaining: Int { max(0, Self.maximumCount - urls.count) }

    var body: some View {
        Section {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, value in
                HStack {
                    AsyncImage(url: URL(string: value)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Image(systemName: "photo").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: thumbnailSide, height: thumbnailSide)
                    .clipped()
                    .accessibilityHidden(true)
                    Text("club.host.cert.item \(index + 1)")
                }
                .accessibilityIdentifier("club.host.cert.item.\(index)")
            }
            .onDelete { offsets in
                var list = urls
                list.remove(atOffsets: offsets)
                urlsText = list.joined(separator: ",")
            }
            .deleteDisabled(disabled || uploading)
            if uploading {
                ProgressView {
                    Text("club.host.cert.uploading")
                }
            } else if remaining > 0 {
                PhotosPicker(selection: $picks, maxSelectionCount: remaining, matching: .images) {
                    Label("club.host.cert.add \(remaining)", systemImage: "photo.badge.plus")
                }
                .disabled(disabled || uploader == nil)
                .accessibilityIdentifier("club.host.cert.add")
            }
        } header: {
            Text("club.host.cert.title \(urls.count) \(Self.maximumCount)")
        } footer: {
            if failedCount > 0 {
                Text("club.host.cert.failed \(failedCount) \(failureMessage ?? "")")
                    .accessibilityIdentifier("club.host.cert.failed")
            } else if uploader == nil {
                Text("club.host.cert.signIn")
            }
        }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            Task { await upload(items) }
        }
    }

    /// MP `addCerts` → `app.chooseImage(…, remain)`: uploads in order and keeps only the URLs the server returned.
    private func upload(_ items: [PhotosPickerItem]) async {
        guard let uploader, !uploading else { picks = []; return }
        uploading = true
        failedCount = 0
        failureMessage = nil
        let result = await uploader.upload(items: Array(items.prefix(remaining)))
        let merged = (urls + result.urls).prefix(Self.maximumCount)
        urlsText = merged.joined(separator: ",")
        failedCount = result.failed
        failureMessage = result.message
        uploading = false
        picks = []
    }
}
