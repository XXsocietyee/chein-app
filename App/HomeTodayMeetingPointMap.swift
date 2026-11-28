import MapKit
import SwiftUI

/// Meeting point of a Today card's club event (P28 event facts): where the group meets, as a coordinate.
struct HomeTodayMeetingPoint: Equatable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

/// mp-home r3 (sweep 11-28 04:50, wave-today-club): design fixtures run offline, so they hand the Today card a bundled
/// MP cover instead of a URL. Production never sets it; a card without a cover stays text-only.
private struct HomeTodayFixtureCoverKey: EnvironmentKey {
    static let defaultValue: Image? = nil
}

extension EnvironmentValues {
    var homeTodayFixtureCover: Image? {
        get { self[HomeTodayFixtureCoverKey.self] }
        set { self[HomeTodayFixtureCoverKey.self] = newValue }
    }
}

/// Fixed meeting-point map snippet (P28): one marker on the system map, no gestures; a tap opens Apple Maps there.
/// Shared by the 首页 Today card and the activity detail 集合点 fact (level B: a map snippet for every place).
struct HomeTodayMeetingPointMap: View {
    let point: HomeTodayMeetingPoint
    let place: String?
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 132

    private var copy: CYKitCopy { CYKitCopy(locale: locale) }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: point.coordinate, latitudinalMeters: 700, longitudinalMeters: 700)
    }

    var body: some View {
        Button(action: openInMaps) {
            Map(initialPosition: .region(region), interactionModes: []) {
                Marker(place ?? copy("Meeting point", "集合点"), systemImage: "mappin", coordinate: point.coordinate)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity)
            .frame(height: min(height, 220))
            .clipShape(.rect(cornerRadius: CYRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: copy("Meeting point", "集合点") + (place.map { ", " + $0 } ?? "")))
        .accessibilityHint(Text(verbatim: copy("Opens in Maps", "在地图中打开")))
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: point.coordinate))
        item.name = place
        item.openInMaps(launchOptions: nil)
    }
}
