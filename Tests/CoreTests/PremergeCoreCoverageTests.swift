import XCTest
import CryptoKit
import Foundation
@testable import QuestifyCore

private actor PremergeStubHTTPTransport: HTTPTransport {
    private let handler: @Sendable (URLRequest) async throws -> (Data, Int)
    private(set) var recordedRequests: [URLRequest] = []

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, Int)) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        recordedRequests.append(request)
        return try await handler(request)
    }
}

@MainActor
final class PremergeCoreCoverageTests: XCTestCase {
    private let signer = ExternalGameFixtureSigner()

    // MARK: - ExternalGameValidator & Entry Integrity

    func testComputeDataSHA256MatchesCryptoKitLowercaseHex() {
        let payload = Data("hangzhou-westlake-quest".utf8)
        let expected = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(ExternalGameValidator.computeDataSHA256(payload), expected)
        XCTAssertEqual(ExternalGameValidator.computeDataSHA256(payload).count, 64)
        XCTAssertNotEqual(
            ExternalGameValidator.computeDataSHA256(payload),
            ExternalGameValidator.computeDataSHA256(Data("hangzhou-westlake-quest!".utf8))
        )
    }

    func testInstalledEntryIntegrityDetectsTamperingAndMissingEntry() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PremergeExternalGameTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = ExternalGameStore(rootDirectory: tempDir, verificationPublicKey: signer.publicKey)
        let archive = ExternalGameStore.makeSampleSignedArchive(
            id: "rpg.premerge.integrity",
            name: "完整性校验示例",
            version: "1.0.0",
            entry: "index.html",
            permissions: ["storage"],
            contentRating: "4+",
            allowedDomains: ["assets.example.com"],
            sign: signer.signPayload
        )
        _ = try store.prepareImport(archive: archive, source: .url(URL(string: "https://example.com/pkg.json")!))
        let installed = try store.confirmInstall()

        let entryURL = try XCTUnwrap(store.entryFileURL(for: installed))
        XCTAssertTrue(FileManager.default.fileExists(atPath: entryURL.path))

        // Tampering with entry bytes must fail hardened SHA-256 verification.
        let originalData = try Data(contentsOf: entryURL)
        try Data("<html><body>tampered</body></html>".utf8).write(to: entryURL, options: .atomic)
        XCTAssertNil(store.entryFileURL(for: installed))

        // Restore original bytes -> integrity check recovers.
        try originalData.write(to: entryURL, options: .atomic)
        XCTAssertEqual(store.entryFileURL(for: installed)?.lastPathComponent, "index.html")

