import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// `Map/Base`, `Map/Pin` and `Map/Legend` (Library section `Map · 地图` 427:1637) as MapKit (owner Q5):
// a muted dark standard map with no POIs; territory cells and fog are overlays; labels stay MapKit's
// own (they draw above overlays). Mine = white (Q1), districts = hue, status = badge shape.

enum CityMapLayerMode: String, CaseIterable, Identifiable {
    case fog, territory
    var id: String { rawValue }
}

extension CityPlace {
    var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude) }

    /// The place's cell: a square about one geohash-7 tile (≈ 150 m) wide, centred on the anchor.
    func cell(halfMeters: Double = 70) -> [CLLocationCoordinate2D] {
        let dLat = halfMeters / 111_320
        let dLng = halfMeters / (111_320 * max(0.2, cos(coordinate.latitude * .pi / 180)))
        let lat = coordinate.latitude, lng = coordinate.longitude
        return [CLLocationCoordinate2D(latitude: lat - dLat, longitude: lng - dLng), CLLocationCoordinate2D(latitude: lat - dLat, longitude: lng + dLng),
                CLLocationCoordinate2D(latitude: lat + dLat, longitude: lng + dLng), CLLocationCoordinate2D(latitude: lat + dLat, longitude: lng - dLng)]
    }
}

struct CityMapLayer: View {
    let places: [CityPlace]
    let mode: CityMapLayerMode
    @Binding var position: MapCameraPosition
    @Binding var selection: String?
    var center: CLLocationCoordinate2D?
    var onCameraChange: ((MKCoordinateRegion) -> Void)? = nil

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    @Environment(\.locale) private var locale

    private var increased: Bool { contrast == .increased || differentiate }

