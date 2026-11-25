#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One flag per gate. Node, NPC, cancel, audit, circle review, register, update, and chapter invite default on.
/// Chapter respond, apply, and withdraw stay closed. City-node writes follow MerchantCoopLiveWrites.cityNode.
private final class MPFirstNoNetworkTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw URLError(.notConnectedToInternet) }
}

@MainActor final class MerchantContentMPFirstApprovalTests: XCTestCase {
    private func service(_ approval: MerchantContentWriteApproval) throws -> MerchantContentService {
        let session = try MerchantContentSession(accountID: 1, epoch: 1, storageScope: "test-realm", token: "synthetic-token")
        return MerchantContentService(configuration: try APIConfiguration(baseURL: URL(string: "https://merchant-info.example")!),
                                      transport: MPFirstNoNetworkTransport(), currentSession: { session },
                                      journal: MerchantContentMemoryPendingStorage(), writeApproval: { approval })
    }
    private func draft() -> MerchantRegistrationContentDraft {
        var d = MerchantRegistrationContentDraft()
        d.addressName = "Synthetic shop"; d.address = "Synthetic road 1"; d.activityDesc = "Synthetic desc"; d.picUrl = "https://img.example/a.png"
        return d
    }

    func test_mp_first_defaults_open_every_merchantinfo_and_merchantapply_write() throws {
        let a = MerchantContentWriteApproval()
        XCTAssertTrue(a.chapterInvite)
        XCTAssertFalse(a.chapterRespond || a.chapterApply || a.chapterWithdraw)
        XCTAssertTrue(a.register && a.updateRegistration && a.cancel && a.node && a.audit && a.circleReview && a.npc)
        let s = try service(.init())
        let open: [MerchantContentCommand] = [
            .register(topicID: 70, nodeID: 9, draft: draft(), cooperateDate: ""),
            .updateRegistration(id: 5, topicID: 70, draft: draft()), .cancelRegistration(id: 5),
            .submitNode(chapterID: 7, draft: MerchantChapterContentDraft()),
            .auditApplication(id: 3, approve: true, reason: ""), .auditNode(nodeID: 9, approve: true, reason: ""),
            .reviewCircle(topicID: 70, scope: "MERCHANT"),
            .saveNPC(nodeID: 9, name: "n", avatar: "a", greeting: "g"), .enrollVoice(nodeID: 9, voiceSample: "s"), .resetVoice(nodeID: 9),
            .invite(chapterID: 7, merchantMemberID: 3, replacementOfOfferID: 1, scope: "MERCHANT", message: nil),
            .claim(poiID: 1), .cancelClaim(poiID: 1), .cityStatus(poiID: 1, online: false), .place(MerchantCityPlacementDraft()),
        ]
        let closedCommands: [MerchantContentCommand] = [
            .apply(chapterID: 7, message: ""), .withdraw(applicationID: 3),
        ]
        for command in open { XCTAssertTrue(s.permits(command), command.key) }
        for command in closedCommands { XCTAssertFalse(s.permits(command), command.key) }
        XCTAssertTrue(s.permitsWrites)
        let closed = try service(.closed)
        for command in open + closedCommands { XCTAssertFalse(closed.permits(command), command.key) }
        XCTAssertFalse(closed.permitsWrites)
    }

    /// The protocol requirement lets `any MerchantContentServing` callers (review confirm button) see the real approval.
    func test_existential_caller_reaches_real_approval() throws {
        let s: any MerchantContentServing = try service(.init())
        XCTAssertTrue(s.permits(.register(topicID: 70, nodeID: 9, draft: draft(), cooperateDate: "")))
    }

    /// MP merchantapply/index.js:651-673: POST JSON create / update.
    func test_register_and_update_request_shape_matches_merchantapply() throws {
        let create = try MerchantContentCommand.register(topicID: 70, nodeID: 9, draft: draft(), cooperateDate: "周末").request()
        XCTAssertEqual(create.path, "api/registration/merchant/create")
        guard case .json(let c) = create.body else { return XCTFail("create must be JSON") }
        XCTAssertEqual(c["topicId"], .integer(70)); XCTAssertEqual(c["nodeId"], .integer(9)); XCTAssertEqual(c["mode"], .integer(1))
        XCTAssertEqual(c["cooperateDate"], .string("周末"))
        for key in ["address", "addressName", "picUrl", "latitude", "longitude", "limitNum", "activityDesc"] { XCTAssertNotNil(c[key], key) }
        let update = try MerchantContentCommand.updateRegistration(id: 5, topicID: 70, draft: draft()).request()
        XCTAssertEqual(update.path, "api/registration/merchant/update")
        guard case .json(let u) = update.body else { return XCTFail("update must be JSON") }
        XCTAssertEqual(u["id"], .integer(5)); XCTAssertEqual(u["topicId"], .integer(70))
    }

    /// MP merchantinfo.js:4859 form `{id}`; :3227 JSON `{topicId, scope}`.
    func test_cancel_and_circle_review_request_shape_matches_merchantinfo() throws {
        let cancel = try MerchantContentCommand.cancelRegistration(id: 5).request()
        XCTAssertEqual(cancel.path, "api/registration/merchant/cancel")
        XCTAssertEqual(cancel.body, .form(["id": "5"]))
        let review = try MerchantContentCommand.reviewCircle(topicID: 70, scope: "MERCHANT").request()
        XCTAssertEqual(review.path, "api/circle-theme/instance/review")
        XCTAssertEqual(review.body, .json(["topicId": .integer(70), "scope": .string("MERCHANT")]))
    }
}
#endif
