import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Owner 2026-11-24. Each decision has a default and a test that pins it.
final class OwnerDecisions1124Tests: XCTestCase {
    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body = Data(#"{"code":200,"data":[]}"#.utf8)
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (body, 200)
        }
    }

    // MARK: D1

    func testPlatformPassOrderReadIsOnForPlayersAndIsNotAMoneyWrite() async throws {
        XCTAssertTrue(PlatformPass.orderReadsEnabled)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/platform-pass/orders"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/platform-pass/orders"))
        XCTAssertTrue(ChinaReviewedRouteCapability.platformPassOrderReadGrant.contains("/api/platform-pass/orders/{}"))

        let china = URL(string: "https://www.chengyinhub.com/prod-api/api/platform-pass/orders")!
        var get = URLRequest(url: china)
        get.httpMethod = "GET"
        XCTAssertNoThrow(try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(get))
        var post = URLRequest(url: china)
        post.httpMethod = "POST"
        XCTAssertTrue(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(post))
        XCTAssertThrowsError(try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(post))

        let wire = Wire()
        let reader = try PlatformPass(configuration: APIConfiguration(baseURL: URL(string: "https://fixture.example.test")!), transport: wire)
        let orders = try await reader.passOrders(token: "session-token", viewerIsMerchant: false)
        XCTAssertTrue(orders.isEmpty)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].httpMethod, "GET")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/platform-pass/orders")
        let merchant = try await reader.passOrders(token: "session-token", viewerIsMerchant: true)
        XCTAssertTrue(merchant.isEmpty)
        XCTAssertEqual(wire.requests.count, 1, "a merchant does not read pass orders")
        XCTAssertThrowsError(try reader.purchase(planCode: "YEAR", channel: "XPAY", token: "session-token"))
        XCTAssertEqual(wire.requests.count, 1)
    }

    // MARK: D2

    func testRefundAndHostCancelStayOffUntilATestDerivationOpensThem() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.hostCancelRefundEnabled)
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/registration/cancel-refund"), .refund)
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/registration/cancel-by-owner"), .refund)
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/free-explore/bundle/order/refund"), .refund)
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/activity/cancel"), .hostCancelRefund)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/activity/cancel_preview"))
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/registration/cancel"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/cancel-refund"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/activity/cancel"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/registration/cancel-refund"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/activity/cancel"))

        let wire = Wire()
        let configuration = try APIConfiguration(baseURL: URL(string: "https://fixture.example.test")!)
        let cancel = await MainActor.run {
            ActivityHostCancelHTTPAccess(configuration: configuration, transport: wire, enabled: { true }, session: { (3, "synthetic-token") })
        }
        do { _ = try await cancel.cancel(activityID: 9, reason: "rain"); XCTFail("host cancel must not send") }
        catch { XCTAssertEqual(error as? ActivityHostCancelFailure, .disabled) }
        XCTAssertTrue(wire.requests.isEmpty)
        _ = try await cancel.preview(activityID: 9)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/activity/cancel_preview")

        let source = try String(contentsOf: sourceURL("Core/ChinaReviewedRouteCapability.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.components(separatedBy: "public enum ReleaseMoneyWriteSwitch {").last)
        XCTAssertTrue(body.contains("public static var refundEnabled: Bool { testDerivation?(.refund) ?? false }"))
        XCTAssertTrue(body.contains("public static var hostCancelRefundEnabled: Bool { testDerivation?(.hostCancelRefund) ?? false }"))
        XCTAssertFalse(body.contains("public static let refundEnabled = false"))
        XCTAssertFalse(body.contains("public static let hostCancelRefundEnabled = false"))
    }

    // MARK: D3

    func testMediaUploadRetriesOnlyAnIdempotentTransportFailureUpToThreeTimes() async throws {
        XCTAssertEqual(MediaUploadRetry.delay(afterFailure: 1), 0.2, accuracy: 0.001)
        XCTAssertEqual(MediaUploadRetry.delay(afterFailure: 2), 0.4, accuracy: 0.001)
        var sleeps: [TimeInterval] = []
        var attempts = 0
        do {
            _ = try await MediaUploadRetry.perform(idempotent: true, sleep: { sleeps.append($0) }) { attempt in
                attempts = attempt
                throw MediaUploadRetryError.transport
            }
            XCTFail("exhausted retry must throw")
        } catch {
            XCTAssertEqual(error as? MediaUploadRetryError, .transport)
        }
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(sleeps, [0.2, 0.4])

        var once = 0
        do {
            _ = try await MediaUploadRetry.perform(idempotent: false, sleep: { _ in XCTFail("non-idempotent write must not wait") }) { attempt in
                once = attempt
                throw MediaUploadRetryError.transport
            }
            XCTFail("the single attempt must throw")
        } catch {
            XCTAssertEqual(error as? MediaUploadRetryError, .transport)
        }
        XCTAssertEqual(once, 1)

        var rejected = 0
        do {
            _ = try await MediaUploadRetry.perform(idempotent: true, sleep: { _ in XCTFail("a rejection must not retry") }) { attempt in
                rejected = attempt
                throw MediaUploadRetryError.rejected
            }
        } catch {
            XCTAssertEqual(error as? MediaUploadRetryError, .rejected)
        }
        XCTAssertEqual(rejected, 1)

        let value = try await MediaUploadRetry.perform(idempotent: true, sleep: { _ in }) { attempt -> String in
            if attempt < 2 { throw MediaUploadRetryError.transport }
            return "ok"
        }
        XCTAssertEqual(value, "ok")
    }

    // MARK: D4

    func testMerchantStaffApprovalMatchesTheAuditContractAndChecksPermission() async throws {
        let owner = try JSONDecoder().decode(MerchantAccess.self, from: Data(#"{"active":true,"merchant":{"id":3,"name":"店"},"roleCode":"MERCHANT_OWNER","permissions":[]}"#.utf8))
        let staff = try JSONDecoder().decode(MerchantAccess.self, from: Data(#"{"active":true,"merchant":{"id":3},"roleCode":"MERCHANT_MANAGER","permissions":["merchant:project:manage"]}"#.utf8))
        let finance = try JSONDecoder().decode(MerchantAccess.self, from: Data(#"{"active":true,"merchant":{"id":3},"roleCode":"MERCHANT_FINANCE","permissions":["merchant:finance:read"]}"#.utf8))
        XCTAssertTrue(MerchantStaffApproval.allows(owner))
        XCTAssertTrue(MerchantStaffApproval.allows(staff))
        XCTAssertFalse(MerchantStaffApproval.allows(finance))
        XCTAssertEqual(MerchantStaffApproval.listPath, "api/merchant/chapter-application/owner-list")
        XCTAssertEqual(MerchantStaffApproval.auditPath, "api/merchant/chapter-application/audit")

        let wire = Wire()
        wire.body = Data(#"{"code":200,"data":{"rows":[{"applicationId":7,"topicId":3,"chapterTitle":"序章","applicantName":"林","status":0},{"applicationId":8,"status":1}]}}"#.utf8)
        let client = MerchantStaffApprovalClient(configuration: try APIConfiguration(baseURL: URL(string: "https://fixture.example.test")!), transport: wire, token: "synthetic-token")
        do { _ = try await client.pending(topicID: 3, access: finance); XCTFail("finance must not list") }
        catch { XCTAssertEqual(error as? MerchantStaffApprovalFailure, .denied) }
        XCTAssertTrue(wire.requests.isEmpty)

        let rows = try await client.pending(topicID: 3, access: staff)
        XCTAssertEqual(rows.map(\.id), [7])
        XCTAssertEqual(rows[0].title, "序章")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/merchant/chapter-application/owner-list")
        let listed = try JSONSerialization.jsonObject(with: XCTUnwrap(wire.requests[0].httpBody)) as? [String: Any]
        XCTAssertEqual(listed?["topicId"] as? Int, 3)

        do { try await client.decide(applicationID: 7, approved: false, remark: "  ", access: staff); XCTFail("reject needs a remark") }
        catch { XCTAssertEqual(error as? MerchantStaffApprovalFailure, .reasonRequired) }
        XCTAssertEqual(wire.requests.count, 1)

        try await client.decide(applicationID: 7, approved: true, remark: "", access: owner)
        let approved = try JSONSerialization.jsonObject(with: XCTUnwrap(wire.requests[1].httpBody)) as? [String: Any]
        XCTAssertEqual(wire.requests[1].url?.path, "/api/merchant/chapter-application/audit")
        XCTAssertEqual(approved?["applicationId"] as? Int, 7)
        XCTAssertEqual(approved?["approved"] as? Bool, true)

        try await client.decide(applicationID: 7, approved: false, remark: "资料不全", access: staff)
        let rejected = try JSONSerialization.jsonObject(with: XCTUnwrap(wire.requests[2].httpBody)) as? [String: Any]
        XCTAssertEqual(rejected?["approved"] as? Bool, false)
        XCTAssertEqual(rejected?["auditRemark"] as? String, "资料不全")
    }

    // MARK: D5

    func testSharedMoneyFormatterUsesTwoDecimals() {
        XCTAssertEqual(MoneyDisplay.current, .twoDecimals)
        XCTAssertEqual(MoneyDisplay.yuan(fen: 1250), "¥12.50")
        XCTAssertEqual(MoneyDisplay.yuan(fen: 0), "¥0.00")
        XCTAssertEqual(MoneyDisplay.yuan(fen: 1), "¥0.01")
        XCTAssertEqual(MoneyDisplay.yuan(fen: -255), "-¥2.55")
        XCTAssertEqual(ClubEnrollmentSessionMoney.yuanText(.integer(1050)), "¥10.50")
    }

    // MARK: D6

    func testNextChapterOpensOnlyOnArrivalAndWGS84BandStaysALocalAccuracyFailure() throws {
        XCTAssertFalse(ChapterArrivalLock.opens(arrivedAtStop: false, chapterLocked: false))
        XCTAssertFalse(ChapterArrivalLock.opens(arrivedAtStop: false, chapterLocked: nil))
        XCTAssertTrue(ChapterArrivalLock.opens(arrivedAtStop: true, chapterLocked: nil))
        XCTAssertTrue(ChapterArrivalLock.opens(arrivedAtStop: true, chapterLocked: false))
        XCTAssertFalse(ChapterArrivalLock.opens(arrivedAtStop: true, chapterLocked: true))

        let away = try PlayLeadProgress(PlayExperienceSyntheticFixtures.wire(
            #"{"exists":true,"isLeader":true,"leaderMemberId":9001,"arrived":1,"meArrived":false,"members":[{"memberId":9001,"arrived":true}]}"#))
        XCTAssertTrue(away.allArrived)
        XCTAssertFalse(away.allows(.unlockChapter, accountID: 9001))
        let here = try PlayLeadProgress(PlayExperienceSyntheticFixtures.wire(
            #"{"exists":true,"isLeader":true,"leaderMemberId":9001,"arrived":1,"meArrived":true,"members":[{"memberId":9001,"arrived":true}]}"#))
        XCTAssertTrue(here.allows(.unlockChapter, accountID: 9001))

        let coordinate = try XCTUnwrap(RoamCoordinate(latitude: 30, longitude: 120))
        let now = Date()
        let band = try RoamDeviceFix(coordinate: coordinate, accuracyMeters: 150, measuredAt: now, datum: .wgs84)
        XCTAssertTrue(PlayArrivalProjection.isUnprojectableAccuracy(band))
        let tight = try RoamDeviceFix(coordinate: coordinate, accuracyMeters: 80, measuredAt: now, datum: .wgs84)
        XCTAssertFalse(PlayArrivalProjection.isUnprojectableAccuracy(tight))
        let marked = try RoamDeviceFix(coordinate: coordinate, accuracyMeters: 150, measuredAt: now, datum: .gcj02)
        XCTAssertFalse(PlayArrivalProjection.isUnprojectableAccuracy(marked))
        let archive = try String(contentsOf: sourceURL("Core/FreeExplorationStoryArchive.swift"), encoding: .utf8)
        XCTAssertTrue(archive.contains("ChapterArrivalLock.opens"))
        let projection = try String(contentsOf: sourceURL("Core/RuntimeLocationProjection.swift"), encoding: .utf8)
        XCTAssertFalse(projection.contains("ChapterArrivalLock"))
    }

    // MARK: D7

    func testPlayKitPilotGateIsOffUntilAnEventIsAdded() throws {
        defer { PlayKitPilotGate.pilotEventIDs = [] }
        PlayKitPilotGate.pilotEventIDs = []
        XCTAssertFalse(PlayKitPilotGate.allows(eventID: nil))
        XCTAssertFalse(PlayKitPilotGate.allows(eventID: 41))
        PlayKitPilotGate.pilotEventIDs = [41]
        XCTAssertTrue(PlayKitPilotGate.allows(eventID: 41))
        XCTAssertFalse(PlayKitPilotGate.allows(eventID: 42))
        let source = try String(contentsOf: sourceURL("Core/PlayKitPilotGate.swift"), encoding: .utf8)
        let release = try XCTUnwrap(source.components(separatedBy: "#else").last?.components(separatedBy: "#endif").first)
        XCTAssertTrue(release.contains("public static func allows(eventID: Int?) -> Bool { false }"))
        let view = try String(contentsOf: sourceURL("App/PlayExperienceView.swift"), encoding: .utf8)
        XCTAssertTrue(view.contains("PlayKitPilotGate.allows(eventID: result.topicID)"))
    }

    // MARK: D8

    func testProductionCastStaysOnFixturesAndSendsNoneOfTheThreeRoutes() async throws {
        XCTAssertTrue(CastCapability.productionEnabled.isEmpty)
        let cast = try String(contentsOf: sourceURL("Core/CastService.swift"), encoding: .utf8)
        XCTAssertTrue(cast.contains("public static let productionEnabled: Set<CastCapability> = []"))
        let coordinator = try String(contentsOf: sourceURL("Core/PlayExperienceCoordinator.swift"), encoding: .utf8)
        XCTAssertTrue(coordinator.contains("enabled: CastCapability.productionEnabled"))
        XCTAssertFalse(coordinator.contains("/api/topic/cast/voice"))
        XCTAssertFalse(coordinator.contains("/api/play/run/profile"))
        XCTAssertFalse(coordinator.contains("/api/play/run/branch"))

        let wire = Wire()
        let service = CastService(
            configuration: try APIConfiguration(baseURL: URL(string: ReviewedMarketLaunch.chinaProductionBaseURL)!),
            transport: wire,
            enabled: [.castProfile, .castVoice, .castBranch])
        do { _ = try await service.castVoice(topicID: 3, chapterID: 1, blockKey: "intro", token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        do { try await service.saveCastProfile(runID: 4, profile: CastPlayerProfile(name: "林", identityKey: nil), token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        do { _ = try await service.recordCastBranch(runID: 4, chapterID: 1, blockKey: "intro", optionIndex: 0, token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    private func sourceURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
    }
}
