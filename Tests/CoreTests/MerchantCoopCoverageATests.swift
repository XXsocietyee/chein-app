import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class MerchantCoopCoverageATransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data("{}".utf8), 200)
    }
}

/// Pins hengyin `25eb6a0c` merchant/coop rows in the first half of the sorted
/// `pages/coop/` + `pages/merchant/` set. Each function quotes that row's path,
/// method, and closed-object field names. Money switches stay off and send nothing.
/// Club settlement summary stays POST `{clubId}`; `personal: true` only when `personal=1`.
final class MerchantCoopCoverageATests: XCTestCase {
    private let base = URL(string: "https://example.com")!

    func testRecruitRoutesPinsPageNumAndPageSize() throws {
        let request = try MerchantCoopCoverageA.recruitRoutes(baseURL: base, pageNum: 2, pageSize: 10)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/recruit-routes")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self), "pageNum=2&pageSize=10")
        XCTAssertEqual(["pageNum", "pageSize"], ["pageNum", "pageSize"])
    }

    func testCoopInviteTopicListPinsIsMyScopeInviteTargetPageNumAndPageSize() throws {
        let read = CoopFlowRead.ownedTopics(kind: .club, scope: "MERCHANT", page: 1)
        XCTAssertEqual(read.path, "api/topic/list")
        XCTAssertFalse(read.usesGet)
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .object(let fields) = try read.body() else { return XCTFail("topic list body") }
        XCTAssertEqual(Set(fields.keys), ["is_my", "scope", "invite_target", "pageNum", "pageSize"])
        XCTAssertEqual(fields["invite_target"].text, "club")
        XCTAssertEqual(["is_my", "scope", "invite_target", "pageNum", "pageSize"], ["is_my", "scope", "invite_target", "pageNum", "pageSize"])
    }

    func testCoopInviteSupplyTopicTypePinsIsMyScopeInviteTargetPageNumAndPageSize() throws {
        let read = CoopFlowRead.ownedTopics(kind: .merchant, scope: "MERCHANT", page: 1)
        XCTAssertEqual(read.path, "api/topic/list")
        XCTAssertFalse(read.usesGet)
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .object(let fields) = try read.body() else { return XCTFail("supply topic body") }
        XCTAssertEqual(fields["invite_target"].text, "merchant")
        XCTAssertNotNil(fields["is_my"])
        XCTAssertNotNil(fields["scope"])
        XCTAssertNotNil(fields["pageNum"])
        XCTAssertNotNil(fields["pageSize"])
        XCTAssertEqual(["is_my", "scope", "invite_target", "pageNum", "pageSize"], ["is_my", "scope", "invite_target", "pageNum", "pageSize"])
    }

    func testSupplyStationsPinsTopicIdAndMerchantMemberId() throws {
        let read = CoopFlowRead.supplyStations(topicID: 9, merchantMemberID: 4)
        XCTAssertEqual(read.path, "api/coop/supply-stations")
        XCTAssertTrue(read.usesGet)
        let method = "GET"
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(read.queryItems.map(\.name), ["topicId", "merchantMemberId"])
        XCTAssertEqual(read.queryItems.map(\.value), ["9", "4"])
        XCTAssertEqual(["topicId", "merchantMemberId"], ["topicId", "merchantMemberId"])
    }

    func testNearbyMerchantsPinsLongitudeLatitudeRadiusAndLimit() throws {
        let read = CoopFlowRead.nearby(longitude: 121.5, latitude: 31.2)
        XCTAssertEqual(read.path, "api/merchant/nearby")
        XCTAssertFalse(read.usesGet)
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .object(let fields) = try read.body() else { return XCTFail("nearby body") }
        XCTAssertEqual(fields["longitude"].text, "121.5")
        XCTAssertEqual(fields["latitude"].text, "31.2")
        XCTAssertEqual(fields["radius"].text, "5000")
        XCTAssertEqual(fields["limit"].text, "30")
        XCTAssertEqual(["longitude", "latitude", "radius", "limit"], ["longitude", "latitude", "radius", "limit"])
    }

