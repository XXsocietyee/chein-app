import SwiftUI
import MapKit

// Roam fog spec stage 2 (§1b, §1d, §1f): the Roam map with the explored-area scrim above it, a coverage readout that
// prints an em dash when unknown, and the reveal choreography. Off by default: `PersonalFogFeature.liveRevealEnabled`
// is false, so `RoamFogMapView` renders exactly `RoamMapView` until a separate reviewed change flips it.

/// What the fog layer draws. Owned by the caller (ledger or fixture); the layer never loads, predicts or uploads.
struct FogPresentation: Equatable {
    let confirmed: FogCellBitmap
    let pending: FogCellBitmap
    /// Bumps whenever either bitmap changes; the mask is rebuilt only on a bump, a window exit or a level-of-detail change.
    let revision: Int
    let coverage: FogCoverageReading
    /// Cells are keyed in the server datum (GCJ-02) and are never re-projected (spec §1a).
    let datum: WalkingCoordinateDatum
}

/// Low Power or thermal `.serious`: no softening pass, no wipe layer (spec §1b, §1c).
enum FogPowerState {
    static var constrained: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
    }
}

extension CYFogCoverageReading {
    /// Core reading to the view-side badge. Unknown stays unknown (em dash); it is never turned into 0.
    init(_ reading: FogCoverageReading) {
        switch reading {
        case let .known(confirmed, pending, areaCells): self = .known(confirmed: confirmed, pending: pending, areaCells: areaCells)
        case let .unknown(reason):
            switch reason {
            case .notLoaded: self = .unknown(.notLoaded)
            case .readFailed: self = .unknown(.readFailed)
            case .noIdentity: self = .unknown(.noIdentity)
            case .permissionMissing: self = .unknown(.permissionMissing)
            case .noAreaSelected: self = .unknown(.noAreaSelected)
            }
        }
    }
}

/// The cache, the wipes and the Reduce Motion crossfade around `FogOverlayLayer`, for a known viewport. Shared by the map
/// overlay and the DEBUG fixtures, so both exercise the same rebuild gate.
struct FogViewportLayer: View {
    let fog: FogPresentation
    let viewport: FogMercatorWindow
    let size: CGSize
    var reveal: RevealChoreographer?
    /// nil: the style manifest's `fogOverlay` token for the current appearance.
    var style: FogScrimStyle? = nil
    @State private var cache = FogMaskCache()
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let constrained = FogPowerState.constrained
        let resolved = cache.resolve(confirmed: fog.confirmed, pending: fog.pending, revision: fog.revision, viewport: viewport, constrained: constrained)
        let rect = FogWindowGeometry.rect(of: resolved.mask.window, in: viewport, pointSize: size)
        let wipes = (reveal?.wipes ?? []).map { wipe in
            FogWipeDraw(cellRect: FogWindowGeometry.rect(of: wipe.cell, in: viewport, pointSize: size),
                        center: FogWindowGeometry.point(latitude: wipe.origin.latitude, longitude: wipe.origin.longitude, in: viewport, pointSize: size),
                        start: wipe.start, duration: wipe.duration)
        }
        let appearance = MapAppearance.resolve(systemIsDark: colorScheme == .dark)
        ZStack {
            FogOverlayLayer(mask: resolved.mask, images: resolved.images, windowRect: rect,
                            style: style ?? .token(appearance), wipes: wipes, softEdgeRadius: constrained ? 0 : 3)
                // Reduce Motion: a new mask fades in over 200 ms instead of any wipe.
                .id(resolved.mask.revision)
                .transition(.opacity)
        }
        .animation(reduceMotion ? .easeOut(duration: RevealChoreographer.crossfadeDuration) : nil, value: resolved.mask.revision)
    }
}

/// Sits above the `Map` inside its `MapReader` (the host stacks it). Reads the camera through two `MapProxy.convert`
/// calls; the Canvas moves with the camera, the mask only rebuilds through `FogMaskCache`.
struct FogMapOverlay: View {
    let fog: FogPresentation
    let proxy: MapProxy
    let size: CGSize
    /// Changes on every camera tick so this body re-reads the projection.
    let cameraRevision: Int
    var reveal: RevealChoreographer?

    private func viewport() -> FogMercatorWindow? {
        guard let nw = proxy.convert(.zero, from: .local), let se = proxy.convert(CGPoint(x: size.width, y: size.height), from: .local),
              let a = RoamCoordinate(latitude: nw.latitude, longitude: nw.longitude),
              let b = RoamCoordinate(latitude: se.latitude, longitude: se.longitude) else { return nil }
        return FogWindowGeometry.viewport(northWest: a, southEast: b, pointSize: size)
    }

    var body: some View {
        let _ = cameraRevision
        if let viewport = viewport() {
            FogViewportLayer(fog: fog, viewport: viewport, size: size, reveal: reveal)
        }
    }
}

/// `RoamMapView` plus the fog layer, the coverage readout and the reveal haptics. With the switch off the fog is dropped
/// and this is `RoamMapView` unchanged.
struct RoamFogMapView: View {
    let area: RoamSearchArea
    let items: [RoamMapItem]
    var selectedID: String? = nil
    var interactionID: AnyHashable? = nil
    var fillsHeight = false
    let fog: FogPresentation?
    var reveal: RevealChoreographer? = nil
    var enabled = PersonalFogFeature.liveRevealEnabled
    /// Cells whose wipe finished; the owner unions them into its bitmap and bumps `FogPresentation.revision`.
    var onBaked: ([FogRenderCell]) -> Void = { _ in }
    let onSelect: (RoamMapItem) -> Void
    @State private var visible = false

    private var active: FogPresentation? { enabled ? fog : nil }

    var body: some View {
        RoamMapView(area: area, items: items, selectedID: selectedID, interactionID: interactionID,
                    fillsHeight: fillsHeight, fog: active, reveal: reveal, onSelect: onSelect)
            .overlay(alignment: .topTrailing) {
                if let active {
                    CYFogCoverageBadge(reading: CYFogCoverageReading(active.coverage)).padding(CYSpacing.md)
                }
            }
            .onAppear { visible = true }
            .onDisappear { visible = false }
            // Haptics: the audit floor of 150 ms lives in CYRevealChoreographer; none while the map is off screen.
            .cyHaptic(.success, trigger: reveal?.hapticSuccessSerial ?? 0, where: { old, new in visible && new > old })
            .cyHaptic(.impactLight, trigger: reveal?.hapticLightSerial ?? 0, where: { old, new in visible && new > old })
            .task(id: reveal?.wipes.isEmpty ?? true) {
                guard let reveal else { return }
                while !reveal.wipes.isEmpty, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    let done = reveal.settle()
                    if !done.isEmpty { onBaked(done) }
                }
            }
    }
}

/// Everything `RoamLiveSessionView` needs to put the fog map behind its HUD. The owner supplies it; nothing here loads data.
struct RoamLiveFogMap {
    let area: RoamSearchArea
    var items: [RoamMapItem] = []
    let presentation: FogPresentation
    var reveal: RevealChoreographer? = nil
    var onBaked: ([FogRenderCell]) -> Void = { _ in }
}
