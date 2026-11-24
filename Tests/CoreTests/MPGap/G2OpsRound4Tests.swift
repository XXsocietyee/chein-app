import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class G2OpsRound4Tests: XCTestCase {
    private final class StubTransport: HTTPTransport {
        let handler: (URLRequest) throws -> (Data, Int)
        var requests: [URLRequest] = []

        init(_ handler: @escaping (URLRequest) throws -> (Data, Int)) {
            self.handler = handler
        }

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try handler(request)
        }
    }

    private let baseConfig = try! APIConfiguration(baseURL: URL(string: "https://example.com")!)
    private let validToken = "valid-token-123456"

    func testClubRound4ModelsAndExportClient() async throws {
        let stop = ClubStoryStopLocation(name: "外滩", address: "中山东一路", latitude: 31.23, longitude: 121.49)
        XCTAssertTrue(stop.hasCoordinates)
        XCTAssertEqual(stop.mapActionTitle, "在地图中打开 外滩")

        var certDraft = ClubApplyCertImagesDraft(uploadedURLs: ["https://a/1.png", "https://a/2.png"])
        XCTAssertEqual(certDraft.remainingCapacity, 7)
        certDraft.failedIndices.insert(1)
        XCTAssertTrue(certDraft.failedIndices.contains(1))

        var range = FEReferenceRangeFilter(fromDate: "2026-11-01", toDate: "2026-11-24")
        XCTAssertTrue(range.isActive)
        let transport = StubTransport { _ in
            (Data(#"{"code":200,"data":{"url":"https://example.com/export.csv"}}"#.utf8), 200)
        }
        let client = ClubFEReferenceExportClient(configuration: baseConfig, transport: transport)
        let url = try await client.exportPayerCSV(range: range, token: validToken)
        XCTAssertEqual(url, "https://example.com/export.csv")
        range.clear()
        XCTAssertFalse(range.isActive)
    }

    func testMerchantRound4ModelsAndClient() async throws {
        var voice = MerchantAINPCVoiceSessionState()
        XCTAssertFalse(voice.isComplete)
        voice.recordedFilePaths = [0: "/tmp/0.m4a", 1: "/tmp/1.m4a", 2: "/tmp/2.m4a"]
        XCTAssertTrue(voice.isComplete)

        let transport = StubTransport { req in
            if req.url?.path.hasSuffix("deposit/status") == true {
                return (Data(#"{"code":200,"data":{"status":"PAID"}}"#.utf8), 200)
            }
            if req.url?.path.hasSuffix("merchant/list") == true {
                return (Data(#"{"code":200,"data":[{"id":1,"name":"书店"}]}"#.utf8), 200)
            }
            return (Data(#"{"code":200}"#.utf8), 200)
        }
        let client = MerchantRound4Client(configuration: baseConfig, transport: transport)
        let candidates = try await client.searchMerchantsForClaim(keyword: "书", token: validToken)
        XCTAssertEqual(candidates.first?.name, "书店")

        let gated = try await client.createCoopDepositApp(coopID: 5, token: validToken, allowsMoneyWrite: false)
        XCTAssertFalse(gated)

        try await client.acceptOperatorInvite(inviteToken: "inv-abc", token: validToken)
        let status = try await client.depositStatus(coopID: 5, token: validToken)
        XCTAssertEqual(status, "PAID")
    }

    func testAccountPublishRound4ModelsAndClient() async throws {
        let branch = ProjectEditBranchBlockDraft(question: "去哪？")
        XCTAssertEqual(branch.options.count, 2)
        let gallery = ProjectEditGalleryBlockDraft(imageURLs: ["1", "2"], columns: 9)
        XCTAssertEqual(gallery.columns, 4)

        let transport = StubTransport { _ in (Data(#"{"code":200}"#.utf8), 200) }
        let client = AccountPublishRound4Client(configuration: baseConfig, transport: transport)
        try await client.handleApplicant(teamID: 10, memberID: 20, approved: true, token: validToken)
        XCTAssertEqual(transport.requests.count, 1)
    }
}
