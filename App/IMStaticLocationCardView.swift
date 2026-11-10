import SwiftUI
import MapKit

struct IMStaticLocationCardView: View {
    let place: IMStaticLocation
    @State private var showMap=false
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            if showMap {
                Map(initialPosition:.region(MKCoordinateRegion(
                    center:CLLocationCoordinate2D(latitude:place.lat,longitude:place.lng),
                    span:MKCoordinateSpan(latitudeDelta:0.01,longitudeDelta:0.01)))) {
                    Marker(place.name,coordinate:CLLocationCoordinate2D(latitude:place.lat,longitude:place.lng))
                }.frame(height:150).allowsHitTesting(false)
            } else {
                // The map service only sees this place once the person asks for the map: a drawn tile stands in until then.
                Button { showMap=true } label: {
                    ZStack {
                        CYCoverArt(seed: place.name, symbol: "map", showsDebugLabel: false, showsGlyph: false)
                        Image(systemName: "mappin.circle.fill").font(.system(size: 34)).symbolRenderingMode(.palette).foregroundStyle(.white, Color.red)
                        Label("d7.imLocationCard.showMap", systemImage: "map").font(.caption.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 10).frame(minHeight: 28).background(.black.opacity(0.5), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(CYSpacing.sm)
                    }.frame(height: 110).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(Text("d7.imLocationCard.showMap"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: place.name).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                if !place.address.isEmpty { Text(verbatim: place.address).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            }.padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 280)
        .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .privacySensitive().onDisappear { showMap=false }
    }
}
