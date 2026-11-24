import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Keep actionable server text without displaying arbitrary networking/debug descriptions.
public struct ProfileReadFailure: Error, Equatable {
    public let httpStatus: Int?
    public let code: Int?
    public let message: String?
    /// Server `errorCode` string (A3-07: `NICKNAME_TAKEN` / `NICKNAME_INVALID` on a profile save).
    public let errorCode: String?
    public var isUnauthorized: Bool { httpStatus == 401 || code == 401 }
    /// Signed in but refused (当前账号无法查看): neither sign-in nor an empty wall.
    public var isDenied: Bool { !isUnauthorized && (httpStatus == 403 || code == 403) }
    public init(httpStatus: Int? = nil, code: Int? = nil, message: String? = nil, errorCode: String? = nil) {
        self.httpStatus = httpStatus; self.code = code; self.message = message; self.errorCode = errorCode
    }
}

/// Own-account reads only. No production host, mutations, payment, player-code issuance,
/// retry loop, credential storage, or redirection. Inject the existing no-redirect transport.
/// One page of `POST /api/registration/list` as `scene-member-order-history` sends it.
public struct ProfileOrderPage: Equatable {
    public let rows: [ProfileOrder]
    public let total: Int?
    public let pageNum: Int
    public let pageSize: Int
    /// More pages when this page is full and the loaded count is still under `total`.
    public var hasMore: Bool {
        guard let total, pageSize > 0 else { return false }
        let loaded = (pageNum - 1) * pageSize + rows.count
        return rows.count >= pageSize && loaded < total
    }
}

