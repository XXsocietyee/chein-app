import Foundation

// MARK: - POI challenge submit (injected writer, gated by default)
// Request shape matches pages/play/poi-challenge/index.js `_submit`:
// POST /api/city/nodes/{id}/complete  { lat, lng, answer, photoUrl, code }.
// Success needs `data.needRedeem` (Bool) in the response, exactly like the mini; anything else is
// "not confirmed" and keeps the duplicate-submit lock. The default writer sends nothing.

public struct ChallengePOICompleteRequest: Equatable {
    public let path: String
    public let body: [String: PlayWireValue]

    public init(path: String, body: [String: PlayWireValue]) {
        self.path = path
        self.body = body
    }
}

public enum ChallengePOIWriteOutcome: Equatable {
    /// Server answered code 200; `data` is the response data object.
    case success(data: PlayWireValue)
    /// Server rejected before writing (one of the mini's REJECTIONS messages).
    case rejected(message: String)
    /// Network error or ambiguous server answer.
    case unconfirmed(message: String)
    /// No write route or grant in this build.
    case unavailable
}

@MainActor public protocol ChallengePOIWriting {
    func complete(_ request: ChallengePOICompleteRequest) async -> ChallengePOIWriteOutcome
}

public struct GatedChallengePOIWriter: ChallengePOIWriting {
    public init() {}
    public func complete(_ request: ChallengePOICompleteRequest) async -> ChallengePOIWriteOutcome { .unavailable }
}

/// Live HTTP writer for `POST /api/city/nodes/{id}/complete`, ported from `pages/play/poi-challenge/index.js`.
public struct ChallengePOIHTTPWriter: ChallengePOIWriting {
    private static let prewriteRejectionMessages: Set<String> = [
        "离据点太远,请到店后再完成",
        "离据点太远，请到店后再完成",
        "答案不正确",
        "请上传拍照打卡照片",
        "照片地址不合法,请重新上传",
        "照片地址不合法，请重新上传",
        "照片未上传成功或不属于当前账号，请重新拍摄上传",
        "照片校验暂不可用，请稍后重试",
        "据点未开放或已下线",
        "节点未上线",
        "缺少定位",
    ]

    private let configuration: @Sendable () async -> APIConfiguration?
    private let transport: any HTTPTransport
    private let tokenProvider: @Sendable () async -> String?
    private let isRouteOpen: @Sendable () async -> Bool

    public init(
        configuration: @escaping @Sendable () async -> APIConfiguration?,
        transport: any HTTPTransport,
        tokenProvider: @escaping @Sendable () async -> String?,
        isRouteOpen: @escaping @Sendable () async -> Bool = { true }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.isRouteOpen = isRouteOpen
    }

    public func complete(_ request: ChallengePOICompleteRequest) async -> ChallengePOIWriteOutcome {
        guard await isRouteOpen(), let config = await configuration(), let rawToken = await tokenProvider() else {
            return .unavailable
        }
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return .unavailable }

        let relativePath = request.path.hasPrefix("/") ? String(request.path.dropFirst()) : request.path
        var fields: [String: String] = [
            "answer": request.body["answer"]?.text ?? "",
            "photoUrl": request.body["photoUrl"]?.text ?? "",
            "code": request.body["code"]?.text ?? "",
        ]
        if let lat = request.body["lat"] {
            if let value = lat.double { fields["lat"] = String(value) }
            else if let text = lat.text { fields["lat"] = text }
        }
        if let lng = request.body["lng"] {
            if let value = lng.double { fields["lng"] = String(value) }
            else if let text = lng.text { fields["lng"] = text }
        }

        let urlRequest: URLRequest
        do {
            urlRequest = try AuthRequestBuilder.makeFormRequest(
                url: config.baseURL.appendingPathComponent(relativePath),
                fields: fields,
                token: token
            )
        } catch {
            return .unavailable
        }

        do {
            let (data, httpStatus) = try await transport.send(urlRequest)
            return Self.classifyHTTPResult(statusCode: httpStatus, data: data)
        } catch {
            return .unconfirmed(message: W8Text.t("网络异常，请重试", "Network error. Please retry."))
        }
    }

    public static func classifyHTTPResult(statusCode httpStatus: Int, data: Data) -> ChallengePOIWriteOutcome {
        guard let root = try? JSONDecoder().decode(PlayWireValue.self, from: data) else {
            return .unconfirmed(message: W8Text.t("结果还没确认，请稍后重试", "Result is not confirmed yet. Please try again."))
        }
        let code = root["code"].tolerantInteger
        let msg = root["msg"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = root["data"]
        if (200...299).contains(httpStatus), code == 200, payload["needRedeem"].bool != nil {
            return .success(data: payload)
        }
        let cleanMsg = msg?.isEmpty == false ? msg! : nil
        if code.map(ChallengePOIRules.isPrewriteRejection) == true
            || (cleanMsg.map { prewriteRejectionMessages.contains($0) } == true) {
            return .rejected(message: cleanMsg ?? W8Text.t("未通过挑战，请核对后重试", "Challenge not passed. Check and try again."))
        }
        return .unconfirmed(message: cleanMsg ?? W8Text.t("结果还没确认，请稍后重试", "Result is not confirmed yet. Please try again."))
    }
}

public enum ChallengePOISubmitState: Equatable {
    case idle
    case submitting
    case done
    case invalid(String)
    case rejected(String)
    case unconfirmed(String)
    case unavailable
}

public enum ChallengePOIRequestBuilder {
    /// Maps the validated coordinator payload onto the mini-program body.
    public static func request(nodeId: Int, payload: [String: PlayWireValue]) -> ChallengePOICompleteRequest {
        var body: [String: PlayWireValue] = [
            "answer": payload["answer"] ?? .string(""),
            "photoUrl": payload["photoUrl"] ?? .string(""),
            "code": .string(""),
        ]
        if let lat = payload["latitude"] { body["lat"] = lat }
        if let lng = payload["longitude"] { body["lng"] = lng }
        return ChallengePOICompleteRequest(path: "/api/city/nodes/\(nodeId)/complete", body: body)
    }
}

@available(macOS 14.0, *)
@MainActor public final class ChallengePOISubmitModel: ObservableObject {
    @Published public private(set) var state: ChallengePOISubmitState = .idle
    private let writer: ChallengePOIWriting

    public init(writer: ChallengePOIWriting) { self.writer = writer }

    public func submit(coordinator: ChallengePOICoordinator, userLat: Double?, userLon: Double?) async {
        guard state != .submitting, !coordinator.submitting else { return }
        let payload: [String: PlayWireValue]
        do { payload = try coordinator.buildCompletionPayload(userLat: userLat, userLon: userLon) }
        catch {
            state = .invalid(error.localizedDescription)
            return
        }
        state = .submitting
        let request = ChallengePOIRequestBuilder.request(nodeId: coordinator.nodeId, payload: payload)
        switch await writer.complete(request) {
        case .success(let data):
            guard data["needRedeem"].bool != nil else {
                coordinator.applyCompletionResult(code: 500, data: data, message: nil)
                state = .unconfirmed(coordinator.errorMessage)
                return
            }
            coordinator.applyCompletionResult(code: 200, data: data, message: nil)
            state = .done
        case .rejected(let message):
            coordinator.applyCompletionResult(code: 1001, data: .null, message: message)
            state = .rejected(message)
        case .unconfirmed(let message):
            coordinator.applyCompletionResult(code: 500, data: .null, message: message)
            state = .unconfirmed(coordinator.errorMessage)
        case .unavailable:
            state = .unavailable
        }
    }
}
