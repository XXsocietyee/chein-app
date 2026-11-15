import SwiftUI
import MapKit

/// Only the original owner-authorized /os mapAnchors are supplied here. This is
/// not the main route map, a user-location layer, a feed, or a new map grant.
struct PlayPreferenceOriginalAnchorMap: View {
    let anchors: [PlayOperatingSummary.Anchor]
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let region = CYMapRegion.boundingRegion(
            coordinates: anchors.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        )
        Map(initialPosition: .region(region), interactionModes: [.pan, .zoom]) {
            ForEach(Array(anchors.enumerated()), id: \.offset) { _, anchor in
                Marker(anchor.name.isEmpty ? "#\(anchor.id)" : anchor.name,
                    coordinate: CLLocationCoordinate2D(latitude: anchor.latitude, longitude: anchor.longitude))
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .light)
        .background { CYMapPlaceholder(fog: false) }
        .mapControls { MapCompass() }
        .frame(height: typeSize.isAccessibilitySize ? 240 : 300)
        .accessibilityLabel(Text("playx.os.anchors"))
        .accessibilityIdentifier("playx.os.originalAnchors.map")
        .privacySensitive()
        // The map owns no persistent camera or private coordinate cache.
        .id(anchors.map { "\($0.id):\($0.latitude):\($0.longitude)" }.joined(separator: "|"))
    }
}
