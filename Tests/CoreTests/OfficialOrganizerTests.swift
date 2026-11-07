import Foundation
import XCTest
@testable import QuestifyCore

final class OfficialOrganizerRulesTests: XCTestCase {
    private func state(_ status: Int?, _ control: OfficialOrganizerControl?) -> OfficialOrganizerEventState {
        .init(status: status, control: control)
    }
    func testAvailabilityMatchesSourceStateGates() {
        let draft = OfficialOrganizerRules.availability(state(0, .normal))
        XCTAssertTrue(draft[.schedule]!.enabled); XCTAssertEqual(draft[.pause]!.hint, .publishFirst); XCTAssertEqual(draft[.resume]!.hint, .notPaused)
        let live = OfficialOrganizerRules.availability(state(2, .normal))
        XCTAssertEqual(live[.schedule]!.hint, .alreadyPublished); XCTAssertTrue(live[.pause]!.enabled)
        let settling = OfficialOrganizerRules.availability(state(4, .normal))
        XCTAssertEqual(settling[.pause]!.hint, .ended)
        let paused = OfficialOrganizerRules.availability(state(2, .paused))
        XCTAssertEqual(paused[.pause]!.hint, .alreadyPaused); XCTAssertTrue(paused[.resume]!.enabled)
        let unknown = OfficialOrganizerRules.availability(nil)
        XCTAssertEqual(unknown[.schedule]!.hint, .stateUnknown)
        XCTAssertEqual(unknown[.pause]!.hint, .controlUnknown); XCTAssertEqual(unknown[.resume]!.hint, .controlUnknown)
        XCTAssertEqual(OfficialOrganizerRules.availability(state(nil, .normal))[.pause]!.hint, .stateUnknown)
    }
    func testNormalizeRequiresIntegerStatusAndKnownControl() {
        let ok = OfficialOrganizerEventState(raw: ["status": 1, "controlState": "PAUSED", "title": " T ", "pausedReason": " r "])
        XCTAssertEqual(ok.status, 1); XCTAssertEqual(ok.control, .paused); XCTAssertEqual(ok.title, "T"); XCTAssertEqual(ok.pausedReason, "r")
        let bad = OfficialOrganizerEventState(raw: ["status": 1.5, "controlState": "weird"])
        XCTAssertNil(bad.status); XCTAssertNil(bad.control)
        XCTAssertNil(OfficialOrganizerEventState(raw: ["status": true]).status)
    }
    func testPauseComposeValidateAndPayload() {
        XCTAssertEqual(OfficialOrganizerRules.compose(.init(preset: "A", extra: "b")), "A：b")
        XCTAssertEqual(OfficialOrganizerRules.compose(.init(preset: " A ", extra: "")), "A")
        XCTAssertEqual(OfficialOrganizerRules.compose(.init(preset: "", extra: " b ")), "b")
        var form = Dictionary(uniqueKeysWithValues: OfficialOrganizerRules.pauseFields.map { ($0, OfficialOrganizerPauseEntry(preset: "", extra: "x")) })
        XCTAssertNil(OfficialOrganizerRules.validatePause(form))
        form["reason"] = .init()
        XCTAssertEqual(OfficialOrganizerRules.validatePause(form), .pauseIncomplete)
        form["reason"] = .init(preset: "", extra: String(repeating: "a", count: 301))
        XCTAssertEqual(OfficialOrganizerRules.validatePause(form), .pauseTooLong)
        form["reason"] = .init(preset: "", extra: "ok")
        XCTAssertEqual(Set(OfficialOrganizerRules.payload(.pause, pause: form).keys), Set(OfficialOrganizerRules.pauseFields))
    }
    func testResumeValidation() {
        XCTAssertEqual(OfficialOrganizerRules.validateResume(reason: "  "), .resumeMissing)
        XCTAssertEqual(OfficialOrganizerRules.validateResume(reason: String(repeating: "a", count: 201)), .resumeTooLong)
        XCTAssertNil(OfficialOrganizerRules.validateResume(reason: "fixed"))
        XCTAssertEqual(OfficialOrganizerRules.payload(.resume, resumeReason: " fixed "), ["reason": "fixed"])
        XCTAssertEqual(OfficialOrganizerRules.payload(.schedule), [:])
    }
    func testReadBack() {
        XCTAssertTrue(OfficialOrganizerRules.readBackMatches(.schedule, state(1, .normal)))
        XCTAssertFalse(OfficialOrganizerRules.readBackMatches(.schedule, state(0, .normal)))
        XCTAssertTrue(OfficialOrganizerRules.readBackMatches(.pause, state(2, .paused)))
        XCTAssertFalse(OfficialOrganizerRules.readBackMatches(.resume, state(2, .paused)))
    }
    func testPresetCountsAreStable() {
        for field in OfficialOrganizerRules.pauseFields { XCTAssertEqual(OfficialOrganizerRules.pausePresets[field]?.count, 3) }
        XCTAssertEqual(OfficialOrganizerCommand.newRequestID().count, 32)
    }
}

