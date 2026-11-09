import Foundation

/// Owner-supplied universal-link configuration.
///
/// The associated domain is not known yet. Both collections stay empty, so this
/// build does not accept an HTTPS origin and does not claim an Associated Domain.
/// Filling either value is a later owner change. Do not copy a host into
/// `Config/Questify.entitlements` from here.
public enum UniversalLinkConfiguration {
    /// Normalized later by `UniversalLinkParser`. Empty until the owner supplies a host.
    public static let verifiedHTTPSOrigins: Set<String> = []

    /// Future Associated Domains values. Empty means this build claims no domain.
    public static let associatedDomainEntitlements: [String] = []
}

/// Stricter front door for the typed entry router.
///
/// `NativeEntryLinkPolicy` still classifies paths. This type only decides whether
/// a URL is allowed to reach that classifier. The default configuration matches
/// `UniversalLinkConfiguration` and accepts nothing. Parsing does not open a
/// connection, change an account, or start a payment.
public struct UniversalLinkParser {
    private let origins: Set<String>

    public init(verifiedHTTPSOrigins: Set<String> = UniversalLinkConfiguration.verifiedHTTPSOrigins) {
        origins = Self.normalizedOrigins(verifiedHTTPSOrigins)
    }

    public func parse(_ url: URL) -> NativeEntryIntent? {
        guard let host = Self.allowedHost(url, origins: origins) else { return nil }
        return NativeEntryLinkPolicy(verifiedHTTPSOrigins: ["https://" + host]).parse(url)
    }

    private static let legacyForbiddenIPv4Host: String = ["47", "103", "124", "64"].joined(separator: ".")

    private static func normalizedOrigins(_ raw: Set<String>) -> Set<String> {
        Set(raw.compactMap { item in
            guard let components = URLComponents(string: item),
                  components.scheme?.lowercased() == "https",
                  let host = components.host?.lowercased(),
                  components.user == nil,
                  components.password == nil,
                  components.port == nil,
                  components.query == nil,
                  components.fragment == nil,
                  components.path.isEmpty || components.path == "/",
                  isAcceptableDNSHost(host) else { return nil }
            return "https://" + host
        })
    }

    private static func allowedHost(_ url: URL, origins: Set<String>) -> String? {
        guard !origins.isEmpty,
              !url.absoluteString.contains("\\"),
              url.absoluteString.utf8.count <= 8192,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              origins.contains("https://" + host),
              isAcceptableDNSHost(host),
              isSafePath(components.percentEncodedPath) else { return nil }
        return host
    }

    private static func isAcceptableDNSHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        guard !normalized.isEmpty,
              !normalized.hasSuffix("."),
              !normalized.contains(":"),
              normalized != "localhost",
              normalized != legacyForbiddenIPv4Host,
              !normalized.hasSuffix(".local"),
              !normalized.hasSuffix(".localhost"),
              !normalized.hasSuffix(".invalid"),
              !isNumericAddress(normalized) else { return false }
        let labels = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...127).contains(labels.count), normalized.utf8.count <= 253 else { return false }
        return labels.allSatisfy(isDNSLabel)
    }

    private static func isDNSLabel(_ label: Substring) -> Bool {
        let scalars = Array(label.unicodeScalars)
        guard (1...63).contains(scalars.count),
              !label.hasPrefix("-"),
              !label.hasSuffix("-"),
              !label.hasPrefix("0x") else { return false }
        return scalars.allSatisfy { scalar in
            let value = Int(scalar.value)
            return (97...122).contains(value) || (48...57).contains(value) || value == 45
        }
    }

    private static func isNumericAddress(_ host: String) -> Bool {
        if host.hasPrefix("0x") { return true }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return !labels.isEmpty && labels.allSatisfy { label in
            !label.isEmpty && label.unicodeScalars.allSatisfy { (48...57).contains(Int($0.value)) }
        }
    }

    private static func isSafePath(_ path: String) -> Bool {
        guard path.hasPrefix("/"),
              !path.contains("//"),
              !path.contains("%"),
              !path.contains("\\"),
              !path.contains(".") else { return false }
        let segments = path.split(separator: "/")
        guard !segments.isEmpty, path == "/" + segments.joined(separator: "/") else { return false }
        return segments.allSatisfy { segment in
            segment.unicodeScalars.allSatisfy { scalar in
                let value = Int(scalar.value)
                return (65...90).contains(value) || (97...122).contains(value)
                    || (48...57).contains(value) || value == 45 || value == 95
            }
        }
    }
}
