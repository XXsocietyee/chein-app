import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Voucher appeal client (IWP-7; wires nothing)
// EP-BND-19 does NOT exist in the backend yet. This file only defines the typed contract, an injected
// service protocol and an `unavailable` default (same pattern as GatedFreeExploreReservationCanceler).
// No canned response exists anywhere in this file. The first backend slice records the appeal and never
// applies the decision, so nothing here may be read as "refunded" or "consumed".

public enum BundleAppealReason: String, Codable, Equatable, CaseIterable {
    case merchantForgotScan = "MERCHANT_FORGOT_SCAN"
    case other = "OTHER"
}

public enum BundleAppealLimits {
    public static let maxEvidenceRefs = 6
    public static let maxNoteCharacters = 500
    static let maxEvidenceRefBytes = 128
}

/// `POST …/voucher/appeal` body. Persisted (without any token) before dispatch.
public struct BundleAppealCommand: Codable, Equatable {
    public let registrationId: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let reasonCode: BundleAppealReason
    public let note: String
    public let evidenceRefs: [String]
    public let idempotencyKey: String

    public init(registrationId: FreeExploreLaunchID, unitId: FreeExploreLaunchID, reasonCode: BundleAppealReason,
                note: String, evidenceRefs: [String], idempotencyKey: String) throws {
        self.registrationId = registrationId; self.unitId = unitId; self.reasonCode = reasonCode
        self.note = note; self.evidenceRefs = evidenceRefs; self.idempotencyKey = idempotencyKey
        try validate()
    }
    /// Limits are mirrored from the spec for early feedback only; the server validates again.
    func validate() throws {
        guard note.count <= BundleAppealLimits.maxNoteCharacters,
              evidenceRefs.count <= BundleAppealLimits.maxEvidenceRefs,
              Set(evidenceRefs).count == evidenceRefs.count,
              evidenceRefs.allSatisfy({ !$0.isEmpty && $0.utf8.count <= BundleAppealLimits.maxEvidenceRefBytes
                  && $0.utf8.allSatisfy { $0 >= 0x21 && $0 < 0x7f } }),
              (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 })
        else { throw FreeExploreLaunchFailure.invalid }
    }
    func wireData() throws -> Data {
        try validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

/// Server `<Appeal>`. `status` / `applyState` stay strings: unknown values must decode and never grant anything.
public struct BundleAppeal: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let reasonCode: String
    public let status: String
    public let applyState: String?
    public let idempotencyKey: String
    public let decisionReason: String?
    public let version: Int?
}

public struct BundleAppealReceipt: Decodable, Equatable {
    public enum Kind: String, Decodable, Equatable { case found = "FOUND", notFound = "NOT_FOUND" }
    public let idempotencyKey: String
    public let receipt: Kind
    public let appeal: BundleAppeal?
    /// A NOT_FOUND answer is never proof that the earlier POST did not reach the server.
    public var provesNoWrite: Bool { false }
}

private struct BundleAppealList: Decodable { let items: [BundleAppeal] }

@MainActor public protocol BundleAppealServing: AnyObject {
    func submit(_ command: BundleAppealCommand) async throws -> BundleAppeal
    func receipt(idempotencyKey: String) async throws -> BundleAppealReceipt
    func list(registrationID: FreeExploreLaunchID) async throws -> [BundleAppeal]
}

/// Default until EP-BND-19 exists and a reviewed composition injects a real service.
@MainActor public final class UnavailableBundleAppealService: BundleAppealServing {
    public init() {}
    public func submit(_ command: BundleAppealCommand) async throws -> BundleAppeal { throw FreeExploreLaunchFailure.disabled }
    public func receipt(idempotencyKey: String) async throws -> BundleAppealReceipt { throw FreeExploreLaunchFailure.disabled }
    public func list(registrationID: FreeExploreLaunchID) async throws -> [BundleAppeal] { throw FreeExploreLaunchFailure.disabled }
}

/// HTTP implementation for when the endpoint ships. Never constructed by shipped composition.
/// Envelope rules mirror BundleAPIClient: code == 200, business 409 LOGIN_REQUIRED is not 401,
/// any write whose outcome is not definite is `.outcomeUnknown` (read back with the SAME key).
@MainActor public final class BundleAppealHTTPClient: BundleAppealServing {
    public let session: FreeExploreLaunchSession
    private let authorization: String
    private let transport: any HTTPTransport
    private let currentSession: () -> FreeExploreLaunchSession?
    private let writeAllowed: () -> Bool
    private let onUnauthorized: (FreeExploreLaunchSession) -> Void
    private static let responseCap = 1_048_576

