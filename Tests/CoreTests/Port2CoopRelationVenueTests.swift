import XCTest
@testable import QuestifyCore

final class Port2CoopRelationVenueTests: XCTestCase {
    func testClosedVenueHiddenAndFactsProjected() throws {
        let json = #"{"relations":[],"discovery":{"clubs":[],"merchants":[{"id":1,"memberId":9,"name":"A","chargeType":1,"capacity":12,"businessTime":"10:00-22:00","suitActivityTypes":"桌游，剧本杀"},{"id":2,"memberId":10,"name":"B","coopOpen":0}]}}"#
        let value = try JSONDecoder().decode(CoopFlowJSON.self, from: Data(json.utf8))
        let discovery = try CoopRelationDiscovery(value)
        XCTAssertEqual(discovery.merchants.count, 1)
        let row = try XCTUnwrap(discovery.merchants.first)
        XCTAssertEqual(row.hours, "10:00-22:00")
        XCTAssertEqual(row.venueTags, [.paidVenue, .capacity(12)])
        XCTAssertEqual(row.suitText, "桌游 · 剧本杀")
    }
}
