import SwiftUI
import MapKit

/// Plain distance text for the run: "120 m", "1.2 km", or an em dash when unknown.
enum CityOrientationFormat {
    static func distance(_ meters: Double?) -> String {
        guard let meters, meters.isFinite, meters >= 0 else { return "—" }
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        return String(format: "%.1f km", meters / 1000)
    }
}

private struct CityOrientationTeamsSinkKey: EnvironmentKey {
    static let defaultValue: (([TeamTrailTeam]) -> Void)? = nil
}

extension EnvironmentValues {
    /// The live run map listens to the teams the existing `TeamTrailSection` already polls.
    /// No second poller: the map only mirrors that section's last read.
    var cityOrientationTeamsSink: (([TeamTrailTeam]) -> Void)? {
        get { self[CityOrientationTeamsSinkKey.self] }
        set { self[CityOrientationTeamsSinkKey.self] = newValue }
    }
}

/// S9 live run (Apple Maps directions pattern): a full-bleed `Map` with numbered control points,
/// the route line, teammates and the user, a maneuver banner on top, and a bottom sheet with
/// `.height(120)` / `.medium` / `.large` detents that the caller fills (`panel`).
/// Reads only `PlayRouteMapPresentation` from the run's current snapshot. It sends nothing.
@MainActor struct CityOrientationRunView<Panel: View, Channel: View>: View {
    @Bindable var model: PlayExperienceCoordinator
    @ObservedObject var location: CityOrientationLocationObserver
    let teammates: [TeamTrailTeam]
    /// Already gated by the caller: false while another presentation of the run screen is up.
    @Binding var sheetShown: Bool
    var onOpenRoute: (() -> Void)?
    var onEnd: (() -> Void)?
    let onPunch: (Int) -> Void
    @ViewBuilder var channel: () -> Channel
    @ViewBuilder var panel: () -> Panel
    @State private var camera: MapCameraPosition = .automatic
    @State private var detent: PresentationDetent = .height(120)
    /// Motion r1: the route and team trails draw on when the run map appears.
    @State private var draw = NativeR2DrawOn()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private var route: PlayRouteMapPresentation? {
        guard let snapshot = model.snapshot else { return nil }
        return PlayRouteMapPresentation(snapshot: snapshot)
    }
    private var currentStop: PlayRouteMapPresentation.Stop? {
        guard let route, let id = route.currentNodeID else { return nil }
        return route.stops.first { $0.id == id }
    }
    private var currentDistance: Double? {
        guard let stop = currentStop else { return nil }
        return location.distance(toLatitude: stop.coordinate?.latitude, longitude: stop.coordinate?.longitude)
    }
    /// The 50 m highlight. It only changes the banner; it never punches (MP `STATION_HIGHLIGHT_METERS`).
    private var inHighlight: Bool {
        guard let distance = currentDistance else { return false }
        return distance <= PlayArrivalPolicy.stationHighlightMeters
    }

