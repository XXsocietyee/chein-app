import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Merchant staff approve or reject a chapter application.
/// Contract matches the mini-program owner list and audit bodies:
/// `POST api/merchant/chapter-application/owner-list` `{topicId}` and
/// `POST api/merchant/chapter-application/audit` `{applicationId, approved, auditRemark}`.
public enum MerchantStaffApproval {
    public static let listPath = "api/merchant/chapter-application/owner-list"
    public static let auditPath = "api/merchant/chapter-application/audit"

    /// Owner, or an active operator with `merchant:project:manage`.
    public static func allows(_ access: MerchantAccess) -> Bool {
        access.isOwner || access.allows(.projects)
    }
}

public enum MerchantStaffApprovalFailure: Error, Equatable {
    case denied
    case reasonRequired
    case invalid
    case unavailable
}

public struct MerchantStaffApplication: Equatable, Identifiable, Sendable {
    public let id: Int
    public let topicID: Int
    public let title: String
    public let applicant: String
    public init(id: Int, topicID: Int, title: String, applicant: String) {
        self.id = id
        self.topicID = topicID
        self.title = title
        self.applicant = applicant
    }
}

public struct MerchantStaffApprovalClient {
    public let configuration: APIConfiguration
    public let transport: any HTTPTransport
    public let token: String

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: String) {
        self.configuration = configuration
        self.transport = transport
        self.token = token
    }

    public func pending(topicID: Int, access: MerchantAccess) async throws -> [MerchantStaffApplication] {
        guard MerchantStaffApproval.allows(access) else { throw MerchantStaffApprovalFailure.denied }
        guard topicID > 0 else { throw MerchantStaffApprovalFailure.invalid }
        let object = try await post(MerchantStaffApproval.listPath, body: ["topicId": topicID])
        return Self.pendingRows(object)
    }

    public func decide(applicationID: Int, approved: Bool, remark: String, access: MerchantAccess) async throws {
        guard MerchantStaffApproval.allows(access) else { throw MerchantStaffApprovalFailure.denied }
        let note = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if !approved, note.isEmpty { throw MerchantStaffApprovalFailure.reasonRequired }
        guard applicationID > 0 else { throw MerchantStaffApprovalFailure.invalid }
        _ = try await post(MerchantStaffApproval.auditPath, body: [
            "applicationId": applicationID,
            "approved": approved,
            "auditRemark": note
        ])
    }

    private func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard AuthRequestBuilder.isValidToken(token) else { throw MerchantStaffApprovalFailure.invalid }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) } catch { throw MerchantStaffApprovalFailure.unavailable }
        guard (200..<300).contains(status),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Self.code(object["code"]) == 200 else { throw MerchantStaffApprovalFailure.unavailable }
        return object
    }

    private static func pendingRows(_ object: [String: Any]) -> [MerchantStaffApplication] {
        let data = object["data"]
        let rows: [Any]
        if let list = data as? [Any] {
            rows = list
        } else if let page = data as? [String: Any] {
            rows = (page["rows"] as? [Any]) ?? (page["list"] as? [Any]) ?? []
        } else {
            rows = []
        }
        return rows.compactMap { item in
            guard let row = item as? [String: Any] else { return nil }
            guard code(row["status"]) == 0 else { return nil }
            guard let id = code(row["applicationId"]) ?? code(row["id"]), id > 0 else { return nil }
            let topic = code(row["topicId"]) ?? 0
            let title = text(row["chapterTitle"]) ?? text(row["title"]) ?? ""
            let applicant = text(row["applicantName"]) ?? text(row["nickname"]) ?? ""
            return MerchantStaffApplication(id: id, topicID: topic, title: title, applicant: applicant)
        }
    }

    private static func code(_ value: Any?) -> Int? {
        if value is Bool { return nil }
        if let number = value as? Int { return number }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.intValue
        }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private static func text(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
