import SwiftUI
import MapKit

// Map chrome for the immersive player screens (play / roam / search map). Presentation only:
// glass controls, the white GO circle, a persistent detent sheet and a non-black cartographic
// placeholder map used by debug fixtures, offline states, and simulator fallback. Real screens keep MapKit underneath.

/// Sanitizes map coordinates and derives non-empty bounding regions so MapKit never opens on
/// `(0, 0)`, `.automatic` with zero annotations, or `MKMapRect.world`.
enum CYMapRegion {
    static let fallbackCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
    static let fallbackSpan = MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)

    static var defaultPosition: MapCameraPosition {
        .region(MKCoordinateRegion(center: fallbackCenter, span: fallbackSpan))
    }

    static func isValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate)
            && coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && abs(coordinate.latitude) <= 85
            && (abs(coordinate.latitude) > 0.0001 || abs(coordinate.longitude) > 0.0001)
    }

    static func region(center: CLLocationCoordinate2D, span: Double = 0.04) -> MKCoordinateRegion {
        sanitizedRegion(center: center, span: span)
    }

    static func sanitizedRegion(
        center: CLLocationCoordinate2D,
        span: Double = 0.04,
        coordinates: [CLLocationCoordinate2D] = []
    ) -> MKCoordinateRegion {
        let clampedSpan = max(0.002, min(span.isFinite ? span : 0.04, 60.0))
        if isValid(center) {
            return MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: clampedSpan, longitudeDelta: clampedSpan)
            )
        }
        return boundingRegion(coordinates: coordinates, minimumSpan: clampedSpan)
    }

    static func boundingRegion(
        coordinates: [CLLocationCoordinate2D],
        minimumSpan: Double = 0.015
    ) -> MKCoordinateRegion {
        let valid = coordinates.filter(isValid)
        guard let first = valid.first else {
            return MKCoordinateRegion(center: fallbackCenter, span: fallbackSpan)
        }
        if valid.count == 1 {
            let span = max(0.004, min(minimumSpan, 60.0))
            return MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for point in valid.dropFirst() {
            minLat = min(minLat, point.latitude); maxLat = max(maxLat, point.latitude)
            minLng = min(minLng, point.longitude); maxLng = max(maxLng, point.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let latDelta = max(minimumSpan, min((maxLat - minLat) * 1.35, 60.0))
        let lngDelta = max(minimumSpan, min((maxLng - minLng) * 1.35, 60.0))
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta))
    }
}

/// Artwork of a round glass control (also used as a NavigationLink / Menu label).
struct CYGlassLabel: View {
    let systemImage: String
    @ScaledMetric(relativeTo: .body) private var scaled: CGFloat = 48
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var size: CGFloat { min(scaled, 60) }
    /// Native r2: an SF Symbol on a plain system-background circle (no material, stroke or fixed black/white).
    var body: some View {
        Image(systemName: systemImage)
            .accessibilityHidden(true)
            .font(.body.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(Color(uiColor: .systemBackground), in: Circle())
            .contentShape(Circle())
    }
}

/// Round 44pt (scaled) glass control floating over a map. Max three per screen (owner rule).
struct CYGlassButton: View {
    private let systemImage: String
    private let label: LocalizedStringKey
    private let action: () -> Void

    init(systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) { CYGlassLabel(systemImage: systemImage) }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .pageTemplateControl(label: Text(label), traits: .isButton)
    }
}

/// Glass capsule container (search field, title pill, stat strip).
struct CYGlassCapsule<Content: View>: View {
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    /// Native r2: plain system-background capsule (no material, no stroke).
    var body: some View {
        content
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: 44)
            .background(Color(uiColor: .systemBackground), in: Capsule())
    }
}

