import XCTest
@testable import Questify

/// Design hand-off r1 · merchant & creator kit rules (review/full-merchant-creator.md MR-17, MR-20).
final class DesignR1MerchantKitTests: XCTestCase {
    private func point(_ date: String, _ amount: String?) throws -> MerchantRevenuePoint {
        let json: [String: Any] = amount.map { ["date": date, "amount": $0] } ?? ["date": date]
        return try JSONDecoder().decode(MerchantRevenuePoint.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))!
    }

    func testTodayIncomeReadsTodaysPointOnly() throws {
        let points = [try point("2026-11-15", "88"), try point("2026-11-16", "39.5")]
        let today = MerchantR1Today.make(revenue7d: points, pendingOrders: 3, now: now, calendar: calendar)
        XCTAssertEqual(today.income, "¥39.50")
        XCTAssertEqual(today.pending, "3")
    }

    func testTodayIncomeAcceptsShortDates() throws {
        XCTAssertEqual(MerchantR1Today.todayIncome([try point("11-16", "12")], now: now, calendar: calendar), "¥12.00")
    }

    func testUnknownTodayNumbersAreDashes() throws {
        let today = MerchantR1Today.make(revenue7d: [try point("2026-11-15", "88")], pendingOrders: nil, now: now, calendar: calendar)
        XCTAssertEqual(today.income, "—")
        XCTAssertEqual(today.pending, "—")
        XCTAssertEqual(today.redemptions, "—", "the server has no date-scoped redemption count yet")
    }

    func testStatusColoursFollowTheMerchantRule() {
        XCTAssertEqual(MerchantR1Status.needsMe.tone, .warning)
        XCTAssertEqual(MerchantR1Status.waiting.tone, .neutral)
        XCTAssertEqual(MerchantR1Status.waiting.symbol, "clock")
        XCTAssertEqual(MerchantR1Status.live.tone, .success)
        XCTAssertEqual(MerchantR1Status.failed.tone, .danger)
        XCTAssertFalse(MerchantR1Status.allCases.contains { $0.tone == .info }, "blue is not used")
    }

    func testUnknownMerchantValuesReadAsDash() {
        XCTAssertEqual(merchantR1Value(nil), "—")
        XCTAssertEqual(merchantR1Value(" "), "—")
    }
}

