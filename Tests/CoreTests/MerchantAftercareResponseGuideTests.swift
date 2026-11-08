import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(QuestifyCore)
@testable import QuestifyCore

private actor AftercareGuideTransport: MerchantBusinessTestTransport {
    var requests: [URLRequest] = []
    let response: String
    init(_ response: String) { self.response = response }
    func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(response.utf8), 200) }
}

/// Source pages/merchant/aftercare/detail/view-model.js buildResponseDraft + respond request shape.
final class MerchantAftercareResponseGuideTests: XCTestCase {
    private let key = "upload/merchant-aftercare-evidence/0123456789abcdef0123456789abcdef.jpg"
    private let receipt = #"{"code":200,"data":{"id":1,"refundId":62001,"decision":"REJECT","processing":"WAITING_PLATFORM_REVIEW","merchantOpinion":"REJECT","refunded":false}}"#

    func testDraftIssuesFollowSourceOrder() {
        XCTAssertEqual(MerchantAftercareResponseDraft(decision: nil).issue, .decisionRequired)
        XCTAssertEqual(MerchantAftercareResponseDraft(decision: .agree, content: String(repeating: "a", count: 501)).issue, .contentTooLong)
        XCTAssertEqual(MerchantAftercareResponseDraft(decision: .reject, content: "  \n").issue, .reasonRequired)
        XCTAssertEqual(MerchantAftercareResponseDraft(decision: .agree, evidenceKey: "upload/other.jpg").issue, .evidenceInvalid)
        XCTAssertEqual(MerchantAftercareResponseDraft(decision: .evidence).issue, .evidenceRequired)
        XCTAssertNil(MerchantAftercareResponseDraft(decision: .agree).issue)
        XCTAssertNil(MerchantAftercareResponseDraft(decision: .evidence, evidenceKey: key).issue)
        XCTAssertNil(MerchantAftercareResponseDraft(decision: .reject, content: "Reason", evidenceKey: key).issue)
    }

    func testVisibleDecisionsKeepSourceOrderAndDropUnknownOrReadOnly() {
        XCTAssertEqual(MerchantAftercareResponseGuide.visibleDecisions(allowed: ["EVIDENCE", "AGREE", "BOGUS"], canRespond: true), [.agree, .evidence])
        XCTAssertTrue(MerchantAftercareResponseGuide.visibleDecisions(allowed: ["AGREE"], canRespond: false).isEmpty)
        XCTAssertTrue(MerchantAftercareResponseGuide.requiresDangerConfirmation(.reject))
        XCTAssertFalse(MerchantAftercareResponseGuide.requiresDangerConfirmation(.agree))
    }

    func testInvalidDraftBuildsNoMutationSoNothingIsSent() throws {
        let refund = try MerchantRefundID(62001)
        XCTAssertNil(MerchantAftercareResponseDraft(decision: .reject, content: "").mutation(refund: refund))
        XCTAssertNil(MerchantAftercareResponseDraft(decision: .evidence).mutation(refund: refund))
    }

    @MainActor func testValidDraftSendsRefundQueryAndJSONBodyThroughFakeTransport() async throws {
        let fake = AftercareGuideTransport(receipt)
        let service = try MerchantBusinessService(configuration: .init(baseURL: URL(string: "https://example.com/test")!),
                                                  readTransport: fake, testingMutationTransport: fake)
        let refund = try MerchantRefundID(62001)
        let draft = MerchantAftercareResponseDraft(decision: .reject, content: "  Reason  ", evidenceKey: key)
        let mutation = try XCTUnwrap(draft.mutation(refund: refund))
        let sent = try await service.execute(mutation, requestID: "ma:test:1", token: "synthetic-token")
        XCTAssertFalse(sent.refundActuallyConfirmed, "an opinion is never relabeled as an executed refund")
        let requests = await fake.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.url?.path, "/test/api/merchant/aftercare/respond")
        XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "refundId", value: "62001")])
        XCTAssertEqual(request.httpMethod, "POST")
        let object = try JSONDecoder().decode(MerchantBusinessValue.self, from: XCTUnwrap(request.httpBody)).object
        XCTAssertEqual(object?["decision"], .string("REJECT"))
        XCTAssertEqual(object?["content"], .string("Reason"))
        XCTAssertEqual(object?["requestId"], .string("ma:test:1"))
        XCTAssertEqual(object?["evidenceKeys"], .array([.string(key)]))
    }

    @MainActor func testMalformedReceiptDoesNotCountAsSuccess() async throws {
        let fake = AftercareGuideTransport(#"{"code":200,"data":null}"#)
        let service = try MerchantBusinessService(configuration: .init(baseURL: URL(string: "https://example.com/test")!),
                                                  readTransport: fake, testingMutationTransport: fake)
        let mutation = try XCTUnwrap(MerchantAftercareResponseDraft(decision: .agree).mutation(refund: MerchantRefundID(62001)))
        do { _ = try await service.execute(mutation, requestID: "ma:test:2", token: "synthetic-token"); XCTFail("must not succeed") }
        catch { XCTAssertEqual(error as? MerchantBusinessFailure, .malformed) }
    }
}
#endif
