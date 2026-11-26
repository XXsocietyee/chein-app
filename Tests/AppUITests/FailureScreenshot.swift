import XCTest

/// Keep the actual failing UI, rather than relying on AX text or screenshots of later states.
func attachFailureScreenshot(_ test:XCTestCase,app:XCUIApplication?) {
    guard let app,(test.testRun?.totalFailureCount ?? 0)>0 else { return }
    emitRegistrationFailureEvidence(app)
    let image=XCTAttachment(screenshot:app.screenshot())
    image.name="Failure state – " + test.name
    image.lifetime = .keepAlways
    test.add(image)
}

/// Only use with explicitly synthetic/offline fixture data.
func attachFixtureScreenshot(_ test:XCTestCase,app:XCUIApplication,name:String) {
    let image=XCTAttachment(screenshot:app.screenshot())
    image.name=name + " – synthetic fixture"
    image.lifetime = .keepAlways
    test.add(image)
}

/// Reveal lazy List rows before asserting them, and keep taps clear of bars/keyboard overlays.
/// A partly clipped NavigationLink may report isHittable without a reliable tap target.
@discardableResult
func revealFixtureElement(_ element: XCUIElement, in app: XCUIApplication,
                          towardTop: Bool = false, maximumSwipes: Int = 10,
                          requiresHittable: Bool = true) -> Bool {
    func viewport() -> (bounds: CGRect, screen: CGRect)? {
        guard let snapshot = try? app.snapshot() else { return nil }
        let screen = snapshot.frame
        var bounds = screen.insetBy(dx: 4, dy: 4)
        func descendants(_ node: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
            var result: [any XCUIElementSnapshot] = []
            for child in node.children {
                result.append(child)
                result.append(contentsOf: descendants(child))
            }
            return result
        }
        let hierarchy = descendants(snapshot)
        // One AX generation: later in-screen bars belong to the presented layer.
        func foregroundBarFrame(_ type: XCUIElement.ElementType) -> CGRect? {
            // A screen-sized Toolbar/NavigationBar is a SwiftUI container wrapper (e.g. the welcome
            // screen's hidden toolbar), not a bar occluding content; it would collapse the viewport.
            let frame = hierarchy.last { $0.elementType == type && !$0.frame.isEmpty && screen.intersects($0.frame) }?.frame
            return frame.flatMap { $0.height < screen.height / 2 ? $0 : nil }
        }
        if let frame = foregroundBarFrame(.navigationBar) { bounds.origin.y = max(bounds.minY, frame.maxY + 4) }
        var bottom = screen.maxY - 40
        if let frame = foregroundBarFrame(.toolbar) { bottom = min(bottom, frame.minY - 4) }
        if let frame = foregroundBarFrame(.keyboard) { bottom = min(bottom, frame.minY - 4) }
        bounds.size.height = max(0, bottom - bounds.minY)
        return (bounds, screen)
    }
    for attempt in 0...maximumSwipes {
        guard let geometry = viewport() else { return false }
        let bounds = geometry.bounds, screen = geometry.screen
        var scrollTowardTop = towardTop
        if element.exists {
            let frame = element.frame
            let fullyVisible = !frame.isEmpty && frame.minY >= bounds.minY && frame.maxY <= bounds.maxY
                && frame.midX >= bounds.minX && frame.midX <= bounds.maxX
            if fullyVisible && (!requiresHittable || element.isHittable) { return true }
            if !frame.isEmpty { scrollTowardTop = frame.midY < bounds.midY }
        }
        guard attempt < maximumSwipes, bounds.height > 80, screen.height > 0 else { break }
        // Short gestures avoid overshooting a partly visible row and oscillating around it.
        let startFraction: CGFloat = scrollTowardTop ? 0.3 : 0.75
        let endFraction: CGFloat = scrollTowardTop ? 0.75 : 0.3
        let startY = (bounds.minY + bounds.height * startFraction - screen.minY) / screen.height
        let endY = (bounds.minY + bounds.height * endFraction - screen.minY) / screen.height
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)))
    }
    return false
}