/// The white GO circle artwork (also used as a NavigationLink label).
struct CYGoLabel: View {
    private let title: LocalizedStringKey
    private let symbol: String?
    /// Only the Latin "GO" mark keeps the heavy italic; a localised word (暂停, 开始) uses the kit title font.
    private let isWordmark: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .largeTitle) private var scaled: CGFloat = 96
    private var size: CGFloat { min(scaled, 112) }
    /// The GO wordmark. `symbol` replaces it with a glyph (the walking state shows a walking figure).
    init(symbol: String? = nil) { self.title = "GO"; self.symbol = symbol; self.isWordmark = true }
    /// A localised action word (string key), drawn in `CYTypography.sheetTitle`.
    init(_ title: LocalizedStringKey, symbol: String? = nil) { self.title = title; self.symbol = symbol; self.isWordmark = false }
    var body: some View {
        Group {
            if let symbol {
                Image(systemName: symbol).accessibilityLabel(Text(title)).font(.system(.title).weight(.heavy))
            } else if isWordmark {
                Text(title).font(.system(.title, design: .default).weight(.heavy).italic())
            } else {
                Text(title).cyText(.sheetTitle)
            }
        }
            .minimumScaleFactor(0.6).lineLimit(1)
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(Color.white, in: Circle())
            .overlay(Circle().strokeBorder(Color.black.opacity(contrast == .increased ? 0.6 : 0), lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
            .contentShape(Circle())
    }
}

/// The mini-program's white GO circle: the single primary action of a map screen.
struct CYGoButton: View {
    private let title: LocalizedStringKey
    private let isWordmark: Bool
    private let action: () -> Void
    /// The GO wordmark button.
    init(action: @escaping () -> Void) {
        self.title = "GO"
        self.isWordmark = true
        self.action = action
    }
    /// A localised action word (string key), e.g. `roam.live.pause` 暂停.
    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.isWordmark = false
        self.action = action
    }
    var body: some View {
        Button(action: action) { isWordmark ? CYGoLabel() : CYGoLabel(title) }
            .buttonStyle(CYGoPressStyle())
            .accessibilityElement(children: .ignore)
            .pageTemplateControl(label: Text(title), traits: .isButton)
            .accessibilitySortPriority(10)   // the one primary map action is reached before the list panel
    }
}

/// Readable cartographic stand-in for a map (land, parks, waterways, avenues). Used behind
/// MapKit views, in offline states, and as a non-black simulator fallback. Never draws a black rectangle.
struct CYMapPlaceholder: View {
    var fog = true
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let isLight = colorScheme == .light
        let land = isLight ? Color(red: 0.93, green: 0.91, blue: 0.87) : Color(red: 0.16, green: 0.21, blue: 0.29)
        let block = isLight ? Color(red: 0.87, green: 0.85, blue: 0.81) : Color(red: 0.21, green: 0.27, blue: 0.36)
        let park = isLight ? Color(red: 0.81, green: 0.89, blue: 0.78) : Color(red: 0.16, green: 0.31, blue: 0.24)
        let water = isLight ? Color(red: 0.71, green: 0.83, blue: 0.94) : Color(red: 0.16, green: 0.33, blue: 0.49)
        let street = isLight ? Color.white : Color.white.opacity(0.24)
        let avenue = isLight ? Color(red: 0.97, green: 0.87, blue: 0.63) : Color(red: 0.49, green: 0.54, blue: 0.44)
        ZStack {
            land
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(x: size.width * 0.54, y: size.height * 0.12, width: size.width * 0.32, height: size.height * 0.18)), with: .color(park))
                ctx.fill(Path(CGRect(x: size.width * 0.04, y: size.height * 0.58, width: size.width * 0.24, height: size.height * 0.18)), with: .color(park))
                ctx.fill(Path(CGRect(x: size.width * 0.14, y: size.height * 0.16, width: size.width * 0.26, height: size.height * 0.14)), with: .color(block))
                ctx.fill(Path(CGRect(x: size.width * 0.62, y: size.height * 0.56, width: size.width * 0.26, height: size.height * 0.18)), with: .color(block))
                var waterPath = Path()
                waterPath.move(to: CGPoint(x: -20, y: size.height * 0.62))
                waterPath.addCurve(to: CGPoint(x: size.width + 20, y: size.height * 0.30),
                                   control1: CGPoint(x: size.width * 0.35, y: size.height * 0.78),
                                   control2: CGPoint(x: size.width * 0.62, y: size.height * 0.20))
                ctx.stroke(waterPath, with: .color(water), lineWidth: 34)
                for i in 0..<9 {
                    var p = Path()
                    let y = size.height * (0.06 + CGFloat(i) * 0.115)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y + size.height * 0.05 * (i.isMultiple(of: 2) ? 1 : -1)))
                    ctx.stroke(p, with: .color(i.isMultiple(of: 3) ? avenue : street), lineWidth: i.isMultiple(of: 3) ? 6 : 2.5)
                }
                for i in 0..<6 {
                    var p = Path()
                    let x = size.width * (0.08 + CGFloat(i) * 0.18)
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.width * 0.12, y: size.height))
                    ctx.stroke(p, with: .color(i.isMultiple(of: 2) ? avenue : street), lineWidth: i.isMultiple(of: 2) ? 5 : 2.5)
                }
            }
            if fog {
                RadialGradient(colors: [.clear, Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.26)], center: .center, startRadius: 140, endRadius: 540)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Readable street-grid stand-in for offline and tile-less simulator maps across both Debug and Release builds.
