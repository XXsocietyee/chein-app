import Foundation

/// Text helpers of mini-program `utils/danger-actions.js` (the single source of danger-confirmation copy):
/// `postExcerpt` and `fillTemplate`. User-visible fallbacks are injected by the caller so each locale
/// (English / Simplified Chinese) supplies its own words; nothing here is a localized string.
public enum DangerActionText {
    /// Source `postExcerpt` (CU-C-107): whitespace runs collapse to one space, the result is trimmed,
    /// longer text is cut to `limit` UTF-16 units plus an ellipsis, and text-less posts read as
    /// `imageOnlyText`. Unlike the JS `slice`, a surrogate pair is never split at the cut.
    public static func postExcerpt(_ text: String?, limit: Int = 12, imageOnlyText: String) -> String {
        let flat = collapse(text ?? "")
        guard !flat.isEmpty else { return imageOnlyText }
        let max = limit > 0 ? limit : 12
        guard flat.utf16.count > max else { return flat }
        var kept = "", used = 0
        for scalar in flat.unicodeScalars {
            let width = String(scalar).utf16.count
            if used + width > max { break }
            kept.unicodeScalars.append(scalar); used += width
        }
        return kept + "…"
    }

    /// Source `fillTemplate`: `{key}` placeholders (ASCII word characters) take `params[key]`; a missing or
    /// empty value reads as `neutral` so no bare placeholder is ever shown. Non-placeholder braces stay.
    public static func fillTemplate(_ text: String?, params: [String: String]?, neutral: String) -> String {
        guard let text, !text.isEmpty, let regex = try? NSRegularExpression(pattern: #"\{([A-Za-z0-9_]+)\}"#) else { return "" }
        let source = text as NSString
        var out = "", cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            out += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let key = source.substring(with: match.range(at: 1))
            if let value = params?[key], !value.isEmpty { out += value } else { out += neutral }
            cursor = match.range.location + match.range.length
        }
        return out + source.substring(from: cursor)
    }

    /// JS `\s` also covers U+FEFF, which `CharacterSet.whitespacesAndNewlines` does not.
    private static func collapse(_ text: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))
        return text.components(separatedBy: separators).filter { !$0.isEmpty }.joined(separator: " ")
    }
}