public struct ProfileService {
    /// `app.getPageSize()` in the mini-program.
    public static let registrationListPageSize = 10
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }

    public func orders(token: String, expectedAccountID: Int? = nil) async throws -> [ProfileOrder] {
        if let expectedAccountID, expectedAccountID <= 0 { throw APIError.invalidRequest }
        let result: OrderRows = try await execute(form("api/registration/list", fields: ["owner_type": "3"], token: token))
        if let expectedAccountID {
            guard result.isTable, result.total == result.rows.count,
                  result.rows.allSatisfy({ $0.memberID == expectedAccountID }),
                  Set(result.rows.map(\.id)).count == result.rows.count else { throw APIError.malformedResponse }
        }
        return result.rows
    }
    /// `pageNum` / `pageSize` / `owner_type: 3` / `status: "0"`. Does not replace `orders()`, which stays unpaged.
    public func orderHistory(token: String, pageNum: Int, pageSize: Int = ProfileService.registrationListPageSize, expectedAccountID: Int? = nil) async throws -> ProfileOrderPage {
        if let expectedAccountID, expectedAccountID <= 0 { throw APIError.invalidRequest }
        guard pageNum > 0, (1...100).contains(pageSize) else { throw APIError.invalidRequest }
        let result: OrderRows = try await execute(form("api/registration/list", fields: [
            "pageNum": String(pageNum), "pageSize": String(pageSize), "owner_type": "3", "status": "0"
        ], token: token))
        if let expectedAccountID {
            guard result.rows.allSatisfy({ $0.memberID == expectedAccountID }),
                  Set(result.rows.map(\.id)).count == result.rows.count else { throw APIError.malformedResponse }
        }
        return ProfileOrderPage(rows: result.rows, total: result.total, pageNum: pageNum, pageSize: pageSize)
    }
    public func order(id: Int, token: String, expectedAccountID: Int? = nil) async throws -> ProfileOrder {
        if let expectedAccountID, expectedAccountID <= 0 { throw APIError.invalidRequest }
        guard id > 0 else { throw APIError.invalidRequest }
        let result: ProfileOrder = try await execute(form("api/registration/info", fields: ["id": String(id)], token: token))
        guard result.id == id else { throw APIError.malformedResponse }
        if let expectedAccountID, result.memberID != expectedAccountID { throw APIError.malformedResponse }
        return result
    }

    /// Same multipart `id` form as `order(id:token:)`. Returns the response bytes unchanged.
    /// An empty body is nil. This does not decode those bytes and does not build an audit row.
    public func postOwnedOrderForm(path: String, id: String, token: String) async throws -> Data? {
        guard path == "api/registration/info" || path == "api/registration/original-event" else {
            throw APIError.invalidRequest
        }
        guard let orderID = Int(id), orderID > 0, String(orderID) == id else { throw APIError.invalidRequest }
        let request = try form(path, fields: ["id": id], token: token)
        try Task.checkCancellation()
        let (data, _) = try await transport.send(request)
        try Task.checkCancellation()
        return data.isEmpty ? nil : data
    }

    public func participants(token: String) async throws -> [ProfileParticipant] {
        let result: ParticipantRows = try await execute(bodyless("api/user/address/list", token: token))
        return result.rows
    }
    /// Same bodyless POST as `participants`. Also keeps the table `total` already on that payload.
    /// Does not add a route or change `participants()`.
    public func participantListFacts(token: String) async throws -> ProfileParticipantListFacts {
        try await execute(bodyless("api/user/address/list", token: token))
    }
    public func participant(id: Int, token: String) async throws -> ProfileParticipant {
        guard id > 0 else { throw APIError.invalidRequest }
        let result: ProfileParticipant = try await execute(form("api/user/address/info", fields: ["id": String(id)], token: token))
        guard result.id == id else { throw APIError.malformedResponse }
        return result
    }
    public func badgeWall(token: String) async throws -> ProfileBadgeWall {
        // Identity is the source's required primary collection. A medal failure must not
        // erase those cards or silently present an incomplete wall as a complete result.
        let identities: IdentityWall = try await execute(jsonEmpty("api/badge/wall-v2", token: token))
        do {
            let medals: MedalWall = try await execute(jsonEmpty("api/medal/wall", token: token))
            return ProfileBadgeWall(identities: identities.identity, medals: medals.medals)
        } catch is CancellationError { throw CancellationError() }
        catch let failure as ProfileReadFailure where failure.isUnauthorized { throw failure }
        catch {
            try Task.checkCancellation()
            return ProfileBadgeWall(identities: identities.identity, medals: nil,
                                    medalFailureMessage: (error as? ProfileReadFailure)?.message,
                                    medalReadRestriction: ProfileMedalReadRestriction.classify(error))
        }
    }

    private func form(_ path: String, fields: [String: String], token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        return try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(path), fields: fields, token: token)
    }
    private func bodyless(_ path: String, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        return try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(path), fields: [:], token: token, includesBody: false)
    }
    private func jsonEmpty(_ path: String, token: String) throws -> URLRequest {
        var request = try bodyless(path, token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        return request
    }
    private func execute<Value: Decodable>(_ request: URLRequest) async throws -> Value {
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        if !(200..<300).contains(status) {
            let failure = try? JSONDecoder().decode(FailureEnvelope.self, from: data)
            throw ProfileReadFailure(httpStatus: status, code: failure?.code, message: failure?.msg)
        }
        do { return try JSONDecoder().decode(Envelope<Value>.self, from: data).data }
        catch let error as ProfileReadFailure { throw error }
        catch { throw APIError.malformedResponse }
    }
    private struct FailureEnvelope: Decodable {
        let code: Int?
        let msg: String?
        private enum CodingKeys: String, CodingKey { case code, msg }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = (try? c.decode(Int.self, forKey: .code))
                ?? (try? c.decode(String.self, forKey: .code)).flatMap(Int.init)
            msg = try? c.decode(String.self, forKey: .msg)
        }
    }
    private struct Envelope<Value: Decodable>: Decodable {
        let data: Value
        private enum CodingKeys: String, CodingKey { case code, data, msg }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let code = try? c.decode(Int.self, forKey: .code)
            guard code == 200 else {
                let text = try? c.decode(String.self, forKey: .code)
                throw ProfileReadFailure(code: code ?? text.flatMap(Int.init), message: try? c.decode(String.self, forKey: .msg))
            }
            // An absent/null data object is malformed, not a fabricated empty collection.
            data = try c.decode(Value.self, forKey: .data)
        }
    }
    private struct OrderRows: Decodable {
        let rows: [ProfileOrder]
        let total: Int?
        let isTable: Bool
        private enum CodingKeys: String, CodingKey { case rows, total }
        init(from decoder: Decoder) throws {
            if let array = try? decoder.singleValueContainer().decode([ProfileOrder].self) { rows = array; total = nil; isTable = false }
            else {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                rows = try c.decode([ProfileOrder].self, forKey: .rows)
                total = try c.decodeIfPresent(Int.self, forKey: .total); isTable = true
            }
        }
    }
    private struct ParticipantRows: Decodable { let rows: [ProfileParticipant] }
    private struct IdentityWall: Decodable { let identity: [ProfileIdentityBadge] }
    private struct MedalWall: Decodable { let medals: [ProfileMedal] }
}
