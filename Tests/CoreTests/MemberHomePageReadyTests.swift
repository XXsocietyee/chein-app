import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor MemberHomePageWire: HTTPTransport {
    let json: String
    let status: Int
    private(set) var requests: [URLRequest] = []
    init(_ json: String, status: Int = 200) { self.json = json; self.status = status }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(json.utf8), status)
    }
}

@MainActor final class MemberHomePageReadyTests: XCTestCase {
    private let base = URL(string: "https://member.example/native")!
    private func service(_ wire: any HTTPTransport) throws -> MemberHomeService {
        .init(configuration: try APIConfiguration(baseURL: base), transport: wire)
    }

    func testUnknownCountIsAnEmDashAndSourceIntegerStaysZero() throws {
        let unknown = try JSONDecoder().decode(MemberIdentitySnapshot.self, from: Data(MemberHomeFixtureData.unknownCounterJSON.utf8))
        XCTAssertEqual(unknown.friendCount, 0)
        XCTAssertEqual(unknown.followCount, 0)
        XCTAssertEqual(unknown.fansCount, 0)
        XCTAssertEqual(unknown.friendCountText, "—")
        XCTAssertEqual(unknown.followCountText, "—")
        XCTAssertEqual(unknown.fansCountText, "—")
        XCTAssertNotEqual(unknown.friendCountText, "0")
        XCTAssertEqual(unknown.topicCountText, "1")
        XCTAssertNil(unknown.friendCountFact.literal)
        let zero = try JSONDecoder().decode(MemberIdentitySnapshot.self, from: Data(MemberHomeFixtureData.zeroCounterJSON.utf8))
        XCTAssertEqual(zero.friendCountText, "0")
        XCTAssertEqual(zero.balanceText, "0.00")
        XCTAssertEqual(zero.balancePreviewText, "0.00")
        XCTAssertEqual(MemberHomePageModel.unknownDisplay, "—")
    }

