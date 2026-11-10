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
        let denied = try await a.publishCheck(eventID: 5)
        XCTAssertEqual(denied, .denied("not host"))
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

final class OfficialOrganizerConsoleStateTests: XCTestCase {
    private func knownCheck() -> OfficialOrganizerCheck {
        OfficialOrganizerCheck(known: true, blockers: [], risks: [], risksKnown: true)
    }

    func testUnknownCountsStayAnEmDashAndZeroStaysZero() {
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.unknownMark, "—")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.countText(known: false, count: 0), "—")
        XCTAssertNotEqual(OfficialOrganizerConsoleSnapshot.countText(known: false, count: 0), "0")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.countText(known: true, count: 0), "0")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.countText(known: false, count: 3), "—")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.statusText(nil), "—")
        XCTAssertNotEqual(OfficialOrganizerConsoleSnapshot.statusText(nil), "0")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.statusText(0), "0")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.controlText(nil), "—")
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.controlText(.paused), "PAUSED")
        XCTAssertFalse(OfficialOrganizerConsoleSnapshot.showsPlayerEntry)
    }

    func testDisabledCapabilityStaysHiddenOffThePlayerEntry() {
        let event = OfficialOrganizerEventState(status: 2, control: .normal, title: "Synthetic")
        let snap = OfficialOrganizerConsoleSnapshot.resolve(enabled: false, load: .allowed(knownCheck(), event))
        XCTAssertEqual(snap.state, .hidden)
        XCTAssertFalse(snap.showsPlayerEntry)
        XCTAssertNil(snap.accessibilityIdentifier)
        XCTAssertEqual(snap.statusText, "—")
        XCTAssertEqual(snap.controlText, "—")
        XCTAssertEqual(snap.blockerCountText, "—")
        XCTAssertNotEqual(snap.statusText, "0")
    }

    func testLoadingEmptyErrorDeniedUnknownAndReady() {
        let loading = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .loading)
        XCTAssertEqual(loading.state, .loading)
        XCTAssertEqual(loading.accessibilityIdentifier, "official.organizer.loading")
        XCTAssertEqual(loading.statusText, "—")
        XCTAssertFalse(loading.showsPlayerEntry)
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .idle).state, .loading)

        let failed = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .failed)
        XCTAssertEqual(failed.state, .error)
        XCTAssertEqual(failed.accessibilityIdentifier, "official.organizer.error")
        XCTAssertEqual(failed.statusText, "—")

        let denied = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .denied)
        XCTAssertEqual(denied.state, .denied)
        XCTAssertEqual(denied.accessibilityIdentifier, "official.organizer.denied")
        XCTAssertFalse(denied.showsPlayerEntry)

        let empty = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(knownCheck(), nil))
        XCTAssertEqual(empty.state, .empty)
        XCTAssertEqual(empty.accessibilityIdentifier, "official.organizer.empty")
        XCTAssertEqual(empty.statusText, "—")
        XCTAssertEqual(empty.blockerCountText, "0")
        XCTAssertEqual(empty.riskCountText, "0")
        XCTAssertNotEqual(empty.statusText, "0")

        let partial = OfficialOrganizerEventState(status: nil, control: .normal)
        let unknown = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(knownCheck(), partial))
        XCTAssertEqual(unknown.state, .unknown)
        XCTAssertEqual(unknown.accessibilityIdentifier, "official.organizer.unknown")
        XCTAssertEqual(unknown.statusText, "—")
        XCTAssertEqual(unknown.controlText, "NORMAL")
        XCTAssertNotEqual(unknown.statusText, "0")

        let omitted = OfficialOrganizerCheck(known: false, blockers: [], risks: [])
        let row = OfficialOrganizerEventState(status: 2, control: .normal)
        let counts = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(omitted, row))
        XCTAssertEqual(counts.state, .unknown)
        XCTAssertEqual(counts.blockerCountText, "—")
        XCTAssertEqual(counts.riskCountText, "—")
        XCTAssertNotEqual(counts.blockerCountText, "0")
        XCTAssertNotEqual(counts.riskCountText, "0")

        let draft = OfficialOrganizerEventState(status: 0, control: .normal)
        let ready = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(knownCheck(), draft))
        XCTAssertEqual(ready.state, .ready)
        XCTAssertEqual(ready.statusText, "0")
        XCTAssertEqual(ready.controlText, "NORMAL")
        XCTAssertEqual(ready.blockerCountText, "0")
        XCTAssertEqual(ready.accessibilityIdentifier, "official.organizer.content")
        XCTAssertFalse(ready.showsPlayerEntry)
    }
}

