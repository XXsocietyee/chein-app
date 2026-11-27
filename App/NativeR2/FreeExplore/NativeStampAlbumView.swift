import SwiftUI

/// Native r2 stamp album (集邮册), in MP `scene-roam-stamp-album` order: the 收到的 entry (MP 我的 / 收到的 tabs),
/// 共 N 枚, a `LazyVGrid` of circular stamp images with captions ending in the dashed 还没收到 cell, the
/// 每投一张换来的那张 line, then paging states. Reads, paging, scopes and capture rules are `RoamStampAlbumView`'s: the same
/// `RoamAlbumReadPresentation` pager (50 per page), the same read-only scope and remote-image policy.
@MainActor struct NativeStampAlbumView: View {
    let album: RoamStampAlbumView
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.roamReceivedStampReader) private var receivedReader
    @StateObject private var presentation: RoamAlbumReadPresentation
    @State private var receivedTarget: ReceivedTarget?

    private struct ReceivedTarget: Hashable { let id = UUID(); let owner: RoamAlbumReadOwner }

    init(album: RoamStampAlbumView) {
        self.album = album
        _presentation = StateObject(wrappedValue: .init(reader: album.reader, scope: album.readOnlyScope))
    }

    private var reader: any RoamExperienceReading { album.reader }
    private var pager: RoamAlbumPager { presentation.pager }
    private var offline: Bool { reader.isOfflineExample }
    private var stamps: [RoamAlbumStamp] { pager.stamps }

    var body: some View {
        let read = presentation.readAction(), refresh = presentation.refreshAction()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if album.canShowAlbum {
                    header
                    content(read: read)
                } else {
                    ContentUnavailableView("nativeR2.freeExplore.album.scopeExpired", systemImage: "clock.arrow.circlepath")
                        .accessibilityIdentifier("roam.experience.album.scopeExpired")
                }
            }
            .padding()
        }
        .cyAlbumChildTitle("roam.experience.album")
        .toolbar {
            if album.allowsCapture, album.canShowAlbum {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { album.captureDestination } label: { Label("media.stamp.title", systemImage: "camera") }
                        .accessibilityIdentifier("roam.experience.album.fab")
                }
            }
        }
        .navigationDestination(item: $receivedTarget) { target in
            if let receivedReader, target.owner == RoamAlbumReadOwner(reader: receivedReader, scope: nil) {
                RoamReceivedStampMetadataDestination(reader: receivedReader, owner: target.owner)
            } else {
                ContentUnavailableView("nativeR2.freeExplore.album.exchangeChanged", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .onAppear { presentation.appear(foreground: scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in presentation.setForeground(phase == .active) }
        .onChange(of: receivedReader.map { RoamAlbumReadOwner(reader: $0, scope: nil) }) { _, _ in receivedTarget = nil }
        .refreshable { await refresh() }
        .onDisappear { presentation.disappear() }
        .accessibilityIdentifier("roam.experience.album")
    }

    // MARK: Header (MP scene-roam-stamp-album order: 我的 / 收到的 head, then 共 N 枚)

    @ViewBuilder private var header: some View {
        if offline {
            Label("roam.experience.offline", systemImage: "testtube.2")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("roam.experience.notice")
        }
        // MP `cy-tabs` 我的 / 收到的: this page is 我的; 收到的 opens the received list (its own reader and scope).
        // mp-roam r3: the native-only 全部 / 邮票 / 照片 kind filter is removed (the MP has no such filter).
        exchangeRow
        if pager.loaded, let total = pager.total {
            LabeledContent {
                Text("stampAlbum.total \(total)").monospacedDigit().contentTransition(.numericText())
            } label: {
                Text("roam.experience.album")
            }
            .accessibilityIdentifier("roam.experience.album.total")
        }
    }

    /// The received-stamp entry (`RoamReceivedStampNavigation`), as one plain row instead of a material banner.
    @ViewBuilder private var exchangeRow: some View {
        if !(reader is RoamReceivedStampReader), let receivedReader {
            let offered = RoamAlbumReadOwner(reader: receivedReader, scope: nil)
            let canOpen = receivedReader.identity != nil && receivedReader.isConfigured
            Button {
                guard offered == RoamAlbumReadOwner(reader: receivedReader, scope: nil), receivedReader.identity != nil,
                      receivedReader.isConfigured, receivedTarget == nil else { return }
                receivedTarget = ReceivedTarget(owner: offered)
            } label: {
                LabeledContent {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                } label: {
                    Label("nativeR2.freeExplore.album.exchange", systemImage: "arrow.left.arrow.right")
                }
            }
            .tint(.primary)
            .disabled(!canOpen)
            .accessibilityIdentifier("roam.receivedMetadata.open")
            if !receivedReader.isConfigured {
                Text(LocalizedStringKey(receivedReader.identity == nil ? "roam.signInRequired" : "roam.notConfigured"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Grid and states

    @ViewBuilder private func content(read: @escaping () -> Void) -> some View {
        let page = StampAlbumIndexPageModel.project(pager)
        if let error = pager.error {
            switch StampAlbumErrorPresentation.resolve(error: error, hasStamps: !pager.stamps.isEmpty) {
            case .denied:
                ContentUnavailableView("stampAlbum.denied", systemImage: "lock")
                    .accessibilityIdentifier("roam.experience.album.denied")
            case .signIn:
                ContentUnavailableView("roam.signInRequired", systemImage: "person.crop.circle")
                    .accessibilityIdentifier("roam.experience.error")
            case .retryWholePage:
                ContentUnavailableView {
                    Label("roam.experience.readFailed", systemImage: "exclamationmark.circle")
                } actions: {
                    Button("action.retry", action: read).buttonStyle(.bordered)
                        .accessibilityIdentifier("roam.experience.retry")
                }
                .accessibilityIdentifier("roam.experience.error")
            case .retryContinuation:
                EmptyView() // below the stamps
            }
        }
        if page.phase == .unknown && pager.stamps.isEmpty && pager.error == nil {
            Label("stampAlbum.unknownDetail", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("roam.experience.album.unknown")
        } else if pager.loaded && pager.stamps.isEmpty && pager.error == nil {
            ContentUnavailableView {
                Label("roam.experience.albumEmpty", systemImage: "photo.on.rectangle")
            } actions: {
                if album.allowsCapture {
                    NavigationLink { album.captureDestination } label: { Label("stampAlbum.openCamera", systemImage: "camera") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("roam.experience.album.openCamera")
                }
            }
            .accessibilityIdentifier("roam.experience.album.empty")
        }
        grid
        if !stamps.isEmpty, !reader.isOfflineExample, !(reader is RoamReceivedStampReader) {
            // MP `album-mini` under the 我的 grid.
            Text("roam.album.mini").font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("roam.experience.album.mini")
        }
        if let error = pager.error, StampAlbumErrorPresentation.resolve(error: error, hasStamps: !pager.stamps.isEmpty) == .retryContinuation {
            StampAlbumContinuationRetry(retry: read).frame(maxWidth: .infinity)
        }
        if presentation.loading {
            ProgressView(LocalizedStringKey(pager.stamps.isEmpty ? "roam.stamps.loading" : "stampAlbum.loadingNext")).frame(maxWidth: .infinity)
        }
        if pager.hasMore && !presentation.loading && pager.loaded {
            Button("roam.experience.loadMore", action: read)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("roam.experience.album.more")
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 16, alignment: .top)], alignment: .center, spacing: 20) {
            ForEach(Array(stamps.enumerated()), id: \.element.id) { index, stamp in
                NavigationLink {
                    RoamStampDetailView(stamp: stamp, offline: offline, readOnlyScope: album.readOnlyScope,
                                        allowsRemoteImages: album.allowsRemoteImages)
                } label: {
                    NativeStampAlbumTile(stamp: stamp, offline: offline, allowsRemoteImages: album.allowsRemoteImages)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.experience.album.stamp")
                .onAppear { requestNextPageIfLast(stamp, index: index) }
            }
            if pager.loaded, !pager.hasMore, !stamps.isEmpty, !(reader is RoamReceivedStampReader) {
                // MP `stkcell--lock`: the dashed last cell 还没收到 once 我的 is read to the end (not a loading state).
                NativeStampAlbumLockTile()
            }
        }
    }

    /// The last tile on screen asks the same pager for the next page; a failed page keeps the stamps in place.
    private func requestNextPageIfLast(_ stamp: RoamAlbumStamp, index: Int) {
        guard album.canShowAlbum, index == stamps.count - 1 else { return }
        guard pager.loaded, pager.hasMore, pager.error == nil, !presentation.loading else { return }
        presentation.readAction()()
    }
}

/// One circular stamp image with its caption (or date) under it, like a Fitness award.
struct NativeStampAlbumTile: View {
    @Environment(\.locale) private var locale
    let stamp: RoamAlbumStamp
    let offline: Bool
    let allowsRemoteImages: Bool
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 88

    var body: some View {
        VStack(spacing: 8) {
            image
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Group {
                if let caption = stamp.caption, !caption.isEmpty {
                    Text(verbatim: caption)
                } else if let date = stamp.createTime {
                    Text(verbatim: LocaleDisplay.civil(String(date.prefix(10)), locale: locale))
                } else {
                    Text("roam.experience.cityStamp")
                }
            }
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var image: some View {
        if !offline, allowsRemoteImages, let url = Self.safeURL(stamp.picUrl) {
            AsyncImage(url: url) { phase in
                if let loaded = phase.image {
                    loaded.resizable().scaledToFill()
                } else if phase.error != nil {
                    placeholder(systemImage: "photo.badge.exclamationmark")
                } else {
                    placeholder(systemImage: "photo").redacted(reason: .placeholder)
                }
            }
        } else {
            placeholder(systemImage: offline ? "building.2.crop.circle" : "photo")
        }
    }

    private func placeholder(systemImage: String) -> some View {
        Circle()
            .fill(.quaternary)
            .overlay { Image(systemName: systemImage).font(.title2).foregroundStyle(.secondary).accessibilityHidden(true) }
    }

    /// Same rule as the old tile: https with a host and no credentials.
    static func safeURL(_ source: String) -> URL? {
        guard let url = URL(string: source), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
}

/// MP `stkcell stkcell--lock`: a dashed circle the size of a stamp tile with 还没收到 under it.
struct NativeStampAlbumLockTile: View {
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 88
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(.tertiary)
                .frame(width: diameter, height: diameter)
                .accessibilityHidden(true)
            Text("roam.album.lockCell").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.experience.album.lock")
    }
}
