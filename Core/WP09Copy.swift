import Foundation

/// Shared unknown mark for WP-09. Unknown is an em dash, never 0, never a hyphen-minus.
public enum WP09Copy {
    public static let unknown = "\u{2014}"

    public static func text(_ zh: String, _ en: String, chinese: Bool) -> String {
        chinese ? zh : en
    }

    public static func amount(_ value: Decimal?) -> String {
        guard let value, !value.isNaN else { return unknown }
        return NSDecimalNumber(decimal: value).stringValue
    }
}