        // Removing entry file on disk must fail integrity check.
        try FileManager.default.removeItem(at: entryURL)
        XCTAssertNil(store.entryFileURL(for: installed))
    }

    // MARK: - MoneyPassExpiry.playableInstant

    func testPlayableInstantRollsBackChinaMidnightByOneMillisecond() throws {
        // 2026-11-15 00:00:00.000 +08:00 == 2026-11-14 16:00:00.000 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3600))
        let midnightDate = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 0, minute: 0, second: 0)))
        let midnightMs = Int64(midnightDate.timeIntervalSince1970 * 1000)

        let rolled = MoneyPassExpiry.playableInstant(midnightMs)
        XCTAssertEqual(rolled, midnightMs - 1)
        XCTAssertEqual(MoneyParityTime.chinaDayIndex(rolled), MoneyParityTime.chinaDayIndex(midnightMs) - 1)

        // One second past midnight remains on the same instant/day.
        let nonMidnightMs = midnightMs + 1000
        XCTAssertEqual(MoneyPassExpiry.playableInstant(nonMidnightMs), nonMidnightMs)
        XCTAssertEqual(MoneyParityTime.chinaDayIndex(nonMidnightMs), MoneyParityTime.chinaDayIndex(midnightMs))
    }

    // MARK: - RewardPledgeRoutes Template Rendering

    func testRewardPledgeRoutesRenderTemplateAndOperation() throws {
        let renderedOffer = RewardPledgeRoutes.renderTemplate(
            RewardPledgeRoutes.offerTemplate,
            name: "versionId",
            value: "ver_42"
        )
        XCTAssertEqual(renderedOffer, "api/rewards/noncash/versions/ver_42")

        let base = URL(string: "https://example.test/native/")!
        var offerReq = URLRequest(url: base.appendingPathComponent(renderedOffer)
            .appending(queryItems: [URLQueryItem(name: "branch", value: "THEME"), URLQueryItem(name: "subjectId", value: "sub_9")]))
        offerReq.httpMethod = "GET"
        XCTAssertEqual(RewardPledgeRoutes.operation(offerReq, baseURL: base), "offer")

        let catalogPath = RewardPledgeRoutes.renderTemplate(RewardPledgeRoutes.catalogTemplate, name: "subjectId", value: "sub_9")
        var catalogReq = URLRequest(url: base.appendingPathComponent(catalogPath))
        catalogReq.httpMethod = "GET"
        XCTAssertEqual(RewardPledgeRoutes.operation(catalogReq, baseURL: base), "catalog")

        let withdrawPath = RewardPledgeRoutes.renderTemplate(RewardPledgeRoutes.withdrawTemplate, name: "versionId", value: "ver_42")
        var withdrawReq = URLRequest(url: base.appendingPathComponent(withdrawPath))
        withdrawReq.httpMethod = "POST"
        XCTAssertEqual(RewardPledgeRoutes.operation(withdrawReq, baseURL: base), "withdraw")

        let holdPath = RewardPledgeRoutes.renderTemplate(RewardPledgeRoutes.holdTemplate, name: "versionId", value: "ver_42")
        var holdReq = URLRequest(url: base.appendingPathComponent(holdPath))
        holdReq.httpMethod = "POST"
        XCTAssertEqual(RewardPledgeRoutes.operation(holdReq, baseURL: base), "hold")
    }

    // MARK: - RoamPresenceVisibilityService & Consent Feedback

    func testRoamPresenceVisibilityServiceCoversSuccessRejectionUnavailableAndFailure() async throws {
        let config = try APIConfiguration(baseURL: URL(string: "https://example.test/native")!)

        // Invalid / missing tokens must fail closed as .unavailable without hitting transport.
        let unusedTransport = PremergeStubHTTPTransport { _ in
            XCTFail("Transport should not be called for invalid token")
            return (Data(), 500)
        }
        let unauthService = RoamPresenceVisibilityService(configuration: config, transport: unusedTransport)
        let nilTokenOutcome = await unauthService.disablePresence(token: nil)
        let shortTokenOutcome = await unauthService.disablePresence(token: " ")
        XCTAssertEqual(nilTokenOutcome, .unavailable)
        XCTAssertEqual(shortTokenOutcome, .unavailable)

        // Valid 200 with data=false -> .disabled
        let disabledTransport = PremergeStubHTTPTransport { _ in
            (Data(#"{"code":200,"data":false}"#.utf8), 200)
        }
        let disabledOutcome = await RoamPresenceVisibilityService(configuration: config, transport: disabledTransport)
            .disablePresence(token: "valid-premerge-token-12345")
        XCTAssertEqual(disabledOutcome, .disabled)

        // Non-200 business code -> .rejected(msg)
        let rejectedTransport = PremergeStubHTTPTransport { _ in
            (Data(#"{"code":409,"msg":"状态冲突"}"#.utf8), 200)
        }
        let rejectedOutcome = await RoamPresenceVisibilityService(configuration: config, transport: rejectedTransport)
            .disablePresence(token: "valid-premerge-token-12345")
        XCTAssertEqual(rejectedOutcome, .rejected("状态冲突"))

        // Transport error -> .failed
        let throwingTransport = PremergeStubHTTPTransport { _ in
            throw URLError(.notConnectedToInternet)
        }
        let failedOutcome = await RoamPresenceVisibilityService(configuration: config, transport: throwingTransport)
            .disablePresence(token: "valid-premerge-token-12345")
        XCTAssertEqual(failedOutcome, .failed)
    }

    func testRoamConsentWithdrawalFeedbackTransitions() {
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .complete, error: nil),
            .withdrawn
        )
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .complete, current: .complete, error: nil),
            .idle
        )
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .serverConfirmed, error: "local fail"),
            .partialLocalPending
        )
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .trackingStopped, error: "local fail"),
            .partialLocalPending
        )
        XCTAssertEqual(
            RoamConsentWithdrawalFeedback.evaluate(previous: .idle, current: .idle, error: "network fail"),
            .failed
        )
    }

    // MARK: - SettingsClubPickerService

    func testSettingsClubPickerServiceOutcomes() async throws {
        let config = try APIConfiguration(baseURL: URL(string: "https://example.test/native")!)

        // Unauthenticated -> .applyForHost
        let emptyOutcome = await SettingsClubPickerService(
            configuration: config,
            transport: PremergeStubHTTPTransport { _ in (Data(), 500) }
        ).resolveEntry(token: nil)
        XCTAssertEqual(emptyOutcome, .applyForHost)

        // Multiple clubs -> .chooseClub
        let multiTransport = PremergeStubHTTPTransport { _ in
            (Data(#"{"code":200,"data":{"owned":[{"id":1,"name":"西湖夜跑团"},{"id":2,"name":"运河城市探索"}]}}"#.utf8), 200)
        }
        let multiOutcome = await SettingsClubPickerService(configuration: config, transport: multiTransport)
            .resolveEntry(token: "valid-premerge-token-12345")
        if case .chooseClub(let clubs) = multiOutcome {
            XCTAssertEqual(clubs.map(\.name), ["西湖夜跑团", "运河城市探索"])
        } else {
            XCTFail("Expected .chooseClub, got \(multiOutcome)")
        }

        // Network URLError -> networkFailureMessage
        let urlErrTransport = PremergeStubHTTPTransport { _ in throw URLError(.timedOut) }
        let urlErrOutcome = await SettingsClubPickerService(configuration: config, transport: urlErrTransport)
            .resolveEntry(token: "valid-premerge-token-12345")
        XCTAssertEqual(urlErrOutcome, .failed(message: SettingsClubPickerService.networkFailureMessage))
    }

    // MARK: - InvoiceIssuerSelectionGuard Fallback Grouping

    func testInvoiceIssuerGroupingUsesDeterministicFallbackTitlesWhenNameBlank() throws {
        let json = """
        [
          {"orderId":101,"issuerId":88,"issuerName":"  ","amount":128.00},
          {"orderId":102,"issuerId":null,"issuerName":null,"amount":68.00}
        ]
        """
        let orders = try JSONDecoder().decode([InvoiceLaunchOrder].self, from: Data(json.utf8))
        let groups = InvoiceIssuerSelectionGuard.group(orders: orders)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].issuerTitle, "开票单位 #88")
        XCTAssertTrue(groups[0].isEnabled)
        XCTAssertEqual(groups[1].issuerTitle, InvoiceIssuerSelectionGuard.unenabledIssuerMessage)
        XCTAssertFalse(groups[1].isEnabled)
    }
}
