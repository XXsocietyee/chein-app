import SwiftUI
import Observation
import UIKit

@MainActor private func roamStampMetadataScope(_ reader: any RoamExperienceReading) -> UUID? {
    if let reader = reader as? RoamAlbumMetadataReader { return reader.scope }
    return (reader as? RoamReceivedStampReader)?.scope
}
@MainActor private func roamStampIsMetadataOnly(_ reader: any RoamExperienceReading) -> Bool {
    reader is RoamAlbumMetadataReader || reader is RoamReceivedStampReader
}

@MainActor struct RoamStampAlbumView: View {
    let reader: any RoamExperienceReading
    var stampDestination: (() -> AnyView)? = nil
    let readOnlyScope: RoamStampAlbumReadOnlyScope?
    init(reader: any RoamExperienceReading, stampDestination: (() -> AnyView)? = nil, readOnlyScope: RoamStampAlbumReadOnlyScope? = nil) {
        self.stampDestination = stampDestination; self.readOnlyScope = readOnlyScope
        self.reader = reader
    }
    var canShowAlbum: Bool { readOnlyScope?.matches(reader) ?? true }
    /// SALBUM-1: a metadata-scope album still offers the camera when the host passes its session camera destination
    /// (the camera itself stays behind `stampCameraEnabled`); remote images keep the read-only scope's policy.
    var allowsCapture: Bool { (readOnlyScope == nil && !roamStampIsMetadataOnly(reader)) || (readOnlyScope != nil && stampDestination != nil) }
    /// SALBUM-1 (MP-first, owner 2026-11-25): the MP album shows every stamp's `picUrl`
    /// (subpackageP3/pages/stamp-album/index/index.wxml:19-23), so metadata readers show it too.
    var allowsRemoteImages: Bool { readOnlyScope?.allowsRemoteImages ?? true }
    @ViewBuilder var captureDestination: some View {
        if allowsCapture {
            if let stampDestination { stampDestination() } else { AnyView(RoamStampCameraView()) }
        }
    }
    var body: some View {
        if NativeR2Flags.freeExplore {
            // Native r2: same reader, scope and pager; the received-stamp entry is a row inside the album.
            NativeStampAlbumView(album: self).id(RoamAlbumReadOwner(reader: reader, scope: readOnlyScope))
        } else {
            RoamStampAlbumContent(album: self).id(RoamAlbumReadOwner(reader: reader, scope: readOnlyScope))
                .modifier(RoamReceivedStampNavigation(isEntry: !(reader is RoamReceivedStampReader)))
        }
    }
}

/// Exact original reader and optional frozen metadata scope, not new image/capture permission.
struct RoamAlbumReadOwner: Hashable {
    let readerID: ObjectIdentifier
    let identity: RoamExperienceIdentity?
    let metadataScope: UUID?
    let presentationScope: UUID?
    let configured: Bool
    let current: Bool
    @MainActor init(reader: any RoamExperienceReading, scope: RoamStampAlbumReadOnlyScope?) {
        readerID = ObjectIdentifier(reader); identity = reader.identity
        metadataScope = roamStampMetadataScope(reader)
        presentationScope = scope?.id; configured = reader.isConfigured
        current = scope?.matches(reader) ?? true
    }
}

