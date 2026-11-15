import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Original draft writer for the NPC author flow.
/// Calls the V2 theme-draft prepare + execute flow, then the existing read.
///
/// Prepare path is `ApiAiController.prepareThemeDraft`: class `@RequestMapping("/api/ai")`
/// plus `@PostMapping("/theme/draft/prepare")` (`{prepareKey, idea}`).
/// Execute path is `ApiAiController.executeThemeDraft`: `@PostMapping("/theme/draft/execute")`
/// (`{requestId}` using the `td2_<32hex>` id returned by prepare).
/// idea is exactly four lines, and nothing else:
/// name: <name value>
/// greeting: <greeting value>
/// persona: <persona value>
/// knowledge: <knowledge value>
/// That string is what AiCreatorServiceImpl puts into the model user JSON as idea.
/// If the held request id is missing, this does not POST and does not mint one.
///
/// A request id kept locally is not server acceptance. The read is
/// `MerchantNPCThemeDraftRequestRead` and uses only the `td2_...` request id
/// returned and accepted by `POST /api/ai/theme/draft/prepare` + `/execute`,
/// after `holdThemeDraftRequest` has stored that id.
/// A response that does not return one does not fall back
/// to the held id, a new UUID, or a hand-filled id.
/// A response that is not acceptance does not GET, does not replace the held id, returns nil, and does not publish.
/// If holdThemeDraftRequest rejects the returned id, this does not GET and does not publish.
/// A missing publisher does not publish the NPC.
@MainActor public final class MerchantNPCOriginalDraftWriter {
    public static let path = "api/ai/theme/draft/prepare"
    public static let executePath = "api/ai/theme/draft/execute"

    private struct Submission {
        let request: URLRequest
        let memberID: Int64
        let token: String
        let name: String
        let greeting: String
        let persona: String
        let knowledge: String
    }

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let reader: MerchantNPCThemeDraftRequestRead
    private let memberID: () -> Int64?
    private let token: () -> String?

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                reader: MerchantNPCThemeDraftRequestRead,
                memberID: @escaping () -> Int64?, token: @escaping () -> String?) {
        self.configuration = configuration
        self.transport = transport
        self.reader = reader
        self.memberID = memberID
        self.token = token
    }

    /// POST prepare, then execute, then read only after SUCCEEDED acceptance and holding the returned td2_ id.
    /// Returns the existing read's fact only when acceptance succeeds.
    /// Does not invent a receipt and does not publish.
    public func submitHeldDraftThenRead(_ flow: MerchantNPCKnowledgeAuthorFlow) async throws -> MerchantNPCDraftReadFact? {
        guard let prepared = try makeSubmission(flow) else { return nil }
        let prepareResponse = try await transport.send(prepared.request)
        guard matches(flow, prepared: prepared) else { return nil }
        guard let preparedIntent = Self.intentView(body: prepareResponse.0, status: prepareResponse.1) else {
            return nil
        }
        let acceptedID: String
        switch preparedIntent.state {
        case "PREPARED":
            guard let execRequest = try makeRequest(path: Self.executePath, token: prepared.token,
                                                    payload: ["requestId": preparedIntent.requestID]) else { return nil }
            let execResponse = try await transport.send(execRequest)
            guard matches(flow, prepared: prepared) else { return nil }
            guard let execIntent = Self.intentView(body: execResponse.0, status: execResponse.1),
                  execIntent.requestID == preparedIntent.requestID,
                  execIntent.state == "SUCCEEDED" else {
                // Not acceptance: does not GET, does not replace the held id, and does not publish.
                return nil
            }
            acceptedID = execIntent.requestID
        case "SUCCEEDED":
            acceptedID = preparedIntent.requestID
        default:
            return nil
        }
        guard flow.holdThemeDraftRequest(memberID: prepared.memberID, requestID: acceptedID) else {
            // The returned id was rejected: does not GET, does not replace the held id, and does not publish.
            return nil
        }
        return try await reader.readAndRecover(flow)
    }

    private func matches(_ flow: MerchantNPCKnowledgeAuthorFlow, prepared: Submission) -> Bool {
        memberID() == prepared.memberID && token() == prepared.token &&
        flow.heldThemeDraftMemberID == prepared.memberID &&
        flow.authored?.name.value == prepared.name &&
        flow.authored?.greeting.value == prepared.greeting &&
        flow.authored?.persona.value == prepared.persona &&
        flow.authored?.knowledge.value == prepared.knowledge
    }

    /// Prepare JSON keys are prepareKey and idea. If the held request id is missing, returns nil and does not POST.
    private func makeSubmission(_ flow: MerchantNPCKnowledgeAuthorFlow) throws -> Submission? {
        guard let held = flow.heldThemeDraftRequestID,
              MerchantNPCKnowledgeAuthorFlow.isThemeDraftRequestID(held),
              let member = flow.heldThemeDraftMemberID, member > 0,
              let loggedIn = memberID(), loggedIn == member,
              let credential = token(), AuthRequestBuilder.isValidToken(credential),
              let authored = flow.authored else { return nil }
        let name = authored.name.value
        let greeting = authored.greeting.value
        let persona = authored.persona.value
        let knowledge = authored.knowledge.value
        let idea = "name: \(name)\ngreeting: \(greeting)\npersona: \(persona)\nknowledge: \(knowledge)"
        let payload: [String: String] = [
            "prepareKey": held,
            "idea": idea
        ]
        guard let request = try makeRequest(path: Self.path, token: credential, payload: payload) else { return nil }
        return Submission(request: request, memberID: member, token: credential,
                          name: name, greeting: greeting, persona: persona, knowledge: knowledge)
    }

    private func makeRequest(path: String, token: String, payload: [String: String]) throws -> URLRequest? {
        guard AuthRequestBuilder.isValidToken(token),
              var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https", components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        let prefix = components.path == "/" ? "" : components.path
        guard !prefix.split(separator: "/").contains("..") else { return nil }
        components.path = prefix + "/" + path
        components.queryItems = nil
        guard let url = components.url, url.path == "/" + path else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }

    /// Reads `AiThemeDraftIntentView` from `R.data` (`code == 200`, `errorCode` absent, `data.requestId` matches `td2_` server ID, and `data.state` is present).
    /// Nested result ids are not `data.requestId`. PREPARED, PROCESSING, FAILED, UNKNOWN, non-2xx, or errorCode != nil must not proceed past their allowed stage.
    private static func intentView(body: Data, status: Int) -> (requestID: String, state: String)? {
        guard (200..<300).contains(status), body.count <= 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              object["code"] as? Int == 200,
              object["errorCode"] == nil,
              let data = object["data"] as? [String: Any],
              let requestID = data["requestId"] as? String,
              G6AIThemeDraft.isServerID(requestID),
              let state = data["state"] as? String else { return nil }
        return (requestID, state)
    }
}
