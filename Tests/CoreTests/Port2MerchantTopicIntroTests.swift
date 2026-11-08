import XCTest
@testable import QuestifyCore

final class Port2MerchantTopicIntroTests: XCTestCase {
    private func topic(_ json: String) throws -> MerchantContentValue {
        try JSONDecoder().decode(MerchantContentValue.self, from: Data(json.utf8))
    }
    func testIncludesMirrorSourceOrderAndOmitMissingCounts() throws {
        let value = try topic(#"{"subtitle":"null","description":" Walk ","totalChapterCount":3,"locationCount":0,"templateCount":5,"audioUrl":"a.mp3","audioDuration":185,"finishMedalName":"","finishMedalImg":"m.png","completeRewardCouponId":9}"#)
        let intro = MerchantTopicIntro(topic: value)
        XCTAssertNil(intro.subtitle)
        XCTAssertEqual(intro.introduction, "Walk")
        XCTAssertEqual(intro.includes, [.chapters(3), .plays(5), .audio(minutes: 3), .medal(name: nil), .completionCoupon])
    }
    func testEmptyTopicIsEmptyAndAudioWithoutDurationHasNoMinutes() throws {
        XCTAssertTrue(MerchantTopicIntro(topic: try topic("{}")).isEmpty)
        let intro = MerchantTopicIntro(topic: try topic(#"{"audioUrl":"a.mp3"}"#))
        XCTAssertEqual(intro.includes, [.audio(minutes: nil)])
    }
}