/// Only read intents retire on cover. Source rows and the existing metadata lease survive a push.
@MainActor final class RoamAlbumReadPresentation: ObservableObject {
    let pager: RoamAlbumPager
    let reader: any RoamExperienceReading
    let scope: RoamStampAlbumReadOnlyScope?
    private let owner: RoamAlbumReadOwner
    @Published private var revision = 0
    @Published private(set) var loading = false
    private var mounted = false
    private var foreground = false
    private var needsAppearanceRead = false
    private var operation = UUID()
    private var work: Task<Void, Never>?
    init(reader: any RoamExperienceReading, scope: RoamStampAlbumReadOnlyScope?) {
        self.reader = reader; self.scope = scope; owner = .init(reader: reader, scope: scope)
        let albumReader: any RoamExperienceReading
        if let scope { albumReader = scope } else { albumReader = reader }
        // SALBUM-6: the album page asks for 50, the same size the mini-program sends.
        pager = .init(reader: albumReader, pageSize: StampAlbumIndexPageModel.sourcePageSize)
    }
    var isCurrent: Bool {
        owner == RoamAlbumReadOwner(reader: reader, scope: scope) && (scope?.matches(reader) ?? true)
    }
    func appear(foreground: Bool) {
        mounted = true; self.foreground = foreground; needsAppearanceRead = true; retire()
        readOnAppearance()
    }
    func disappear() { mounted = false; needsAppearanceRead = false; retire() }
    func setForeground(_ value: Bool) {
        guard foreground != value else { return }
        foreground = value; retire(); readOnAppearance()
    }
    private func readOnAppearance() {
        // Defer an initial inactive mount, but never refresh a hidden parent or revive a retired lease.
        guard mounted, foreground, needsAppearanceRead, isCurrent else { return }
        readAction(refresh: true)()
    }
    private func retire() {
        operation = UUID(); work?.cancel(); work = nil
        pager.cancelPending(); loading = false; revision &+= 1
    }
    private func accepts(_ offered: UUID) -> Bool {
        mounted && foreground && isCurrent && operation == offered && !Task.isCancelled
    }
    private func begin(_ offered: UUID, refresh: Bool) -> UUID? {
        guard accepts(offered), refresh || (!loading && pager.hasMore) else { return nil }
        operation = UUID(); work?.cancel(); work = nil
        if refresh { pager.reset() }
        loading = true; return operation
    }
    func readAction(refresh: Bool = false) -> () -> Void {
        let offered = operation
        return { [weak self] in
            guard let self, let issued = self.begin(offered, refresh: refresh) else { return }
            self.work = Task { [weak self] in
                guard let self else { return }
                await self.read(issued: issued)
            }
        }
    }
    func refreshAction() -> () async -> Void {
        let offered = operation
        return { [weak self] in
            guard let self, let issued = self.begin(offered, refresh: true) else { return }
            await self.read(issued: issued)
        }
    }
    private func read(issued: UUID) async {
        guard operation == issued else { return }
        guard accepts(issued) else { retire(); return }
        needsAppearanceRead = false
        await pager.loadNext()
        guard operation == issued else { return }
        guard accepts(issued) else {
            if !isCurrent { pager.reset() }
            retire(); return
        }
        loading = false; work = nil; operation = UUID(); revision &+= 1
    }
}