    public init(session: FreeExploreLaunchSession, authorization: String, transport: any HTTPTransport,
                currentSession: @escaping () -> FreeExploreLaunchSession?,
                writeAllowed: @escaping () -> Bool = { false },
                onUnauthorized: @escaping (FreeExploreLaunchSession) -> Void = { _ in }) throws {
        guard AuthRequestBuilder.isValidToken(authorization) else { throw FreeExploreLaunchFailure.invalid }
        self.session = session; self.authorization = authorization; self.transport = transport
        self.currentSession = currentSession; self.writeAllowed = writeAllowed; self.onUnauthorized = onUnauthorized
    }

    public func submit(_ command: BundleAppealCommand) async throws -> BundleAppeal {
        guard currentSession() == session else { throw FreeExploreLaunchFailure.staleSession }
        guard writeAllowed() else { throw FreeExploreLaunchFailure.disabled }
        let value: BundleAppeal = try await send(try request("voucher/appeal", query: [:], body: command.wireData()), write: true)
        guard value.holderMemberId == session.accountID, value.unitId == command.unitId,
              value.registrationId == command.registrationId, value.idempotencyKey == command.idempotencyKey else {
            throw FreeExploreLaunchFailure.outcomeUnknown
        }
        return value
    }

    public func receipt(idempotencyKey: String) async throws -> BundleAppealReceipt {
        let key = idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...64).contains(key.utf8.count) else { throw FreeExploreLaunchFailure.invalid }
        let value: BundleAppealReceipt = try await send(
            try request("voucher/appeal/receipt", query: ["idempotencyKey": key], body: nil), write: false)
        guard value.idempotencyKey == key else { throw FreeExploreLaunchFailure.malformed }
        switch value.receipt {
        case .found:
            guard let appeal = value.appeal, appeal.holderMemberId == session.accountID,
                  appeal.idempotencyKey == key else { throw FreeExploreLaunchFailure.malformed }
        case .notFound:
            guard value.appeal == nil else { throw FreeExploreLaunchFailure.malformed }
        }
        return value
    }

    public func list(registrationID: FreeExploreLaunchID) async throws -> [BundleAppeal] {
        let value: BundleAppealList = try await send(
            try request("voucher/appeal", query: ["registrationId": registrationID.text], body: nil), write: false)
        guard value.items.allSatisfy({ $0.holderMemberId == session.accountID && $0.registrationId == registrationID }) else {
            throw FreeExploreLaunchFailure.malformed
        }
        return value.items
    }

    private func request(_ path: String, query: [String: String], body: Data?) throws -> URLRequest {
        guard var url = URLComponents(url: session.baseURL.appendingPathComponent("api/free-explore/bundle/" + path),
                                      resolvingAgainstBaseURL: false) else { throw FreeExploreLaunchFailure.invalid }
        if !query.isEmpty { url.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) } }
        guard let endpoint = url.url else { throw FreeExploreLaunchFailure.invalid }
        var request = URLRequest(url: endpoint)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }
        return request
    }

    private struct Code: Decodable { let code: Int; let businessCode: String? }
    private struct Envelope<T: Decodable>: Decodable { let data: T? }

    private func send<T: Decodable>(_ request: URLRequest, write: Bool) async throws -> T {
        let unknown: FreeExploreLaunchFailure = write ? .outcomeUnknown : .malformed
        let response: (Data, Int)
        do { response = try await transport.send(request) } catch {
            if write { throw FreeExploreLaunchFailure.outcomeUnknown }
            throw error
        }
        let (data, status) = response
        guard currentSession() == session else { throw write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.staleSession }
        if status == 401 { onUnauthorized(session); throw APIError.unauthorized }
        guard data.count <= Self.responseCap else { throw unknown }
        let header = try? JSONDecoder().decode(Code.self, from: data)
        if header?.code == 401 { onUnauthorized(session); throw APIError.unauthorized }
        guard (200..<300).contains(status), header?.code == 200 else {
            if write, status >= 500 || header == nil { throw FreeExploreLaunchFailure.outcomeUnknown }
            throw FreeExploreLaunchFailure.response(status: status, code: header?.code ?? status, businessCode: header?.businessCode, message: nil)
        }
        guard let value = try? JSONDecoder().decode(Envelope<T>.self, from: data).data else { throw unknown }
        return value
    }
}
