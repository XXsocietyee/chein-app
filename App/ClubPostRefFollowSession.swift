import SwiftUI

/// CLB-G05 / CLB-G10 session hooks for `ClubCommunityContext` (MP `pages/club/detail/index.js:1982-1998`, 3224-3243).
/// Both are plain player reads/writes the MP sends; the server decides. A sign-out or account switch mid-flight
/// drops the result.
@MainActor extension AppSession {
    var clubPostRefLoader: (() async throws -> [ClubPostRefOption])? {
        guard regionalConfiguration?.showsRoute("/api/registration/my-joined") == true else { return nil }
        return { [weak self] in
            guard let self, let token = self.token, AuthRequestBuilder.isValidToken(token),
                  let configuration = self.regionalConfiguration?.apiConfiguration else { throw APIError.unauthorized }
            let stamp = self.sessionRevision
            let client = ClubRemainingGapClient(configuration: configuration, transport: self.runtimeHTTPTransport)
            do {
                let options = try await client.fetchPostRefOptions(token: token)
                guard self.sessionRevision == stamp, self.token == token else { throw CancellationError() }
                return options
            } catch {
                if error as? APIError == .unauthorized { self.expireIfMatching(error: error, stamp: stamp, credential: token) }
                throw error
            }
        }
    }

    var clubFollowAuthorAction: ((Int) async throws -> Void)? {
        guard regionalConfiguration?.showsRoute("/api/user/follow/action") == true else { return nil }
        return { [weak self] memberID in
            guard let self, let token = self.token, AuthRequestBuilder.isValidToken(token),
                  let configuration = self.regionalConfiguration?.apiConfiguration else { throw APIError.unauthorized }
            let stamp = self.sessionRevision
            let client = ClubRemainingGapClient(configuration: configuration, transport: self.runtimeHTTPTransport)
            do {
                try await client.toggleFollowAuthor(targetUserID: memberID, follow: true, token: token)
            } catch {
                if error as? APIError == .unauthorized { self.expireIfMatching(error: error, stamp: stamp, credential: token) }
                throw error
            }
        }
    }

    /// CLB-G04: 申请带队 (`/api/coop/pool/apply`). Nil when the route is not offered here.
    var clubCoopPoolApply: ((_ topicID: Int, _ clubID: Int, _ message: String) async throws -> Void)? {
        guard regionalConfiguration?.showsRoute("/api/coop/pool/apply") == true else { return nil }
        return { [weak self] topicID, clubID, message in
            guard let self, let token = self.token, AuthRequestBuilder.isValidToken(token),
                  let configuration = self.regionalConfiguration?.apiConfiguration else { throw APIError.unauthorized }
            let stamp = self.sessionRevision
            let client = ClubCoopPoolApplyClient(configuration: configuration, transport: self.runtimeHTTPTransport)
            do {
                try await client.apply(topicID: topicID, clubID: clubID, message: message, token: token)
            } catch {
                if error as? APIError == .unauthorized { self.expireIfMatching(error: error, stamp: stamp, credential: token) }
                throw error
            }
        }
    }
}