@MainActor private struct RoamStampAlbumContent: View {
    let album: RoamStampAlbumView
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.collectionAlbumHosted) private var hosted
    /// SALBUM-3: the 收集册 collage, except at accessibility sizes where the readable card grid stays.
    private var collage: Bool { hosted && !dynamicTypeSize.isAccessibilitySize }
    @Environment(\.cyPalette) private var palette
    @Namespace private var hero
    @StateObject private var presentation: RoamAlbumReadPresentation
    init(album: RoamStampAlbumView) {
        self.album = album
        _presentation = StateObject(wrappedValue: .init(reader: album.reader, scope: album.readOnlyScope))
    }
    private var reader: any RoamExperienceReading { album.reader }
    private var readOnlyScope: RoamStampAlbumReadOnlyScope? { album.readOnlyScope }
    private var canShowAlbum: Bool { album.canShowAlbum }
    private var allowsCapture: Bool { album.allowsCapture }
    private var allowsRemoteImages: Bool { album.allowsRemoteImages }
    private var captureDestination: some View { album.captureDestination }
    private var pager: RoamAlbumPager { presentation.pager }
    var body: some View {
        let read = presentation.readAction(), refresh = presentation.refreshAction()
        // subpackageP3/pages/stamp-album/index page model: an unknown total is an em dash, never a guessed 0.
        let page = StampAlbumIndexPageModel.project(pager)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                if canShowAlbum {
                // Inside 收集册 (B62) the head carries the title; the standalone album keeps its cover.
                if !hosted { RoamStampAlbumCover(total: pager.total, loaded: pager.loaded) }
                RoamExperienceNotice(offline: reader.isOfflineExample)
                if !hosted, !pager.stamps.isEmpty {
                    RoamStampAlbumPages(stamps: Array(pager.stamps.prefix(6)), offline: reader.isOfflineExample, allowsRemoteImages: allowsRemoteImages)
                }
                switch page.phase {
                case .ready, .unknown: StampAlbumTotalHeader(text: page.totalText)
                case .loading:
                    // A next-page read keeps the headline that was already read.
                    if pager.loaded, let total = pager.total, total > 0 { StampAlbumTotalHeader(text: String(total)) }
                case .empty, .error: EmptyView()
                }
                if let error = pager.error {
                    switch StampAlbumErrorPresentation.resolve(error: error, hasStamps: !pager.stamps.isEmpty) {
                    case .denied: StampAlbumDeniedNotice()
                    case .retryContinuation: EmptyView() // rendered after the stamps, below
                    case .signIn, .retryWholePage: RoamExperienceIssue(error: error, retry: read)
                    }
                }
                if page.phase == .unknown && pager.stamps.isEmpty && pager.error == nil {
                    Label("stampAlbum.unknownDetail", systemImage: "questionmark.circle")
                        .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                        .accessibilityIdentifier("roam.experience.album.unknown")
                } else if pager.loaded && pager.stamps.isEmpty {
                    // B63: mini-program cy-empty 还没有邮票 + 打开集邮相机, no extra line.
                    CYEmptyState(systemImage: "rectangle.stack", "roam.experience.albumEmpty")
                        .accessibilityIdentifier("roam.experience.album.empty")
                    if allowsCapture {
                        NavigationLink { captureDestination } label: { Label("stampAlbum.openCamera", systemImage: "camera") }
                            .buttonStyle(.cyDomainPrimary(fullWidth: false)).frame(maxWidth: .infinity).frame(minHeight: 44)
                            .accessibilityIdentifier("roam.experience.album.openCamera")
                    }
                }
                LazyVGrid(columns: collage ? Array(repeating: GridItem(.flexible(), spacing: CYSpacing.sm), count: 4)
                                           : CYCollectionGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize),
                          alignment: .leading, spacing: collage ? CYSpacing.sm : CYCollectionGrid.spacing) {
                    ForEach(Array(pager.stamps.enumerated()), id: \.element.id) { index, stamp in
                        NavigationLink {
                            RoamStampDetailView(stamp: stamp, offline: reader.isOfflineExample, readOnlyScope: readOnlyScope, allowsRemoteImages: allowsRemoteImages)
                                .cyHeroDestination(stamp.id, in: hero)
                        } label: {
                            Group {
                                if collage {
                                    // SALBUM-3 (MP stamp-album wxml:18-23): image-only stamps, 4 across, tilted up to ±12°.
                                    // The push keeps the hero zoom, the native form of the MP fly-to-centre.
                                    RoamStampCollageTile(stamp: stamp, offline: reader.isOfflineExample, allowsRemoteImages: allowsRemoteImages)
                                        // N-ALBUM (r10): plain grid tiles, no tilt.
                                        .modifier(RoamStampPerforatedTile(seed: stamp.id, enabled: true, maxTilt: 0))
                                        .accessibilityLabel(Text("stampAlbum.openStamp \(index + 1)"))
                                } else {
                                    RoamStampCard(stamp: stamp, offline: reader.isOfflineExample, allowsRemoteImages: allowsRemoteImages, kit: true)
                                        .modifier(RoamStampPerforatedTile(seed: stamp.id, enabled: hosted, maxTilt: 0))
                                }
                            }
                                .cyNewPulse(CYAlbumRecency.isNew(stamp.createTime), text: Text(verbatim: ChannelCopy.text("新", "New", locale: locale)))
                                .cyHeroSource(stamp.id, in: hero)
                        }.buttonStyle(QuestifyCardButtonStyle()).accessibilityIdentifier("roam.experience.album.stamp")
                            .onAppear { requestNextPageIfLast(index) }
                    }
                }
                if let error = pager.error, StampAlbumErrorPresentation.resolve(error: error, hasStamps: !pager.stamps.isEmpty) == .retryContinuation {
                    StampAlbumContinuationRetry(retry: read)
                }
                if presentation.loading {
                    CYSkeleton().accessibilityLabel(Text(pager.stamps.isEmpty ? "roam.loading" : "stampAlbum.loadingNext"))
                }
                if pager.hasMore && !presentation.loading && pager.loaded {
                    Button("roam.experience.loadMore", action: read)
                        .buttonStyle(CYPillButtonStyle(style: .secondary))
                        .accessibilityIdentifier("roam.experience.album.more")
                }
                } else { RoamStampReadOnlyUnavailable() }
            }.padding()
        }.cyDomainPageBackground()
            .cyAlbumChildTitle("roam.experience.album")
            .cyHideTabBar()
            .toolbar {
                if allowsCapture, !hosted {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { captureDestination } label: { Label("media.stamp.title", systemImage: "camera") }
                    }
                } else if hosted, allowsCapture, canShowAlbum, (pager.total ?? pager.stamps.count) > 0 {
                    // N-ALBUM (r10): the camera is a toolbar item, not a floating shadowed + (MP stamp-album al-fab).
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { captureDestination } label: { Label("stampAlbum.openCamera", systemImage: "camera") }
                            .accessibilityIdentifier("roam.experience.album.fab")
                    }
                }
            }
            .onAppear { presentation.appear(foreground: scenePhase == .active) }
            .onChange(of: scenePhase) { _, phase in presentation.setForeground(phase == .active) }
            .refreshable { await refresh() }
            .onDisappear { presentation.disappear() }
            .accessibilityIdentifier("roam.experience.album")
    }

    /// The last tile that is on screen asks the existing album reader for the next page.
    /// A failed page leaves the stamps in place; the continuation copy below is the retry.
    private func requestNextPageIfLast(_ index: Int) {
        guard canShowAlbum, index == pager.stamps.count - 1 else { return }
        guard pager.loaded, pager.hasMore, pager.error == nil, !presentation.loading else { return }
        presentation.readAction()()
    }
}
/// B62 stamp look inside 收集册: a white perforated edge and a small per-stamp tilt (deterministic from the id).
struct RoamStampPerforatedTile: ViewModifier {
    let seed: Int
    let enabled: Bool
    /// Largest tilt in degrees either way (the 收集册 collage uses the MP ±12°).
    var maxTilt: Int = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var angle: Double { reduceMotion ? 0 : Double(abs(seed &* 37) % (maxTilt * 2 + 1) - maxTilt) }
    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(CYSpacing.sm)
                .background(RoamStampPerforation().fill(Color.white, style: FillStyle(eoFill: true)))
                .rotationEffect(.degrees(angle))
                .padding(CYSpacing.sm)
        } else {
            content
        }
    }
}