private final class OrganizerTransport: HTTPTransport, @unchecked Sendable {
    var replies: [(String, Int)] = []
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !replies.isEmpty else { throw APIError.httpStatus(503) }
        let r = replies.removeFirst(); return (Data(r.0.utf8), r.1)
    }
}
@MainActor final class OfficialOrganizerAccessTests: XCTestCase {
    private func make(_ t: OrganizerTransport, enabled: Bool = true) throws -> OfficialOrganizerHTTPAccess {
        .init(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!), transport: t, enabled: { enabled },
              session: { (7, "synthetic-token") })
    }
    func testPublishCheckAllowedDeniedAndUnknownBlockers() async throws {
        let t = OrganizerTransport()
        t.replies = [(#"{"code":200,"data":{"blockers":["need cover"],"risks":["r1"]}}"#, 200),
                     (#"{"code":403,"msg":"not host"}"#, 200), (#"{"code":200,"data":{}}"#, 200)]
        let a = try make(t)
        guard case .allowed(let check) = try await a.publishCheck(eventID: 5) else { return XCTFail() }
        XCTAssertFalse(check.pass); XCTAssertEqual(check.blockers, ["need cover"]); XCTAssertEqual(check.risks, ["r1"])
        XCTAssertEqual(t.requests[0].url?.path, "/prod-api/api/official/v2/events/5/publish-check")
        XCTAssertEqual(t.requests[0].value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertEqual(try await a.publishCheck(eventID: 5), .denied("not host"))
        guard case .allowed(let unknown) = try await a.publishCheck(eventID: 5) else { return XCTFail() }
        XCTAssertFalse(unknown.known); XCTAssertFalse(unknown.pass)
    }
    func testStateFallsBackToMyPublishedForDrafts() async throws {
        let t = OrganizerTransport()
        t.replies = [(#"{"code":404}"#, 200), (#"{"code":200,"data":{"events":[{"id":9,"status":0,"title":"Draft"},{"id":5,"status":0,"controlState":"NORMAL","title":"Mine"}]}}"#, 200)]
        let s = try await make(t).eventState(eventID: 5)
        XCTAssertEqual(s?.title, "Mine"); XCTAssertEqual(s?.status, 0)
    }
    func testCommandSubmitBodyAndReceiptMatching() async throws {
        let t = OrganizerTransport()
        let id = String(repeating: "a", count: 32)
        t.replies = [(#"{"code":200,"data":{"requestId":"\#(id)","state":"APPLIED","message":"done"}}"#, 200),
                     (#"{"code":200,"data":{"requestId":"\#(String(repeating: "b", count: 32))","state":"APPLIED"}}"#, 200), ("oops", 502)]
        let a = try make(t)
        let cmd = OfficialOrganizerCommand(eventID: 5, action: .resume, requestId: id, fields: ["reason": "ok"])
        let receipt = try await a.command(cmd, mode: .submit)
        XCTAssertEqual(receipt, .init(requestId: id, state: .applied, message: "done"))
        let body = try JSONSerialization.jsonObject(with: t.requests[0].httpBody!) as! [String: String]
        XCTAssertEqual(body, ["reason": "ok", "targetId": "5", "action": "resume", "requestId": id])
        XCTAssertEqual(t.requests[0].url?.path, "/prod-api/api/official/command")
        let mismatch = try await a.command(cmd, mode: .query)
        XCTAssertNil(mismatch, "another request's receipt must not settle this command")
        XCTAssertEqual(t.requests[1].url?.path, "/prod-api/api/official/command/query")
        let unknown = try await a.command(cmd, mode: .cancel)
        XCTAssertNil(unknown)
    }
    func testDisabledAccessSendsNothing() async throws {
        let t = OrganizerTransport(); let a = try make(t, enabled: false)
        do { _ = try await a.publishCheck(eventID: 1); XCTFail() } catch { XCTAssertEqual(error as? OfficialOrganizerFailure, .disabled) }
        XCTAssertTrue(t.requests.isEmpty)
    }
}
