import Foundation
import CryptoKit

public enum QmodSourceSubmissionIssue: String, Error, Equatable {
    case disabled, stale, invalidPackage, storage, malformed, unknown, notFound, rejected, unauthorized
    case reviewPredecessorConflict, existingReview, requestConflict
    public var isNonterminalConflict: Bool {
        self == .reviewPredecessorConflict || self == .existingReview || self == .requestConflict
    }
}
public enum QmodSourceSubmissionWire {
    static func same(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
    static func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
    static func hashValid(_ text: String) -> Bool { text.range(of: "\\A[0-9a-f]{64}\\z", options: .regularExpression) != nil }
    static func uuid(_ text: String) -> Bool { UUID(uuidString: text).map { $0.uuidString.lowercased() == text } == true }
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func object(_ bytes: Data, limit: Int = 1 << 20) throws -> [String: Any] {
        // Check original bytes before Foundation decoding can consume a UTF-8 BOM.
        // Never strip or normalize it: source hashes and uploaded documents are exact-byte contracts.
        guard !bytes.isEmpty, bytes.count <= limit, !bytes.starts(with: [0xef, 0xbb, 0xbf]),
              let text = String(data: bytes, encoding: .utf8), !text.hasPrefix("\u{feff}") else { throw QmodSourceSubmissionIssue.invalidPackage }
        let parsed = try ContentDraftJSON.parse(text)
        func bounded(_ node: ContentDraftJSON, depth: Int) -> Bool {
            guard depth <= 32 else { return false }
            switch node {
            case .object(let value): return value.values.allSatisfy { bounded($0, depth: depth + 1) }
            case .array(let value): return value.allSatisfy { bounded($0, depth: depth + 1) }
            default: return true
            }
        }
        guard bounded(parsed, depth: 0), let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw QmodSourceSubmissionIssue.invalidPackage }
        return root
    }
    static func keys(_ object: [String: Any], _ names: Set<String>) throws {
        guard Set(object.keys) == names else { throw QmodSourceSubmissionIssue.invalidPackage }
    }
}

