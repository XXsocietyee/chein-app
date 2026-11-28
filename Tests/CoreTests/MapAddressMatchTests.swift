import XCTest
@testable import QuestifyCore

final class MapAddressMatchTests: XCTestCase {
    func testEmptyQueryMatchesAndPinyinIsPrefixOnly() {
        XCTAssertTrue(MapAddressMatch.matches(name: "徐汇滨江", address: "龙腾大道", pinyin: "xuhuibinjiang", initials: "xhbj", query: " "))
        XCTAssertTrue(MapAddressMatch.matches(name: "徐汇滨江", address: nil, pinyin: nil, initials: nil, query: "滨江"))
        XCTAssertTrue(MapAddressMatch.matches(name: "A", address: "龙腾大道", pinyin: nil, initials: nil, query: "龙腾"))
        XCTAssertFalse(MapAddressMatch.matches(name: "徐汇滨江", address: "龙腾大道", pinyin: "xuhuibinjiang", initials: "xhbj", query: "w"))
        XCTAssertTrue(MapAddressMatch.matches(name: "徐汇滨江", address: nil, pinyin: "xuhuibinjiang", initials: "xhbj", query: "XUHUI"))
        XCTAssertTrue(MapAddressMatch.matches(name: "徐汇滨江", address: nil, pinyin: "xuhuibinjiang", initials: "xhbj", query: "XHBJ"))
        XCTAssertFalse(MapAddressMatch.matches(name: "徐汇滨江", address: nil, pinyin: "xuhuibinjiang", initials: "xhbj", query: "hbj"))
        XCTAssertFalse(MapAddressMatch.matches(name: "徐汇滨江", address: nil, pinyin: "", initials: "", query: "x"))
        XCTAssertFalse(MapAddressMatch.matches(name: "徐汇滨江", address: nil, pinyin: nil, initials: nil, query: "x"))
    }

    func testRouteNodeKeepsPinyinWhenPresentAndDropsMalformed() throws {
        let full = try JSONDecoder().decode(RoamRouteNode.self, from: Data(#"{"id":1,"addressName":"店","latitude":31.2,"longitude":121.4,"namePinyin":"dian","nameInitials":"d"}"#.utf8))
        XCTAssertEqual(full.namePinyin, "dian")
        XCTAssertEqual(full.nameInitials, "d")
        let missing = try JSONDecoder().decode(RoamRouteNode.self, from: Data(#"{"id":2,"latitude":31.2,"longitude":121.4}"#.utf8))
        XCTAssertNil(missing.namePinyin)
        XCTAssertNil(missing.nameInitials)
        let bad = try JSONDecoder().decode(RoamRouteNode.self, from: Data(#"{"id":3,"latitude":31.2,"longitude":121.4,"namePinyin":{"x":1},"nameInitials":"  "}"#.utf8))
        XCTAssertNil(bad.namePinyin)
        XCTAssertNil(bad.nameInitials)
    }
}
