import SwiftUI
import MapKit
import UIKit

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
    /// P-053: the peek grows with Dynamic Type so the metrics row is never clipped at accessibility sizes.
    @ScaledMetric(relativeTo: .title2) private var peekHeight: CGFloat = 120
    /// P-052: a tapped control-point marker opens its punch sheet.
    @State private var selectedStop: Int?
    /// Motion r1: the route and team trails draw on when the run map appears.
    @State private var draw = NativeR2DrawOn()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

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
                    .presentationDetents([.height(peekHeight), .medium, .large], selection: $detent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
            }
            // P-050: the session is owned by the play screen; leaving this view (a pushed page) or the
            // foreground does not stop it. Background reading is gated by the session's active run.
            .onAppear {
                location.start()
                if detent == .height(120), peekHeight != 120 { detent = .height(peekHeight) }
            }
            .onChange(of: peekHeight) { old, new in
                if detent == .height(old) { detent = .height(new) }
            }
            .onDisappear {
                QuestLiveActivityCenter.shared.clearPlayContext()
                QuestLiveActivityCenter.shared.setCheckInHandler(nil)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { location.start() }
            }
            // Native r2 M4: Dynamic Island shows this run as an orientation run with the distance to the next control point.
            .onChange(of: currentDistance, initial: true) { _, meters in
                QuestLiveActivityCenter.shared.setPlayContext(mode: .orientation, nextDistanceMeters: meters, arrived: inHighlight)
            }
            // Components r1 C1: the Live Activity 打卡 button opens this stop's punch sheet (same as the arrival island).
            .onChange(of: currentStop?.id, initial: true) { _, id in
                if let id {
                    QuestLiveActivityCenter.shared.setCheckInHandler { onPunch(id) }
                } else {
                    QuestLiveActivityCenter.shared.setCheckInHandler(nil)
                }
            }
            // Native r2 M4: entering the 50 m highlight pops an arrival island whose action opens the same punch sheet.
            .onChange(of: inHighlight) { old, new in
                guard !old, new, let stop = currentStop else { return }
                // P-054: VoiceOver hears the arrival. The island announces itself; without it, post here.
                if !IslandCenter.isEnabled {
                    AccessibilityNotification.Announcement(
                        appLocalized("island.arrival.punch", locale: locale) + ", " + stopTitle(stop)).post()
                }
                IslandCenter.shared.show(IslandItem(kind: .arrival, title: .key("island.arrival.punch"),
                                                    subtitle: .verbatim(stopTitle(stop)),
                                                    actions: [IslandAction(title: .key("island.arrival.punch.action"),
                                                                           systemImage: "checkmark.seal", prominent: true) { onPunch(stop.id) }],
                                                    open: { onPunch(stop.id) }, lifetime: .seconds(6),
                                                    dedupeKey: "arrival.punch", startsExpanded: true))
            }
            .accessibilityIdentifier("nativeR2.city.run")
    }

    // MARK: map

    private var map: some View {
        Map(position: $camera, selection: $selectedStop) {
            UserAnnotation()
            if let route {
                ForEach(route.segments) { segment in
                    MapPolyline(coordinates: NativeR2RoutePath.leg(coordinate(segment.start), coordinate(segment.end),
                                                                   index: route.segments.firstIndex(where: { $0.id == segment.id }) ?? 0,
                                                                   count: route.segments.count, progress: draw.progress))
                        .stroke(segmentStyle(segment, in: route),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: segmentDash(segment, in: route)))
                }
                // P-052: system Markers (Maps balloons, system contrast and size): the order as a monogram,
                // a checkmark when done, a lock when locked. Tapping one opens its punch sheet.
                ForEach(route.mappedStops) { stop in
                    if let point = stop.coordinate {
                        if stop.state == .completed {
                            Marker(stopTitle(stop), systemImage: "checkmark", coordinate: coordinate(point))
                                .tint(Color.green)
                                .tag(stop.id)
                        } else if stop.state == .locked {
                            Marker(stopTitle(stop), systemImage: "lock.fill", coordinate: coordinate(point))
                                .tint(Color.gray)
                                .tag(stop.id)
                        } else {
                            Marker(stopTitle(stop), monogram: Text(verbatim: String(stop.order)), coordinate: coordinate(point))
                                .tint(stop.state == .current ? Color.accentColor : Color.gray)
                                .tag(stop.id)
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
        // fix-r11 N-r11-2 / comp-r1 C6: no locate-me control, as in the MP (subpackageRoam/session/index.wxml:27,
        // components/cy/route-thumb/index.wxml:6 `show-location="{{false}}"`; only 开启定位 when location is off).
        .mapControls {
            MapCompass()
            MapPitchToggle()
        }
        .onAppear { fitCamera() }
        .onChange(of: selectedStop) { _, id in
            guard let id else { return }
            selectedStop = nil
            onPunch(id)
        }
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
            // P-055: the banner always opens the punch sheet (it never punches by itself); the route map
            // stays one tap away in the controls below.
            Button {
                onPunch(stop.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: bannerSymbol)
                        .font(.title2)
                        .foregroundStyle(inHighlight ? Color.green : Color.accentColor)
                        .nativeR2SymbolReplace()
                        .nativeR2Bounce(inHighlight)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        if model.clock.phase == .paused { CityOrientationPausedTag() }
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
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        // MP index.wxml:600-604: 公里 · 预计 · 到达, estimated at walking pace.
                        if !inHighlight, location.access != .denied {
                            CityOrientationETAText(meters: currentDistance)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("nativeR2.city.banner.hint"))
            .accessibilityIdentifier("nativeR2.city.banner")
        }
    }
    private var bannerSymbol: String {
        if model.clock.phase == .paused { return "pause.circle" }
        if inHighlight { return "checkmark.circle.fill" }
        if location.access == .denied { return "location.slash" }
        return "figure.walk"
    }

    private var controls: some View {
        HStack(spacing: 8) {
            // Design pass roam (P6): the other teams on this route sit next to the map controls.
            if !teammates.isEmpty {
                CityOrientationTeamStack(teams: teammates)
            }
            Spacer(minLength: 0)
            // MP pages/roam/index.wxml:150: the only location control is 开启定位, shown while location is off.
            if location.access == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: { Label("nativeR2.city.enableLocation", systemImage: "location.slash") }
                    .accessibilityIdentifier("nativeR2.city.enableLocation")
            }
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

/// S9 peek row (Fitness live metrics): run clock, walked distance and points done, plus the caller's buttons.
@MainActor struct CityOrientationRunMetricsRow<Trailing: View>: View {
    @Bindable var model: PlayExperienceCoordinator
    let walkedMeters: Double
    /// design-r2-play P1: metres to the current stop; before any walking the distance cell leads with it.
    var nextStopMeters: Double? = nil
    @ViewBuilder var trailing: () -> Trailing
    /// Paused dims the stats only; the primary (Continue) keeps full strength (P3).
    private var statsOpacity: Double { model.clock.phase == .paused ? 0.6 : 1 }
    private var leadsWithNextStop: Bool { walkedMeters <= 0 && nextStopMeters != nil }

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
        // P-053: one row when it fits; at large Dynamic Type sizes a two-column grid, then a stack, so the
        // values never truncate or overflow the peek.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                clockCell
                distanceCell
                pointsCell
                Spacer(minLength: 0)
                trailing()
            }
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        clockCell
                        distanceCell
                    }
                    GridRow {
                        pointsCell
                    }
                }
                trailing()
            }
            VStack(alignment: .leading, spacing: 12) {
                clockCell
                distanceCell
                pointsCell
                trailing()
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nativeR2.city.metrics")
    }

    private var clockCell: some View {
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
        .fixedSize()
        .opacity(statsOpacity)
    }
    private var distanceCell: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: CityOrientationFormat.distance(walkedMeters > 0 ? walkedMeters : (nextStopMeters ?? 0)))
                .font(.title2.bold().monospacedDigit())
                .nativeR2RollingNumber(walkedMeters > 0 ? walkedMeters : (nextStopMeters ?? 0))
            Text(leadsWithNextStop ? "designR2Play.city.metric.toNext" : "nativeR2.city.metric.distance")
                .font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize()
        .opacity(statsOpacity)
    }
    private var pointsCell: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: points).font(.title2.bold().monospacedDigit())
                .nativeR2RollingNumber(Double(doneCount))
            Text("nativeR2.city.metric.points").font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize()
        .opacity(statsOpacity)
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
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: CityOrientationFormat.distance(distance))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: distance ?? 0))
                        CityOrientationETAText(meters: distance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
    /// Design pass roam (P4): the live run folds punched stops into 已完成 (n); the past stays one tap away.
    @State private var showsDone = false

    private var doneStops: [PlayRouteMapPresentation.Stop] { route.stops.filter { $0.state == .completed } }
    private var openStops: [PlayRouteMapPresentation.Stop] { route.stops.filter { $0.state != .completed } }

    var body: some View {
        Section {
            if onOpen != nil {
                ForEach(openStops) { stop in stopRow(stop) }
                if !doneStops.isEmpty {
                    DisclosureGroup(isExpanded: $showsDone) {
                        ForEach(doneStops) { stop in stopRow(stop) }
                    } label: {
                        Label {
                            Text("design.roam.doneSection \(doneStops.count)")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
                        }
                    }
                    .accessibilityIdentifier("nativeR2.city.legs.done")
                }
            } else {
                ForEach(route.stops) { stop in stopRow(stop) }
            }
        } header: {
            header
        }
    }

    /// Steps header: 打卡点 · N / M with a small progress ring ("2 of 5", R-steps).
    private var header: some View {
        HStack(spacing: CYSpacing.sm) {
            Text("nativeR2.city.legs")
            Spacer(minLength: CYSpacing.sm)
            if !route.stops.isEmpty {
                Text("design.roam.stepsProgress \(doneStops.count) \(route.stops.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(doneStops.count)))
                CYRing(progress: Double(doneStops.count) / Double(route.stops.count),
                       label: "design.roam.stepsRing", tint: Color.green, diameter: 18, lineWidth: 3) {
                    EmptyView()
                }
                .accessibilityHidden(true)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func stopRow(_ stop: PlayRouteMapPresentation.Stop) -> some View {
        if let onOpen {
            Button { onOpen(stop.id) } label: { row(stop).foregroundStyle(.primary) }
                .accessibilityIdentifier("playx.node.\(stop.id)")
        } else {
            row(stop).accessibilityIdentifier("nativeR2.city.leg.\(stop.id)")
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
    /// Control points on the route; 0 shows the count only (comp-r1 C6 team progress).
    var total: Int = 0
    var body: some View {
        Section {
            ForEach(teams) { team in
                CityOrientationTeamProgressRow(team: team, total: total)
            }
        } header: {
            Text("nativeR2.city.teammates")
        } footer: {
            if teams.isEmpty { Text("nativeR2.city.teammates.none") }
        }
        .accessibilityIdentifier("nativeR2.city.teammates")
    }
}

/// Design pass roam (P6 other people are present): up to three team initials in their trail colours and
/// "N 队在路上". One VoiceOver element. Reads the same `TeamTrailSection` poll as the map; sends nothing.
struct CityOrientationTeamStack: View {
    let teams: [TeamTrailTeam]
    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            HStack(spacing: -8) {
                ForEach(teams.prefix(3)) { team in
                    Text(verbatim: initial(team))
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(NativeR2RoutePath.teamColor(team.colorIndex)))
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
            Text("design.roam.teamsOnRoute \(teams.count)")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, CYSpacing.sm)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nativeR2.city.teamStack")
    }
    private func initial(_ team: TeamTrailTeam) -> String {
        if !team.initial.isEmpty { return team.initial }
        return team.name.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "·"
    }
}