/// Exact original bytes. No JSON reserialization of source documents and no E1–E5 conversion.
public struct QmodSourceSubmissionSource: Codable, Equatable, Sendable {
    public let manifestBase64: String
    public let filesBase64: [String: String]
    public let nativeSort: H5OriginalSortSource?
    public var sourceKind: String {
        guard let data = Data(base64Encoded: manifestBase64), let value = try? QmodSourceSubmissionWire.object(data) else { return "" }
        return value["kind"] as? String ?? ""
    }
    public init(manifest: Data, files: [String: Data], nativeSort: H5OriginalSortSource? = nil) {
        manifestBase64 = manifest.base64EncodedString(); filesBase64 = files.mapValues { $0.base64EncodedString() }; self.nativeSort = nativeSort
    }
    public var sourceHash: String { get throws { QmodSourceSubmissionWire.hash(try QmodSourceSubmissionWire.encode(self)) } }
    public func exactBytes() throws -> [String: Data] {
        let h5 = sourceKind == "questify.h5"
        let fileLimit = h5 ? 8 << 20 : 1 << 20
        var result: [String: Data] = [:]
        for (path, encoded) in filesBase64.merging(["manifest.json": manifestBase64], uniquingKeysWith: { _, right in right }) {
            try QmodSourceLocalInputFailure.check(h5 ? "H5_ASSET_ENCODED_CHARACTERS" : "R2_ENCODED_CHARACTERS", path: path, actual: Int64(encoded.count))
            guard let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded, h5 || !bytes.isEmpty else { throw QmodSourceSubmissionIssue.invalidPackage }
            if h5 { try QmodSourceLocalInputFailure.check("H5_ASSET_BYTES", path: path, actual: Int64(bytes.count)) }
            else { try QmodSourceLocalInputFailure.check("R2_FILE_BYTES", path: path, actual: Int64(bytes.count), localFileLimit: Int64(fileLimit)) }
            result[path] = bytes
        }
        guard !filesBase64.keys.contains("manifest.json") else { throw QmodSourceSubmissionIssue.invalidPackage }
        try QmodSourceLocalInputFailure.check(h5 ? "H5_SOURCE_BYTES" : "R2_SOURCE_BYTES", path: "manifest.json", actual: Int64(result.values.reduce(0, { $0 + $1.count })))
        return result
    }
}
public struct QmodSourceSubmissionCommand: Codable, Equatable, Sendable {
    public let requestId: String
    public let source: QmodSourceSubmissionSource
    public init(requestId: String = UUID().uuidString.lowercased(), source: QmodSourceSubmissionSource) throws {
        guard QmodSourceSubmissionWire.uuid(requestId) else { throw QmodSourceSubmissionIssue.malformed }
        self.requestId = requestId; self.source = source
    }
}
/// Exact first-party media resource facts, not a client estimate or a new permission/approval.
public struct H5SourceImageLimit: Codable, Equatable, Sendable {
    public let profile: String, path: String, sourceSHA256: String, metric: String, unit: String
    public let actual: Int64, allowed: Int64
    public let atLeast: Bool
    private static let bounds: [String: (Int64, String)] = [
        "STATIC_CANVAS_PIXELS": (40_000_000, "pixels"), "ICC_PROFILE_BYTES": (8_388_608, "bytes"), "ICC_TAGS": (4_096, "tags"), "OUTPUT_BYTES": (8_388_608, "bytes"), "CHUNKS": (4_096, "chunks"), "FRAMES": (200, "frames"),
        "CANVAS_PIXELS": (4_000_000, "pixels"), "RENDERED_PIXELS": (40_000_000, "pixels"), "DURATION_MILLIS": (60_000, "milliseconds"),
        "REVIEWED_PNG_BYTES": (8_388_608, "bytes"), "DERIVED_BUNDLE_BYTES": (8_388_608, "bytes"), "ENVELOPE_BYTES": (33_554_432, "bytes")
    ]
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool {
        guard source.sourceKind == "questify.h5", profile == (metric == "STATIC_CANVAS_PIXELS" ? "h5-package-static-image-limits-v3" : ["ICC_PROFILE_BYTES", "ICC_TAGS"].contains(metric) ? "h5-package-image-color-limits-v2" : "h5-package-image-limits-v1"), let bound = Self.bounds[metric], allowed == bound.0,
              unit == bound.1, actual > allowed, atLeast == !["STATIC_CANVAS_PIXELS", "ICC_TAGS", "CANVAS_PIXELS", "RENDERED_PIXELS", "ENVELOPE_BYTES"].contains(metric), path.range(of: "\\A[A-Za-z0-9_./-]{1,200}\\z", options: .regularExpression) != nil,
              !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//"), !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }),
              QmodSourceSubmissionWire.hashValid(sourceSHA256), let encoded = path == "manifest.json" ? source.manifestBase64 : source.filesBase64[path],
              let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded else { return false }
        return QmodSourceSubmissionWire.hash(bytes) == sourceSHA256
    }
    private enum CodingKeys: String, CodingKey { case profile, path, sourceSHA256, metric, unit, actual, allowed, atLeast }
    private struct Key: CodingKey {
        let stringValue: String; var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil }
    }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["profile", "path", "sourceSHA256", "metric", "unit", "actual", "allowed", "atLeast"] else { throw QmodSourceSubmissionIssue.unknown }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(String.self, forKey: .profile); path = try c.decode(String.self, forKey: .path)
        sourceSHA256 = try c.decode(String.self, forKey: .sourceSHA256); metric = try c.decode(String.self, forKey: .metric)
        unit = try c.decode(String.self, forKey: .unit); actual = try c.decode(Int64.self, forKey: .actual); allowed = try c.decode(Int64.self, forKey: .allowed)
        atLeast = try c.decode(Bool.self, forKey: .atLeast)
    }
}
/// A committed, original-request-bound no-draft tombstone. Transient 422/404 is not this proof.
public struct QmodSourceSubmissionRejection: Codable, Equatable, Sendable, Error {
    public let schema: String, requestId: String, sourceHash: String, rejectionReason: String
    public let durable: Bool
    public let limit: QmodSourceLimitDetail?
    public init(schema: String, requestId: String, sourceHash: String, rejectionReason: String, durable: Bool, limit: QmodSourceLimitDetail? = nil) {
        self.schema = schema; self.requestId = requestId; self.sourceHash = sourceHash; self.rejectionReason = rejectionReason; self.durable = durable; self.limit = limit
    }
    public func matches(_ command: QmodSourceSubmissionCommand) -> Bool {
        guard durable, requestId == command.requestId, (try? command.source.sourceHash) == sourceHash, rejectionReason.utf8.count <= 85,
              rejectionReason.range(of: "\\AQMOD_[A-Z0-9_]{1,80}\\z", options: .regularExpression) != nil else { return false }
        if schema == "qmod-source-rejection-v1" { return limit == nil }
        guard schema == "qmod-source-rejection-v2", let limit, rejectionReason == limit.reason else { return false }
        return limit.matches(command.source)
    }
}
extension QmodSourceSubmissionRejection {
    private enum CodingKeys: String, CodingKey { case schema, requestId, sourceHash, rejectionReason, durable, limit }
    private struct Key: CodingKey {
        let stringValue: String; var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil }
    }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self), c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(String.self, forKey: .schema)
        let names: Set<String> = ["schema", "requestId", "sourceHash", "rejectionReason", "durable"]
        if schema == "qmod-source-rejection-v1" {
            guard Set(all.allKeys.map(\.stringValue)) == names else { throw QmodSourceSubmissionIssue.unknown }; limit = nil
        } else if schema == "qmod-source-rejection-v2" {
            guard Set(all.allKeys.map(\.stringValue)) == names.union(["limit"]) else { throw QmodSourceSubmissionIssue.unknown }
            limit = try c.decode(QmodSourceLimitDetail.self, forKey: .limit)
        } else { throw QmodSourceSubmissionIssue.unknown }
        requestId = try c.decode(String.self, forKey: .requestId); sourceHash = try c.decode(String.self, forKey: .sourceHash)
        rejectionReason = try c.decode(String.self, forKey: .rejectionReason); durable = try c.decode(Bool.self, forKey: .durable)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schema, forKey: .schema); try c.encode(requestId, forKey: .requestId); try c.encode(sourceHash, forKey: .sourceHash)
        try c.encode(rejectionReason, forKey: .rejectionReason); try c.encode(durable, forKey: .durable)
        if let limit { try c.encode(limit, forKey: .limit) }
    }
}
public struct QmodSourceSubmissionReceipt: Codable, Equatable, Sendable {
    public let requestId: String, sourceHash: String, state: String, editKind: String
    public let sourceId: Int64, draftId: Int64
    public let published: Bool
    public func sameIdentity(as other: Self) -> Bool {
        requestId == other.requestId && sourceId == other.sourceId && draftId == other.draftId &&
            sourceHash == other.sourceHash && state == other.state && editKind == other.editKind
    }
    public func matches(_ command: QmodSourceSubmissionCommand) -> Bool {
        requestId == command.requestId && sourceId > 0 && draftId > 0 && state == "CREATED_PRIVATE_DRAFT" && editKind == "MEMBER_TEMPLATE" &&
            (try? command.source.sourceHash) == sourceHash
    }
}
public struct QmodSourceSubmissionReviewCommand: Codable, Equatable, Sendable {
    public let sourceHash: String, draftHash: String, reviewAttemptId: String
    public let previousReviewAttemptId: String?
    public let confirmedByAuthor: Bool
    public var isValid: Bool {
        confirmedByAuthor && QmodSourceSubmissionWire.hashValid(sourceHash) && QmodSourceSubmissionWire.hashValid(draftHash) &&
            QmodSourceSubmissionWire.uuid(reviewAttemptId) && (previousReviewAttemptId.map { QmodSourceSubmissionWire.uuid($0) && $0 != reviewAttemptId } ?? true)
    }
    init(view: QmodSourceSubmissionReview, previousReviewAttemptId: String? = nil) throws {
        guard view.canSubmit, previousReviewAttemptId.map(QmodSourceSubmissionWire.uuid) ?? true else { throw QmodSourceSubmissionIssue.malformed }
        sourceHash = view.sourceHash; draftHash = view.draftHash; confirmedByAuthor = true
        reviewAttemptId = UUID().uuidString.lowercased(); self.previousReviewAttemptId = previousReviewAttemptId
    }
}
public struct QmodSourceSubmissionReview: Codable, Equatable, Sendable {
    public struct Fields: Codable, Equatable, Sendable {
        public let title: String, description: String, ruleInstructions: String, merchantGuide: String, advancedConfigJson: String
        public let validationMethod: Int
        public var qmodContentLocalesJson: String? = nil
        public func contentLocales() throws -> QmodContentLocalesArtifact? {
            guard let json = qmodContentLocalesJson else { return nil }
            return try QmodContentLocalesArtifact(json: json, expectedKind: "MEMBER_TEMPLATE", defaultPayload: QmodSourceSubmissionWire.object(QmodSourceSubmissionWire.encode(self)))
        }
    }
    public let schema: String, requestId: String, sourceHash: String, draftHash: String, phase: String, auditStatus: String
    public let sourceId: Int64, draftId: Int64, auditTaskId: Int64?
    public let published: Bool, draftMatchesReviewed: Bool
    public let fields: Fields?
    public var reviewAttemptId: String? = nil
    public var rejectionReason: String? = nil
    public var machineModeration: QmodTextModerationEvidence? = nil
    public var canSubmit: Bool { phase == "READY" && reviewAttemptId == nil && auditStatus == "NOT_SUBMITTED" && auditTaskId == nil && !published && draftMatchesReviewed && fields != nil && rejectionReason == nil }
    public var isTerminalRejection: Bool {
        phase == "PREFLIGHT_REJECTED" && reviewAttemptId.map(QmodSourceSubmissionWire.uuid) == true && auditStatus == "NOT_SUBMITTED" && auditTaskId == nil && !draftMatchesReviewed && fields == nil &&
            rejectionReason.map({ $0.utf8.count <= 85 && $0.range(of: "\\AQMOD_[A-Z0-9_]{1,80}\\z", options: .regularExpression) != nil }) == true
    }
    public func sameImmutableIdentity(as other: Self) -> Bool {
        schema == other.schema && requestId == other.requestId && sourceId == other.sourceId && draftId == other.draftId &&
            sourceHash == other.sourceHash && draftHash == other.draftHash && reviewAttemptId == other.reviewAttemptId &&
            phase == other.phase && auditTaskId == other.auditTaskId && rejectionReason == other.rejectionReason && fields == other.fields
    }
    public func matches(_ receipt: QmodSourceSubmissionReceipt) -> Bool {
        guard schema == "qmod-source-review-v1", requestId == receipt.requestId, sourceId == receipt.sourceId, draftId == receipt.draftId,
              sourceHash == receipt.sourceHash, QmodSourceSubmissionWire.hashValid(draftHash) else { return false }
        if isTerminalRejection { return true }
        guard rejectionReason == nil, let fields, fields.validationMethod == 0, fields.title.utf16.count <= 80,
              fields.description.utf16.count <= 1000, fields.advancedConfigJson.utf8.count <= 65_536 else { return false }
        if fields.qmodContentLocalesJson != nil, (try? fields.contentLocales()) == nil { return false }
        if phase == "READY" { return canSubmit }
        return phase == "SUBMITTED" && reviewAttemptId.map(QmodSourceSubmissionWire.uuid) == true && (auditTaskId ?? 0) > 0 && ["PENDING", "APPROVED", "REJECTED", "ESCALATED", "CANCELLED"].contains(auditStatus)
    }
    public func matches(_ command: QmodSourceSubmissionReviewCommand) -> Bool {
        sourceHash == command.sourceHash && draftHash == command.draftHash && command.isValid &&
            (phase == "READY" ? reviewAttemptId == nil : reviewAttemptId == command.reviewAttemptId)
    }
}

