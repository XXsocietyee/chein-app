import SwiftUI
import Observation

@MainActor struct SearchRoutePreviewView: View {
    @Environment(\.walkingNavigationFactory) private var walkingFactory
    let origin: RoamCoordinate
    let destination: RoamCoordinate
    let name: String
    let scope: UUID
    var navigationReference: WalkingTargetReference? = nil
    var offline = false
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var planner: (any SearchRoutePlanning)? = nil
    // Only an approved host may provide the origin's coordinate context. Untyped
    // search centers retain the unavailable preview; never infer datum from a target.
    var previewOriginContext: WalkingCoordinate? = nil
    @State private var loader = SearchRoutePreviewLoader()
    var request: SearchRouteRequest? {
        SearchRouteRequest.walkingPreview(origin: origin, originContext: previewOriginContext,
                                          destination: destination)
    }
    private var input: SearchRoutePreviewLoader.Input {
        .init(request: request, scope: scope, reference: navigationReference)
    }
    var body: some View {
        let input = self.input
        let owner = loader.capture(for: input)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PlatformExternalMapHost(destination: .init(name: name, latitude: destination.latitude, longitude: destination.longitude), scope: scope, makeModel: makeExternalMaps)
                Text("searchMap.routeOriginDisclosure").font(.footnote).foregroundStyle(.secondary)
                Text("searchMap.mode.walking").font(.headline).accessibilityAddTraits(.isHeader)
                if let navigationReference, let walkingFactory, walkingFactory.available {
                    NavigationLink {
                        WalkingNavigationView(reference: navigationReference, factory: walkingFactory, offline: offline)
                    } label: { Label("walking.title", systemImage: "figure.walk").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("walking.open")
                }
                if let walkingFactory, walkingFactory.available, !offline {
                    WalkingSavedDestinationSection(factory: walkingFactory)
                        .id(walkingFactory.checkpointPresentationID)
                }
                if owner != nil, let route = loader.route {
                    SearchMapCanvas(area: RoamSearchArea(coordinate: origin, label: ""),
                        pins: [SearchMapPin(id: "destination", title: name, coordinate: destination, symbol: "mappin")],
                        polyline: route.coordinates, offline: offline)
                    Text("searchMap.roadRoute").font(.headline).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("searchMap.route.kind")
                    LabeledContent("searchMap.distance") { Text(Measurement(value: route.distanceMeters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road)) }
                    if let eta = route.etaSeconds { LabeledContent("searchMap.etaMinutes") { Text(max(1, (eta / 60).rounded()), format: .number.precision(.fractionLength(0))) } }
                    ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text(verbatim: "\(index + 1)").font(.body).monospacedDigit().foregroundStyle(.tertiary)
                            Text(verbatim: step.instruction).font(.body).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Text(Measurement(value: step.distanceMeters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                                .font(.body).monospacedDigit().foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                } else if owner != nil, loader.failed {
                    SearchMapIssue(key: "walking.previewUnavailable") {
                        // Capture the current owner at the click, before this Task can queue.
                        guard let retryOwner = loader.capture(for: input) else { return }
                        Task { await load(retryOwner) }
                    }
                }
                else { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("searchMap.loading")) }
                Text("searchMap.routeBoundary").font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
            .navigationTitle(Text(verbatim: name))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loader.appear(input) }
            .onChange(of: input) { _, current in loader.update(current) }
            .task(id: owner) {
                guard let owner else { return }
                await load(owner)
            }
            .onDisappear { loader.disappear() }
    }
    private func load(_ owner: SearchRoutePreviewLoader.Owner) async {
        await loader.load(owner) {
            planner ?? owner.input.reference.flatMap { walkingFactory?.makePreviewPlanner(reference: $0) }
        }
    }
}


/// Reading this local reference never requests a route, a device fix, or new authorization.
@MainActor private struct WalkingSavedDestinationSection: View {
    let factory: NativeWalkingNavigationFactory
    @State private var saved: WalkingSavedDestination?
    @State private var failed = false
    @State private var attempted = false
    @State private var confirmsRemoval = false
    @State private var readGate = WalkingCheckpointReadGate()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let offered = readGate.ticket
        VStack(alignment: .leading, spacing: 8) {
            if let saved, factory.savedDestinationIsCurrent(saved) {
                NavigationLink {
                    WalkingNavigationView(reference: saved.record.reference, factory: factory,
                                          restoringDestination: saved)
                } label: { Label("walking.saved.open", systemImage: "bookmark") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("walking.saved.open")
                Text("walking.saved.notice").font(.footnote).foregroundStyle(.secondary)
                Button(role: .destructive) { confirmsRemoval = true } label: { Text("walking.saved.remove") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("walking.saved.remove")
                    .confirmationDialog(Text("walking.saved.remove"), isPresented: $confirmsRemoval, titleVisibility: .visible) {
                        Button(role: .destructive) {
                            do { try factory.removeSavedDestination(saved); self.saved = nil; failed = false }
                            catch { failed = true }
                        } label: { Text("walking.saved.remove") }
                        .accessibilityIdentifier("walking.saved.remove.confirm")
                    }
            }
            if failed {
                Text("walking.saved.failed").font(.subheadline).accessibilityIdentifier("walking.saved.failed")
                Button { load(offered) } label: { Label("walking.saved.retryRead", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .disabled(offered == nil || !factory.available)
                    .accessibilityIdentifier("walking.saved.retryRead")
            }
        }
        .onAppear { readGate.appear(active: scenePhase == .active); load(readGate.ticket) }
        .onDisappear { readGate.disappear() }
        .onChange(of: scenePhase) { _, value in
            readGate.setActive(value == .active)
            if !attempted { load(readGate.ticket) }
        }
    }
    private func load(_ offered: UUID?) {
        guard readGate.accepts(offered), factory.available else { return }
        attempted = true
        do { saved = try readGate.read(offered, factory: factory); failed = false }
        catch { failed = true }
    }
}

/// A synchronous local-read gesture belongs to one visible visit. Retiring a visit
/// keeps rendered values intact so a pushed destination is not removed by its parent.
@MainActor @Observable final class WalkingCheckpointReadGate {
    private var visit = UUID()
    private var visible = false
    private var active = false
    var ticket: UUID? { visible && active ? visit : nil }
    func appear(active: Bool) { visit = UUID(); visible = true; self.active = active }
    func disappear() { visit = UUID(); visible = false; active = false }
    func setActive(_ value: Bool) {
        if !value { visit = UUID() }
        active = value
    }
    func accepts(_ offered: UUID?) -> Bool {
        guard let offered else { return false }
        return visible && active && offered == visit
    }
    func read(_ offered: UUID?, factory: NativeWalkingNavigationFactory) throws -> WalkingSavedDestination? {
        guard accepts(offered), factory.available else { throw WalkingCheckpointFailure.unavailable }
        return try factory.savedDestination()
    }
    func restore(_ offered: UUID?, saved: WalkingSavedDestination,
                 factory: NativeWalkingNavigationFactory) -> WalkingNavigationCoordinator? {
        guard accepts(offered), factory.savedDestinationIsCurrent(saved) else { return nil }
        return factory.restoreSavedDestination(saved)
    }
}