/// SALBUM-3: the collage cell is the stamp photo alone (4:5, the camera crop), no caption or number.
private struct RoamStampCollageTile: View {
    let stamp: RoamAlbumStamp
    let offline: Bool
    let allowsRemoteImages: Bool
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Color.clear
            .aspectRatio(0.8, contentMode: .fit)
            .overlay {
                if !offline, allowsRemoteImages, let url = QuestifyCardArtwork.safeURL(stamp.picUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { palette.bgRaised }
                    }
                } else {
                    CYCoverArt(seed: String(stamp.id), symbol: "building.2.crop.circle.fill", cornerRadius: 0)
                }
            }
            .clipped()
    }
}

/// Rectangle with half-circle notches along every edge (stamp perforation), filled even-odd.
struct RoamStampPerforation: Shape {
    var radius: CGFloat = 3
    var step: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        func notch(_ x: CGFloat, _ y: CGFloat) { path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)) }
        var x = rect.minX + step / 2
        while x < rect.maxX { notch(x, rect.minY); notch(x, rect.maxY); x += step }
        var y = rect.minY + step / 2
        while y < rect.maxY { notch(rect.minX, y); notch(rect.maxX, y); y += step }
        return path
    }
}

/// Album cover: gold seal ring counting up to the collection size, the one visible title, one honest line.
/// Every stamp in the album is already earned, so the seal is full once the total is known and a dash before that.
private struct RoamStampAlbumCover: View {
    let total: Int?
    let loaded: Bool
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var sentence: String {
        if let total, total > 0 { return ChannelCopy.text("已集齐 \(total) 枚城市印章", "\(total) city stamps collected", locale: locale) }
        if loaded { return ChannelCopy.text("还没有印章，去城市里盖第一枚吧", "No stamps yet. Go collect the first one.", locale: locale) }
        return ChannelCopy.text("正在翻开集章册", "Opening the album", locale: locale)
    }
    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.lg) {
            CYAlbumProgressRing(value: total ?? 0, total: total, size: 88, accessibilityLabel: Text(verbatim: sentence))
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("roam.experience.album")
                    .cyText(.display).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: sentence)
                    .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyHeroScreen()
    }
}

