import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Device-token upload the app can build without an APNs auth key.
///
/// `POST api/device/push-token` is not on `ChinaReviewedRouteCapability` and no player-write grant covers it, so
/// `compositionAdmitsUpload()` is false. `deliverableRequest` therefore returns nil. The settings client must not call
/// `registerForRemoteNotifications` while that stays false: a token would have nowhere to go.
public enum DevicePushTokenUpload {
    public static let path = "api/device/push-token"
    public static let sandbox = "SANDBOX"
    public static let production = "PRODUCTION"

    /// The China composition admits this POST only when the reviewed catalog lists it. It does not.
    public static func compositionAdmitsUpload() -> Bool {
        ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path)
    }

    /// The HTTP shape. This does not send. A missing or invalid session token yields nil.
    public static func urlRequest(for body: DevicePushTokenUploadRequest, configuration: APIConfiguration, sessionToken: String?) -> URLRequest? {
        guard let sessionToken, AuthRequestBuilder.isValidToken(sessionToken),
              let data = try? encoder.encode(body) else { return nil }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionToken, forHTTPHeaderField: "Authorization")
        request.httpBody = data
        return request
    }

    /// Nil while the composition refuses the upload, and nil for a body that is not a device token.
    public static func deliverableRequest(for body: DevicePushTokenUploadRequest, configuration: APIConfiguration, sessionToken: String?) -> URLRequest? {
        guard compositionAdmitsUpload() else { return nil }
        return urlRequest(for: body, configuration: configuration, sessionToken: sessionToken)
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

/// `POST api/device/push-token` body. `token` is lowercase hex of the APNs device-token bytes (32 bytes).
/// Fixture tokens (`fixture-`) are not device tokens. `environment` is `SANDBOX` or `PRODUCTION`, matching the
/// entitlement the build is signed with, not the fixture label `PRODUCTION_LABEL`.
public struct DevicePushTokenUploadRequest: Codable, Equatable, Sendable {
    public let bundleId: String
    public let environment: String
    public let token: String

    public init?(token: Data, environment: String, bundleId: String) {
        let hex = Self.hex(token)
        guard Self.isDeviceTokenHex(hex),
              environment == DevicePushTokenUpload.sandbox || environment == DevicePushTokenUpload.production,
              Self.isBundleId(bundleId) else { return nil }
        self.token = hex
        self.environment = environment
        self.bundleId = bundleId
    }

    public static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Exactly 32 bytes, written as 64 lowercase hex digits.
    public static func isDeviceTokenHex(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }

    public static func isBundleId(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 256 && value.allSatisfy { $0.isASCII && !$0.isWhitespace }
    }
}
