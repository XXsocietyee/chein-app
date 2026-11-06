import Foundation

/// The enclosing original server request/sourceHash binds every input file. No hash of undecoded bytes is fabricated.
public struct QmodSourceInputLimitFact: Codable, Equatable, Sendable {
    public let profile: String, path: String, metric: String, unit: String
    public let actual: Int64, allowed: Int64
    public let atLeast: Bool
    static let profileVersion = "qmod-source-input-limits-v1"
    static let bounds: [String: (Int64, String)] = [
        "R2_ENCODED_CHARACTERS": (1_398_104, "characters"), "R2_RESOURCES": (3, "files"), "R2_SOURCE_BYTES": (2_097_152, "bytes"),
        "H5_MANIFEST_ENCODED_CHARACTERS": (349_528, "characters"), "H5_MANIFEST_BYTES": (262_144, "bytes"),
        "H5_ASSET_ENCODED_CHARACTERS": (11_184_812, "characters"), "H5_ASSET_BYTES": (8_388_608, "bytes"),
        "H5_RESOURCES": (256, "files"), "H5_SOURCE_BYTES": (8_388_608, "bytes")
    ]
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool {
        guard profile == Self.profileVersion, let bound = Self.bounds[metric], allowed == bound.0, unit == bound.1,
              actual > allowed, atLeast == (metric == "H5_SOURCE_BYTES"), path.range(of: "\\A[A-Za-z0-9_./-]{1,200}\\z", options: .regularExpression) != nil,
              !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//"), !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { return false }
        return path == "manifest.json" || source.filesBase64[path] != nil
    }
    private enum CodingKeys: String, CodingKey { case profile, path, metric, unit, actual, allowed, atLeast }
    private struct Key: CodingKey { let stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["profile", "path", "metric", "unit", "actual", "allowed", "atLeast"] else { throw QmodSourceSubmissionIssue.unknown }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(String.self, forKey: .profile); path = try c.decode(String.self, forKey: .path); metric = try c.decode(String.self, forKey: .metric)
        unit = try c.decode(String.self, forKey: .unit); actual = try c.decode(Int64.self, forKey: .actual); allowed = try c.decode(Int64.self, forKey: .allowed); atLeast = try c.decode(Bool.self, forKey: .atLeast)
    }
}

/// Original server-measured audio limit. The approved bound is retained with its immutable policy hash/reference;
/// there is deliberately no invented local duration/rate policy and no interpretation as content approval.
public struct H5SourceAudioLimit: Codable, Equatable, Sendable {
    public let profile: String, path: String, sourceSHA256: String, metric: String, unit: String, policyHash: String, approvalReference: String
    public let actual: Int64, allowed: Int64
    public let atLeast: Bool
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool {
        let units = ["AUDIO_PCM_BYTES": "bytes", "AUDIO_PROBE_BYTES": "bytes", "AUDIO_DURATION_MILLIS": "milliseconds", "AUDIO_SAMPLE_RATE": "hertz", "AUDIO_CHANNELS": "channels"]
        guard profile == "h5-package-audio-limits-v1", units[metric] == unit, allowed > 0, allowed <= Int64(Int32.max), actual > allowed,
              atLeast == ["AUDIO_PCM_BYTES", "AUDIO_PROBE_BYTES"].contains(metric), QmodSourceSubmissionWire.hashValid(sourceSHA256), QmodSourceSubmissionWire.hashValid(policyHash),
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, approvalReference.utf16.count <= 256,
              path.range(of: "\\A[A-Za-z0-9_./-]{1,200}\\z", options: .regularExpression) != nil, !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//"),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }), ["mp3", "aac", "m4a", "wav"].contains((path as NSString).pathExtension.lowercased()),
              let encoded = source.filesBase64[path], let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
              QmodSourceSubmissionWire.hash(bytes) == sourceSHA256 else { return false }
        switch metric {
        case "AUDIO_PCM_BYTES": return allowed <= 8_388_608 - 44
        case "AUDIO_PROBE_BYTES": return allowed <= 8_388_608
        case "AUDIO_SAMPLE_RATE": return allowed <= Int64(Int32.max / 4)
        case "AUDIO_CHANNELS": return allowed <= 2
        default: return true
        }
    }
    private enum CodingKeys: String, CodingKey { case profile, path, sourceSHA256, metric, unit, actual, allowed, atLeast, policyHash, approvalReference }
    private struct Key: CodingKey { let stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["profile", "path", "sourceSHA256", "metric", "unit", "actual", "allowed", "atLeast", "policyHash", "approvalReference"] else { throw QmodSourceSubmissionIssue.unknown }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(String.self, forKey: .profile); path = try c.decode(String.self, forKey: .path); sourceSHA256 = try c.decode(String.self, forKey: .sourceSHA256)
        metric = try c.decode(String.self, forKey: .metric); unit = try c.decode(String.self, forKey: .unit)
        actual = try c.decode(Int64.self, forKey: .actual); allowed = try c.decode(Int64.self, forKey: .allowed); atLeast = try c.decode(Bool.self, forKey: .atLeast)
        policyHash = try c.decode(String.self, forKey: .policyHash); approvalReference = try c.decode(String.self, forKey: .approvalReference)
    }
}