    var body: some View {
        map
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 8) {
                    banner
                    controls
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .sensoryFeedback(.success, trigger: inHighlight) { old, new in !old && new }
            .sheet(isPresented: $sheetShown) {
                panel()
                    .presentationDetents([.height(120), .medium, .large], selection: $detent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
            }
            .onAppear { location.start() }
            .onDisappear { location.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { location.start() } else { location.stop() }
            }
            .accessibilityIdentifier("nativeR2.city.run")
    }

    // MARK: map

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let route {
                ForEach(route.segments) { segment in
                    MapPolyline(coordinates: NativeR2RoutePath.leg(coordinate(segment.start), coordinate(segment.end),
                                                                   index: route.segments.firstIndex(where: { $0.id == segment.id }) ?? 0,
                                                                   count: route.segments.count, progress: draw.progress))
                        .stroke(segmentStyle(segment, in: route),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: segmentDash(segment, in: route)))
                }
                ForEach(route.mappedStops) { stop in
                    if let point = stop.coordinate {
                        Annotation(stopTitle(stop), coordinate: coordinate(point)) {
                            CityOrientationStopBadge(order: stop.order, state: stop.state)
                                .accessibilityIdentifier("nativeR2.city.pin.\(stop.id)")
                        }
                    }
                }
            }
            if let stop = currentStop, let point = stop.coordinate {
                // Before the start: the 300 m start lock. During the run: the 50 m highlight.
                MapCircle(center: coordinate(point),
                          radius: model.clock.phase == .idle ? PlayArrivalPolicy.startRadiusMeters : PlayArrivalPolicy.stationHighlightMeters)
                    .foregroundStyle(Color.accentColor.opacity(0.15))
            }
            if NativeR2Flags.motion {
                ForEach(teammates) { team in
                    if team.points.count > 1 {
                        MapPolyline(coordinates: NativeR2RoutePath.prefix(team.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                                                                          progress: draw.progress))
                            .stroke(NativeR2RoutePath.teamColor(team.colorIndex), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            ForEach(teammates) { team in
                if let last = team.points.last {
                    Annotation(team.name, coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                        Text(verbatim: teammateInitial(team))
                            .font(.caption.bold())
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(uiColor: .tertiarySystemFill)))
                            .accessibilityIdentifier("nativeR2.city.teammate.\(team.id)")
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .onAppear { fitCamera() }
        .task(id: route?.segments.count ?? 0) { await draw.run(reduceMotion: reduceMotion) }
        .accessibilityIdentifier("nativeR2.city.map")
    }

    private func fitCamera() {
        guard camera == .automatic, let route else { return }
        let points = route.mappedStops.compactMap(\.coordinate).map { coordinate($0) }
        guard !points.isEmpty else { return }
        camera = .region(CYMapRegion.boundingRegion(coordinates: points))
    }

    private func segmentStyle(_ segment: PlayRouteMapPresentation.Segment, in route: PlayRouteMapPresentation) -> AnyShapeStyle {
        segmentIsDone(segment, in: route) ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.accentColor)
    }
    /// Done and current legs are solid; legs further ahead are dashed (Maps' "later" style).
    private func segmentDash(_ segment: PlayRouteMapPresentation.Segment, in route: PlayRouteMapPresentation) -> [CGFloat] {
        if segmentIsDone(segment, in: route) { return [] }
        guard let index = route.stops.firstIndex(where: { $0.id == segment.id }), index + 1 < route.stops.count else { return [6, 5] }
        return route.stops[index + 1].id == route.currentNodeID ? [] : [6, 5]
    }
    private func segmentIsDone(_ segment: PlayRouteMapPresentation.Segment, in route: PlayRouteMapPresentation) -> Bool {
        guard let index = route.stops.firstIndex(where: { $0.id == segment.id }), index + 1 < route.stops.count else { return false }
        return route.stops[index].state == .completed && route.stops[index + 1].state == .completed
    }
    private func coordinate(_ value: PlayRouteMapPresentation.Coordinate) -> CLLocationCoordinate2D {
        .init(latitude: value.latitude, longitude: value.longitude)
    }
    private func stopTitle(_ stop: PlayRouteMapPresentation.Stop) -> String {
        if stop.state == .locked { return appLocalized("playRoute.lockedStop", locale: locale) }
        if let name = stop.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return appLocalized("playRoute.unnamedStop", locale: locale)
    }
    private func teammateInitial(_ team: TeamTrailTeam) -> String {
        if !team.initial.isEmpty { return team.initial }
        return team.name.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "·"
    }

    // MARK: banner and controls

    @ViewBuilder private var banner: some View {
        if let stop = currentStop {
            Button {
                if inHighlight { onPunch(stop.id) } else { onOpenRoute?() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: bannerSymbol)
                        .font(.title2)
                        .foregroundStyle(inHighlight ? Color.green : Color.accentColor)
                        .nativeR2SymbolReplace()
                        .nativeR2Bounce(inHighlight)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        if inHighlight {
                            Text("nativeR2.city.banner.arrived").font(.headline)
                        } else if location.access == .denied {
                            Text("nativeR2.city.banner.locationOff").font(.headline)
                        } else {
                            Text(verbatim: CityOrientationFormat.distance(currentDistance))
                                .font(.title2.bold())
                                .monospacedDigit()
                                .nativeR2RollingNumber(currentDistance ?? 0)
                        }
                        Text("nativeR2.city.banner.to \(stop.order) \(stopTitle(stop))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nativeR2.city.banner")
        }
    }
    private var bannerSymbol: String {
        if inHighlight { return "checkmark.circle.fill" }
        if location.access == .denied { return "location.slash" }
        return "figure.walk"
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            channel()
            if let onOpenRoute {
                Button(action: onOpenRoute) { Label("playRoute.open", systemImage: "map") }
                    .accessibilityIdentifier("playRoute.open")
            }
            if let onEnd, model.clock.phase != .ended {
                Button(action: onEnd) { Label("playx.run.end", systemImage: "flag.checkered") }
                    .disabled(!model.canManageRun)
                    .accessibilityIdentifier("playx.run.end")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
}

/// A numbered control point: done shows a checkmark (green), current uses the accent, locked a lock (gray).
struct CityOrientationStopBadge: View {
    let order: Int
    let state: PlayRouteMapPresentation.State
    var body: some View {
        ZStack {
            Circle().fill(fill)
            switch state {
            case .completed: Image(systemName: "checkmark")
            case .locked: Image(systemName: "lock.fill")
            default: Text(verbatim: String(order)).monospacedDigit()
            }
        }
        .font(.caption.bold())
        .foregroundStyle(.white)
        .frame(width: 30, height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String(order)) + Text(verbatim: ", ") + Text(LocalizedStringKey(state.labelKey)))
    }
    private var fill: Color {
        switch state {
        case .completed: return .green
        case .current: return .accentColor
        case .locked: return .gray
        case .available, .unknown: return .secondary
        }
    }
}

/// S9 peek row (Fitness live metrics): run clock, walked distance and points done, plus the caller's buttons.
@MainActor struct CityOrientationRunMetricsRow<Trailing: View>: View {
    @Bindable var model: PlayExperienceCoordinator
    let walkedMeters: Double
    @ViewBuilder var trailing: () -> Trailing

    private var doneCount: Int {
        guard let snapshot = model.snapshot else { return 0 }
        return snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
    }
    private var points: String {
        guard let snapshot = model.snapshot, !snapshot.visibleNodes.isEmpty else { return "—" }
        let done = snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
        return "\(done)/\(snapshot.visibleNodes.count)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                // The run clock ticks from the monotonic anchor; pausing stops it (PlayRunClock).
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(verbatim: PlayRunElapsedText.format(model.clock.elapsed(monotonicNow: ProcessInfo.processInfo.systemUptime)))
                        .font(.title2.bold().monospacedDigit())
                        .accessibilityAddTraits(.updatesFrequently)
                        .accessibilityIdentifier("playx.run.clock")
                }
                Text(model.clock.phase == .paused ? "nativeR2.city.paused" : "nativeR2.city.metric.time")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: walkedMeters > 0 ? CityOrientationFormat.distance(walkedMeters) : "—")
                    .font(.title2.bold().monospacedDigit())
                    .nativeR2RollingNumber(walkedMeters)
                Text("nativeR2.city.metric.distance").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: points).font(.title2.bold().monospacedDigit())
                    .nativeR2RollingNumber(Double(doneCount))
                Text("nativeR2.city.metric.points").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .opacity(model.clock.phase == .paused ? 0.6 : 1)
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nativeR2.city.metrics")
    }
}

/// S9 medium detent: the next control point with its requirement, distance and hint.
@MainActor struct CityOrientationNextStopSection: View {
    let node: PlayNode
    let snapshot: PlaySnapshot
    let distance: Double?
    let onPunch: () -> Void
    let onHint: () -> Void
    var body: some View {
        Section("nativeR2.city.next") {
            Button(action: onPunch) {
                LabeledContent {
                    Text(verbatim: CityOrientationFormat.distance(distance)).monospacedDigit()
                } label: {
                    Text(verbatim: node.name ?? "#\(node.id)")
                    Text(LocalizedStringKey("playx.task." + PlayNodeTask.resolve(mode: snapshot.result.mode, node: node).rawValue))
                }
                .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("referenceTask.open")
            if let address = node.address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
                Label { Text(verbatim: address) } icon: { Image(systemName: "mappin.and.ellipse") }
                    .foregroundStyle(.secondary)
            }
            if let reason = snapshot.lockReason(node), snapshot.isLocked(node) {
                Label { Text(verbatim: reason) } icon: { Image(systemName: "lock") }
                    .foregroundStyle(.secondary)
            }
            Button(action: onHint) { Label("playHUD.hint", systemImage: "lightbulb") }
                .accessibilityIdentifier("playHUD.hint")
        }
    }
}

/// S9 large detent: every control point in route order (the Fitness "Segments" list).
/// Each row keeps the station identifier `playx.node.<id>`.
@MainActor struct CityOrientationLegsSection: View {
    let route: PlayRouteMapPresentation
    /// Nil shows read-only rows (finish summary).
    var onOpen: ((Int) -> Void)? = nil
    @Environment(\.locale) private var locale
    var body: some View {
        Section("nativeR2.city.legs") {
            ForEach(route.stops) { stop in
                if let onOpen {
                    Button { onOpen(stop.id) } label: { row(stop).foregroundStyle(.primary) }
                        .accessibilityIdentifier("playx.node.\(stop.id)")
                } else {
                    row(stop).accessibilityIdentifier("nativeR2.city.leg.\(stop.id)")
                }
            }
        }
    }
    private func row(_ stop: PlayRouteMapPresentation.Stop) -> some View {
        LabeledContent {
            Text(LocalizedStringKey(stop.state.labelKey))
        } label: {
            Label {
                Text(verbatim: "\(stop.order) · " + name(stop))
            } icon: {
                Image(systemName: stop.state.symbol)
                    .foregroundStyle(stop.state == .completed ? Color.green : stop.state == .current ? Color.accentColor : Color.secondary)
            }
        }
    }
    private func name(_ stop: PlayRouteMapPresentation.Stop) -> String {
        if stop.state == .locked { return appLocalized("playRoute.lockedStop", locale: locale) }
        if let name = stop.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return appLocalized("playRoute.unnamedStop", locale: locale)
    }
}

/// S9 large detent: teams sharing their route on this activity (Find My people rows).
struct CityOrientationTeammatesSection: View {
    let teams: [TeamTrailTeam]
    var body: some View {
        Section {
            ForEach(teams) { team in
                LabeledContent {
                    if team.done > 0 { Text("playerGap.trail.done \(team.done)") }
                } label: {
                    Label { Text(verbatim: team.name) } icon: { Image(systemName: "person.crop.circle") }
                }
            }
        } header: {
            Text("nativeR2.city.teammates")
        } footer: {
            if teams.isEmpty { Text("nativeR2.city.teammates.none") }
        }
        .accessibilityIdentifier("nativeR2.city.teammates")
    }
}
