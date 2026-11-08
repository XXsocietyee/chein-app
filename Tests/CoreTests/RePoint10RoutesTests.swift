import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore
#elseif canImport(Core)
@testable import Core
#endif

/// SYNTHETIC fixtures derived from ApiTopicController.topicInfo (form `id`), ApiImController.block
/// (form `target_member_id`), ApiLoginController.smsSend (form `phone`). NOT COMPILED / NOT RUN.
final class RePoint10RoutesTests: XCTestCase {
    private let base = URL(string: "https://example.invalid")!

    func testTableCoversAll29RoutesOnce() {
        XCTAssertEqual(RePoint10Routes.table.count, 29)
        XCTAssertEqual(Set(RePoint10Routes.table.map(\.iosPath)).count, 29)
    }
    func testCounts() {
        let c = Dictionary(grouping: RePoint10Routes.table, by: \.status).mapValues(\.count)
        XCTAssertEqual(c[.repointed], 3); XCTAssertEqual(c[.needsOwner], 1); XCTAssertEqual(c[.trueGap], 25)
    }
    func testGapRoutesProduceNoRequest() {
        XCTAssertNil(RePoint10Routes.formRequest(baseURL: base, iosPath: "/api/workshop/owned", fields: ["id": "1"], token: "t"))
        XCTAssertNil(RePoint10Routes.formRequest(baseURL: base, iosPath: "/api/us/auth/apple/exchange", fields: ["id": "1"], token: "t"))
    }
    func testTopicDetailRequestIsFormInfoToUser() throws {
        let r = try XCTUnwrap(RePoint10Routes.formRequest(baseURL: base, iosPath: "/api/topic/detail", fields: ["id": "12"], token: "tok"))
        XCTAssertEqual(r.url?.path, "/api/topic/info-to-user"); XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(String(data: r.httpBody ?? Data(), encoding: .utf8), "id=12")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
    }
    func testBlockRequestIsImBlock() throws {
        let r = try XCTUnwrap(RePoint10Routes.formRequest(baseURL: base, iosPath: "api/ugc/block", fields: ["target_member_id": "7"], token: "tok"))
        XCTAssertEqual(r.url?.path, "/api/im/block")
        XCTAssertNil(RePoint10Routes.formRequest(baseURL: base, iosPath: "/api/ugc/block", fields: ["target_member_id": "0"], token: "tok"))
    }
    func testSmsIsAnonymousAndNeedsPhone() throws {
        let r = try XCTUnwrap(RePoint10Routes.formRequest(baseURL: base, iosPath: "/api/user/sms/send", fields: ["phone": "13800000000"], token: "tok"))
        XCTAssertEqual(r.url?.path, "/api/sms/send"); XCTAssertNil(r.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(RePoint10Routes.formRequest(baseURL: base, iosPath: "/api/user/sms/send", fields: ["phone": ""], token: "tok"))
    }
    func testDecodeTopicDetailFailsClosed() {
        XCTAssertThrowsError(try RePoint10Routes.decodeTopicDetail(Data(#"{"code":200,"msg":"ok"}"#.utf8)))   // data key omitted
        XCTAssertThrowsError(try RePoint10Routes.decodeTopicDetail(Data(#"{"code":500,"msg":"参数不合规"}"#.utf8)))
        XCTAssertThrowsError(try RePoint10Routes.decodeTopicDetail(Data(#"{"code":401}"#.utf8)))
    }
}
