import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Deterministic readiness checks. No socket, session, or live route is opened.
@MainActor final class TemplateAuthoringPageReadinessTests: XCTestCase {
    private func session() throws -> TemplateAuthoringSession {
        try .init(accountID: 901, namespace: "synthetic-template-author", epoch: 1, authorizationRevision: "member-fixture")
    }
    private func coordinator(session: TemplateAuthoringSession?, transport: TemplateAuthoringSyntheticTransport? = nil) -> TemplateAuthoringCoordinator {
        let store = TemplateAuthoringLocalStore(storage: TemplateAuthoringMemoryStorage())
        return TemplateAuthoringCoordinator(adapter: .init(transport: transport), store: store, currentSession: { session })
    }

    func testMissingSessionAndUnreadableInfoStayHidden() throws {
        let signedOut = coordinator(session: nil)
        let draft = TemplateAuthoringDraft(title: "Zero")
        XCTAssertTrue(signedOut.editorReadiness.hidden)
        XCTAssertNil(signedOut.editorReadiness.phase)
        XCTAssertEqual(signedOut.editorReadiness.durationText, "—")
        XCTAssertEqual(signedOut.editorReadiness.useCountText, "—")
        let hiddenDraft = TemplateAuthoringPageReadiness.editor(sessionPresent: false, submitting: true, blocked: true, uncertain: true, draft: draft, messageKey: "templateAuthor.uncertain")
        XCTAssertTrue(hiddenDraft.hidden)
        XCTAssertNil(hiddenDraft.phase)
        XCTAssertNotEqual(hiddenDraft.durationText, "0")
        let leaked = signedOut.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.zeroCounts, httpStatus: 200, inFlight: false)
        XCTAssertTrue(leaked.hidden)
        XCTAssertNil(leaked.phase)
        XCTAssertEqual(leaked.durationText, "—")
        XCTAssertEqual(leaked.useCountText, "—")
        XCTAssertNil(leaked.title)
    }

    func testEditorPhasesKeepLiteralZeroAndUnknownDash() async throws {
        let owner = try session()
        let blank = coordinator(session: owner)
        blank.open(seed: .init())
        XCTAssertEqual(blank.editorReadiness.phase, .empty)
        XCTAssertEqual(blank.editorReadiness.durationText, "—")
        XCTAssertEqual(blank.editorReadiness.useCountText, "—")
        var zero = TemplateAuthoringDraft(title: "Zero")
        zero.duration = 0
        let ready = TemplateAuthoringPageReadiness.editor(sessionPresent: true, submitting: false, blocked: false, uncertain: false, draft: zero, messageKey: nil)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.durationText, "0")
        XCTAssertEqual(ready.useCountText, "—")
        let loading = TemplateAuthoringPageReadiness.editor(sessionPresent: true, submitting: true, blocked: false, uncertain: false, draft: TemplateAuthoringSyntheticFixtures.draft(), messageKey: nil)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.durationText, "10")
        let storage = TemplateAuthoringMemoryStorage()
        let failed = TemplateAuthoringCoordinator(adapter: .init(transport: TemplateAuthoringSyntheticTransport()), store: .init(storage: storage), currentSession: { owner })
        failed.open(seed: TemplateAuthoringSyntheticFixtures.draft())
        storage.failWrites = true
        failed.saveLocal()
        XCTAssertEqual(failed.editorReadiness.phase, .error)
        XCTAssertEqual(failed.editorReadiness.durationText, "10")
        let transport = TemplateAuthoringSyntheticTransport(scenario: .uncertain)
        let uncertain = coordinator(session: owner, transport: transport)
        uncertain.open(seed: TemplateAuthoringSyntheticFixtures.draft())
        uncertain.prepare(.publish)
        await uncertain.confirm(try XCTUnwrap(uncertain.review))
        XCTAssertEqual(uncertain.state, .uncertain)
        XCTAssertEqual(uncertain.editorReadiness.phase, .unknown)
        XCTAssertEqual(uncertain.editorReadiness.durationText, "10")
        XCTAssertEqual(uncertain.editorReadiness.useCountText, "—")
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testLibraryInfoUsesExistingPayloadWithoutSendingOrGuessingZero() async throws {
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/template/info"), .liveInProduction)
        let configuration = try APIConfiguration(baseURL: try XCTUnwrap(URL(string: "https://example.test")))
        let info = TemplateAuthoringRequest(path: "/api/template/info", body: .form(["id": "901"]), mutates: false)
        XCTAssertThrowsError(try TemplateAuthoringWireRequestBuilder.make(info, configuration: configuration, token: "fixture-token"))
        let owner = try session()
        let transport = TemplateAuthoringSyntheticTransport()
        let reader = coordinator(session: owner, transport: transport)
        let loading = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.loadingBody, httpStatus: nil, inFlight: true)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.durationText, "—")
        let empty = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.empty, httpStatus: 200, inFlight: false)
        XCTAssertEqual(empty.phase, .empty)
        let failed = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.error, httpStatus: 200, inFlight: false)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.durationText, "—")
        let unknown = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.unknown, httpStatus: 200, inFlight: false)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.durationText, "—")
        XCTAssertEqual(unknown.useCountText, "—")
        XCTAssertNil(unknown.title)
        let missing = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.missingCounts, httpStatus: 200, inFlight: false)
        XCTAssertEqual(missing.phase, .ready)
        XCTAssertEqual(missing.title, "Synthetic city question")
        XCTAssertEqual(missing.durationText, "—")
        XCTAssertEqual(missing.useCountText, "—")
        let zeros = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.zeroCounts, httpStatus: 200, inFlight: false)
        XCTAssertEqual(zeros.phase, .ready)
        XCTAssertEqual(zeros.durationText, "0")
        XCTAssertEqual(zeros.useCountText, "0")
        let blanks = reader.libraryInfoReadiness(data: TemplateAuthoringPageFixtureData.blankNumbers, httpStatus: 200, inFlight: false)
        XCTAssertEqual(blanks.phase, .ready)
        XCTAssertEqual(blanks.durationText, "—")
        XCTAssertEqual(blanks.useCountText, "—")
        let paddedZero = Data(#"{"code":200,"data":{"id":901,"title":"Synthetic city question","duration":" 0 ","useNum":"00"}}"#.utf8)
        let padded = reader.libraryInfoReadiness(data: paddedZero, httpStatus: 200, inFlight: false)
        XCTAssertEqual(padded.durationText, "0")
        XCTAssertEqual(padded.useCountText, "—")
        let typed = Data(#"{"code":200,"data":{"id":901,"title":"Synthetic city question","duration":true,"useNum":"10min"}}"#.utf8)
        let words = reader.libraryInfoReadiness(data: typed, httpStatus: 200, inFlight: false)
        XCTAssertEqual(words.phase, .ready)
        XCTAssertEqual(words.durationText, "—")
        XCTAssertEqual(words.useCountText, "—")
        XCTAssertEqual(reader.libraryInfoReadiness(data: Data("[]".utf8), httpStatus: 500, inFlight: false).phase, .error)
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