/// Lazy `List`/`CollectionView` rows exist only near the viewport (a row scrolled far past is dropped from the accessibility
/// tree, so "not found" can mean "scrolled past"). Sweeps down, then back up past the start, until `element` is hittable.
/// Use it for rows in a long list; `revealFixtureElement` keeps its single-direction contract for short screens.
@discardableResult
func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, container: XCUIElement? = nil,
                     maxSweeps: Int = 12) -> Bool {
    let scroller = container ?? app.collectionViews.firstMatch
    // A swipe leaves the list coasting; a tap during the coast only stops it and never reaches the row. Report the row
    // ready only once its frame has stopped moving.
    func settled() -> Bool {
        var last = element.frame
        for _ in 0..<12 {
            Thread.sleep(forTimeInterval: 0.25)
            let frame = element.frame
            if frame == last { return element.isHittable }
            last = frame
        }
        return false
    }
    func ready() -> Bool { element.exists && element.isHittable && settled() }
    if ready() { return true }
    guard scroller.exists else { return element.waitForExistence(timeout: 2) && element.isHittable }
    for _ in 0..<maxSweeps { scroller.swipeUp(); if ready() { return true } }
    for _ in 0..<(maxSweeps * 2) { scroller.swipeDown(); if ready() { return true } }
    for _ in 0..<maxSweeps { scroller.swipeUp(); if ready() { return true } }
    return ready()
}

/// Opens a row of a long lazy list by tapping its coordinates once it sits fully inside the visible area and has held
/// still for half a second. `isHittable` is not used: the hub keeps relaying out while it loads, so the element can be
/// reported unhittable (or still coasting) even though the row is on screen. Sweeps down, back up, then down again.
@discardableResult
func openListRow(_ element: XCUIElement, in app: XCUIApplication, container: XCUIElement, maxSweeps: Int = 12) -> Bool {
    let screen = app.windows.firstMatch.frame
    func visible() -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return !frame.isEmpty && frame.minY > 120 && frame.maxY < screen.maxY - 90 && frame.midX > 0 && frame.midX < screen.maxX
    }
    func tapIfStill() -> Bool {
        guard visible() else { return false }
        let before = element.frame
        Thread.sleep(forTimeInterval: 0.5)
        guard visible(), abs(element.frame.minY - before.minY) < 1 else { return false }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }
    if tapIfStill() { return true }
    guard container.exists else { return false }
    for _ in 0..<maxSweeps { container.swipeUp(velocity: .slow); if tapIfStill() { return true } }
    for _ in 0..<(maxSweeps * 2) { container.swipeDown(velocity: .slow); if tapIfStill() { return true } }
    for _ in 0..<maxSweeps { container.swipeUp(velocity: .slow); if tapIfStill() { return true } }
    return false
}

/// First GO asks for location through the in-app primer before the roam starts; accept it when it appears.
func acceptLocationPrimerIfShown(in app: XCUIApplication) {
    // CYPermissionPrimingView's primary pill (e5c renamed it from cy.permission.priming.primary).
    let allow = app.buttons["permission.priming.allow"]
    if allow.waitForExistence(timeout: 2) { allow.tap() }
}

/// GO is a press-and-hold pill (600 ms): a tap cancels. Holds past the commit so the start fires.
func holdGo(_ element: XCUIElement) { element.press(forDuration: 0.9) }

/// SwiftUI can expose a row-sized Switch around the actual native switch track.
/// Validate and tap that descendant, whose frame excludes the label and row padding.
func tapFixtureNativeSwitch(_ element: XCUIElement, in app: XCUIApplication,
                            file: StaticString = #filePath, line: UInt = #line) {
    guard element.exists || revealFixtureElement(element, in: app) else {
        XCTFail(app.debugDescription, file: file, line: line); return
    }
    let nativeTrack = element.descendants(matching: .switch).firstMatch
    let control = nativeTrack.exists ? nativeTrack : element
    guard revealFixtureElement(control, in: app), element.isEnabled, control.isEnabled else {
        XCTFail("Native switch track is not enabled and visible. " + app.debugDescription, file: file, line: line)
        return
    }
    control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
}


