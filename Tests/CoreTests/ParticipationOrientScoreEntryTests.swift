import XCTest
@testable import QuestifyCore

final class ParticipationOrientScoreEntryTests: XCTestCase {
    func testTopicRegistrationKeepsMatchingTopicAndSelfPlayActivity() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"cmsTopic":{"id":91,"productType":1}}
        """#)
        XCTAssertEqual(detail.topicID, 91)
        XCTAssertEqual(detail.activityID, 0)
        XCTAssertEqual(detail.productType, 1)
        XCTAssertEqual(ParticipationOrientScoreEntry.request(detail, accountID: 7)?.topicID, 91)
        XCTAssertEqual(ParticipationOrientScoreEntry.request(detail, accountID: 7)?.activityID, 0)
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: 8))
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: nil))
        XCTAssertTrue(ParticipationOrientScoreEntry.canAskSession(detail))
    }

    func testStringTopicIdMatchesIntegerOwnerAndStringProductType() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"cmsTopic":{"id":"91","productType":"1"}}
        """#)
        XCTAssertEqual(detail.topicID, 91)
        XCTAssertEqual(detail.activityID, 0)
        XCTAssertEqual(detail.productType, 1)
        let raw = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"id":"71","ownerType":"1","ownerId":"91","cmsTopic":{"id":"91","productType":"1"}}"#.utf8))
        let keys = ParticipationOrientScoreEntry.keys(raw: raw, registrationID: 71)
        XCTAssertEqual(keys.topicID, 91)
        XCTAssertEqual(keys.activityID, 0)
        XCTAssertEqual(keys.productType, 1)
    }

    func testMismatchedTopicIdsAreNotRepaired() throws {
        let swapped = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"cmsTopic":{"id":92,"productType":1}}
        """#)
        XCTAssertNil(swapped.topicID)
        XCTAssertNil(swapped.activityID)
        XCTAssertEqual(swapped.productType, 1)
        XCTAssertNil(ParticipationOrientScoreEntry.request(swapped, accountID: 7))

        let ownerOnly = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"cmsTopic":{"name":"Synthetic","productType":1}}
        """#)
        XCTAssertNil(ownerOnly.topicID)
        XCTAssertNil(ownerOnly.activityID)
        XCTAssertNotEqual(ownerOnly.topicID, 71)
        XCTAssertNotEqual(ownerOnly.topicID, 91)
    }

    func testRegistrationIdIsNotATopicId() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":71,"cmsTopic":{"productType":1}}
        """#)
        XCTAssertNil(detail.topicID)
        XCTAssertNil(detail.activityID)
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: 7))
    }

    func testConflictingTopLevelTopicIdClearsTheTopic() throws {
        let conflict = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"topicId":3,"cmsTopic":{"id":91,"productType":1}}
        """#)
        XCTAssertNil(conflict.topicID)
        XCTAssertNil(conflict.activityID)
        let zero = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"topicId":0,"cmsTopic":{"id":91,"productType":1}}
        """#)
        XCTAssertEqual(zero.topicID, 91)
        XCTAssertEqual(zero.activityID, 0)
    }

    func testActivityRegistrationUsesActivityTopicIdNotZero() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"ownerType":2,"ownerId":55,"cmsActivity":{"id":55,"topicId":91,"productType":1},"cmsTopic":{"id":91,"productType":2}}
        """#)
        XCTAssertEqual(detail.topicID, 91)
        XCTAssertEqual(detail.activityID, 55)
        XCTAssertEqual(detail.productType, 1)
        XCTAssertEqual(ParticipationOrientScoreEntry.request(detail, accountID: 7)?.activityID, 55)
    }

    func testActivityWithoutTopicIdDoesNotInventOne() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"ownerType":2,"ownerId":55,"cmsActivity":{"id":55,"productType":1}}
        """#)
        XCTAssertNil(detail.topicID)
        XCTAssertEqual(detail.activityID, 55)
        XCTAssertEqual(detail.productType, 1)
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: 7))
        XCTAssertFalse(ParticipationOrientScoreEntry.canAskSession(detail))
    }

    func testActivityIdThatDoesNotMatchOwnerIsDropped() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"ownerType":2,"ownerId":55,"cmsActivity":{"id":56,"topicId":91,"productType":1}}
        """#)
        XCTAssertNil(detail.topicID)
        XCTAssertNil(detail.activityID)
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: 7))
    }

    func testProductTypeTwoAndNonIntegersStayOffTheScoreRead() throws {
        let free = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"cmsTopic":{"id":91,"productType":2}}
        """#)
        XCTAssertEqual(free.topicID, 91)
        XCTAssertEqual(free.activityID, 0)
        XCTAssertEqual(free.productType, 2)
        XCTAssertNil(ParticipationOrientScoreEntry.request(free, accountID: 7))
        XCTAssertFalse(ParticipationOrientScoreEntry.canAskSession(free))

        let flag = try decode(#"""
        {"id":71,"memberId":7,"ownerType":1,"ownerId":91,"cmsTopic":{"id":91,"productType":true}}
        """#)
        XCTAssertNil(flag.productType)
        XCTAssertNil(ParticipationOrientScoreEntry.request(flag, accountID: 7))
    }

    func testPayloadWithoutIdsLeavesTheLoaderNil() throws {
        let detail = try decode(#"""
        {"id":71,"memberId":7,"registrationStatus":2,"paymentStatus":2}
        """#)
        XCTAssertNil(detail.topicID)
        XCTAssertNil(detail.activityID)
        XCTAssertNil(detail.productType)
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: 7))
        XCTAssertFalse(ParticipationOrientScoreEntry.canAskSession(detail))
    }

    func testMissingMemberKeepsTheEntryHidden() throws {
        let detail = try decode(#"""
        {"id":71,"ownerType":1,"ownerId":91,"cmsTopic":{"id":91,"productType":1}}
        """#)
        XCTAssertEqual(detail.topicID, 91)
        XCTAssertNil(ParticipationOrientScoreEntry.request(detail, accountID: 7))
        XCTAssertFalse(ParticipationOrientScoreEntry.canAskSession(detail))
    }

    private func decode(_ json: String) throws -> ParticipationDetail {
        try JSONDecoder().decode(ParticipationDetail.self, from: Data(json.utf8))
    }
}
