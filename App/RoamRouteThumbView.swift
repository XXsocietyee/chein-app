import MapKit
import SwiftUI

/// ROAM-r11-10: trip-row route thumb on a real basemap (MP subpackageRoam/components/cy/route-thumb/index.js:1-8):
/// a fixed, non-interactive map with the track polyline, a hollow start and a filled end dot, and the visited
/// places. Without at least two coordinates (new phone / location data cleared) it falls back to the schematic.
struct RoamRouteThumbView: View {
    let record: RoamHistoryRecord

    private var coordinates: [CLLocationCoordinate2D] {
        record.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }
    private var placeCoordinates: [CLLocationCoordinate2D] {
        record.pois.filter { !$0.isDemoEntry }.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    var body: some View {
        if coordinates.count >= 2, let region = Self.region(fitting: coordinates + placeCoordinates) {
            mapThumb(region: region)
        } else {
            RoamRouteSketchView(record: record)
        }
    }

    private func mapThumb(region: MKCoordinateRegion) -> some View {
        let line = coordinates
        let places = placeCoordinates
        return Map(initialPosition: .region(region), interactionModes: []) {
            MapPolyline(coordinates: line).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            ForEach(Array(places.enumerated()), id: \.offset) { _, place in
                Annotation("", coordinate: place) { RoamRouteThumbDot(filled: true, size: 7, tint: .orange) }
            }
            if let first = line.first {
                Annotation("", coordinate: first) { RoamRouteThumbDot(filled: false, size: 10, tint: .accentColor) }
            }
            if let last = line.last {
                Annotation("", coordinate: last) { RoamRouteThumbDot(filled: true, size: 10, tint: .accentColor) }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("roam.experience.routeSketch"))
    }

    /// Bounding region with a 30 % margin and a ~150 m floor so a short loop is not zoomed to the street.
    static func region(fitting points: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        let lats = points.map(\.latitude), lngs = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLng = lngs.min(), let maxLng = lngs.max() else { return nil }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.3, 0.0015),
                                    longitudeDelta: max((maxLng - minLng) * 1.3, 0.0015))
        return MKCoordinateRegion(center: center, span: span)
    }
}

private struct RoamRouteThumbDot: View {
    let filled: Bool
    let size: CGFloat
    let tint: Color
    var body: some View {
        Circle()
            .fill(filled ? tint : Color.white)
            .overlay(Circle().strokeBorder(tint, lineWidth: 2))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
