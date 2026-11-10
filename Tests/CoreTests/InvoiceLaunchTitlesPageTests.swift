#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class InvoiceLaunchTitlesPageTests: XCTestCase {
    private let dash = InvoiceLaunchTitlesPage.unknownDisplay

    func testUnknownCountIsAnEmDashAndALiteralZeroStaysZero() {
        XCTAssertEqual(dash, "—")
        XCTAssertFalse(InvoiceLaunchTitlesPage.routeMarkedLive)
        XCTAssertEqual(InvoiceLaunchTitlesPage.countText(nil), dash)
        XCTAssertEqual(InvoiceLaunchTitlesPage.countText(0), "0")
        XCTAssertEqual(InvoiceLaunchTitlesPage.countText(2), "2")
        XCTAssertEqual(InvoiceLaunchTitlesPage.countText(numericString: "0"), dash)
        XCTAssertEqual(InvoiceLaunchTitlesPage.countText(numericString: ""), dash)
        XCTAssertNotEqual(InvoiceLaunchTitlesPage.countText(nil), "0")
        XCTAssertNotEqual(InvoiceLaunchTitlesPage.countText(numericString: "0"), "0")
    }

    func testSignedOutAndUnavailableDoNotInventAZeroCount() throws {
        let signedOut = InvoiceLaunchTitlesPage.facts(.init(titles: []))
        XCTAssertEqual(signedOut.phase, .empty)
        XCTAssertEqual(signedOut.countText, dash)
        XCTAssertNotEqual(signedOut.countText, "0")
        XCTAssertTrue(signedOut.rows.isEmpty)
        XCTAssertEqual(signedOut.copyKey, InvoiceLaunchTitlesPage.Copy.signIn)
        XCTAssertEqual(signedOut.accessibilityIdentifier, "invoice.titles.signIn")
        XCTAssertFalse(signedOut.showsPendingSave)
        XCTAssertFalse(signedOut.showsAdd)
        XCTAssertFalse(signedOut.canAdd)
        XCTAssertFalse(signedOut.readOnly)

        let held = InvoiceLaunchTitlesPage.facts(.init(pendingSave: true, pendingRequestKnown: true, titles: try titles(1)))
        XCTAssertEqual(held.phase, .empty)
        XCTAssertEqual(held.countText, dash)
        XCTAssertFalse(held.showsPendingSave)

        let off = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, unavailable: true, titles: []))
        XCTAssertEqual(off.phase, .error)
        XCTAssertEqual(off.copyKey, InvoiceLaunchTitlesPage.Copy.unavailable)
        XCTAssertEqual(off.countText, dash)
        XCTAssertEqual(off.accessibilityIdentifier, "invoice.titles.unavailable")
        XCTAssertFalse(off.showsAdd)
    }

    func testLoadingWinsAndAFailedReadStaysUnknownRatherThanZero() {
        let loading = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, loading: true, failed: true, pendingSave: true))
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.copyKey, InvoiceLaunchTitlesPage.Copy.loading)
        XCTAssertEqual(loading.countText, dash)
        XCTAssertTrue(loading.showsPendingSave)
        XCTAssertEqual(loading.pendingHoldKey, InvoiceLaunchTitlesPage.Copy.pendingHold)
        XCTAssertFalse(loading.canQuerySave)
        XCTAssertFalse(loading.showsAdd)

        let failed = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, failed: true))
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.copyKey, InvoiceLaunchTitlesPage.Copy.error)
        XCTAssertEqual(failed.countText, dash)
        XCTAssertNotEqual(failed.countText, "0")
        XCTAssertEqual(failed.accessibilityIdentifier, "invoice.titles.error")

        let missing = InvoiceLaunchTitlesPage.facts(.init(signedIn: true))
        XCTAssertEqual(missing.phase, .unknown)
        XCTAssertEqual(missing.copyKey, InvoiceLaunchTitlesPage.Copy.unknown)
        XCTAssertEqual(missing.countText, dash)
        XCTAssertFalse(missing.showsPendingSave)
    }

    func testConfirmedEmptyListIsZeroAndAReadyListKeepsItsCount() throws {
        let empty = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, allowsSave: true, titles: []))
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.countText, "0")
        XCTAssertEqual(empty.copyKey, InvoiceLaunchTitlesPage.Copy.empty)
        XCTAssertTrue(empty.showsAdd)
        XCTAssertTrue(empty.canAdd)
        XCTAssertFalse(empty.readOnly)
        XCTAssertEqual(empty.accessibilityIdentifier, "invoice.titles.empty")

        let quiet = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, titles: []))
        XCTAssertEqual(quiet.countText, "0")
        XCTAssertTrue(quiet.readOnly)
        XCTAssertEqual(quiet.readOnlyKey, InvoiceLaunchTitlesPage.Copy.readOnly)
        XCTAssertEqual(quiet.readOnlyIdentifier, "invoice.titlesReadOnly")
        XCTAssertFalse(quiet.canAdd)

        let rows = try titles(2)
        let ready = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, allowsSave: true, allowsDelete: true, titles: rows))
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.countText, "2")
        XCTAssertEqual(ready.copyKey, InvoiceLaunchTitlesPage.Copy.titles)
        XCTAssertEqual(ready.rows.map(\.id), [11, 12])
        XCTAssertEqual(ready.rows.map(\.titleName), ["Synthetic title", "Synthetic title 2"])
        XCTAssertEqual(ready.rows.map(\.typeKey), ["PERSONAL", "COMPANY"])
        XCTAssertEqual(ready.rows[0].taxText, nil)
        XCTAssertEqual(ready.rows[1].taxText, "******")
        XCTAssertFalse(ready.rows[0].showsDefault)
        XCTAssertTrue(ready.rows[1].showsDefault)
        XCTAssertTrue(ready.rows.allSatisfy { $0.canEdit && $0.canDelete })
        XCTAssertTrue(ready.canAdd)
        XCTAssertFalse(ready.readOnly)
        XCTAssertEqual(ready.accessibilityIdentifier, "invoice.titles.ready")
    }

    func testUnknownSaveKeepsAKnownCountAndBlocksEditsButNotAConfirmedDelete() throws {
        let pending = InvoiceLaunchTitlesPage.facts(.init(
            signedIn: true, pendingSave: true, pendingRequestKnown: true,
            allowsSave: true, allowsDelete: true, titles: try titles(2)))
        XCTAssertEqual(pending.phase, .unknown)
        XCTAssertEqual(pending.countText, "2")
        XCTAssertNotEqual(pending.countText, dash)
        XCTAssertEqual(pending.copyKey, InvoiceLaunchTitlesPage.Copy.unknown)
        XCTAssertEqual(pending.pendingHoldKey, InvoiceLaunchTitlesPage.Copy.pendingHold)
        XCTAssertTrue(pending.showsPendingSave)
        XCTAssertTrue(pending.canQuerySave)
        XCTAssertTrue(pending.showsAdd)
        XCTAssertFalse(pending.canAdd)
        XCTAssertFalse(pending.readOnly)
        XCTAssertTrue(pending.rows.allSatisfy { !$0.canEdit && $0.canDelete })

        let noRequest = InvoiceLaunchTitlesPage.facts(.init(
            signedIn: true, pendingSave: true, titles: []))
        XCTAssertEqual(noRequest.phase, .unknown)
        XCTAssertEqual(noRequest.countText, "0")
        XCTAssertFalse(noRequest.canQuerySave)
        XCTAssertEqual(noRequest.pendingHoldKey, InvoiceLaunchTitlesPage.Copy.pendingHold)

        let writing = InvoiceLaunchTitlesPage.facts(.init(
            signedIn: true, pendingSave: true, pendingRequestKnown: true, writing: true,
            deletingID: 11, allowsSave: true, allowsDelete: true, titles: try titles(2)))
        XCTAssertFalse(writing.canQuerySave)
        XCTAssertFalse(writing.canAdd)
        XCTAssertTrue(writing.rows.allSatisfy { !$0.canEdit && !$0.canDelete })
    }

    func testDeleteInFlightBlocksOnlyThatRowAndABadTaxEchoIsAnEmDash() throws {
        let rows = try titles(2)
        let deleting = InvoiceLaunchTitlesPage.facts(.init(
            signedIn: true, deletingID: 11, allowsDelete: true, titles: rows))
        XCTAssertEqual(deleting.phase, .ready)
        XCTAssertFalse(deleting.rows[0].canDelete)
        XCTAssertTrue(deleting.rows[1].canDelete)
        XCTAssertTrue(deleting.rows.allSatisfy { !$0.canEdit })

        let masked = try title(id: 13, type: "COMPANY", name: "  ", tax: "NOT-A-MASK", isDefault: false)
        let odd = try title(id: 14, type: "OTHER", name: "Synthetic title", tax: "", isDefault: false)
        let facts = InvoiceLaunchTitlesPage.facts(.init(signedIn: true, titles: [masked, odd]))
        XCTAssertEqual(facts.countText, "2")
        XCTAssertEqual(facts.rows[0].titleName, dash)
        XCTAssertEqual(facts.rows[0].taxText, dash)
        XCTAssertNotEqual(facts.rows[0].taxText, "NOT-A-MASK")
        XCTAssertEqual(facts.rows[1].typeKey, dash)
        XCTAssertNil(facts.rows[1].taxText)
    }

    func testRefreshKeepsAKnownListInsteadOfReplacingItWithZero() throws {
        let refreshing = InvoiceLaunchTitlesPage.facts(.init(
            signedIn: true, loading: true, allowsSave: true, titles: try titles(1)))
        XCTAssertEqual(refreshing.phase, .ready)
        XCTAssertEqual(refreshing.countText, "1")
        XCTAssertFalse(refreshing.readOnly)
        XCTAssertTrue(refreshing.canAdd)

        let failedRefresh = InvoiceLaunchTitlesPage.facts(.init(
            signedIn: true, failed: true, allowsSave: true, titles: []))
        XCTAssertEqual(failedRefresh.phase, .empty)
        XCTAssertEqual(failedRefresh.countText, "0")
        XCTAssertEqual(failedRefresh.copyKey, InvoiceLaunchTitlesPage.Copy.empty)
        XCTAssertFalse(failedRefresh.readOnly)
        XCTAssertTrue(failedRefresh.canAdd)
    }

    private func titles(_ count: Int) throws -> [InvoiceLaunchTitle] {
        try (0..<count).map { index in
            let company = index == 1
            return try title(id: Int64(11 + index), type: company ? "COMPANY" : "PERSONAL",
                             name: index == 0 ? "Synthetic title" : "Synthetic title \(index + 1)",
                             tax: company ? "******" : nil, isDefault: company)
        }
    }

    private func title(id: Int64, type: String, name: String, tax: String?, isDefault: Bool) throws -> InvoiceLaunchTitle {
        let object: [String: Any] = [
            "id": id, "titleType": type, "titleName": name, "isDefault": isDefault,
            "taxNoMasked": tax ?? NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(InvoiceLaunchTitle.self, from: data)
    }
}
#endif