struct CYMapStreetGrid: View {
    var body: some View {
        ZStack {
            Color(red: 0.18, green: 0.23, blue: 0.31)
            Canvas { ctx, size in
                let block = Color(red: 0.22, green: 0.28, blue: 0.37)
                let street = Color(red: 0.39, green: 0.44, blue: 0.52)
                let avenue = Color(red: 0.56, green: 0.55, blue: 0.41)
                ctx.fill(Path(CGRect(x: size.width * 0.52, y: size.height * 0.12, width: size.width * 0.34, height: size.height * 0.16)), with: .color(Color(red: 0.17, green: 0.32, blue: 0.24)))
                ctx.fill(Path(CGRect(x: 0, y: size.height * 0.5, width: size.width * 0.26, height: size.height * 0.2)), with: .color(block))
                let step: CGFloat = 64
                var x: CGFloat = -10
                var i = 0
                while x < size.width + step {
                    var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 14, y: size.height))
                    ctx.stroke(p, with: .color(i % 4 == 0 ? avenue : street), lineWidth: i % 4 == 0 ? 7 : 3); x += step; i += 1
                }
                var y: CGFloat = 20
                i = 0
                while y < size.height + step {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y - 18))
                    ctx.stroke(p, with: .color(i % 3 == 0 ? avenue : street), lineWidth: i % 3 == 0 ? 7 : 3); y += step * 0.9; i += 1
                }
                var diag = Path(); diag.move(to: CGPoint(x: 0, y: size.height * 0.9)); diag.addLine(to: CGPoint(x: size.width, y: size.height * 0.25))
                ctx.stroke(diag, with: .color(avenue), lineWidth: 9)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Place-pin artwork from the mini-program. Unselected category pins are the small dots; selected pins are the teardrops.
enum CYMapMarkerKind: Equatable {
    case landmark, merchant, park, shop, street, unknown, cluster
    case search, searchLocation, route, publish, roam
}

enum CYMapMarkerArt {
    static func image(kind: CYMapMarkerKind, selected: Bool) -> Image {
        switch kind {
        case .landmark: return selected ? MPAsset.MapMarker.pinLandmark : MPAsset.MapMarker.dotLandmark
        case .merchant: return selected ? MPAsset.MapMarker.pinMerchant : MPAsset.MapMarker.dotMerchant
        case .park: return selected ? MPAsset.MapMarker.pinPark : MPAsset.MapMarker.dotPark
        case .shop: return selected ? MPAsset.MapMarker.pinShop : MPAsset.MapMarker.dotShop
        case .street: return selected ? MPAsset.MapMarker.pinStreet : MPAsset.MapMarker.dotStreet
        case .unknown: return selected ? MPAsset.MapMarker.pinUnknown : MPAsset.MapMarker.dotUnknown
        case .cluster: return MPAsset.MapMarker.dotCluster
        // Round 4 image parity: the search map's topic pin is the page-local `pages/searchmap/images/d_smapicon.png`
        // (searchmap/index.js:532); `/images/d_smapicon.png` is the roam hangout fallback, a different drawing.
        case .search: return selected ? MPAsset.MapMarker.pagesSearchmapImagesDSmapicon : MPAsset.MapMarker.iconMap6
        case .searchLocation: return MPAsset.MapMarker.dLocation2
        case .route: return MPAsset.MapMarker.iconMap4
        case .publish: return MPAsset.MapMarker.mapPin
        case .roam: return selected ? MPAsset.MapMarker.roamPushpin : MPAsset.MapMarker.dotUnknown
        }
    }

    static func kind(symbol: String) -> CYMapMarkerKind {
        switch symbol {
        case "circle.grid.2x2", "circle.grid.2x2.fill": return .cluster
        case "mappin": return .search
        case "location", "location.fill", "location.circle", "location.circle.fill": return .searchLocation
        case "mappin.circle", "mappin.circle.fill": return .publish
        case "mappin.and.ellipse": return .roam
        case "flag", "flag.fill", "binoculars", "binoculars.fill", "star", "star.fill": return .landmark
        case "cart", "cart.fill", "cup.and.saucer", "cup.and.saucer.fill", "storefront", "storefront.fill": return .merchant
        case "music.note", "leaf", "leaf.fill", "tree", "tree.fill": return .park
        case "book", "book.fill", "bag", "bag.fill": return .shop
        case "road.lanes", "point.topleft.down.to.point.bottomright.curvepath": return .street
        default: return .unknown
        }
    }
}