    func testIdentityEnvelopeStatesDoNotInventNumbers() throws {
        XCTAssertEqual(MemberHomePageModel.classifyIdentity(data: Data(MemberHomeFixtureData.unknownEnvelope.utf8), status: 200), .unknown)
        XCTAssertEqual(MemberHomePageModel.classifyIdentity(data: Data(MemberHomeFixtureData.arrayEnvelope.utf8), status: 200), .unknown)
        XCTAssertEqual(MemberHomePageModel.classifyIdentity(data: Data(MemberHomeFixtureData.emptyEnvelope.utf8), status: 200), .empty)
        let rejected = MemberHomePageModel.classifyIdentity(data: Data(MemberHomeFixtureData.rejectedEnvelope.utf8), status: 200)
        XCTAssertEqual(rejected, .error(.init(httpStatus: 200, code: 500, message: "Synthetic rejection")))
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(.unknown), "member.card.unknownValue")
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(.empty), "member.card.empty")
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(.loading), "member.card.loading")
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(rejected), "member.card.failed")
        let signedOut = MemberHomePageModel.classifyIdentity(data: Data(#"{"code":2}"#.utf8), status: 200)
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(signedOut), "member.card.signedOut")
        let httpEmpty = MemberHomePageModel.classifyIdentity(data: Data(MemberHomeFixtureData.emptyEnvelope.utf8), status: 503)
        XCTAssertEqual(httpEmpty, .error(.init(httpStatus: 503, code: 200, message: nil)))
        let ready = MemberHomePageModel.classifyIdentity(data: MemberHomeFixtureData.envelope(MemberHomeFixtureData.unknownCounterJSON), status: 200)
        guard case .ready(.identity(let card)) = ready else { return XCTFail("\(ready)") }
        XCTAssertEqual(card.friendText, "—")
        XCTAssertEqual(card.topicText, "1")
        XCTAssertEqual(card.cityText, "—")
        XCTAssertEqual(card.levelText, "—")
        XCTAssertEqual(card.balanceText, "—")
        XCTAssertEqual(card.streakText, "—")
        let withStreak = MemberHomeIdentityReady(snapshot: try MemberHomeFixtureData.readyIdentity(), streakDays: 0)
        XCTAssertEqual(withStreak.streakText, "0")
        XCTAssertEqual(MemberHomeIdentityReady(snapshot: try MemberHomeFixtureData.readyIdentity(), streakDays: nil).streakText, "—")
        XCTAssertEqual(MemberHomeIdentityReady(snapshot: try MemberHomeFixtureData.readyIdentity(), streakDays: -3).streakText, "—")
    }

    func testRoleInfoEmptyUnknownAndMoneyWritesStayOff() throws {
        XCTAssertEqual(MemberHomePageModel.classifyRoleInfo(data: Data(MemberHomeFixtureData.unknownEnvelope.utf8), status: 200), .unknown)
        XCTAssertEqual(MemberHomePageModel.classifyRoleInfo(data: Data(MemberHomeFixtureData.emptyRoleEnvelope.utf8), status: 200), .empty)
        XCTAssertEqual(MemberHomePageModel.benefitsCopyKey(.empty), "member.benefits.unavailable")
        XCTAssertEqual(MemberHomePageModel.benefitsCopyKey(.unknown), "member.card.unknownValue")
        let missingClubs = try JSONDecoder().decode(MemberRoleInfo.self, from: Data(MemberHomeFixtureData.missingClubsRoleJSON.utf8))
        XCTAssertEqual(missingClubs.ownedClubCount, 0)
        XCTAssertEqual(missingClubs.ownedClubCountText, "—")
        let noClubs = try JSONDecoder().decode(MemberRoleInfo.self, from: Data(#"{"role":"player","ownedClubs":[]}"#.utf8))
        XCTAssertEqual(noClubs.ownedClubCount, 0)
        XCTAssertEqual(noClubs.ownedClubCountText, "0")
        let ready = MemberHomePageModel.classifyRoleInfo(data: MemberHomeFixtureData.envelope(MemberHomeFixtureData.readyRoleJSON), status: 200)
        guard case .ready(.benefits(let benefits)) = ready else { return XCTFail("\(ready)") }
        XCTAssertFalse(benefits.rows.contains { $0.opensEarnings })
        XCTAssertFalse(benefits.showsMerchantChoice)
        XCTAssertFalse(benefits.paymentEnabled)
        XCTAssertFalse(benefits.payoutEnabled)
        XCTAssertFalse(benefits.withdrawalEnabled)
        XCTAssertFalse(benefits.virtualGoodsEnabled)
        let earned = MemberHomePageModel.classifyRoleInfo(data: Data(#"{"code":200,"data":{"role":"player","permission":{"withdrawable":true}}}"#.utf8), status: 200)
        guard case .ready(.benefits(let unlocked)) = earned else { return XCTFail("\(earned)") }
        XCTAssertTrue(unlocked.rows.contains { $0.opensEarnings })
        XCTAssertFalse(unlocked.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        for capability in MemberHomePageCapability.allCases {
            let enabled = MemberHomePageModel.isEnabled(capability)
            XCTAssertEqual(enabled, capability == .identityRead || capability == .roleInfoRead)
        }
        XCTAssertEqual(MemberHomePageModel.wiredRoutes, [AuthEndpoint.userInfo.rawValue, MemberRoleInfoReadRoute.path])
    }

    func testPageReadsUseTheExistingRoutesOnly() async throws {
        let wire = MemberHomePageWire(MemberHomeFixtureData.envelope(MemberHomeFixtureData.readyIdentityJSON))
        let page = try await service(wire).identityPage(token: "synthetic-member")
        guard case .ready(.identity(let card)) = page else { return XCTFail("\(page)") }
        XCTAssertEqual(card.nickname, "Synthetic member")
        XCTAssertEqual(card.friendText, "3")
        XCTAssertEqual(card.likeText, "0")
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        let configuration = try APIConfiguration(baseURL: base)
        XCTAssertEqual(request.url, configuration.url(for: .userInfo))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.httpBody)
        let thrown = MemberHomePageWire(MemberHomeFixtureData.arrayEnvelope)
        do { _ = try await service(thrown).identity(token: "synthetic-member"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        let unknown = try await service(thrown).identityPage(token: "synthetic-member")
        XCTAssertEqual(unknown, .unknown)
        let roleWire = MemberHomePageWire(MemberHomeFixtureData.envelope(MemberHomeFixtureData.readyRoleJSON))
        _ = try await service(roleWire).roleInfoPage(token: "synthetic-member")
        let roleRequest = try XCTUnwrap(await roleWire.requests.first)
        XCTAssertEqual(roleRequest.url, base.appendingPathComponent(MemberRoleInfoReadRoute.path))
        XCTAssertTrue(MemberRoleInfoReadRoute.accepts(roleRequest, baseURL: base))
    }

    func testReaderKeepsBenefitsHiddenUntilApprovalAndExpiresUnauthorized() async throws {
        let wire = MemberHomePageWire(MemberHomeFixtureData.envelope(MemberHomeFixtureData.readyRoleJSON))
        var session = try MemberHomeSession(accountID: 7, epoch: 1, token: "synthetic-member", roleInfoApproval: nil)
        var expired = 0
        let reader = MemberHomeSessionReader(service: try service(wire), currentSession: { session }, onUnauthorized: { _ in expired += 1 })
        let hidden = await reader.benefitsPage()
        XCTAssertEqual(hidden, .empty)
        XCTAssertEqual(await wire.requests.count, 0)
        session = try MemberHomeSession(accountID: 7, epoch: 1, token: "synthetic-member", roleInfoApproval: UUID())
        let shown = await reader.benefitsPage()
        guard case .ready(.benefits(let shownBenefits)) = shown else { return XCTFail("\(shown)") }
        XCTAssertFalse(shownBenefits.withdrawalEnabled)
        XCTAssertEqual(await wire.requests.count, 1)
        let guest = MemberHomeSessionReader(service: try service(wire), currentSession: { nil })
        let signedOut = await guest.identityPage()
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(signedOut), "member.card.signedOut")
        let unauthorized = MemberHomePageWire(#"{"code":401}"#, status: 200)
        let expiring = MemberHomeSessionReader(service: try service(unauthorized), currentSession: { session }, onUnauthorized: { _ in expired += 1 })
        let failed = await expiring.identityPage()
        XCTAssertEqual(MemberHomePageModel.identityCopyKey(failed), "member.card.signedOut")
        XCTAssertEqual(expired, 1)
        let dormant = MemberHomeSessionReader(service: nil, currentSession: { session })
        XCTAssertEqual(await dormant.identityPage(), .empty)
    }
}
