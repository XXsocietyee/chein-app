import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix/1128c-ai-showcase (owner 11-28 ~12:25 UTC: "highlight AI in our build process"; planning audit H-08a/b/c and the
/// Release-composition rule). The player/club AI creation services are switched ON in the reviewed China composition:
///
/// | Feature | Route | Roles (backend `ApiAiController` gate) |
/// |---|---|---|
/// | `.publishingAIQuota` | POST `api/ai/theme/draft/quota` (no body) | player, club (`gateThemeDraftRole`) |
/// | `.publishingAITheme` | POST `api/ai/theme/draft/prepare`, `…/execute` | player, club (`gateThemeDraftRole`) |
/// | `.publishingAIClub` | POST `api/ai/club/design` `{idea, clubStyle?, targetDurationMin?}` | club (`gateRole` blocks players) |
/// | `.publishingAITemplate` | POST `api/ai/template/fill` `{shopName, extraNote, category?, reward?, playStyle?}` | club |
/// | `.publishingAISafety` | POST `api/ai/safety/precheck` `{title, subtitle, description, nodes[]}` | club |
///
/// The draft read-backs (`GET api/ai/theme/draft/request|recovery`) already run through `G6CapabilitySource`.
/// Merchant AI (`api/ai/merchant/*`, the store-bound template fill) stays deferred: merchant accounts get none of these.
/// A path the China production host does not serve is left out against that host, like `projectEditorRoutes`.
@MainActor enum AICreationReleaseApprovals {
    static let quotaPath = "api/ai/theme/draft/quota"
    static let themePaths = [PublishingContracts.aiThemeDraftPreparePath, PublishingContracts.aiThemeDraftExecutePath]
    static let clubDesignPath = "api/ai/club/design"
    static let templateFillPath = "api/ai/template/fill"
    static let safetyPath = AISafetyPrecheckRequest.path
    static var allPaths: Set<String> { Set([quotaPath, clubDesignPath, templateFillPath, safetyPath] + themePaths) }

    /// The roles the backend lets through: players may draft themes; club hosts get every creator AI.
    static func features(role: String) -> [BusinessRuntimeFeature] {
        switch role {
        case "player": return [.publishingAIQuota, .publishingAITheme]
        case "club": return [.publishingAIQuota, .publishingAITheme, .publishingAIClub, .publishingAITemplate, .publishingAISafety]
        default: return []
        }
    }

    static func paths(_ feature: BusinessRuntimeFeature) -> [String] {
        switch feature {
        case .publishingAIQuota: return [quotaPath]
        case .publishingAITheme: return themePaths
        case .publishingAIClub: return [clubDesignPath]
        case .publishingAITemplate: return [templateFillPath]
        case .publishingAISafety: return [safetyPath]
        default: return []
        }
    }

    static func routes(baseURL: URL, role: String) -> [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] {
        let production = ChinaReviewedRouteCapability.targetsChinaProduction(baseURL)
        var result: [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] = [:]
        for feature in features(role: role) {
            let served = paths(feature).filter { !production || ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + $0) }
            let routes = Set(served.compactMap { try? BusinessRuntimeRoute.post($0) })
            if !routes.isEmpty { result[feature] = routes }
        }
        return result
    }

    /// Composition-transport admission (called from `acceptsPlayerWrite`, so a live player-write grant for this viewer
    /// is already required). POST only, no query; the quota read has no body, every other call is a JSON object.
    /// The exact field sets are checked again by `PublishingAIRuntimeTransport`. Nil leaves other paths alone.
    static func decision(relative: String, method: String, request: URLRequest) -> Bool? {
        guard allPaths.contains(relative) else { return nil }
        guard method == "POST", request.url?.query == nil else { return false }
        if relative == quotaPath { return request.httpBody == nil || request.httpBody?.isEmpty == true }
        guard request.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("application/json") == true,
              let body = request.httpBody, !body.isEmpty,
              (try? JSONSerialization.jsonObject(with: body)) is [String: Any] else { return false }
        return true
    }
}
