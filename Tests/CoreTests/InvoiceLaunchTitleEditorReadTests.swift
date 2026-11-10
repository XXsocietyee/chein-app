#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore

final class InvoiceLaunchTitleEditorReadTests: XCTestCase {
    private let mask = "91******1234"
    private let fullTax = "913456789012345678"
    private let syntheticPhone = "SYNTHETIC_PHONE"
    private let syntheticEmail = "SYNTHETIC_EMAIL"

    func testCreateIsReadyImmediatelyAndDoesNotInventIdentity() {
        for raw in [nil, "", "0", "00", "01", "-1", "9223372036854775808"] {
            XCTAssertNil(InvoiceLaunchTitleEditorRead.editingID(raw), raw ?? "nil")
        }
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.editingID("11"), 11)
        let screen = InvoiceLaunchTitleEditorRead.screen(source: .loading, editingID: nil, pending: nil)
        guard case .ready(let form) = screen else { return XCTFail("Expected a blank ready form") }
        XCTAssertEqual(form, .create)
        XCTAssertEqual(form.idText, "—")
        XCTAssertEqual(form.taxNoMaskedText, "—")
        XCTAssertEqual(form.taxEntry, "")
        XCTAssertFalse(form.isDefault)
        XCTAssertFalse(form.shownFields.contains("0"))
        assertNoInventedIdentity(form)
    }

    func testUnknownSaveKeepsTheBlankFormAndTheOriginalRequestKey() {
        let pending = InvoiceLaunchPending(kind: .saveTitle, titleRequestID: "synthetic-title-request")
        let screen = InvoiceLaunchTitleEditorRead.screen(source: .failed, editingID: 0, pending: pending)
        guard case .unknown(let form, let requestID) = screen else { return XCTFail("Expected UNKNOWN") }
        XCTAssertEqual(form, .create)
        XCTAssertEqual(requestID, "synthetic-title-request")
        XCTAssertEqual(form.taxEntry, "")
        assertNoInventedIdentity(form)
    }

    func testEditStaysLoadingUntilTitlesArriveEvenWhenASaveIsUnknown() throws {
        let pending = InvoiceLaunchPending(kind: .saveTitle, titleRequestID: nil)
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .loading, editingID: 11, pending: pending), .loading)
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .failed, editingID: 11, pending: nil), .error)
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .titles([]), editingID: 11, pending: pending), .error)
        let other = try title(id: 12, type: "PERSONAL", name: "Synthetic", mask: .null, isDefault: false)
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .titles([other]), editingID: 11, pending: nil), .error)
    }

    func testFoundTitleShowsTheMaskAndDropsRawTaxPhoneAndEmail() throws {
        let row = try title(id: 11, type: "COMPANY", name: "Synthetic Co", mask: .text(mask), isDefault: true,
                            extras: ["taxNo": fullTax, "phone": syntheticPhone, "email": syntheticEmail])
        let screen = InvoiceLaunchTitleEditorRead.screen(source: .titles([row]), editingID: 11, pending: nil)
        guard case .ready(let form) = screen else { return XCTFail("Expected the saved title") }
        XCTAssertEqual(form.idText, "11")
        XCTAssertEqual(form.titleType, "COMPANY")
        XCTAssertEqual(form.titleName, "Synthetic Co")
        XCTAssertEqual(form.taxNoMaskedText, mask)
        XCTAssertTrue(form.isDefault)
        XCTAssertEqual(form.taxEntry, "")
        assertNoInventedIdentity(form)
        let pending = InvoiceLaunchPending(kind: .saveTitle, titleRequestID: "0")
        let unknown = InvoiceLaunchTitleEditorRead.screen(source: .titles([row]), editingID: 11, pending: pending)
        guard case .unknown(let held, let requestID) = unknown else { return XCTFail("Expected UNKNOWN") }
        XCTAssertEqual(held.taxNoMaskedText, mask)
        XCTAssertEqual(held.idText, "11")
        XCTAssertEqual(requestID, "0")
        let apply = InvoiceLaunchPending(kind: .apply, apply: try InvoiceLaunchApply(titleId: 11, orderIds: [21]))
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .titles([row]), editingID: 11, pending: apply), .ready(form))
    }

    func testMissingOrUnmaskedTaxIsAnEmDashNeverZero() throws {
        let personal = try title(id: 11, type: "PERSONAL", name: "0", mask: .null, isDefault: false)
        let omitted = try title(id: 11, type: "PERSONAL", name: "Synthetic", mask: .omit, isDefault: false)
        let zero = try title(id: 11, type: "COMPANY", name: "Synthetic", mask: .text("0"), isDefault: false)
        let raw = try title(id: 11, type: "COMPANY", name: "Synthetic", mask: .text(fullTax), isDefault: false)
        let short = try title(id: 11, type: "COMPANY", name: "Synthetic", mask: .text("******"), isDefault: false)
        for row in [personal, omitted, zero, raw] {
            let screen = InvoiceLaunchTitleEditorRead.screen(source: .titles([row]), editingID: 11, pending: nil)
            guard case .ready(let form) = screen else { return XCTFail("Expected a ready title") }
            XCTAssertEqual(form.taxNoMaskedText, "—")
            XCTAssertNotEqual(form.taxNoMaskedText, "0")
            XCTAssertFalse(form.shownFields.contains(fullTax))
        }
        let namedZero = InvoiceLaunchTitleEditorRead.screen(source: .titles([personal]), editingID: 11, pending: nil)
        guard case .ready(let kept) = namedZero else { return XCTFail("Expected the literal name") }
        XCTAssertEqual(kept.titleName, "0")
        let known = InvoiceLaunchTitleEditorRead.screen(source: .titles([short]), editingID: 11, pending: nil)
        guard case .ready(let masked) = known else { return XCTFail("Expected the short mask") }
        XCTAssertEqual(masked.taxNoMaskedText, "******")
    }

    func testLoginAndUnavailableStayEmptyAndDoNotExposeTheTitle() {
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .login, editingID: 11, pending: nil), .empty(.login))
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .unavailable, editingID: nil, pending:
            InvoiceLaunchPending(kind: .saveTitle, titleRequestID: "synthetic-title-request")), .empty(.unavailable))
        let leaked = String(describing: InvoiceLaunchTitleEditorRead.screen(source: .login, editingID: 11, pending: nil))
        XCTAssertFalse(leaked.contains("Synthetic"))
        XCTAssertFalse(leaked.contains(mask))
    }

    func testMissingDefaultAndNumericDefaultDoNotBecomeFalseOrZero() {
        XCTAssertThrowsError(try titleData(["id": "11", "titleType": "PERSONAL", "titleName": "Synthetic", "isDefault": 0]))
        XCTAssertThrowsError(try titleData(["id": "11", "titleType": "PERSONAL", "titleName": "Synthetic"]))
        XCTAssertEqual(InvoiceLaunchTitleEditorRead.screen(source: .failed, editingID: 11, pending: nil), .error)
    }

    private enum TaxMask {
        case null
        case omit
        case text(String)
    }

    private func title(id: Int64, type: String, name: String, mask: TaxMask, isDefault: Bool,
                        extras: [String: String] = [:]) throws -> InvoiceLaunchTitle {
        var body: [String: Any] = ["id": String(id), "titleType": type, "titleName": name, "isDefault": isDefault]
        switch mask {
        case .null: body["taxNoMasked"] = NSNull()
        case .omit: break
        case .text(let text): body["taxNoMasked"] = text
        }
        for (key, value) in extras { body[key] = value }
        return try titleData(body)
    }

    private func titleData(_ body: [String: Any]) throws -> InvoiceLaunchTitle {
        try JSONDecoder().decode(InvoiceLaunchTitle.self, from: JSONSerialization.data(withJSONObject: body))
    }

    private func assertNoInventedIdentity(_ form: InvoiceLaunchTitleEditorForm, file: StaticString = #filePath, line: UInt = #line) {
        let names = Mirror(reflecting: form).children.compactMap(\.label)
        XCTAssertFalse(names.contains("phone"), file: file, line: line)
        XCTAssertFalse(names.contains("email"), file: file, line: line)
        XCTAssertFalse(names.contains("taxNo"), file: file, line: line)
        let shown = form.shownFields.joined(separator: "\n")
        XCTAssertFalse(shown.contains(fullTax), file: file, line: line)
        XCTAssertFalse(shown.contains(syntheticPhone), file: file, line: line)
        XCTAssertFalse(shown.contains(syntheticEmail), file: file, line: line)
    }
}

private extension InvoiceLaunchTitleEditorForm {
    var shownFields: [String] { [idText, titleType, titleName, taxNoMaskedText, taxEntry] }
}
#endif
