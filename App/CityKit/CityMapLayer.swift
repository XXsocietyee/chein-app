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

/// Overlapping pins (xrefs-1 follow-up): pins closer than one pin width on screen are grouped. Zoomed out, a group is
/// one count bubble that zooms in on tap; zoomed in far enough that the places still overlap (the same building), the
/// pins fan out on a small ring around their centre so each one can be tapped.
struct CityPinGroup: Identifiable, Equatable {
    struct Member: Equatable { let place: CityPlace; let coordinate: CLLocationCoordinate2D
        static func == (a: Member, b: Member) -> Bool { a.place.id == b.place.id && a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude }
    }
    let id: String
    let center: CLLocationCoordinate2D
    /// One member: a plain pin. Several with `fanned`: separate pins on a ring. Several otherwise: a cluster bubble.
    let members: [Member]
    let fanned: Bool
    static func == (a: CityPinGroup, b: CityPinGroup) -> Bool { a.id == b.id && a.members == b.members && a.fanned == b.fanned }

    /// Groups `places` for a camera showing `span` degrees of longitude across `widthPoints`.
    /// - Parameters:
    ///   - pinPoints: the on-screen distance under which two pins overlap (the 44 pt hit frame).
    ///   - fanBelowSpan: below this longitude span a group fans out instead of collapsing to a count.
    static func make(_ places: [CityPlace], longitudeSpan: Double, widthPoints: Double, pinPoints: Double = 44,
                     fanBelowSpan: Double = 0.006) -> [CityPinGroup] {
        guard longitudeSpan > 0, widthPoints > 0, !places.isEmpty else {
            return places.map { CityPinGroup(id: $0.id, center: $0.clCoordinate, members: [Member(place: $0, coordinate: $0.clCoordinate)], fanned: false) }
        }
        let degreesPerPoint = longitudeSpan / widthPoints
        let threshold = pinPoints * degreesPerPoint
        // Greedy, stable: places in id order join the first group whose seed is within one pin width.
        var seeds: [(seed: CLLocationCoordinate2D, places: [CityPlace])] = []
        for place in places.sorted(by: { $0.id < $1.id }) {
            let c = place.clCoordinate
            let lngScale = max(0.2, cos(c.latitude * .pi / 180))
            if let index = seeds.firstIndex(where: { abs($0.seed.latitude - c.latitude) < threshold * lngScale && abs($0.seed.longitude - c.longitude) < threshold }) {
                seeds[index].places.append(place)
            } else {
                seeds.append((c, [place]))
            }
        }
        let fans = longitudeSpan < fanBelowSpan
        return seeds.map { group in
            let lat = group.places.map(\.coordinate.latitude).reduce(0, +) / Double(group.places.count)
            let lng = group.places.map(\.coordinate.longitude).reduce(0, +) / Double(group.places.count)
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let id = group.places.map(\.id).joined(separator: "+")
            guard group.places.count > 1 else {
                return CityPinGroup(id: id, center: center, members: [Member(place: group.places[0], coordinate: group.places[0].clCoordinate)], fanned: false)
            }
            guard fans else {
                return CityPinGroup(id: id, center: center, members: group.places.map { Member(place: $0, coordinate: $0.clCoordinate) }, fanned: false)
            }
            // A ring one pin wide around the centre, first member at 12 o'clock, clockwise.
            let radius = pinPoints * 0.75 * degreesPerPoint
            let lngScale = max(0.2, cos(lat * .pi / 180))
            let members = group.places.enumerated().map { index, place in
                let angle = Double(index) / Double(group.places.count) * 2 * .pi
                return Member(place: place, coordinate: CLLocationCoordinate2D(latitude: lat + radius * cos(angle) * lngScale,
                                                                               longitude: lng + radius * sin(angle)))
            }
            return CityPinGroup(id: id, center: center, members: members, fanned: true)
        }
    }
}

struct CityMapLayer: View {
    let places: [CityPlace]
    let mode: CityMapLayerMode
    @Binding var position: MapCameraPosition
    @Binding var selection: String?
    var center: CLLocationCoordinate2D?
    var onCameraChange: ((MKCoordinateRegion) -> Void)? = nil
    /// The selected pin's centre in the window (the origin of the pin → deed tile flight).
    var onPinPoint: ((String, CGPoint) -> Void)? = nil

    @State private var longitudeSpan: Double = 0
    @State private var mapWidth: Double = 393
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    @Environment(\.locale) private var locale

    private var increased: Bool { contrast == .increased || differentiate }

