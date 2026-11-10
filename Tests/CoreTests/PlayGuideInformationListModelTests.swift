import XCTest
@testable import QuestifyCore

final class PlayGuideInformationListModelTests: XCTestCase {
    private let dash = PlayGuideDocumentCount.unknownMark

    private func project(_ json: String, status: Int = 200, capability: Bool = true) -> PlayGuideInformationListPage {
        PlayGuideInformationListPage.project(capabilityPresent: capability, body: Data(json.utf8), status: status)
    }

    private func row(_ id: Int, title: String = "Guide", subtitle: String? = "Sub", contents: String = "Body") -> String {
        var fields = ["\"id\":\(id)", "\"title\":\"\(title)\"", "\"contents\":\"\(contents)\""]
        if let subtitle { fields.append("\"subtitle\":\"\(subtitle)\"") }
        return "{\(fields.joined(separator: ","))}"
    }

    func testMissingCapabilityStaysHiddenAndDoesNotMarkTheListRouteLive() {
        let body = #"{"code":200,"data":[],"total":0}"#
        let page = project(body, capability: false)
        XCTAssertTrue(page.isHidden)
        XCTAssertNil(page.phase)
        XCTAssertEqual(page.documentCountText, dash)
        XCTAssertNil(page.documentCount.literal)
        XCTAssertFalse(PlayGuideInformationListPage.routeMarkedLive)
        XCTAssertEqual(PlayGuideInformationListPage.listPath, ProfileGuideReadRoute.listPath)
        XCTAssertEqual(PlayGuideInformationListPage.listPath, "api/common/infomation_list")
        XCTAssertNotEqual(page.documentCountText, "0")
    }

    func testLoadingHasNoDocumentCount() {
        let page = PlayGuideInformationListPage.project(capabilityPresent: true, body: nil, status: nil)
        XCTAssertEqual(page.phase, .some(.loading))
        XCTAssertFalse(page.isHidden)
        XCTAssertEqual(page.documentCountText, dash)
        XCTAssertNil(page.documentCount.literal)
    }