    var body: some View {
        Map(position: $position, selection: $selection) {
            UserAnnotation()
            if mode == .fog, let fog = fogPolygon {
                MapPolygon(fog)
                    .foregroundStyle(CityTokens.fog)
                    .stroke(CityTokens.fogEdge, lineWidth: 1)
            }
            if mode == .territory {
                ForEach(places.filter { $0.ownership == .mine || $0.ownership == .other }) { place in
                    MapPolygon(coordinates: place.cell())
                        .foregroundStyle(CityTokens.district(place.districtIndex).opacity(0.22))
                        .stroke(CityTokens.district(place.districtIndex), lineWidth: increased ? 2.5 : 1.5)
                    if place.ownership == .mine {
                        MapPolygon(coordinates: place.cell(halfMeters: 62))
                            .foregroundStyle(.clear)
                            .stroke(CityTokens.mine, style: StrokeStyle(lineWidth: 2, dash: increased ? [6, 4] : []))
                    }
                }
            }
            ForEach(places) { place in
                Annotation(CityCopy(locale: locale).title(place), coordinate: place.clCoordinate, anchor: .center) {
                    CityPin(place: place, selected: selection == place.id)
                }
                .annotationTitles(.hidden)
                .tag(place.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls { MapCompass() }
        .environment(\.colorScheme, .dark)
        .onMapCameraChange(frequency: .onEnd) { context in onCameraChange?(context.region) }
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// One polygon over the area with the lit cells cut out (`MKPolygon` interior polygons).
    private var fogPolygon: MKPolygon? {
        let anchor = center ?? places.first?.clCoordinate
        guard let anchor else { return nil }
        let span = 0.08
        var outer = [CLLocationCoordinate2D(latitude: anchor.latitude - span, longitude: anchor.longitude - span),
                     CLLocationCoordinate2D(latitude: anchor.latitude - span, longitude: anchor.longitude + span),
                     CLLocationCoordinate2D(latitude: anchor.latitude + span, longitude: anchor.longitude + span),
                     CLLocationCoordinate2D(latitude: anchor.latitude + span, longitude: anchor.longitude - span)]
        let holes = places.filter { $0.ownership != .fogged }.map { place -> MKPolygon in
            var cell = place.cell(halfMeters: 90)
            return MKPolygon(coordinates: &cell, count: cell.count)
        }
        return MKPolygon(coordinates: &outer, count: outer.count, interiorPolygons: holes)
    }
}

/// `Map/Pin`: 44 pt hit frame; shape tells ownership (mine = white disc, other = outline flag,
/// open = dashed ring with +, unlit = hollow ring with ?). Selected pins scale to 1.15.
struct CityPin: View {
    let place: CityPlace
    var selected = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            switch place.ownership {
            case .mine:
                Circle().fill(CityTokens.mine).frame(width: 34, height: 34)
                Image(systemName: "flag.fill").font(.footnote.weight(.bold)).foregroundStyle(CityTokens.bandInk)
            case .other:
                Circle().fill(Color.black.opacity(0.72)).frame(width: 34, height: 34)
                Circle().strokeBorder(Color.white, lineWidth: 2).frame(width: 34, height: 34)
                Image(systemName: "flag").font(.footnote.weight(.bold)).foregroundStyle(.white)
            case .open:
                Circle().fill(Color.black.opacity(0.55)).frame(width: 30, height: 30)
                Circle().strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 30, height: 30)
                Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.white)
            case .fogged:
                Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5).frame(width: 26, height: 26)
                Text(verbatim: "?").font(.caption.weight(.bold)).foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .overlay(alignment: .topTrailing) { badge }
        .frame(width: 44, height: 44)
        .scaleEffect(selected ? 1.15 : 1)
        .animation(reduceMotion ? CityTokens.reducedFade : CityTokens.pressSpring, value: selected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var badge: some View {
        if place.isProtected(now: Date()) {
            Image(systemName: "lock.fill").font(.caption2.weight(.bold)).foregroundStyle(.black)
                .frame(width: 16, height: 16).background(Color.white, in: Circle()).offset(x: -2, y: 2)
        } else if place.isWeathered {
            Image(systemName: "exclamationmark").font(.caption2.weight(.black)).foregroundStyle(.black)
                .frame(width: 16, height: 16).background(CityTokens.coin, in: Circle()).offset(x: -2, y: 2)
        }
    }

    private var label: String {
        let copy = CityCopy(locale: locale)
        let state: String
        switch place.ownership {
        case .mine: state = copy("你持有", "yours")
        case .other: state = copy("\(place.holderName ?? "玩家") 持有", "held by \(place.holderName ?? "a player")")
        case .open: state = copy("可圈", "claimable")
        case .fogged: state = copy("未点亮", "unlit")
        }
        return copy.title(place) + copy("，", ", ") + state
    }
}

/// `Map/Legend`: one capsule row, glass (opaque under Reduce Transparency).
struct CityMapLegend: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.cyPalette) private var palette
    var body: some View {
        let copy = CityCopy(locale: locale)
        HStack(spacing: CYSpacing.md) {
            item(AnyView(Circle().fill(CityTokens.mine).frame(width: 12, height: 12)), copy("我的", "Mine"))
            item(AnyView(Circle().strokeBorder(Color.white, lineWidth: 1.5).frame(width: 12, height: 12)), copy("别人的", "Others"))
            item(AnyView(Circle().strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])).frame(width: 12, height: 12)), copy("可圈", "Open"))
            item(AnyView(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5).frame(width: 12, height: 12)), copy("未点亮", "Unlit"))
        }
        .font(CYTypography.caption)
        .foregroundStyle(palette.textSecondary)
        .padding(.horizontal, CYSpacing.md).frame(minHeight: 32)
        .background {
            if reduceTransparency { Capsule().fill(palette.bgElevated) } else { Capsule().fill(.ultraThinMaterial) }
        }
        .accessibilityElement(children: .combine)
    }
    private func item(_ glyph: AnyView, _ text: String) -> some View {
        HStack(spacing: 4) { glyph.accessibilityHidden(true); Text(verbatim: text) }
    }
}
