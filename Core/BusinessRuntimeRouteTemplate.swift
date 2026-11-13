import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One exact HTTP verb and one numeric `{id}` segment. Anything else is not a template.
public struct BusinessRuntimeRouteTemplate: Hashable {
    /// Decimal length of `Int64.max`. A longer digit string is refused before parsing.
    public static let maximumIdentifierLength = 19

    public let method: String
    public let path: String
    public let feature: BusinessRuntimeFeature

    public init?(method: String, path: String, feature: BusinessRuntimeFeature) {
        guard method == "GET" || method == "POST" else { return nil }
        let segments = Self.segments(path)
        guard segments.first == "api", segments.filter({ $0 == "{id}" }).count == 1 else { return nil }
        for segment in segments where segment != "{id}" {
            guard Self.isLiteralSegment(segment) else { return nil }
        }
        let sample = segments.map { $0 == "{id}" ? "1" : $0 }.joined(separator: "/")
        guard let route = try? BusinessRuntimeRoute(method: method, path: sample), feature.accepts(route) else { return nil }
        self.method = method
        self.path = path
        self.feature = feature
    }

    /// The captured id when `requestMethod` and `requestPath` match this template.
    /// `..`, `%2f` / `%2F` / `%5c`, any other `%`, an empty id, a non-digit, an overlong
    /// id, a leading zero, or an extra segment all refuse.
    public func match(method requestMethod: String, path requestPath: String) -> Int64? {
        guard requestMethod == method, !Self.rejects(requestPath) else { return nil }
        let requestSegments = Self.segments(requestPath)
        let templateSegments = Self.segments(path)
        guard requestSegments.count == templateSegments.count else { return nil }
        var captured: Int64?
        for pair in zip(templateSegments, requestSegments) {
            if pair.0 == "{id}" {
                guard let identifier = Self.positiveIdentifier(pair.1) else { return nil }
                captured = identifier
            } else if pair.1 != pair.0 {
                return nil
            }
        }
        guard let identifier = captured else { return nil }
        return identifier
    }

    /// Canonical path for an id this template would match. Nil when the id is not issuable.
    public func concretePath(for identifier: Int64) -> String? {
        let text = String(identifier)
        guard Self.positiveIdentifier(text) == identifier else { return nil }
        let rendered = Self.segments(path).map { segment -> String in
            segment == "{id}" ? text : segment
        }
        return rendered.joined(separator: "/")
    }

    public static func positiveIdentifier(_ segment: String) -> Int64? {
        guard !segment.isEmpty, segment.count <= maximumIdentifierLength else { return nil }
        guard segment.allSatisfy(isASCIIDigit) else { return nil }
        if segment.count > 1, segment.first == "0" { return nil }
        guard let value = Int64(segment), value > 0, String(value) == segment else { return nil }
        return value
    }

    private static func segments(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    }

    private static func rejects(_ path: String) -> Bool {
        let lowered = path.lowercased()
        if lowered.contains("%2f") || lowered.contains("%5c") { return true }
        if path.contains("%") || path.contains("..") || path.contains("\\") { return true }
        return path.contains("?") || path.contains("#") || path.contains("*")
    }

    private static func isLiteralSegment(_ segment: String) -> Bool {
        guard !segment.isEmpty, segment != ".", segment != ".." else { return false }
        guard !segment.contains("%"), !segment.contains("{"), !segment.contains("}") else { return false }
        guard !segment.contains("?"), !segment.contains("#"), !segment.contains("*"), !segment.contains("\\") else { return false }
        return segment.allSatisfy { character in
            character.isASCII && (character.isLetter || isASCIIDigit(character) || character == "-" || character == "_")
        }
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        guard let ascii = character.asciiValue else { return false }
        return ascii >= 48 && ascii <= 57
    }
}

/// Contract §7 item 18. The six recipient reads the file, video, and voice services already build.
/// `/api/native/channels/read-through` is not here: this app has no per-message seen-by model.
public enum IMPreviewRouteTemplates {
    public static let all: [BusinessRuntimeRouteTemplate] = {
        let rows: [(String, String, BusinessRuntimeFeature)] = [
            ("GET", "api/im/file/message/{id}/authorization", .imFilePreviewStatus),
            ("GET", "api/im/file/message/{id}/preview", .imFilePreview),
            ("GET", "api/im/video/message/{id}/authorization", .imVideoPreviewStatus),
            ("GET", "api/im/video/message/{id}/preview", .imVideoPreview),
            ("GET", "api/im/voice/message/{id}", .imVoicePlayback),
            ("GET", "api/im/voice/message/{id}/authorization", .imVoicePlaybackStatus)
        ]
        var built: [BusinessRuntimeRouteTemplate] = []
        built.reserveCapacity(rows.count)
        for row in rows {
            guard let template = BusinessRuntimeRouteTemplate(method: row.0, path: row.1, feature: row.2) else {
                preconditionFailure("IM preview template \(row.1) was rejected")
            }
            built.append(template)
        }
        return built
    }()

    public static func template(for feature: BusinessRuntimeFeature) -> BusinessRuntimeRouteTemplate? {
        all.first { $0.feature == feature }
    }

    /// Normalized `{}` patterns, the form `ChinaReviewedRouteCapability` already stores.
    public static var grantPatterns: Set<String> {
        Set(all.map { template in
            "/" + template.path.replacingOccurrences(of: "{id}", with: "{}")
        })
    }
}