/// Original complete-video producer limits; own real technical policy, never IM or standalone audio authorization.
public struct H5SourceVideoLimit: Codable, Equatable, Sendable {
    public let profile: String, path: String, sourceSHA256: String, metric: String, unit: String, policyHash: String, approvalReference: String
    public let actual: Int64, allowed: Int64
    public let atLeast: Bool
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool {
        let units = ["VIDEO_OUTPUT_BYTES": "bytes", "VIDEO_PROBE_BYTES": "bytes", "VIDEO_PIXELS": "pixels", "VIDEO_FRAMES": "frames",
                     "VIDEO_DECODED_RGB_BYTES": "bytes", "VIDEO_REVIEWED_FRAME_BYTES": "bytes", "VIDEO_PRIVATE_PROOF_BYTES": "bytes", "VIDEO_DURATION_MILLIS": "milliseconds",
                     "VIDEO_AUDIO_PCM_BYTES": "bytes", "VIDEO_AUDIO_SAMPLE_RATE": "hertz", "VIDEO_AUDIO_CHANNELS": "channels"]
        guard source.sourceKind == "questify.h5", profile == "h5-package-video-limits-v1", units[metric] == unit, allowed > 0, allowed <= Int64(Int32.max), actual > allowed,
              atLeast == ["VIDEO_OUTPUT_BYTES", "VIDEO_PROBE_BYTES", "VIDEO_DECODED_RGB_BYTES", "VIDEO_REVIEWED_FRAME_BYTES", "VIDEO_PRIVATE_PROOF_BYTES", "VIDEO_AUDIO_PCM_BYTES"].contains(metric), QmodSourceSubmissionWire.hashValid(sourceSHA256), QmodSourceSubmissionWire.hashValid(policyHash),
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, approvalReference.utf16.count <= 256,
              path.range(of: "\\A[A-Za-z0-9_./-]{1,200}\\z", options: .regularExpression) != nil, !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//"),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }), ["mp4", "mov"].contains((path as NSString).pathExtension.lowercased()),
              let encoded = source.filesBase64[path], let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
              QmodSourceSubmissionWire.hash(bytes) == sourceSHA256 else { return false }
        switch metric {
        case "VIDEO_AUDIO_PCM_BYTES": return allowed <= 8_388_608 - 44
        case "VIDEO_OUTPUT_BYTES", "VIDEO_PROBE_BYTES": return allowed <= 8_388_608
        case "VIDEO_PIXELS": return allowed <= 40_000_000
        case "VIDEO_REVIEWED_FRAME_BYTES", "VIDEO_PRIVATE_PROOF_BYTES": return allowed <= 33_554_432
        case "VIDEO_AUDIO_SAMPLE_RATE": return allowed <= Int64(Int32.max / 4)
        case "VIDEO_AUDIO_CHANNELS": return allowed <= 2
        default: return true
        }
    }

    private enum CodingKeys: String, CodingKey { case profile, path, sourceSHA256, metric, unit, actual, allowed, atLeast, policyHash, approvalReference }
    private struct Key: CodingKey { let stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["profile", "path", "sourceSHA256", "metric", "unit", "actual", "allowed", "atLeast", "policyHash", "approvalReference"] else { throw QmodSourceSubmissionIssue.unknown }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(String.self, forKey: .profile); path = try c.decode(String.self, forKey: .path); sourceSHA256 = try c.decode(String.self, forKey: .sourceSHA256)
        metric = try c.decode(String.self, forKey: .metric); unit = try c.decode(String.self, forKey: .unit)
        actual = try c.decode(Int64.self, forKey: .actual); allowed = try c.decode(Int64.self, forKey: .allowed); atLeast = try c.decode(Bool.self, forKey: .atLeast)
        policyHash = try c.decode(String.self, forKey: .policyHash); approvalReference = try c.decode(String.self, forKey: .approvalReference)
    }
}

