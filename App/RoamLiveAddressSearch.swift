import CoreLocation
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// MP `components/cy/map-address-search` (pages/roam/index.wxml:297, `screen=='map'`): the 输入地址 entry on the live map.
/// MP order: field (路名、门牌号或店名) + 取消 → up to five rows (pin · name · address) → 这附近没有搜到.
/// Rows come from the session's own nearby places (MP `_searchPlaces` = `this._pois` with a coordinate) and match on
/// name or address (MP `matchPlaces` ①; pinyin needs backend fields the API does not send). Picking a row moves the
/// map there without leaving the screen (MP `onSearchPick`).
enum RoamLiveAddressMatch {
    /// MP `MAX_RESULTS` (P-33): at most five rows.
    static let maxResults = 5
    static let searchingID = ["roam", "live", "addressSearch", "searching"].joined(separator: ".")

    static func subtitle(_ place: RoamPlace) -> String? {
        let raw = place.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !raw.isEmpty { return raw }
        let desc = place.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return desc.isEmpty ? nil : desc
    }

    static func results(_ places: [RoamPlace], query: String) -> [RoamPlace] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let located = places.filter { $0.coordinate != nil }
        let hits: [RoamPlace]
        if needle.isEmpty {
            hits = located
        } else {
            hits = located.filter { place in
                if place.name.localizedCaseInsensitiveContains(needle) { return true }
                guard let sub = subtitle(place) else { return false }
                return sub.localizedCaseInsensitiveContains(needle)
            }
        }
        return Array(hits.prefix(maxResults))
    }

    /// MP `_refresh` order: the local matches first, then the remote rows whose name is not already listed, five at most.
    static func rows(local: [RoamPlace], remote: [MapSearchPlayerService.Place]) -> [RoamLiveAddressRow] {
        var rows: [RoamLiveAddressRow] = local.compactMap { place in
            guard let point = place.coordinate else { return nil }
            return RoamLiveAddressRow(id: "local-\(place.id)", name: place.name, subtitle: subtitle(place),
                                      latitude: point.latitude, longitude: point.longitude, localPlaceID: place.id, nodeLevel: place.nodeLevel)
        }
        var names = Set(local.map(\.name))
        for place in remote {
            guard let point = place.coordinate, !names.contains(place.name) else { continue }
            names.insert(place.name)
            let address = place.address.trimmingCharacters(in: .whitespacesAndNewlines)
            rows.append(RoamLiveAddressRow(id: "remote-\(place.id)", name: place.name, subtitle: address.isEmpty ? nil : address,
                                           latitude: point.latitude, longitude: point.longitude, localPlaceID: nil, nodeLevel: nil))
        }
        return Array(rows.prefix(maxResults))
    }
}

/// One 输入地址 result: a session place (`localPlaceID`) or a remote place-search / city-node row (neutral pin, MP `kind: 'place'`).
struct RoamLiveAddressRow: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double
    let localPlaceID: Int?
    let nodeLevel: Int?
}

/// MP `_searchRemote` → `_searchNodes`: 350 ms debounce, last keystroke wins; `api/map/place-search` near the map centre,
/// and when it is off (empty) or fails, `api/city/nodes?keyword=`. `remoteError` = the MP line
/// 联网搜索暂时不可用，先显示附近的地点 (place search failed; local rows and any node rows stay).
@MainActor final class RoamLiveRemotePlaceModel: ObservableObject {
    @Published private(set) var places: [MapSearchPlayerService.Place] = []
    @Published private(set) var searching = false
    @Published private(set) var remoteError = false
    private var token = 0

    func search(_ keyword: String, latitude: Double, longitude: Double, localNames: Set<String>, client: PlayerCapabilityClient) async {
        token += 1
        let current = token
        guard keyword.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2, latitude != 0, longitude != 0 else {
            searching = false; remoteError = false; places = []; return
        }
        searching = true; remoteError = false
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard current == token, !Task.isCancelled else { return }
        let service = MapSearchPlayerService(client: client)
        var placeSearchFailed = false
        do {
            let rows = try await service.placeSearch(keyword: keyword, latitude: latitude, longitude: longitude, localNames: localNames)
            guard current == token else { return }
            if !rows.isEmpty {
                places = rows; searching = false; return
            }
        } catch {
            guard current == token else { return }
            placeSearchFailed = true
            remoteError = true
        }
        do {
            let nodes = try await service.cityNodePlaces(keyword: keyword, latitude: latitude, longitude: longitude, localNames: localNames)
            guard current == token else { return }
            places = nodes
            remoteError = placeSearchFailed
        } catch {
            guard current == token else { return }
            places = []
            remoteError = true
        }
        searching = false
    }

    func cancel() {
        token += 1
        searching = false
    }
}

