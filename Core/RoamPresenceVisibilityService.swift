import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Result of calling `POST /api/roam/presence-visibility` to turn off nearby presence sharing.
public enum RoamPresenceDisableOutcome: Equatable {
    /// Server confirmed `data == false`.
    case disabled
    /// Server returned an explicit non-200 business code or message.
    case rejected(String?)
    /// Local session/configuration could not issue the request.
    case unavailable
    /// Network transport or response decoding failed.
    case failed
}

/// Reviewed non-money service for disabling approximate nearby roam presence visibility.
public struct RoamPresenceVisibilityService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// `GET /api/roam/presence-visibility?sessionId=`. Nil data stays unknown. This does not turn sharing on.
    public func readPresence(token: String?, sessionID: Int) async -> Bool? {
        guard let token, AuthRequestBuilder.isValidToken(token), sessionID > 0 else { return nil }
        let baseRequest: URLRequest
        do {
            baseRequest = try RoamPresenceVisibilityContract.readRequest(baseURL: configuration.baseURL, sessionID: sessionID)
        } catch { return nil }
        var request = baseRequest
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        do {
            let (data, status) = try await transport.send(request)
            guard (200..<300).contains(status) else { return nil }
            return RoamPresenceVisibilityContract.decode(data)
        } catch { return nil }
    }

    /// ROAM-r11-5: mid-session 附近的人位置分享 (MP utils/roam-presence-privacy.js:24-31 `setSharing`). Turning on needs a
    /// live session id and the explicit consent; the change echo must equal the requested value or the result is nil.
    public func setPresence(token: String?, sessionID: Int?, visible: Bool, consentAccepted: Bool) async -> Bool? {
        guard let token, AuthRequestBuilder.isValidToken(token) else { return nil }
        guard var request = try? RoamPresenceVisibilityContract.changeRequest(baseURL: configuration.baseURL, sessionID: sessionID,
                                                                              visible: visible, consentAccepted: consentAccepted) else { return nil }
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        do {
            let (data, status) = try await transport.send(request)
            guard (200..<300).contains(status), let echo = RoamPresenceVisibilityContract.decode(data), echo == visible else { return nil }
            return echo
        } catch { return nil }
    }

    /// Sends `POST /api/roam/presence-visibility` with `visible=false` and validates `data == false`.
    public func disablePresence(token: String?) async -> RoamPresenceDisableOutcome {
        guard let token, AuthRequestBuilder.isValidToken(token) else { return .unavailable }
        let baseRequest: URLRequest
        do {
            baseRequest = try RoamPresenceVisibilityContract.changeRequest(
                baseURL: configuration.baseURL,
                sessionID: nil,
                visible: false,
                consentAccepted: false
            )
        } catch {
            return .unavailable
        }
        var request = baseRequest
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        do {
            let (data, status) = try await transport.send(request)
            if (200..<300).contains(status), RoamPresenceVisibilityContract.decode(data) == false {
                return .disabled
            }
            if let envelope = try? JSONDecoder().decode(ServerStatusMessage.self, from: data) {
                if let code = envelope.code, code != 200 {
                    return .rejected(envelope.msg)
                }
                if status >= 400 {
                    return .rejected(envelope.msg)
                }
            }
            return .failed
        } catch {
            return .failed
        }
    }
}

/// Evaluates consent-revocation state transitions to surface accurate user toast feedback.
public enum RoamConsentWithdrawalFeedback: Equatable {
    case idle
    case withdrawn
    case partialLocalPending
    case failed

    /// Returns feedback whenever an explicit revoke attempt completes or settles partway.
    public static func evaluate(previous: ComplianceRoamCleanup, current: ComplianceRoamCleanup, error: String?) -> Self {
        if current == .complete && previous != .complete {
            return .withdrawn
        }
        if error != nil {
            if current == .serverConfirmed || current == .trackingStopped {
                return .partialLocalPending
            }
            return .failed
        }
        return .idle
    }
}

private struct ServerStatusMessage: Decodable {
    let code: Int?
    let msg: String?
}
