import XCTest

final class MerchantTemplatePreparationFlowTests: XCTestCase {
    private var app: XCUIApplication?
    override func setUp() { super.setUp(); continueAfterFailure = false }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app?.terminate(); app = nil }
    private func nativeAlertAction(_ identifier: String, in app: XCUIApplication) throws -> XCUIElement {
        let matches = app.alerts.buttons.matching(identifier: identifier)
        // Wait for presentation before resolving the native wrapper/button pair.
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        let leaves = matches.allElementsBoundByAccessibilityElement.filter {
            $0.descendants(matching: .button).count == 0
        }
        // Two independent actions must still fail; never tap an arbitrary match.
        XCTAssertEqual(leaves.count, 1, app.debugDescription)
        return try XCTUnwrap(leaves.count == 1 ? leaves.first : nil)
    }
    private func open() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--uitesting-merchant-operations-fixture"]
        app.launch(); self.app = app
        let entry = app.buttons["merchant.operations.entry.merchant.operations.templates"]
        XCTAssertTrue(revealFixtureElement(entry, in: app)); entry.tap()
        let row = app.buttons["merchant.operations.template.71"]
        XCTAssertTrue(revealFixtureElement(row, in: app)); row.tap()
        return app
    }
    private func edit(_ app: XCUIApplication) {
        let venue = app.buttons["merchant.preparation.venue"]
        XCTAssertTrue(revealFixtureElement(venue, in: app)); venue.tap()
        app.buttons["Museum"].tap()
        let materials = app.descendants(matching: .any)["merchant.operations.field.requiredMaterials"].firstMatch
        XCTAssertTrue(revealFixtureElement(materials, in: app)); materials.tap(); materials.typeText("  Map and pen  ")
    }
    private func review(_ app: XCUIApplication) {
        let review = app.buttons["merchant.operations.review"]
        XCTAssertTrue(revealFixtureElement(review, in: app)); XCTAssertTrue(review.isEnabled); review.tap()
    }
    func testVenueSelectionMaterialsReviewCancelAndSourceReadback() {
        let app = open(); edit(app); review(app)
        let materials = app.staticTexts["merchant.preparation.review.materials"]
        XCTAssertTrue(revealFixtureElement(materials, in: app, requiresHittable: false)); XCTAssertEqual(materials.label, "Map and pen")
        app.buttons["merchant.operations.confirm.cancel"].tap()
        let field = app.descendants(matching: .any)["merchant.operations.field.requiredMaterials"].firstMatch
        XCTAssertTrue(revealFixtureElement(field, in: app, towardTop: true)); XCTAssertEqual(field.value as? String, "  Map and pen  ")
        review(app)
        let confirm = app.buttons["merchant.operations.confirm"]
        XCTAssertTrue(revealFixtureElement(confirm, in: app)); confirm.tap()
        let saved = app.staticTexts["merchant.operations.exampleSaved"]
        XCTAssertTrue(revealFixtureElement(saved, in: app, requiresHittable: false))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertTrue(revealFixtureElement(field, in: app, towardTop: true)); XCTAssertEqual(field.value as? String, "Map and pen")
        app.buttons["merchant.operations.reload"].tap()
        XCTAssertTrue(revealFixtureElement(field, in: app, towardTop: true)); XCTAssertEqual(field.value as? String, "Map and pen")
        attachFixtureScreenshot(self, app: app, name: "Merchant preparation fields retained by synthetic source")
    }
    func testReloadRequiresExplicitDiscardAndDoesNotSavePreparationEdits() throws {
        let app = open(); edit(app)
        app.buttons["merchant.operations.reload"].tap()
        let keepEditing = try nativeAlertAction("merchant.operations.keepEditing", in: app)
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 5)); keepEditing.tap()
        let field = app.descendants(matching: .any)["merchant.operations.field.requiredMaterials"].firstMatch
        XCTAssertTrue(revealFixtureElement(field, in: app, towardTop: true)); XCTAssertEqual(field.value as? String, "  Map and pen  ")
        app.buttons["merchant.operations.reload"].tap()
        let discardReload = try nativeAlertAction("merchant.operations.discardReload", in: app)
        XCTAssertTrue(discardReload.waitForExistence(timeout: 5)); discardReload.tap()
        XCTAssertTrue(revealFixtureElement(field, in: app, towardTop: true))
        XCTAssertNotEqual(field.value as? String, "  Map and pen  ")
        XCTAssertFalse(app.buttons["merchant.operations.close"].exists)
        XCTAssertFalse(app.staticTexts["merchant.operations.exampleSaved"].exists)
    }
}
