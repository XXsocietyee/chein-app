import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Reader-side raw bodies for three page models that must tell a missing number from a literal 0.
/// In-memory transports only; no socket, URLSession, live server or route change.
private final class GapBodyTransport: HTTPTransport {
    var json: String
    var status = 200
    private(set) var requests: [URLRequest] = []
    init(_ json: String) { self.json = json }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(json.utf8), status)
    }
}

final class CoreGapReaderBodyTests: XCTestCase {
    private let dash = "\u{2014}"
    private func config() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://example.com/fixture/")!)
    }

    // MARK: Club tab (pages/talent/list)

    func testClubHomeBodyIsTheUnmodifiedResponseOfTheExistingRead() async throws {
        let body = #"{"code":200,"data":{"owned":[{"id":7,"name":"Fixture"}],"joined":[],"nearby":[],"leaderStatus":{"canCreate":true}}}"#
        let transport = GapBodyTransport(body)
        let data = try await ClubService(configuration: config(), transport: transport).homeBody(token: "fixture-token")
        XCTAssertEqual(String(data: data, encoding: .utf8), body)
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "https://example.com/fixture/api/club/home")
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
    }

    func testClubHomeBodyStillRejectsAServerRefusalBeforeAnyPageModel() async throws {
        let transport = GapBodyTransport(#"{"code":500,"msg":"fixture"}"#)
        do {
            _ = try await ClubService(configuration: config(), transport: transport).homeBody(token: "fixture-token")
            XCTFail("a business refusal is not a body")
        } catch {
            XCTAssertNotNil(error as? ClubReadFailure)
        }
    }

    func testClubTabProjectsFromTheRawBodyAndKeepsUnknownCountsAsEmDashes() throws {
        let body = Data(#"{"code":200,"data":{"owned":[{"id":81,"name":"Fixture","memberCount":0},{"id":82,"name":"No count"}],"joined":[],"nearby":[]}}"#.utf8)
        let model = ClubTabPageModel.project(homeBody: body)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.rows.map(\.memberCount.text), ["0", dash])
        XCTAssertEqual(model.eventCount.text, dash)
    }

    func testClubTabRawBodyNilIsUnknownAndAMalformedBodyIsAnErrorNeverEmpty() {
        XCTAssertEqual(ClubTabPageModel.project(homeBody: nil).phase, .unknown)
        XCTAssertEqual(ClubTabPageModel.project(homeBody: nil, inFlight: true).phase, .loading)
        for text in ["", "[]", "{}", #"{"code":500,"data":{}}"#, #"{"code":200}"#, #"{"code":200,"data":[]}"#] {
            XCTAssertEqual(ClubTabPageModel.project(homeBody: Data(text.utf8)).phase, .error, text)
        }
        XCTAssertNil(ClubTabPageModel.homeData(from: Data("not json".utf8)))
    }

    func testClubTabRawBodyStaysCapabilityGated() {
        let body = Data(#"{"code":200,"data":{"owned":[],"joined":[],"nearby":[],"leaderStatus":{"canCreate":true}}}"#.utf8)
        let model = ClubTabPageModel.project(homeBody: body)
        XCTAssertTrue(model.showsCreateClub)
        XCTAssertFalse(ClubTabPageModel.project(homeBody: body, merchant: true).showsCreateClub)
        XCTAssertFalse(model.showsMerchantChoice)
        XCTAssertFalse(model.paymentEnabled)
        XCTAssertFalse(model.payoutEnabled)
    }

    // MARK: Club edit (pages/club/edit)

    func testClubDetailBodyIsTheUnmodifiedResponseAndRejectsABadID() async throws {
        let body = #"{"code":200,"data":{"id":7,"name":"Fixture","memberCount":0}}"#
        let transport = GapBodyTransport(body)
        let service = try ClubService(configuration: config(), transport: transport)
        let data = try await service.detailBody(id: 7, token: "fixture-token")
        XCTAssertEqual(String(data: data, encoding: .utf8), body)
        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "https://example.com/fixture/api/club/detail")
        do {
            _ = try await service.detailBody(id: 0, token: "fixture-token")
            XCTFail("id 0 must not reach the transport")
        } catch {
            XCTAssertEqual(error as? APIError, .invalidRequest)
        }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testClubEditPageReadsTheFullRawBodyAndKeepsAMissingCountApartFromZero() {
        let zero = Data(#"{"code":200,"data":{"id":81,"memberCount":0}}"#.utf8)
        let omitted = Data(#"{"code":200,"data":{"id":81}}"#.utf8)
        let playerFirst = ClubEditPage.make(read: .detail(zero, blockers: nil), surface: .playerFirst, clubID: 81, governanceAvailable: true)
        XCTAssertEqual(playerFirst.state, .ready)
        XCTAssertEqual(playerFirst.memberCountText, "0")
        XCTAssertFalse(playerFirst.showsEdit)
        XCTAssertFalse(playerFirst.showsDissolve)
        XCTAssertFalse(playerFirst.entryVisible)
        let missing = ClubEditPage.make(read: .detail(omitted, blockers: nil), surface: .manage, clubID: 81, governanceAvailable: true)
        XCTAssertEqual(missing.memberCountText, dash)
        XCTAssertFalse(missing.showsEdit, "no proven owner or admin capability in the body")
        XCTAssertFalse(missing.showsDissolve)
    }

    func testClubEditPageWithoutABodyIsEmptyOrUnknownNeverACount() {
        let idle = ClubEditPage.make(readback: .idle, write: .idle, surface: .manage, clubID: 7,
                                     governanceAvailable: false, detailBody: nil, blockersBody: nil)
        XCTAssertEqual(idle.state, .empty)
        XCTAssertEqual(idle.memberCountText, dash)
        let withBody = ClubEditPage.make(readback: .idle, write: .idle, surface: .playerFirst, clubID: 7,
                                         governanceAvailable: false, detailBody: Data(#"{"code":200,"data":{"id":7,"memberCount":3}}"#.utf8), blockersBody: nil)
        XCTAssertEqual(withBody.memberCountText, "3")
    }

    // MARK: Favorites (pages/mylike/mylike)

    func testFavoritePostsPageKeepsTheRawBodyForTheFavoritesProjection() async throws {
        let body = #"{"code":200,"data":{"rows":[{"id":11,"likeCount":0,"commentCount":0},{"id":12}],"total":2}}"#
        let transport = GapBodyTransport(body)
        let service = try AccountCollectionService(configuration: config(), transport: transport)
        let page = try await service.favoritePosts(pageNumber: 1, pageSize: 10, token: "synthetic-token")
        XCTAssertEqual(page.rawPayload.flatMap { String(data: $0, encoding: .utf8) }, body)
        XCTAssertEqual(transport.requests.first?.url?.path, "/fixture/api/creativesquare/list")
        let state = AccountCollectionFavoritesPageModel.resolvePosts(loading: false, payload: page.rawPayload, failure: nil, pageSize: 10)
        guard case .ready(let ready) = state else { return XCTFail("ready") }
        XCTAssertEqual(ready.posts.map(\.likeCountText), ["0", dash])
        XCTAssertEqual(ready.posts.map(\.commentCountText), ["0", dash])
    }

    func testAPageBuiltWithoutABodyHasNoRawPayloadAndStaysUnknown() {
        let page = AccountCollectionPostPage(rows: [], pageNumber: 1, pageSize: 10)
        XCTAssertNil(page.rawPayload)
        XCTAssertEqual(AccountCollectionFavoritesPageModel.resolvePosts(loading: false, payload: page.rawPayload, failure: nil, pageSize: 10), .unknown)
    }
}
