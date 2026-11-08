import XCTest
@testable import QuestifyCore

final class Wire2MerchantTopicDetailFactsTests: XCTestCase {
    private func topic(_ json: String) throws -> MerchantContentValue {
        try JSONDecoder().decode(MerchantContentValue.self, from: Data(json.utf8))
    }
    func testStatBarCellsAppearOnlyWhenPresent() throws {
        let facts = MerchantTopicDetailFacts(topic: try topic(#"{"totalTime":9000,"startDate":"2026-07-04 00:00:00","endDate":"2026-07-29","totalMileage":12,"averageRating":4.8,"registrationMerchantCount":3}"#))
        XCTAssertEqual(facts.statBar, [.init(kind: .hours, value: "2.5+"), .init(kind: .openRange, value: "7.4-7.29"), .init(kind: .mileage, value: "12")])
        XCTAssertTrue(MerchantTopicDetailFacts(topic: try topic("{}")).statBar.isEmpty)
        XCTAssertTrue(MerchantTopicDetailFacts(topic: try topic(#"{"totalTime":100,"startDate":"2026-07-04"}"#)).statBar.isEmpty)
    }
    func testWholeHoursHaveNoDecimal() throws {
        XCTAssertEqual(MerchantTopicDetailFacts(topic: try topic(#"{"totalTime":7200}"#)).statBar, [.init(kind: .hours, value: "2+")])
    }
    func testTemplatesAndChapterMeta() throws {
        let json = #"{"chaptersList":[{"name":"A","totalTime":3600,"templateCount":2,"nodes":[{"name":"N1","imgUrl":"https://x.test/a.jpg;http://x.test/b.jpg, https://x.test/c.jpg","cmsMemberTemplate":{"id":7,"title":"T","imgUrl":"","players":"2-4","duration":0}},{"address":"Addr"}]},{"name":"B","locationCount":4}]}"#
        let facts = MerchantTopicDetailFacts(topic: try topic(json))
        XCTAssertEqual(facts.nodeTemplates.count, 1)
        XCTAssertEqual(facts.nodeTemplates[0].durationMinutes, 0)
        XCTAssertNil(facts.nodeTemplates[0].imageURL)
        XCTAssertEqual(facts.chapters[0].nodeCount, 2)
        XCTAssertEqual(facts.chapters[0].playCount, 2)
        XCTAssertEqual(facts.chapters[0].totalSeconds, 3600)
        XCTAssertEqual(facts.chapters[0].nodes[0].images.map(\.absoluteString), ["https://x.test/a.jpg", "https://x.test/c.jpg"])
        XCTAssertEqual(facts.chapters[0].nodes[1].title, "Addr")
        XCTAssertEqual(facts.chapters[1].nodeCount, 4)
        XCTAssertNil(facts.chapters[1].totalSeconds)
        XCTAssertFalse(MerchantTopicChapterFacts(name: nil, totalSeconds: nil, nodeCount: 0, playCount: 0, nodes: []).hasMeta)
    }
}
