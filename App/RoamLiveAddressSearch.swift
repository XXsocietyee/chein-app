import SwiftUI
import QuestifyCore

/// MP `components/cy/map-address-search` (pages/roam/index.wxml:297, `screen=='map'`): the 输入地址 entry on the live map.
/// MP order: field (路名、门牌号或店名) + 取消 → up to five rows (pin · name · address) → 这附近没有搜到.
/// Rows come from the session's own nearby places (MP `_searchPlaces` = `this._pois` with a coordinate) and match on
/// name or address (MP `matchPlaces` ①; pinyin needs backend fields the API does not send). Picking a row moves the
/// map there without leaving the screen (MP `onSearchPick`).
enum RoamLiveAddressMatch {
    /// MP `MAX_RESULTS` (P-33): at most five rows.
    static let maxResults = 5

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
}

struct RoamLiveAddressSearchSheet: View {
    let places: [RoamPlace]
    let onPick: (RoamPlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var query = ""

    private var rows: [RoamPlace] { RoamLiveAddressMatch.results(places, query: query) }

    var body: some View {
        NavigationStack {
            List {
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("roam.live.addressSearch.none", systemImage: "magnifyingglass")
                    }
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("roam.live.addressSearch.none")
                } else {
                    ForEach(rows) { place in
                        Button {
                            onPick(place)
                            dismiss()
                        } label: {
                            row(place)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("roam.live.addressSearch.row.\(place.id)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("roam.live.addressSearch.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("roam.live.addressSearch.prompt"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("roam.live.addressSearch.cancel")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ place: RoamPlace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: RoamLivePlaceLevel.symbol(place.nodeLevel))
                .foregroundStyle(RoamLivePlaceLevel.tint(place.nodeLevel))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: place.name.isEmpty ? appLocalized("roam.unnamed", locale: locale) : place.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let sub = RoamLiveAddressMatch.subtitle(place) {
                    Text(verbatim: sub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
