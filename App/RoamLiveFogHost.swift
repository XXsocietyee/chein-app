import SwiftUI
import MapKit

/// Gap #24 (1128 plan R-02d; OWNER RULE 3 level-A signature surface, design-principles P29): the live roam map with
/// the fog lifting where the player walked. The host keeps the session's own marker map (places, shops, the user dot)
/// and stacks `FogMapOverlay` above it inside one `MapReader`, so the fog follows the camera. `FogViewportLayer`
/// already owns the motion policy: Reduce Motion crossfades each new mask (static reveal, no wipe, no shimmer);
/// Low Power Mode or a serious thermal state draws the mask once with no softening and no animation.
struct RoamLiveFogHost<Ground: View>: View {
    let fog: FogPresentation?
    let ground: Ground
    @State private var cameraRevision = 0

    init(fog: FogPresentation?, @ViewBuilder ground: () -> Ground) {
        self.fog = fog
        self.ground = ground()
    }

    var body: some View {
        GeometryReader { geometry in
            MapReader { proxy in
                ground
                    .onMapCameraChange(frequency: .continuous) { _ in cameraRevision &+= 1 }
                    .overlay { RoamLiveFogLayer(fog: fog, proxy: proxy, size: geometry.size, cameraRevision: cameraRevision) }
                    .overlay(alignment: .topTrailing) { RoamLiveFogBadge(fog: fog) }
            }
        }
    }
}

/// The fog itself; nothing when the walk has no revealed cell yet or the player switched the fog layer off.
private struct RoamLiveFogLayer: View {
    let fog: FogPresentation?
    let proxy: MapProxy
    let size: CGSize
    let cameraRevision: Int

    var body: some View {
        if let fog {
            FogMapOverlay(fog: fog, proxy: proxy, size: size, cameraRevision: cameraRevision)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// The coverage readout: an em dash when unknown, never a made-up 0.
private struct RoamLiveFogBadge: View {
    let fog: FogPresentation?

    var body: some View {
        if let fog {
            CYFogCoverageBadge(reading: CYFogCoverageReading(fog.coverage))
                .padding(.top, CYSpacing.xxl * 2)
                .padding(.trailing, CYSpacing.md)
        }
    }
}

extension FogPresentation {
    /// The live walk's projection (Core `RoamLiveFogProjection`) as the drawable presentation. Cells stay GCJ-02.
    init(_ projection: RoamLiveFogProjection) {
        self.init(confirmed: projection.confirmed, pending: projection.pending, revision: projection.revision,
                  coverage: projection.coverage, datum: .gcj02)
    }
}
