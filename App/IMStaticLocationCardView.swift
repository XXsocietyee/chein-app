import SwiftUI
import MapKit

struct IMStaticLocationCardView: View {
    let place: IMStaticLocation
    @State private var showMap = false
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    private var placeTitle: String {
        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "—" : name
    }

    /// On the cover the label sits on a dark scrim, so it stays white. Below the cover it uses the role text color.
    private var showMapLabel: some View {
        Text("d7.imLocationCard.showMap")
            .font(CYTypography.caption.weight(.semibold))
            .foregroundStyle(typeSize.isAccessibilitySize ? palette.textPrimary : Color.white)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CYSpacing.md)
            .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
            .background {
                if !typeSize.isAccessibilitySize { Capsule().fill(palette.overlay) }
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            media
            details
        }
        .modifier(IMLocationCardWidth(accessibility: typeSize.isAccessibilitySize))
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .privacySensitive()
        .onDisappear { showMap = false }
    }

    @ViewBuilder private var media: some View {
        if showMap {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay { locationMap.allowsHitTesting(false) }
                .clipped()
                .accessibilityLabel(Text(verbatim: placeTitle))
        } else {
            // The map service only sees this place once the person asks for the map: a drawn tile stands in until then.
            Button { showMap = true } label: { coverButton }
                .buttonStyle(CYPressScaleStyle())
                .accessibilityLabel(Text("d7.imLocationCard.showMap"))
        }
    }

    private var locationMap: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
            Marker(placeTitle, coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng))
        }
    }

    private var coverButton: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay { CYCoverArt(seed: placeTitle, symbol: "mappin.and.ellipse") }
                .overlay(alignment: .bottomTrailing) {
                    if !typeSize.isAccessibilitySize { showMapLabel.padding(CYSpacing.lg) }
                }
                .clipped()
            if typeSize.isAccessibilitySize {
                showMapLabel.padding(CYSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: placeTitle)
                .font(CYTypography.bodyMedium)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !place.address.isEmpty {
                Text(verbatim: place.address)
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IMLocationCardWidth: ViewModifier {
    let accessibility: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if accessibility { content.frame(maxWidth: .infinity, alignment: .leading) }
        else { content.frame(maxWidth: 280, alignment: .leading) }
    }
}

#if DEBUG
#Preview("Location card · player") {
    IMStaticLocationCardView(place: try! IMStaticLocation(name: "Fixture Park", address: "1 Example Road", latitude: 31.23, longitude: 121.47, datum: "WGS84"))
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.player)
}
#Preview("Location card · merchant") {
    IMStaticLocationCardView(place: try! IMStaticLocation(name: "Fixture Park", address: "1 Example Road", latitude: 31.23, longitude: 121.47, datum: "WGS84"))
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.merchant)
}
#endif