    func testEmptyListDoesNotInventZeroWhenTotalIsAbsent() {
        let page = project(#"{"code":200,"data":[]}"#)
        XCTAssertEqual(page.phase, .some(.empty))
        XCTAssertEqual(page.documentCountText, dash)
        XCTAssertNil(page.documentCount.literal)
        XCTAssertNotEqual(page.documentCountText, "0")
        let filtered = project(#"{"code":200,"data":[\#(row(7, title: "11", subtitle: "11", contents: "x"))]}"#)
        XCTAssertEqual(filtered.phase, .some(.empty))
        XCTAssertEqual(filtered.documentCountText, dash)
    }

    func testServerZeroStaysZeroAndUnknownTotalsStayAnEmDash() {
        let zero = project(#"{"code":200,"data":[],"total":0}"#)
        XCTAssertEqual(zero.phase, .some(.empty))
        XCTAssertEqual(zero.documentCount.literal, 0)
        XCTAssertEqual(zero.documentCountText, "0")
        let cases = [
            #"{"code":200,"data":[],"total":"UNKNOWN"}"#,
            #"{"code":200,"data":[],"total":"0"}"#,
            #"{"code":200,"data":[],"total":null}"#,
            #"{"code":200,"data":[],"total":1.5}"#,
            #"{"code":200,"data":[],"total":-1}"#,
            #"{"code":200,"data":[],"total":true}"#,
        ]
        for json in cases {
            let page = project(json)
            XCTAssertEqual(page.phase, .some(.empty), json)
            XCTAssertEqual(page.documentCountText, dash, json)
            XCTAssertNil(page.documentCount.literal, json)
            XCTAssertNotEqual(page.documentCountText, "0", json)
        }
    }

    func testExplicitUnknownListIsNotEmptyOrZero() {
        for json in [#"{"code":200}"#, #"{"code":200,"data":null}"#, #"{"code":200,"data":"UNKNOWN","total":4}"#] {
            let page = project(json)
            XCTAssertEqual(page.phase, .some(.unknown), json)
            XCTAssertEqual(page.documentCountText, dash, json)
            XCTAssertNil(page.documentCount.literal, json)
            XCTAssertNotEqual(page.phase, .some(.empty), json)
        }
    }

    func testTransportAndMalformedListsAreErrors() {
        let http = project(#"{"code":200,"data":[]}"#, status: 503)
        XCTAssertEqual(http.phase, .some(.error))
        XCTAssertEqual(http.documentCountText, dash)
        let rejected = project(#"{"code":401,"data":[]}"#)
        XCTAssertEqual(rejected.phase, .some(.error))
        let duplicate = project(#"{"code":200,"data":[\#(row(21)),\#(row(21))],"total":2}"#)
        XCTAssertEqual(duplicate.phase, .some(.error))
        XCTAssertNil(duplicate.documentCount.literal)
        XCTAssertNotEqual(duplicate.documentCountText, "2")
        let object = project(#"{"code":200,"data":{"rows":[]}}"#)
        XCTAssertEqual(object.phase, .some(.error))
    }

    func testReadyRowsKeepTheServerTotalInsteadOfTheRowCount() {
        let page = project(#"{"code":200,"data":[\#(row(21)),\#(row(22, title: "11", subtitle: "11"))],"total":9}"#)
        guard case .ready(let rows)? = page.phase else { return XCTFail("\(String(describing: page.phase))") }
        XCTAssertEqual(rows.map(\.id), [21])
        XCTAssertEqual(page.documentCount.literal, 9)
        XCTAssertEqual(page.documentCountText, "9")
        XCTAssertNotEqual(page.documentCountText, "1")
        let omitted = project(#"{"code":200,"data":[\#(row(21))]}"#)
        XCTAssertEqual(omitted.phase, .some(.ready([rows[0]])))
        XCTAssertEqual(omitted.documentCountText, dash)
        XCTAssertNil(omitted.documentCount.literal)
    }

    func testCoordinatorIgnoresOtherRoutesAndAClosedGrant() {
        var closed = PlayGuideInformationListCoordinator(capabilityPresent: false)
        XCTAssertTrue(closed.page.isHidden)
        closed.apply(route: .list, body: Data(#"{"code":200,"data":[],"total":0}"#.utf8), status: 200)
        XCTAssertTrue(closed.page.isHidden)
        XCTAssertEqual(closed.page.documentCountText, dash)
        XCTAssertNotEqual(closed.page.documentCountText, "0")

        var open = PlayGuideInformationListCoordinator(capabilityPresent: true)
        XCTAssertEqual(open.page.phase, .some(.loading))
        let ready = Data(#"{"code":200,"data":[\#(row(21))]}"#.utf8)
        open.apply(route: nil, body: ready, status: 200)
        open.apply(route: .detail(21), body: ready, status: 200)
        XCTAssertEqual(open.page.phase, .some(.loading))
        open.apply(route: .list, body: ready, status: 200)
        guard case .ready(let rows)? = open.page.phase else { return XCTFail() }
        XCTAssertEqual(rows.map(\.id), [21])
        XCTAssertEqual(open.page.documentCountText, dash)
    }

    func testDebugFixtureProjectsUsableRowsWithoutInventingACount() throws {
        #if DEBUG
        let body = Data("{\"code\":200,\"data\":\(SocialAccountSyntheticFixtures.informationJSON)}".utf8)
        let page = PlayGuideInformationListPage.project(capabilityPresent: true, body: body, status: 200)
        guard case .ready(let rows)? = page.phase else { return XCTFail("\(String(describing: page.phase))") }
        XCTAssertEqual(rows.map(\.id), [91, 92])
        XCTAssertEqual(page.documentCountText, dash)
        XCTAssertNil(page.documentCount.literal)
        #else
        throw XCTSkip("DEBUG fixture is compiled out")
        #endif
    }
}
