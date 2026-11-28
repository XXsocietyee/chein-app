import SwiftUI
import MapKit

/// fix-1128b-social #26 (audit H-07, 总规划 Task 1.3; MP uses `wx.chooseLocation`). The 选择地点 map: a search result
/// moves the camera, and a tap drops a pin whose coordinate the picker returns (name from Apple reverse geocoding when it
/// answers, otherwise the localized 地图选点 label plus the coordinate). No current-location or permission request.
@MainActor struct PublishingPlaceMapPreview: View {
    let selected: PublishingPlace?
    let onDrop: (CLLocationCoordinate2D) -> Void
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            MapReader { proxy in
                Map(position: $camera) {
                    if let selected {
                        Marker(selected.name, coordinate: CLLocationCoordinate2D(latitude: selected.latitude, longitude: selected.longitude))
                    }
                }
                .onTapGesture(coordinateSpace: .local) { point in Self.drop(point, proxy: proxy, onDrop: onDrop) }
            }
            .frame(height: 240)
            .accessibilityLabel(Text(selected.map { $0.name } ?? String(localized: "social1128.place.mapHint")))
            .accessibilityIdentifier("publishModes.placeMap")
            Text("social1128.place.tapHint").font(.footnote).foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, CYSpacing.xs)
        }
        .onAppear { follow(selected) }
        .onChange(of: selected?.id) { _, _ in follow(selected) }
    }

    private func follow(_ place: PublishingPlace?) {
        guard let place else { return }
        camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
    }

    private static func drop(_ point: CGPoint, proxy: MapProxy, onDrop: (CLLocationCoordinate2D) -> Void) {
        guard let coordinate = proxy.convert(point, from: .local) else { return }
        onDrop(coordinate)
    }
}

extension PublishingMapKitAdapter {
    /// The player / club 发布 flows (activity 选择地点, quick publish, topic stop map centre). Merchant pickers keep
    /// their own (off) adapter: merchant is out of the first release.
    static var playerPublishing: PublishingMapKitAdapter { PublishingMapKitAdapter(enabled: true) }

    /// A dropped pin as a place. The label is replaced by Apple's reverse-geocoded name when one comes back.
    static func droppedPin(_ coordinate: CLLocationCoordinate2D) -> PublishingPlace? {
        let address = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        return try? PublishingPlace(id: "pin:" + address, name: String(localized: "social1128.place.dropped"), address: address,
                                    latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Reverse geocode a dropped pin (same id, so the picker's selection stays). Nil when disabled or no answer.
    func named(_ pin: PublishingPlace) async -> PublishingPlace? {
        guard isEnabled else { return nil }
        let location = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let name = mark.name ?? mark.thoroughfare ?? mark.locality ?? ""
        let parts = [mark.administrativeArea, mark.locality, mark.subLocality, mark.thoroughfare, mark.subThoroughfare].compactMap { $0 }
        let address = parts.isEmpty ? pin.address : parts.joined()
        return try? PublishingPlace(id: pin.id, name: name, address: address, latitude: pin.latitude, longitude: pin.longitude)
    }
}
