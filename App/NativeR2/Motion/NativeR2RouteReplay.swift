import SwiftUI
import MapKit

/// One walked leg of a city-orientation route, between two control points in route order.
struct NativeR2RouteLeg: Identifiable {
    let id: Int
    let order: Int
    let title: String
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    var meters: Double { NativeR2RoutePath.meters(start, end) }

    /// Legs whose two control points are both done, in route order. Reads only the presentation.
    static func walked(in route: PlayRouteMapPresentation, locale: Locale) -> [NativeR2RouteLeg] {
        var legs: [NativeR2RouteLeg] = []
        for segment in route.segments {
            guard let index = route.stops.firstIndex(where: { $0.id == segment.id }), index + 1 < route.stops.count else { continue }
            let from = route.stops[index], to = route.stops[index + 1]
            guard from.state == .completed, to.state == .completed else { continue }
            let name = to.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            legs.append(NativeR2RouteLeg(
                id: segment.id, order: legs.count + 1,
                title: name.isEmpty ? appLocalized("playRoute.unnamedStop", locale: locale) : name,
                start: CLLocationCoordinate2D(latitude: segment.start.latitude, longitude: segment.start.longitude),
                end: CLLocationCoordinate2D(latitude: segment.end.latitude, longitude: segment.end.longitude)))
        }
        return legs
    }
}

/// M1 route replay (Fitness route map + Maps directions list): the walked route draws itself leg by
/// leg, the camera follows the drawing head and ends on the finish, the time and distance counters
/// roll with it, and the result rests in a system bottom sheet with every leg and its distance.
/// Display only: it reads the finish summary's values and sends nothing.
@MainActor struct NativeR2RouteReplayView: View {
    let legs: [NativeR2RouteLeg]
    let totalSeconds: Int
    let walkedMeters: Double
    var tint: Color = .accentColor
    @State private var draw = NativeR2DrawOn()
    @State private var camera: MapCameraPosition = .automatic
    @State private var shownLegs = 0
    @State private var focusLeg: Int?
    @State private var replayToken = 0
    @State private var arrivals = 0
    @State private var showsResult = false
    @State private var detent: PresentationDetent = .height(200)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var legMeters: Double { legs.reduce(0) { $0 + $1.meters } }
    private var totalMeters: Double { walkedMeters > 0 ? walkedMeters : legMeters }
    private var finished: Bool { draw.progress >= 1 }
    private var drawnLegs: Int {
        finished ? legs.count : min(legs.count, Int(draw.progress * Double(legs.count)))
    }
    private var headLeg: Int { min(max(0, legs.count - 1), drawnLegs) }
    private var currentLeg: Int { focusLeg ?? headLeg }
    /// Share of the route drawn so far, by leg length; the counters scale the real totals by it.
    private var share: Double {
        guard !legs.isEmpty, shownLegs < legs.count else { return 1 }
        let done = legs.prefix(shownLegs).reduce(0) { $0 + $1.meters }
        return legMeters > 0 ? done / legMeters : Double(shownLegs) / Double(legs.count)
    }
    private var shownSeconds: Int { Int((Double(totalSeconds) * share).rounded()) }
    private var shownMeters: Double { totalMeters * share }
    private var duration: TimeInterval { min(8, max(1.6, 0.8 * Double(legs.count))) }

    var body: some View {
        Group {
            if legs.isEmpty {
                ContentUnavailableView("nativeR2.motion.empty", systemImage: "map")
            } else {
                map
                    .safeAreaInset(edge: .top, spacing: 0) {
                        counters.padding(.horizontal).padding(.top, 8)
                    }
                    .toolbar { toolbar }
                    .task(id: replayToken) { await replay() }
                    .onChange(of: drawnLegs) { _, value in
                        withAnimation(reduceMotion ? nil : .smooth) { shownLegs = value }
                    }
                    .onChange(of: headLeg) { _, leg in
                        if focusLeg == nil, !finished { follow(leg) }
                    }
                    .sheet(isPresented: $showsResult) { resultSheet }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { showsResult = false }
        .accessibilityIdentifier("nativeR2.motion.replay")
    }

    private var title: Text {
        legs.isEmpty ? Text("nativeR2.motion.result.title") : Text("nativeR2.motion.leg \(currentLeg + 1) \(legs.count)")
    }

    private func replay() async {
        focusLeg = nil
        shownLegs = 0
        camera = .region(CYMapRegion.boundingRegion(coordinates: legs.flatMap { [$0.start, $0.end] }))
        if !reduceMotion, NativeR2Flags.motion { follow(0) }
        await draw.run(duration: duration, reduceMotion: reduceMotion)
        guard !Task.isCancelled else { return }
        shownLegs = legs.count
        if let last = legs.last {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.8)) {
                camera = .camera(MapCamera(centerCoordinate: last.end, distance: 900))
            }
        }
        arrivals += 1
        showsResult = true
    }

