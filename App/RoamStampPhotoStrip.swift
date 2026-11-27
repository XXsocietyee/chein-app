import SwiftUI
import UIKit

/// design-r2-roam (P16 / P8): where a roam stamp photo in `RoamHistoryRecord.photos` can be read from.
/// Records migrated from the mini-program keep MP-style paths (`finish.photos[].path`): `wxfile://…`,
/// `http://tmp/…`, `http://usr/…` live only inside WeChat's sandbox and can never be opened here, so they
/// render as a named stamp placeholder instead of a broken image. Native paths are read from the app's own
/// sandbox only (absolute paths under the home directory, `file://` URLs, or paths relative to Documents);
/// `https://` URLs (MP `url` field) load remotely. Nothing is uploaded, copied or cached.
enum RoamStampPhotoSource: Equatable {
    case remote(URL)
    case local(URL)
    case unavailable

    init(_ raw: String) {
        let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = path.lowercased()
        if lower.hasPrefix("https://") {
            if let url = URL(string: path) { self = .remote(url) } else { self = .unavailable }
            return
        }
        // MP sandbox schemes (wxfile://, http://tmp/, http://usr/) and plain http never load here.
        if path.isEmpty || lower.hasPrefix("wxfile://") || lower.hasPrefix("http://") {
            self = .unavailable
            return
        }
        var candidate: URL? = nil
        if lower.hasPrefix("file://") {
            candidate = URL(string: path)
        } else if path.hasPrefix("/") {
            candidate = URL(fileURLWithPath: path)
        } else if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            candidate = documents.appendingPathComponent(path)
        }
        guard let url = candidate, url.isFileURL else { self = .unavailable; return }
        let standardized = url.standardizedFileURL.path
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path
        // Only this app's sandbox; `..` segments cannot escape it.
        guard standardized.hasPrefix(home + "/"), FileManager.default.fileExists(atPath: standardized) else {
            self = .unavailable
            return
        }
        self = .local(URL(fileURLWithPath: standardized))
    }
}

/// One stamp tile: the photo when it can be read, otherwise a quiet stamp placeholder. Local files are read off
/// the main thread and downsampled before they are shown.
@MainActor struct RoamStampPhotoView: View {
    let path: String
    @State private var image: UIImage?

    var body: some View {
        let source = RoamStampPhotoSource(path)
        ZStack {
            Rectangle().fill(CYNight.ink1)
            switch source {
            case .remote(let url):
                AsyncImage(url: url) { phase in
                    if let loaded = phase.image { loaded.resizable().scaledToFill() } else { placeholder }
                }
            case .local:
                if let image { Image(uiImage: image).resizable().scaledToFill().accessibilityHidden(true) } else { placeholder }
            case .unavailable:
                placeholder
            }
        }
        .clipped()
        .task(id: path) {
            guard case .local(let url) = source else { return }
            let data = await Self.read(url)
            guard !Task.isCancelled else { return }
            image = data.flatMap { UIImage(data: $0) }?.preparingThumbnail(of: CGSize(width: 360, height: 480))
        }
    }
    private var placeholder: some View {
        Image(systemName: "seal").font(.title).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
    }
    nonisolated private static func read(_ url: URL) async -> Data? {
        await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
    }
}

/// MP `finish-stamps`: a horizontal strip of this walk's stamps, each with its caption (MP `item.name || '漫游打卡'`;
/// native records carry no per-photo name, so every caption is the MP fallback). Hidden when there are none.
@MainActor struct RoamFinishStampStrip: View {
    let photos: [String]
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 96

    var body: some View {
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("u10.roamFinish.stamps").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                    .accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, path in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                RoamStampPhotoView(path: path)
                                    .frame(width: tileWidth, height: tileWidth * 4 / 3)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                                        .strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                                Text("design.roam.stamp.caption").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                    .frame(width: tileWidth, alignment: .leading)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("design.roam.stamp.caption"))
                            .accessibilityValue(Text("design.roam.stamp.position \(index + 1) \(photos.count)"))
                            .accessibilityIdentifier("roam.finishReport.stamp.\(index)")
                        }
                    }
                }
            }
            .padding(.top, CYSpacing.xl)
            .accessibilityIdentifier("roam.finishReport.stamps")
        }
    }
}