/// verify-r2 (round 2 app fixes): theme arbitration, merchant button shape, 7-day Today numbers, dates and money.
@MainActor
final class VerifyR2AppFixTests: XCTestCase {
    private func point(_ date: String, _ amount: String?) throws -> MerchantRevenuePoint {
        let json: [String: Any] = amount.map { ["date": date, "amount": $0] } ?? ["date": date]
        return try JSONDecoder().decode(MerchantRevenuePoint.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // N-01 · one source of truth for the window's scheme.
    func testShellSchemeWithNoRequestFallsBackToTheRole() {
        let arbiter = CYShellSchemeArbiter()
        XCTAssertNil(arbiter.requestedScheme)
    }

    func testPushedLightPageWinsAndPopRestoresTheShell() {
        let arbiter = CYShellSchemeArbiter()
        let root = UUID(), editor = UUID()
        arbiter.register(root, depth: 2, scheme: .dark)       // tab root page that themes itself .player
        arbiter.register(editor, depth: 2, scheme: .light)    // editor pushed on top: same depth, more recent
        XCTAssertEqual(arbiter.requestedScheme, .light)
        arbiter.unregister(editor)                            // popped
        XCTAssertEqual(arbiter.requestedScheme, .dark)
    }

    func testANestedCardDoesNotOverrideItsPage() {
        let arbiter = CYShellSchemeArbiter()
        arbiter.register(UUID(), depth: 2, scheme: .dark)     // the page
        arbiter.register(UUID(), depth: 3, scheme: .light)    // a merchant-themed card inside it
        XCTAssertEqual(arbiter.requestedScheme, .dark)
    }

    func testRootPageReturningToTheWindowAfterAPopIsMostRecent() {
        let arbiter = CYShellSchemeArbiter()
        let root = UUID(), editor = UUID()
        arbiter.register(root, depth: 2, scheme: .dark)
        arbiter.register(editor, depth: 2, scheme: .light)
        arbiter.unregister(root)                              // root left the window under the push
        XCTAssertEqual(arbiter.requestedScheme, .light)
        arbiter.register(root, depth: 2, scheme: .dark)       // pop starts: root back in the window
        arbiter.unregister(editor)
        XCTAssertEqual(arbiter.requestedScheme, .dark)
    }

    // skill-r2 Q4 · one capsule shape for player, merchant and editor (button-radius 999 everywhere).
    func testButtonShapeFollowsTheDomain() {
        XCTAssertNil(CYDomainPalette(.player).buttonCornerRadius)
        XCTAssertNil(CYDomainPalette(.merchant).buttonCornerRadius)
        XCTAssertNil(CYDomainPalette(.topicEditor).buttonCornerRadius)
        XCTAssertEqual(CYDomainPalette(.merchant).buttonMinHeight, 46)
        XCTAssertEqual(CYDomainPalette(.player).buttonMinHeight, 44)
    }

    // Handbook sheet-header rule (verify-r1 Q10, skill-r2 hand-off): three styles, picked by the sheet's domain.
    func testSheetHeaderStyleFollowsTheDomain() {
        XCTAssertEqual(CYSheetHeaderStyle.forDomain(.topicEditor), .editor)
        XCTAssertEqual(CYSheetHeaderStyle.forDomain(.merchant), .merchant)
        XCTAssertEqual(CYSheetHeaderStyle.forDomain(.player), .player)
        XCTAssertEqual(CYSheetHeaderStyle.automatic.resolved(in: .merchant), .merchant)
        XCTAssertEqual(CYSheetHeaderStyle.player.resolved(in: .merchant), .player, "an explicit style wins")
    }

    // N-07 / Q4 · 7-day numbers instead of a hero of dashes.
    func testTodayCardShowsSevenDayNumbers() throws {
        let points = try (10...16).map { try point("2026-11-\($0)", "10") }
        let today = MerchantR1Today.make(revenue7d: points, pendingOrders: 3)
        XCTAssertEqual(today.weekIncome, "¥70.00")
        XCTAssertEqual(today.weekAverage, "¥10.00")
        let sparse = MerchantR1Today.make(revenue7d: [try point("2026-11-15", "70")], pendingOrders: 0)
        XCTAssertEqual(sparse.weekAverage, "¥10.00", "averaged over the 7-day window, not over the days returned")
        XCTAssertEqual(today.pending, "3")
    }

    func testSevenDayNumbersAreUnknownWhenAnyDayIsNotANumber() throws {
        let today = MerchantR1Today.make(revenue7d: [try point("2026-11-15", "88"), try point("2026-11-16", nil)], pendingOrders: nil)
        XCTAssertEqual(today.weekIncome, "—", "never a partial sum")
        XCTAssertEqual(MerchantR1Today.make(revenue7d: [], pendingOrders: 1).weekIncome, "—")
    }

    // MC-02 · join dates as 11月16日, wall-clock fields kept.
    func testJoinDateReadsAsMonthAndDay() {
        let zh = Locale(identifier: "zh_Hans_CN")
        XCTAssertEqual(ClubJoinDateDisplay.text("2026-11-16 05:46:11", locale: zh), "11月16日")
        XCTAssertEqual(ClubJoinDateDisplay.text("2026-11-16 23:59:59", locale: zh), "11月16日", "no time-zone shift")
        XCTAssertEqual(ClubJoinDateDisplay.text("not a date", locale: zh), "not a date")
    }

    // N-16 / Q8 · 账户余额 is ¥ with two decimals.
    func testBalanceReadsAsYuan() {
        let zh = Locale(identifier: "zh_Hans_CN")
        XCTAssertEqual(MemberBalanceDisplay.text("560", locale: zh), "¥560.00")
        XCTAssertEqual(MemberBalanceDisplay.text("560.5", locale: zh), "¥560.50")
        XCTAssertEqual(MemberBalanceDisplay.text("—", locale: zh), "—")
    }

    // Identity step · masked display and the client-side GB 11643 check (owner 2026-11-16).
    func testIdentityStepBlocksUntilValid() {
        var draft = MerchantOnboardingDraft()
        XCTAssertEqual(draft.blocker(step: MerchantOnboardingSteps.identity), "merchant.onboarding.identity.required.realName")
        draft.realName = "示例商户"
        draft.idCardNumber = MerchantIdentityNumber("11010519491231002X")
        XCTAssertEqual(draft.blocker(step: MerchantOnboardingSteps.identity), "merchant.onboarding.identity.required.consent")
        draft.identityConsent = true
        XCTAssertNil(draft.blocker(step: MerchantOnboardingSteps.identity))
        XCTAssertEqual(draft.idCardNumber.masked, "110***********002X")
    }
}
