import Foundation

/// Masks phone numbers, OpenIDs, tokens, and street addresses inside text that
/// is about to be passed to `print`, `os_log`, `Logger`, or `NSLog`.
/// Call it on the value at that call. This is not a logger.
public enum LogFieldRedaction {
    public static let marker = "[redacted]"

    /// Keys whose string or number values are secrets in a log line.
    /// Longer names are listed first so a short name does not win an alternation.
    private static let fieldNames = [
        "phoneNumber", "mobilePhone", "telephone", "wechatOpenId", "wxOpenId", "open_id",
        "access_token", "refresh_token", "accessToken", "refreshToken", "sessionToken",
        "authToken", "idToken", "bearerToken", "shareToken", "address_line", "addressLine",
        "detailAddress", "fullAddress", "street_address", "streetAddress", "phone", "mobile",
        "openid", "unionid", "token", "street", "address"
    ]

    private static let nameGroup = fieldNames.joined(separator: "|")

    private static let jsonString = Self.regex(#""(\#(Self.nameGroup))"\s*:\s*"(?:\\.|[^"\\])*""#, caseInsensitive: true)
    private static let jsonNumber = Self.regex(#""(\#(Self.nameGroup))"\s*:\s*-?\d+(?:\.\d+)?"#, caseInsensitive: true)
    private static let street = Self.regex(
        #"(?<!\w)\d{1,5}(?:\s+[A-Za-z][A-Za-z0-9.'-]*){1,4}\s+(?:Street|St|Road|Rd|Avenue|Ave|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct)\b"#,
        caseInsensitive: true)
    private static let query = Self.regex(
        #"(?<![A-Za-z0-9_])(\#(Self.nameGroup))=([^&#\s"']*)"#,
        caseInsensitive: true)
    private static let bearer = Self.regex(#"Bearer\s+[A-Za-z0-9\-._~+/=]+"#, caseInsensitive: true)
    private static let mobile = Self.regex(#"(?<!\d)1[3-9]\d{9}(?!\d)"#)
    private static let plusNumber = Self.regex(#"(?<!\d)\+\d{10,15}(?!\d)"#)
    private static let openID = Self.regex(#"(?<![A-Za-z0-9_])o[A-Za-z0-9_-]{27}(?![A-Za-z0-9_])"#)
    private static let wholePhone = Self.regex(#"\A(?:1[3-9]\d{9}|\+\d{10,15})\z"#)
    private static let wholeOpenID = Self.regex(#"\Ao[A-Za-z0-9_-]{27}\z"#)

    /// The failure text around a secret stays. Only the secret is replaced.
    public static func redacted(_ value: String) -> String {
        let scanned = Self.scan(value)
        if scanned == value, Self.entireSecret(value) { return Self.marker }
        return scanned
    }

    private static func scan(_ value: String) -> String {
        var text = Self.replace(Self.jsonString, in: value, with: #""$1":"\#(Self.marker)""#)
        text = Self.replace(Self.jsonNumber, in: text, with: #""$1":"\#(Self.marker)""#)
        text = Self.replace(Self.street, in: text, with: Self.marker)
        text = Self.replace(Self.query, in: text, with: #"$1=\#(Self.marker)"#)
        text = Self.replace(Self.bearer, in: text, with: "Bearer \(Self.marker)")
        text = Self.replace(Self.mobile, in: text, with: Self.marker)
        text = Self.replace(Self.plusNumber, in: text, with: Self.marker)
        text = Self.replace(Self.openID, in: text, with: Self.marker)
        return text
    }

    /// A whole value with no spaces that is not a plain word. `notConfigured` stays.
    /// `fixture-token` does not.
    private static func entireSecret(_ value: String) -> Bool {
        if value.isEmpty { return false }
        if value.contains(where: { $0.isWhitespace || "/:?&=\"{}[]".contains($0) }) { return false }
        if Self.matches(Self.wholePhone, value) || Self.matches(Self.wholeOpenID, value) { return true }
        let hasLetter = value.contains(where: \.isLetter)
        let hasNonLetter = value.contains(where: { !$0.isLetter })
        return hasLetter && hasNonLetter && value.count >= 8
    }

    private static func matches(_ pattern: NSRegularExpression, _ value: String) -> Bool {
        let range = NSRange(value.startIndex..., in: value)
        guard let found = pattern.firstMatch(in: value, range: range) else { return false }
        return found.range.location == 0 && found.range.length == range.length
    }

    private static func replace(_ pattern: NSRegularExpression, in text: String, with template: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func regex(_ pattern: String, caseInsensitive: Bool = false) -> NSRegularExpression {
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }
        do { return try NSRegularExpression(pattern: pattern, options: options) }
        catch { preconditionFailure("log field pattern did not compile") }
    }
}
