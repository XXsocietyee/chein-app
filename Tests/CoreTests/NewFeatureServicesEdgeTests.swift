import XCTest
@testable import QuestifyCore

@MainActor final class NewFeatureServicesEdgeTests: XCTestCase {
    private final class StubTransport: HTTPTransport {
        var nextHandler: ((URLRequest) throws -> (Data, Int))?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            if let nextHandler { return try nextHandler(request) }
            return (Data(#"{"code":404,"errorCode":"NOT_FOUND"}"#.utf8), 404)
        }
    }

    private final class MockAudioCapturer: PlayAudioClipCapturing {
        var startError: Error?
        var stopClip: PlayRecordedAudioClip?
        var stopError: Error?
        private var interruptionHandler: (() -> Void)?
        private(set) var cancelled = false

        func startRecording(onInterruption: @escaping () -> Void) async throws {
            if let startError { throw startError }
            interruptionHandler = onInterruption
        }

        func stopRecording() async throws -> PlayRecordedAudioClip {
            if let stopError { throw stopError }
            guard let stopClip else { throw PlayExperienceError.invalidAction }
            return stopClip
        }

        func cancelRecording() {
            cancelled = true
        }

        func simulateInterruption() {
            interruptionHandler?()
        }
    }

    private let baseURL = URL(string: "https://city.example.test/prod-api/")!
    private var lease: CityGameProductionLease { CityGameProductionLease(host: "city.example.test", regionID: "r1")! }

    // MARK: - RoamTerritoryService

    func testRoamTerritoryValidationAndErrors() async throws {
        let stub = StubTransport()
        var current = true
        var unauthorizedCount = 0
        let service = try RoamTerritoryService(
            configuration: APIConfiguration(baseURL: baseURL),
            token: "tok-1",
            lease: lease,
            transport: stub,
            isCurrent: { current },
            onUnauthorized: { unauthorizedCount += 1 }
        )

        // Invalid latitude / radius caught before network.
        do {
            _ = try await service.nearby(lat: 91, lng: 120)
            XCTFail("Expected invalidRequest for out-of-range latitude")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidRequest)
        }
        do {
            _ = try await service.nearby(lat: 30, lng: 120, radius: 10)
            XCTFail("Expected invalidRequest for too-small radius")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidRequest)
        }