/// Shared map pin. Draws the mini-program marker for the symbol; selection swaps dot → pin where the set has both.
struct CYMapMarker: View {
    var symbol: String = "mappin"
    var kind: CYMapMarkerKind?
    var selected = false

    var body: some View {
        let resolved = kind ?? CYMapMarkerArt.kind(symbol: symbol)
        let side: CGFloat = {
            switch resolved {
            case .cluster: return 36
            case .searchLocation, .route: return 28
            case .publish, .roam: return selected ? 40 : 22
            case .search: return selected ? 32 : 20
            default: return selected ? 36 : 18
            }
        }()
        CYMapMarkerArt.image(kind: resolved, selected: selected)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

/// Pin used by placeholder maps: white label callout like the mini-program search map.
struct CYMapCallout: View {
    let text: String
    var selected = false
    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: text)
                .cyText(.bodyMedium)
                .foregroundStyle(.black)
                .lineLimit(2)
                .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).strokeBorder(Color.black.opacity(selected ? 0.9 : 0), lineWidth: 2))
            Image(systemName: "arrowtriangle.down.fill").accessibilityHidden(true).font(.system(size: 9)).foregroundStyle(.white).offset(y: -1)
        }
    }
}

private struct CYMapSheetModifier<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheet: () -> Sheet
    @Environment(\.dynamicTypeSize) private var type
    @State private var selection: PresentationDetent = .height(236)

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheet()
                .presentationDetents(detents, selection: $selection)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .cyPlayerSheetGlass()
                .interactiveDismissDisabled()
                .onAppear { if type.isAccessibilitySize { selection = .medium } }
        }
    }
}

extension View {
    /// Persistent bottom sheet over a full-bleed map: detents, map stays interactive behind, never dismissed.
    /// Use for node / task / result information; the screen's primary action lives inside it.
    /// At accessibility text sizes it opens at the medium detent so the primary action is visible.
    func cyMapSheet<Sheet: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.height(236), .medium, .large],
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        modifier(CYMapSheetModifier(isPresented: isPresented, detents: detents, sheet: content))
    }
}

// MARK: - Map scaffold (real screens)

/// Spring every map sheet / panel snaps with (response 0.42, damping 0.82: one soft settle, no wobble).
let cyRoamSheetSnap = Animation.spring(response: 0.42, dampingFraction: 0.82)

/// Fill of the map panel; content inside the panel stays clear so header and list share one surface.
/// ds-consistency r3 (sweep 283dd3b52 `d2-roam`): the elevated system surface, so the panel follows the system
/// appearance like every other sheet (it was fixed black, a dark slab under a light map in light mode).
let cyMapPanelColor = CYColor.bgElevated

/// Panel height as a fraction of the available height. The grabber drags between them.
/// With a `peek` line the compact detent is only the grabber + that one line.
enum CYPanelDetent: CaseIterable { case compact, medium, large
    var fraction: CGFloat { switch self { case .compact: 0.30; case .medium: 0.58; case .large: 0.94 } }
}

/// Full-bleed map (any view) + glass controls on top + a bottom panel with three detents holding the
/// screen's list. `floating` sits just above the panel (the white GO circle / the one primary action).
/// Used by real screens whose existing sheets (details, entries) must keep working, so the panel is
/// in-view and never a second system sheet. The list inside keeps scrolling; only the grabber drags.
///
/// `peek`: when given, the compact detent is a small bar (grabber + this one line) and the panel
/// content stays mounted but hidden there; `floating` is only shown at the compact detent.
struct CYMapScaffold<Map: View, Controls: View, Floating: View, Panel: View>: View {
    private let map: Map, controls: Controls, floating: Floating, panel: Panel
    private let peek: AnyView?
    private let allowed: [CYPanelDetent]
    @State private var detent: CYPanelDetent
    @GestureState private var drag: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// E2E-20261113b N3: inside a tab the panel's visible content ends above the floating tab bar; its fill still runs under it.
    @Environment(\.cyTabBarClearance) private var tabBarClearance
    @ScaledMetric(relativeTo: .body) private var peekLine: CGFloat = 52
    /// Grabber row: a 44 pt drag/adjust target (the bar itself stays 40 x 5).
    private let grabberHeight: CGFloat = 44

