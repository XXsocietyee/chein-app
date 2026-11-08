import Foundation
import XCTest
@testable import Questify

final class Adapt1IMReportLocationTests: XCTestCase {
    private let clientID = "0123456789abcdef0123456789abcdef"

    private func place() throws -> IMStaticLocation {
        try IMStaticLocation(name: "人民广场", address: "上海", latitude: 31.2304, longitude: 121.4737, datum: "WGS84")
    }
    private func intent() throws -> IMOutgoingIntent {
        try IMOutgoingIntent(scope: adapt1Scope(), payload: .staticLocation(place()), clientMessageID: clientID)
    }
    private func card(name: String = "人民广场", lat: Double = 31.2304) -> [String: Any] {
        ["cardType": "location", "name": name, "address": "上海", "lat": lat, "lng": 121.4737]
    }

    // MARK: report (A5)

    func testReportSendsFormMessageIdAndReasonNotJSON() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.reportSuccess, 200)])
        let outcome = try await adapt1Adapter(transport, paths: [Adapt1IMPath.report]).reportMessage(messageID: 55, reasonLabel: "诈骗", note: "要求转账", token: "tok")
        XCTAssertEqual(outcome, .submittedUnreceipted(message: "举报已提交"))
        let request = transport.requests[0]
        XCTAssertEqual(request.url?.path, "/prod-api/api/im/report")
        XCTAssertEqual(adapt1Fields(request), ["message_id": "55", "reason": "诈骗：要求转账"])
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "tok")
    }

    func testReportWithoutNoteSendsLabelOnly() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.reportSuccess, 200)])
        _ = try await adapt1Adapter(transport, paths: [Adapt1IMPath.report]).reportMessage(messageID: 5, reasonLabel: "垃圾广告", note: "  ", token: "tok")
        XCTAssertEqual(adapt1Fields(transport.requests[0])["reason"], "垃圾广告")
    }

    func testReasonTextCapsLengthTruncatingOnlyTheNote() {
        let text = Adapt1IMBackendAdapter.reasonText(label: "垃圾广告", note: String(repeating: "a", count: 200))
        XCTAssertNotNil(text)
        XCTAssertLessThanOrEqual(text!.utf16.count, 64)
        XCTAssertTrue(text!.hasPrefix("垃圾广告："))
        XCTAssertNil(Adapt1IMBackendAdapter.reasonText(label: " ", note: "x"))
        XCTAssertNil(Adapt1IMBackendAdapter.reasonText(label: String(repeating: "x", count: 65), note: nil))
    }

    func testReportBusinessErrorAndGatesAndInvalidInput() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.error("不能举报自己的消息"), 200)])
        let adapter = try adapt1Adapter(transport, paths: [Adapt1IMPath.report])
        do { _ = try await adapter.reportMessage(messageID: 5, reasonLabel: "诈骗", note: nil, token: "tok"); XCTFail() }
        catch let failure as MessagingReadFailure { XCTAssertEqual(failure.message, "不能举报自己的消息") }
        do { _ = try await adapter.reportMessage(messageID: 0, reasonLabel: "诈骗", note: nil, token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        let off = try adapt1Adapter(transport, writes: false, paths: [Adapt1IMPath.report])
        do { _ = try await off.reportMessage(messageID: 5, reasonLabel: "诈骗", note: nil, token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    // MARK: static location (A6)

    func testStaticLocationIsSentAsTypeThreeLocationCardNeverTypeThirteen() throws {
        let fields = try Adapt1StaticLocationCard.wireFields(for: place())
        XCTAssertEqual(fields["msg_type"], "3")
        XCTAssertEqual(fields["content"], "[位置]")
        let object = try JSONSerialization.jsonObject(with: Data(fields["extra_json"]!.utf8)) as! [String: Any]
        XCTAssertEqual(Set(object.keys), ["cardType", "name", "address", "lat", "lng"])
        XCTAssertEqual(object["cardType"] as? String, "location")
        XCTAssertEqual(object["lat"] as? Double, 31.2304)
        XCTAssertEqual(try place().wireFields()["msg_type"], "13", "existing type-13 path is untouched")
    }

    func testSendStaticLocationAcceptsTheServerRebuiltCard() async throws {
        let body = Adapt1Fixture.sendEnvelope(clientMessageID: clientID, content: "[位置] 人民广场", card: card())
        let transport = Adapt1FakeTransport([(body, 200)])
        let message = try await adapt1Adapter(transport, paths: [Adapt1IMPath.send]).sendStaticLocation(intent(), token: "tok")
        XCTAssertEqual(message.id, 101)
        XCTAssertEqual(Adapt1StaticLocationCard.read(message), try place())
        XCTAssertNil(IMStaticLocation.read(message), "existing type-13 reader still refuses the card form")
        let sent = transport.requests[0]
        XCTAssertEqual(sent.url?.path, "/prod-api/api/im/send")
        let fields = adapt1Fields(sent)
        XCTAssertEqual(fields["conversation_id"], "9")
        XCTAssertEqual(fields["client_message_id"], clientID)
        XCTAssertEqual(fields["msg_type"], "3")
    }

    func testSendStaticLocationMismatchesAreUnknownOutcome() async throws {
        let bodies = [
            Adapt1Fixture.sendEnvelope(clientMessageID: clientID, content: "[位置] 外滩", card: card(name: "外滩")),
            Adapt1Fixture.sendEnvelope(clientMessageID: clientID, content: "[位置] 人民广场", card: card(lat: 31.5)),
            Adapt1Fixture.sendEnvelope(clientMessageID: "ffffffffffffffffffffffffffffffff", content: "[位置] 人民广场", card: card()),
            Adapt1Fixture.sendEnvelope(senderID: 8, clientMessageID: clientID, content: "[位置] 人民广场", card: card()),
            Adapt1Fixture.sendEnvelope(conversationID: 10, clientMessageID: clientID, content: "[位置] 人民广场", card: card()),
            Adapt1Fixture.sendEnvelope(clientMessageID: clientID, content: "人民广场", card: card()),
            Adapt1Fixture.bareSuccess
        ]
        for body in bodies {
            let transport = Adapt1FakeTransport([(body, 200)])
            do { _ = try await adapt1Adapter(transport, paths: [Adapt1IMPath.send]).sendStaticLocation(intent(), token: "tok"); XCTFail() }
            catch { XCTAssertEqual(error as? IMCapabilityGap, .unknownOutcome) }
            XCTAssertEqual(transport.requests.count, 1)
        }
    }

    func testSendStaticLocationBackendRejectionAndGates() async throws {
        let transport = Adapt1FakeTransport([(Adapt1Fixture.error("不支持的消息类型"), 200)])
        do { _ = try await adapt1Adapter(transport, paths: [Adapt1IMPath.send]).sendStaticLocation(intent(), token: "tok"); XCTFail() }
        catch let failure as MessagingReadFailure { XCTAssertEqual(failure.message, "不支持的消息类型") }
        let route = try IMOutgoingIntent(scope: adapt1Scope(), payload: .route(topicID: 3), clientMessageID: clientID)
        do { _ = try await adapt1Adapter(transport, paths: [Adapt1IMPath.send]).sendStaticLocation(route, token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        do { _ = try await adapt1Adapter(transport, writes: false, paths: [Adapt1IMPath.send]).sendStaticLocation(intent(), token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertEqual(transport.requests.count, 1)
    }
}
