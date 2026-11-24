import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/gerenziliao/gerenziliao`, `pages/addressinfo/addressinfo`, `pages/crop/index`,
/// `pages/shezhi/shezhi`, `pages/publish/activity/index`, `pages/publish/template-intro/index`
/// (`AP-G03`–`AP-G08`, `AP-G12`, `AP-G13`).
public enum CropGapShape: String, Equatable, Sendable {
    case rect
    case circle
}

public enum SettingsSceneTarget: Equatable, Sendable {
    case privacy
    case marketing
    case about
    case complaint
    case unknown(String)

    public init(scene: String) {
        switch scene.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "privacy": self = .privacy
        case "marketing": self = .marketing
        case "about": self = .about
        case "complaint": self = .complaint
        default: self = .unknown(scene)
        }
    }
}

public enum AccountPublishRemainingCopy {
    public static let bindPhoneTitle = "绑定手机号"
    public static let rebindPhoneTitle = "更换手机号"
    public static let cropReset = "还原"
    public static let settingsComplaint = "投诉建议"
    public static let settingsUnknownScene = "场景无法打开"
    public static let activitySoldLockNote = "已售出，时间和地点不可改"
    public static let organizerInfoTitle = "发起人信息"
    public static let organizerLoadFailed = "发起人信息未加载"
    public static let retryLoad = "重新加载"
}

public struct AccountPublishRemainingClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func bindPhone(code: String, token: String) async throws -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.invalidRequest }
        struct PhonePayload: Decodable { let phone: String }
        let payload: PhonePayload = try await MPGapHTTP.postJSON(
            configuration: configuration,
            transport: transport,
            path: "api/getwxbindphone",
            body: ["code": trimmed],
            token: token
        )
        return payload.phone
    }
}