/// The server's durable rejection tombstone deliberately contains no draft fields.
/// Decode and persist that exact shape rather than mistaking an empty object for an editor snapshot.
extension QmodSourceSubmissionReview {
    private enum CodingKeys: String, CodingKey {
        case schema, requestId, sourceHash, draftHash, phase, auditStatus, sourceId, draftId, auditTaskId, published, draftMatchesReviewed, fields, reviewAttemptId, rejectionReason, machineModeration
    }
    private struct EmptyFields: Codable {
        struct Key: CodingKey { let stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
        init() {}
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            guard container.allKeys.isEmpty else { throw QmodSourceSubmissionIssue.malformed }
        }
        func encode(to encoder: Encoder) throws { _ = encoder.container(keyedBy: Key.self) }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(String.self, forKey: .schema); requestId = try c.decode(String.self, forKey: .requestId)
        sourceHash = try c.decode(String.self, forKey: .sourceHash); draftHash = try c.decode(String.self, forKey: .draftHash)
        phase = try c.decode(String.self, forKey: .phase); auditStatus = try c.decode(String.self, forKey: .auditStatus)
        sourceId = try c.decode(Int64.self, forKey: .sourceId); draftId = try c.decode(Int64.self, forKey: .draftId)
        auditTaskId = try c.decodeIfPresent(Int64.self, forKey: .auditTaskId)
        published = try c.decode(Bool.self, forKey: .published); draftMatchesReviewed = try c.decode(Bool.self, forKey: .draftMatchesReviewed)
        reviewAttemptId = try c.decodeIfPresent(String.self, forKey: .reviewAttemptId)
        rejectionReason = try c.decodeIfPresent(String.self, forKey: .rejectionReason)
        // Ancillary evidence must not poison a valid original review receipt. Its own identity is checked below.
        machineModeration = try? c.decodeIfPresent(QmodTextModerationEvidence.self, forKey: .machineModeration)
        if phase == "PREFLIGHT_REJECTED" { _ = try c.decode(EmptyFields.self, forKey: .fields); fields = nil }
        else { fields = try c.decode(Fields.self, forKey: .fields) }
        if let machineModeration, !machineModeration.matches(self) { self.machineModeration = nil }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schema, forKey: .schema); try c.encode(requestId, forKey: .requestId)
        try c.encode(sourceHash, forKey: .sourceHash); try c.encode(draftHash, forKey: .draftHash)
        try c.encode(phase, forKey: .phase); try c.encode(auditStatus, forKey: .auditStatus)
        try c.encode(sourceId, forKey: .sourceId); try c.encode(draftId, forKey: .draftId)
        try c.encode(auditTaskId, forKey: .auditTaskId); try c.encode(published, forKey: .published)
        try c.encode(machineModeration, forKey: .machineModeration)
        try c.encode(reviewAttemptId, forKey: .reviewAttemptId)
        try c.encode(draftMatchesReviewed, forKey: .draftMatchesReviewed); try c.encode(rejectionReason, forKey: .rejectionReason)
        if let fields { try c.encode(fields, forKey: .fields) } else { try c.encode(EmptyFields(), forKey: .fields) }
    }
}