/// Original complete static-font producer facts; embedding flags never establish rights.
public struct H5SourceFontLimit: Codable, Equatable, Sendable {
    public let profile: String, path: String, sourceSHA256: String, metric: String, unit: String, policyHash: String, approvalReference: String
    public let actual: Int64, allowed: Int64
    public let atLeast: Bool
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool {
        let units = ["FONT_OUTPUT_BYTES": "bytes", "FONT_DECODED_BYTES": "bytes", "FONT_LOG_BYTES": "bytes", "FONT_TABLES": "tables", "FONT_GLYPHS": "glyphs",
                     "FONT_GLYPH_PIXELS": "pixels", "FONT_RENDERED_PIXELS": "pixels", "FONT_REVIEWED_GLYPH_BYTES": "bytes", "FONT_PRIVATE_PROOF_BYTES": "bytes",
                     "FONT_METADATA_BYTES": "bytes", "FONT_PRIVATE_BYTES": "bytes"]
        guard source.sourceKind == "questify.h5", profile == "h5-package-font-limits-v1", units[metric] == unit, allowed > 0, allowed <= Int64(Int32.max), actual > allowed,
              atLeast == ["FONT_OUTPUT_BYTES", "FONT_DECODED_BYTES", "FONT_LOG_BYTES", "FONT_RENDERED_PIXELS", "FONT_REVIEWED_GLYPH_BYTES", "FONT_PRIVATE_PROOF_BYTES", "FONT_METADATA_BYTES"].contains(metric), QmodSourceSubmissionWire.hashValid(sourceSHA256), QmodSourceSubmissionWire.hashValid(policyHash),
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, approvalReference.utf16.count <= 256,
              path.range(of: "\\A[A-Za-z0-9_./-]{1,200}\\z", options: .regularExpression) != nil, !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//"),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }), ["ttf", "otf", "woff", "woff2"].contains((path as NSString).pathExtension.lowercased()),
              let encoded = source.filesBase64[path], let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
              QmodSourceSubmissionWire.hash(bytes) == sourceSHA256 else { return false }
        switch metric {
        case "FONT_OUTPUT_BYTES", "FONT_DECODED_BYTES", "FONT_LOG_BYTES", "FONT_METADATA_BYTES", "FONT_PRIVATE_BYTES": return allowed <= 8_388_608
        case "FONT_TABLES", "FONT_GLYPHS": return allowed <= 65_535
        case "FONT_GLYPH_PIXELS": return allowed <= 40_000_000
        case "FONT_REVIEWED_GLYPH_BYTES", "FONT_PRIVATE_PROOF_BYTES": return allowed <= 33_554_432
        default: return true
        }
    }

    private enum CodingKeys: String, CodingKey { case profile, path, sourceSHA256, metric, unit, actual, allowed, atLeast, policyHash, approvalReference }
    private struct Key: CodingKey { let stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["profile", "path", "sourceSHA256", "metric", "unit", "actual", "allowed", "atLeast", "policyHash", "approvalReference"] else { throw QmodSourceSubmissionIssue.unknown }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(String.self, forKey: .profile); path = try c.decode(String.self, forKey: .path); sourceSHA256 = try c.decode(String.self, forKey: .sourceSHA256)
        metric = try c.decode(String.self, forKey: .metric); unit = try c.decode(String.self, forKey: .unit)
        actual = try c.decode(Int64.self, forKey: .actual); allowed = try c.decode(Int64.self, forKey: .allowed); atLeast = try c.decode(Bool.self, forKey: .atLeast)
        policyHash = try c.decode(String.self, forKey: .policyHash); approvalReference = try c.decode(String.self, forKey: .approvalReference)
    }
}

