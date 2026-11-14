import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ContentLandingRefusal: Error, Equatable, Sendable {
    case invalidRequest
    case approvedRefused
    case notAdmitted
}

public struct ContentLandingEnvelope: Equatable, Sendable {
    public let httpStatus: Int?
    public let code: String?
    public let reasonCode: String?
    public let message: String?
    public let dataJSON: Data?
    public let netFail: Bool

    public var ok: Bool {
        guard let httpStatus, (200...299).contains(httpStatus), code == "200" else { return false }
        return true
    }

    public var confirmed: Bool {
        guard let httpStatus, !netFail else { return false }
        return (200...299).contains(httpStatus) || (400...499).contains(httpStatus)
    }

    public var versionConflict: Bool {
        httpStatus == 409
    }
}

public enum ContentLandingTri: String, Equatable, Sendable {
    case undeclared
    case yes
    case no
}

public struct ContentLandingFact: Equatable, Sendable {
    public static let unknownMark = "—"
    public let topicID: String
    public let versionText: String
    public let summary: String
    public let groupEligible: ContentLandingTri
    public let schoolEligible: ContentLandingTri
    public let groupMin: String
    public let groupMax: String
    public let ageMin: String
    public let ageMax: String
    public let accessibilityNote: String
    public let canonicalPath: String
    public let translationState: String
    public let title: String
    public let subtitle: String
    public let translationSummary: String
    public let locale: String

    public var needsReviewAgain: Bool { translationState == "APPROVED" }
}

/// Author landing reads and writes. Price, sale, and refund fields are not sent.
/// A translation save never carries `APPROVED`.
public struct ContentLandingSource {
    public static let paths: [String] = [
        "/api/content-landing/info",
        "/api/content-landing/save",
        "/api/content-landing/translation/save"
    ]

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func info(topicID: String, token: String) async throws -> ContentLandingEnvelope {
        guard Self.isID(topicID) else { throw ContentLandingRefusal.invalidRequest }
        return try await send("/api/content-landing/info", fields: ["topicId": NSNumber(value: Int64(topicID)!)], token: token)
    }

    public func save(topicID: String, expectedVersion: String, summary: String, group: ContentLandingTri, school: ContentLandingTri,
                     groupMin: String, groupMax: String, ageMin: String, ageMax: String, accessibility: String,
                     token: String) async throws -> ContentLandingEnvelope {
        let fields = try Self.saveFields(topicID: topicID, expectedVersion: expectedVersion, summary: summary, group: group,
                                         school: school, groupMin: groupMin, groupMax: groupMax, ageMin: ageMin, ageMax: ageMax,
                                         accessibility: accessibility)
        return try await send("/api/content-landing/save", fields: fields, token: token)
    }

    public func saveTranslation(topicID: String, locale: String, title: String, subtitle: String, summary: String,
                                token: String) async throws -> ContentLandingEnvelope {
        let fields = try Self.translationFields(topicID: topicID, locale: locale, title: title, subtitle: subtitle, summary: summary)
        return try await send("/api/content-landing/translation/save", fields: fields, token: token)
    }

    public static func fact(topicID: String, in envelope: ContentLandingEnvelope) -> ContentLandingFact? {
        guard envelope.ok, let object = object(envelope.dataJSON) else { return nil }
        return fact(topicID: topicID, object: object)
    }

    public static func fact(topicID: String, object: [String: Any]) -> ContentLandingFact {
        let mark = ContentLandingFact.unknownMark
        let version = whole(object["expectedVersion"]) ?? whole(object["version"])
        return ContentLandingFact(
            topicID: topicID,
            versionText: version.map(String.init) ?? mark,
            summary: text(object["landingSummary"]) ?? "",
            groupEligible: tri(object["groupEligible"]),
            schoolEligible: tri(object["schoolEligible"]),
            groupMin: count(object["groupMinPeople"]),
            groupMax: count(object["groupMaxPeople"]),
            ageMin: count(object["ageMin"]),
            ageMax: count(object["ageMax"]),
            accessibilityNote: text(object["accessibilityNote"]) ?? "",
            canonicalPath: text(object["canonicalPath"]) ?? mark,
            translationState: text(object["translationState"]) ?? "UNKNOWN",
            title: text(object["title"]) ?? "",
            subtitle: text(object["subtitle"]) ?? "",
            translationSummary: text(object["summary"]) ?? "",
            locale: text(object["locale"]) ?? "")
    }

