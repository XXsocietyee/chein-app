import Foundation

/// MP `utils/map-address-search.js` `matchPlaces`: name or address contains the query,
/// or full pinyin / initials have the query as a prefix. Empty query matches. The client
/// does not invent pinyin; pass nil when the payload omitted the fields.
public enum MapAddressMatch {
    public static func matches(name: String, address: String?, pinyin: String?, initials: String?, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if needle.isEmpty { return true }
        if name.lowercased().contains(needle) { return true }
        if let address, address.lowercased().contains(needle) { return true }
        if let pinyin, !pinyin.isEmpty, pinyin.lowercased().hasPrefix(needle) { return true }
        if let initials, !initials.isEmpty, initials.lowercased().hasPrefix(needle) { return true }
        return false
    }
}
