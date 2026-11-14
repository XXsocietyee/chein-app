import Foundation

/// Actions dispatched through `/api/official/command` by the `event-attendance` component.
public enum OfficialAttendanceAction: String, CaseIterable, Equatable {
    case attendanceConfig = "attendance-config"
    case attendanceClaim = "attendance-claim"
    case attendanceRotate = "attendance-rotate"
    case attendanceVerify = "attendance-verify"
}

public struct OfficialAttendanceSnapshot: Equatable {
    public let dutyState: String
    public let configVersion: Int?
    public let meetingName: String
    public let meetingAddress: String
    public let latitude: Double?
    public let longitude: Double?
    public let phone: String
    public let backupPhone: String
    public let credential: String
    public let checkedAtText: String
    public let activeParticipation: Bool

    public init(dutyState: String = "", configVersion: Int? = nil, meetingName: String = "",
                meetingAddress: String = "", latitude: Double? = nil, longitude: Double? = nil,
                phone: String = "", backupPhone: String = "", credential: String = "",
                checkedAtText: String = "", activeParticipation: Bool = false) {
        self.dutyState = dutyState; self.configVersion = configVersion; self.meetingName = meetingName
        self.meetingAddress = meetingAddress; self.latitude = latitude; self.longitude = longitude
        self.phone = phone; self.backupPhone = backupPhone; self.credential = credential
        self.checkedAtText = checkedAtText; self.activeParticipation = activeParticipation
    }

    public init(raw: [String: Any]) {
        let cfg = (raw["config"] as? [String: Any]) ?? [:]
        let mine = (raw["mine"] as? [String: Any]) ?? [:]
        func str(_ d: [String: Any], _ k: String) -> String { (d[k] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        func dbl(_ d: [String: Any], _ k: String) -> Double? {
            if let n = d[k] as? NSNumber { return n.doubleValue }
            if let s = d[k] as? String { return Double(s) }
            return nil
        }
        dutyState = str(raw, "dutyState")
        configVersion = (raw["configVersion"] as? NSNumber)?.intValue
        meetingName = str(cfg, "meetingName")
        meetingAddress = str(cfg, "meetingAddress")
        latitude = dbl(cfg, "latitude")
        longitude = dbl(cfg, "longitude")
        phone = str(cfg, "phone")
        backupPhone = str(cfg, "backupPhone")
        credential = str(mine, "credential")
        checkedAtText = str(mine, "checkedAt")
        activeParticipation = (raw["activeParticipation"] as? Bool) ?? false
    }
}

public struct OfficialPlayContact: Equatable {
    public let name: String
    public let phone: String
    public init(name: String, phone: String) { self.name = name; self.phone = phone }
}

@MainActor
public final class OfficialAttendanceService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func fetchAttendance(eventID: Int, organizer: Bool, token: String?) async throws -> OfficialAttendanceSnapshot {
        guard eventID > 0 else { throw OfficialOrganizerFailure.invalid }
        guard let token, AuthRequestBuilder.isValidToken(token) else { throw OfficialOrganizerFailure.unauthorized }
        let suffix = organizer ? "manage" : ""
        let path = suffix.isEmpty ? "api/official/events/\(eventID)/attendance" : "api/official/events/\(eventID)/attendance/manage"
        var req = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        req.httpMethod = "GET"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(token, forHTTPHeaderField: "Authorization")
        let (data, status) = try await transport.send(req)
        if status == 401 || status == 403 { throw OfficialOrganizerFailure.unauthorized }
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = (root["code"] as? NSNumber)?.intValue, code == 200,
              let payload = root["data"] as? [String: Any] else { throw OfficialOrganizerFailure.network }
        return OfficialAttendanceSnapshot(raw: payload)
    }

    public func fetchContact(activityID: Int, token: String?) async -> OfficialPlayContact? {
        guard activityID > 0, let token, AuthRequestBuilder.isValidToken(token),
              var components = URLComponents(url: configuration.baseURL.appendingPathComponent("api/play/contact"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "activityId", value: String(activityID))]
        guard let url = components.url else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(token, forHTTPHeaderField: "Authorization")
        guard let (data, status) = try? await transport.send(req), (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["code"] as? NSNumber)?.intValue == 200,
              let payload = root["data"] as? [String: Any] else { return nil }
        let phone = (payload["phone"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = (payload["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phone.isEmpty else { return nil }
        return OfficialPlayContact(name: name, phone: phone)
    }

    public func sendCommand(eventID: Int, action: OfficialAttendanceAction, fields: [String: String] = [:],
                            token: String?, requestId: String = OfficialOrganizerCommand.newRequestID()) async throws -> OfficialOrganizerReceipt? {
        guard eventID > 0 else { throw OfficialOrganizerFailure.invalid }
        guard let token, AuthRequestBuilder.isValidToken(token) else { throw OfficialOrganizerFailure.unauthorized }
        if action == .attendanceVerify {
            let code = (fields["credentialCode"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard code.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw OfficialOrganizerFailure.invalid }
        }
        var body = fields
        body["targetId"] = String(eventID)
        body["action"] = action.rawValue
        body["requestId"] = requestId
        var req = URLRequest(url: configuration.baseURL.appendingPathComponent("api/official/command"))
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(token, forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (data, status) = try await transport.send(req)
        if status == 401 || status == 403 { throw OfficialOrganizerFailure.unauthorized }
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["code"] as? NSNumber)?.intValue == 200,
              let receipt = (root["data"] as? [String: Any])?["receipt"] as? [String: Any],
              let rid = receipt["requestId"] as? String, !rid.isEmpty,
              let stateRaw = receipt["state"] as? String,
              let state = OfficialOrganizerReceipt.State(rawValue: stateRaw) else { return nil }
        return OfficialOrganizerReceipt(requestId: rid, state: state, message: (receipt["message"] as? String) ?? "")
    }
}
