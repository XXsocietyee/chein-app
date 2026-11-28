import XCTest
@testable import QuestifyCore

/// Page-ready contract for pages/activity/detail/index. Synthetic JSON only.
final class ActivityDetailPageReadyTests: XCTestCase {
    private func detail(_ json: String) throws -> ActivityDetail {
        let access = try JSONDecoder().decode(ActivityDetailAccess.self, from: Data(json.utf8))
        guard case .allowed(let detail) = access else {
            XCTFail("Expected an allowed activity")
            throw APIError.malformedResponse
        }
        return detail
    }

    func testCapabilityStaysOnTheLiveReadAndKeepsWritesHidden() {
        XCTAssertEqual(ActivityDetailPageCapability.readPath, SignedInContentDetailReadRoute.activity.path)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: ActivityDetailPageCapability.readPath), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/activity/detail"), .liveInProduction) // live on TEST r2 (club gaps)
        XCTAssertFalse(ChinaReviewedRouteCapability.isHiddenFromChinaReviewed("/api/club/activity/detail"))
        XCTAssertFalse(ActivityDetailPageCapability.showsMerchantChoice)
        XCTAssertFalse(ActivityDetailPageCapability.paymentEnabled)
        XCTAssertFalse(ActivityDetailPageCapability.payoutEnabled)
        XCTAssertFalse(ActivityDetailPageCapability.withdrawalEnabled)
        XCTAssertFalse(ActivityDetailPageCapability.virtualGoodsEnabled)
        XCTAssertNotEqual(ActivityDetailPageCapability.readPath, "api/club/activity/detail")
    }

    func testUnauthorizedActivityReadAsksForSignIn() {
        XCTAssertTrue(ActivityDetailPageModel.readFailedBecauseSignedOut(APIError.unauthorized))
        XCTAssertFalse(ActivityDetailPageModel.readFailedBecauseSignedOut(APIError.malformedResponse))
        XCTAssertFalse(ActivityDetailPageModel.readFailedBecauseSignedOut(CancellationError()))
    }

    func testLoadingAndFailureDoNotInventCounts() throws {
        let access = ActivityDetailAccess.allowed(try detail(ActivityDetailPageFixtureData.readyJSON))
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: true, failed: false, access: nil), .loading)
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: true, failed: true, access: access), .loading)
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: true, failed: false, access: access), .loading)
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: false, failed: true, access: access), .error)
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: false, failed: false, access: nil), .loading)
        XCTAssertEqual(ActivityDetailPageModel.countText(nil), "—")
        XCTAssertEqual(ActivityDetailPageModel.countText(0), "0")
        XCTAssertEqual(ActivityDetailPageModel.countText(7), "7")
        XCTAssertEqual(ActivityDetailPageModel.decimalText(nil), "—")
        XCTAssertEqual(ActivityDetailPageModel.decimalText(.zero), "0")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(nil), "—")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(.nan), "—")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(.infinity), "—")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(-1), "—")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(0), "0")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(0.04), "—")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(1.5), "1.5")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(90), "90")
        XCTAssertEqual(ActivityDetailPageModel.measurementText(4.2), "4.2")
        XCTAssertThrowsError(try JSONDecoder().decode(ActivityDetailAccess.self, from: Data(ActivityDetailPageFixtureData.errorEnvelopeJSON.utf8)))
    }

    func testReadyFixtureKeepsKnownNumbers() throws {
        let detail = try detail(ActivityDetailPageFixtureData.readyJSON)
        let phase = ActivityDetailPageModel.phase(loading: false, failed: false, access: .allowed(detail))
        guard case .ready(let snapshot) = phase else {
            return XCTFail("Expected a ready activity")
        }
        XCTAssertEqual(snapshot.activityID, 101)
        XCTAssertEqual(snapshot.nameText, "Fixture activity")
        XCTAssertEqual(snapshot.categoryText, "Fixture walk")
        XCTAssertEqual(snapshot.meetingPoint, .named("Fixture meeting point"))
        XCTAssertEqual(snapshot.meetingPointText, "Fixture meeting point")
        XCTAssertEqual(snapshot.registeredCountText, "7")
        XCTAssertEqual(snapshot.reviewCountText, "2")
        XCTAssertEqual(snapshot.averageRatingText, "4.2")
        XCTAssertFalse(snapshot.reviewsConfirmedEmpty)
        XCTAssertEqual(snapshot.tickets.map(\.priceText), ["12.5"])
        XCTAssertEqual(snapshot.tickets.map(\.inventoryText), ["3"])
        XCTAssertEqual(snapshot.tickets.map(\.soldOut), [false])
        XCTAssertEqual(snapshot.plays.map(\.titleText), ["Fixture play"])
        XCTAssertEqual(snapshot.plays.map(\.playersText), ["4"])
        XCTAssertEqual(snapshot.plays.map(\.durationText), ["90"])
        XCTAssertFalse(snapshot.ticketsEmpty)
    }

    func testUnknownFixtureIsAnEmDashAndNotZero() throws {
        let detail = try detail(ActivityDetailPageFixtureData.unknownJSON)
        XCTAssertNil(detail.signUpFlag)
        XCTAssertNil(detail.people.registrationCount)
        XCTAssertNil(detail.reviews.commentCount)
        XCTAssertNil(detail.reviews.averageRating)
        let phase = ActivityDetailPageModel.phase(loading: false, failed: false, access: .allowed(detail))
        guard case .ready(let snapshot) = phase else {
            return XCTFail("A named activity with a ticket is ready, with unknown numbers")
        }
        XCTAssertEqual(snapshot.registeredCountText, "—")
        XCTAssertEqual(snapshot.reviewCountText, "—")
        XCTAssertEqual(snapshot.averageRatingText, "—")
        XCTAssertEqual(snapshot.categoryText, "—")
        XCTAssertEqual(snapshot.meetingPoint, .unconfirmed)
        XCTAssertEqual(snapshot.meetingPointText, "—")
        XCTAssertEqual(snapshot.tickets.map(\.priceText), ["—"])
        XCTAssertEqual(snapshot.tickets.map(\.inventoryText), ["—"])
        XCTAssertEqual(snapshot.tickets.map(\.soldOut), [false])
        XCTAssertEqual(snapshot.plays.map(\.titleText), ["—"])
        XCTAssertEqual(snapshot.plays.map(\.playersText), ["—"])
        XCTAssertEqual(snapshot.plays.map(\.durationText), ["—"])
        for text in [snapshot.registeredCountText, snapshot.reviewCountText, snapshot.averageRatingText,
                     snapshot.tickets[0].priceText, snapshot.tickets[0].inventoryText, snapshot.plays[0].durationText] {
            XCTAssertNotEqual(text, "0")
        }
    }

    func testExplicitZeroStaysZero() throws {
        let detail = try detail(ActivityDetailPageFixtureData.zeroJSON)
        let phase = ActivityDetailPageModel.phase(loading: false, failed: false, access: .allowed(detail))
        guard case .ready(let snapshot) = phase else {
            return XCTFail("A known zero is a fact")
        }
        XCTAssertEqual(snapshot.registeredCountText, "0")
        XCTAssertEqual(snapshot.reviewCountText, "0")
        XCTAssertEqual(snapshot.averageRatingText, "0")
        XCTAssertTrue(snapshot.reviewsConfirmedEmpty)
        XCTAssertEqual(snapshot.tickets.map(\.priceText), ["0"])
        XCTAssertEqual(snapshot.tickets.map(\.inventoryText), ["0"])
        XCTAssertEqual(snapshot.tickets.map(\.soldOut), [true])
        XCTAssertEqual(snapshot.plays.map(\.playersText), ["0"])
        XCTAssertEqual(snapshot.plays.map(\.durationText), ["0"])
        XCTAssertFalse(ActivityDetailPageModel.isEmpty(detail))
    }

    func testEmptyShellAndBlankTitle() throws {
        let empty = try detail(ActivityDetailPageFixtureData.emptyJSON)
        XCTAssertTrue(ActivityDetailPageModel.isEmpty(empty))
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: false, failed: false, access: .allowed(empty)), .empty)
        XCTAssertEqual(ActivityDetailPageModel.project(empty).registeredCountText, "—")
        XCTAssertEqual(ActivityDetailPageModel.project(empty).reviewCountText, "—")
        XCTAssertEqual(ActivityDetailPageModel.project(empty).averageRatingText, "—")
        XCTAssertTrue(ActivityDetailPageModel.project(empty).ticketsEmpty)

        let blank = try detail(ActivityDetailPageFixtureData.blankNameJSON)
        let phase = ActivityDetailPageModel.phase(loading: false, failed: false, access: .allowed(blank))
        guard case .ready(let snapshot) = phase else {
            return XCTFail("A blank title with a ticket stays ready")
        }
        XCTAssertEqual(snapshot.nameText, "—")
        XCTAssertEqual(snapshot.tickets.map(\.priceText), ["1"])
        XCTAssertNotEqual(snapshot.nameText, "0")
    }

    func testClubGateHidesTheActivityBody() throws {
        let access = try JSONDecoder().decode(ActivityDetailAccess.self, from: Data(ActivityDetailPageFixtureData.clubGateJSON.utf8))
        XCTAssertEqual(ActivityDetailPageModel.phase(loading: false, failed: false, access: access),
                       .clubRequired(clubID: 9, message: "Synthetic gate"))
    }

    func testDateOnlyActivityStaysReadyWithUnknownCounts() throws {
        let detail = try detail(#"{"id":101,"name":"Fixture activity","startDate":"2026-10-20"}"#)
        let phase = ActivityDetailPageModel.phase(loading: false, failed: false, access: .allowed(detail))
        guard case .ready(let snapshot) = phase else {
            return XCTFail("A start date is enough to leave the empty shell")
        }
        XCTAssertEqual(snapshot.registeredCountText, "—")
        XCTAssertEqual(snapshot.meetingPointText, "—")
        XCTAssertTrue(snapshot.ticketsEmpty)
        XCTAssertNotEqual(snapshot.registeredCountText, "0")
    }
}
