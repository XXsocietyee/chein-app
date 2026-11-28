import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Source-backed JSON adapter for `/api/team/{create,join,quit,kick,disband,join-mode}` (P0-8: live in `makeTeamCoordinator`
/// when the reviewed membership write lease is issued). Join-mode uses the verified mini/backend setter.
/// No remote operation receipt or automatic retry is invented.
/// The caller must persist the exact local operation identity before invoking submit.
@MainActor public final class TeamHTTPService: TeamServing {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let reader: TeamReadOnlyService
    private let approval: OperationEndpointApproval?
    private let journal: any TeamPendingJournal
    private let currentSession: () -> TeamSession?
    /// Gap #6: join / quit / kick / disband / join-mode go through `POST /api/team/command` (the route the Release
    /// player lease admits, MP `utils/team-event-command.js`). Create keeps `api/team/create`.
    private let commandWriter: TeamCommandWriter?
    public var authority: TeamServiceAuthority { approval == nil && commandWriter == nil ? .readOnly : .approved }
    public init(configuration: APIConfiguration, transport: any HTTPTransport, approval: OperationEndpointApproval? = nil,
                journal: any TeamPendingJournal, currentSession: @escaping () -> TeamSession?,
                creationLoader: ((Int, TeamSession) async throws -> TeamCreationContext)? = nil,
                readApproval: OperationEndpointApproval? = nil, requiresIDMembership: Bool = false,
                commandWriter: TeamCommandWriter? = nil) {
        self.configuration = configuration; self.transport = transport; self.approval = approval
        self.journal = journal; self.currentSession = currentSession; self.commandWriter = commandWriter
        // P0-8: the production reader keeps its own read lease and the fresh-membership rule on ID reads.
        reader = TeamReadOnlyService(configuration: configuration, transport: transport, readApproval: readApproval,
                                     currentSession: currentSession, requiresIDMembership: requiresIDMembership,
                                     creationLoader: creationLoader)
    }
    private func check(_ session: TeamSession) throws {
        try Task.checkCancellation()
        guard currentSession() == session else { throw TeamFailure.stale }
    }
    public func myTeams(session: TeamSession) async throws -> [OwnedTeam] { try await reader.myTeams(session: session) }
    public func detail(_ lookup: TeamLookup, session: TeamSession) async throws -> TeamDetail { try await reader.detail(lookup, session: session) }
    public func creationContext(ownerID: Int, session: TeamSession) async throws -> TeamCreationContext { try await reader.creationContext(ownerID: ownerID, session: session) }
    public func receipt(operationID: UUID, session: TeamSession) async throws -> TeamWriteOutcome? { nil }
    public func submit(_ action: TeamAction, operationID: UUID, session: TeamSession) async -> TeamWriteOutcome {
        var request: URLRequest?
        let command = commandWriter.flatMap { writer in Self.commandFields(action).map { (writer, $0) } }
        do {
            let contract = try TeamWriteContract(action)
            let path = command == nil ? String(contract.path.dropFirst()) : AccountPublishMPContract.teamCommandPath
            let lease = command?.0.approval ?? approval
            guard let lease, lease.allows(configuration: configuration, namespace: session.storageNamespace, accountID: session.accountID, path: path) else { return .notSent }
            try check(session)
            let expected = TeamPendingRecord(operationID: operationID, ownerKey: session.ownerKey, targetKey: action.targetKey, joinMode: action.requestedJoinMode)
            guard let persisted = try journal.pending(ownerKey: session.ownerKey, targetKey: action.targetKey), persisted.operationID == expected.operationID else { return .notSent }
            if persisted.dispatchStarted == true { return .unknown }
            guard persisted == expected else { return .notSent }
            if case .create(let context, _, _) = action {
                let fresh = try await creationContext(ownerID: context.ownerID, session: session)
                guard fresh == context, fresh.eligible else { return .notSent }
            } else if let lookup = action.lookup {
                let fresh = try await detail(lookup, session: session)
                guard action.isAllowed(detail: fresh) else { return .notSent }
            } else { return .notSent }
            try check(session)
            if command == nil {
                let body: [String: Any] = contract.fields.mapValues { value in
                    switch value { case .integer(let number): return number as Any; case .text(let text): return text as Any }
                }
                request = try OperationAdapterHTTP.json(configuration: configuration, path: path, body: JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]), token: session.token)
            }
            try check(session)
            guard try journal.pending(ownerKey: session.ownerKey, targetKey: action.targetKey) == expected else { return .unknown }
            var dispatched = expected; dispatched.dispatchStarted = true
            try journal.write(dispatched)
        } catch { return .notSent }
        if let command {
            // The journal's operation id is the command `requestId`, so a later query / retry addresses this request.
            let writer = command.0, fields = command.1
            let receipt = await writer.submitReceipt(key: action.targetKey, path: AccountPublishMPContract.teamCommandPath,
                                                     fields: fields, requestID: TeamCommandWriter.requestID(for: operationID),
                                                     token: session.token)
            do { try check(session) } catch { return .unknown }
            return Self.decodeCommand(receipt, action: action, operationID: operationID)
        }
        guard let request else { return .notSent }
        do {
            let (data, status) = try await transport.send(request)
            try check(session)
            return Self.decodeAcknowledgment(data, status: status, action: action, operationID: operationID)
        } catch { return .unknown }
    }

    /// MP command fields (`pages/team/detail` `_recovery.start(action, payload)`, `pages/team/join`): ids as strings,
    /// `joinMode` 1 | 2. Create has no command form.
    static func commandFields(_ action: TeamAction) -> [String: String]? {
        switch action {
        case .create: return nil
        case .join(let id, let code):
            guard id > 0, TeamLookup.validInvite(code) else { return nil }
            return ["action": "join", "targetId": String(id), "inviteCode": code.trimmingCharacters(in: .whitespacesAndNewlines)]
        case .leave(let id): return id > 0 ? ["action": "quit", "targetId": String(id)] : nil
        case .remove(let id, let member):
            guard id > 0, member > 0 else { return nil }
            return ["action": "kick", "targetId": String(id), "memberId": String(member)]
        case .disband(let id): return id > 0 ? ["action": "disband", "targetId": String(id)] : nil
        case .changeJoinMode(let id, let mode):
            guard id > 0, mode == .invitation || mode == .publicApplication else { return nil }
            return ["action": "join-mode", "targetId": String(id), "joinMode": String(mode.rawValue)]
        }
    }

    /// Gap #7: only `data.state == APPLIED` is success; the page then re-reads `/api/team/info`. REJECTED keeps the
    /// server message (and its `errorCode`); CANCELLED never ran; UNKNOWN stays pending for the recovery card.
    static func decodeCommand(_ receipt: TeamCommandReceipt, action: TeamAction, operationID: UUID) -> TeamWriteOutcome {
        switch receipt.terminal {
        case .applied:
            guard let teamID = action.teamID, teamID > 0 else { return .unknown }
            if case .changeJoinMode(_, let mode) = action {
                return .joinModeAcknowledged(operationID: operationID, teamID: teamID, mode: mode)
            }
            return .acknowledged(operationID: operationID, teamID: teamID)
        case .rejected:
            let message = receipt.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { return .rejectedMessage(errorCode: receipt.errorCode, message: message) }
            if TeamSeatPresentation.isMachineCode(receipt.errorCode) { return .rejectedCode(receipt.errorCode) }
            return .rejected
        case .cancelled: return .notSent
        case .unknown: return .unknown
        }
    }
    static func decodeAcknowledgment(_ data: Data, status: Int, action: TeamAction, operationID: UUID) -> TeamWriteOutcome {
        let envelope = try? OperationAdapterHTTP.envelope(data)
        if status == 401 || status == 403 { return .rejected }
        guard (200..<300).contains(status), let code = envelope?["code"]?.integer else { return .unknown }
        guard code == 200 else {
            if let errorCode = envelope?["errorCode"]?.text, TeamSeatPresentation.isMachineCode(errorCode) { return .rejectedCode(errorCode) }
            return .rejected
        }
        if case .changeJoinMode(let teamID, let requested) = action {
            guard teamID > 0, requested != .unknown,
                  let raw = envelope?["data"]?.object?["joinMode"]?.integer,
                  let returned = TeamJoinMode(rawValue: raw), returned != .unknown,
                  returned == requested else { return .unknown }
            return .joinModeAcknowledged(operationID: operationID, teamID: teamID, mode: returned)
        }
        let teamID: Int
        if case .create = action {
            guard let id = OperationAdapterHTTP.positiveID(envelope?["data"]?.object?["teamId"]) else { return .unknown }
            teamID = id
        } else {
            guard let id = action.teamID, id > 0 else { return .unknown }; teamID = id
        }
        // This confirms only acknowledgment of the request, never a synthesized roster/status.
        return .acknowledged(operationID: operationID, teamID: teamID)
    }
}