/// "Recently collected": the newest stamps as album pages that turn on their spine; each page flips to its details.
private struct RoamStampAlbumPages: View {
    let stamps: [RoamAlbumStamp]
    let offline: Bool
    let allowsRemoteImages: Bool
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: ChannelCopy.text("最近集到", "Recently collected", locale: locale))
                .cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            CYAlbumPager(items: stamps, height: 300, pageLabel: { page, count in
                Text(verbatim: ChannelCopy.text("第 \(page) 页，共 \(count) 页", "Page \(page) of \(count)", locale: locale))
            }) { stamp in
                RoamStampAlbumPage(stamp: stamp, offline: offline, allowsRemoteImages: allowsRemoteImages)
            }
        }
        .accessibilityIdentifier("roam.experience.album.pages")
    }
}

/// One album page. Front: the stamp picture with its caption over a bottom gradient. Back: number, date, caption.
private struct RoamStampAlbumPage: View {
    let stamp: RoamAlbumStamp
    let offline: Bool
    let allowsRemoteImages: Bool
    @State private var flipped = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var number: String { String(format: "NO. %04d", stamp.id % 10000) }
    private var day: String? { stamp.createTime.map { String($0.prefix(10)) } }
    var body: some View {
        CYFlipCard(flipped: $flipped, flipActionTitle: Text(verbatim: ChannelCopy.text("翻面", "Flip", locale: locale))) {
            front
        } back: {
            back
        }
        .cyNewPulse(CYAlbumRecency.isNew(stamp.createTime), text: Text(verbatim: ChannelCopy.text("新", "New", locale: locale)))
    }
    private var front: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if offline { CYCoverArt(seed: String(stamp.id), symbol: "seal.fill", showsDebugLabel: false, cornerRadius: CYRadius.lg) }
                else if allowsRemoteImages { RoamStampImage(source: stamp.picUrl) }
                else { Label("roam.experience.imageUnavailable", systemImage: "photo").cyText(.meta).foregroundStyle(palette.textSecondary) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            // SALBUM-8: 示例插图 only for the offline example; a real stamp is its photo.
            .accessibilityLabel(offline ? Text("roam.experience.sampleArt") : Text("roam.experience.stampImage"))
            LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                if let caption = stamp.caption, !caption.isEmpty {
                    Text(verbatim: caption).cyText(.cardTitle).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.leading)
                }
                Text(verbatim: number).cyText(.caption).monospaced().foregroundStyle(.white.opacity(0.82))
            }
            .padding(CYSpacing.lg)
        }
        .cyFoilSheen(trigger: flipped ? 0 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(verbatim: ChannelCopy.text("双击翻面查看详情", "Double-tap to flip for details", locale: locale)))
    }
    private var back: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                CYStatusChip("roam.experience.cityStamp", systemImage: "seal.fill")
                Spacer(minLength: CYSpacing.sm)
                Text(verbatim: number).cyText(.caption).monospaced().foregroundStyle(palette.textTertiary)
            }
            Divider()
            if let day { CYFactRow(label: Text(verbatim: ChannelCopy.text("盖章日期", "Collected on", locale: locale)), value: day) }
            CYFactRow(label: Text(verbatim: ChannelCopy.text("编号", "Number", locale: locale)), value: number)
            if let caption = stamp.caption, !caption.isEmpty {
                Text(verbatim: caption).cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text(verbatim: ChannelCopy.text("轻点翻回正面", "Tap to turn back", locale: locale))
                .cyText(.caption).foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyAlbumCard(padding: CYSpacing.lg)
    }
}

