import XCTest
@testable import Questify

@MainActor final class IMReviewAuditReaderTests: XCTestCase {
    private let base = URL(string: "https://example.test/native")!

    func testKnownTaskReadsStatusAndTimelineFromTheApplicantDetail() async throws {
        let body = """
        {"code":200,"data":{"task":{"id":42,"status":1,"bizType":"TOPIC","bizId":7},"timeline":[{"id":9,"action":"SUBMIT","createTime":"2026-11-12 09:00:00","reasonText":"  "},{"id":10,"action":"APPROVE","createTime":"2026-11-12 10:00:00","reasonText":"ok"}],"canRevert":true,"reportCount":3}}
        """
        let wire = Wire(body: Data(body.utf8))
        let record = try await reader(wire).record(taskID: " 42 ")
        XCTAssertEqual(wire.requests.count, 1)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertEqual(request.url?.path, "/native/api/audit/42/detail")
        XCTAssertNil(request.url?.query)
        let locale = Locale(identifier: "en")
        let parsed = try IMReviewAuditDetail.record(json: Data(body.utf8), locale: locale)
        XCTAssertEqual(record, parsed)
        XCTAssertNotEqual(record.statusLabel, IMReviewAuditDetail.unknown)
        XCTAssertEqual(record.timeline.map(\.id), [0, 1])
        XCTAssertEqual(record.timeline.map(\.time), ["2026-11-12 09:00:00", "2026-11-12 10:00:00"])
        XCTAssertEqual(record.timeline.map(\.reason), [nil, "ok"])
        XCTAssertFalse(record.timeline.contains { $0.label == IMReviewAuditDetail.unknown })
        XCTAssertEqual(Set(record.timeline.map(\.label)).count, 2)
    }

    func testUnknownFieldsAreAnEmDashAndAMissingTaskIsNotARecord() throws {
        let locale = Locale(identifier: "zh-Hans")
        let unknown = """
        {"code":200,"data":{"task":{"status":true,"bizType":9},"timeline":[{"action":"REPORT"},{"action":"APPROVE","createTime":"  ","reasonText":1}]}}
        """
        let record = try IMReviewAuditDetail.record(json: Data(unknown.utf8), locale: locale)
        XCTAssertEqual(record.statusLabel, "—")
        XCTAssertEqual(record.timeline.map(\.label), ["—", try action("APPROVE", locale)])
        XCTAssertEqual(record.timeline.map(\.time), ["—", "—"])
        XCTAssertEqual(record.timeline.map(\.reason), [nil, nil])
        for body in [
            #"{"code":200,"data":{}}"#,
            #"{"code":200,"data":{"task":null,"timeline":[]}}"#,
            #"{"code":200}"#,
            "not-json"
        ] {
            XCTAssertThrowsError(try IMReviewAuditDetail.record(json: Data(body.utf8), locale: locale))
        }
        let nested = #"{"code":200,"data":{"task":{"status":"0","timeline":[{"action":"SUBMIT","createTime":"t"}]}}}"#
        let fromTask = try IMReviewAuditDetail.record(json: Data(nested.utf8), locale: locale)
        XCTAssertEqual(fromTask.statusLabel, try status(0, locale))
        XCTAssertEqual(fromTask.timeline.map(\.label), [try action("SUBMIT", locale)])
        XCTAssertEqual(fromTask.timeline.map(\.time), ["t"])
    }

    func testClosedGroupTitlesAndBadIdsDoNotSend() async throws {
        XCTAssertTrue(IMReviewAuditDetail.hidesDetail(cardTitle: "你的组局已关闭"))
        XCTAssertTrue(IMReviewAuditDetail.hidesDetail(cardTitle: " 你参与的组局已关闭 "))
        XCTAssertFalse(IMReviewAuditDetail.hidesDetail(cardTitle: "审核结果"))
        XCTAssertFalse(IMReviewAuditDetail.hidesDetail(cardTitle: nil))
        let wire = Wire(body: Data("{}".utf8))
        let client = try reader(wire)
        for taskID in ["", "0", "01", "-3", "42a", "9223372036854775808"] {
            do { _ = try await client.record(taskID: taskID); XCTFail(taskID) }
            catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testFailureStatusesDoNotInventARecordOrAWrite() async throws {
        let wire = Wire(status: 403, body: Data(#"{"code":403,"msg":"无权查看该审批记录"}"#.utf8))
        let client = try reader(wire)
        do { _ = try await client.record(taskID: "42"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .httpStatus(403)) }
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.first?.httpMethod, "GET")
        XCTAssertFalse(wire.requests.contains { $0.url?.path.contains("appeal") == true })
        XCTAssertFalse(wire.requests.contains { $0.httpMethod != "GET" })
    }

    private func reader(_ wire: Wire) throws -> IMReviewAuditHTTPReader {
        IMReviewAuditHTTPReader(configuration: try APIConfiguration(baseURL: base), transport: wire, token: { "synthetic-token" }, locale: Locale(identifier: "en"))
    }

    private func status(_ code: Int, _ locale: Locale) throws -> String {
        let body = #"{"code":200,"data":{"task":{"status":\#(code)}}}"#
        return try XCTUnwrap(IMReviewAuditDetail.record(json: Data(body.utf8), locale: locale).statusLabel)
    }

    private func action(_ name: String, _ locale: Locale) throws -> String {
        let body = #"{"code":200,"data":{"task":{"status":0},"timeline":[{"action":"\#(name)"}]}}"#
        return try XCTUnwrap(IMReviewAuditDetail.record(json: Data(body.utf8), locale: locale).timeline.first?.label)
    }

    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var status: Int
        var body: Data
        init(status: Int = 200, body: Data) { self.status = status; self.body = body }
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (body, status) }
    }
}
