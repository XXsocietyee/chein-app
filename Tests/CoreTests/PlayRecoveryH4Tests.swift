import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// cloud-h4 §六 U05-01..04: refusal contract, receipt re-read, action context, download pack.
@MainActor final class PlayRecoveryH4Tests: XCTestCase {
    private func wire(_ json: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8)) }
    private func session() throws -> PlayExperienceSession { try .init(accountID: 9001, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token") }
    private func service(_ transport: any HTTPTransport, enabled: Set<PlayExperienceCapability>) throws -> PlayExperienceService {
        .init(configuration: try .init(baseURL: URL(string: "https://example.com/")!), transport: transport, enabled: enabled)
    }
    private func recorder() -> PlayRecoveryRecordingTransport {
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/api/play/nodes"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.branch), 200)
        transport.responses["/api/play/route-state"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.route), 200)
        transport.responses["/api/play/action-context"] = .reply(Data(#"{"code":200,"data":{"routeSessionId":"501","expectedRouteVersion":2}}"#.utf8), 200)
        return transport
    }
    private func field(_ request: URLRequest, _ name: String) -> String? {
        if request.httpMethod == "GET" {
            return request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems?.first { $0.name == name }?.value
        }
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        guard let start = body.range(of: "name=\"\(name)\"\r\n\r\n") else { return nil }
        let rest = body[start.upperBound...]
        return rest.range(of: "\r\n").map { String(rest[..<$0.lowerBound]) }
    }

    // MARK: U05-01 refusal contract

    func testArriveRefusalKeepsMachineFieldsAndReplacements() throws {
        let refusal = try XCTUnwrap(PlayCommandRefusal(envelope: wire(#"{"code":500,"msg":"还没到这一站附近","errorCode":"ARRIVE_TOO_FAR","retryable":true,"refreshRequired":false,"intentNotExecuted":true,"intentTerminal":true,"newActionIdRequired":true,"arrivalReasonCode":"ARRIVE_TOO_FAR","canRetry":true,"approvedFallbacks":["12","12","bad","13"]}"#)))
        XCTAssertTrue(refusal.carriesContract)
        XCTAssertTrue(refusal.settlesAsFailed)
        XCTAssertFalse(refusal.isPending)
        XCTAssertEqual(refusal.arrivalReason, .tooFar)
        XCTAssertEqual(refusal.approvedFallbacks, [12, 13])
        let failure = PlayArrivalFailure(nodeID: 11, refusal: refusal, snapshot: nil)
        XCTAssertEqual(failure.actions, [.relocate])
        // No current read: replacement ids are never shown without a real, open stop to open.
        XCTAssertTrue(failure.replacements.isEmpty)
    }

    func testEveryArrivalReasonHasItsOwnNextStepAndNoneWidensTheFence() {
        XCTAssertEqual(PlayArrivalFailureReason.accuracyLow.actions(retryable: true, appealable: false, nodeHasScan: true), [.relocate, .scanInstead])
        XCTAssertEqual(PlayArrivalFailureReason.accuracyLow.actions(retryable: false, appealable: false, nodeHasScan: false), [])
        XCTAssertEqual(PlayArrivalFailureReason.guardSpeed.actions(retryable: false, appealable: true, nodeHasScan: false), [.appealGuard])
        XCTAssertEqual(PlayArrivalFailureReason.coordinatesNotConfigured.actions(retryable: false, appealable: false, nodeHasScan: false), [.contactOrganizer])
        XCTAssertEqual(PlayArrivalFailureReason.stopClosed.actions(retryable: false, appealable: false, nodeHasScan: false), [.contactOrganizer])
        // GPS never stands in for a merchant scan.
        XCTAssertFalse(PlayArrivalFailureReason.methodUnavailable.actions(retryable: true, appealable: false, nodeHasScan: false).contains(.relocate))
    }

    func testAnswerArriveFirstUsesItsSubReason() throws {
        let refusal = try XCTUnwrap(PlayCommandRefusal(envelope: wire(#"{"code":500,"msg":"m","errorCode":"ARRIVE_FIRST","reasonCode":"ARRIVE_ACCURACY_LOW","retryable":false,"intentNotExecuted":true}"#)))
        XCTAssertEqual(refusal.arrivalReason, .accuracyLow)
    }

    func testPendingAndReusedIdsAreNeverSettledAsFailures() throws {
        let pending = try XCTUnwrap(PlayCommandRefusal(envelope: wire(#"{"code":520,"msg":"m","errorCode":"INTENT_PENDING","retryable":true,"receiptState":"UNKNOWN"}"#)))
        XCTAssertTrue(pending.isPending)
        XCTAssertFalse(pending.settlesAsFailed)
        let reused = try XCTUnwrap(PlayCommandRefusal(envelope: wire(#"{"code":409,"msg":"m","errorCode":"INTENT_ACTION_REUSED","newActionIdRequired":true}"#)))
        XCTAssertFalse(reused.settlesAsFailed)
        // An older server sends only code + msg: keep the existing unknown handling.
        let legacy = try XCTUnwrap(PlayCommandRefusal(envelope: wire(#"{"code":500,"msg":"m"}"#)))
        XCTAssertFalse(legacy.carriesContract)
        XCTAssertNil(PlayCommandRefusal(envelope: try wire(#"{"code":200,"data":{}}"#)))
    }

    func testArriveRefusalIsThrownWithItsFieldsAndRequestCarriesTheContext() async throws {
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/api/play/arrive"] = .reply(Data(#"{"code":500,"msg":"定位精度不足","errorCode":"ARRIVE_ACCURACY_LOW","retryable":true,"intentNotExecuted":true,"intentTerminal":true,"newActionIdRequired":true,"arrivalReasonCode":"ARRIVE_ACCURACY_LOW","canRetry":true,"approvedFallbacks":[]}"#.utf8), 200)
        let api = try service(transport, enabled: [.reads, .classicCompletion])
        let advance = try PlayRouteAdvance(actionID: "action-1", expectedVersion: 3, routeSessionID: 501, runtimeInstance: nil, authorityEpoch: nil)
        let measured = Date()
        do {
            _ = try await api.complete(scope: .topic(71), nodeID: 11, evidence: .location(longitude: 121.4, latitude: 31.2, coordinateSystem: "GCJ02", accuracyMeters: 95, measuredAt: measured), advance: advance, token: "synthetic-token")
            XCTFail("refusal expected")
        } catch let refusal as PlayCommandRefusal {
            XCTAssertEqual(refusal.arrivalReason, .accuracyLow)
            XCTAssertEqual(refusal.message, "定位精度不足")
        }
        let post = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(field(post, "routeActionId"), "action-1")
        XCTAssertEqual(field(post, "expectedRouteVersion"), "3")
        XCTAssertEqual(field(post, "routeSessionId"), "501")
        XCTAssertEqual(field(post, "accuracy"), "95.0")
        XCTAssertEqual(field(post, "locationTimestamp"), String(Int64((measured.timeIntervalSince1970 * 1000).rounded(.down))))
    }

    func testUnboundJournalKeepsItsOriginalRequestShape() throws {
        let api = try service(PlayRecoveryRecordingTransport(), enabled: [.classicCompletion])
        let advance = try PlayRouteAdvance(actionID: "action-1", expectedVersion: 3)
        let request = try api.completionRequest(scope: .topic(71), nodeID: 11, evidence: .location(longitude: 121.4, latitude: 31.2, coordinateSystem: "GCJ02", accuracyMeters: 10, measuredAt: Date()), advance: advance, token: "synthetic-token", boundary: "b")
        XCTAssertNil(field(request, "locationTimestamp"))
        XCTAssertNil(field(request, "routeSessionId"))
        // A journal written before the new fields decodes unchanged.
        let old = try JSONDecoder().decode(PlayRouteAdvance.self, from: Data(#"{"actionID":"action-1","expectedVersion":3}"#.utf8))
        XCTAssertEqual(old, advance)
        XCTAssertFalse(old.isContextBound)
    }

    func testActionContextRequiresBothSharedRuntimeFieldsOrNeither() throws {
        let personal = try PlayBasicActionContext(raw: wire(#"{"routeSessionId":"0","expectedRouteVersion":0}"#))
        XCTAssertEqual(personal.routeSessionID, 0)
        XCTAssertNil(personal.runtimeInstance)
        let shared = try PlayBasicActionContext(raw: wire(#"{"routeSessionId":"9","expectedRouteVersion":4,"runtimeInstance":"inst-1","authorityEpoch":2}"#))
        XCTAssertEqual(shared.authorityEpoch, 2)
        XCTAssertThrowsError(try PlayBasicActionContext(raw: wire(#"{"routeSessionId":"9","expectedRouteVersion":4,"runtimeInstance":"inst-1"}"#)))
    }

    // MARK: U05-03 receipt

    func testTerminalFailedReceiptIsADefiniteFailureNotUnknown() throws {
        let failed = Data(#"{"code":500,"msg":"还没到这一站附近","errorCode":"ARRIVE_TOO_FAR","retryable":true,"intentTerminal":true,"newActionIdRequired":true}"#.utf8)
        guard case .failed(let refusal) = try PlayActionReceipt.decode(failed, status: 200, routeActionID: "action-1") else { return XCTFail("terminal replay") }
        XCTAssertEqual(refusal.arrivalReason, .tooFar)
        // A non-terminal refusal on the receipt read (for example scope denied) still proves nothing.
        let denied = Data(#"{"code":500,"msg":"m","errorCode":"INTENT_SCOPE_DENIED","intentNotExecuted":true}"#.utf8)
        XCTAssertThrowsError(try PlayActionReceipt.decode(denied, status: 200, routeActionID: "action-1"))
    }

    func testBoundSubmitReadsContextThenSettlesATerminalRefusal() async throws {
        let current = try session(), transport = recorder(), recovery = PlayMemoryCompletionRecovery()
        transport.responses["/api/play/answer"] = .reply(Data(#"{"code":500,"msg":"答案不正确","errorCode":"ANSWER_WRONG","retryable":false,"intentTerminal":true,"newActionIdRequired":true}"#.utf8), 200)
        let model = PlayExperienceCoordinator(scope: .activity(41), service: try service(transport, enabled: [.reads, .classicCompletion, .actionContextBinding]),
                                              recovery: recovery, pausedStorage: PlayMemoryPausedStorage(), currentSession: { current })
        await model.load()
        await model.submit(try model.review(nodeID: 701, evidence: .answer("wrong")))
        let paths = transport.requests.map { $0.url?.path ?? "" }
        let contextIndex = try XCTUnwrap(paths.firstIndex(of: "/api/play/action-context"))
        let postIndex = try XCTUnwrap(paths.firstIndex(of: "/api/play/answer"))
        XCTAssertLessThan(contextIndex, postIndex)
        XCTAssertEqual(field(transport.requests[postIndex], "routeSessionId"), "501")
        guard case .failed(701, let refusal)? = model.submitRecovery else { return XCTFail("definite failure") }
        XCTAssertEqual(refusal.errorCode, "ANSWER_WRONG")
        XCTAssertFalse(model.unresolved)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNil(try await recovery.read(PlayRunStorageKey.make(session: current, scope: .activity(41))))
        XCTAssertFalse(paths.contains("/api/play/action-receipt"))
    }

    func testRestartReReadsTheOriginalReceiptAndNeverResubmits() async throws {
        let current = try session(), transport = recorder(), recovery = PlayMemoryCompletionRecovery()
        transport.responses["/api/play/answer"] = .failure(.unknownResult)
        transport.responses["/api/play/action-receipt"] = .reply(Data(#"{"code":520,"data":null}"#.utf8), 200)
        let enabled: Set<PlayExperienceCapability> = [.reads, .classicCompletion, .actionContextBinding]
        let first = PlayExperienceCoordinator(scope: .activity(41), service: try service(transport, enabled: enabled),
                                              recovery: recovery, pausedStorage: PlayMemoryPausedStorage(), currentSession: { current })
        await first.load()
        await first.submit(try first.review(nodeID: 701, evidence: .answer("synthetic answer")))
        XCTAssertEqual(first.submitRecovery, .pending(nodeID: 701))
        XCTAssertEqual(first.phase, .unknown)
        let actionID = try XCTUnwrap(transport.requests.first { $0.url?.path == "/api/play/answer" }.flatMap { field($0, "routeActionId") })

        // "Restart": a new coordinator over the same journal. The receipt now says applied.
        transport.responses["/api/play/action-receipt"] = .reply(Data((#"{"code":200,"data":{"nodeId":701,"routeActionId":""# + actionID + #"","intentTerminal":true}}"#).utf8), 200)
        let restarted = PlayExperienceCoordinator(scope: .activity(41), service: try service(transport, enabled: enabled),
                                                  recovery: recovery, pausedStorage: PlayMemoryPausedStorage(), currentSession: { current })
        await restarted.load()
        XCTAssertEqual(restarted.submitRecovery, .confirmed(nodeID: 701))
        XCTAssertFalse(restarted.unresolved)
        XCTAssertNil(try await recovery.read(PlayRunStorageKey.make(session: current, scope: .activity(41))))
        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 1)
        let reads = transport.requests.filter { $0.url?.path == "/api/play/action-receipt" }
        XCTAssertTrue(reads.allSatisfy { field($0, "routeActionId") == actionID })
    }

    // MARK: U05-02

    func testRouteNoticeAndStationPauseShowOnlyServerFacts() throws {
        let route = try JSONDecoder().decode(PlayRouteState.self, from: Data(#"{"routeMode":"LINEAR","status":"FALLBACK"}"#.utf8))
        XCTAssertEqual(PlayRouteNotice(route: route), .switchedToFallback)
        XCTAssertNil(PlayRouteNotice(route: nil))
        let paused = try XCTUnwrap(PlayStationPauseNotice(state: "PAUSED", pause: wire(#"{"reasonCode":"WEATHER","reason":"暴雨","resumeEta":null}"#), fallback: .null))
        XCTAssertFalse(paused.hasApprovedReplacement)
        XCTAssertNil(paused.resumeEta)
        // A fallback without the plan's player message is not an approved replacement.
        let partial = try XCTUnwrap(PlayStationPauseNotice(state: "PAUSED", pause: .null, fallback: wire(#"{"targetNodeId":12}"#)))
        XCTAssertFalse(partial.hasApprovedReplacement)
        XCTAssertNil(PlayStationPauseNotice(state: "ACTIVE", pause: .null, fallback: .null))
    }

    func testArrivalReadingNeedsARealLog() throws {
        XCTAssertEqual(PlayArrivalReading(receipt: try wire(#"{"arrivalReading":{"level":2,"log":" 风从桥下来 "}}"#))?.log, "风从桥下来")
        XCTAssertNil(PlayArrivalReading(receipt: try wire(#"{"arrivalReading":{"level":5,"log":"x"}}"#)))
        XCTAssertNil(PlayArrivalReading(receipt: try wire(#"{"arrivalReading":{"level":1,"log":""}}"#)))
    }

    // MARK: U05-04

    private let revision = #"{"status":"REVISION","topicId":21,"activityId":null,"contentRevisionId":7,"revisionNo":3,"schemaVersion":1,"manifestVersion":1,"contentSha256":"\#(String(repeating: "a", count: 64))","stations":[{"nodeId":11,"nodeName":"第一站","chapterId":501,"scanReady":false,"scope":"START"}],"requiredCapabilities":null,"assets":[{"assetKey":"chapter:501:audio","url":"https://cdn.example.com/a.mp3","sha256":null,"bytes":null,"mime":null,"priority":1,"scope":"START","textAlternative":null,"verified":false,"unverifiedReason":"HASH_AND_BYTES_UNKNOWN"},{"assetKey":"node:11:image","url":"https://cdn.example.com/b.jpg","sha256":null,"bytes":3,"mime":"image/jpeg","priority":3,"scope":"OPTIONAL","textAlternative":"桥","verified":false}],"assetVerification":"UNVERIFIED","expiresAt":null,"onlineRequired":false,"sourceLocale":"zh-CN"}"#

    func testManifestKeepsUnknownsAndRejectsContradictions() throws {
        let manifest = try PlayContentManifest(raw: wire(revision))
        XCTAssertEqual(manifest.status, .revision)
        XCTAssertNil(manifest.requiredCapabilityKeys, "null is undeclared, not an empty requirement list")
        XCTAssertEqual(manifest.requiredAssets.map(\.assetKey), ["chapter:501:audio"])
        XCTAssertEqual(manifest.optionalAssets.first?.bytes, 3)
        XCTAssertNil(manifest.requiredAssets.first?.bytes, "missing size stays unknown, never 0")
        XCTAssertEqual(manifest.knownSize(of: manifest.assets).unknownCount, 1)
        XCTAssertNotNil(manifest.identity)
        let legacy = try PlayContentManifest(raw: wire(#"{"status":"ONLINE_LEGACY","topicId":21,"onlineRequired":true,"sourceLocale":"zh-CN","assets":[],"stations":[]}"#))
        XCTAssertNil(legacy.identity)
        XCTAssertThrowsError(try PlayContentManifest(raw: wire(#"{"status":"ONLINE_LEGACY","topicId":21,"onlineRequired":false,"sourceLocale":"zh-CN"}"#)))
        XCTAssertThrowsError(try PlayContentManifest(raw: wire(#"{"status":"REVISION","topicId":21,"onlineRequired":false,"sourceLocale":"zh-CN"}"#)))
    }

    func testPrefetchStoreIsAccountPrivateAndAHalfPackNeverReplacesTheCompleteOne() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlayContentPrefetchStore(root: root)
        let mine = store.ownerDirectory(namespace: "cn", accountID: 1, scope: .topic(21))
        XCTAssertNotEqual(mine, store.ownerDirectory(namespace: "cn", accountID: 2, scope: .topic(21)))
        let old = try PlayContentManifest(raw: wire(revision))
        let oldIdentity = try XCTUnwrap(old.identity)
        _ = try store.store(Data("abc".utf8), for: old.requiredAssets[0], owner: mine, identity: oldIdentity, at: Date())
        XCTAssertTrue(try store.promoteIfComplete(old, owner: mine))
        XCTAssertEqual(store.completeIdentity(owner: mine), oldIdentity)

        let newer = try PlayContentManifest(raw: wire(revision.replacingOccurrences(of: #""contentRevisionId":7"#, with: #""contentRevisionId":8"#)))
        let newIdentity = try XCTUnwrap(newer.identity)
        XCTAssertFalse(try store.promoteIfComplete(newer, owner: mine))
        XCTAssertEqual(store.completeIdentity(owner: mine), oldIdentity, "half pack keeps the complete one")
        XCTAssertFalse(store.stored(owner: mine, identity: oldIdentity).isEmpty)
        // A stated size that does not match is not stored.
        XCTAssertThrowsError(try store.store(Data("abcd".utf8), for: newer.optionalAssets[0], owner: mine, identity: newIdentity, at: Date()))
        let row = try store.store(Data("xyz".utf8), for: newer.requiredAssets[0], owner: mine, identity: newIdentity, at: Date())
        XCTAssertFalse(row.serverVerified, "an unverified asset never becomes verified locally")
        XCTAssertTrue(try store.promoteIfComplete(newer, owner: mine))
        XCTAssertEqual(store.completeIdentity(owner: mine), newIdentity)
        XCTAssertTrue(store.stored(owner: mine, identity: oldIdentity).isEmpty)
    }

    func testOfflineScopeIsNotDeclaredForUnverifiedFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/api/play/content-manifest"] = .reply(Data((#"{"code":200,"data":"# + revision + "}").utf8), 200)
        let current = try session()
        let model = PlayOfflinePackModel(scope: .topic(21), service: try service(transport, enabled: [.reads]), session: current, isCurrent: { true },
                                         store: PlayContentPrefetchStore(root: root), fetch: { _ in Data("abc".utf8) })
        await model.load()
        XCTAssertEqual(model.offlineScope, .incomplete)
        XCTAssertNotNil(model.lastSyncedAt)
        await model.downloadRequired()
        XCTAssertEqual(model.requiredStoredCount, 1)
        XCTAssertEqual(model.offlineScope, .notVerified)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(field(request, "topicId"), "21")
        XCTAssertNil(field(request, "revisionId"))
    }
}
