import XCTest

/// w2-20: mini-program im/list + im/chat parity on the offline DEBUG messaging
/// fixture (`--im-expanded-fixture message-*`). Synthetic data only; the safety
/// writer mutates the in-memory fixture reader, never a network endpoint.
final class IMMessagingParityUITests: XCTestCase {
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--im-expanded-fixture", "message-" + scenario]
        app.launch()
        return app
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)[id] }

    func testInboxUsesSourceTabsAndFiltersByConversationType() {
        let app = launch("success")
        let tabs = app.segmentedControls["messaging.list.scope"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        // R7-PC-D8-1 MP-first (im/list/index.js:276-279): 收件箱 / 发件箱. The inbox lists every conversation;
        // the outbox holds only the invites I sent, so no conversation row shows there.
        XCTAssertEqual(tabs.buttons.count, 2)
        XCTAssertTrue(tabs.buttons.element(boundBy: 0).isSelected)
        XCTAssertTrue(app.buttons["messaging.conversation.901"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["messaging.conversation.904"].exists)
        XCTAssertTrue(app.buttons["messaging.conversation.903"].exists, "Official type 3 is in the inbox")
        tabs.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.buttons["messaging.conversation.901"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["messaging.conversation.904"].exists)
        tabs.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["messaging.conversation.901"].waitForExistence(timeout: 5))
    }

    func testSystemNoticeMoreMenuOnlyOffersHide() {
        let app = launch("safety")
        let tabs = app.segmentedControls["messaging.list.scope"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["messaging.conversation.902"].waitForExistence(timeout: 5))
        app.buttons["messaging.conversation.902"].tap()
        XCTAssertTrue(element("im.reply.systemNotice", app).waitForExistence(timeout: 5))
        app.buttons["im.chat.more"].tap()
        XCTAssertTrue(app.buttons["im.chat.more.hide"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["im.chat.more.report"].exists)
        XCTAssertFalse(app.buttons["im.chat.more.block"].exists)
    }

    func testClosedConversationOffersReturnToList() {
        let app = launch("closed")
        app.buttons["messaging.conversation.901"].tap()
        let back = app.buttons["im.chat.returnToList"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["messaging.conversation.901"].waitForExistence(timeout: 5))
    }
}
