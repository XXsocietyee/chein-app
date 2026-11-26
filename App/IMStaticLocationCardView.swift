import SwiftUI
import MapKit

struct IMStaticLocationCardView: View {
    let place: IMStaticLocation
    @State private var showMap = false

    private var placeTitle: String {
        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "—" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showMap { map } else { cover }
            details
        }
        .frame(maxWidth: 280)
        // Messages-style location bubble: system hierarchical fill, system bubble shape.
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .privacySensitive()
        .onDisappear { showMap = false }
    }

    private var map: some View {
        Map(initialPosition: .region(CYMapRegion.region(
            center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng),
            span: 0.01))) {
            Marker(placeTitle, coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng))
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(height: 150)
        .allowsHitTesting(false)
        .accessibilityLabel(Text(verbatim: placeTitle))
    }

    /// The map service only sees this place once the person asks for the map: a drawn tile stands in until then.
    private var cover: some View {
        Button { showMap = true } label: {
            Label("d7.imLocationCard.showMap", systemImage: "map")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding([.horizontal, .top], 12)
        .accessibilityLabel(Text("d7.imLocationCard.showMap"))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: placeTitle)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !place.address.isEmpty {
                Text(verbatim: place.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
