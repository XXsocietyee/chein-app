import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Additional body-level contract guard for provider-generating calls. It cannot broaden
/// BusinessRuntimeTransport's exact deployment/account/epoch/method/path grants.
@MainActor public final class PublishingAIRuntimeTransport: HTTPTransport {
    private let feature: BusinessRuntimeFeature
    private let baseURL: URL
    private let transport: any HTTPTransport
    public init(feature: BusinessRuntimeFeature, baseURL: URL, transport: any HTTPTransport) {
        self.feature = feature; self.baseURL = baseURL; self.transport = transport
    }
    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard Self.validates(request, feature: feature, baseURL: baseURL) else { throw APIError.invalidRequest }
        return try await transport.send(request)
    }
    public static func validates(_ request: URLRequest, feature: BusinessRuntimeFeature, baseURL: URL) -> Bool {
        guard request.httpMethod == "POST", request.url?.query == nil, request.url?.fragment == nil else { return false }
        let matchedPath: String?
        if feature == .publishingAITheme {
            matchedPath = [PublishingContracts.aiThemeDraftPreparePath, PublishingContracts.aiThemeDraftExecutePath]
                .first(where: { request.url == baseURL.appendingPathComponent($0) })
        } else {
            let path: String
            switch feature {
            case .publishingAIClub: path = "api/ai/club/design"
            case .publishingAITemplate: path = "api/ai/template/fill"
            case .publishingAISafety: path = AISafetyPrecheckRequest.path
            case .publishingAIQuota:
                return request.url == baseURL.appendingPathComponent("api/ai/theme/draft/quota") && (request.httpBody == nil || request.httpBody?.isEmpty == true)
            default: return false
            }
            matchedPath = request.url == baseURL.appendingPathComponent(path) ? path : nil
        }
        guard let matchedPath,
              request.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("application/json") == true,
              let data = request.httpBody, let fields = try? JSONDecoder().decode([String: ProjectEditJSON].self, from: data) else { return false }
        if feature == .publishingAITheme && matchedPath == PublishingContracts.aiThemeDraftExecutePath {
            guard Set(fields.keys) == ["requestId"],
                  let requestID = fields["requestId"]?.text,
                  G6AIThemeDraft.isServerID(requestID) else { return false }
            return true
        }
        // fix/1128c-ai-showcase (H-08b): exactly the backend `AiSafetyPrecheckReq` keys.
        if feature == .publishingAISafety { return AISafetyPrecheckRequest.validates(fields) }
        if feature == .publishingAITemplate {
            guard Set(fields.keys).isSubset(of: ["shopName", "extraNote", "category", "reward", "playStyle", "validationMethod"]),
                  let name = fields["shopName"]?.text, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let note = fields["extraNote"]?.text, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            for key in ["category", "reward", "playStyle"] { if let value = fields[key], value.text == nil { return false } }
            if let value = fields["validationMethod"], value.integer.flatMap(MerchantTemplateMethod.init(rawValue:)) == nil { return false }
            return true
        }
        guard let idea = fields["idea"]?.text, !idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch feature {
        case .publishingAITheme:
            guard Set(fields.keys) == ["prepareKey", "idea", "productType"],
                  let prepareKey = fields["prepareKey"]?.text, UUID(uuidString: prepareKey) != nil else { return false }
            return idea.count <= 300 && [1, 2].contains(fields["productType"]?.integer ?? 0)
        case .publishingAIClub:
            guard Set(fields.keys).isSubset(of: ["idea", "clubStyle", "targetDurationMin"]) else { return false }
            if let style = fields["clubStyle"], style.text == nil { return false }
            if let duration = fields["targetDurationMin"], duration.integer == nil { return false }
            return true
        default: return false
        }
    }
}
public extension BusinessRuntimeFactory {
    func publishingAuxiliary(feature: BusinessRuntimeFeature, journal: any OperationPendingJournal,
                             credentials: @escaping () -> PublishingCredentials?) -> PublishingAuxiliaryService? {
        guard feature == .publishingAITheme || feature == .publishingAIClub || feature == .publishingAITemplate || feature == .publishingAISafety, permits(feature),
              let approval = approval([feature]), let api = try? APIConfiguration(baseURL: captured.baseURL) else { return nil }
        let scoped = PublishingAIRuntimeTransport(feature: feature, baseURL: captured.baseURL, transport: client([feature]))
        return PublishingAuxiliaryService(configuration: api, transport: scoped, approval: approval, journal: journal, credentials: credentials)
    }
}