struct RoamLiveAddressSearchSheet: View {
    let places: [RoamPlace]
    /// MP `lat` / `lng` properties: the map centre the remote search runs around; nil skips the remote leg.
    var center: CLLocationCoordinate2D? = nil
    /// P1-21 map-app choice for the per-row 导航 (MP `onNavigate` → `wx.openLocation`); nil hides 导航.
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    let onPick: (RoamLiveAddressRow) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.socialRoamCapabilities) private var capabilities
    @StateObject private var remote = RoamLiveRemotePlaceModel()
    @State private var query = ""
    @State private var maps: PlatformExternalMaps?
    @State private var navigateTarget: RoamLiveAddressRow?

    private struct SearchKey: Hashable { let query: String; let account: Int? }

    private var localRows: [RoamPlace] { RoamLiveAddressMatch.results(places, query: query) }
    private var rows: [RoamLiveAddressRow] { RoamLiveAddressMatch.rows(local: localRows, remote: remote.places) }

    var body: some View {
        NavigationStack {
            List {
                resultsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("roam.live.addressSearch.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("roam.live.addressSearch.prompt"))
            .onSubmit(of: .search, pickFirst)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cancel() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("roam.live.addressSearch.cancel")
                }
            }
            .task(id: SearchKey(query: query, account: capabilities?.accountID)) { await runRemote() }
            .confirmationDialog(PlatformMapApp.reviewTitle(maps?.apps ?? []), isPresented: navigateShown, titleVisibility: .visible) {
                navigateChoices
            } message: {
                Text(verbatim: navigateTarget.map { destination($0).copyText } ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { if maps == nil { maps = makeExternalMaps?() } }
        .onDisappear { maps?.invalidate(); remote.cancel() }
    }

    @ViewBuilder private var resultsSection: some View {
        if rows.isEmpty {
            if remote.searching {
                ContentUnavailableView {
                    Label("search.r3.loading.results", systemImage: "magnifyingglass")
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier(RoamLiveAddressMatch.searchingID)
            } else {
                ContentUnavailableView {
                    Label("roam.live.addressSearch.none", systemImage: "magnifyingglass")
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("roam.live.addressSearch.none")
            }
        } else {
            ForEach(rows) { item in
                rowButton(item)
            }
        }
        if remote.remoteError {
            Text("roam.live.addressSearch.remoteError")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("roam.live.addressSearch.remoteError")
        }
    }

    private func rowButton(_ item: RoamLiveAddressRow) -> some View {
        HStack(spacing: 12) {
            Button {
                pick(item)
            } label: {
                row(item)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("roam.live.addressSearch.row.\(item.id)")
            if maps != nil {
                Button {
                    navigate(item)
                } label: {
                    Text("nativeR2.mapHome.card.navigate")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("roam.live.addressSearch.navigateTo \(item.name)"))
                .accessibilityIdentifier("roam.live.addressSearch.navigate.\(item.id)")
            }
        }
    }

    private func row(_ item: RoamLiveAddressRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.localPlaceID == nil ? "mappin" : RoamLivePlaceLevel.symbol(item.nodeLevel))
                .foregroundStyle(item.localPlaceID == nil ? Color.secondary : RoamLivePlaceLevel.tint(item.nodeLevel))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name.isEmpty ? appLocalized("roam.unnamed", locale: locale) : item.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let sub = item.subtitle {
                    Text(verbatim: sub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var navigateShown: Binding<Bool> {
        Binding(get: { navigateTarget != nil }, set: { shown in if !shown { navigateTarget = nil } })
    }

    @ViewBuilder private var navigateChoices: some View {
        ForEach(maps?.apps ?? [], id: \.self) { app in
            Button(PlatformMapApp.label(app, among: maps?.apps ?? [])) { openTarget(in: app) }
        }
        Button("platform.cancel", role: .cancel) { navigateTarget = nil }
    }

    private func destination(_ item: RoamLiveAddressRow) -> PlatformMapDestination {
        PlatformMapDestination(name: item.name, address: item.subtitle, latitude: item.latitude, longitude: item.longitude)
    }

    private func navigate(_ item: RoamLiveAddressRow) {
        maps?.select(destination(item))
        navigateTarget = item
    }

    private func openTarget(in app: PlatformMapApp) {
        guard let item = navigateTarget, let maps else { return }
        let selected = destination(item)
        navigateTarget = nil
        Task { await maps.openReviewedDestination(selected, in: app) }
    }

    private func runRemote() async {
        guard let capabilities, let center else {
            remote.cancel()
            return
        }
        let names = Set(localRows.map(\.name))
        await remote.search(query, latitude: center.latitude, longitude: center.longitude, localNames: names, client: capabilities.client)
    }

    /// MP `onConfirm`: the keyboard 搜索 key picks the first row.
    private func pickFirst() {
        if let first = rows.first { pick(first) }
    }

    private func pick(_ item: RoamLiveAddressRow) {
        remote.cancel()
        onPick(item)
        dismiss()
    }

    private func cancel() {
        remote.cancel()
        dismiss()
    }
}
