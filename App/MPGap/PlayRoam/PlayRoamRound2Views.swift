import SwiftUI

/// `BWALL-2` / `BWALL-3` (2-col 已点亮/未解锁 badge wall grid),
/// `RPOI-2` / `RPOI-3` / `RPOI-8` (POI detail unified action row, pending check-in recovery, inline gallery),
/// `JREPORT-2` (Node photo viewer), and `OCARDS-2` (Object cards gatherable pile + grid fallback).

public struct BadgeWallTwoColumnGridView: View {
    public let items: [BadgeWallMedalItem]
    public var onSelect: (BadgeWallMedalItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: CYSpacing.md), count: 2)

    public init(items: [BadgeWallMedalItem], onSelect: @escaping (BadgeWallMedalItem) -> Void = { _ in }) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
        let split = BadgeWallGrouping.split(items)
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if !split.unlocked.isEmpty {
                    section(title: "已点亮", medals: split.unlocked)
                }
                if !split.locked.isEmpty {
                    section(title: "未解锁", medals: split.locked)
                }
            }
            .padding(CYSpacing.md)
        }
        .background(CYColor.bgPage)
    }

    @ViewBuilder
    private func section(title: String, medals: [BadgeWallMedalItem]) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(title)
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)

            LazyVGrid(columns: columns, spacing: CYSpacing.md) {
                ForEach(medals) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(spacing: CYSpacing.xs) {
                            Group {
                                if let urlStr = item.imageURL, !urlStr.isEmpty {
                                    CYCachedAsyncImage(urlStr, role: .shelf)
                                } else {
                                    MPAsset.BadgeMedal.medalGold
                                        .resizable()
                                        .scaledToFit()
                                        .padding(CYSpacing.xs)
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .saturation(item.isUnlocked ? 1 : 0)
                            .opacity(item.isUnlocked ? 1 : 0.55)

                            Text(item.title)
                                .cyText(.cardTitle)
                                .foregroundStyle(CYColor.textPrimary)
                                .lineLimit(2)

                            Text(item.familyName)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(CYSpacing.sm)
                        .background(CYColor.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

public struct RoamPOIDetailGapSections: View {
    public let galleryURLs: [String]
    public let isFavorited: Bool
    public let pendingCheckIn: RoamPendingCheckInContext?
    public var onTapGalleryImage: (Int) -> Void = { _ in }
    public var onToggleFavorite: () -> Void = {}
    public var onNavigate: () -> Void = {}
    public var onPostCityStamp: () -> Void = {}
    public var onQueryPendingCheckIn: () -> Void = {}
    public var onRetryOnSiteCheckIn: () -> Void = {}

    public init(
        galleryURLs: [String] = [],
        isFavorited: Bool = false,
        pendingCheckIn: RoamPendingCheckInContext? = nil,
        onTapGalleryImage: @escaping (Int) -> Void = { _ in },
        onToggleFavorite: @escaping () -> Void = {},
        onNavigate: @escaping () -> Void = {},
        onPostCityStamp: @escaping () -> Void = {},
        onQueryPendingCheckIn: @escaping () -> Void = {},
        onRetryOnSiteCheckIn: @escaping () -> Void = {}
    ) {
        self.galleryURLs = galleryURLs
        self.isFavorited = isFavorited
        self.pendingCheckIn = pendingCheckIn
        self.onTapGalleryImage = onTapGalleryImage
        self.onToggleFavorite = onToggleFavorite
        self.onNavigate = onNavigate
        self.onPostCityStamp = onPostCityStamp
        self.onQueryPendingCheckIn = onQueryPendingCheckIn
        self.onRetryOnSiteCheckIn = onRetryOnSiteCheckIn
    }

    public var body: some View {
        VStack(spacing: CYSpacing.md) {
            if !galleryURLs.isEmpty {
                TabView {
                    ForEach(Array(galleryURLs.enumerated()), id: \.offset) { idx, urlStr in
                        if !urlStr.isEmpty {
                            Button {
                                onTapGalleryImage(idx)
                            } label: {
                                CYCachedAsyncImage(urlStr, role: .cover)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(4 / 3, contentMode: .fill)
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .tabViewStyle(.page)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            }

            HStack(spacing: CYSpacing.sm) {
                Button(isFavorited ? "已收藏" : "收藏", systemImage: isFavorited ? "heart.fill" : "heart", action: onToggleFavorite)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("导航", systemImage: "location", action: onNavigate)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("投一张", systemImage: "envelope", action: onPostCityStamp)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }

            if pendingCheckIn != nil {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("roam.poi.pending")
                        .cyText(.cardTitle)
                    HStack(spacing: CYSpacing.sm) {
                        Button("查询当前状态", action: onQueryPendingCheckIn)
                            .buttonStyle(.bordered)
                        Button("重新现场核验", action: onRetryOnSiteCheckIn)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(CYSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CYColor.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }
        }
    }
}

public struct JourneyReportNodePhotoViewerSheet: View {
    public let photos: [JourneyReportNodePhotoItem]
    @State private var selection: Int
    public var onClose: () -> Void

    public init(photos: [JourneyReportNodePhotoItem], initialIndex: Int = 0, onClose: @escaping () -> Void) {
        self.photos = photos
        self._selection = State(initialValue: initialIndex)
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("mp.report.photos.title"), style: .player, onClose: onClose)
            if photos.isEmpty {
                ContentUnavailableView("mp.report.photos.empty", systemImage: "photo")
            } else {
                TabView(selection: $selection) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: CYSpacing.sm) {
                            if !item.photoURL.isEmpty {
                                CYCachedAsyncImage(item.photoURL, role: .cover)
                                    .aspectRatio(contentMode: .fit)
                            }
                            Text(item.nodeName)
                                .cyText(.cardTitle)
                        }
                        .padding(CYSpacing.md)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
            }
        }
    }
}