/// Complete COLR0 palette/layer facts from the original SOURCE writer; no guessed foreground or first-palette approval.
public struct H5SourceFontColorLimit: Codable, Equatable, Sendable {
    public let profile: String, path: String, sourceSHA256: String, metric: String, unit: String, policyHash: String, approvalReference: String
    public let actual: Int64, allowed: Int64
    public let atLeast: Bool
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool {
        let units = ["FONT_COLOR_PALETTES": "palettes", "FONT_COLOR_LAYERS": "layers", "FONT_COLOR_COMPOSITIONS": "compositions", "FONT_COLOR_LAYER_APPLICATIONS": "layerApplications"]
        guard source.sourceKind == "questify.h5", profile == "h5-package-font-color-limits-v1", units[metric] == unit, allowed > 0, allowed <= Int64(Int32.max), actual > allowed,
              !atLeast, QmodSourceSubmissionWire.hashValid(sourceSHA256), QmodSourceSubmissionWire.hashValid(policyHash),
              !approvalReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, approvalReference.utf16.count <= 256,
              path.range(of: "\\A[A-Za-z0-9_./-]{1,200}\\z", options: .regularExpression) != nil, !path.hasPrefix("/"), !path.hasSuffix("/"), !path.contains("//"),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }), ["ttf", "otf", "woff", "woff2"].contains((path as NSString).pathExtension.lowercased()),
              let encoded = source.filesBase64[path], let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
              QmodSourceSubmissionWire.hash(bytes) == sourceSHA256 else { return false }
        return !["FONT_COLOR_PALETTES", "FONT_COLOR_LAYERS"].contains(metric) || allowed <= 65_535
    }

    private enum CodingKeys: String, CodingKey { case profile, path, sourceSHA256, metric, unit, actual, allowed, atLeast, policyHash, approvalReference }
    private struct Key: CodingKey { let stringValue: String; var intValue: Int? { nil }; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
    public init(from decoder: Decoder) throws {
        let all = try decoder.container(keyedBy: Key.self)
        guard Set(all.allKeys.map(\.stringValue)) == ["profile", "path", "sourceSHA256", "metric", "unit", "actual", "allowed", "atLeast", "policyHash", "approvalReference"] else { throw QmodSourceSubmissionIssue.unknown }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profile = try c.decode(String.self, forKey: .profile); path = try c.decode(String.self, forKey: .path); sourceSHA256 = try c.decode(String.self, forKey: .sourceSHA256)
        metric = try c.decode(String.self, forKey: .metric); unit = try c.decode(String.self, forKey: .unit)
        actual = try c.decode(Int64.self, forKey: .actual); allowed = try c.decode(Int64.self, forKey: .allowed); atLeast = try c.decode(Bool.self, forKey: .atLeast)
        policyHash = try c.decode(String.self, forKey: .policyHash); approvalReference = try c.decode(String.self, forKey: .approvalReference)
    }
}