/// `POST /api/team/command` plus query and cancel. The 32-hex request id is kept until
/// a 2xx or 4xx answer. Transport failure, 5xx, and a malformed body stay on that id.
public enum TeamCommandTerminal: Equatable {
    case applied(Int)
    case rejected(Int)
    case cancelled(Int)
    case unknown
}

/// pages/team/detail recovery card shown while the saved command state is UNKNOWN.
public enum TeamCommandRecoveryCopy {
    public static let query = "查询原请求"
    public static let retry = "按原输入重试"
    public static let abort = "终止尚未执行的请求"
    public static let abortNote = "终止只针对未执行的原请求；已经提交的业务不会撤销。"
}

/// A decoded `/api/team/command` answer. `message` is the server's player-facing text (MP shows it next to the button).
public struct TeamCommandReceipt: Equatable {
    public let terminal: TeamCommandTerminal
    public let errorCode: String
    public let message: String
    public init(terminal: TeamCommandTerminal, errorCode: String, message: String) {
        self.terminal = terminal; self.errorCode = errorCode; self.message = message
    }
    public static let unknown = TeamCommandReceipt(terminal: .unknown, errorCode: "", message: "")

    /// A 2xx body. `code != 200` is a validation rejection (`ServiceException`, e.g. 原请求号与输入不一致) and is terminal.
    static func decode(_ data: Data, status: Int) -> TeamCommandReceipt {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .unknown }
        let code = (root["code"] as? Int) ?? Int(root["code"] as? String ?? "")
        guard let code else { return .unknown }
        if code == 401 { return .unknown }
        guard code == 200 else {
            return TeamCommandReceipt(terminal: .rejected(status), errorCode: root["errorCode"] as? String ?? "",
                                      message: root["msg"] as? String ?? "")
        }
        guard let receipt = AccountPublishMPContract.teamHandleReceipt(from: data) else { return .unknown }
        switch receipt.state {
        case "APPLIED": return TeamCommandReceipt(terminal: .applied(status), errorCode: "", message: "")
        case "REJECTED": return TeamCommandReceipt(terminal: .rejected(status), errorCode: receipt.errorCode, message: receipt.message)
        case "CANCELLED": return TeamCommandReceipt(terminal: .cancelled(status), errorCode: "", message: receipt.message)
        default: return .unknown
        }
    }
}

