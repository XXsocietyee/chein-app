import SwiftUI

/// ROAM-13 (MP pages/roam/index.wxml:144-160, index.js:5852-5895; subpackageRoam/utils/roam-city-guide.js):
/// the 附近活动 peek's second tab, 本城推荐. Same static catalog as the MP, no location needed.
struct RoamCityGuideCity: Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
}

struct RoamCityGuidePlace: Hashable, Identifiable {
    /// MP `CATEGORY_LABELS` (utils/roam-poi-presentation.js:5-7).
    enum Category: String { case street, shop, park, landmark
        var labelKey: LocalizedStringKey {
            switch self {
            case .street: return "roam.cityGuide.category.street"
            case .shop: return "roam.cityGuide.category.shop"
            case .park: return "roam.cityGuide.category.park"
            case .landmark: return "roam.cityGuide.category.landmark"
            }
        }
    }
    let id: String
    let city: String
    let name: String
    let category: Category
    let address: String
    let reason: String
    /// MP `seed: 'roam:seed:v1:' + place.id`: server rows carry it in `tags`; never matched by name.
    var seed: String { "roam:seed:v1:" + id }
}

/// One tap on a 本城推荐 card; the token makes a second tap on the same card a new request.
struct RoamCityGuideOpen: Hashable {
    let place: RoamCityGuidePlace
    let token = UUID()
}

/// MP `stripFor(cityId)` result plus `inCity` from the component's `strip` event.
struct RoamCityGuideStrip: Equatable {
    let city: RoamCityGuideCity
    let items: [RoamCityGuidePlace]
    /// The map faces this city (within 60 km); otherwise it is the default city and the tab stays 本城推荐.
    let inCity: Bool

    /// MP `nearestCity` (≤ 60 km, closest wins) then `stripFor(near || defaultCity())`.
    static func resolve(latitude: Double?, longitude: Double?) -> RoamCityGuideStrip? {
        let near = latitude.flatMap { lat in longitude.flatMap { lng in nearestCity(latitude: lat, longitude: lng) } }
        let cityID = near ?? RoamCityGuideCatalog.cities.first { city in RoamCityGuideCatalog.places.contains { $0.city == city.id } }?.id
        guard let cityID, let city = RoamCityGuideCatalog.cities.first(where: { $0.id == cityID }) else { return nil }
        let items = RoamCityGuideCatalog.places.filter { $0.city == cityID }
        guard !items.isEmpty else { return nil }
        return RoamCityGuideStrip(city: city, items: items, inCity: near != nil)
    }
    static func nearestCity(latitude: Double, longitude: Double) -> String? {
        guard latitude.isFinite, longitude.isFinite else { return nil }
        var best: String?
        var bestDistance = 60_000.0
        for city in RoamCityGuideCatalog.cities {
            let distance = haversineMetres(latitude, longitude, city.latitude, city.longitude)
            if distance <= bestDistance { best = city.id; bestDistance = distance }
        }
        return best
    }
    private static func haversineMetres(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let radians = Double.pi / 180
        let dLat = (lat2 - lat1) * radians, dLng = (lng2 - lng1) * radians
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * radians) * cos(lat2 * radians) * sin(dLng / 2) * sin(dLng / 2)
        return 6_371_000 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

extension RoamPlace {
    /// `/api/roam/pois` tags arrive as a JSON array string; the shared decoder splits on commas, so the
    /// brackets and quotes are trimmed before the exact seed comparison (MP `PM.parseTags(row.tags).includes(seed)`).
    func carriesCityGuideSeed(_ seed: String) -> Bool {
        type == 1 && tags.contains { $0.trimmingCharacters(in: CharacterSet(charactersIn: "[]\"' ")) == seed }
    }
}

/// 本城推荐 card row: cover from the matching loaded place (MP `_cityStripWithCovers`), else the MP placeholder.
struct RoamCityGuideCards: View {
    let strip: RoamCityGuideStrip
    let places: [RoamPlace]
    let onOpen: (RoamCityGuidePlace) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(strip.items) { item in
                    Button { onOpen(item) } label: {
                        // N-r11-4: a plain Label row with the MP placeholder art instead of the shelf image card.
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                (Text(item.category.labelKey) + Text(verbatim: " · ") + Text(verbatim: item.reason))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        } icon: {
                            MPAsset.BannerCover.homeRouteCityPlaceholder.resizable().scaledToFill()
                                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityHidden(true)
                        }
                        .frame(width: 240, alignment: .leading)
                        .padding(10)
                        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: item.name))
                    .accessibilityIdentifier("roam.home.peek.city.\(item.id)")
                }
            }.padding(.vertical, 4)
        }
        .accessibilityIdentifier("roam.home.peek.city")
    }
    private func cover(for item: RoamCityGuidePlace) -> URL? {
        guard let raw = places.first(where: { $0.carriesCityGuideSeed(item.seed) })?.coverImage,
              let url = URL(string: raw), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