/// System confirmation popovers can expose a row-sized Button around its native leaf.
func tapFixtureSheetAction(_ label: String, in sheet: XCUIElement, app: XCUIApplication,
                           file: StaticString = #filePath, line: UInt = #line) {
    let query = sheet.buttons.matching(NSPredicate(format: "label == %@", label))
    func leaves() -> [XCUIElement] {
        query.allElementsBoundByIndex.filter {
            $0.descendants(matching: .button).count == 0 && $0.isEnabled && $0.isHittable
        }
    }
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in leaves().count == 1 }, object: sheet)
    guard XCTWaiter.wait(for: [ready], timeout: 5) == .completed, let button = leaves().first else {
        XCTFail("Expected one enabled native action in the presented sheet: " + app.debugDescription, file: file, line: line)
        return
    }
    button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
}

/// Use the system dismissal region, outside the popover and all keyboard surfaces.
func dismissFixtureConfirmationPopover(in app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
    let outside = app.otherElements["PopoverDismissRegion"]
    let popover = app.popovers.firstMatch
    guard outside.exists, popover.exists else {
        XCTFail("Expected an adaptive confirmation popover: " + app.debugDescription, file: file, line: line); return
    }
    // The Keyboard AX frame excludes the prediction/accessory strip above its keys.
    // A tap in that strip reaches the input window instead of PopoverDismissRegion.
    let inputElements = app.keyboards.allElementsBoundByIndex + app.otherElements.matching(
        NSPredicate(format: "identifier == %@ OR identifier == %@ OR label == %@",
                    "inputView", "SystemInputAssistantView", "Typing Predictions")
    ).allElementsBoundByIndex
    let inputFrames = inputElements.map { $0.frame.intersection(app.frame) }
        .filter { !$0.isNull && !$0.isEmpty }
    // Prefer the content beside the popup. Screen-edge/home-indicator taps may
    // be intercepted even though the dismissal region's AX frame contains them.
    let content = app.frame.insetBy(dx: 40, dy: 80)
    let popup = popover.frame.insetBy(dx: -16, dy: -16)
    let candidates = [
        CGPoint(x: content.maxX - 1, y: popover.frame.midY),
        CGPoint(x: content.minX + 1, y: popover.frame.midY),
        CGPoint(x: content.midX, y: popup.maxY + 24),
        CGPoint(x: content.midX, y: popup.minY - 24),
        CGPoint(x: content.midX, y: content.midY)
    ]
    guard let point = candidates.first(where: { candidate in
        content.contains(candidate) && outside.frame.contains(candidate) && !popup.contains(candidate)
            && inputFrames.allSatisfy { !$0.insetBy(dx: -16, dy: -16).contains(candidate) }
    }) else {
        XCTFail("No safe outside-popover dismissal point: " + app.debugDescription, file: file, line: line); return
    }
    outside.coordinate(withNormalizedOffset: .zero)
        .withOffset(CGVector(dx: point.x - outside.frame.minX, dy: point.y - outside.frame.minY)).tap()
}

