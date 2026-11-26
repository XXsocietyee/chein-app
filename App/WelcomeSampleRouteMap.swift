import SwiftUI
import MapKit

/// L1 P-007: the welcome screen opens on a live Apple map with a sample walking route drawing itself on, so the
/// first thing a new player sees is what a roam looks like. Bundled coordinates only: no request, no location
/// prompt (`UserAnnotation` shows the player's position only when location is already allowed).
/// Reduce Motion or `-nativeR2.motion NO`: the route appears at once.
struct WelcomeSampleRouteMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var mapHeight: CGFloat = 200
    @State private var draw = NativeR2DrawOn()

    /// People's Square → Nanjing Road → the Bund (Shanghai), a short walk.
    static let route: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 31.2323, longitude: 121.4720),
        CLLocationCoordinate2D(latitude: 31.2348, longitude: 121.4762),
        CLLocationCoordinate2D(latitude: 31.2361, longitude: 121.4805),
        CLLocationCoordinate2D(latitude: 31.2382, longitude: 121.4851),
        CLLocationCoordinate2D(latitude: 31.2401, longitude: 121.4903),
    ]

    private static var region: MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 31.2362, longitude: 121.4812),
                           span: MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.026))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map(initialPosition: .region(Self.region), interactionModes: []) {
                UserAnnotation()
                MapPolyline(coordinates: Self.route)
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
                MapPolyline(coordinates: NativeR2RoutePath.prefix(Self.route, progress: draw.progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                if let start = Self.route.first {
                    Marker("nativeR2.shell.welcome.sampleRoute.start", systemImage: "figure.walk", coordinate: start)
                }
                if let finish = Self.route.last {
                    Marker("nativeR2.shell.welcome.sampleRoute.finish", systemImage: "flag.checkered", coordinate: finish)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: min(mapHeight, 320))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("nativeR2.shell.welcome.sampleRoute.a11y"))
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("welcome.sampleRoute")
            Label("nativeR2.shell.welcome.sampleRoute", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .task { await draw.run(duration: 2.0, reduceMotion: reduceMotion) }
    }
}