@MainActor public final class TeamCommandWriter {
    public static let paths: Set<String> = ["api/team/command", "api/team/command/query", "api/team/command/cancel"]
    public let approval: OperationEndpointApproval
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let token: () -> String?
    private var savedRequestIDs: [String: String] = [:]

    public init(approval: OperationEndpointApproval, configuration: APIConfiguration, transport: any HTTPTransport,
                token: @escaping () -> String? = { nil }) throws {
        guard approval.baseURL == configuration.baseURL, Self.paths.isSubset(of: approval.paths) else {
            throw APIError.invalidConfiguration
        }
        self.approval = approval
        self.configuration = configuration
        self.transport = transport
        self.token = token
    }

    /// Gap #6: the composition transport admits a team command only with the signed-in viewer's own Authorization
    /// header, so the Release writer carries the captured session token.
    public convenience init(approval: OperationEndpointApproval, configuration: APIConfiguration, transport: any HTTPTransport,
                            context: RuntimeDependencyContext) throws {
        let token = context.session.token
        try self.init(approval: approval, configuration: configuration, transport: transport, token: { token })
    }

    public func savedRequestID(for key: String) -> String? { savedRequestIDs[key] }

    /// The recovery card adopts the pending journal's request id, so query / retry / cancel address the request that
    /// `TeamHTTPService` already sent. An id already saved under `key` is kept.
    public func adopt(key: String, requestID: String) {
        guard !key.isEmpty, savedRequestIDs[key] == nil, Self.validRequestID(requestID) else { return }
        savedRequestIDs[key] = requestID
    }

    public func submit(key: String, path: String, fields: [String: String]) async -> TeamCommandTerminal {
        await submitReceipt(key: key, path: path, fields: fields).terminal
    }

