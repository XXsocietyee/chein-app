#if DEBUG
import Foundation
import SwiftUI

/// Mount only under an explicit UI-test launch argument, never the production factory.
@MainActor
enum ClubCommunityFixture {
    static let identity = ClubReadIdentity(accountID: 5, epoch: 1)
    static func context() throws -> ClubCommunityContext {
        try context(identity: identity, clubID: 10)
    }
    /// mp-club r3 (18:15 sweep): design fixtures mount the club 帖文 feed with their own viewer and club id.
    static func context(identity: ClubReadIdentity, clubID: Int) throws -> ClubCommunityContext {
        let transport = ClubCommunityFixtureTransport(clubID: clubID)
        let service = ClubCommunityService(offlineBaseURL: URL(string: "https://fixture.invalid")!, transport: transport)
        let session = try ClubCommunitySession(identity: identity, token: "fixture-only")
        let evidence: (Int, ClubCommunityPost?, ClubCommunityComment?) async throws -> ClubCommunityEvidence = { clubID, post, comment in
            .init(identity: identity, clubID: clubID, joined: true, owner: true, administrator: false, post: post, comment: comment)
        }
        let coordinator = ClubCommunityCoordinator(service: service, currentSession: { session }, refreshEvidence: { old in
            try await evidence(old.clubID, old.post, old.comment)
        })
        return ClubCommunityContext(service: service, currentSession: { session }, coordinator: coordinator, evidence: evidence)
    }
}
private final class ClubCommunityFixtureTransport: ClubCommunityOfflineTransport {
    let clubID: Int
    init(clubID: Int) { self.clubID = clubID }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let payload: String
        switch request.url?.path {
        case "/api/club/post/list":
            payload = #"{"rows":[{"id":20,"clubId":\#(clubID),"authorMemberId":5,"content":"Fixture club post","version":2,"isPinned":0,"nickname":"Fixture author"},{"id":21,"clubId":\#(clubID),"authorMemberId":6,"content":"Another member post","version":1,"isPinned":0}]}"#
        case "/api/club/post/feed":
            payload = #"{"rows":[{"id":20,"clubId":\#(clubID),"authorMemberId":5,"content":"Fixture club post","version":2,"isPinned":0}],"clubCount":1,"hasMore":false}"#
        case "/api/club/post/comment/list":
            payload = #"[{"id":30,"postId":20,"memberId":6,"nickname":"Fixture member","content":"Fixture comment"}]"#
        case "/api/club/post/history":
            payload = #"[{"id":40,"snapshotVersion":1,"content":"Previous public content","images":""}]"#
        default: payload = "null"
        }
        return (Data("{\"code\":200,\"data\":\(payload)}".utf8), 200)
    }
}
#endif
