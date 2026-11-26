import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// S6 官方路线 list, pushed in the sheet. Same read as `OfficialRouteListView` (`OfficialRouteReader.list`).
@MainActor struct RoamMapHomeRoutesList: View {
    let reader: OfficialRouteReader
    @Bindable var model: RoamMapHomeModel
    private enum LoadState: Equatable { case loading, ready([OfficialRoute]), empty, failed, offline }
    @State private var state: LoadState = .loading

    var body: some View {
        List {
            switch state {
            case .loading:
                ForEach(0..<4, id: \.self) { _ in
                    Label("nativeR2.mapHome.loading", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .redacted(reason: .placeholder)
                }
            case .ready(let routes):
                ForEach(routes) { route in
                    NavigationLink(value: RoamMapHomeRoute.officialRoute(route.id)) { row(route) }
                        .accessibilityIdentifier("officialRoute.row." + route.id)
                }
            case .empty:
                ContentUnavailableView("nativeR2.mapHome.routes.empty", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            case .failed, .offline:
                ContentUnavailableView {
                    Label(state == .offline ? LocalizedStringKey("nativeR2.mapHome.offline") : LocalizedStringKey("nativeR2.mapHome.routes.failed"),
                          systemImage: state == .offline ? "wifi.slash" : "exclamationmark.triangle")
                } actions: {
                    Button("action.retry") { Task { await load() } }.buttonStyle(.bordered)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("nativeR2.mapHome.officialRoutes"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load(refreshing: true) }
        .accessibilityIdentifier("officialRoute.list")
    }

    private func row(_ route: OfficialRoute) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: route.name).lineLimit(2)
                HStack(spacing: 4) {
                    if !route.city.isEmpty { Text(verbatim: route.city) }
                    if route.distanceKm > 0 {
                        Text(Measurement(value: route.distanceKm, unit: UnitLength.kilometers), format: .measurement(width: .abbreviated))
                    }
                    if route.totalMinutes > 0 {
                        Text(Measurement(value: Double(route.totalMinutes), unit: UnitDuration.minutes), format: .measurement(width: .abbreviated))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").foregroundStyle(.green)
        }
    }

    private func load(refreshing: Bool = false) async {
        if !refreshing { state = .loading }
        do {
            let routes = try await reader.list()
            state = routes.isEmpty ? .empty : .ready(routes)
        } catch is CancellationError { return }
        catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            state = .offline
        } catch { state = .failed }
    }
}

/// S6 route card: the map draws the polyline and numbered stops; the sheet lists the stops.
/// Same read as `OfficialRouteDetailView` (`OfficialRouteReader.detail`). The MP has no start button here.
@MainActor struct RoamMapHomeRouteCard: View {
    let reader: OfficialRouteReader
    let routeID: String
    @Bindable var model: RoamMapHomeModel
    private enum LoadState: Equatable { case loading, ready(OfficialRouteDetail), notFound, failed }
    @State private var state: LoadState = .loading

    var body: some View {
        List {
            switch state {
            case .loading:
                ForEach(0..<4, id: \.self) { _ in
                    Label("nativeR2.mapHome.loading", systemImage: "mappin").redacted(reason: .placeholder)
                }
            case .ready(let detail):
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: detail.route.name).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        if !detail.route.city.isEmpty {
                            Text(verbatim: detail.route.city).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                if detail.nodes.isEmpty {
                    ContentUnavailableView("nativeR2.mapHome.route.noStops", systemImage: "mappin.slash")
                } else {
                    Section {
                        ForEach(RoamMapHomePin.make(officialRoute: detail)) { pin in
                            NavigationLink(value: RoamMapHomeRoute.pin(pin.id)) { stopRow(pin) }
                        }
                    } header: {
                        Text("nativeR2.mapHome.route.stops")
                    }
                }
            case .notFound:
                ContentUnavailableView("nativeR2.mapHome.route.notFound", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            case .failed:
                ContentUnavailableView {
                    Label("nativeR2.mapHome.routes.failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("action.retry") { Task { await load() } }.buttonStyle(.bordered)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.path.removeAll() } label: {
                    Label("action.close", systemImage: "xmark.circle.fill").symbolRenderingMode(.hierarchical)
                }
            }
        }
        .task(id: routeID) { await load() }
        .accessibilityIdentifier("officialRoute.detail")
    }

    private func stopRow(_ pin: RoamMapHomePin) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: pin.title)
                if case .officialStop(let node) = pin.payload, node.stayMinutes > 0 {
                    Text(Measurement(value: Double(node.stayMinutes), unit: UnitDuration.minutes), format: .measurement(width: .abbreviated))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: Self.numberSymbol(pin.monogram)).foregroundStyle(.green)
        }
    }

    /// SF Symbols number the circles 0...50; longer routes fall back to a pin.
    private static func numberSymbol(_ monogram: String?) -> String {
        guard let monogram, let number = Int(monogram), (0...50).contains(number) else { return "mappin.circle.fill" }
        return monogram + ".circle.fill"
    }

    private func load() async {
        state = .loading
        do {
            let detail = try await reader.detail(routeID)
            state = .ready(detail)
            model.officialRoute = detail
        }
        catch is CancellationError { return }
        catch OfficialRouteReader.Failure.notFound { state = .notFound }
        catch { state = .failed }
    }
}