    private func follow(_ index: Int) {
        guard legs.indices.contains(index) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: max(0.4, duration / Double(max(1, legs.count))))) {
            camera = .camera(MapCamera(centerCoordinate: legs[index].end, distance: 1500))
        }
    }

    private func focus(_ index: Int) {
        guard legs.indices.contains(index) else { return }
        focusLeg = index
        let leg = legs[index]
        withAnimation(reduceMotion ? nil : .smooth) {
            camera = .region(CYMapRegion.boundingRegion(coordinates: [leg.start, leg.end], minimumSpan: 0.004))
        }
    }

    // MARK: map

    private var map: some View {
        Map(position: $camera) {
            ForEach(legs) { leg in
                // Upcoming: dashed preview. Drawn: solid, trimmed to the drawing head.
                MapPolyline(coordinates: [leg.start, leg.end])
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
                MapPolyline(coordinates: NativeR2RoutePath.leg(leg.start, leg.end, index: leg.order - 1,
                                                               count: legs.count, progress: draw.progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: leg.order - 1 == focusLeg ? 7 : 5, lineCap: .round, lineJoin: .round))
            }
            if let first = legs.first {
                Marker("nativeR2.motion.start", systemImage: "figure.walk", coordinate: first.start)
            }
            if let last = legs.last {
                Annotation("nativeR2.motion.finish", coordinate: last.end) {
                    NativeR2ArrivalMark(tint: tint, trigger: arrivals)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .accessibilityIdentifier("nativeR2.motion.replay.map")
    }

    /// Top card: time and distance roll up as the route draws.
    private var counters: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("nativeR2.motion.time").font(.caption).foregroundStyle(.secondary)
                Text(verbatim: PlayRunElapsedText.format(shownSeconds))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .nativeR2RollingNumber(Double(shownSeconds))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 2) {
                Text("nativeR2.motion.distance").font(.caption).foregroundStyle(.secondary)
                Text(verbatim: CityOrientationFormat.distance(shownMeters))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .nativeR2RollingNumber(shownMeters)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityIdentifier("nativeR2.motion.counters")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { focus(currentLeg - 1) } label: { Label("nativeR2.motion.prev", systemImage: "chevron.up") }
                .disabled(!finished || currentLeg <= 0)
                .accessibilityIdentifier("nativeR2.motion.prev")
            Button { focus(currentLeg + 1) } label: { Label("nativeR2.motion.next", systemImage: "chevron.down") }
                .disabled(!finished || currentLeg >= legs.count - 1)
                .accessibilityIdentifier("nativeR2.motion.next")
        }
    }

    // MARK: result sheet

    private var resultSheet: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: CityOrientationFormat.distance(totalMeters))
                            .font(.largeTitle.bold())
                            .monospacedDigit()
                        Text("nativeR2.motion.result.sentence \(legs.count)")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            NativeR2Chip(systemImage: "timer") { Text(verbatim: PlayRunElapsedText.format(totalSeconds)) }
                            NativeR2Chip(systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                                Text("nativeR2.motion.result.legs \(legs.count)")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("nativeR2.motion.result")
                }
                Section("nativeR2.motion.legs") {
                    ForEach(legs) { leg in
                        Button {
                            focus(leg.order - 1)
                            detent = .height(200)
                        } label: {
                            Label {
                                Text(verbatim: leg.title).foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: leg.order <= 50 ? "\(leg.order).circle.fill" : "circle.fill")
                                    .foregroundStyle(leg.order - 1 == currentLeg ? tint : Color.secondary)
                            }
                        }
                        .badge(Text(verbatim: CityOrientationFormat.distance(leg.meters)))
                        .accessibilityIdentifier("nativeR2.motion.leg.\(leg.order)")
                    }
                }
            }
            .navigationTitle(Text("nativeR2.motion.result.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { replayToken += 1 } label: { Label("nativeR2.motion.replayAgain", systemImage: "arrow.counterclockwise") }
                        .accessibilityIdentifier("nativeR2.motion.replayAgain")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("nativeR2.motion.done") { showsResult = false }
                        .accessibilityIdentifier("nativeR2.motion.done")
                }
            }
        }
        .presentationDetents([.height(200), .medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .cySheetBackdropExempt()
    }
}

/// A result chip: a system `Label` on the tertiary fill capsule.
struct NativeR2Chip<Title: View>: View {
    let systemImage: String
    @ViewBuilder var title: () -> Title

    var body: some View {
        Label { title() } icon: { Image(systemName: systemImage) }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.fill.tertiary, in: Capsule())
    }
}

/// Finish / meeting point on the map: a bouncing flag inside a pulsing dashed ring, with a success
/// haptic each time `trigger` changes. Reduce Motion: still symbols, haptic kept.
@MainActor struct NativeR2ArrivalMark: View {
    let tint: Color
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animates: Bool { NativeR2Flags.motion && !reduceMotion }

    var body: some View {
        ZStack {
            Image(systemName: "circle.dashed")
                .font(.largeTitle)
                .foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeat(2), isActive: animates && trigger > 0)
            Image(systemName: "flag.checkered.circle.fill")
                .font(.title)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, tint)
                .symbolEffect(.bounce, value: animates ? trigger : 0)
        }
        .accessibilityHidden(true)
        .sensoryFeedback(.success, trigger: trigger)
    }
}