    /// Gap #7 (T-03+): `/api/team/command` answers HTTP 200 `code:200` with `data.state` APPLIED / REJECTED / CANCELLED /
    /// UNKNOWN (TeamEventCommandService.execute). Only APPLIED is success. REJECTED carries the server `message` and
    /// `errorCode`. UNKNOWN, a missing receipt, transport failure and 5xx keep the saved id for query / retry / cancel.
    /// `requestID` seeds the id for a new key (the team journal's operation id), so a restart queries the same request.
    public func submitReceipt(key: String, path: String, fields: [String: String], requestID seed: String? = nil,
                              token explicit: String? = nil) async -> TeamCommandReceipt {
        guard Self.paths.contains(path), !key.isEmpty else { return .unknown }
        let requestID = savedRequestIDs[key] ?? seed.flatMap { Self.validRequestID($0) ? $0 : nil } ?? Self.hexIdentifier()
        savedRequestIDs[key] = requestID
        guard let encoded = Self.commandBody(path: path, fields: fields, requestID: requestID) else { return .unknown }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(AccountPublishMPContract.jsonContentType, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let credential = explicit ?? token(), AuthRequestBuilder.isValidToken(credential) {
            request.setValue(credential, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encoded
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) }
        catch { return .unknown }
        if (400..<500).contains(status) {
            savedRequestIDs[key] = nil
            return TeamCommandReceipt(terminal: .rejected(status), errorCode: "", message: "")
        }
        guard (200..<300).contains(status) else { return .unknown }
        let receipt = TeamCommandReceipt.decode(data, status: status)
        switch receipt.terminal {
        case .applied, .rejected, .cancelled: savedRequestIDs[key] = nil
        case .unknown: break
        }
        return receipt
    }

    static func validRequestID(_ value: String) -> Bool {
        value.count == 32 && value.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }

    /// The journal's operation UUID as the 32-hex command id the backend accepts.
    public static func requestID(for operationID: UUID) -> String {
        operationID.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Mini-program command order for join, quit, kick, disband, and join-mode: payload fields, then
    /// `targetId`, `action`, `requestId`. Query and cancel stay on sorted keys.
    private static func commandBody(path: String, fields: [String: String], requestID: String) -> Data? {
        guard path == AccountPublishMPContract.teamCommandPath,
              let action = fields["action"],
              ["join", "quit", "kick", "disband", "join-mode"].contains(action) else {
            var body = fields
            body["requestId"] = requestID
            return try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        var parts: [String] = []
        switch action {
        case "join":
            if let code = fields["inviteCode"] { parts.append("\"inviteCode\":\(jsonText(code))") }
        case "kick":
            if let member = fields["memberId"] { parts.append("\"memberId\":\(jsonText(member))") }
        case "join-mode":
            if let mode = fields["joinMode"] {
                if let number = Int(mode), String(number) == mode {
                    parts.append("\"joinMode\":\(number)")
                } else {
                    parts.append("\"joinMode\":\(jsonText(mode))")
                }
            }
        default:
            break
        }
        if let target = fields["targetId"] { parts.append("\"targetId\":\(jsonText(target))") }
        parts.append("\"action\":\(jsonText(action))")
        parts.append("\"requestId\":\(jsonText(requestID))")
        return Data(("{" + parts.joined(separator: ",") + "}").utf8)
    }

    private static func jsonText(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            default: out.append(Character(scalar))
            }
        }
        out += "\""
        return out
    }

    /// `POST /api/team/command/query` with only the saved `{requestId}`. Does not mint an id.
    public func query(key: String) async -> TeamCommandTerminal {
        await settle(key: key, path: "api/team/command/query", fields: [:], requestIDOnly: true)
    }

    /// `POST /api/team/command/cancel` with the saved command plus `requestId`. Does not mint an id.
    public func cancel(key: String, fields: [String: String]) async -> TeamCommandTerminal {
        await settle(key: key, path: "api/team/command/cancel", fields: fields, requestIDOnly: false)
    }

    /// Clears the saved id only when `data.state` is APPLIED, REJECTED, or CANCELLED.
    private func settle(key: String, path: String, fields: [String: String], requestIDOnly: Bool) async -> TeamCommandTerminal {
        guard let requestID = savedRequestIDs[key], !key.isEmpty else { return .unknown }
        var body: [String: String] = requestIDOnly ? [:] : fields
        body["requestId"] = requestID
        guard let encoded = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else { return .unknown }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let credential = token(), AuthRequestBuilder.isValidToken(credential) {
            request.setValue(credential, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encoded
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) } catch { return .unknown }
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .unknown }
        let code = (root["code"] as? Int) ?? Int(root["code"] as? String ?? "")
        guard code == 200, let payload = root["data"] as? [String: Any], let state = payload["state"] as? String else { return .unknown }
        switch state {
        case "APPLIED":
            savedRequestIDs[key] = nil
            return .applied(status)
        case "REJECTED":
            savedRequestIDs[key] = nil
            return .rejected(status)
        case "CANCELLED":
            savedRequestIDs[key] = nil
            return .cancelled(status)
        default:
            return .unknown
        }
    }

    private static func hexIdentifier() -> String { requestID(for: UUID()) }
}
