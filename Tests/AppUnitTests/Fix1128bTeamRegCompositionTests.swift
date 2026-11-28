import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Questify

/// fix/1128b-team-reg: each gap builds the shipped Release composition (`RegionalLaunchConfiguration.shippedComposition`,
/// the reviewed China deployment) and proves the service is switched on and admits the exact path(s).
@MainActor final class Fix1128bTeamRegCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    // MARK: Gap #6 / #7 — team writes go through `api/team/command`

    func testGap6ReleaseTeamWritesUseTheCommandWriterTheLeaseAdmits() async throws {
        let recorder = Fix1128bRecorder()
        let composition = shipped(recorder)
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let writes = composition.teamWrites(player, transport: transport)
        let writer = try XCTUnwrap(writes.commands, "Release must compose the team command writer")
        XCTAssertTrue(TeamCommandWriter.paths.isSubset(of: writer.approval.paths))
        let api = try XCTUnwrap(composition.reviewed?.regional.apiConfiguration)
        XCTAssertTrue(writer.approval.allows(configuration: api, namespace: player.session.namespace,
                                             accountID: player.session.accountID, path: "api/team/command"))
        recorder.payload = #"{"code":200,"data":{"requestId":"r","state":"APPLIED","message":"原请求已执行"}}"#
        let receipt = await writer.submitReceipt(key: "team-4", path: "api/team/command",
                                                 fields: ["action": "quit", "targetId": "4"],
                                                 requestID: TeamCommandWriter.requestID(for: UUID()))
        XCTAssertEqual(recorder.paths.last, "api/team/command", "the composition firewall admits the signed command")
        XCTAssertEqual(receipt.terminal, .applied(200))
        recorder.payload = #"{"code":200,"data":{"requestId":"r","state":"REJECTED","message":"暂时无法加入该队伍"}}"#
        let rejected = await writer.submitReceipt(key: "team-5", path: "api/team/command", fields: ["action": "disband", "targetId": "5"])
        XCTAssertEqual(rejected.terminal, .rejected(200))
        XCTAssertEqual(rejected.message, "暂时无法加入该队伍")
    }

    func testGap6SignedOutHasNoTeamWrites() {
        let composition = shipped(Fix1128bRecorder())
        let none = composition.teamWrites(nil, transport: composition.transport())
        XCTAssertNil(none.commands)
        XCTAssertNil(none.approval)
    }

    // MARK: Gap #8 — player waitlist in Release

    func testGap8ReleaseWaitlistLeaseAdmitsTheThreeWaitlistRoutes() async throws {
        let recorder = Fix1128bRecorder()
        let composition = shipped(recorder)
        let player = try playerContext(composition)
        let approval = try XCTUnwrap(composition.registrationWaitlistApproval(player), "Release must issue the waitlist lease")
        XCTAssertEqual(approval.paths, ["api/club/event-ops/waitlist/status", "api/club/event-ops/waitlist/join",
                                        "api/club/event-ops/waitlist/cancel"])
        XCTAssertNil(composition.registrationWaitlistApproval(try playerContext(composition, role: "merchant")),
                     "merchant routes stay off")
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let api = try XCTUnwrap(composition.reviewed?.regional.apiConfiguration)
        let session = try RegistrationWaitlistLeaseSession(accountID: 7, namespace: player.session.namespace, token: "player-token")
        let service = try RegistrationWaitlistLeaseService(configuration: api, transport: transport, approval: approval,
                                                           activityID: 5, current: { session })
        let none = #"{"code":200,"data":{"activityId":5,"ticketId":6,"memberId":7,"state":"NONE","eligibilityState":"ELIGIBLE","waitlistJoinAllowed":true}}"#
        let joined = #"{"code":200,"data":{"id":11,"activityId":5,"ticketId":6,"memberId":7,"state":"WAITING"}}"#
        let waiting = #"{"code":200,"data":{"id":11,"activityId":5,"ticketId":6,"memberId":7,"state":"WAITING","eligibilityState":"ELIGIBLE","waitlistJoinAllowed":false}}"#
        recorder.queue = [none, joined, waiting]
        let scope = try RegistrationWaitlistScope(activityID: 5, ticketID: 6)
        let result = try await service.join(scope)
        XCTAssertEqual(result.state, .waiting)
        XCTAssertEqual(recorder.paths, ["api/club/event-ops/waitlist/status", "api/club/event-ops/waitlist/join",
                                        "api/club/event-ops/waitlist/status"])
        XCTAssertEqual(recorder.bodies[1], ["activityId": 5, "ticketId": 6])
        // Another activity's scope never sends.
        do { _ = try await service.status(try RegistrationWaitlistScope(activityID: 99, ticketID: 6)); XCTFail("scoped to one activity") }
        catch { XCTAssertEqual(recorder.paths.count, 3) }
    }

    func testGap8FirewallAdmitsOnlyTheExactScopeBody() throws {
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        func request(_ body: String, type: String = "application/json") -> URLRequest {
            var value = URLRequest(url: base.appendingPathComponent("api/club/event-ops/waitlist/join"))
            value.httpMethod = "POST"; value.setValue(type, forHTTPHeaderField: "Content-Type"); value.httpBody = Data(body.utf8)
            return value
        }
        XCTAssertTrue(ReviewedProductionFormMutationRoute.waitlistScopeBody(request(#"{"activityId":5,"ticketId":6}"#)))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.waitlistScopeBody(request(#"{"activityId":5,"ticketId":6,"memberId":7}"#)))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.waitlistScopeBody(request(#"{"activityId":"5","ticketId":6}"#)))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.waitlistScopeBody(request(#"{"activityId":0,"ticketId":6}"#)))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.waitlistScopeBody(request(#"{"activityId":5,"ticketId":6}"#, type: "text/plain")))
    }

    // MARK: Gap #9 — Release order configuration

    func testGap9ReleaseOrderConfigurationApprovesDevicePaymentAndReviewedOrderActions() throws {
        let composition = shipped(Fix1128bRecorder())
        let player = try playerContext(composition)
        let order = try XCTUnwrap(composition.sessionDependencies(player).orderLifecycleConfiguration)
        XCTAssertTrue(order.devicePaymentApproved)
        XCTAssertTrue(order.allowsReviewedCancellationAndRefund)
        XCTAssertFalse(order.externalCheckoutApproved, "the review-sheet checkout stays closed; re-pay uses the pay section")
        XCTAssertTrue(order.matches(player))
    }

    // MARK: helpers

    func shipped(_ recorder: Fix1128bRecorder) -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
    }

    func playerContext(_ composition: AppCompositionRoot, role: String = "player") throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token", role: role)
        return RuntimeDependencyContext(market: .china, baseURL: base, role: role, session: session)
    }
}

final class Fix1128bRecorder: HTTPTransport {
    var paths: [String] = []
    var methods: [String] = []
    var bodies: [[String: Int]] = []
    var payload = #"{"code":200,"data":[]}"#
    /// Answers in order when non-empty, then falls back to `payload`.
    var queue: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        methods.append(request.httpMethod ?? "")
        let object = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        bodies.append(object.compactMapValues { $0 as? Int })
        let answer = queue.isEmpty ? payload : queue.removeFirst()
        return (Data(answer.utf8), 200)
    }
}
