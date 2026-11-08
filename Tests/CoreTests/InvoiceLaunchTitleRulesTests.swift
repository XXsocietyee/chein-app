#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class InvoiceLaunchTitleRulesTests: XCTestCase {
    private typealias S = InvoiceLaunchTestSupport

    func testPersonalNeedsOnlyTrimmedNonEmptyNameUpToOneHundred() {
        XCTAssertTrue(InvoiceLaunchTitleRules.canSubmit(type: "PERSONAL", name: " Synthetic ", tax: ""))
        XCTAssertFalse(InvoiceLaunchTitleRules.canSubmit(type: "PERSONAL", name: "   ", tax: ""))
        XCTAssertTrue(InvoiceLaunchTitleRules.canSubmit(type: "PERSONAL", name: String(repeating: "a", count: 100), tax: ""))
        XCTAssertFalse(InvoiceLaunchTitleRules.canSubmit(type: "PERSONAL", name: String(repeating: "a", count: 101), tax: ""))
        XCTAssertFalse(InvoiceLaunchTitleRules.canSubmit(type: "OTHER", name: "Synthetic", tax: ""))
    }

    func testCompanyTaxNumberMustBeFifteenToTwentyDigitsOrLetters() {
        XCTAssertTrue(InvoiceLaunchTitleRules.isValidTax("913456789012345"))
        XCTAssertTrue(InvoiceLaunchTitleRules.isValidTax(" 91345678901234567890 "))
        XCTAssertTrue(InvoiceLaunchTitleRules.isValidTax("91345678abcd345678"))
        XCTAssertFalse(InvoiceLaunchTitleRules.isValidTax("91345678901234"))
        XCTAssertFalse(InvoiceLaunchTitleRules.isValidTax("913456789012345678901"))
        XCTAssertFalse(InvoiceLaunchTitleRules.isValidTax("9134567890****5678"))
        XCTAssertFalse(InvoiceLaunchTitleRules.isValidTax("91345678-012345678"))
        XCTAssertFalse(InvoiceLaunchTitleRules.canSubmit(type: "COMPANY", name: "Synthetic", tax: ""))
        XCTAssertTrue(InvoiceLaunchTitleRules.canSubmit(type: "COMPANY", name: "Synthetic", tax: "913456789012345678"))
    }

    func testDraftTrimsNameUppercasesTaxAndDropsTaxForPersonal() throws {
        let company = try InvoiceLaunchTitleRules.draft(id: nil, type: "COMPANY", name: "  Synthetic Co  ", tax: " 91345678abcd345678 ", isDefault: true)
        XCTAssertEqual(company.titleName, "Synthetic Co"); XCTAssertEqual(company.taxNo, "91345678ABCD345678"); XCTAssertTrue(company.isDefault)
        let personal = try InvoiceLaunchTitleRules.draft(id: 11, type: "PERSONAL", name: "Synthetic", tax: "913456789012345678", isDefault: false)
        XCTAssertNil(personal.taxNo); XCTAssertEqual(personal.id, 11)
        XCTAssertThrowsError(try InvoiceLaunchTitleRules.draft(id: nil, type: "COMPANY", name: "Synthetic", tax: "short", isDefault: false)) {
            XCTAssertEqual($0 as? InvoiceLaunchIssue, .invalid)
        }
        XCTAssertThrowsError(try InvoiceLaunchTitleRules.draft(id: 0, type: "PERSONAL", name: "Synthetic", tax: "", isDefault: false))
    }

    /// Main action through the fake transport: the form-built draft is what reaches the wire.
    func testFormDraftIsTheExactBodySentToTheSaveRoute() async throws {
        let h = try S.Harness(); h.wire.responses = [try S.success(S.title), try S.success([S.title])]
        let draft = try InvoiceLaunchTitleRules.draft(id: nil, type: "COMPANY", name: " Synthetic Co ", tax: "91345678abcd345678", isDefault: false)
        let saved = try await h.coordinator().saveTitle(draft)
        XCTAssertEqual(saved.id, 11); XCTAssertNil(try h.store.load())
        let body = try JSONSerialization.jsonObject(with: try XCTUnwrap(h.wire.requests[0].httpBody)) as! [String: Any]
        XCTAssertEqual(body["titleName"] as? String, "Synthetic Co")
        XCTAssertEqual(body["taxNo"] as? String, "91345678ABCD345678")
        XCTAssertEqual(body["titleType"] as? String, "COMPANY")
    }

    func testInvalidFormNeverReachesTheTransport() async throws {
        let h = try S.Harness()
        XCTAssertThrowsError(try InvoiceLaunchTitleRules.draft(id: nil, type: "COMPANY", name: "Synthetic", tax: "9134****", isDefault: false))
        XCTAssertTrue(h.wire.requests.isEmpty)
    }
}
#endif