    public static func saveFields(topicID: String, expectedVersion: String, summary: String, group: ContentLandingTri,
                                  school: ContentLandingTri, groupMin: String, groupMax: String, ageMin: String,
                                  ageMax: String, accessibility: String) throws -> [String: Any] {
        guard isID(topicID), let version = Int64(expectedVersion), version >= 0, String(version) == expectedVersion else {
            throw ContentLandingRefusal.invalidRequest
        }
        guard summary.utf16.count <= 500, accessibility.utf16.count <= 500 else { throw ContentLandingRefusal.invalidRequest }
        var fields: [String: Any] = [
            "topicId": NSNumber(value: Int64(topicID)!),
            "expectedVersion": NSNumber(value: version),
            "landingSummary": summary.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        fields["groupEligible"] = triValue(group)
        fields["schoolEligible"] = triValue(school)
        try putCount(&fields, key: "groupMinPeople", groupMin)
        try putCount(&fields, key: "groupMaxPeople", groupMax)
        try putCount(&fields, key: "ageMin", ageMin)
        try putCount(&fields, key: "ageMax", ageMax)
        fields["accessibilityNote"] = accessibility.trimmingCharacters(in: .whitespacesAndNewlines)
        return fields
    }

    public static func translationFields(topicID: String, locale: String, title: String, subtitle: String, summary: String) throws -> [String: Any] {
        let language = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isID(topicID), !language.isEmpty, language.count <= 16,
              title.utf16.count <= 120, subtitle.utf16.count <= 160, summary.utf16.count <= 500 else {
            throw ContentLandingRefusal.invalidRequest
        }
        return [
            "topicId": NSNumber(value: Int64(topicID)!),
            "locale": language,
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "subtitle": subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            "summary": summary.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    private func send(_ path: String, fields: [String: Any], token: String) async throws -> ContentLandingEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw ContentLandingRefusal.invalidRequest }
        let refused = ["price", "payAmount", "payChannel", "amount", "status", "APPROVED"]
        if fields.keys.contains(where: { refused.contains($0) }) { throw ContentLandingRefusal.notAdmitted }
        if (fields["status"] as? String) == "APPROVED" { throw ContentLandingRefusal.approvedRefused }
        guard JSONSerialization.isValidJSONObject(fields),
              let body = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else {
            throw ContentLandingRefusal.invalidRequest
        }
        let url = path.split(separator: "/").reduce(configuration.baseURL) { $0.appendingPathComponent(String($1)) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let key = ChinaReviewedRouteCapability.normalized(path)
        guard Self.paths.contains(key), ChinaReviewedRouteCapability.hostTipSurfaceGrant.contains(key) else {
            throw ContentLandingRefusal.notAdmitted
        }
        do { try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request) }
        catch { throw ContentLandingRefusal.notAdmitted }
        do {
            let (data, status) = try await transport.send(request)
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let code = object.flatMap { $0["code"] as? String } ?? (object?["code"] as? NSNumber).map { $0.stringValue }
            return ContentLandingEnvelope(httpStatus: status, code: code ?? String(status), reasonCode: object?["reasonCode"] as? String,
                                          message: object?["msg"] as? String, dataJSON: Self.jsonData(object?["data"]), netFail: false)
        } catch {
            return ContentLandingEnvelope(httpStatus: nil, code: "fail", reasonCode: nil, message: nil, dataJSON: nil, netFail: true)
        }
    }

    private static func putCount(_ fields: inout [String: Any], key: String, _ raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        guard let number = Int(trimmed), number >= 0, String(number) == trimmed, number < 10000 else {
            throw ContentLandingRefusal.invalidRequest
        }
        fields[key] = NSNumber(value: number)
    }

    private static func triValue(_ value: ContentLandingTri) -> Any {
        switch value {
        case .undeclared: return NSNull()
        case .yes: return true
        case .no: return false
        }
    }

    private static func tri(_ value: Any?) -> ContentLandingTri {
        guard let flag = value as? Bool else { return .undeclared }
        return flag ? .yes : .no
    }

    private static func count(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "" }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() {
            return number.stringValue
        }
        if let text = value as? String { return text }
        return ContentLandingFact.unknownMark
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        return value
    }

    private static func whole(_ value: Any?) -> Int64? {
        if let text = value as? String, let number = Int64(text) { return number }
        guard let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() else { return nil }
        return number.int64Value
    }

    static func isID(_ value: String) -> Bool {
        guard let number = Int64(value), number > 0, String(number) == value else { return false }
        return true
    }

    private static func object(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func jsonData(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull), JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
