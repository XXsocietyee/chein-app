import Foundation
import Observation
import CryptoKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ModOwnedReportIssue: Error { case disabled, stale, invalid, unavailable, unauthorized, persistence, conflict }
/// Independent reviewed authority. Neither commerce purchase approval nor a visible button grants report dispatch.
public struct ModOwnedReportApproval {
    public let revision = UUID()
    public let context: RuntimeDependencyContext
    public let expiresAt: Date
    public let readApprovalReference: String
    public let writeApprovalReference: String?
    public init(context: RuntimeDependencyContext, expiresAt: Date, readApprovalReference: String, writeApprovalReference: String? = nil) throws {
        _ = try APIConfiguration(baseURL: context.baseURL)
        guard context.market == .china, context.baseURL.scheme == "https", context.session.accountID > 0,
              expiresAt.timeIntervalSince1970.isFinite else { throw ModOwnedReportIssue.disabled }
        try ModInstallationValidation.text(readApprovalReference, maximum: 512)
        if let writeApprovalReference { try ModInstallationValidation.text(writeApprovalReference, maximum: 512) }
        self.context = context; self.expiresAt = expiresAt; self.readApprovalReference = readApprovalReference
        self.writeApprovalReference = writeApprovalReference
    }
    public func matches(_ context: RuntimeDependencyContext) -> Bool {
        ContentDraftContextFence.matches(self.context, context) && self.context.session.role == context.session.role && Date() < expiresAt
    }
}
public struct ModOwnedReportReason: Decodable, Equatable, Identifiable {
    public let code, label: String
    public var id: String { code }
}
public struct ModOwnedReportTarget: Decodable {
    public let licenseId, moduleId, releaseId, contentHash, termsHash, title, scope: String
    public let reasons: [ModOwnedReportReason]
    public var identity: ModInstallationIdentity { .init(licenseId: licenseId, moduleId: moduleId, releaseId: releaseId, contentHash: contentHash, termsHash: termsHash) }
    func validate(_ expected: ModInstallationIdentity) throws {
        try identity.validate()
        guard identity == expected, scope == "ORIGINAL_OWNED_RELEASE_REPORT_ONLY", title.utf8.count <= 8192,
              !reasons.isEmpty, reasons.count <= 64, Set(reasons.map(\.code)).count == reasons.count,
              reasons.allSatisfy({ !$0.code.isEmpty && $0.code.utf8.count <= 64 && !$0.label.isEmpty && $0.label.utf16.count <= 64 }) else { throw ModOwnedReportIssue.invalid }
    }
}
public struct ModOwnedReportReceipt: Codable, Equatable {
    public let actorMemberId: Int
    public let licenseId, requestId, reasonSHA256, state: String
    public let moduleId, releaseId, contentHash, termsHash: String?
    public let targetId, auditRecordId, auditTaskId: Int64?
    public let auditStatus: Int?
    func validate(_ pending: ModOwnedReportPending, actor: Int) throws {
        guard actorMemberId == actor, licenseId == pending.reference.licenseId, requestId == pending.requestId,
              reasonSHA256 == pending.reasonSHA256, ["UNKNOWN", "SUBMITTED", "ALREADY_REPORTED"].contains(state),
              auditStatus == nil || [0, 1, 2, 3, 4].contains(auditStatus!) else { throw ModOwnedReportIssue.invalid }
        if state != "UNKNOWN" {
            guard moduleId == pending.reference.moduleId, releaseId == pending.reference.releaseId,
                  contentHash == pending.reference.contentHash, termsHash == pending.reference.termsHash,
                  (targetId ?? 0) > 0, (auditRecordId ?? 0) > 0, (auditTaskId ?? 0) > 0 else { throw ModOwnedReportIssue.invalid }
        } else {
            guard targetId == nil, auditRecordId == nil, auditTaskId == nil, auditStatus == nil,
                  moduleId == nil, releaseId == nil, contentHash == nil, termsHash == nil else { throw ModOwnedReportIssue.invalid }
        }
    }
}
public struct ModOwnedReportPending: Codable, Equatable {
    public let reference: ModInstallationIdentity
    public let requestId, reasonSHA256: String
    public var receipt: ModOwnedReportReceipt?
    static func digest(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
}
/// Scope is realm + namespace + account + exact original license tuple. No token, raw reason or licensed bytes.
@MainActor public final class ModOwnedReportStore {
    private let storage: any TemplateAuthoringStorage
    private let scope: String
    private let reference: ModInstallationIdentity
    private let actor: Int
    private var key: String { "mod-owned-report-v1." + ModOwnedReportPending.digest(scope) }
    private struct Record: Codable { let scope: String; let pending: ModOwnedReportPending }
    public init(storage: any TemplateAuthoringStorage, context: RuntimeDependencyContext, reference: ModInstallationIdentity) {
        self.storage = storage; self.reference = reference; actor = context.session.accountID
        scope = [context.baseURL.absoluteString, context.session.namespace, String(actor), reference.licenseId, reference.moduleId,
                 reference.releaseId, reference.contentHash, reference.termsHash].map { "\($0.utf8.count):\($0)" }.joined()
    }
    public func load() throws -> ModOwnedReportPending? {
        guard let bytes = try storage.read(key) else { return nil }
        guard bytes.count <= 16384, let value = try? JSONDecoder().decode(Record.self, from: bytes), value.scope == scope,
              value.pending.reference == reference, UUID(uuidString: value.pending.requestId)?.uuidString.lowercased() == value.pending.requestId,
              TemplateContentReportTarget.hash(value.pending.reasonSHA256) else { throw ModOwnedReportIssue.persistence }
        try value.pending.receipt?.validate(value.pending, actor: actor)
        return value.pending
    }
    func reserve(reason: String) throws -> ModOwnedReportPending {
        guard try load() == nil else { throw ModOwnedReportIssue.conflict }
        let pending = ModOwnedReportPending(reference: reference, requestId: UUID().uuidString.lowercased(), reasonSHA256: ModOwnedReportPending.digest(reason), receipt: nil)
        try save(pending); return pending
    }
    func accept(_ receipt: ModOwnedReportReceipt, original: ModOwnedReportPending) throws {
        guard var current = try load(), current.requestId == original.requestId, current.reference == original.reference,
              current.reasonSHA256 == original.reasonSHA256 else { throw ModOwnedReportIssue.persistence }
        try receipt.validate(current, actor: actor)
        if let prior = current.receipt, prior.state != "UNKNOWN" {
            guard receipt.state == prior.state, prior.targetId == receipt.targetId,
                  prior.auditTaskId == receipt.auditTaskId, prior.auditRecordId == receipt.auditRecordId else { throw ModOwnedReportIssue.conflict }
        }
        current.receipt = receipt; try save(current)
    }
    private func save(_ pending: ModOwnedReportPending) throws {
        try storage.write(JSONEncoder().encode(Record(scope: scope, pending: pending)), key: key)
        guard try load() == pending else { throw ModOwnedReportIssue.persistence }
    }
}

/// Three exact routes, isolated ephemeral transport; no global HTTP grants, redirects, payment or asset access.
@MainActor public final class ModOwnedReportService {
    public let context: RuntimeDependencyContext
    private let lease: ContentDraftSessionLease
    private let approval: ModOwnedReportApproval
    private let currentApproval: () -> ModOwnedReportApproval?
    private let unauthorized: (RuntimeDependencyContext) -> Void
    private let session: URLSession
    private var revoked = false
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
    public init(lease: ContentDraftSessionLease, approval: ModOwnedReportApproval, currentApproval: @escaping () -> ModOwnedReportApproval?,
                unauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) throws {
        guard approval.matches(lease.context), currentApproval()?.revision == approval.revision else { throw ModOwnedReportIssue.disabled }
        self.lease = lease; context = lease.context; self.approval = approval; self.currentApproval = currentApproval; self.unauthorized = unauthorized
        let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil; config.urlCache = nil; config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    public var expiresAt: Date { approval.expiresAt }
    public var isCurrent: Bool { (try? check()) != nil }
    public var canWrite: Bool { isCurrent && approval.writeApprovalReference != nil }
    public func invalidate() { revoked = true; session.invalidateAndCancel() }
    private func check() throws {
        try Task.checkCancellation()
        guard !revoked, lease.isCurrent, approval.matches(context), let current = currentApproval(),
              current.revision == approval.revision, current.matches(context) else { throw ModOwnedReportIssue.stale }
    }
    func target(_ reference: ModInstallationIdentity) async throws -> ModOwnedReportTarget {
        try reference.validate()
        let result: ModOwnedReportTarget = try await send(license: reference.licenseId, suffix: "target")
        try result.validate(reference); return result
    }
    func receipt(_ pending: ModOwnedReportPending) async throws -> ModOwnedReportReceipt {
        try pending.reference.validate()
        guard UUID(uuidString: pending.requestId)?.uuidString.lowercased() == pending.requestId,
              TemplateContentReportTarget.hash(pending.reasonSHA256) else { throw ModOwnedReportIssue.invalid }
        let value: ModOwnedReportReceipt = try await send(license: pending.reference.licenseId,
            suffix: "reports/" + pending.requestId, reasonHash: pending.reasonSHA256)
        try value.validate(pending, actor: context.session.accountID); return value
    }
    func submit(_ pending: ModOwnedReportPending, reason: String) async throws -> ModOwnedReportReceipt {
        try check(); guard canWrite, pending.reasonSHA256 == ModOwnedReportPending.digest(reason),
            UUID(uuidString: pending.requestId)?.uuidString.lowercased() == pending.requestId else { throw ModOwnedReportIssue.disabled }
        // Always independently reread the original server tuple/reason policy, including explicit replay after UNKNOWN.
        let current = try await target(pending.reference)
        guard current.reasons.contains(where: { $0.code == reason }) else { throw ModOwnedReportIssue.invalid }
        struct Command: Encodable { let requestId, moduleId, releaseId, contentHash, termsHash, reasonCode: String }
        let reference = pending.reference
        let body = try JSONEncoder().encode(Command(requestId: pending.requestId, moduleId: reference.moduleId,
            releaseId: reference.releaseId, contentHash: reference.contentHash, termsHash: reference.termsHash, reasonCode: reason))
        let value: ModOwnedReportReceipt = try await send(license: reference.licenseId, suffix: "reports", body: body)
        try value.validate(pending, actor: context.session.accountID); return value
    }
    private struct Envelope<T: Decodable>: Decodable { let code: Int; let data: T? }
    private struct Code: Decodable { let code: Int }
    private func send<T: Decodable>(license: String, suffix: String, reasonHash: String? = nil, body: Data? = nil) async throws -> T {
        try check(); try ModInstallationValidation.key(license)
        if body != nil { guard canWrite, suffix == "reports", reasonHash == nil else { throw ModOwnedReportIssue.disabled } }
        else if suffix == "target" { guard reasonHash == nil else { throw ModOwnedReportIssue.invalid } }
        else { guard suffix.hasPrefix("reports/"), let id = suffix.split(separator: "/").last,
                     suffix == "reports/" + String(id), UUID(uuidString: String(id))?.uuidString.lowercased() == String(id),
                     let reasonHash, TemplateContentReportTarget.hash(reasonHash) else { throw ModOwnedReportIssue.invalid } }
        var components = URLComponents(url: context.baseURL.appendingPathComponent("api/mod-owned-report/licenses/" + license + "/" + suffix), resolvingAgainstBaseURL: false)
        if let reasonHash { components?.queryItems = [URLQueryItem(name: "reasonSHA256", value: reasonHash)] }
        guard let url = components?.url else { throw ModOwnedReportIssue.invalid }
        var request = URLRequest(url: url); request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body
        request.httpShouldHandleCookies = false; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(context.session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        try check(); let (data, response) = try await session.data(for: request); try check()
        guard let http = response as? HTTPURLResponse, data.count <= 65536, let text = String(data: data, encoding: .utf8),
              (try? ContentDraftJSON.parse(text)) != nil else { throw ModOwnedReportIssue.invalid }
        let code = try? JSONDecoder().decode(Code.self, from: data).code
        if http.statusCode == 401 || code == 401 { unauthorized(context); invalidate(); throw ModOwnedReportIssue.unauthorized }
        if http.statusCode == 403 || code == 403 { invalidate(); throw ModOwnedReportIssue.stale }
        guard (200..<300).contains(http.statusCode), code == 200,
              let value = try JSONDecoder().decode(Envelope<T>.self, from: data).data else { throw ModOwnedReportIssue.unavailable }
        try check(); return value
    }
}

@MainActor @Observable public final class ModOwnedReportController {
    public let reference: ModInstallationIdentity
    public private(set) var target: ModOwnedReportTarget?
    public private(set) var pending: ModOwnedReportPending?
    public private(set) var busy = false
    public private(set) var message = ""
    private let service: ModOwnedReportService
    private let store: ModOwnedReportStore
    public init(reference: ModInstallationIdentity, service: ModOwnedReportService, store: ModOwnedReportStore) {
        self.reference = reference; self.service = service; self.store = store
    }
    public var expiresAt: Date { service.expiresAt }
    public var isCurrent: Bool { service.isCurrent }
    public var canWrite: Bool { service.canWrite && !busy && target != nil }
    public func invalidate() { service.invalidate(); target = nil; pending = nil; message = "" }
    private func rejectStale() -> Bool {
        guard isCurrent else { target = nil; pending = nil; message = "stale"; return true }; return false
    }
    public func refresh() async {
        guard !busy, !rejectStale() else { return }; busy = true; defer { busy = false }
        message = ""; target = nil
        do {
            pending = try store.load()
            // Receipt recovery is independent of current artifact visibility/status and never performs a write.
            if let original = pending {
                let receipt = try await service.receipt(original)
                guard !rejectStale() else { return }; try store.accept(receipt, original: original); pending = try store.load()
            }
        } catch { if rejectStale() { return }; message = "recoveryUnavailable" }
        do { let value = try await service.target(reference); guard !rejectStale() else { return }; target = value }
        catch { if rejectStale() { return }; if message.isEmpty { message = "targetUnavailable" } }
    }
    /// An explicit confirmation is required for both first send and exact UUID replay; no automatic mutation on entry/restart.
    public func submit(reason: String) async {
        guard canWrite, target?.reasons.contains(where: { $0.code == reason }) == true, !rejectStale() else { return }
        busy = true; defer { busy = false }; message = ""
        do {
            let original: ModOwnedReportPending
            if let existing = try store.load() {
                guard existing.receipt == nil || existing.receipt?.state == "UNKNOWN" else { throw ModOwnedReportIssue.conflict }
                guard existing.reasonSHA256 == ModOwnedReportPending.digest(reason) else { throw ModOwnedReportIssue.conflict }
                original = existing
            } else { original = try store.reserve(reason: reason) }
            pending = original // Persisted before dispatch; cancellation/timeout must not mint a new UUID.
            let value = try await service.submit(original, reason: reason)
            guard !rejectStale() else { return }; try store.accept(value, original: original); pending = try store.load()
        } catch { if rejectStale() { return }; message = "unknown"; pending = try? store.load() }
    }
}