/// Emit a small allowlisted AX projection before screenshot capture can stall.
/// Never emit arbitrary AX strings, values, paths, addresses or launch arguments.
private func emitRegistrationFailureEvidence(_ app: XCUIApplication) {
    guard let index = app.launchArguments.firstIndex(of: "--uitesting-registration-fixture"),
          index + 1 < app.launchArguments.count,
          ["waitlistClaimed", "waitlistConverted", "waitlistOrderError"].contains(app.launchArguments[index + 1]) else { return }
    let allowed = ["Order number, OFFLINE-WAITLIST-9417", "订单号, OFFLINE-WAITLIST-9417",
                   "Order number", "订单号", "OFFLINE-WAITLIST-9417",
                   "registration.waitlist.order.close", "profile.order.detail.retry",
                   "registration.waitlist.openOrder"]
    let types = ["StaticText", "Button", "Other", "NavigationBar", "ScrollView", "Table", "Cell"]
    let snapshot = String(app.debugDescription.prefix(65536))
    var rows: [[String: Any]] = []
    for line in snapshot.split(separator: "\n").prefix(512) {
        guard let type = types.first(where: { line.trimmingCharacters(in: .whitespaces).hasPrefix($0 + ",") }) else { continue }
        let matches = allowed.filter { line.contains("'" + $0 + "'") }
        guard !matches.isEmpty else { continue }
        rows.append(["type": type, "knownStrings": matches])
        if rows.count == 128 { break }
    }
    let payload: [String: Any] = ["version": 1, "fixture": "registration-waitlist", "rows": rows,
                                 "sourceTruncated": snapshot.count == 65536 || snapshot.split(separator: "\n").count >= 512 || rows.count == 128]
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), data.count <= 32768,
          let text = String(data: data, encoding: .utf8) else { return }
    print("QUESTIFY_UI_EVIDENCE_V1 " + text)
    fflush(stdout)
}

/// Fresh installs open the onboarding pager, where `welcome.player` only exists on the final (consent) step.
/// Tap `onboarding.skip` when it is shown; relaunches that already completed onboarding start on the final step
/// and have no skip button, so this is a no-op there.
func skipOnboardingIfPresent(in app: XCUIApplication, timeout: TimeInterval = 10) {
    let skip = app.buttons["onboarding.skip"]
    let player = app.buttons["welcome.player"]
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !skip.exists, !player.exists { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
    if skip.exists, !player.exists { skip.tap() }
}

/// `welcome.settings` is an item of the `welcome.more` Menu (onboarding and classic welcome), so it only exists
/// in the accessibility tree while the menu is open: open the menu first when the item is not already hittable.
@discardableResult
func revealWelcomeSettings(in app: XCUIApplication, timeout: TimeInterval = 10) -> XCUIElement {
    let item = app.buttons["welcome.settings"]
    if item.exists, item.isHittable { return item }
    let more = app.buttons["welcome.more"]
    _ = more.waitForExistence(timeout: timeout)
    if more.exists { more.tap() }
    _ = item.waitForExistence(timeout: 5)
    return item
}

/// Settings shows language as a menu-style Picker row ("Language" / "语言"), not a flat list of option buttons:
/// open the row, then pick the option (`English` / `简体中文`) from the menu that appears.
@discardableResult
func selectLanguage(in app: XCUIApplication, option: String, timeout: TimeInterval = 5) -> Bool {
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Language' OR label CONTAINS '语言'")).firstMatch
    guard row.waitForExistence(timeout: timeout) else { return false }
    if !row.isHittable { app.swipeUp() }
    row.tap()
    let choice = app.buttons[option]
    guard choice.waitForExistence(timeout: timeout) else { return false }
    choice.tap()
    return true
}

/// r10 C-T5 / C-F4 (MP temp/index.wxml:1492-1494; fabu/index.js saveDraft=1): the app-only 保存到此设备 / 存到本机
/// moved out of the editor's bottom bar into its ⋯ toolbar menu. Opens that menu, then taps the item.
func tapEditorMenuItem(_ id: String, menu: String, in app: XCUIApplication,
                       file: StaticString = #filePath, line: UInt = #line) {
    let more = app.buttons[menu]
    guard more.waitForExistence(timeout: 5), more.isEnabled else {
        XCTFail("Missing editor menu " + menu + ": " + app.debugDescription, file: file, line: line); return
    }
    more.tap()
    let item = app.buttons[id]
    guard item.waitForExistence(timeout: 5), item.isEnabled else {
        XCTFail("Missing enabled menu item " + id + ": " + app.debugDescription, file: file, line: line); return
    }
    item.tap()
}
