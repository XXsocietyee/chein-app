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
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var coverSide: CGFloat = 44
    private var isChinese: Bool { locale.language.languageCode?.identifier == "zh" }

    var body: some View {
        List {
            switch state {
            case .loading:
                ProgressView { Text("nativeR2.mapHome.loading") }
                    .frame(maxWidth: .infinity)
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

    /// MP `.orl-card`: the route's cover when it has one, then the name and `metaText` (city · distance · duration).
    private func row(_ route: OfficialRoute) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: route.name).lineLimit(2)
                let meta = OfficialRouteMeta.text(route, chinese: isChinese)
                if !meta.isEmpty {
                    Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } icon: {
            if route.previewImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").foregroundStyle(.green)
            } else {
                E1CoverArt(seed: route.name, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                           imageURL: route.previewImage, symbolPoint: nil)
                    .frame(width: coverSide, height: coverSide)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                    .accessibilityHidden(true)
            }
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
    @Environment(\.locale) private var locale
    private var isChinese: Bool { locale.language.languageCode?.identifier == "zh" }

    var body: some View {
        List {
            switch state {
            case .loading:
                ProgressView { Text("nativeR2.mapHome.loading") }
                    .frame(maxWidth: .infinity)
            case .ready(let detail):
                // MP official-route: title = route name, subtitle = metaText (city · distance · duration), the cover,
                // then 节点（N） and the stop rows (order, name, address, 参考停留).
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: detail.route.name).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        let meta = OfficialRouteMeta.text(detail.route, chinese: isChinese)
                        if !meta.isEmpty {
                            Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if !detail.route.previewImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Color.clear.aspectRatio(1.6, contentMode: .fit)
                            .overlay {
                                E1CoverArt(seed: detail.route.name, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                                           imageURL: detail.route.previewImage)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                            .listRowInsets(EdgeInsets())
                            .accessibilityHidden(true)
                    }
                }
                Section {
                    if detail.nodes.isEmpty {
                        ContentUnavailableView("nativeR2.mapHome.route.noStops", systemImage: "mappin.slash")
                    } else {
                        ForEach(RoamMapHomePin.make(officialRoute: detail)) { pin in
                            NavigationLink(value: RoamMapHomeRoute.pin(pin.id)) { stopRow(pin) }
                        }
                    }
                } header: {
                    Text("officialRoute.detail.nodes \(detail.nodes.count)")
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
                if case .officialStop(let node) = pin.payload {
                    if !node.address.isEmpty {
                        Text(verbatim: node.address).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if node.stayMinutes > 0 {
                        // MP `.orr-node__sub`: 参考停留 N 分钟.
                        Text("officialRoute.detail.stay \(OfficialRouteFormat.duration(node.stayMinutes, chinese: isChinese))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
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
