import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Classify-only gate for `POST api/merchant/desk/redeem/resolve`. Default off. This call does not redeem.
public struct MerchantDeskManualCodeGate: Equatable {
    public var enabled: Bool
    public static let off = Self(enabled: false)
    /// Production hosts pass this so 手输码 can resolve `api/merchant/desk/redeem/resolve`. It does not redeem.
    public static let live = Self(enabled: true)
    public init(enabled: Bool = false) { self.enabled = enabled }
}

public struct MerchantDeskManualCodeChoice: Equatable {
    public let name: String
    public let title: String
    public let options: [Option]
    public struct Option: Equatable { public let value: String; public let label: String }
}

public enum MerchantDeskManualRoute: Equatable {
    case route(endpoint: String, code: String, fields: [String: String], loadingTitle: String, choice: MerchantDeskManualCodeChoice?)
    case redirect(message: String, path: String)
    case rejected(message: String)
}

public enum MerchantDeskManualCode {
    public static let path = "api/merchant/desk/redeem/resolve"
    public static let maxLength = 512
    public static let submitTitles = [
        "/api/verify/groupcode/redeem": "核销中...",
        "/api/registration/scan_dynamic_code": "验票中...",
        "/api/registration/scan_qr_code": "验票中...",
        "/api/coupon/verification": "核销中...",
    ]
    public static func validationError(_ raw: String) -> String? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.isEmpty { return "请输入核销码" }
        if code.utf16.count > maxLength { return "核销码过长" }
        return nil
    }
    public static func body(code: String) -> [String: String] { ["code": code, "mode": "MANUAL"] }

    public static func route(envelope: [String: Any]) -> MerchantDeskManualRoute {
        func rejected(_ message: String?) -> MerchantDeskManualRoute {
            let text = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let chinese = text.unicodeScalars.contains { (0x4E00...0x9FA5).contains($0.value) }
            return .rejected(message: chinese ? text : "未能识别核销码，请重试")
        }
        let code = envelope["code"]
        let ok = (code as? Int) == 200 || (code as? String) == "200" || (code as? NSNumber)?.intValue == 200
        guard ok, let data = envelope["data"] as? [String: Any] else {
            return rejected(envelope["msg"] as? String)
        }
        if (data["accepted"] as? Bool) != true {
            let message = ((data["message"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let path = ((data["redirectPath"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if path.hasPrefix("/pages/merchant/") {
                return .redirect(message: message.isEmpty ? "这不是城瘾的核销码" : message, path: path)
            }
            return .rejected(message: message.isEmpty ? "这不是城瘾的核销码" : message)
        }
        let form = data["form"] as? [String: Any] ?? [:]
        let endpoint = ((form["submitEndpoint"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title = submitTitles[endpoint], let fields = form["fields"] as? [Any] else {
            return .rejected(message: "未能识别核销码，请重试")
        }
        var hidden: [String: String] = [:]
        var choice: MerchantDeskManualCodeChoice?
        for item in fields {
            guard let field = item as? [String: Any] else { return .rejected(message: "未能识别核销码，请重试") }
            let name = ((field["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return .rejected(message: "未能识别核销码，请重试") }
            if field["widget"] as? String == "hidden", let value = field["value"] as? String, !value.isEmpty {
                hidden[name] = value
                continue
            }
            let rawOptions = field["widget"] as? String == "select" ? (field["options"] as? [Any] ?? []) : []
            let options: [MerchantDeskManualCodeChoice.Option] = rawOptions.compactMap { item in
                guard let row = item as? [String: Any],
                      let value = (row["value"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
                      let label = (row["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return nil }
                return .init(value: value, label: label)
            }
            guard !options.isEmpty, options.count == rawOptions.count, choice == nil else {
                return .rejected(message: "未能识别核销码，请重试")
            }
            let label = ((field["label"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            choice = .init(name: name, title: label.isEmpty ? "请选择" : label, options: options)
        }
        guard let code = hidden["code"], !code.isEmpty else { return .rejected(message: "未能识别核销码，请重试") }
        return .route(endpoint: endpoint, code: code, fields: hidden, loadingTitle: title, choice: choice)
    }
}

public struct MerchantDeskManualCodeClient {
    public let gate: MerchantDeskManualCodeGate
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport, gate: MerchantDeskManualCodeGate = .off) {
        self.configuration = configuration
        self.transport = transport
        self.gate = gate
    }
    public func resolve(code raw: String, token: String) async throws -> MerchantDeskManualRoute {
        guard gate.enabled else { throw MerchantBusinessFailure.disabled }
        guard MerchantDeskManualCode.validationError(raw) == nil else { throw MerchantBusinessFailure.invalid }
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(MerchantDeskManualCode.path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: MerchantDeskManualCode.body(code: code), options: [.sortedKeys])
        let (data, status) = try await transport.send(request)
        guard (200..<300).contains(status),
              let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw MerchantBusinessFailure.malformed }
        return MerchantDeskManualCode.route(envelope: envelope)
    }
}
