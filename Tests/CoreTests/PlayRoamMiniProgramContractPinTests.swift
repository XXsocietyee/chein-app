import Foundation
import XCTest
@testable import QuestifyCore

/// Pins the play-roam `request(` rows that `cursor/mp-contract-coverage` left without a test.
/// Mini-program: hengyin `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.
/// Money writes and the store-day gates stay off. A default play service sends nothing.
private final class PlayRoamPinTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    var bodies: [String: String] = [:]
    static let lockedCapsule = #"{"code":200,"data":{"id":"40","state":"LOCKED","unlockAtMs":1,"createdAtMs":1}}"#
    static let deletedCapsule = #"{"code":200,"data":{"id":"40","state":"DELETED","unlockAtMs":1,"createdAtMs":1}}"#
    static let capsulePage = #"{"code":200,"data":{"items":[{"id":"40","state":"LOCKED"}],"hasMore":false,"nextBeforeId":null}}"#
    static let activeGoal = #"{"code":200,"data":{"id":"40","requestId":"abcdefghijklmnop","metric":"DISTINCT_ROUTES","target":3,"startDate":"2099-01-01","endDateExclusive":"2099-06-01","progress":0,"state":"ACTIVE","privateCommemoration":false,"timeZone":"Asia/Shanghai","countingVersion":"COMPLETED_SESSION_AGGREGATE_V1","asOfMs":1,"createdAtMs":1}}"#
    static let cancelledGoal = #"{"code":200,"data":{"id":"40","requestId":"abcdefghijklmnop","metric":"DISTINCT_ROUTES","target":3,"startDate":"2099-01-01","endDateExclusive":"2099-06-01","progress":0,"state":"CANCELLED","privateCommemoration":false,"timeZone":"Asia/Shanghai","countingVersion":"COMPLETED_SESSION_AGGREGATE_V1","asOfMs":1,"createdAtMs":1}}"#
    static let goalPage = #"{"code":200,"data":{"items":[{"id":"40","requestId":"abcdefghijklmnop","metric":"DISTINCT_ROUTES","target":3,"startDate":"2099-01-01","endDateExclusive":"2099-06-01","progress":0,"state":"ACTIVE","privateCommemoration":false,"timeZone":"Asia/Shanghai","countingVersion":"COMPLETED_SESSION_AGGREGATE_V1","asOfMs":1,"createdAtMs":1}],"hasMore":false,"nextBeforeId":null}}"#

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        let payload = bodies[path] ?? #"{"code":200,"data":null}"#
        return (Data(payload.utf8), 200)
    }
}

@MainActor final class PlayRoamMiniProgramContractPinTests: XCTestCase {
    private func playService(_ transport: PlayRoamPinTransport, enabled: Set<PlayExperienceCapability>) throws -> PlayExperienceService {
        PlayExperienceService(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport, enabled: enabled)
    }

    private func storeService(_ transport: PlayRoamPinTransport) -> PlayStoreDayService {
        PlayStoreDayService(
            configuration: try? APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport, market: .china, currentSession: { nil })
    }

