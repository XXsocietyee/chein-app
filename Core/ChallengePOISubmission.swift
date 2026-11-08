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
