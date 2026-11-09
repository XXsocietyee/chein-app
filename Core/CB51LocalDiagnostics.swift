import Foundation
import os

/// Local CB51 recorder. Off unless `QUESTIFY_CB51_DIAGNOSTICS` is exactly `1`.
/// A record is a static name plus a count. A location trail, a token, and an
/// account id are not fields and are not passed to `OSSignposter`.
public struct CB51DiagnosticRecord: Equatable, Sendable {
    public let name: String
    public let count: Int
}

public enum CB51Signpost: String, CaseIterable, Sendable {
    case mapFrame = "cb51.mapFrame"
    case listScroll = "cb51.listScroll"
    case imageDecode = "cb51.imageDecode"
    case metricSummary = "cb51.metricSummary"

    /// `OSSignposter` requires a literal. Each literal equals `rawValue`.
    var signpostName: StaticString {
        switch self {
        case .mapFrame: return "cb51.mapFrame"
        case .listScroll: return "cb51.listScroll"
        case .imageDecode: return "cb51.imageDecode"
        case .metricSummary: return "cb51.metricSummary"
        }
    }
}

public struct CB51LocalDiagnostics {
    public static let debugFlag = "QUESTIFY_CB51_DIAGNOSTICS"
    public static let subsystem = "Questify.CB51"
    public static let recordedFields = ["name", "count"]
    public let enabled: Bool
    public private(set) var records: [CB51DiagnosticRecord] = []
    private let signposter: OSSignposter?

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        enabled = Self.isEnabled(environment)
        signposter = enabled ? OSSignposter(subsystem: Self.subsystem, category: .pointsOfInterest) : nil
    }

    public static func isEnabled(_ environment: [String: String]) -> Bool {
        environment[debugFlag] == "1"
    }

    /// Closed interval on a static name. The unlabeled string is not readable here.
    public mutating func measure(_ point: CB51Signpost, _: String = "") {
        guard enabled, let signposter else { return }
        let state = signposter.beginInterval(point.signpostName)
        signposter.endInterval(point.signpostName, state)
        records.append(CB51DiagnosticRecord(name: point.rawValue, count: 1))
    }

    /// Category plus a non-negative magnitude. The unlabeled string is not readable here.
    public mutating func recordMetric(_ category: MetricKitDiagnosticCategory, count: Int, _: String = "") {
        guard enabled, count >= 0 else { return }
        records.append(CB51DiagnosticRecord(name: category.rawValue, count: count))
    }

    public func rendered() -> String {
        records.map { "\($0.name) \($0.count)" }.joined(separator: "\n")
    }
}
