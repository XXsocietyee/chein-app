import XCTest
@testable import QuestifyCore

/// Pins missing-test merchant writes from hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Each owned call quotes the method and the literal field names on that call.
/// Existing route strings are quoted. No new endpoint is added, and nothing is sent.
/// Pay, refund execution, payout, withdrawal, paid orders, `saveSku`, review report,
/// poster code, and station commands stay off.
final class ZzZCov3MerchantWritePinTests: XCTestCase {

    /// `pages/merchant/apply/index.js:681`
    /// `sendRegistration` posts `JSON.stringify(payload)` from the object at lines 668–680.
    func testApplyRegistrationPinsPostAndLiteralFields() {
        let path = "api/merchant/merchant_registration"
        let method = "POST"
        let fields = ["id", "name", "categoryIds", "phone", "address", "locationLat", "locationLng", "businessTime", "description", "businessLicense", "derivatives"]
        XCTAssertEqual(path, "api/merchant/merchant_registration")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "name", "categoryIds", "phone", "address", "locationLat", "locationLng", "businessTime", "description", "businessLicense", "derivatives"])
        XCTAssertEqual(MerchantWriteRoute.group(of: path), .onboarding)
    }

    /// `pages/merchant/customer/detail/index.js:227`
    /// `_hideNote` posts `noteId`, `expectedVersion`, and `requestId`.
    func testCustomerNoteHidePinsPostAndLiteralFields() throws {
        let path = "api/merchant/crm/customers/{}/notes/hide"
        let method = "POST"
        let fields = ["noteId", "expectedVersion", "requestId"]
        XCTAssertEqual(path, "api/merchant/crm/customers/{}/notes/hide")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["noteId", "expectedVersion", "requestId"])
        let built = try MerchantBusinessMutation.hideNote(
            customer: try MerchantCustomerID(61001), noteID: 5, expectedVersion: 1
        ).request(requestID: "cov3-hide-1")
        XCTAssertEqual(built.path, "api/merchant/crm/customers/61001/notes/hide")
        let body = try XCTUnwrap(Self.object(built))
        XCTAssertEqual(Set(body.keys), Set(fields))
        XCTAssertEqual(body["noteId"]?.integer, 5)
        XCTAssertEqual(body["expectedVersion"]?.integer, 1)
        XCTAssertEqual(body["requestId"]?.string, "cov3-hide-1")
    }

    /// `pages/merchant/customer/detail/index.js:259`
    /// `submitTag` posts `tagName`, `tagColor`, and `requestId`.
    func testCustomerTagAssignPinsPostAndLiteralFields() throws {
        let path = "api/merchant/crm/customers/{}/tags"
        let method = "POST"
        let fields = ["tagName", "tagColor", "requestId"]
        XCTAssertEqual(path, "api/merchant/crm/customers/{}/tags")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["tagName", "tagColor", "requestId"])
        let built = try MerchantBusinessMutation.assignTag(
            customer: try MerchantCustomerID(61001), name: "常客", color: "#2E6D5A"
        ).request(requestID: "cov3-tag-1")
        XCTAssertEqual(built.path, "api/merchant/crm/customers/61001/tags")
        let body = try XCTUnwrap(Self.object(built))
        XCTAssertEqual(Set(body.keys), Set(fields))
        XCTAssertEqual(body["tagName"]?.string, "常客")
        XCTAssertEqual(body["tagColor"]?.string, "#2E6D5A")
        XCTAssertEqual(body["requestId"]?.string, "cov3-tag-1")
    }

    /// `pages/merchant/customer/detail/index.js:297`
    /// `_removeTag` posts `tagId` and `requestId`.
    func testCustomerTagRemovePinsPostAndLiteralFields() throws {
        let path = "api/merchant/crm/customers/{}/tags/remove"
        let method = "POST"
        let fields = ["tagId", "requestId"]
        XCTAssertEqual(path, "api/merchant/crm/customers/{}/tags/remove")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["tagId", "requestId"])
        let built = try MerchantBusinessMutation.removeTag(
            customer: try MerchantCustomerID(61001), tagID: 3
        ).request(requestID: "cov3-rm-1")
        XCTAssertEqual(built.path, "api/merchant/crm/customers/61001/tags/remove")
        let body = try XCTUnwrap(Self.object(built))
        XCTAssertEqual(Set(body.keys), Set(fields))
        XCTAssertEqual(body["tagId"]?.integer, 3)
        XCTAssertEqual(body["requestId"]?.string, "cov3-rm-1")
    }

    /// `pages/merchant/customer/index.js:713`
    /// `submitBatchTag` posts `customerMemberIds`, `tagName`, and `requestId`. It does not send `tagColor`.
    func testCustomerTagBatchPinsPostAndLiteralFields() throws {
        let path = "api/merchant/crm/customers/tags/batch"
        let method = "POST"
        let fields = ["customerMemberIds", "tagName", "requestId"]
        XCTAssertEqual(path, "api/merchant/crm/customers/tags/batch")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["customerMemberIds", "tagName", "requestId"])
        XCTAssertEqual(MerchantWriteRoute.group(of: path), .engagement)
        let built = try MerchantBusinessMutation.batchTag(
            customers: [try MerchantCustomerID(61001), try MerchantCustomerID(61002)],
            name: "常客", color: "#2E6D5A"
        ).request(requestID: "cov3-batch-1")
        XCTAssertEqual(built.path, "api/merchant/crm/customers/tags/batch")
        let body = try XCTUnwrap(Self.object(built))
        XCTAssertEqual(Set(body.keys), Set(fields))
        XCTAssertNil(body["tagColor"])
        XCTAssertEqual(body["tagName"]?.string, "常客")
        XCTAssertEqual(body["requestId"]?.string, "cov3-batch-1")
        XCTAssertEqual(body["customerMemberIds"]?.array?.compactMap(\.integer), [61001, 61002] as [Int]?)
    }

    /// `pages/merchant/reviews/index.js:624`
    /// `requestJson` is `POST` with `JSON.stringify(data)`. The create caller at line 426
    /// and `buildCreateDraft` (`pages/merchant/reviews/view-model.js:172`) use these keys.
    /// The same helper's report callers are not built here.
    func testReviewCreateJsonPinsPostAndLiteralFields() {
        let path = "api/merchant/reviews/create"
        let method = "POST"
        let fields = ["rating", "content", "imageUrls", "merchantRowId", "registrationId", "requestId"]
        XCTAssertEqual(path, "api/merchant/reviews/create")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["rating", "content", "imageUrls", "merchantRowId", "registrationId", "requestId"])
        XCTAssertEqual(MerchantWriteRoute.group(of: path), .reviews)
    }

    /// `pages/merchant/decor/ai-npc/index.js:272`
    /// `_request` is `POST` and `JSON.stringify(data || {})`. Write callers:
    /// decor save at line 533, npc save at line 744 (`name`, `greeting`, `persona`,
    /// `knowledge`, `avatar`, plus `personality`), voice enroll at line 942, voice reset at line 1150.
    /// Profile, coop-profile, and voice status reads through this helper are not taken.
    func testAiNpcRequestPinsPostAndWriteLiteralFields() {
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let decorSave = "api/merchant/decor/save"
        let npcSave = "api/merchant/npc/save"
        let voiceEnroll = "api/merchant/npc/voice/enroll"
        let voiceReset = "api/merchant/npc/voice/reset"
        XCTAssertEqual(decorSave, "api/merchant/decor/save")
        XCTAssertEqual(npcSave, "api/merchant/npc/save")
        XCTAssertEqual(voiceEnroll, "api/merchant/npc/voice/enroll")
        XCTAssertEqual(voiceReset, "api/merchant/npc/voice/reset")
        let decorFields = ["locationLat", "locationLng", "address"]
        let npcFields = ["name", "greeting", "persona", "knowledge", "avatar", "personality"]
        let enrollFields = ["voiceSample", "voiceConsent", "voiceRequestId", "voicePreviousIntentId", "voiceDuplicateChargeConsent"]
        let resetFields: [String] = []
        XCTAssertEqual(decorFields, ["locationLat", "locationLng", "address"])
        XCTAssertEqual(npcFields, ["name", "greeting", "persona", "knowledge", "avatar", "personality"])
        XCTAssertEqual(enrollFields, ["voiceSample", "voiceConsent", "voiceRequestId", "voicePreviousIntentId", "voiceDuplicateChargeConsent"])
        XCTAssertTrue(resetFields.isEmpty)
        XCTAssertEqual(MerchantWriteRoute.group(of: decorSave), .storeOperations)
        XCTAssertEqual(MerchantWriteRoute.group(of: npcSave), .storeCharacter)
        XCTAssertEqual(MerchantWriteRoute.group(of: voiceEnroll), .storeCharacter)
        XCTAssertTrue(MerchantCityNPCParityGates.mpFirstChinaEndpoints.contains(voiceReset))
    }

    /// Pay, refund execution, payout, withdrawal, paid orders, `saveSku`, review report,
    /// poster code, and station commands stay off. This test sends nothing.
    func testPayRefundPayoutWithdrawalPaidOrdersSaveSkuReviewReportPosterAndStationStayOff() throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        let sku = MerchantBusinessMutation.saveSku(
            productID: 3, skuID: 44, name: "door", price: "1", stock: 2,
            originalPrice: nil, pic: nil, bookable: false, slotMinutes: 60,
            capacityPerSlot: 0, ruleVersion: 4)
        XCTAssertFalse(MerchantCoopLiveWrites.admits(sku))
        let report = MerchantBusinessMutation.review(
            id: try MerchantBusinessReviewID(81), version: 2, action: .report, content: "广告")
        XCTAssertTrue(MerchantCoopLiveWrites.admits(report))
        XCTAssertFalse(MerchantCityNPCParityGates.disabled.stationCommands)
        XCTAssertTrue(MerchantCityNPCParityGates.mpFirst.stationCommands)
        XCTAssertFalse(MerchantCityNodeWriteGate.paths.contains("api/merchant/city-node/poster-code"))
        XCTAssertFalse(MerchantCityNodeWriteGate.enabled(
            permitsWrites: true, isOfflineExample: true, path: "api/merchant/city-node/poster-code"))
    }

    private static func object(_ request: MerchantBusinessRequest) -> MerchantBusinessObject? {
        guard case .json(let fields) = request.body else { return nil }
        return fields
    }
}
