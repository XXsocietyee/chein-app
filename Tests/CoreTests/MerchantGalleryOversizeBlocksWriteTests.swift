#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class GalleryGuardTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let access = #"{"code":200,"data":{"active":true,"merchant":{"id":31},"roleCode":"MERCHANT_OWNER","permissions":["merchant:profile:write","merchant:coop:manage"]}}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if path.hasSuffix("/api/merchant/access/me") { return (Data(access.utf8), 200) }
        if path.hasSuffix("/api/merchant/decor/save") { return (Data(#"{"code":200,"msg":"ok"}"#.utf8), 200) }
        if path.hasSuffix("/api/merchant/coop-profile") {
            return (Data(("{\"code\":200,\"data\":" + MerchantOperationsFixtureData.storeJSON + "}").utf8), 200)
        }
        return (Data(#"{"code":404}"#.utf8), 404)
    }
    func saves() -> [URLRequest] { requests.filter { $0.url?.path.hasSuffix("/api/merchant/decor/save") == true } }
}

@MainActor private final class GalleryGuardJournal: OperationPendingJournal {
    var record: OperationPendingRecord?
    func pending(ownerKey: String, targetKey: String) throws -> OperationPendingRecord? { record }
    func write(_ record: OperationPendingRecord) throws { self.record = record }
    func clear(_ record: OperationPendingRecord) throws { self.record = nil }
}

/// Mini gallery page caps the album at 9 images; the native draft must never reach the write route above that.
@MainActor final class MerchantGalleryOversizeBlocksWriteTests: XCTestCase {
    func testTenImagesCannotBeReviewedOrSaved() async throws {
        let transport = GalleryGuardTransport()
        let config = try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!)
        let session = try MerchantOperationsSession(accountID: 7, epoch: 1, token: "synthetic-token", storageNamespace: "gallery-guard")
        let approval = try OperationEndpointApproval(baseURL: config.baseURL, namespace: session.storageNamespace, accountID: session.accountID, paths: ["api/merchant/decor/save"])
        let reader = MerchantOperationsSessionReader(service: MerchantOperationsService(configuration: config, transport: transport),
                                                     currentSession: { session }, approval: approval, journal: GalleryGuardJournal())
        let owner = MerchantOperationsCoordinator(reader: reader, destination: .gallery)
        await owner.load()
        guard case .gallery(var value) = owner.draft else { return XCTFail("Expected gallery draft") }
        value.gallery = (1...10).map { "synthetic-gallery-\($0)" }
        owner.edit(.gallery(value))
        owner.prepare()
        XCTAssertNil(owner.confirmation)
        XCTAssertEqual(owner.issue, .key("merchant.operations.invalidDraft"))
        XCTAssertTrue(transport.saves().isEmpty)
    }
}
#endif
