#if DEBUG
import SwiftUI
import Observation

@MainActor @Observable final class ProfileSelfProjectsFixturePublicReader: SocialAccountReading, SquareReading {
    var identity = SocialAccountIdentity(accountID:81,epoch:1,role:"player")
    var presentationRevision: UInt64 = 1
    var scope = UUID()
    var isConfigured = true
    var isOfflineExample = true
    var isSignedIn: Bool { identity.accountID != nil }
    func publicProfile(memberID:Int) async throws -> SocialPublicProfile {
        try JSONDecoder().decode(SocialPublicProfile.self,from:Data("{\"id\":\(memberID),\"nickname\":\"\(iaFixtureText("Synthetic projects owner", "示例项目主人"))\"}".utf8))
    }
    func informationList() async throws -> [SocialInformation] { [] }
    func information(id:Int) async throws -> SocialInformation { throw APIError.notConfigured }
    func invitationHistory(page:Int) async throws -> SocialInviteHistory { throw APIError.notConfigured }
    func squareFeed(query:SquareQuery,cursor:SquareCursor?) async throws -> SquareFeedPage { .init(items:[],hasMore:false) }
    func squareDetail(id:Int) async throws -> SquarePost { throw APIError.notConfigured }
    func squareComments(postID:Int,pageNumber:Int) async throws -> SquareCommentPage { .init(items:[],pageNumber:pageNumber) }
}
@MainActor @Observable final class ProfileSelfProjectsFixtureReader: CreatorContentReading {
    var scope=UUID(); var isAuthenticated=true; var isConfigured=true; let isOfflineExample=true
    var reads=0; var scenario:String
    init(_ scenario:String="content") { self.scenario=scenario }
    func projects(query:CreatorContentQuery) async throws -> CreatorContentProjectPage {
        reads += 1
        if scenario == "failure" && reads == 1 { throw APIError.httpStatus(503) }
        if scenario == "refreshFailure" && reads == 2 { throw APIError.httpStatus(503) }
        if scenario == "empty" { return .init(rows:[],total:0) }
        let raw = #"{"rows":[{"id":7,"bizType":"activity","title":"\#(iaFixtureText("Synthetic activity", "示例活动"))"},{"id":7,"bizType":"topic","title":"\#(iaFixtureText("Synthetic current topic", "示例进行中项目"))","startTime":"2020-01-01","endTime":"2099-01-01"},{"id":8,"bizType":"topic","title":"\#(iaFixtureText("Synthetic ended topic", "示例已结束项目"))","startTime":"2020-01-01","endTime":"2020-01-02"},{"id":9,"bizType":"topic","title":"\#(iaFixtureText("Synthetic unknown schedule", "示例待定档期项目"))"}],"total":4}"#
        let page=try JSONDecoder().decode(CreatorContentProjectPage.self,from:Data(raw.utf8))
        return .init(rows:page.rows,total:scenario == "truncated" ? 201:page.total)
    }
    func center() async throws -> CreatorContentCenter { throw APIError.invalidRequest }
}
@MainActor struct ProfileSelfProjectsFixtureHost: View {
    private let social:ProfileSelfProjectsFixturePublicReader
    private let projects:ProfileSelfProjectsFixtureReader
    private let memberID:Int
    /// The design sweep (`e4-self-projects*`) shows the player screen only; UI tests keep the read counter and retire control.
    private let showsTestControls:Bool
    init(scenario:String="content",showsTestControls:Bool=true) {
        self.showsTestControls=showsTestControls
        let social=ProfileSelfProjectsFixturePublicReader(),projects=ProfileSelfProjectsFixtureReader(scenario)
        if scenario == "guest" { social.identity = .init(accountID:nil,epoch:1);projects.isAuthenticated=false }
        social.isOfflineExample=showsTestControls
        self.social=social;self.projects=projects;memberID=scenario == "other" ? 92:81
    }
    var body:some View {
        NavigationStack {
            SocialPublicProfileView(memberID:memberID,reader:social,squareReader:social,
                selfProjectsAccess:.init(reader:projects,owner:social.identity,detail:{ destination in
                    AnyView(Text(verbatim:"Synthetic detail: \(String(describing:destination))").accessibilityIdentifier("profile.selfProjectsFixture.detail"))
                }))
                .safeAreaInset(edge:.bottom) {
                    if showsTestControls {
                    VStack {
                        Text(verbatim:"Projects reads: \(projects.reads)").accessibilityIdentifier("profile.selfProjectsFixture.reads")
                        Button("Retire synthetic account") {
                            social.identity = .init(accountID:82,epoch:2);social.presentationRevision += 1;projects.scope=UUID()
                        }.accessibilityIdentifier("profile.selfProjectsFixture.retire")
                    }.cyText(.meta)
                    }
                }
        }
    }
}
#endif
