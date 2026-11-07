import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

private struct OtherError: Error {}

/// Finding 1: the team "Submit report" button must reach a real service and only a successful answer shows success.
@MainActor final class TeamReportSubmissionTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var result: Result<(Data, Int), Error> = .success((Data(#"{"code":200,"data":{"taskId":9}}"#.utf8), 200))
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return try result.get() }
    }
    private final class Stub: TeamOrientBoardAccess {
        var enabled = true
        var error: Error?
        private(set) var reports: [(Int, String)] = []
        func loadBoard(teamID: Int) async throws -> TeamOrientBoardDetail? { nil }
        func loadRanking(ownerType: Int, ownerID: Int) async throws -> [TeamOrientRankingRow] { [] }
        func reportTeam(teamID: Int, reason: String) async throws {
            reports.append((teamID, reason))
            if let error { throw error }
        }
    }
    private func access(_ wire: Wire, signedIn: Bool = true) throws -> TeamOrientBoardHTTPAccess {
        TeamOrientBoardHTTPAccess(configuration: try APIConfiguration(baseURL: URL(string: "https://api.example.com")!),
                                  transport: wire, session: { signedIn ? (7, "synthetic-7") : nil })
    }

    func testSuccessIsShownOnlyAfterServiceSucceeds() async {
        let stub = Stub()
        let state = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "  spam  ")
        XCTAssertEqual(state, .submitted)
        XCTAssertEqual(stub.reports.count, 1)
    }

    func testFailingServiceNeverShowsSuccessAndIsRetryable() async {
        let stub = Stub()
        stub.error = TeamReportFailure.network
        let first = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "spam")
        XCTAssertEqual(first, .failed(.network))
        stub.error = TeamReportFailure.rejected("nope")
        let second = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "spam")
        XCTAssertEqual(second, .failed(.rejected("nope")))
        stub.error = OtherError()
        let third = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "spam")
        XCTAssertEqual(third, .failed(.network))
        stub.error = nil
        let retry = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "spam")
        XCTAssertEqual(retry, .submitted, "the same report can be retried after a failure")
    }

    func testUnwiredOrDisabledServiceIsUnavailableNotSuccess() async {
        let none = await TeamReportSubmission.run(access: nil, teamID: 3, reason: "spam")
        XCTAssertEqual(none, .unavailable)
        let stub = Stub()
        stub.enabled = false
        let off = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "spam")
        XCTAssertEqual(off, .unavailable)
        XCTAssertTrue(stub.reports.isEmpty)
        stub.enabled = true
        stub.error = TeamReportFailure.unavailable
        let denied = await TeamReportSubmission.run(access: stub, teamID: 3, reason: "spam")
        XCTAssertEqual(denied, .unavailable)
    }

    func testHTTPAccessPostsExactJSONAndSucceedsOnlyOnEnvelope200() async throws {
        let wire = Wire()
        try await access(wire).reportTeam(teamID: 12, reason: "  rude  ")
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/team/report")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-7")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), #"{"reason":"rude","teamId":12}"#)
    }

    func testHTTPAccessMapsEveryNonSuccessToAFailure() async throws {
        for (result, expected): (Result<(Data, Int), Error>, TeamReportFailure) in [
            (.success((Data(#"{"code":500,"msg":"busy"}"#.utf8), 200)), .rejected("busy")),
            (.success((Data("<html>".utf8), 200)), .network),
            (.success((Data(#"{"code":200}"#.utf8), 502)), .network),
            (.success((Data(#"{"code":200}"#.utf8), 401)), .unauthorized),
            (.failure(URLError(.notConnectedToInternet)), .network),
            (.failure(APIError.notConfigured), .unavailable)
        ] {
            let wire = Wire(); wire.result = result
            let state = await TeamReportSubmission.run(access: try access(wire), teamID: 3, reason: "spam")
            switch expected {
            case .unavailable: XCTAssertEqual(state, .unavailable)
            default: XCTAssertEqual(state, .failed(expected))
            }
            XCTAssertNotEqual(state, .submitted)
        }
        let signedOut = Wire()
        let state = await TeamReportSubmission.run(access: try access(signedOut, signedIn: false), teamID: 3, reason: "spam")
        XCTAssertEqual(state, .unavailable)
        XCTAssertTrue(signedOut.requests.isEmpty)
        let wire = Wire()
        for (id, reason) in [(0, "x"), (3, "   "), (3, String(repeating: "a", count: 201))] {
            do { try await access(wire).reportTeam(teamID: id, reason: reason); XCTFail("must reject") }
            catch { XCTAssertEqual(error as? TeamReportFailure, .invalid) }
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
