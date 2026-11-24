import XCTest
@testable import QuestifyCore

final class G2OpsGapTests: XCTestCase {
    func testClubCoopPoolCopyMatchesMP() {
        XCTAssertEqual(ClubCoopPoolCopy.sectionTitle, "可对接的活动")
        XCTAssertEqual(ClubCoopPoolCopy.applyModalTitle(topicName: "夜游"), "申请带队「夜游」")
        XCTAssertEqual(ClubCoopPoolCopy.applyModalTitle(topicName: "  "), "申请带队「该主题」")
    }

    func testFEReferenceSettlementMoneyWriteGateClosedByDefault() async throws {
        final class RecordingTransport: HTTPTransport {
            var count = 0
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                count += 1
                return (Data("{\"code\":200}".utf8), 200)
            }
        }
        let transport = RecordingTransport()
        let config = APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let client = ClubFEReferenceSettlementClient(configuration: config, transport: transport)

        let settled = try await client.markSettled(id: 42, token: "valid-token-123456", allowsMoneyWrite: false)
        XCTAssertFalse(settled)
        XCTAssertEqual(transport.count, 0)
    }

    func testCoopDepositMoneyWriteGateClosedByDefault() async throws {
        final class RecordingTransport: HTTPTransport {
            var count = 0
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                count += 1
                return (Data("{\"code\":200}".utf8), 200)
            }
        }
        let transport = RecordingTransport()
        let config = APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let client = MerchantGapOperationsClient(configuration: config, transport: transport)

        let created = try await client.createDeposit(coopID: 9, token: "valid-token-123456", allowsMoneyWrite: false)
        let retried = try await client.retryDepositRefund(coopID: 9, token: "valid-token-123456", allowsMoneyWrite: false)
        XCTAssertFalse(created)
        XCTAssertFalse(retried)
        XCTAssertEqual(transport.count, 0)
    }

    func testMerchantAIInsightGrowTipsRespectPermissions() {
        let none = MerchantAIInsightGrowTip.visibleTips(canCoop: false, canCityNode: false, canCoupon: false, canAINPC: false)
        XCTAssertTrue(none.isEmpty)

        let all = MerchantAIInsightGrowTip.visibleTips(canCoop: true, canCityNode: true, canCoupon: true, canAINPC: true)
        XCTAssertEqual(all.map(\.key), [.coop, .citynode, .coupon, .aiNpc])
    }

    func testTeamGapCopyAndMaxLength() {
        XCTAssertEqual(TeamGapCopy.maxJoinCodeLength, 40)
        XCTAssertEqual(TeamGapCopy.buyTicketCTA, "去买这一场的票")
        XCTAssertEqual(AccountPublishGapCopy.ownComposerPlaceholder, "有什么新鲜好玩的分享吗？")
    }
}