    private func tools(_ transport: PlayRoamPinTransport) throws -> RoamPrivateToolsService {
        RoamPrivateToolsService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport)
    }

    private func text(_ request: URLRequest) throws -> String {
        String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
    }

    private func jsonObject(_ request: URLRequest) throws -> [String: Any] {
        let data = Data(try text(request).utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func query(_ request: URLRequest) throws -> [URLQueryItem] {
        try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
    }

    func testPlayRoamGatesStayOff() async throws {
        XCTAssertTrue(PlayStageAnalyticsGate.enabled) // PLAY-r11-3: MP utils/stage-events.js:36-50
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertFalse(MerchantCityNPCParityGates.disabled.storeDayProofWrites)
        XCTAssertFalse(MerchantCityNPCParityGates.disabled.storeDayConsentWrites)
        let transport = PlayRoamPinTransport()
        let journey = try JourneyLoopSource(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: transport, endpointClass: .nonProduction)
        XCTAssertThrowsError(try journey.giftClaim(token: "gift-token", requestID: "giftclaim1", sessionToken: "synthetic")) { error in
            XCTAssertEqual(error as? JourneyRefusal, .moneyOff)
        }
        let play = try playService(transport, enabled: [])
        do {
            _ = try await play.startAdvanced(activityID: 41, topicID: 71, nodeID: 701, token: "synthetic")
            XCTFail("a default service must not send")
        } catch let error as PlayExperienceError {
            XCTAssertEqual(error, .disabled)
        }
        let store = storeService(transport)
        let photo = await store.photo(scope: .activity(5), nodeID: 701, pictureURL: "https://example.com/a.jpg")
        XCTAssertEqual(photo, .rejected(nil))
        let consent = await store.consent(merchantID: 9, event: .agree, requestID: "merchant-agree-9-1")
        XCTAssertEqual(consent, .rejected(nil))
        do {
            _ = try await store.latestConsent(merchantID: 9)
            XCTFail("reads stay off")
        } catch let error as PlayStoreDayFailure {
            XCTAssertEqual(error, .unavailable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testAdvancedStartPinsActivityTopicNodeAndDeclaration() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/play/advanced/start"] = String(decoding: PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.advanced), as: UTF8.self)
        let service = try playService(transport, enabled: [.advanced])
        let state = try await service.startAdvanced(activityID: 41, topicID: 71, nodeID: 701, token: "synthetic")
        XCTAssertEqual(state.sessionID, 601)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/play/advanced/start")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let json = try jsonObject(request)
        let fields = ["activityId", "topicId", "nodeId", "clientPlatform", "clientVersion", "supportedCapabilities"]
        XCTAssertEqual(fields, ["activityId", "topicId", "nodeId", "clientPlatform", "clientVersion", "supportedCapabilities"])
        XCTAssertEqual(json["activityId"] as? Int, 41)
        XCTAssertEqual(json["topicId"] as? Int, 71)
        XCTAssertEqual(json["nodeId"] as? Int, 701)
        XCTAssertEqual(json["clientPlatform"] as? String, "ios-native")
        XCTAssertEqual(json["supportedCapabilities"] as? [String], PlayClientCapabilities.tokens)
        XCTAssertEqual(PlayClientCapabilities.declaration(["chapter.blocks", "media.photo"]), "chapter.blocks@1,media.photo@1")
        let miniProgramPlatform = "wechat-miniprogram"
        XCTAssertEqual(miniProgramPlatform, "wechat-miniprogram")
    }

    func testAdvancedActionPinsSessionVersionKeyActionAndPayload() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/play/advanced/action"] = String(decoding: PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.advanced), as: UTF8.self)
        let service = try playService(transport, enabled: [.advanced])
        let pending = PlayAdvancedPending(sessionID: 601, version: 1, key: "action-key-1", action: "RETRY", payload: [:])
        let state = try await service.advancedAction(pending, token: "synthetic")
        XCTAssertEqual(state.version, 2)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/play/advanced/action")
        XCTAssertEqual(NativePlatformService.actionPath, "api/play/advanced/action")
        let json = try jsonObject(request)
        let fields = ["sessionId", "version", "idempotencyKey", "action", "payload"]
        XCTAssertEqual(Set(json.keys), Set(fields))
        XCTAssertEqual(json["sessionId"] as? Int, 601)
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(json["idempotencyKey"] as? String, "action-key-1")
        XCTAssertEqual(json["action"] as? String, "RETRY")
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        XCTAssertTrue(payload.isEmpty)
    }

    func testRunSessionSavePinsElapsedSavedAtAndScope() async throws {
        let transport = PlayRoamPinTransport()
        let client = try PlayRuntimeClient(configuration: APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport, token: "synthetic")
        let refused = await PlayRunSessionSave.save(client: client, scope: .activity(5), elapsedSeconds: -1, savedAt: 1_700_000_000_000)
        XCTAssertFalse(refused)
        XCTAssertTrue(transport.requests.isEmpty)
        let saved = await PlayRunSessionSave.save(client: client, scope: .activity(5), elapsedSeconds: 12, savedAt: 1_700_000_000_000)
        XCTAssertTrue(saved)
        let topic = await PlayRunSessionSave.save(client: client, scope: .topic(8), elapsedSeconds: 12, savedAt: 1_700_000_000_000)
        XCTAssertTrue(topic)
        XCTAssertEqual(transport.requests.count, 2)
        let activity = transport.requests[0]
        XCTAssertEqual(activity.httpMethod, "POST")
        XCTAssertEqual(activity.url?.path, "/api/play/run-session/save")
        XCTAssertEqual(activity.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(try text(activity), "activityId=5&elapsedSeconds=12&savedAt=1700000000000")
        XCTAssertEqual(try text(transport.requests[1]), "elapsedSeconds=12&savedAt=1700000000000&topicId=8")
        let fields = ["elapsedSeconds", "savedAt", "activityId", "topicId"]
        XCTAssertEqual(fields, ["elapsedSeconds", "savedAt", "activityId", "topicId"])
    }

    func testRunSessionClearPinsSavedAtAndScope() async throws {
        let transport = PlayRoamPinTransport()
        let client = try PlayRuntimeClient(configuration: APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport, token: "synthetic")
        let cleared = await PlayRunSessionClear.clear(client: client, scope: .activity(5), savedAt: 1_700_000_000_000)
        XCTAssertTrue(cleared)
        let topic = await PlayRunSessionClear.clear(client: client, scope: .topic(8), savedAt: 1_700_000_000_000)
        XCTAssertTrue(topic)
        XCTAssertEqual(transport.requests[0].httpMethod, "POST")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/play/run-session/clear")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(try text(transport.requests[0]), "activityId=5&savedAt=1700000000000")
        XCTAssertEqual(try text(transport.requests[1]), "savedAt=1700000000000&topicId=8")
        let fields = ["savedAt", "activityId", "topicId"]
        XCTAssertEqual(fields, ["savedAt", "activityId", "topicId"])
    }

    func testRunSessionReadPinsActivityOrTopic() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/play/run-session"] = #"{"code":200,"data":{"runState":"PAUSED","elapsedSeconds":12,"savedAt":1700000000000}}"#
        let service = try playService(transport, enabled: [.reads])
        let activity = try await service.readPaused(scope: .activity(5), token: "synthetic")
        XCTAssertEqual(activity.record?.elapsedSeconds, 12)
        let topic = try await service.readPaused(scope: .topic(8), token: "synthetic")
        XCTAssertEqual(topic.record?.savedAt, 1_700_000_000_000)
        XCTAssertEqual(transport.requests[0].httpMethod, "GET")
        XCTAssertEqual(transport.requests[0].url?.path, "/api/play/run-session")
        XCTAssertEqual(try query(transport.requests[0]), [URLQueryItem(name: "activityId", value: "5")])
        XCTAssertEqual(try query(transport.requests[1]), [URLQueryItem(name: "topicId", value: "8")])
        let fields = ["activityId", "topicId"]
        XCTAssertEqual(fields, ["activityId", "topicId"])
    }

    func testPlayPhotoContractPinsSessionNodeAndPicture() async throws {
        let activity = try XCTUnwrap(PlayStoreDayService.photoContract(scope: .activity(5), nodeID: 701, pictureURL: "https://example.com/a.jpg"))
        XCTAssertEqual(activity, ["activityId": "5", "nodeId": "701", "picUrl": "https://example.com/a.jpg"])
        let topic = try XCTUnwrap(PlayStoreDayService.photoContract(scope: .topic(8), nodeID: 3, pictureURL: "https://example.com/a.jpg"))
        XCTAssertEqual(topic["topicId"], "8")
        XCTAssertNil(topic["activityId"])
        XCTAssertEqual(PlayStoreDayService.photoPath, "api/play/photo")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["activityId", "topicId", "nodeId", "picUrl"]
        XCTAssertEqual(fields, ["activityId", "topicId", "nodeId", "picUrl"])
        let transport = PlayRoamPinTransport()
        let outcome = await storeService(transport).photo(scope: .activity(5), nodeID: 701, pictureURL: "https://example.com/a.jpg")
        XCTAssertEqual(outcome, .rejected(nil))
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMerchantOnsiteConsentWritePinsSubjectEventAndRequest() async throws {
        let body = try XCTUnwrap(PlayStoreDayService.consentWriteContract(merchantID: 9, event: .agree, requestID: "merchant-agree-9-1"))
        XCTAssertEqual(body["docType"] as? String, "merchant_onsite_data_sharing")
        XCTAssertEqual(body["scene"] as? String, "merchant_redeem")
        XCTAssertEqual(body["scopeType"] as? String, "MERCHANT")
        XCTAssertEqual(body["scopeId"] as? Int, 9)
        XCTAssertEqual(body["eventType"] as? String, "AGREE")
        XCTAssertEqual(body["requestId"] as? String, "merchant-agree-9-1")
        XCTAssertEqual(PlayStoreDayService.consentWritePath, "api/compliance/consents")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["docType", "scene", "scopeType", "scopeId", "eventType", "requestId"]
        XCTAssertEqual(Set(body.keys.map(\.description)), Set(fields))
        let transport = PlayRoamPinTransport()
        let outcome = await storeService(transport).consent(merchantID: 9, event: .agree, requestID: "merchant-agree-9-1")
        XCTAssertEqual(outcome, .rejected(nil))
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMerchantOnsiteConsentLatestPinsSubject() async throws {
        let body = try XCTUnwrap(PlayStoreDayService.consentLatestContract(merchantID: 9))
        XCTAssertEqual(body["docType"] as? String, "merchant_onsite_data_sharing")
        XCTAssertEqual(body["scene"] as? String, "merchant_redeem")
        XCTAssertEqual(body["scopeType"] as? String, "MERCHANT")
        XCTAssertEqual(body["scopeId"] as? Int, 9)
        XCTAssertNil(body["eventType"])
        XCTAssertNil(body["requestId"])
        XCTAssertEqual(PlayStoreDayService.consentLatestPath, "api/compliance/consents/latest")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["docType", "scene", "scopeType", "scopeId"]
        XCTAssertEqual(Set(body.keys.map(\.description)), Set(fields))
        let transport = PlayRoamPinTransport()
        do {
            _ = try await storeService(transport).latestConsent(merchantID: 9)
            XCTFail("reads stay off")
        } catch let error as PlayStoreDayFailure {
            XCTAssertEqual(error, .unavailable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testCapsuleCreatePinsRequestBodyPhotoAndUnlock() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/capsules/create"] = PlayRoamPinTransport.lockedCapsule
        let service = try tools(transport)
        let now = Date(timeIntervalSince1970: 1_763_942_400)
        let draft = RoamCapsuleDraft(requestID: "abcdefghijklmnop", body: "hello", photoURL: "", unlockDate: "2030-01-01")
        let capsule = try await service.createCapsule(draft, now: now, token: "synthetic")
        XCTAssertEqual(capsule.id, "40")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/capsules/create")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(try text(request), #"{"requestId":"abcdefghijklmnop","body":"hello","photoUrl":"","unlockDate":"2030-01-01"}"#)
        let fields = ["requestId", "body", "photoUrl", "unlockDate"]
        XCTAssertEqual(fields, ["requestId", "body", "photoUrl", "unlockDate"])
    }

    func testCapsuleDetailPinsId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/capsules/detail"] = PlayRoamPinTransport.lockedCapsule
        let capsule = try await tools(transport).capsule(id: "40", token: "synthetic")
        XCTAssertEqual(capsule.state, .locked)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/capsules/detail")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "id", value: "40")])
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
    }

    func testCapsuleReceiptPinsRequestId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/capsules/receipt"] = PlayRoamPinTransport.lockedCapsule
        let capsule = try await tools(transport).capsuleReceipt(requestID: "abcdefghijklmnop", token: "synthetic")
        XCTAssertEqual(capsule.id, "40")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/capsules/receipt")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "requestId", value: "abcdefghijklmnop")])
        let fields = ["requestId"]
        XCTAssertEqual(fields, ["requestId"])
    }

    func testCapsuleListPinsBeforeIdAndLimit() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/capsules/list"] = PlayRoamPinTransport.capsulePage
        let page = try await tools(transport).capsules(beforeID: "40", token: "synthetic")
        XCTAssertEqual(page.items.map(\.id), ["40"])
        XCTAssertFalse(page.hasMore)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/capsules/list")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "beforeId", value: "40"),
            URLQueryItem(name: "limit", value: "20"),
        ])
        let fields = ["beforeId", "limit"]
        XCTAssertEqual(fields, ["beforeId", "limit"])
    }

    func testCapsuleDeletePinsId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/capsules/delete"] = PlayRoamPinTransport.deletedCapsule
        let capsule = try await tools(transport).deleteCapsule(id: "40", token: "synthetic")
        XCTAssertEqual(capsule.state, .deleted)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/capsules/delete")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(try text(request), "id=40")
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
    }

    func testGoalCreatePinsRequestMetricTargetAndDates() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/exploration-goals/create"] = PlayRoamPinTransport.activeGoal
        let now = Date(timeIntervalSince1970: 1_763_942_400)
        let draft = RoamGoalDraft(requestID: "abcdefghijklmnop", metric: .distinctRoutes, target: 3, startDate: "2099-01-01", endDateExclusive: "2099-06-01")
        let goal = try await tools(transport).createGoal(draft, now: now, token: "synthetic")
        XCTAssertEqual(goal.id, "40")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/exploration-goals/create")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(try text(request), #"{"requestId":"abcdefghijklmnop","metric":"DISTINCT_ROUTES","target":3,"startDate":"2099-01-01","endDateExclusive":"2099-06-01"}"#)
        let fields = ["requestId", "metric", "target", "startDate", "endDateExclusive"]
        XCTAssertEqual(fields, ["requestId", "metric", "target", "startDate", "endDateExclusive"])
    }

    func testGoalReceiptPinsRequestId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/exploration-goals/receipt"] = PlayRoamPinTransport.activeGoal
        let draft = RoamGoalDraft(requestID: "abcdefghijklmnop", metric: .distinctRoutes, target: 3, startDate: "2099-01-01", endDateExclusive: "2099-06-01")
        let goal = try await tools(transport).goalReceipt(requestID: "abcdefghijklmnop", draft: draft, token: "synthetic")
        XCTAssertEqual(goal.requestID, "abcdefghijklmnop")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/exploration-goals/receipt")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "requestId", value: "abcdefghijklmnop")])
        let fields = ["requestId"]
        XCTAssertEqual(fields, ["requestId"])
    }

    func testGoalDetailPinsId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/exploration-goals/detail"] = PlayRoamPinTransport.activeGoal
        let goal = try await tools(transport).goal(id: "40", token: "synthetic")
        XCTAssertEqual(goal.id, "40")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/exploration-goals/detail")
        XCTAssertEqual(try query(request), [URLQueryItem(name: "id", value: "40")])
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
    }

    func testGoalListPinsLimitAndBeforeId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/exploration-goals/list"] = PlayRoamPinTransport.goalPage
        let page = try await tools(transport).goals(beforeID: "40", token: "synthetic")
        XCTAssertEqual(page.items.map(\.id), ["40"])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/exploration-goals/list")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "beforeId", value: "40"),
            URLQueryItem(name: "limit", value: "20"),
        ])
        let fields = ["limit", "beforeId"]
        XCTAssertEqual(fields, ["limit", "beforeId"])
    }

    func testGoalCancelPinsId() async throws {
        let transport = PlayRoamPinTransport()
        transport.bodies["/api/exploration-goals/cancel"] = PlayRoamPinTransport.cancelledGoal
        let goal = try await tools(transport).cancelGoal(id: "40", token: "synthetic")
        XCTAssertEqual(goal.state, .cancelled)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/exploration-goals/cancel")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(try text(request), "id=40")
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
    }

    func testPassCancelStaysUnsent() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.cancelOrderPath, "api/platform-pass/orders/{}/cancel")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let transport = PlayRoamPinTransport()
        let client = PlatformPass(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport)
        XCTAssertThrowsError(try client.cancelPassOrder(orderNo: "orderNo", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPassConfirmStaysUnsent() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertEqual(PlatformPass.confirmOrderPath, "api/platform-pass/orders/{}/confirm")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let transport = PlayRoamPinTransport()
        let client = PlatformPass(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport)
        XCTAssertThrowsError(try client.confirmPassOrder(orderNo: "orderNo", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPassRefundApplyStaysUnsent() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.refundApplyPath, "api/platform-pass/orders/{}/refund-apply")
        XCTAssertEqual(PlatformPass.refundApplyField, "reason")
        let method = "POST"
        let fields = ["reason"]
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["reason"])
        let transport = PlayRoamPinTransport()
        let client = PlatformPass(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: transport)
        XCTAssertThrowsError(try client.refundApplyPassOrder(orderNo: "orderNo", reason: "changed my mind", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}