/// Private author/installer artifact only. Player rendering uses QmodContentLanguageProjection's current step instead.
public struct QmodContentLocalesArtifact {
    public static let field = "qmodContentLocalesJson"
    public let defaultLocale: String
    public let locales: [String]
    public let kind: String
    private let variants: [String: [String: Any]]
    public init(json: String, expectedKind: String, defaultPayload: [String: Any]? = nil) throws {
        let root = try QmodSourceSubmissionWire.object(Data(json.utf8), limit: 524288)
        try QmodSourceSubmissionWire.keys(root, ["schema", "kind", "defaultLocale", "sourceManifestHash", "variants"])
        guard root["schema"] as? String == "qmod-content-locales-v1", root["kind"] as? String == expectedKind,
              ["MEMBER_TEMPLATE", "TOPIC"].contains(expectedKind), let language = root["defaultLocale"] as? String,
              let sourceHash = root["sourceManifestHash"] as? String, QmodSourceSubmissionWire.hashValid(sourceHash),
              let variants = root["variants"] as? [String: [String: Any]], Set(variants.keys) == ["en", "zh-Hans"],
              let original = variants[language] else { throw QmodSourceSubmissionIssue.malformed }
        for variant in variants.values {
            guard variant[Self.field] == nil else { throw QmodSourceSubmissionIssue.malformed }
            if expectedKind == "MEMBER_TEMPLATE" {
                try QmodSourceSubmissionWire.keys(variant, ["title", "description", "ruleInstructions", "merchantGuide", "validationMethod", "advancedConfigJson"])
                let fields = try JSONDecoder().decode(QmodSourceSubmissionReview.Fields.self, from: JSONSerialization.data(withJSONObject: variant))
                guard fields.validationMethod == 0, !fields.title.isEmpty, fields.title.utf16.count <= 80,
                      !fields.description.isEmpty, fields.description.utf16.count <= 1000,
                      fields.ruleInstructions == fields.description, fields.merchantGuide.utf8.count <= 128000 else { throw QmodSourceSubmissionIssue.malformed }
                _ = try ModInstallationNativeGraph(json: fields.advancedConfigJson)
            } else {
                let adapter = variant["adapter"] as? String
                guard adapter == "r2-native-choice-topic-1" || adapter == ModCompositionVenueSelection.adapter else { throw QmodSourceSubmissionIssue.malformed }
                if adapter == ModCompositionVenueSelection.adapter {
                    guard variant["compositionLockHash"] == nil, variant["namespaceVersion"] == nil, variant["moduleFrames"] == nil,
                          let nodes = variant["nodes"] as? [[String: Any]], nodes.allSatisfy({
                              ["NARRATIVE", "CHOICE", "END", "VENUE_CHECK"].contains($0["sourceType"] as? String ?? "") && $0["moduleOrigin"] == nil
                          }) else { throw QmodSourceSubmissionIssue.malformed }
                }
                _ = try ModInstallationTopicGraph(json: String(decoding: JSONSerialization.data(withJSONObject: variant, options: [.sortedKeys]), as: UTF8.self))
            }
            guard try Self.bytes(Self.mechanics(variant)) == Self.bytes(Self.mechanics(original)) else { throw QmodSourceSubmissionIssue.malformed }
        }
        if var expected = defaultPayload {
            expected.removeValue(forKey: Self.field)
            guard try Self.bytes(expected) == Self.bytes(original) else { throw QmodSourceSubmissionIssue.malformed }
        }
        defaultLocale = language; locales = variants.keys.sorted(); kind = expectedKind; self.variants = variants
    }
    public func template(locale: String) throws -> QmodSourceSubmissionReview.Fields {
        guard kind == "MEMBER_TEMPLATE", let variant = variants[locale] else { throw QmodSourceSubmissionIssue.malformed }
        return try JSONDecoder().decode(QmodSourceSubmissionReview.Fields.self, from: JSONSerialization.data(withJSONObject: variant))
    }
    private static func bytes(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes]) }
    private static func mechanics(_ value: Any) throws -> Any {
        if let map = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (key, child) in map where !["title", "description", "body", "label", "outcomeLabel", "ruleInstructions"].contains(key) {
                if key == "advancedConfigJson", let text = child as? String { out[key] = try mechanics(QmodSourceSubmissionWire.object(Data(text.utf8), limit: 65536)) }
                else { out[key] = try mechanics(child) }
            }
            return out
        }
        if let values = value as? [Any] { return try values.map(mechanics) }
        return value
    }
}