    init(detent: CYPanelDetent = .medium, allowed: [CYPanelDetent] = CYPanelDetent.allCases, peek: AnyView? = nil,
         @ViewBuilder map: () -> Map, @ViewBuilder controls: () -> Controls,
         @ViewBuilder floating: () -> Floating, @ViewBuilder panel: () -> Panel) {
        self.map = map(); self.controls = controls(); self.floating = floating(); self.panel = panel()
        self.allowed = allowed
        self.peek = peek
        _detent = State(initialValue: detent)
    }
    private var effective: CYPanelDetent { peek == nil && type.isAccessibilitySize && detent == .compact ? .medium : detent }
    private func height(_ d: CYPanelDetent, total: CGFloat) -> CGFloat {
        if d == .compact, peek != nil { return min(grabberHeight + min(peekLine, 120), total * 0.3) }
        return total * d.fraction
    }
    private var pool: [CYPanelDetent] { allowed.isEmpty ? CYPanelDetent.allCases : allowed }
    private var isPeeking: Bool { peek != nil && effective == .compact }

    var body: some View {
        GeometryReader { geo in
            let base = height(effective, total: geo.size.height)
            let low = peek == nil ? geo.size.height * 0.22 : height(.compact, total: geo.size.height)
            let panelHeight = min(max(base - drag, low), geo.size.height * 0.96)
            ZStack(alignment: .bottom) {
                map.frame(maxWidth: .infinity, maxHeight: .infinity).clipped().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    controls.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm)
                        .padding(.bottom, CYSpacing.sm)
                        // Title and glass controls sit on a soft scrim so white text keeps 4.5:1 over any map tile.
                        .background(alignment: .top) {
                            LinearGradient(colors: [.black.opacity(0.62), .black.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom)
                                .padding(.bottom, -CYSpacing.lg).ignoresSafeArea(edges: .top).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // VoiceOver order (a11y-dt r3): top controls → floating actions (GO first inside) → panel → map pins.
                // Without containers the pins interleave with the floating buttons by position.
                .accessibilityElement(children: .contain).accessibilitySortPriority(3)
                floating.padding(.bottom, panelHeight + CYSpacing.lg)
                    .accessibilityElement(children: .contain).accessibilitySortPriority(2)
                    .opacity(peek != nil && !isPeeking ? 0 : 1)
                    .allowsHitTesting(!(peek != nil && !isPeeking))
                    .accessibilityHidden(peek != nil && !isPeeking)
                    .animation(reduceMotion ? nil : cyRoamSheetSnap, value: isPeeking)
                    .cyHaptic(.impactLight, trigger: effective)
                VStack(spacing: 0) {
                    grabber(total: geo.size.height)
                    ZStack(alignment: .top) {
                        panel.frame(maxWidth: .infinity, maxHeight: .infinity).frame(height: isPeeking ? geo.size.height * 0.58 : nil)
                            .opacity(isPeeking ? 0 : 1)
                            .allowsHitTesting(!isPeeking)
                            .accessibilityHidden(isPeeking)
                        if isPeeking, let peek {
                            peek.contentShape(Rectangle())
                                .accessibilityElement(children: .combine)
                                .onTapGesture { withAnimation(reduceMotion ? nil : cyRoamSheetSnap) { detent = .medium } }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint(Text("map.panel.size"))
                        }
                    }
                    .clipped()
                }
                .accessibilityElement(children: .contain).accessibilitySortPriority(1)
                .padding(.bottom, tabBarClearance)
                .frame(height: panelHeight + tabBarClearance, alignment: .top)
                .background(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                        .fill(cyMapPanelColor)
                        .shadow(color: .black.opacity(0.4), radius: 18, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    /// Spoken value of the grabber: which of the three sizes the panel is at.
    private func detentName(_ d: CYPanelDetent) -> LocalizedStringKey {
        switch d { case .compact: "map.panel.size.compact"; case .medium: "map.panel.size.medium"; case .large: "map.panel.size.large" }
    }

    private func grabber(total: CGFloat) -> some View {
        Capsule().fill(Color(uiColor: .tertiaryLabel)).frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: grabberHeight)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let target = height(effective, total: total) - value.translation.height
                    withAnimation(reduceMotion ? nil : cyRoamSheetSnap) { detent = pool.min { abs(height($0, total: total) - target) < abs(height($1, total: total) - target) } ?? .medium }
                })
            .accessibilityElement()
            .accessibilityLabel(Text("map.panel.size"))
            .accessibilityValue(Text(detentName(effective)))
            .accessibilityAdjustableAction { direction in
                guard let i = pool.firstIndex(of: detent) else { return }
                let next = direction == .increment ? min(i + 1, pool.count - 1) : max(i - 1, 0)
                withAnimation(reduceMotion ? nil : cyRoamSheetSnap) { detent = pool[next] }
            }
    }
}