struct RoamStampCard: View {
    let stamp: RoamAlbumStamp
    let offline: Bool
    var allowsRemoteImages = true
    /// Album list uses the kit chip. The detail page keeps the previous label.
    var kit = false
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if kit { compact } else { full }
    }
    /// Collection cell: same footprint and elevation as the badge-wall tile (art on top, name, meta).
    private var compact: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Group {
                if offline { CYCoverArt(seed: String(stamp.id), symbol: "building.2.crop.circle.fill", cornerRadius: CYRadius.md).frame(height: 112) }
                else if allowsRemoteImages { RoamStampImage(source: stamp.picUrl).frame(maxHeight: 112).clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)) }
                else { Label("roam.experience.imageUnavailable", systemImage: "photo").cyText(.meta) }
            }.accessibilityLabel(offline ? Text("roam.experience.sampleArt") : Text("roam.experience.stampImage"))
            if let caption = stamp.caption, !caption.isEmpty {
                Text(verbatim: caption).cyText(.bodyMedium).foregroundStyle(palette.textPrimary).lineLimit(typeSize.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
            }
            Text(verbatim: String(format: "NO. %04d", stamp.id % 10000)).cyText(.caption).monospaced().foregroundStyle(palette.textTertiary)
            if let date = stamp.createTime { Text(verbatim: String(date.prefix(10))).cyText(.meta).foregroundStyle(palette.textSecondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(CYSpacing.md)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private var full: some View {
        RoamExperienceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    if kit {
                        CYStatusChip("roam.experience.cityStamp", systemImage: "envelope.badge")
                    } else {
                        Image(systemName: "envelope.badge").accessibilityHidden(true)
                        Text("roam.experience.cityStamp").cyText(.meta).bold()
                    }
                    Spacer()
                    Text(verbatim: String(format: "NO. %04d", stamp.id % 10000)).cyText(.caption, monospacedDigit: true)
                }
                if offline {
                    ZStack {
                        if kit { CYCoverArt(seed: String(stamp.id), symbol: "building.2.crop.circle.fill", cornerRadius: 12) }
                        else {
                            RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.13))
                            Image(systemName: "building.2.crop.circle").font(.largeTitle).imageScale(.large).foregroundStyle(Color.accentColor)
                        }
                    }.frame(height: 140).accessibilityLabel(Text("roam.experience.sampleArt"))
                } else if allowsRemoteImages { RoamStampImage(source: stamp.picUrl) }
                else { Label("roam.experience.imageUnavailable", systemImage: "photo") }
                if let caption = stamp.caption, !caption.isEmpty { Text(verbatim: caption).cyText(.sectionTitle).multilineTextAlignment(.leading) }
                if let date = stamp.createTime { Text(verbatim: date.replacingOccurrences(of: "T", with: " ")).cyText(.meta).foregroundStyle(.secondary) }
            }
        }
    }
}
private struct RoamStampImage: View {
    let source: String
    var body: some View {
        if let url = URL(string: source), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else if phase.error != nil { Label("roam.experience.imageUnavailable", systemImage: "photo.badge.exclamationmark") }
                else { ProgressView("roam.loading") }
            }.frame(maxWidth: .infinity, minHeight: 100, maxHeight: 240).accessibilityLabel(Text("roam.experience.stampImage"))
        } else { Label("roam.experience.imageUnavailable", systemImage: "photo") }
    }
}
@MainActor struct RoamStampDetailView: View {
    let stamp: RoamAlbumStamp
    let offline: Bool
    var readOnlyScope: RoamStampAlbumReadOnlyScope? = nil
    var allowsRemoteImages = true
    var canShowStamp: Bool { readOnlyScope?.isCurrent ?? true }
    /// N-ALBUM (r10): the stamp detail as an inset-grouped List: an image row, then LabeledContent
    /// (MP subpackageP3/stamp-album/index/index.wxml detail: photo, caption, number, date). No flip, foil or gradient.
    var body: some View {
        List {
            if canShowStamp {
                RoamExperienceNotice(offline: offline)
                Section {
                    if offline {
                        Image(systemName: "building.2.crop.circle").font(.largeTitle).imageScale(.large)
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .accessibilityLabel(Text("roam.experience.sampleArt"))
                    } else if allowsRemoteImages && (readOnlyScope?.allowsRemoteImages ?? true) {
                        RoamStampImage(source: stamp.picUrl)
                    } else {
                        Label("roam.experience.imageUnavailable", systemImage: "photo")
                    }
                    if let caption = stamp.caption, !caption.isEmpty {
                        Text(verbatim: caption).font(.headline).multilineTextAlignment(.leading)
                    }
                    LabeledContent {
                        Text(verbatim: String(format: "NO. %04d", stamp.id % 10000)).monospacedDigit()
                    } label: {
                        Label("roam.experience.cityStamp", systemImage: "envelope.badge")
                    }
                    if let date = stamp.createTime {
                        Text(verbatim: date.replacingOccurrences(of: "T", with: " ")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else { RoamStampReadOnlyUnavailable() }
        }
        .listStyle(.insetGrouped)
        .cyPageTitle("roam.experience.cityStamp").cyHideTabBar()
        .cyDomainScreen(.player)
    }
}
struct RoamCityStampDraftView: View {
    let offline: Bool
    @State private var draft = RoamCityStampDraft()
    @State private var review = false
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoamExperienceNotice(offline: offline)
                RoamExperienceCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("roam.experience.draftOnly", systemImage: "pencil.and.outline").cyText(.meta).foregroundStyle(.secondary)
                        Image(systemName: "camera.metering.none").font(.largeTitle).imageScale(.large).foregroundStyle(.tint).frame(maxWidth: .infinity).padding()
                            .accessibilityHidden(true)
                        TextField("roam.experience.caption", text: $draft.caption, axis: .vertical)
                            .lineLimit(2...5).textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("roam.experience.stamp.caption")
                        LabeledContent("roam.experience.remaining", value: String(draft.remaining)).cyText(.meta).monospacedDigit()
                        if !draft.canReview { Label("roam.experience.captionLimit", systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                        Button("roam.experience.previewDraft") { withAnimation(reduceMotion ? nil : QuestifyMotion.content) { review = true } }
                            .buttonStyle(.questifyPrimary).disabled(!draft.canReview)
                            .accessibilityIdentifier("roam.experience.stamp.preview")
                        if review {
                            Divider()
                            Text("roam.experience.localPreview").cyText(.meta).bold()
                            if draft.caption.isEmpty { Text("roam.experience.captionEmpty").foregroundStyle(.secondary) }
                            else { Text(verbatim: draft.caption).cyText(.sectionTitle) }
                        }
                    }
                }
                Label("roam.experience.mediaUnavailable", systemImage: "camera.fill")
                Text("roam.experience.stampHint").cyText(.body).foregroundStyle(.secondary)
            }.padding()
        }.cyPageTitle("roam.experience.cityStamp")
            .cyHideTabBar()
            .onChange(of: draft.caption) { _, _ in review = false }
            .accessibilityIdentifier("roam.experience.stamp.draft")
        .cyDomainScreen(.player)
    }
}


/// SwiftUI retains this owner for the logical page while a child destination covers it.
final class RoamAlbumPageOwner: ObservableObject {}

/// A frozen view-only album scope. It delegates the existing album read and no other capability.
@MainActor @Observable final class RoamStampAlbumReadOnlyScope: RoamExperienceReading {
    private let base: any RoamExperienceReading
    private let readerID: ObjectIdentifier
    private let expected: RoamExperienceIdentity
    private let presentationIsCurrent: () -> Bool
    private let metadataScope: UUID?
    @ObservationIgnored private weak var pageOwner: RoamAlbumPageOwner?
    private var pageOwnerWasBound = false
    private var retired = false
    let id = UUID()
    init(reader: any RoamExperienceReading, identity: RoamExperienceIdentity,
         isCurrent: @escaping () -> Bool) {
        base = reader; readerID = ObjectIdentifier(reader); expected = identity; presentationIsCurrent = isCurrent
        metadataScope = roamStampMetadataScope(reader)
    }
    var isCurrent: Bool {
        !retired && (!pageOwnerWasBound || pageOwner != nil) && presentationIsCurrent() && base.identity == expected &&
        roamStampMetadataScope(base) == metadataScope
    }
    /// SALBUM-1 (MP-first): stamp `picUrl` is shown as in the MP album.
    var allowsRemoteImages: Bool { true }
    var hasPageOwner: Bool { pageOwnerWasBound && pageOwner != nil }
    func bind(to owner: RoamAlbumPageOwner) {
        if pageOwnerWasBound {
            if pageOwner !== owner { retire() }
            return
        }
        pageOwner = owner; pageOwnerWasBound = true
    }
    func retire() { retired = true }
    func matches(_ reader: any RoamExperienceReading) -> Bool { ObjectIdentifier(reader) == readerID && isCurrent }
    var identity: RoamExperienceIdentity? { isCurrent ? expected : nil }
    var isConfigured: Bool { isCurrent && base.isConfigured }
    var isOfflineExample: Bool { base.isOfflineExample }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage {
        guard isCurrent, !Task.isCancelled else { throw CancellationError() }
        guard base.isConfigured else { throw APIError.notConfigured }
        let result = try await base.album(page: page, pageSize: pageSize)
        guard isCurrent, !Task.isCancelled else { throw CancellationError() }
        return result
    }
    func history() throws -> [RoamHistoryRecord] { throw APIError.notConfigured }
    func localWalkStatus() throws -> RoamLocalWalkStatus { throw APIError.notConfigured }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact { throw APIError.notConfigured }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage { throw APIError.notConfigured }
    func shopBadge() async throws -> RoamShopBadge? { throw APIError.notConfigured }
}
private struct RoamStampReadOnlyUnavailable: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Text(verbatim: locale.language.languageCode?.identifier == "zh"
             ? "此集邮册已不属于当前查看会话。请返回后重新打开。"
             : "This album is no longer part of the current viewing session. Go back and open it again.")
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("roam.experience.album.scopeExpired")
    }
}


