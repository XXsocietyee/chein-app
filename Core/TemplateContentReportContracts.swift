import Foundation
import CryptoKit

public struct TemplateContentReportTarget: Codable, Equatable, Hashable {
    public enum Kind: String, Codable, Equatable, Hashable { case library = "TEMPLATE_LIBRARY", member = "TEMPLATE" }
    public let kind: Kind
    public let id: Int
    public init?(kind: Kind, id: Int) { guard id > 0 else { return nil }; self.kind = kind; self.id = id }
    public var writePath: String { kind == .library ? "api/template/report" : "api/template/personal-report" }
    public var detailPath: String { kind == .library ? "api/template/info" : "api/template/myinfo" }
    public static let receiptPath = "api/template/report-receipt"
    public static let policyPath = "api/v1/community/capabilities"
    public static let readPaths: Set<String> = [receiptPath, policyPath, "api/template/info", "api/template/myinfo"]
    public static let writePaths: Set<String> = ["api/template/report", "api/template/personal-report"]
    public static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    public static func uuid(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
    public static func hash(_ value: String) -> Bool { value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } }
    public static func reason(_ value: String) -> Bool { !value.isEmpty && value.utf16.count <= 64 && value.trimmingCharacters(in: .whitespacesAndNewlines) == value }
}
