import SwiftUI

/// Image-led route card: cover with duration + distance chips over the art, title on the scrim, city and badge below.
struct OfficialRouteCard: View {
    let route: OfficialRoute
    let chinese: Bool
    @Environment(\.cyPalette) private var palette
    private var copy: String { chinese ? "官方路线" : "Official route" }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay { E1CoverArt(seed: route.name, symbol: "point.topleft.down.to.point.bottomright.curvepath", imageURL: route.previewImage) }
                .overlay(alignment: .topLeading) { chips.padding(CYSpacing.md) }
                .overlay(alignment: .bottomLeading) {
                    Text(verbatim: route.name)
                        .font(CYTypography.sectionTitle.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                        .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md).padding(.top, CYSpacing.jumbo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                }
            HStack(spacing: CYSpacing.sm) {
                if !route.city.isEmpty {
                    Label { Text(verbatim: route.city) } icon: { Image(systemName: "mappin.and.ellipse") }
                        .font(CYTypography.meta).foregroundStyle(palette.textSecondary).lineLimit(1)
                }
                Spacer(minLength: CYSpacing.sm)
                CYStatusChip(verbatim: copy, tone: .info, systemImage: "checkmark.seal")
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .background(palette.bgElevated)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).stroke(palette.borderSubtle))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var chips: some View {
        let duration = OfficialRouteFormat.duration(route.totalMinutes, chinese: chinese)
        let distance = OfficialRouteFormat.distance(route.distanceKm)
        HStack(spacing: CYSpacing.xs) {
            if !duration.isEmpty { E1GlassChip(systemImage: "clock", text: duration) }
            if !distance.isEmpty { E1GlassChip(systemImage: "figure.walk", text: distance) }
        }
    }
}

struct OfficialRouteDetailContent: View {
    let detail: OfficialRouteDetail
    let chinese: Bool
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var route: OfficialRoute { detail.route }
    private func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    private var firstStopURL: URL? {
        detail.nodes.lazy.compactMap { n -> URL? in
            guard let lat = n.latitude, let lng = n.longitude else { return nil }
            return OfficialRouteDetailView.mapURL(lat: lat, lng: lng, name: n.name)
        }.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                hero
                stats
                stops
            }
            .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm).padding(.bottom, CYSpacing.xxl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let url = firstStopURL {
                Link(destination: url) {
                    Label(t("在地图中打开起点", "Open first stop in Maps"), systemImage: "map")
                        .font(CYTypography.cardTitle).frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(palette.actionPrimaryFg)
                        .background(Capsule(style: .continuous).fill(palette.actionPrimaryBg))
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                .background(.bar)
            }
        }
    }

    private var hero: some View {
        Color.clear.aspectRatio(dynamicTypeSize.isAccessibilitySize ? 1.0 : 1.3, contentMode: .fit)
            .overlay { E1CoverArt(seed: route.name, symbol: "point.topleft.down.to.point.bottomright.curvepath", imageURL: route.previewImage) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYStatusChip(verbatim: t("官方路线", "Official route"), tone: .info, systemImage: "checkmark.seal")
                    Text(verbatim: route.name).font(.system(.largeTitle).weight(.bold)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                    if !route.city.isEmpty {
                        Label { Text(verbatim: route.city) } icon: { Image(systemName: "mappin.and.ellipse") }
                            .font(CYTypography.meta).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(CYSpacing.lg).padding(.top, 72).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
    }

    @ViewBuilder private var stats: some View {
        let duration = OfficialRouteFormat.duration(route.totalMinutes, chinese: chinese)
        let distance = OfficialRouteFormat.distance(route.distanceKm)
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        layout {
            stat("clock", t("用时", "Duration"), duration.isEmpty ? "—" : duration)
            stat("figure.walk", t("距离", "Distance"), distance.isEmpty ? "—" : distance)
            stat("mappin.and.ellipse", t("站点", "Stops"), detail.nodes.isEmpty ? "—" : "\(detail.nodes.count)")
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    private func stat(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(palette.textSecondary)
            Text(verbatim: value).font(CYTypography.cardTitle).monospacedDigit().foregroundStyle(palette.textPrimary).lineLimit(2).minimumScaleFactor(0.8)
            Text(verbatim: label).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var stops: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("officialRoute.detail.nodes \(detail.nodes.count)").font(CYTypography.sectionTitle.weight(.semibold))
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
                Text(verbatim: "\(node.order)").font(.footnote.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.textInverse).frame(width: 28, height: 28)
                    .background(Circle().fill(palette.textPrimary)).accessibilityHidden(true)
                if !last { Rectangle().fill(palette.borderStrong).frame(width: 2).frame(maxHeight: .infinity) }
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: node.name).font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                if !node.address.isEmpty { Text(verbatim: node.address).font(CYTypography.meta).foregroundStyle(palette.textSecondary) }
                if node.stayMinutes > 0 {
                    CYStatusChip(verbatim: t("停留 ", "Stay ") + OfficialRouteFormat.duration(node.stayMinutes, chinese: chinese), systemImage: "hourglass")
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, last ? 0 : CYSpacing.lg)
            Spacer(minLength: 0)
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
}