/// Stable whole-page read scope. Only metadata is loaded; remote pictures and capture stay absent.
@MainActor struct RoamAlbumMetadataDestination: View {
    let reader: RoamAlbumMetadataReader
    var stampDestination: (() -> AnyView)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var scope: RoamStampAlbumReadOnlyScope?
    @StateObject private var pageOwner = RoamAlbumPageOwner()
    @State private var mounted = false
    init(reader: RoamAlbumMetadataReader, scope: RoamStampAlbumReadOnlyScope? = nil, stampDestination: (() -> AnyView)? = nil) {
        self.reader = reader; _scope = State(initialValue: scope); self.stampDestination = stampDestination
    }
    var body: some View {
        Group {
            if let scope {
                RoamStampAlbumView(reader: reader, stampDestination: stampDestination, readOnlyScope: scope)
                    .background { RoamAlbumMetadataLifetime(scope: scope).id(scope.id) }
            } else if reader.identity == nil {
                RoamExperienceIssue(error: APIError.unauthorized)
            } else { ProgressView("roam.loading") }
        }
        .onAppear { mounted = true; attachIfVisible() }
        .onDisappear { mounted = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { scope?.retire() } else { attachIfVisible() }
        }
    }
    private func attachIfVisible() {
        guard mounted, scenePhase == .active else { return }
        if let scope { scope.bind(to: pageOwner); return }
        guard let identity = reader.identity else { return }
        let fresh = RoamStampAlbumReadOnlyScope(reader: reader, identity: identity, isCurrent: { true })
        fresh.bind(to: pageOwner); scope = fresh
    }
}

/// A child detail can cover this page. Removing the page's attachment retires only its own scope.
@MainActor struct RoamAlbumMetadataLifetime: UIViewControllerRepresentable {
    let scope: RoamStampAlbumReadOnlyScope
    func makeUIViewController(context: Context) -> Controller { Controller(scope: scope) }
    func updateUIViewController(_ controller: Controller, context: Context) {}
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        // A covered page can lose this rendering attachment while its StateObject lives.
        // Once the logical page leaves, its weak owner expires and the scope rejects reads.
        if !controller.scope.hasPageOwner { controller.scope.retire() }
    }
    @MainActor final class Controller: UIViewController {
        let scope: RoamStampAlbumReadOnlyScope
        init(scope: RoamStampAlbumReadOnlyScope) { self.scope = scope; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { return nil }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard !scope.hasPageOwner else { return }
            var current: UIViewController? = self
            while let value = current {
                if value.isBeingDismissed || value.isMovingFromParent { scope.retire(); return }
                current = value.parent
            }
        }
    }
}