/// A current evidence projection, deliberately excluded from the original immutable review receipt identity.
public struct QmodTextModerationEvidence: Codable, Equatable, Sendable {
    public struct Language: Codable, Equatable, Sendable {
        public let locale: String, state: String, decision: String
    }
    public let schema: String, snapshotHash: String, sourceHash: String
    public let auditTaskId: Int64
    public let humanReviewRequired: Bool, publicationApproval: Bool
    public let languages: [Language]
    public func matches(_ review: QmodSourceSubmissionReview) -> Bool {
        guard schema == "qmod-text-moderation-evidence-v1", review.phase == "SUBMITTED",
              auditTaskId == review.auditTaskId, sourceHash == review.sourceHash, snapshotHash == review.draftHash,
              humanReviewRequired, !publicationApproval, languages.count == 2,
              Set(languages.map(\.locale)) == Set(["en", "zh-Hans"]) else { return false }
        return languages.allSatisfy { language in
            let pending = ["NOT_ENABLED", "NOT_CAPTURED", "WAITING_APPROVAL", "QUEUED", "IN_FLIGHT", "UNKNOWN", "SUPERSEDED"]
            if pending.contains(language.state) { return language.decision == "UNAVAILABLE" }
            return language.state == "RECORDED" && ["PASS", "REVIEW", "UNAVAILABLE"].contains(language.decision)
        }
    }
}