        // Non-https photoUrl rejected before network.
        do {
            _ = try await service.claim(.init(
                requestId: "req-bad-url",
                lat: 30.25,
                lng: 120.15,
                accuracyM: 8,
                photoUrl: "http://insecure.example/a.jpg",
                pointId: "p1"
            ))
            XCTFail("Expected invalidRequest for non-HTTPS photo URL")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidRequest)
        }

        // 401 invokes onUnauthorized and throws .unauthorized.
        stub.nextHandler = { _ in (Data(#"{"code":401,"errorCode":"UNAUTHORIZED"}"#.utf8), 401) }
        do {
            _ = try await service.myTerritories()
            XCTFail("Expected unauthorized")
        } catch let error as RoamTerritoryError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(unauthorizedCount, 1)
        }

        // 409/400 rejected preserves server code.
        stub.nextHandler = { _ in (Data(#"{"code":409,"errorCode":"TERRITORY_PROTECTED"}"#.utf8), 409) }
        do {
            _ = try await service.nearby(lat: 30.25, lng: 120.15)
            XCTFail("Expected rejected")
        } catch let error as RoamTerritoryError {
            XCTAssertEqual(error, .rejected(status: 409, code: "TERRITORY_PROTECTED", message: nil))
        }

        // Malformed 200 body throws .malformed.
        stub.nextHandler = { _ in (Data(#"{"code":200,"data":"not-an-object"}"#.utf8), 200) }
        do {
            _ = try await service.leaderboard(boardId: "b1")
            XCTFail("Expected malformed")
        } catch let error as RoamTerritoryError {
            XCTAssertEqual(error, .malformed)
        }

        // Stale viewer drops without hitting network.
        current = false
        do {
            _ = try await service.myTerritories()
            XCTFail("Expected notCurrent")
        } catch let error as RoamTerritoryError {
            XCTAssertEqual(error, .notCurrent)
        }
    }

    // MARK: - CityGameHTTPService Dice Errors

    func testCityGameDiceServiceErrors() async throws {
        let stub = StubTransport()
        var unauthorizedCount = 0
        var isCurrent = true
        let service = try CityGameHTTPService(
            configuration: APIConfiguration(baseURL: baseURL),
            token: "tok-1",
            lease: lease,
            transport: stub,
            isCurrent: { isCurrent },
            onUnauthorized: { unauthorizedCount += 1 }
        )

        // Limit out of 1...200 rejected before network.
        do {
            _ = try await service.diceAudit(boardId: "b1", limit: 999)
            XCTFail("Expected invalidRequest")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidRequest)
        }

        // 409 snapshotChanged.
        stub.nextHandler = { _ in (Data(#"{"code":409,"errorCode":"CITY_SNAPSHOT_CHANGED"}"#.utf8), 409) }
        do {
            _ = try await service.rollUnifiedDice(requestId: "req-1", boardId: "b1", expectedVersion: 2)
            XCTFail("Expected snapshotChanged")
        } catch let error as CityGameServiceError {
            XCTAssertEqual(error, .snapshotChanged)
        }

        // 401 unauthorized.
        stub.nextHandler = { _ in (Data(#"{"code":401}"#.utf8), 401) }
        do {
            _ = try await service.diceAudit(boardId: "b1", limit: 10)
            XCTFail("Expected unauthorized")
        } catch let error as CityGameServiceError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(unauthorizedCount, 1)
        }

        isCurrent = false
        do {
            _ = try await service.rollUnifiedDice(requestId: "req-2", boardId: "b1")
            XCTFail("Expected notCurrent")
        } catch let error as CityGameServiceError {
            XCTAssertEqual(error, .notCurrent)
        }
    }

    // MARK: - PlayAudioClipModel Edge Cases

    func testPlayAudioClipModelConfigurationAndErrorPaths() async throws {
        XCTAssertThrowsError(try PlayAudioClipConfiguration(minDurationSeconds: 0))
        XCTAssertThrowsError(try PlayAudioClipConfiguration(minDurationSeconds: 61))
        XCTAssertThrowsError(try PlayRecordedAudioClip(bytes: Data(), mimeType: "audio/mp4", durationSeconds: 3))
        XCTAssertThrowsError(try PlayRecordedAudioClip(bytes: Data([1, 2]), mimeType: "audio/mp4", durationSeconds: 61))

        let config = try PlayAudioClipConfiguration(minDurationSeconds: 5)
        let capturer = MockAudioCapturer()
        let model = PlayAudioClipModel(configuration: config, capturer: capturer)

        await model.start()
        XCTAssertEqual(model.phase, .recording)
        model.advanceElapsed(to: 5)
        XCTAssertTrue(model.meetsMinimumDuration)

        // Interruption transitions to .failed.
        capturer.simulateInterruption()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(model.failureReason, "interrupted")

        // Duration below minimum transitions to .failed.
        await model.start()
        capturer.stopClip = try PlayRecordedAudioClip(bytes: Data([0xAA, 0xBB]), mimeType: "audio/mp4", durationSeconds: 2)
        await model.stopAndUpload { _, _ in "https://cdn.example/a.m4a" }
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(model.failureReason, "duration_below_minimum")
        XCTAssertNil(model.sourcePayload)

        // Non-HTTPS URL rejected.
        await model.start()
        capturer.stopClip = try PlayRecordedAudioClip(bytes: Data([0xAA, 0xBB]), mimeType: "audio/mp4", durationSeconds: 6)
        await model.stopAndUpload { _, _ in "http://insecure.example/a.m4a" }
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(model.failureReason, "invalid_media_url")

        // Happy upload -> completed -> reset returns to .idle.
        await model.start()
        await model.stopAndUpload { _, _ in "https://cdn.example/valid.m4a" }
        XCTAssertEqual(model.phase, .completed)
        XCTAssertNotNil(model.sourcePayload)
        model.reset()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.sourcePayload)
    }

    // MARK: - CYScratchProgressTracker Edge Cases

    func testCYScratchProgressTrackerThresholdAndRevealAll() {
        XCTAssertEqual(CYScratchProgressTracker.clampThreshold(nil), CYScratchProgressTracker.defaultThreshold)
        XCTAssertEqual(CYScratchProgressTracker.clampThreshold(-1), CYScratchProgressTracker.defaultThreshold)
        XCTAssertEqual(CYScratchProgressTracker.clampThreshold(1.8), 1.0)

        var tracker = CYScratchProgressTracker(width: 64, height: 64, threshold: 0.4)
        // Small stroke stays below threshold.
        XCTAssertFalse(tracker.stamp(from: .init(x: 4, y: 4), to: .init(x: 6, y: 6), radius: 2))
        XCTAssertFalse(tracker.revealed)

        // Full sweep crosses threshold and only fires transition once.
        let crossed = tracker.stamp(from: .init(x: 0, y: 32), to: .init(x: 64, y: 32), radius: 32)
        XCTAssertTrue(crossed)
        XCTAssertTrue(tracker.revealed)
        XCTAssertFalse(tracker.revealAll())
    }

    // MARK: - ExternalGameReviewClient Monetization & Sessions

    func testExternalGameReviewClientMonetizationAndSessionPaths() async throws {
        let stub = StubTransport()
        let config = try APIConfiguration(baseURL: URL(string: "https://8120.example.test")!)
        let client = ExternalGameReviewClient(
            configuration: config,
            transport: stub,
            nowMillis: { 1_700_000_000_000 },
            entropy: { "entropy-1" }
        )

        // Malformed / unauthorized monetization read returns nil cleanly.
        stub.nextHandler = { _ in (Data(#"{"code":500}"#.utf8), 500) }
        let nilCfg = await client.monetizationConfig(gameID: "bad id!", token: "tok-1")
        XCTAssertNil(nilCfg)
        let summaryErr = await client.creatorSummary(token: "tok-1")
        XCTAssertNil(summaryErr)

        // Valid saveMonetizationConfig & creatorSummary.
        stub.nextHandler = { req in
            let path = req.url?.path ?? ""
            if req.httpMethod == "PUT", path == ExternalGameReviewPaths.monetization("westlake-treasure") {
                return (Data(#"{"code":200,"data":{"gameId":"westlake-treasure","gameName":"西湖寻宝","pricingMode":"PAID","priceFen":800,"currency":"CNY","creatorShareBps":7000,"channelFeeBearer":0,"trafficRewardMode":"POINTS","rewardPerPlayPoints":12,"rewardPerPlayFen":0,"dailyUserCap":5,"dailyGameCap":100,"minDurationMs":15000,"reviewStatus":"PENDING","entitled":false,"isOwner":true,"moneyGateOpen":false}}"#.utf8), 200)
            }
            if path == ExternalGameReviewPaths.creatorSummary {
                return (Data(#"{"code":200,"data":{"paidOrders":3,"grossSalesFen":2400,"creatorSalesNetFen":1680,"trafficValidPlays":21,"trafficSettledPoints":252,"trafficSettledFen":0,"moneyGateOpen":false,"payoutGateOpen":false,"configs":[]}}"#.utf8), 200)
            }
            if req.httpMethod == "PUT", path == ExternalGameReviewPaths.nodeBinding(42) {
                return (Data(#"{"code":200,"data":{"bound":true}}"#.utf8), 200)
            }
            return (Data(#"{"code":404}"#.utf8), 404)
        }
        let saved = await client.saveMonetizationConfig(
            gameID: "westlake-treasure",
            pricingMode: "PAID",
            priceFen: 800,
            trafficRewardMode: "POINTS",
            channelFeeBearer: 0,
            token: "tok-1"
        )
        XCTAssertEqual(saved?.priceFen, 800)
        XCTAssertEqual(saved?.reviewStatus, "PENDING")

        let summary = await client.creatorSummary(token: "tok-1")
        XCTAssertEqual(summary?.paidOrders, 3)
        XCTAssertEqual(summary?.trafficSettledPoints, 252)

        let bound = await client.bindNode(nodeID: 42, gameID: "westlake-treasure", minScore: 60, requirePass: true, token: "tok-1")
        XCTAssertTrue(bound)
    }

    // MARK: - WorldEnvironmentProjection & Random Drop / Task

    func testWorldEnvironmentProjectionAndRandomModels() {
        XCTAssertEqual(WorldEnvironmentProjection.read(.null).availability, .unknown)
        XCTAssertEqual(WorldEnvironmentProjection.read(.object(["other": .int(1)])).availability, .waitingSource)
        let partial = WorldEnvironmentProjection.read(.object([
            "environment": .object([
                "weather": .string("rain"),
                "season": .string("unknown"),
            ])
        ]))
        XCTAssertEqual(partial.availability, .ready)
        XCTAssertEqual(partial.weather, .known("rain"))
        XCTAssertEqual(partial["season"], .unknown)

        let task = PlayRandomDispatchedTask.fromResponse(.object([
            "dispatchedTask": .object(["nodeId": .int(19), "nodeName": .string("孤山凉亭")])
        ]))
        XCTAssertEqual(task?.displayName, "孤山凉亭")
        XCTAssertEqual(task?.revealTitle(locale: Locale(identifier: "zh-Hans")), "今日盲盒任务：孤山凉亭")
        XCTAssertEqual(task?.revealTitle(locale: Locale(identifier: "en")), "Today's Mystery Task: 孤山凉亭")

        let drop = PlayRewardDrop.fromReward(.object([
            "drop": .object(["dropType": .int(1), "label": .string("双倍积分卡"), "extraXp": .int(50)])
        ]))
        XCTAssertNotNil(drop)
        XCTAssertTrue(drop?.toastMessage(locale: Locale(identifier: "zh-Hans")).contains("双倍积分卡") == true)
    }

    // MARK: - Shop NPC live path (the unserved /api/ai/npc/dialogue method is gone)

    func testShopNPCTextUsesShopChatAndRateLimits() async throws {
        final class RateLimitTransport: ShopNPCHTTPTransport {
            var paths: [String] = []
            func perform(_ request: ShopNPCHTTPRequest) async throws -> ShopNPCHTTPResponse {
                paths.append(request.path)
                return ShopNPCHTTPResponse(status: 429, body: Data())
            }
        }
        let http = RateLimitTransport()
        let client = ShopNPCHTTPClient(transport: http)
        let nodeID = try XCTUnwrap(ShopNPCNodeID(20))
        let scope = ShopNPCScope(sessionID: "sess-1", accountID: "1", roleID: "player", accessRevision: 1, nodeID: nodeID)
        do {
            _ = try await client.text("茶馆主人还在吗？", requestID: UUID(), scope: scope)
            XCTFail("Expected rateLimited")
        } catch let err as ShopNPCFailure {
            XCTAssertEqual(err, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(http.paths, ["/api/ai/npc/shop-chat"])
    }
}