/// Exact flat versioned nested proof. Historical image-limit bytes retain their original representation.
public enum QmodSourceLimitDetail: Codable, Equatable, Sendable {
    case image(H5SourceImageLimit), input(QmodSourceInputLimitFact), audio(H5SourceAudioLimit), video(H5SourceVideoLimit), font(H5SourceFontLimit), fontColor(H5SourceFontColorLimit)
    private struct Profile: Decodable { let profile: String }
    public init(from decoder: Decoder) throws {
        switch try Profile(from: decoder).profile {
        case "h5-package-image-limits-v1", "h5-package-image-color-limits-v2", "h5-package-static-image-limits-v3": self = .image(try H5SourceImageLimit(from: decoder))
        case "h5-package-font-color-limits-v1": self = .fontColor(try H5SourceFontColorLimit(from: decoder))
        case "h5-package-font-limits-v1": self = .font(try H5SourceFontLimit(from: decoder))
        case "h5-package-video-limits-v1": self = .video(try H5SourceVideoLimit(from: decoder))
        case "h5-package-audio-limits-v1": self = .audio(try H5SourceAudioLimit(from: decoder))
        case QmodSourceInputLimitFact.profileVersion: self = .input(try QmodSourceInputLimitFact(from: decoder))
        default: throw QmodSourceSubmissionIssue.unknown
        }
    }
    public func encode(to encoder: Encoder) throws { switch self { case .image(let value): try value.encode(to: encoder); case .audio(let value): try value.encode(to: encoder); case .video(let value): try value.encode(to: encoder); case .font(let value): try value.encode(to: encoder); case .fontColor(let value): try value.encode(to: encoder); case .input(let value): try value.encode(to: encoder) } }
    public var profile: String { switch self { case .image(let v): return v.profile; case .audio(let v): return v.profile; case .video(let v): return v.profile; case .font(let v): return v.profile; case .fontColor(let v): return v.profile; case .input(let v): return v.profile } }
    public var path: String { switch self { case .image(let v): return v.path; case .audio(let v): return v.path; case .video(let v): return v.path; case .font(let v): return v.path; case .fontColor(let v): return v.path; case .input(let v): return v.path } }
    public var metric: String { switch self { case .image(let v): return v.metric; case .audio(let v): return v.metric; case .video(let v): return v.metric; case .font(let v): return v.metric; case .fontColor(let v): return v.metric; case .input(let v): return v.metric } }
    public var unit: String { switch self { case .image(let v): return v.unit; case .audio(let v): return v.unit; case .video(let v): return v.unit; case .font(let v): return v.unit; case .fontColor(let v): return v.unit; case .input(let v): return v.unit } }
    public var actual: Int64 { switch self { case .image(let v): return v.actual; case .audio(let v): return v.actual; case .video(let v): return v.actual; case .font(let v): return v.actual; case .fontColor(let v): return v.actual; case .input(let v): return v.actual } }
    public var allowed: Int64 { switch self { case .image(let v): return v.allowed; case .audio(let v): return v.allowed; case .video(let v): return v.allowed; case .font(let v): return v.allowed; case .fontColor(let v): return v.allowed; case .input(let v): return v.allowed } }
    public var atLeast: Bool { switch self { case .image(let v): return v.atLeast; case .audio(let v): return v.atLeast; case .video(let v): return v.atLeast; case .font(let v): return v.atLeast; case .fontColor(let v): return v.atLeast; case .input(let v): return v.atLeast } }
    public var sourceSHA256: String? { switch self { case .image(let value): return value.sourceSHA256; case .audio(let value): return value.sourceSHA256; case .video(let value): return value.sourceSHA256; case .font(let value): return value.sourceSHA256; case .fontColor(let value): return value.sourceSHA256; case .input: return nil } }
    public var reason: String { switch self { case .image(let v): return "QMOD_H5_IMAGE_LIMIT_" + v.metric; case .audio(let v): return "QMOD_H5_AUDIO_LIMIT_" + v.metric; case .video(let v): return "QMOD_H5_VIDEO_LIMIT_" + v.metric; case .font(let v): return "QMOD_H5_FONT_LIMIT_" + v.metric; case .fontColor(let v): return "QMOD_H5_FONT_COLOR_LIMIT_" + v.metric; case .input(let v): return "QMOD_SOURCE_INPUT_LIMIT_" + v.metric } }
    public func matches(_ source: QmodSourceSubmissionSource) -> Bool { switch self { case .image(let v): return v.matches(source); case .audio(let v): return v.matches(source); case .video(let v): return v.matches(source); case .font(let v): return v.matches(source); case .fontColor(let v): return v.matches(source); case .input(let v): return v.matches(source) } }
}