    var body: some View {
        MapReader { proxy in
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
            ForEach(groups) { group in
                if group.members.count == 1 || group.fanned {
                    ForEach(group.members, id: \.place.id) { member in
                        Annotation(CityCopy(locale: locale).title(member.place), coordinate: member.coordinate, anchor: .center) {
                            CityPin(place: member.place, selected: selection == member.place.id)
                        }
                        .annotationTitles(.hidden)
                        .tag(member.place.id)
                    }
                } else {
                    Annotation(CityCopy(locale: locale)("\(group.members.count) 个地点", "\(group.members.count) places"), coordinate: group.center, anchor: .center) {
                        CityPinCluster(count: group.members.count, hasMine: group.members.contains { $0.place.ownership == .mine }) {
                            zoom(into: group)
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls { MapCompass() }
        .environment(\.colorScheme, .dark)
        .onMapCameraChange(frequency: .onEnd) { context in
            longitudeSpan = context.region.span.longitudeDelta
            onCameraChange?(context.region)
        }
        .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { mapWidth = $0 }
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: selection) { _, id in
            guard let id, let onPinPoint, let place = places.first(where: { $0.id == id }) else { return }
            let coordinate = groups.flatMap(\.members).first { $0.place.id == id }?.coordinate ?? place.clCoordinate
            if let point = proxy.convert(coordinate, to: .global) { onPinPoint(id, point) }
        }
        }
    }

    private var groups: [CityPinGroup] {
        CityPinGroup.make(places, longitudeSpan: longitudeSpan, widthPoints: mapWidth)
    }

    /// A count bubble zooms the camera onto its members (or to the fan-out span when they share one spot).
    private func zoom(into group: CityPinGroup) {
        let lats = group.members.map(\.coordinate.latitude), lngs = group.members.map(\.coordinate.longitude)
        let span = max(0.004, (lngs.max()! - lngs.min()!) * 2.2, (lats.max()! - lats.min()!) * 2.2)
        withAnimation(CYMotion.standard) {
            position = .region(MKCoordinateRegion(center: group.center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)))
        }
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
        // Lit ground snaps to a ~150 m grid and each grid cell is cut once: overlapping interior polygons
        // would cancel each other out (even-odd) and draw fog back inside the light.
        let step = 0.00137
        var seen = Set<String>()
        var holes: [MKPolygon] = []
        for place in places where place.ownership != .fogged {
            let row = Int((place.coordinate.latitude / step).rounded(.down)), column = Int((place.coordinate.longitude / step).rounded(.down))
            for dr in -1...1 { for dc in -1...1 {
                let key = "\(row + dr):\(column + dc)"
                guard seen.insert(key).inserted else { continue }
                let lat = Double(row + dr) * step, lng = Double(column + dc) * step
                var cell = [CLLocationCoordinate2D(latitude: lat, longitude: lng), CLLocationCoordinate2D(latitude: lat, longitude: lng + step),
                            CLLocationCoordinate2D(latitude: lat + step, longitude: lng + step), CLLocationCoordinate2D(latitude: lat + step, longitude: lng)]
                holes.append(MKPolygon(coordinates: &cell, count: cell.count))
            } }
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
                Text(verbatim: "?").cyText(.meta, weight: .bold).foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .overlay(alignment: .topTrailing) { badge }
        .frame(width: 44, height: 44)
        .scaleEffect(selected && !reduceMotion ? CYMotion.Scale.pinSelected : 1)
        .overlay { if selected && reduceMotion { Circle().strokeBorder(Color.white, lineWidth: 2).frame(width: 42, height: 42) } }
        .animation(reduceMotion ? CityTokens.reducedFade : CYMotion.release, value: selected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var badge: some View {
        if place.isProtected(now: Date()) {
            Image(systemName: "lock.fill").accessibilityHidden(true).font(.caption2.weight(.bold)).foregroundStyle(.black)
                .frame(width: 16, height: 16).background(Color.white, in: Circle()).offset(x: -2, y: 2)
        } else if place.isWeathered {
            Image(systemName: "exclamationmark").accessibilityHidden(true).font(.caption2.weight(.black)).foregroundStyle(.black)
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

/// Several places closer than a pin width at this zoom: a count bubble; tap zooms in.
struct CityPinCluster: View {
    let count: Int
    var hasMine = false
    let action: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        Button(action: action) {
            Text(verbatim: "\(count)")
                .cyText(.numericBody)
                .foregroundStyle(hasMine ? CityTokens.bandInk : .white)
                .frame(minWidth: 34, minHeight: 34)
                .padding(.horizontal, count > 9 ? 4 : 0)
                .background(hasMine ? AnyShapeStyle(CityTokens.mine) : AnyShapeStyle(Color.black.opacity(0.72)), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white, lineWidth: 2))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: CityCopy(locale: locale)("\(count) 个地点，放大查看", "\(count) places, zoom in")))
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
        .cyText(.caption)
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
