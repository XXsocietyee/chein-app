import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RoamFinishAddressTests: XCTestCase {
    private func place(id: Int, name: String, address: String? = nil) throws -> RoamPlace {
        var fields = "\"id\":\(id),\"name\":\"\(name)\""
        if let address { fields += ",\"address\":\"\(address)\"" }
        return try JSONDecoder().decode(RoamPlace.self, from: Data("{\(fields)}".utf8))
    }

    func testSelectedNameWinsAndAddressFillsAnEmptyName() throws {
        let lantern = try place(id: 7, name: "Lantern", address: "Alley")
        let gate = try place(id: 3, name: "  ", address: "North Gate")
        XCTAssertEqual(RoamFinishAddress.text(phase: .finishing, places: [gate, lantern], confirmedPOIIDs: [3, 7], chinese: false), "Lantern")
        XCTAssertEqual(RoamFinishAddress.text(phase: .active, places: [gate], confirmedPOIIDs: [3], chinese: true), "North Gate")
        let blank = try place(id: 8, name: " ", address: " ")
        XCTAssertEqual(RoamFinishAddress.text(phase: .active, places: [blank], confirmedPOIIDs: [8], chinese: false), "Current location")
    }

    func testLocationSentencesAndUnknownDash() {
        XCTAssertEqual(RoamFinishAddress.text(phase: .acquiring, places: [], confirmedPOIIDs: [], chinese: true), "当前位置")
        XCTAssertEqual(RoamFinishAddress.text(phase: .paused, places: [], confirmedPOIIDs: [], chinese: false), "Current location")
        XCTAssertEqual(RoamFinishAddress.text(phase: .ready, places: [], confirmedPOIIDs: [], chinese: true), "尚未开启定位")
        XCTAssertEqual(RoamFinishAddress.text(phase: .locationDenied, places: [], confirmedPOIIDs: [], chinese: false), "Location is off")
        XCTAssertEqual(RoamFinishAddress.unknown, "—")
        XCTAssertEqual(RoamFinishAddress.text(phase: .unavailable, places: [], confirmedPOIIDs: [], chinese: true), RoamFinishAddress.unknown)
        XCTAssertEqual(RoamFinishAddress.text(phase: .recoveryRequired, places: [], confirmedPOIIDs: [], chinese: false), "—")
        XCTAssertEqual(RoamFinishAddress.text(phase: .finished, places: [], confirmedPOIIDs: [7], chinese: false), "—")
    }
}

@MainActor final class RoamPlaceReviewAttemptTests: XCTestCase {
    func testUnknownStaysOnTheSameIdAndADifferentDraftDoesNotSend() {
        var minted = 0
        var attempt = RoamPlaceReviewAttempt.idle
        let first = attempt.begin(stars: 4, text: "  nice  ", makeRequestID: { minted += 1; return "req-\(minted)" })
        attempt = first.0
        XCTAssertEqual(first.1, .send(requestID: "req-1", stars: 4, text: "nice"))
        XCTAssertFalse(attempt.locked)
        let invalid = attempt.begin(stars: 0, text: "x", makeRequestID: { minted += 1; return "req-\(minted)" })
        XCTAssertEqual(invalid.0.requestID, "req-1")
        XCTAssertEqual(invalid.1, .hold)
        XCTAssertEqual(minted, 1)
        attempt = attempt.resolve(.unknown)
        XCTAssertTrue(attempt.locked)
        XCTAssertEqual(attempt.requestID, "req-1")
        let retry = attempt.begin(stars: 4, text: "nice", makeRequestID: { minted += 1; return "req-\(minted)" })
        XCTAssertEqual(retry.1, .send(requestID: "req-1", stars: 4, text: "nice"))
        XCTAssertEqual(minted, 1)
        let other = attempt.begin(stars: 5, text: "other", makeRequestID: { minted += 1; return "req-\(minted)" })
        XCTAssertEqual(other.0, attempt)
        XCTAssertEqual(other.1, .hold)
        XCTAssertEqual(minted, 1)
        XCTAssertEqual(attempt.resolve(.published), .idle)
        XCTAssertEqual(attempt.resolve(.rejected), .idle)
        XCTAssertEqual(attempt.resolve(.notSent), .idle)
        let long = RoamPlaceReviewAttempt.idle.begin(stars: 1, text: String(repeating: "字", count: 201), makeRequestID: { "nope" })
        XCTAssertEqual(long.1, .hold)
        XCTAssertNil(long.0.requestID)
    }

