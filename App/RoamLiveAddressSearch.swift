import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// MP `components/cy/map-address-search` (pages/roam/index.wxml:297, `screen=='map'`): the 输入地址 entry on the live map.
/// MP order: field (路名、门牌号或店名) + 取消 → up to five rows (pin · name · address) → 这附近没有搜到.
/// Rows come from this session's nearby places and registered shops. Match is MP `matchPlaces`:
/// name or address contains, or (shops) `namePinyin` / `nameInitials` prefix. The client never invents pinyin.
/// Picking a row moves the map there without leaving the screen (MP `onSearchPick`).
enum RoamLiveAddressMatch {
    /// MP `MAX_RESULTS` (P-33): at most five rows.
    static let maxResults = 5

    static func subtitle(_ place: RoamPlace) -> String? {
        let raw = place.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !raw.isEmpty { return raw }
        let desc = place.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return desc.isEmpty ? nil : desc
    }

    static func rows(places: [RoamPlace], shops: [RoamRouteNode], query: String) -> [RoamLiveAddressHit] {
        var hits: [RoamLiveAddressHit] = []
        for place in places {
            guard place.coordinate != nil else { continue }
            guard MapAddressMatch.matches(name: place.name, address: subtitle(place), pinyin: nil, initials: nil, query: query) else { continue }
            hits.append(.place(place))
        }
        for shop in shops {
            guard shop.coordinate != nil else { continue }
            guard MapAddressMatch.matches(name: shop.addressName, address: shop.address, pinyin: shop.namePinyin, initials: shop.nameInitials, query: query) else { continue }
            hits.append(.shop(shop))
        }
        return Array(hits.prefix(maxResults))
    }
}

enum RoamLiveAddressHit: Identifiable {
    case place(RoamPlace)
    case shop(RoamRouteNode)
    var id: String {
        switch self {
        case .place(let place): return "place.\(place.id)"
        case .shop(let shop): return "shop.\(shop.id)"
        }
    }
}

struct RoamLiveAddressSearchSheet: View {
    let places: [RoamPlace]
    let shops: [RoamRouteNode]
    let onPickPlace: (RoamPlace) -> Void
    let onPickShop: (RoamRouteNode) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var query = ""

    private var rows: [RoamLiveAddressHit] { RoamLiveAddressMatch.rows(places: places, shops: shops, query: query) }

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
                    ForEach(rows) { hit in
                        Button {
                            switch hit {
                            case .place(let place): onPickPlace(place)
                            case .shop(let shop): onPickShop(shop)
                            }
                            dismiss()
                        } label: {
                            row(hit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(identifier(hit))
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

    private func identifier(_ hit: RoamLiveAddressHit) -> String {
        switch hit {
        case .place(let place): return "roam.live.addressSearch.row.\(place.id)"
        case .shop(let shop): return "roam.live.addressSearch.row.shop.\(shop.id)"
        }
    }

    private func row(_ hit: RoamLiveAddressHit) -> some View {
        let name: String
        let subtitle: String?
        let symbol: String
        let tint: Color
        switch hit {
        case .place(let place):
            name = place.name.isEmpty ? appLocalized("roam.unnamed", locale: locale) : place.name
            subtitle = RoamLiveAddressMatch.subtitle(place)
            symbol = RoamLivePlaceLevel.symbol(place.nodeLevel)
            tint = RoamLivePlaceLevel.tint(place.nodeLevel)
        case .shop(let shop):
            name = shop.addressName.isEmpty ? appLocalized("nativeR2.mapHome.kind.merchant", locale: locale) : shop.addressName
            let address = shop.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            subtitle = address.isEmpty ? nil : address
            symbol = "storefront.fill"
            tint = .gray
        }
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(verbatim: subtitle)
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