#if DEBUG
@MainActor final class OfficialOrganizerConsoleFixtureTests: XCTestCase {
    private func access(_ transport: OrganizerTransport, enabled: Bool = true) throws -> OfficialOrganizerHTTPAccess {
        OfficialOrganizerHTTPAccess(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!),
                                    transport: transport, enabled: { enabled }, session: { (7, "synthetic-token") })
    }

    func testFixtureBytesUseTheExistingPublishCheckAndDoNotOpenAPlayerEntry() async throws {
        let transport = OrganizerTransport()
        transport.replies = [(String(decoding: OfficialOrganizerConsoleFixtureData.omittedCounts, as: UTF8.self), 200)]
        let reader = try access(transport)
        guard case .allowed(let omitted) = try await reader.publishCheck(eventID: 5) else { return XCTFail() }
        XCTAssertFalse(omitted.known)
        XCTAssertFalse(omitted.risksKnown)
        XCTAssertEqual(transport.requests[0].url?.path, "/prod-api/api/official/v2/events/5/publish-check")
        XCTAssertEqual(transport.requests[0].httpMethod, "GET")
        let empty = OfficialOrganizerConsoleSnapshot.resolve(enabled: reader.enabled, load: .allowed(omitted, nil))
        XCTAssertEqual(empty.state, .empty)
        XCTAssertEqual(empty.blockerCountText, "—")
        XCTAssertEqual(empty.riskCountText, "—")
        XCTAssertFalse(empty.showsPlayerEntry)

        transport.replies = [(String(decoding: OfficialOrganizerConsoleFixtureData.allowedCheck, as: UTF8.self), 200),
                             (String(decoding: OfficialOrganizerConsoleFixtureData.draftEvent, as: UTF8.self), 200)]
        guard case .allowed(let draftCheck) = try await reader.publishCheck(eventID: 5) else { return XCTFail() }
        XCTAssertTrue(draftCheck.known)
        XCTAssertTrue(draftCheck.risksKnown)
        XCTAssertEqual(draftCheck.blockers.count, 0)
        let draft = try await reader.eventState(eventID: 5)
        XCTAssertEqual(draft?.status, 0)
        XCTAssertEqual(draft?.control, .normal)
        let ready = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(draftCheck, draft))
        XCTAssertEqual(ready.state, .ready)
        XCTAssertEqual(ready.statusText, "0")
        XCTAssertEqual(ready.controlText, "NORMAL")
        XCTAssertEqual(transport.requests[2].url?.path, "/prod-api/api/official/events/5")

        transport.replies = [(String(decoding: OfficialOrganizerConsoleFixtureData.allowedCheck, as: UTF8.self), 200),
                             (String(decoding: OfficialOrganizerConsoleFixtureData.readyEvent, as: UTF8.self), 200)]
        guard case .allowed(let liveCheck) = try await reader.publishCheck(eventID: 5) else { return XCTFail() }
        let live = try await reader.eventState(eventID: 5)
        XCTAssertEqual(live?.status, 2)
        let liveSnap = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(liveCheck, live))
        XCTAssertEqual(liveSnap.state, .ready)
        XCTAssertEqual(liveSnap.statusText, "2")
        XCTAssertFalse(liveSnap.showsPlayerEntry)

        transport.replies = [(#"{"code":404}"#, 200),
                             (String(decoding: OfficialOrganizerConsoleFixtureData.emptyPublished, as: UTF8.self), 200)]
        let missing = try await reader.eventState(eventID: 5)
        XCTAssertNil(missing)
        XCTAssertTrue(transport.requests.contains { $0.url?.path == "/prod-api/api/official/my-published" })
        XCTAssertFalse(transport.requests.contains { $0.url?.path == "/prod-api/api/official/v2/events" })
        let missingSnap = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(liveCheck, missing))
        XCTAssertEqual(missingSnap.state, .empty)
        XCTAssertEqual(missingSnap.statusText, "—")
        XCTAssertNotEqual(missingSnap.statusText, "0")

        transport.replies = [(String(decoding: OfficialOrganizerConsoleFixtureData.unknownEvent, as: UTF8.self), 200)]
        let unknownEvent = try await reader.eventState(eventID: 5)
        XCTAssertNil(unknownEvent?.status)
        XCTAssertNil(unknownEvent?.control)
        let unknown = OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .allowed(draftCheck, unknownEvent))
        XCTAssertEqual(unknown.state, .unknown)
        XCTAssertEqual(unknown.statusText, "—")
        XCTAssertNotEqual(unknown.statusText, "0")

        transport.replies = [(String(decoding: OfficialOrganizerConsoleFixtureData.denied, as: UTF8.self), 200)]
        let denied = try await reader.publishCheck(eventID: 5)
        XCTAssertEqual(denied, .denied("synthetic host gate"))
        let hidden = OfficialOrganizerConsoleSnapshot.resolve(enabled: false, load: .denied)
        XCTAssertEqual(hidden.state, .hidden)
        XCTAssertNil(hidden.accessibilityIdentifier)
        XCTAssertFalse(hidden.showsPlayerEntry)

        transport.replies = [("{}", 503)]
        do { _ = try await reader.publishCheck(eventID: 5); XCTFail() }
        catch { XCTAssertEqual(error as? OfficialOrganizerFailure, .network) }
        XCTAssertEqual(OfficialOrganizerConsoleSnapshot.resolve(enabled: true, load: .failed).state, .error)
        XCTAssertEqual(transport.requests.count, 10)
    }
}
#endif
