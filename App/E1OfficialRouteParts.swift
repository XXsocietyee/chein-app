import SwiftUI

/// MP `subpackageRoam/utils/official-route.js` metaText: city · distance (公里) · duration (分钟), skipping blanks.
enum OfficialRouteMeta {
    static func text(_ route: OfficialRoute, chinese: Bool) -> String {
        var distance = OfficialRouteFormat.distance(route.distanceKm)
        if chinese, distance.hasSuffix(" km") { distance = String(distance.dropLast(3)) + " 公里" }
        return [route.city, distance, OfficialRouteFormat.duration(route.totalMinutes, chinese: chinese)]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// MP `official-routes` `.orl-card`: the route's `previewImg` cover when it has one (no default art in the MP),
/// then the name and the meta line.
struct OfficialRouteCard: View {
    let route: OfficialRoute
    let chinese: Bool
    @Environment(\.cyPalette) private var palette

    private var hasCover: Bool { !route.previewImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if hasCover {
                Color.clear.aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay { E1CoverArt(seed: route.name, symbol: "point.topleft.down.to.point.bottomright.curvepath", imageURL: route.previewImage) }
                    .clipped()
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: route.name)
                    .cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                let meta = OfficialRouteMeta.text(route, chinese: chinese)
                if !meta.isEmpty {
                    Text(verbatim: meta).cyText(.meta).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// MP `official-route`: page title = route name (the nav bar), subtitle = meta line, the cover when present,
/// then 节点（N） and the stop rows (tap a located stop → map).
struct OfficialRouteDetailContent: View {
    let detail: OfficialRouteDetail
    let chinese: Bool
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Stops whose `imgUrl` failed to load. The title stays; the tile is not shown again.
    @State private var hiddenNodeImages: Set<String> = []
    private var route: OfficialRoute { detail.route }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                let meta = OfficialRouteMeta.text(route, chinese: chinese)
                if !meta.isEmpty {
                    Text(verbatim: meta).cyText(.meta).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !route.previewImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Color.clear.aspectRatio(dynamicTypeSize.isAccessibilitySize ? 1.0 : 1.6, contentMode: .fit)
                        .overlay { E1CoverArt(seed: route.name, symbol: "point.topleft.down.to.point.bottomright.curvepath", imageURL: route.previewImage) }
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
                        .accessibilityHidden(true)
                }
                stops
            }
            .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm).padding(.bottom, CYSpacing.xxl)
        }
    }

    @ViewBuilder private var stops: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("officialRoute.detail.nodes \(detail.nodes.count)").cyText(.sectionTitle)
                .foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
            if detail.nodes.isEmpty {
                Text("officialRoute.detail.noNodes").foregroundStyle(palette.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(detail.nodes.enumerated()), id: \.element.id) { index, node in
                        nodeRow(node, last: index == detail.nodes.count - 1)
                    }
                }
                .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
            }
        }
    }

    @ViewBuilder private func nodeRow(_ node: OfficialRouteNode, last: Bool) -> some View {
        let body = HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(spacing: 0) {
                Text(verbatim: "\(node.order)").cyText(.numericBody)
                    .foregroundStyle(palette.textInverse).frame(width: 28, height: 28)
                    .background(Circle().fill(palette.textPrimary)).accessibilityHidden(true)
                if !last { Rectangle().fill(palette.borderStrong).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: node.name).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                if !node.address.isEmpty { Text(verbatim: node.address).cyText(.meta).foregroundStyle(palette.textSecondary) }
                if node.stayMinutes > 0 {
                    // MP `.orr-node__sub`: 参考停留 N 分钟 as a plain sub line.
                    Text("officialRoute.detail.stay \(OfficialRouteFormat.duration(node.stayMinutes, chinese: chinese))")
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                }
            }
            .padding(.bottom, last ? 0 : CYSpacing.lg)
            Spacer(minLength: 0)
            // MP `orr-node__img` sits on the trailing side (the map glyph already scales with `.title3`).
            if !hiddenNodeImages.contains(node.id), let thumbURL = OfficialRouteNodeThumb.url(from: node.imageURL) {
                OfficialRouteNodeThumb(url: thumbURL) { hideNodeImage(node.id) }
            }
            if node.latitude != nil {
                Image(systemName: "arrow.up.right.circle").font(.title3).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        if let lat = node.latitude, let lng = node.longitude, let url = OfficialRouteDetailView.mapURL(lat: lat, lng: lng, name: node.name) {
            Link(destination: url) { body }
                .accessibilityLabel(Text("officialRoute.detail.nodeLocation \(node.order) \(node.name)"))
        } else {
            body.accessibilityElement(children: .combine)
                .accessibilityLabel(Text("officialRoute.detail.node \(node.order) \(node.name)"))
        }
    }

    private func hideNodeImage(_ id: String) {
        hiddenNodeImages.insert(id)
    }
}

/// MP `orr-node__img` is 112rpx (56pt) on the trailing side of the stop title.
/// The map glyph on that side already scales with `.title3`, so the tile does too.
/// A blank `imgUrl` or a failed load drops the tile; the stop title stays.
private struct OfficialRouteNodeThumb: View {
    let url: URL
    let onFailure: () -> Void
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 56

    var body: some View {
        PlayerFeedRemoteImage(url: url, maxPixel: 168, placeholder: {
            Color.clear
        }, failure: {
            Color.clear.onAppear(perform: onFailure)
        })
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Same https gate as `E1CoverArt`: anything else is not a remote image this page can show.
    static func url(from imageURL: String) -> URL? {
        let raw = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
