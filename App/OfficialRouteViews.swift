import SwiftUI

// Mini-program subpackageRoam/official-routes + official-route, hosted inside the Roam start tab
// (an intro-card push, no new top-level page). Read-only: "start this route" stays unported, as in the source.

private var officialRouteIsChinese: Bool { Locale.current.language.languageCode?.identifier == "zh" }

@MainActor struct OfficialRouteListView: View {
    let reader: OfficialRouteReader
    @State private var state: LoadState = .loading
    private enum LoadState { case loading, ready([OfficialRoute]), empty, failed }
    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("officialRoute.loading"))
            case .failed:
                CYErrorStateView(title: "officialRoute.list.error", message: "officialRoute.error.message", retryTitle: "officialRoute.retry") { Task { await load() } }
            case .empty:
                CYEmptyStateView(systemImage: "point.topleft.down.to.point.bottomright.curvepath", title: "officialRoute.list.empty")
            case .ready(let routes):
                List(routes) { route in
                    NavigationLink { OfficialRouteDetailView(reader: reader, routeID: route.id) } label: { row(route) }
                        .frame(minHeight: 44)
                        .accessibilityLabel(Text("officialRoute.list.open \(route.name)"))
                }.listStyle(.insetGrouped)
            }
        }
        .navigationTitle(Text("officialRoute.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .accessibilityIdentifier("officialRoute.list")
    }
    private func row(_ route: OfficialRoute) -> some View {
        HStack(spacing: 12) {
            OfficialRouteImage(urlString: route.previewImage, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: route.name).font(.headline)
                let meta = OfficialRouteFormat.meta(route, chinese: officialRouteIsChinese)
                if !meta.isEmpty { Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }
    private func load() async {
        state = .loading
        do {
            let routes = try await reader.list()
            state = routes.isEmpty ? .empty : .ready(routes)
        } catch is CancellationError { return } catch { state = .failed }
    }
}

@MainActor struct OfficialRouteDetailView: View {
    let reader: OfficialRouteReader
    let routeID: String
    @State private var state: LoadState = .loading
    private enum LoadState { case loading, ready(OfficialRouteDetail), notFound, failed }
    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("officialRoute.loading"))
            case .failed:
                CYErrorStateView(title: "officialRoute.detail.error", message: "officialRoute.error.message", retryTitle: "officialRoute.retry") { Task { await load() } }
            case .notFound:
                CYEmptyStateView(systemImage: "questionmark.folder", title: "officialRoute.detail.notFound")
            case .ready(let detail):
                content(detail)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .accessibilityIdentifier("officialRoute.detail")
    }
    private var navTitle: Text {
        if case .ready(let d) = state { return Text(verbatim: d.route.name) }
        return Text("officialRoute.detail.title")
    }
    private func content(_ detail: OfficialRouteDetail) -> some View {
        List {
            Section {
                if !detail.route.previewImage.isEmpty { OfficialRouteImage(urlString: detail.route.previewImage, size: nil) }
                let meta = OfficialRouteFormat.meta(detail.route, chinese: officialRouteIsChinese)
                if !meta.isEmpty { Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary) }
            }
            Section {
                if detail.nodes.isEmpty {
                    Text("officialRoute.detail.noNodes").foregroundStyle(.secondary)
                } else {
                    ForEach(detail.nodes) { node in nodeRow(node) }
                }
            } header: { Text("officialRoute.detail.nodes \(detail.nodes.count)") }
        }.listStyle(.insetGrouped)
    }
    @ViewBuilder private func nodeRow(_ node: OfficialRouteNode) -> some View {
        let body = HStack(alignment: .top, spacing: 12) {
            Text(verbatim: "\(node.order)").font(.headline.monospacedDigit()).frame(minWidth: 28, minHeight: 28)
                .background(.tint.opacity(0.15), in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: node.name).font(.body.weight(.semibold))
                if !node.address.isEmpty { Text(verbatim: node.address).font(.footnote).foregroundStyle(.secondary) }
                if node.stayMinutes > 0 {
                    Text("officialRoute.detail.stay \(OfficialRouteFormat.duration(node.stayMinutes, chinese: officialRouteIsChinese))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if !node.imageURL.isEmpty { OfficialRouteImage(urlString: node.imageURL, size: 48) }
        }.frame(minHeight: 44)
        if let lat = node.latitude, let lng = node.longitude, let url = Self.mapURL(lat: lat, lng: lng, name: node.name) {
            Link(destination: url) { body }
                .accessibilityLabel(Text("officialRoute.detail.nodeLocation \(node.order) \(node.name)"))
        } else {
            body.accessibilityElement(children: .combine)
                .accessibilityLabel(Text("officialRoute.detail.node \(node.order) \(node.name)"))
        }
    }
    static func mapURL(lat: Double, lng: Double, name: String) -> URL? {
        var c = URLComponents(string: "https://maps.apple.com/")
        c?.queryItems = [URLQueryItem(name: "ll", value: "\(lat),\(lng)"), URLQueryItem(name: "q", value: name)]
        return c?.url
    }
    private func load() async {
        state = .loading
        do { state = .ready(try await reader.detail(routeID)) }
        catch is CancellationError { return }
        catch OfficialRouteReader.Failure.notFound { state = .notFound }
        catch { state = .failed }
    }
}

private struct OfficialRouteImage: View {
    let urlString: String
    let size: CGFloat?
    var body: some View {
        if let url = URL(string: urlString), url.scheme == "https" {
            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.12) }
                .frame(width: size, height: size ?? 180).frame(maxWidth: size == nil ? .infinity : nil)
                .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
        }
    }
}