/// A retained local observation, explicitly NOT a server request, acceptance, no-write proof, or authority to clear pending.
public struct QmodSourceLocalInputFailure: Codable, Equatable, Sendable, Error, Identifiable {
    public struct Fact: Codable, Equatable, Sendable {
        public let profile: String, path: String, metric: String, unit: String, measurement: String
        public let actual: Int64, allowed: Int64
        public let proposal: Bool
        public var displayPath: String { path.unicodeScalars.map { scalar in
            (scalar.value >= 0x21 && scalar.value <= 0x7e && scalar.value != 0x5c) ? String(scalar) : "\\u{" + String(scalar.value, radix: 16) + "}"
        }.joined() }
        var valid: Bool {
            !profile.isEmpty && profile.utf8.count <= 128 && !path.isEmpty && path.utf8.count <= 262144 && metric.range(of: "\\A[A-Z0-9_]{1,64}\\z", options: .regularExpression) != nil &&
                ["bytes", "files", "characters", "levels"].contains(unit) && ["ACTUAL", "AT_LEAST", "ZIP_DECLARED", "FILE_METADATA"].contains(measurement) && allowed >= 0 && actual > allowed
        }
    }
    public let schema: String, id: String, packageLabel: String
    public let archiveSHA256: String?
    public let facts: [Fact]
    public let otherChecksBlocked: Bool
    public var valid: Bool {
        schema == "qmod-local-source-input-failure-v1" && QmodSourceSubmissionWire.uuid(id) && !packageLabel.isEmpty && packageLabel.count <= 200 &&
            (archiveSHA256.map(QmodSourceSubmissionWire.hashValid) ?? true) && !facts.isEmpty && facts.count <= 520 && facts.allSatisfy(\.valid)
    }
    func identifying(label: String, archive: Data?) -> Self {
        Self(schema: schema, id: id, packageLabel: QmodArchiveLabels.sanitize(label), archiveSHA256: archive.map(QmodSourceSubmissionWire.hash), facts: facts.map { fact in
            Fact(profile: fact.profile, path: fact.path == "@archive" ? label : fact.path, metric: fact.metric, unit: fact.unit, measurement: fact.measurement, actual: fact.actual, allowed: fact.allowed, proposal: fact.proposal)
        }, otherChecksBlocked: otherChecksBlocked)
    }
    static func check(_ metric: String, path: String, actual: Int64, localFileLimit: Int64? = nil) throws {
        let bound: (Int64, String)
        if let localFileLimit { bound = (localFileLimit, "bytes") }
        else { guard let value = QmodSourceInputLimitFact.bounds[metric] else { throw QmodSourceSubmissionIssue.invalidPackage }; bound = value }
        guard actual > bound.0 else { return }
        throw Self.make(facts: [.init(profile: localFileLimit == nil ? QmodSourceInputLimitFact.profileVersion : "qmod-local-source-file-safety-v1", path: path,
            metric: metric, unit: bound.1, measurement: metric == "H5_SOURCE_BYTES" ? "AT_LEAST" : "ACTUAL", actual: actual, allowed: bound.0, proposal: false)])
    }
    static func readBudget(actual: Int64, allowed: Int64, label: String, metadata: Bool) -> Self {
        make(facts: [.init(profile: "qmod-source-local-read-safety-v1", path: label, metric: "READ_BYTES", unit: "bytes", measurement: metadata ? "FILE_METADATA" : "AT_LEAST", actual: actual, allowed: allowed, proposal: false)]).identifying(label: label, archive: nil)
    }
    static func archive(_ report: QmodLocalInspectionReport, limits: QmodLimitProfile, package: Data, observations: [Fact] = []) -> Self? {
        var facts: [Fact] = observations; var other = false
        func add(_ metric: String, _ path: String?, _ actual: Int64, _ allowed: Int64, _ unit: String, _ measurement: String) {
            facts.append(.init(profile: limits.profileVersion, path: path ?? "@archive", metric: metric, unit: unit, measurement: measurement, actual: actual, allowed: allowed, proposal: limits.isProposal))
        }
        for issue in report.issues {
            switch issue.code {
            case .archiveTooLarge(let actual, let limit): add("ARCHIVE_BYTES", nil, actual, limit, "bytes", "ACTUAL")
            case .readBudgetExceeded(let actual, let limit): add("READ_BYTES", nil, actual, limit, "bytes", "AT_LEAST")
            case .fileTooLarge(let path, let actual, let limit): add("FILE_BYTES", path, actual, limit, "bytes", "ZIP_DECLARED")
            case .expandedTooLarge(let path, let actual, let limit): add("EXPANDED_BYTES", path, actual, limit, "bytes", "ZIP_DECLARED")
            case .tooManyEntries(let actual, let limit): add("RESOURCE_COUNT", nil, Int64(actual), Int64(limit), "files", "ACTUAL")
            case .abnormalCompression(let path, let compressed, let uncompressed):
                let (product, overflow) = compressed.multipliedReportingOverflow(by: report.expansionNumerator)
                if !overflow, report.expansionDenominator > 0, uncompressed > product / report.expansionDenominator {
                    facts.append(.init(profile: "qmod-local-expansion-stop-v1", path: path, metric: "EXPANSION_BYTES", unit: "bytes", measurement: "ZIP_DECLARED", actual: uncompressed, allowed: product / report.expansionDenominator, proposal: false))
                } else { other = true } // A generic old inflate failure is not a measured ratio or invented byte count.
            case .unsafeEntry(let path):
                if path.count > limits.maxPathLength { add("PATH_LENGTH", path, Int64(path.count), Int64(limits.maxPathLength), "characters", "ACTUAL") }
                let depth = path.split(separator: "/", omittingEmptySubsequences: false).count
                if depth > limits.maxDepth { add("PATH_DEPTH", path, Int64(depth), Int64(limits.maxDepth), "levels", "ACTUAL") }
                other = true // Unsafe paths can violate more than their length/depth; never claim the other checks passed.
            default: other = true
            }
        }
        guard !facts.isEmpty else { return nil }
        let value = make(facts: facts, other: other)
        return Self(schema: value.schema, id: value.id, packageLabel: report.packageLabel, archiveSHA256: QmodSourceSubmissionWire.hash(package), facts: facts, otherChecksBlocked: other)
    }
    private static func make(facts: [Fact], other: Bool = false) -> Self {
        Self(schema: "qmod-local-source-input-failure-v1", id: UUID().uuidString.lowercased(), packageLabel: "source", archiveSHA256: nil, facts: facts, otherChecksBlocked: other)
    }
}
