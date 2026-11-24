import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class ParticipantAddressListPageTests: XCTestCase {
    private func facts(_ json: String) throws -> ProfileParticipantListFacts {
        try JSONDecoder().decode(ProfileParticipantListFacts.self, from: Data(json.utf8))
    }

    private func service(_ transport: ProfileTestTransport) throws -> ProfileService {
        ProfileService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/fixture/")!), transport: transport)
    }

    func testMissingAndNullTotalsStayEmDashWhileLiteralZeroStaysZero() throws {
        let missing = try facts(#"{"rows":[{"id":5,"fullName":"Fixture"}]}"#)
        XCTAssertNil(missing.total)
        let missingPage = ProfileParticipantListCoordinator.project(list: .success(missing))
        XCTAssertEqual(missingPage.phase, .ready)
        XCTAssertEqual(missingPage.totalText, "—")
        XCTAssertEqual(missingPage.totalText, ProfileParticipantListPage.unknownMark)
        XCTAssertEqual(ProfileParticipantListPage.unknownMark.unicodeScalars.map(\.value), [0x2014])
        XCTAssertNotEqual(missingPage.totalText, "0")
        XCTAssertNotEqual(missingPage.totalText, String(missing.rows.count))
        XCTAssertEqual(missingPage.cards.map(\.id), [5])
        XCTAssertFalse(missingPage.isRefreshing)
        XCTAssertTrue(missingPage.showsAdd)

        let nullTotal = try facts(#"{"rows":[],"total":null}"#)
        let nullPage = ProfileParticipantListCoordinator.project(list: .success(nullTotal))
        XCTAssertEqual(nullPage.phase, .empty)
        XCTAssertNil(nullPage.total)
        XCTAssertEqual(nullPage.totalText, "—")
        XCTAssertNotEqual(nullPage.totalText, "0")
        XCTAssertTrue(nullPage.cards.isEmpty)
        XCTAssertTrue(nullPage.showsAdd)

        let zero = try facts(#"{"rows":[],"total":0}"#)
        let zeroPage = ProfileParticipantListCoordinator.project(list: .success(zero))
        XCTAssertEqual(zeroPage.phase, .empty)
        XCTAssertEqual(zeroPage.total, 0)
        XCTAssertEqual(zeroPage.totalText, "0")

        let zeroBesideRow = try facts(#"{"rows":[{"id":5,"fullName":"Fixture"}],"total":0}"#)
        let beside = ProfileParticipantListCoordinator.project(list: .success(zeroBesideRow))
        XCTAssertEqual(beside.phase, .ready)
        XCTAssertEqual(beside.totalText, "0")
        XCTAssertNotEqual(beside.totalText, "1")
    }

    func testNumericStringAndNegativeTotalAreRejected() throws {
        for json in [#"{"rows":[],"total":"0"}"#, #"{"rows":[],"total":"UNKNOWN"}"#, #"{"rows":[],"total":true}"#, #"{"rows":[],"total":-1}"#] {
            XCTAssertThrowsError(try facts(json), json)
        }
        XCTAssertEqual(try facts(#"{"rows":[],"total":0.0}"#).total, 0)
    }

    func testLoadingErrorAndUnknownDoNotInventZero() throws {
        let loading = ProfileParticipantListCoordinator.project(list: nil)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertNil(loading.total)
        XCTAssertEqual(loading.totalText, "—")
        XCTAssertNotEqual(loading.totalText, "0")
        XCTAssertFalse(loading.showsAdd)
        XCTAssertTrue(loading.cards.isEmpty)

        let cancelled = ProfileParticipantListCoordinator.project(list: .failure(CancellationError()))
        XCTAssertEqual(cancelled.phase, .loading)
        XCTAssertEqual(cancelled.totalText, "—")

        let failed = ProfileParticipantListCoordinator.project(list: .failure(APIError.httpStatus(503)))
        XCTAssertEqual(failed.phase, .error)
        XCTAssertNil(failed.total)
        XCTAssertEqual(failed.totalText, "—")
        XCTAssertNotEqual(failed.totalText, "0")
        XCTAssertFalse(failed.showsAdd)

        let denied = ProfileParticipantListCoordinator.project(list: .failure(ProfileReadFailure(code: 403, message: "Record unavailable")))
        XCTAssertEqual(denied.phase, .error)
        XCTAssertEqual(denied.totalText, "—")

        let unknown = ProfileParticipantListCoordinator.project(list: .failure(APIError.malformedResponse))
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertNil(unknown.total)
        XCTAssertEqual(unknown.totalText, "—")
        XCTAssertNotEqual(unknown.totalText, "0")
        XCTAssertFalse(unknown.showsAdd)
        XCTAssertTrue(unknown.cards.isEmpty)
    }

    func testRefreshKeepsAKnownZeroAndAFirstFailureDoesNot() throws {
        let retained = try facts(#"{"rows":[],"total":0}"#)
        let refreshing = ProfileParticipantListCoordinator.project(list: nil, retained: retained)
        XCTAssertEqual(refreshing.phase, .empty)
        XCTAssertEqual(refreshing.totalText, "0")
        XCTAssertTrue(refreshing.isRefreshing)
        XCTAssertTrue(refreshing.showsAdd)

        let cancelled = ProfileParticipantListCoordinator.project(list: .failure(CancellationError()), retained: retained)
        XCTAssertEqual(cancelled.phase, .empty)
        XCTAssertEqual(cancelled.totalText, "0")
        XCTAssertTrue(cancelled.isRefreshing)

        let failed = ProfileParticipantListCoordinator.project(list: .failure(APIError.httpStatus(503)), retained: retained)
        XCTAssertEqual(failed.phase, .empty)
        XCTAssertEqual(failed.total, 0)
        XCTAssertEqual(failed.totalText, "0")
        XCTAssertFalse(failed.isRefreshing)

        let malformed = ProfileParticipantListCoordinator.project(list: .failure(APIError.malformedResponse), retained: retained)
        XCTAssertEqual(malformed.phase, .empty)
        XCTAssertEqual(malformed.totalText, "0")

        let firstMalformed = ProfileParticipantListCoordinator.project(list: .failure(APIError.malformedResponse))
        XCTAssertEqual(firstMalformed.phase, .unknown)
        XCTAssertEqual(firstMalformed.totalText, "—")
        XCTAssertNotEqual(firstMalformed.totalText, "0")
    }

    func testOutcomeUnknownClearsTheCountToAnEmDash() throws {
        let retained = try facts(#"{"rows":[{"id":5,"fullName":"Fixture","mobilePhone":"00000000000"}],"total":1}"#)
        let page = ProfileParticipantListCoordinator.project(list: .success(retained), retained: retained, outcomeUnknown: true)
        XCTAssertEqual(page.phase, .unknown)
        XCTAssertNil(page.total)
        XCTAssertEqual(page.totalText, "—")
        XCTAssertNotEqual(page.totalText, "0")
        XCTAssertNotEqual(page.totalText, "1")
        XCTAssertTrue(page.cards.isEmpty)
        XCTAssertFalse(page.showsAdd)
        XCTAssertFalse(page.isRefreshing)
    }

    func testCardsKeepTheContractPhoneAndDoNotAddContactFields() throws {
        let decoded = try facts(#"{"rows":[{"id":5,"fullName":"Fixture","mobilePhone":"00000000000","province":"Province City District","detailAddress":"Fixture street"}],"total":1}"#)
        let card = try XCTUnwrap(ProfileParticipantListCoordinator.project(list: .success(decoded)).cards.first)
        XCTAssertEqual(card.fullName, "Fixture")
        XCTAssertEqual(card.mobilePhone, "00000000000")
        XCTAssertEqual(card.phoneText, "00000000000")
        let labels = Set(Mirror(reflecting: card).children.compactMap(\.label))
        XCTAssertEqual(labels, ["id", "fullName", "mobilePhone"])

        let blank = try facts(#"{"rows":[{"id":6,"fullName":"","mobilePhone":"  "}]}"#)
        let blankCard = try XCTUnwrap(ProfileParticipantListCoordinator.project(list: .success(blank)).cards.first)
        XCTAssertEqual(blankCard.fullName, "")
        XCTAssertEqual(blankCard.mobilePhone, "  ")
        XCTAssertEqual(blankCard.phoneText, "—")
        XCTAssertNotEqual(blankCard.phoneText, "0")
        XCTAssertNil(ProfileParticipantListCoordinator.project(list: .success(blank)).total)
    }

    func testParticipantListFactsUsesTheExistingListRoute() async throws {
        let transport = ProfileTestTransport([.json(#"{"code":200,"data":{"rows":[{"id":5,"fullName":"Fixture"}],"total":1}}"#)])
        let facts = try await service(transport).participantListFacts(token: "fixture-token")
        XCTAssertEqual(facts.rows.map(\.id), [5])
        XCTAssertEqual(facts.total, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/fixture/api/user/address/list")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "fixture-token")
        XCTAssertEqual(transport.requests.count, 1)

        let zero = ProfileTestTransport([.json(#"{"code":200,"data":{"rows":[],"total":0}}"#)])
        let empty = try await service(zero).participantListFacts(token: "fixture-token")
        XCTAssertEqual(empty.total, 0)
        XCTAssertEqual(ProfileParticipantListCoordinator.project(list: .success(empty)).totalText, "0")

        let absent = ProfileTestTransport([.json(#"{"code":200,"data":{"rows":[]}}"#)])
        let unknownCount = try await service(absent).participantListFacts(token: "fixture-token")
        XCTAssertNil(unknownCount.total)
        XCTAssertEqual(ProfileParticipantListCoordinator.project(list: .success(unknownCount)).totalText, "—")

        for json in [#"{"code":200,"data":{"rows":[],"total":"0"}}"#, #"{"code":200,"data":{"total":0}}"#, #"{"code":200,"data":{"rows":"wrong"}}"#] {
            let transport = ProfileTestTransport([.json(json)])
            do {
                _ = try await service(transport).participantListFacts(token: "fixture-token")
                XCTFail(json)
            } catch {
                XCTAssertEqual(error as? APIError, .malformedResponse)
                let page = ProfileParticipantListCoordinator.project(list: .failure(APIError.malformedResponse))
                XCTAssertEqual(page.phase, .unknown)
                XCTAssertEqual(page.totalText, "—")
            }
        }
    }

    func testExistingParticipantsReadStillIgnoresAStringTotal() async throws {
        let transport = ProfileTestTransport([.json(#"{"code":200,"data":{"rows":[{"id":5,"fullName":"Fixture"}],"total":"0"}}"#)])
        let rows = try await service(transport).participants(token: "fixture-token")
        XCTAssertEqual(rows.map(\.id), [5])
        XCTAssertEqual(transport.requests.count, 1)
    }
}
