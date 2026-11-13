import Foundation
import XCTest
@testable import QuestifyCore

/// App-side items of `docs/channels/contract.md` §7 against hengyin `feature/im-channels` @ bb4ee788a.
final class ChannelsContractAppSideTests: XCTestCase {
    private let hash64 = String(repeating: "a", count: 64)
    private let request = "00000000-0000-4000-8000-000000000001"

    // MARK: §7.3 has_more as integer or boolean

    func testFlexibleFlagAcceptsBooleanAndZeroOneOnly() throws {
        struct Box: Decodable { @JSONFlexibleFlag var has_more: Bool }
        struct OptionalBox: Decodable { @JSONFlexibleOptionalFlag var has_more: Bool? }
        let decoder = JSONDecoder()
        XCTAssertTrue(try decoder.decode(Box.self, from: Data(#"{"has_more":true}"#.utf8)).has_more)
        XCTAssertFalse(try decoder.decode(Box.self, from: Data(#"{"has_more":false}"#.utf8)).has_more)
        XCTAssertTrue(try decoder.decode(Box.self, from: Data(#"{"has_more":1}"#.utf8)).has_more)
        XCTAssertFalse(try decoder.decode(Box.self, from: Data(#"{"has_more":0}"#.utf8)).has_more)
        for bad in [#"{"has_more":2}"#, #"{"has_more":"1"}"#, #"{"has_more":0.5}"#, #"{}"#] {
            XCTAssertThrowsError(try decoder.decode(Box.self, from: Data(bad.utf8)), bad)
        }
        XCTAssertNil(try decoder.decode(OptionalBox.self, from: Data(#"{}"#.utf8)).has_more)
        XCTAssertNil(try decoder.decode(OptionalBox.self, from: Data(#"{"has_more":null}"#.utf8)).has_more)
        XCTAssertEqual(try decoder.decode(OptionalBox.self, from: Data(#"{"has_more":1}"#.utf8)).has_more, true)

        let object = try JSONSerialization.jsonObject(with: Data(#"{"a":true,"b":0,"c":1,"d":2,"e":"1"}"#.utf8)) as! [String: Any]
        XCTAssertEqual(JSONFlexibleFlag.value(object["a"]), true)
        XCTAssertEqual(JSONFlexibleFlag.value(object["b"]), false)
        XCTAssertEqual(JSONFlexibleFlag.value(object["c"]), true)
        XCTAssertNil(JSONFlexibleFlag.value(object["d"]))
        XCTAssertNil(JSONFlexibleFlag.value(object["e"]))
    }

    func testFriendPageDecodesIntegerHasMore() throws {
        let body = #"{"viewer_id":7,"incoming":[],"outgoing":[],"friends":[],"has_more":0,"next_cursor":null,"review_has_more":1}"#
        let page = try JSONDecoder().decode(NativeFriendPage.self, from: Data(body.utf8))
        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(page.reviewHasMore, true)
        let boolean = try JSONDecoder().decode(NativeFriendPage.self, from: Data(body.replacingOccurrences(of: #""has_more":0"#, with: #""has_more":true"#).utf8))
        XCTAssertTrue(boolean.hasMore)
        let roundTrip = try JSONDecoder().decode(NativeFriendPage.self, from: JSONEncoder().encode(page))
        XCTAssertEqual(roundTrip, page)
    }

    // MARK: §7.4 progress privacy

    func testProgressScopeShowsFriendAggregateAsSelf() throws {
        struct Box: Decodable { let scope: NativeChannelProgressScope }
        XCTAssertEqual(try JSONDecoder().decode(Box.self, from: Data(#"{"scope":"FRIEND"}"#.utf8)).scope, .onlyMe)
        XCTAssertEqual(try JSONDecoder().decode(Box.self, from: Data(#"{"scope":"TEAM"}"#.utf8)).scope, .team)
        XCTAssertThrowsError(try JSONDecoder().decode(Box.self, from: Data(#"{"scope":"EVERYONE"}"#.utf8)))
    }

    // MARK: §7.11 video receipts without cover, duration or dimensions

    func testVideoReceiptWithoutCoverDecodesAndBecomesReady() throws {
        let scope = try IMScope(identity: .init(accountID: 7, epoch: 1), conversationID: 30)
        let body = """
        {"source":"original-im-video-upload-v1","owner_member_id":"7","conversation_id":"30","upload_request_id":"\(request)",
         "source_sha256":"\(hash64)","state":"UPLOADED","video_review_state":"APPROVED","cover_review_state":null,"transcoded":false,
         "reference":{"uploadRequestID":"\(request)","attachmentID":"11","sha256":"\(hash64)","size":5000,
                      "coverSHA256":null,"coverSize":null,"durationMS":null,"width":null,"height":null}}
        """
        let receipt = try JSONDecoder().decode(IMVideoUploadReceipt.self, from: Data(body.utf8))
        XCTAssertNoThrow(try receipt.validate(scope: scope, requestID: request, hash: hash64))
        XCTAssertTrue(receipt.ready)
        let reference = try XCTUnwrap(receipt.reference)
        XCTAssertFalse(reference.hasCover)
        XCTAssertNil(reference.durationMS)
        let fields = try reference.wireFields()
        XCTAssertEqual(fields["msg_type"], "11")
        XCTAssertEqual(fields["content"], "[视频]")
        let held = try JSONDecoder().decode(IMVideoUploadReceipt.self,
            from: Data(body.replacingOccurrences(of: #""video_review_state":"APPROVED""#, with: #""video_review_state":"HOLD""#).utf8))
        XCTAssertNoThrow(try held.validate(scope: scope, requestID: request, hash: hash64))
        XCTAssertFalse(held.ready)
    }

    func testVideoReferenceStillRejectsHalfACoverAndBadDurations() {
        XCTAssertThrowsError(try IMVideoReference(uploadRequestID: request, attachmentID: "11", sha256: hash64,
                                                  coverSHA256: hash64, size: 10).validate())
        XCTAssertThrowsError(try IMVideoReference(uploadRequestID: request, attachmentID: "11", sha256: hash64,
                                                  size: 10, durationMS: 0).validate())
        XCTAssertThrowsError(try IMVideoReference(uploadRequestID: request, attachmentID: "11", sha256: hash64,
                                                  size: 10, width: 10).validate())
        XCTAssertNoThrow(try IMVideoReference(uploadRequestID: request, attachmentID: "11", sha256: hash64, coverSHA256: hash64,
                                              size: 10, coverSize: 9, durationMS: 1000, width: 2, height: 2).validate())
    }

    // MARK: §7.12 voice without ASR or server duration

    func testVoiceReceiptUsesTheRecordedClipAndIgnoresASR() throws {
        let scope = try IMScope(identity: .init(accountID: 7, epoch: 1), conversationID: 30)
        let clip = try IMVoiceClip(bytes: Data(repeating: 1, count: 4000), waveform: Data([1, 2, 3, 4]), durationMS: 2300)
        let body = """
        {"source":"original-im-voice-upload-v1","owner_member_id":"7","conversation_id":"30","upload_request_id":"\(request)",
         "source_sha256":"\(clip.sha256)","state":"UPLOADED","asset_id":"91","review_state":"APPROVED","size":4000,
         "duration_ms":null,"waveform":null,"asr_state":"NOT_AVAILABLE","transcoded":false}
        """
        let receipt = try JSONDecoder().decode(IMVoiceUploadReceipt.self, from: Data(body.utf8))
        XCTAssertNoThrow(try receipt.validate(scope: scope, requestID: request, hash: clip.sha256))
        XCTAssertTrue(receipt.ready(recorded: clip))
        let reference = try XCTUnwrap(receipt.reference(recorded: clip))
        XCTAssertEqual(reference.durationMS, 2300)
        XCTAssertEqual(reference.assetID, 91)
        XCTAssertEqual(reference.waveform, Data([1, 2, 3, 4]).base64EncodedString())
        XCTAssertEqual(try reference.wireFields()["msg_type"], "10")
        let other = try IMVoiceClip(bytes: Data(repeating: 1, count: 3999), waveform: Data([1]), durationMS: 1000)
        XCTAssertNil(receipt.reference(recorded: other), "a size mismatch is not this upload")
        let held = try JSONDecoder().decode(IMVoiceUploadReceipt.self,
            from: Data(body.replacingOccurrences(of: #""review_state":"APPROVED""#, with: #""review_state":"HOLD""#).utf8))
        XCTAssertFalse(held.ready(recorded: clip))
    }

    // MARK: §7.13 file cap

    func testFilePickerCapIsTenMegabytes() throws {
        XCTAssertEqual(IMFileSelection.maximumBytes, 10 * 1024 * 1024)
        XCTAssertNoThrow(try IMFileSelection(name: "a.txt", bytes: Data(repeating: 65, count: 10 * 1024 * 1024)))
        XCTAssertThrowsError(try IMFileSelection(name: "a.txt", bytes: Data(repeating: 65, count: 10 * 1024 * 1024 + 1)))
    }

    // MARK: §4 / §7.10 team pool hint

    @MainActor func testTeamPoolHintDecodesAndRendersTheServerHint() async throws {
        let pool = #"{"teamId":5,"topicId":3,"activityId":0,"enabled":true,"hintsTotal":3,"hintsUsed":1,"hintsLeft":2,"skipsTotal":1,"skipsUsed":0,"skipsLeft":1,"timerLimitSec":600,"timerStartedAt":null,"timerDeadline":null,"timerExpired":false,"teamScore":4,"scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":[7],"version":2,"frozenAt":"2026-11-13T00:00:00"}"#
        let transport = PoolTransport()
        transport.responses = [
            (Data(#"{"code":200,"data":\#(pool)}"#.utf8), 200)
        ]
        let configuration = try APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!)
        let service = TeamPoolService(configuration: configuration, transport: transport, token: { "token" })
        let model = TeamPoolHintModel(service: service, nodeID: 9, resolveTeam: { 5 })
        await model.load()
        XCTAssertTrue(model.isVisible)
        XCTAssertTrue(model.canRequestHint)
        XCTAssertEqual(transport.requests.first?.url?.query, "teamId=5")

        transport.responses = [(Data(#"{"code":500,"msg":"x","errorCode":"OUTCOME_UNKNOWN","outcome_known":false}"#.utf8), 500)]
        await model.requestHint()
        XCTAssertEqual(model.notice, .unknown)
        XCTAssertTrue(model.canRecover)
        let firstBody = try XCTUnwrap(transport.requests.last?.httpBody)
        let sent = try JSONSerialization.jsonObject(with: firstBody) as! [String: Any]
        let requestID = try XCTUnwrap(sent["requestId"] as? String)
        XCTAssertEqual(sent["teamId"] as? Int, 5)
        XCTAssertEqual(sent["nodeId"] as? Int, 9)

        let consume = #"{"requestId":"\#(requestID)","kind":"HINT","nodeId":9,"consumed":false,"byMemberId":8,"pool":\#(pool),"hint":{"level":1,"type":"TEXT","content":"Look under the bridge"}}"#
        transport.responses = [(Data(#"{"code":200,"data":{"requestId":"\#(requestID)","state":"APPLIED","result":\#(consume)}}"#.utf8), 200)]
        await model.recover()
        XCTAssertEqual(model.hint, TeamPoolHint(level: 1, type: "TEXT", content: "Look under the bridge"))
        XCTAssertTrue(model.coveredByTeam)
        XCTAssertNil(model.notice)
        XCTAssertEqual(transport.requests.last?.url?.path, "/prod-api/api/team/pool/requests/\(requestID)")
        XCTAssertEqual(transport.requests.last?.httpMethod, "GET")
    }

    @MainActor func testTeamPoolDefiniteRejectionNeedsMatchingStatus() async throws {
        let configuration = try APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!)
        let transport = PoolTransport()
        let service = TeamPoolService(configuration: configuration, transport: transport, token: { "token" })
        transport.responses = [(Data(#"{"code":409,"msg":"x","errorCode":"TEAM_POOL_EXHAUSTED","outcome_known":true}"#.utf8), 409)]
        do { _ = try await service.hint(teamID: 5, nodeID: 9, requestID: TeamPoolService.newRequestID()); XCTFail() }
        catch { XCTAssertEqual(error as? TeamPoolFailure, .rejected(status: 409, errorCode: "TEAM_POOL_EXHAUSTED")) }
        // HTTP 200 with a 4xx body code is not definite (contract §0.1).
        transport.responses = [(Data(#"{"code":409,"msg":"x","errorCode":"TEAM_POOL_EXHAUSTED"}"#.utf8), 200)]
        do { _ = try await service.hint(teamID: 5, nodeID: 9, requestID: TeamPoolService.newRequestID()); XCTFail() }
        catch { XCTAssertEqual(error as? TeamPoolFailure, .outcomeUnknown) }
        // A disabled pool is not shown.
        transport.responses = [(Data(#"{"code":200,"data":{"teamId":5,"enabled":false,"unavailableReason":"TEAM_POOL_NOT_CONFIGURED"}}"#.utf8), 200)]
        let model = TeamPoolHintModel(service: service, nodeID: 9, resolveTeam: { 5 })
        await model.load()
        XCTAssertFalse(model.isVisible)
        // A HINT result without hint text is malformed.
        let pool = #"{"teamId":5,"enabled":true,"hintsTotal":1,"hintsUsed":1,"hintsLeft":0,"skipsTotal":0,"skipsUsed":0,"skipsLeft":0}"#
        transport.responses = [(Data(#"{"code":200,"data":{"requestId":"abcdefabcdefabcdef","kind":"HINT","nodeId":9,"consumed":true,"pool":\#(pool)}}"#.utf8), 200)]
        do { _ = try await service.hint(teamID: 5, nodeID: 9, requestID: "abcdefabcdefabcdef"); XCTFail() }
        catch { XCTAssertEqual(error as? TeamPoolFailure, .malformed) }
    }

    // MARK: grants: social routes admitted, money still refused

    func testChannelsSocialGrantAdmitsSocialRoutesAndNeverMoney() {
        for path in ["/api/guilds/1/42/channels", "/api/channels/1001", "/api/im/file/upload", "/api/im/video/receipt",
                     "/api/im/voice/upload", "/api/friend/remove", "/api/friend/directory", "/api/friend/channel-invite/command",
                     "/api/join-request/submit", "/api/onboarding/submit", "/api/welcome-screen/get", "/api/team/pool/hint",
                     "/api/team/pool/requests/0123456789abcdef0123456789abcdef", "/api/channels/1001/permissions/2/77",
                     "/api/im/notification-requests/00000000-0000-4000-8000-000000000001", "/api/rank/list"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        for money in ["/api/registration/pay", "/api/registration/pay/app", "/api/pay/create", "/api/withdrawal/create",
                      "/api/club/settlement/withdraw", "/api/wallet/withdraw", "/api/asset/withdraw", "/api/login"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
        for path in ChinaReviewedRouteCapability.channelsSocialOwnerGrant {
            XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path), path)
            XCTAssertNil(ChinaReviewedRouteCapability.forcedOff(path), path)
            // Chain and appeal "withdraw" are social actions; money withdrawal is refused by the checks above.
            for word in ["pay", "wallet", "refund", "settlement", "purchase", "payout", "order", "coupon", "webhook", "audit-log"] {
                XCTAssertFalse(path.lowercased().contains(word), "\(path) \(word)")
            }
            XCTAssertEqual(ChinaReviewedRouteCapability.normalized(path), path, "grant paths are already normalized")
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/webhook"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/audit-log"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/webhook/context"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/webhook/not-issued"))
        for path in ChinaReviewedRouteCapability.beGapImOwnerGrant {
            XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: path), path)
            XCTAssertNil(ChinaReviewedRouteCapability.forcedOff(path), path)
            XCTAssertEqual(ChinaReviewedRouteCapability.normalized(path), path, "grant paths are already normalized")
        }
    }
}

private final class PoolTransport: HTTPTransport {
    var responses: [(Data, Int)] = []
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }
}