    func testLockStoreKeepsOnlyALockedAttempt() {
        let locked = RoamPlaceReviewAttempt(requestID: "req-9", stars: 2, text: "kept", locked: true)
        RoamPlaceReviewLockStore.write(accountID: 4, poiID: 7, locked)
        XCTAssertEqual(RoamPlaceReviewLockStore.read(accountID: 4, poiID: 7), locked)
        XCTAssertEqual(RoamPlaceReviewLockStore.read(accountID: 4, poiID: 8), .idle)
        RoamPlaceReviewLockStore.write(accountID: 4, poiID: 7, .idle)
        XCTAssertEqual(RoamPlaceReviewLockStore.read(accountID: 4, poiID: 7), .idle)
    }
}

final class RoamPlaceCommentClientTests: XCTestCase {
    private final class Script: HTTPTransport {
        var requests: [URLRequest] = []
        var outcome: Result<(Data, Int), Error>
        init(_ outcome: Result<(Data, Int), Error>) { self.outcome = outcome }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try outcome.get()
        }
    }

    private func client(_ script: Script) throws -> RoamPlaceCommentClient {
        let configuration = try APIConfiguration(baseURL: URL(string: "https://chengyin.example")!)
        return RoamPlaceCommentClient(configuration: configuration, transport: script)
    }

    private func body(_ request: URLRequest) -> String { String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "" }

    func testListUsesOwnerTypeFourAndDoesNotTreatAFailedReadAsEmpty() async throws {
        XCTAssertFalse(RoamPlaceCommentClient.routeMarkedLive)
        let payload = #"{"code":200,"data":{"rows":[{"id":9,"memberId":4,"memberNickname":"Ada","rating":5,"contents":"nice","createTime":"2026-01-02 10:00:00"},{"id":10,"contents":"  "}]}}"#
        let script = Script(.success((Data(payload.utf8), 200)))
        let loaded = try await client(script).list(poiID: 7, token: "token-1")
        guard case .loaded(let rows) = loaded else { return XCTFail("\(loaded)") }
        XCTAssertEqual(rows, [RoamPlaceCommentClient.Row(id: "9", memberID: 4, name: "Ada", timeText: "2026-01-02", stars: 5, text: "nice")])
        let sent = try XCTUnwrap(script.requests.first)
        XCTAssertTrue(sent.url?.path.hasSuffix("/api/comment/list") == true)
        let text = body(sent)
        XCTAssertTrue(text.contains("name=\"owner_type\""))
        XCTAssertTrue(text.contains("\r\n4\r\n"))
        XCTAssertTrue(text.contains("name=\"owner_id\""))
        XCTAssertTrue(text.contains("name=\"pageSize\""))
        let broken = Script(.success((Data(#"{"code":200,"data":{}}"#.utf8), 200)))
        let unavailable = try await client(broken).list(poiID: 7, token: "token-1")
        XCTAssertEqual(unavailable, .unavailable)
        let denied = Script(.success((Data(), 401)))
        XCTAssertEqual(try await client(denied).list(poiID: 7, token: "token-1"), .unauthorized)
        let offline = Script(.failure(URLError(.cannotConnectToHost)))
        XCTAssertEqual(try await client(offline).list(poiID: 7, token: "token-1"), .unavailable)
    }

    func testPublishKeepsTheRequestIdAndSendsNoMoney() async throws {
        let script = Script(.failure(URLError(.cannotConnectToHost)))
        let unknown = try await client(script).publish(poiID: 7, stars: 4, text: "nice", requestID: "req-1", token: "token-1")
        XCTAssertEqual(unknown, .unknown)
        let text = body(try XCTUnwrap(script.requests.first))
        XCTAssertTrue(text.contains("name=\"requestId\""))
        XCTAssertTrue(text.contains("req-1"))
        XCTAssertTrue(text.contains("name=\"reply_id\""))
        for banned in ["price", "pay", "amount", "quote"] {
            XCTAssertFalse(text.lowercased().contains(banned), banned)
        }
        let rejected = Script(.success((Data(#"{"code":400,"msg":"nope"}"#.utf8), 200)))
        XCTAssertEqual(try await client(rejected).publish(poiID: 7, stars: 4, text: "nice", requestID: "req-1", token: "token-1"), .rejected("nope"))
        let published = Script(.success((Data(#"{"code":200}"#.utf8), 200)))
        XCTAssertEqual(try await client(published).publish(poiID: 7, stars: 4, text: "nice", requestID: "req-1", token: "token-1"), .published)
        let undecodable = Script(.success((Data("not-json".utf8), 200)))
        XCTAssertEqual(try await client(undecodable).publish(poiID: 7, stars: 4, text: "nice", requestID: "req-1", token: "token-1"), .unknown)
        let skipped = Script(.success((Data(#"{"code":200}"#.utf8), 200)))
        XCTAssertEqual(try await client(skipped).publish(poiID: 7, stars: 4, text: "nice", requestID: "bad id", token: "token-1"), .notSent)
        XCTAssertTrue(skipped.requests.isEmpty)
    }
}
