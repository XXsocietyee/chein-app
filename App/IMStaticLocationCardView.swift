import SwiftUI
import MapKit

struct IMStaticLocationCardView: View {
    let place: IMStaticLocation
    @State private var showMap = false
    @Environment(\.cyPalette) private var palette

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
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .privacySensitive()
        .onDisappear { showMap = false }
    }

    private var map: some View {
        Map(initialPosition: .region(CYMapRegion.region(
            center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng),
            span: 0.01))) {
            Marker(placeTitle, coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng))
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .environment(\.colorScheme, .light)
        .background { CYMapPlaceholder(fog: false) }
        .frame(height: 150)
        .allowsHitTesting(false)
        .accessibilityLabel(Text(verbatim: placeTitle))
    }

    /// The map service only sees this place once the person asks for the map: a drawn tile stands in until then.
    private var cover: some View {
        Button { showMap = true } label: {
            ZStack(alignment: .bottomTrailing) {
                CYCoverArt(seed: placeTitle, symbol: "mappin.and.ellipse")
                Text("d7.imLocationCard.showMap")
                    .cyText(.caption, weight: .semibold)
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CYSpacing.md)
                    .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    .background(palette.overlay, in: Capsule())
                    .padding(CYSpacing.lg)
            }
            .frame(height: 140)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("d7.imLocationCard.showMap"))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: placeTitle)
                .cyText(.bodyMedium)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !place.address.isEmpty {
                Text(verbatim: place.address)
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
