import SwiftUI
import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// R7-PC-B1-1 (MP-first rule, owner 2026-11-25): topic 收藏 exactly as the mini program does it.
/// - Seed: `POST api/topic/like_list {pageNum: 1, pageSize: 200}` once on entry (pages/topic/index/index.js:577-591).
/// - Toggle: optimistic, then `POST api/topic/like {id, type: 1|0}`; a non-200 or a network failure rolls back
///   with a toast (index.js:619-637).
/// Gate: the reviewed lease that already covers `api/topic/like` + `api/topic/like_list` (TopicUnlikeApproval).
@MainActor struct TopicFavoriteHost {
    let controller: TopicLikeHostController
    /// `(topicID, token) -> liked`, from the MP like_list read.
    let readLiked: (Int, String) async throws -> Bool
}

enum TopicFavoriteMP {
    /// MP `_loadFav` body.
    static let listFields: [String: String] = ["pageNum": "1", "pageSize": "200"]
    static func listRequest(configuration: APIConfiguration, token: String) throws -> URLRequest {
        try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(PlayerContentMPContract.likeListPath),
                                               fields: listFields, token: token)
    }
    /// `rows.some(t => String(t.id) === String(topicId))`; a non-200 envelope is not an answer.
    static func liked(topicID: Int, data: Data, status: Int) throws -> Bool {
        guard (200..<300).contains(status), let list = try? JSONDecoder().decode(ListEnvelope.self, from: data), list.code == 200 else {
            throw APIError.invalidRequest
        }
        return (list.data?.rows ?? list.rows ?? []).contains { $0.id == topicID }
    }
    /// What the bookmark shows, MP-style: the newest intent while it is pending or accepted, rolled back on a rejection.
    static func displayed(_ state: TopicLikeLedger.State?) -> Bool? {
        switch state {
        case .confirmed(let liked)?, .mismatch(_, let liked)?: return liked
        case .sending(let d)?, .awaitingReadback(let d)?, .unknown(let d)?: return d.liked
        case .rejected(let d, _)?: return !d.liked
        case nil: return nil
        }
    }
    private struct ListEnvelope: Decodable {
        struct Row: Decodable { let id: Int? }
        struct Page: Decodable { let rows: [Row]? }
        let code: Int
        let rows: [Row]?
        let data: Page?
    }
}

private struct TopicFavoriteHostFactoryKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> TopicFavoriteHost?)? = nil
}
extension EnvironmentValues {
    /// Nil (fixtures, signed out, no reviewed lease) hides the 收藏 button.
    var topicFavoriteHostFactory: (@MainActor () -> TopicFavoriteHost?)? {
        get { self[TopicFavoriteHostFactoryKey.self] }
        set { self[TopicFavoriteHostFactoryKey.self] = newValue }
    }
}

extension AppSession {
    func makeTopicFavoriteHost() -> TopicFavoriteHost? {
        guard let context = currentRuntimeDependencyContext, let api = regionalConfiguration?.apiConfiguration,
              composition.topicUnlikeApproval(context) != nil else { return nil }
        let transport = runtimeHTTPTransport
        let fresh: () -> RuntimeDependencyContext? = { [weak self] in
            guard let self, let now = self.currentRuntimeDependencyContext, ContentDraftContextFence.matches(context, now) else { return nil }
            return now
        }
        let controller = TopicLikeHostController(
            likeGrantEnabled: true,
            requestBuilder: { topicID, direction, token in
                // Mini-program body (`id` then `type`, urlencoded). The contract builder omits Authorization.
                var request = try TopicLikeHostController.miniProgramLikeRequest(
                    baseURL: api.baseURL, topicID: topicID, direction: direction, token: token)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(token, forHTTPHeaderField: "Authorization")
                return request
            },
            transport: transport,
            currentScope: { fresh().flatMap { try? TopicLikeScope(accountID: $0.session.accountID, epoch: $0.session.epoch, namespace: $0.session.namespace) } },
            token: { fresh()?.session.token })
        return TopicFavoriteHost(controller: controller, readLiked: { topicID, token in
            let (data, status) = try await transport.send(try TopicFavoriteMP.listRequest(configuration: api, token: token))
            return try TopicFavoriteMP.liked(topicID: topicID, data: data, status: status)
        })
    }
}