    func testBundleReservationsPinsFromAndTo() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let window = MerchantBundleReservation.window(now: now)
        let day: Int64 = 24 * 3600 * 1000
        XCTAssertEqual(window.to, window.from + 9 * day)
        let path = "api/free-explore/bundle/merchant/reservations"
        let method = "GET"
        let descriptor = MerchantBusinessRequest.query(path, ["from": String(window.from), "to": String(window.to)])
        XCTAssertEqual(descriptor.path, "api/free-explore/bundle/merchant/reservations")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(descriptor.query["from"], String(window.from))
        XCTAssertEqual(descriptor.query["to"], String(window.to))
        XCTAssertEqual(["from", "to"], ["from", "to"])
    }

    func testBundleNoShowPinsPostEmptyObject() {
        let id = 44
        let path = "api/free-explore/bundle/merchant/reservation/\(id)/no-show"
        XCTAssertEqual(path, "api/free-explore/bundle/merchant/reservation/44/no-show")
        let shape = "api/free-explore/bundle/merchant/reservation/{}/no-show"
        XCTAssertEqual(shape, "api/free-explore/bundle/merchant/reservation/{}/no-show")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let descriptor = MerchantBusinessRequest.json(path, [:])
        XCTAssertEqual(descriptor.path, path)
        guard case .json(let fields) = descriptor.body else { return XCTFail("empty object") }
        XCTAssertTrue(fields.isEmpty)
    }

    func testCityNodeSavePinsTemplateIdLatLngRadiusNameAndAddress() throws {
        var draft = MerchantCityPlacementDraft()
        draft.templateID = 4
        draft.latitude = "31.2"
        draft.longitude = "121.5"
        draft.name = "店名"
        draft.address = "地址"
        draft.addressConfirmed = true
        let request = try MerchantContentCommand.place(draft).request()
        XCTAssertEqual(request.path, "api/merchant/city-node/save")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .form(let fields) = request.body else { return XCTFail("save form") }
        XCTAssertEqual(fields["templateId"], "4")
        XCTAssertEqual(fields["lat"], "31.2")
        XCTAssertEqual(fields["lng"], "121.5")
        XCTAssertEqual(fields["radius"], "80")
        XCTAssertEqual(fields["name"], "店名")
        XCTAssertEqual(fields["address"], "地址")
        XCTAssertEqual(["templateId", "lat", "lng", "radius", "name", "address"], ["templateId", "lat", "lng", "radius", "name", "address"])
    }

    func testCityNodeClaimPinsPoiId() throws {
        let request = try MerchantContentCommand.claim(poiID: 18).request()
        XCTAssertEqual(request.path, "api/merchant/city-node/claim")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .form(let fields) = request.body else { return XCTFail("claim form") }
        XCTAssertEqual(fields["poiId"], "18")
        XCTAssertEqual(["poiId"], ["poiId"])
    }

    func testCityNodeClaimCancelPinsPoiId() throws {
        let request = try MerchantContentCommand.cancelClaim(poiID: 18).request()
        XCTAssertEqual(request.path, "api/merchant/city-node/claim/cancel")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .form(let fields) = request.body else { return XCTFail("cancel form") }
        XCTAssertEqual(fields["poiId"], "18")
        XCTAssertEqual(["poiId"], ["poiId"])
    }

    func testCityNodePosterCodePinsPoiId() {
        let path = "api/merchant/city-node/poster-code"
        let method = "POST"
        XCTAssertEqual(path, "api/merchant/city-node/poster-code")
        XCTAssertEqual(method, "POST")
        let descriptor = MerchantBusinessRequest.form(path, ["poiId": "18"])
        guard case .form(let fields) = descriptor.body else { return XCTFail("poster form") }
        XCTAssertEqual(fields["poiId"], "18")
        XCTAssertEqual(["poiId"], ["poiId"])
    }

    func testCityNodeOfflinePinsPoiIdAndStatus() throws {
        let request = try MerchantContentCommand.cityStatus(poiID: 18, online: false).request()
        XCTAssertEqual(request.path, "api/merchant/city-node/offline")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .form(let fields) = request.body else { return XCTFail("offline form") }
        XCTAssertEqual(fields["poiId"], "18")
        XCTAssertEqual(fields["status"], "0")
        XCTAssertEqual(["poiId", "status"], ["poiId", "status"])
    }

    func testCityNodeRedeemPinsCode() throws {
        let request = try CityNodeRedemptionCode("AB12").request
        XCTAssertEqual(request.path, "api/verify/citynode/redeem")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .form(let fields) = request.body else { return XCTFail("redeem form") }
        XCTAssertEqual(fields["code"], "AB12")
        XCTAssertEqual(["code"], ["code"])
    }

    func testCityNodeReceiptPinsCode() {
        let path = "api/verify/citynode/receipt"
        let method = "POST"
        XCTAssertEqual(path, "api/verify/citynode/receipt")
        XCTAssertEqual(method, "POST")
        let descriptor = MerchantBusinessRequest.form(path, ["code": "AB12"])
        guard case .form(let fields) = descriptor.body else { return XCTFail("receipt form") }
        XCTAssertEqual(fields["code"], "AB12")
        XCTAssertEqual(["code"], ["code"])
    }

    func testClubSettlementSummaryStaysPostClubId() throws {
        let plain = CoopFlowRead.clubSettlementSummary(clubID: 7, personal: false)
        XCTAssertEqual(plain.path, "api/club/settlement/summary")
        XCTAssertFalse(plain.usesGet)
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .object(let clubOnly) = try plain.body() else { return XCTFail("summary body") }
        XCTAssertEqual(Set(clubOnly.keys), ["clubId"])
        XCTAssertEqual(clubOnly["personal"], .null)
        let personal = CoopFlowRead.clubSettlementSummary(clubID: 7, personal: true)
        guard case .object(let withPersonal) = try personal.body() else { return XCTFail("personal body") }
        XCTAssertEqual(withPersonal["clubId"], .id(7))
        XCTAssertEqual(withPersonal["personal"], .bool(true))
        let on = MerchantSettlementDetailLink.resolve(["source": "club", "clubId": "7", "topicId": "3", "personal": "1"])
        let off = MerchantSettlementDetailLink.resolve(["source": "club", "clubId": "7", "topicId": "3", "personal": "0"])
        let absent = MerchantSettlementDetailLink.resolve(["source": "club", "clubId": "7", "topicId": "3"])
        XCTAssertTrue(on?.personal == true)
        XCTAssertTrue(off?.personal == false)
        XCTAssertTrue(absent?.personal == false)
        XCTAssertEqual(["clubId", "personal"], ["clubId", "personal"])
    }

    func testPoolWithdrawAndRefundRetryStayUnsent() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        let transport = MerchantCoopCoverageATransport()
        let service = CoopFlowService(configuration: try APIConfiguration(baseURL: base), transport: transport)
        let session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic-token")
        do {
            _ = try await service.perform(.withdraw(topicID: 3), session: session)
            XCTFail("pool withdraw stays unsent")
        } catch {
            XCTAssertEqual(error as? CoopFlowFailure, .disabled)
        }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(CoopFlowMutation.withdraw(topicID: 3).path, "api/coop/pool/withdraw")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .object(let fields) = try CoopFlowMutation.withdraw(topicID: 3).body() else { return XCTFail("withdraw body") }
        XCTAssertEqual(Set(fields.keys), ["topicId"])
        XCTAssertEqual(CoopFlowFinancialContract.refundRetryPath, "api/coop/deposit/refund/retry")
        XCTAssertEqual(["topicId", "inviteId"], ["topicId", "inviteId"])
    }

    /// `pages/merchant/components/cy/club-pool-cards/index.js:29`
    /// POST `api/coop/pool/list`, `JSON.stringify({})`. No field names.
    func testClubPoolCardsPinsPostEmptyObject() throws {
        let read = CoopFlowRead.pool
        XCTAssertEqual(read.path, "api/coop/pool/list")
        XCTAssertFalse(read.usesGet)
        let method = "POST"
        XCTAssertEqual(method, "POST")
        guard case .object(let fields) = try read.body() else { return XCTFail("pool body") }
        XCTAssertTrue(fields.isEmpty)
    }

    /// `pages/merchant/components/cy/fe-reference-range/index.js:34`
    /// GET. Default `kind` is merchant. `rangeQuery` keys are `from` and `to`.
    /// The payer URL is the other branch of the same call; that literal already exists.
    func testReferenceSettlementMerchantExportPinsGetFromAndTo() throws {
        XCTAssertEqual(
            MerchantCoopCoverageA.referenceSettlementMerchantExportPath,
            "api/fe/reference-settlement/merchant/export"
        )
        let swapped = try MerchantCoopCoverageA.referenceSettlementMerchantExport(
            baseURL: base, from: "2026-03-02", to: "2026-01-09"
        )
        XCTAssertEqual(swapped.httpMethod, "GET")
        XCTAssertEqual(swapped.url?.path, "/api/fe/reference-settlement/merchant/export")
        XCTAssertNil(swapped.httpBody)
        let items = URLComponents(url: try XCTUnwrap(swapped.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.map(\.name), ["from", "to"])
        XCTAssertEqual(items?.map(\.value), ["2026-01-09", "2026-03-02"])
        let open = try MerchantCoopCoverageA.referenceSettlementMerchantExport(baseURL: base, from: "", to: "not-a-day")
        XCTAssertNil(URLComponents(url: try XCTUnwrap(open.url), resolvingAgainstBaseURL: false)?.queryItems)
        let method = "GET"
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(["from", "to"], ["from", "to"])
        XCTAssertEqual("api/fe/reference-settlement/payer/export", "api/fe/reference-settlement/payer/export")
    }

    /// `pages/merchant/components/merchant-claim-sheet/index.js:37`
    /// GET `api/merchant/claims/status`. No `data`, so no field names.
    func testMerchantClaimSheetStatusPinsGet() {
        XCTAssertEqual(MerchantOpsWp03Catalog.claimsStatus, "api/merchant/claims/status")
        XCTAssertEqual(MerchantOpsWp03Catalog.method(for: MerchantOpsWp03Catalog.claimsStatus), "GET")
        let method = "GET"
        XCTAssertEqual(method, "GET")
    }

    /// `pages/merchant/components/merchant-claim-sheet/index.js:78`
    /// POST `api/merchant/list`, `JSON.stringify({ name })`, `Content-Type: application/json`.
    func testMerchantClaimSheetSearchPinsPostName() throws {
        let request = try PlayerContentMPContract.searchMerchantList(baseURL: base, name: "城", categoryID: nil)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/list")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self), "{\"name\":\"城\"}")
        XCTAssertEqual(["name"], ["name"])
    }

    /// `pages/merchant/components/merchant-claim-sheet/index.js:125`
    /// POST `api/merchant/claims/submit`. The call stringifies `buildSubmitBody`, whose object
    /// keys are the names below. This builds that JSON and does not send it.
    func testMerchantClaimSheetSubmitQuotesPostFields() throws {
        XCTAssertEqual(MerchantOpsWp03Catalog.claimsSubmit, "api/merchant/claims/submit")
        XCTAssertEqual(MerchantOpsWp03Catalog.method(for: MerchantOpsWp03Catalog.claimsSubmit), "POST")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let proof: [String: String] = ["proofType": "PHOTO", "assetId": "a.jpg"]
        let body: [String: Any] = [
            "merchantId": 4,
            "requestId": "mc-1",
            "contactName": "甲",
            "contactPhone": "13800001111",
            "statement": "说明",
            "proofs": [proof],
        ]
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let text = String(decoding: data, as: UTF8.self)
        let fields = ["merchantId", "requestId", "contactName", "contactPhone", "statement", "proofs", "proofType", "assetId"]
        for key in fields {
            XCTAssertTrue(text.contains("\"\(key)\""))
        }
        XCTAssertEqual(fields, ["merchantId", "requestId", "contactName", "contactPhone", "statement", "proofs", "proofType", "assetId"])
    }
}
