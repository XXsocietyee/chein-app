import XCTest

/// One offline golden path per journey named for this task.
/// `docs/release/workflows.md` is not in this tree. The journeys are the ones named in the task:
/// sign up/login, discover to activity sign-up, play session including team, roam, city,
/// club/channel/IM, community post, creator publish plus review status, external game submit/catalog,
/// merchant, wallet, report/appeal, and account deletion.
///
/// Every path launches an existing DEBUG fixture. This file does not add a transport, a host, or a success response.
/// A step that would send money, a merchant write, or a password login is not taken.
/// XCUITest was not executed here: this workspace has no Swift compiler.
final class WorkflowJourneyGoldenPathUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        attachFailureScreenshot(self, app: app)
        app?.terminate()
        app = nil
    }

    func testSignUpLoginShowsThePhoneFormAndDoesNotSend() {
        let english = launch(design("e4-auth-phone", language: "en"))
        assertPhoneForm(english, signInLabel: "Sign in", sentLabel: "Code sent. Check your messages.")
        let chinese = launch(design("e4-auth-phone", language: "zh-Hans"))
        assertPhoneForm(chinese, signInLabel: "登录", sentLabel: "验证码已发送，请查看短信。")
    }

    func testDiscoverOpensAnActivityThenRegistrationReviewsOffline() {
        let feed = launch(englishModule(["--uitesting-module", "home-feed", "--uitesting-home-feed-scenario", "content"]))
        let activity = feed.buttons["homeFeed.nearby.activity.7"]
        XCTAssertTrue(activity.waitForExistence(timeout: 30), feed.debugDescription)
        XCTAssertTrue(revealFixtureElement(activity, in: feed), feed.debugDescription)
        activity.tap()
        let destination = feed.staticTexts["homeFeed.destination.activity"]
        XCTAssertTrue(destination.waitForExistence(timeout: 15), feed.debugDescription)
        XCTAssertEqual(destination.label, "Synthetic activity destination 7")

        let registration = launch(englishModule(["--uitesting-registration-fixture", "standard"]))
        XCTAssertTrue(registration.navigationBars["Activity registration"].waitForExistence(timeout: 10), registration.debugDescription)
        let consent = registration.switches["registration.form.consent"]
        XCTAssertTrue(revealFixtureElement(consent, in: registration), registration.debugDescription)
        let control = consent.switches.firstMatch
        (control.exists ? control : consent).tap()
        let review = registration.buttons["registration.form.review"]
        XCTAssertTrue(revealFixtureElement(review, in: registration), registration.debugDescription)
        XCTAssertTrue(review.isEnabled, registration.debugDescription)
        review.tap()
        let create = registration.alerts.buttons["Create demo registration"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), registration.debugDescription)
        create.tap()
        let read = registration.buttons["registration.form.readStatus"]
        XCTAssertTrue(read.waitForExistence(timeout: 10), registration.debugDescription)
        XCTAssertFalse(registration.buttons["Pay"].exists)
        XCTAssertFalse(registration.buttons["registration.form.review"].exists)
    }

    func testPlaySessionOpensATaskAndTheTeamBackpack() {
        let play = launch(englishModule([
            "--uitesting-module", "playExperience",
            "--uitesting-play-experience-scenario", "classic"
        ]))
        let node = play.buttons["playx.node.701"]
        XCTAssertTrue(revealFixtureElement(node, in: play), play.debugDescription)
        node.tap()
        XCTAssertTrue(play.navigationBars["Journey task"].waitForExistence(timeout: 5), play.debugDescription)
        XCTAssertFalse(play.buttons["playx.confirm"].exists)

        let team = launch(englishModule(["--uitesting-module", "playTeamBackpack"]))
        let item = team.descendants(matching: .any)["play.teamBackpack.item.tea"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 8), team.debugDescription)
        XCTAssertTrue(team.descendants(matching: .any)["play.teamBackpack"].firstMatch.exists)
        XCTAssertFalse(team.staticTexts["play.teamBackpack.failed"].exists)
    }

    func testRoamHomeThenHistorySession() {
        let home = launch(englishModule(["--uitesting-roam-home", "--uitesting-roam-home-scenario", "content"]))
        XCTAssertTrue(home.segmentedControls["roam.home.tabs"].waitForExistence(timeout: 8), home.debugDescription)

        let experience = launch(englishModule([
            "--uitesting-roam-experience",
            "--uitesting-roam-experience-scenario", "content"
        ]))
        let history = experience.buttons["roam.experience.history.open"]
        XCTAssertTrue(revealFixtureElement(history, in: experience, maximumSwipes: 12), experience.debugDescription)
        history.tap()
        let record = experience.buttons.matching(identifier: "roam.experience.history.record").firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5), experience.debugDescription)
        record.tap()
        XCTAssertTrue(any("roam.experience.session", experience).waitForExistence(timeout: 5), experience.debugDescription)
        XCTAssertTrue(experience.staticTexts["Saved local journey"].waitForExistence(timeout: 5))
    }

    func testCityAcquireReviewCanBeCancelled() {
        let city = launch(englishModule(["--uitesting-module", "cityGame"]))
        XCTAssertTrue(any("city.read.screen", city).waitForExistence(timeout: 8), city.debugDescription)
        let acquire = city.buttons["cityGame.action.ACQUIRE_PROPERTY.prop-cafe"]
        XCTAssertTrue(revealFixtureElement(acquire, in: city), city.debugDescription)
        acquire.tap()
        XCTAssertTrue(city.otherElements["cityGame.review"].waitForExistence(timeout: 8), city.debugDescription)
        XCTAssertTrue(city.staticTexts["Only you pay. Nothing is deducted if it fails."].exists)
        let cancel = city.buttons["cityGame.cancel"]
        XCTAssertTrue(revealFixtureElement(cancel, in: city), city.debugDescription)
        cancel.tap()
        XCTAssertFalse(city.otherElements["cityGame.review"].exists)
        XCTAssertEqual(city.staticTexts["cityGame.recorder.submissions"].label, "0")
        XCTAssertFalse(city.buttons["Pay"].exists)
    }

    func testClubChannelAndDirectMessageFixtures() {
        let club = launch(englishModule(["--club-community-fixture"]))
        XCTAssertTrue(club.otherElements["club.community.post.20"].waitForExistence(timeout: 8), club.debugDescription)
        let compose = club.buttons["club.community.compose"]
        XCTAssertTrue(revealFixtureElement(compose, in: club), club.debugDescription)
        compose.tap()
        XCTAssertTrue(club.textViews["club.community.content"].waitForExistence(timeout: 5), club.debugDescription)
        club.buttons["Cancel"].tap()
        XCTAssertFalse(club.buttons["club.community.confirm"].exists)

        let channel = launch(design("d4-channel-chat", language: "en"))
        XCTAssertTrue(channel.staticTexts["Saturday route is confirmed. Meet at the east gate at 9:30."].waitForExistence(timeout: 8), channel.debugDescription)
        XCTAssertEqual(channel.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")).count, 0)

        let inbox = launch([
            "--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "--im-expanded-fixture", "message-success"
        ])
        let row = inbox.buttons["messaging.conversation.901"]
        XCTAssertTrue(row.waitForExistence(timeout: 8), inbox.debugDescription)
        row.tap()
        XCTAssertTrue(inbox.buttons["messaging.message.10"].waitForExistence(timeout: 5), inbox.debugDescription)
    }

    func testCommunityPostSavesOnDeviceAndDoesNotPublish() {
        let square = launch(englishModule(["--uitesting-module", "square-workspace"]))
        let body = square.textViews["squareWorkspace.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 8), square.debugDescription)
        body.tap()
        body.typeText("Offline community draft")
        let save = square.buttons["squareWorkspace.saveLocal"]
        XCTAssertTrue(revealFixtureElement(save, in: square), square.debugDescription)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let status = square.staticTexts["squareWorkspace.status"]
        XCTAssertTrue(revealFixtureElement(status, in: square, requiresHittable: false), square.debugDescription)
        XCTAssertEqual(status.label, "Saved on this device")
        let server = square.buttons["squareWorkspace.saveServer"]
        XCTAssertTrue(revealFixtureElement(server, in: square, requiresHittable: false), square.debugDescription)
        XCTAssertFalse(server.isEnabled)
    }

    func testCreatorReviewCanBeCancelledAndStatusStaysApproved() {
        let editor = launch(englishModule(["--uitesting-module", "projectEdit"]))
        let name = editor.textFields["projectEdit.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 8), editor.debugDescription)
        name.tap()
        let current = (name.value as? String) ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "Reviewed fixture name")
        editor.buttons["projectEdit.review"].tap()
        XCTAssertTrue(editor.staticTexts["Reviewed fixture name"].waitForExistence(timeout: 5), editor.debugDescription)
        let cancel = editor.buttons["projectEdit.cancelReview"]
        XCTAssertTrue(revealFixtureElement(cancel, in: editor), editor.debugDescription)
        cancel.tap()
        XCTAssertTrue(editor.buttons["projectEdit.review"].waitForExistence(timeout: 5))
        XCTAssertFalse(editor.staticTexts["Simulation completed. No project was published."].exists)

        let creator = launch(englishModule(["--uitesting-module", "creatorContent"]))
        creator.buttons["creatorContent.openCenter"].tap()
        let status = creator.staticTexts["creatorContent.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 8), creator.debugDescription)
        XCTAssertEqual(status.label, "Approved creator")
    }

    func testExternalGameCatalogAndSubmissionsFailClosed() {
        let library = launch(design("e5-external-game", language: "en"))
        XCTAssertTrue(any("externalGame.catalog", library).waitForExistence(timeout: 8), library.debugDescription)
        let catalogError = any("externalGame.catalog.error", library)
        XCTAssertTrue(catalogError.waitForExistence(timeout: 8), library.debugDescription)
        XCTAssertTrue(
            catalogError.label == "The catalog did not load." || catalogError.label == "目录没有加载出来。",
            catalogError.label
        )
        XCTAssertFalse(any("externalGame.catalog.empty", library).exists)
        let submissions = library.buttons["externalGame.submissions"]
        XCTAssertTrue(revealFixtureElement(submissions, in: library), library.debugDescription)
        submissions.tap()
        let submissionError = any("externalGame.submissions.error", library)
        XCTAssertTrue(submissionError.waitForExistence(timeout: 8), library.debugDescription)
        XCTAssertTrue(
            submissionError.label == "Submissions did not load." || submissionError.label == "提交列表没有加载出来。",
            submissionError.label
        )
        XCTAssertFalse(any("externalGame.submissions.empty", library).exists)
        XCTAssertTrue(library.buttons["externalGame.submitReview"].exists)
    }

    func testMerchantCustomerTimelineOpensWithoutAWrite() {
        let merchant = launch(englishModule([
            "--uitesting-merchant-business-fixture",
            "--uitesting-merchant-business-scenario", "ready"
        ]))
        let customers = merchant.buttons["merchant.business.open.customers"]
        XCTAssertTrue(revealFixtureElement(customers, in: merchant), merchant.debugDescription)
        customers.tap()
        let row = merchant.buttons["merchant.business.row.customer.61001"]
        XCTAssertTrue(revealFixtureElement(row, in: merchant), merchant.debugDescription)
        row.tap()
        XCTAssertTrue(merchant.staticTexts["Example follow-up"].waitForExistence(timeout: 8), merchant.debugDescription)
        XCTAssertFalse(merchant.staticTexts["Example submitted"].exists)
    }

    func testWalletIncomeDetailOpensWithoutPay() {
        let wallet = launch(englishModule(["--wallet-commerce-fixture"]))
        let income = wallet.buttons["wallet.fixture.income"]
        XCTAssertTrue(income.waitForExistence(timeout: 8), wallet.debugDescription)
        income.tap()
        let row = wallet.buttons["wallet.income.detail.open.4"]
        XCTAssertTrue(row.waitForExistence(timeout: 8), wallet.debugDescription)
        row.tap()
        XCTAssertTrue(wallet.buttons["wallet.income.detail.close"].waitForExistence(timeout: 8), wallet.debugDescription)
        XCTAssertFalse(wallet.buttons["Pay"].exists)
        XCTAssertFalse(wallet.staticTexts["wallet.income.detail.retired"].exists)
    }

    func testReportStaysUnsubmittedAndAppealReasonCanCancel() {
        let report = launch(["--uitesting-profile-complaint", "--profile-complaint-scenario", "content"])
        let topic = report.buttons["profile.complaint.topic"]
        XCTAssertTrue(revealFixtureElement(topic, in: report), report.debugDescription)
        topic.tap()
        report.buttons["Synthetic city topic"].tap()
        let reason = report.textViews["profile.complaint.reason"]
        XCTAssertTrue(revealFixtureElement(reason, in: report), report.debugDescription)
        reason.tap()
        reason.typeText("Synthetic service issue")
        let review = report.buttons["profile.complaint.review"]
        XCTAssertTrue(revealFixtureElement(review, in: report), report.debugDescription)
        review.tap()
        XCTAssertTrue(report.staticTexts["profile.complaint.notSubmitted"].waitForExistence(timeout: 8), report.debugDescription)
        XCTAssertFalse(report.buttons["profile.complaint.submit"].exists)

        let appeal = launch(englishModule(["--square-governance-fixture"]))
        let entry = appeal.buttons["square.gov.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 8), appeal.debugDescription)
        entry.tap()
        let appealButton = appeal.buttons["square.gov.appeal.91"]
        XCTAssertTrue(revealFixtureElement(appealButton, in: appeal), appeal.debugDescription)
        appealButton.tap()
        XCTAssertTrue(appeal.textViews["square.gov.reason"].exists || appeal.textFields["square.gov.reason"].exists)
        appeal.buttons["Cancel"].tap()
        XCTAssertFalse(appeal.buttons["square.gov.confirm"].exists)
    }

    func testAccountDeletionReviewShowsImpactAndDoesNotComplete() {
        let deletion = launch(design("e4-deregister", language: "en"))
        XCTAssertTrue(any("compliance.reviewWarning", deletion).waitForExistence(timeout: 8), deletion.debugDescription)
        let impact = deletion.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Your points are removed and cannot be restored.")
        ).firstMatch
        XCTAssertTrue(impact.waitForExistence(timeout: 8), deletion.debugDescription)
        XCTAssertTrue(any("compliance.serverStatus", deletion).exists)
        XCTAssertFalse(any("compliance.completed", deletion).exists)
        XCTAssertFalse(any("compliance.cancellationConfirmed", deletion).exists)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        app?.terminate()
        let next = XCUIApplication()
        next.launchArguments = arguments
        app = next
        next.launch()
        return next
    }

    private func englishModule(_ extra: [String]) -> [String] {
        ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
    }

    private func design(_ name: String, language: String) -> [String] {
        let chinese = language == "zh-Hans"
        return [
            "--design-fixture", name,
            "-preferences.language", language,
            "-AppleLanguages", chinese ? "(zh-Hans)" : "(en)",
            "-AppleLocale", chinese ? "zh_CN" : "en_US"
        ]
    }

    private func any(_ identifier: String, _ application: XCUIApplication) -> XCUIElement {
        application.descendants(matching: .any)[identifier].firstMatch
    }

    private func assertPhoneForm(_ application: XCUIApplication, signInLabel: String, sentLabel: String) {
        let phone = application.textFields["auth.channels.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 8), application.debugDescription)
        XCTAssertEqual(phone.value as? String, "13812345678")
        XCTAssertTrue(application.textFields["auth.channels.code"].exists)
        let send = application.buttons["auth.channels.sendCode"]
        XCTAssertTrue(send.exists)
        XCTAssertFalse(send.isEnabled)
        let signIn = application.buttons["auth.channels.phoneSignIn"]
        XCTAssertTrue(signIn.exists)
        XCTAssertFalse(signIn.isEnabled)
        XCTAssertEqual(signIn.label, signInLabel)
        XCTAssertTrue(application.staticTexts[sentLabel].exists)
        XCTAssertFalse(application.buttons["auth.signIn"].exists)
    }
}
