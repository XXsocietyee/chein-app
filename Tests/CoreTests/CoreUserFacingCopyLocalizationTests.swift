import XCTest
@testable import QuestifyCore

/// FP-M9: Core presentation strings that views show must have an English form (W8Text) while the
/// pinned Chinese form is unchanged.
final class CoreUserFacingCopyLocalizationTests: XCTestCase {
    override func tearDown() {
        W8Text.languageOverride = nil
        super.tearDown()
    }

    private func hasHan(_ text: String) -> Bool { text.range(of: "\\p{Han}", options: .regularExpression) != nil }

    private func assertBothLanguages(_ make: () -> [String], file: StaticString = #filePath, line: UInt = #line) {
        W8Text.languageOverride = "en"
        let english = make()
        W8Text.languageOverride = "zh-Hans"
        let chinese = make()
        XCTAssertEqual(english.count, chinese.count, file: file, line: line)
        for (en, zh) in zip(english, chinese) {
            XCTAssertFalse(en.isEmpty, file: file, line: line)
            XCTAssertFalse(hasHan(en), "Chinese leaked in English mode: \(en)", file: file, line: line)
            XCTAssertTrue(hasHan(zh), "No Chinese in zh-Hans mode: \(zh)", file: file, line: line)
        }
    }

    func testInAppLanguageSettingDrivesCoreCopy() {
        XCTAssertNil(AppLanguage.system.w8Override)
        XCTAssertEqual(AppLanguage.english.w8Override, "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.w8Override, "zh-Hans")
        W8Text.languageOverride = AppLanguage.english.w8Override
        XCTAssertEqual(W8Text.t("重试", "Retry"), "Retry")
        W8Text.languageOverride = AppLanguage.simplifiedChinese.w8Override
        XCTAssertEqual(W8Text.t("重试", "Retry"), "重试")
    }

    func testNotificationPermissionLabels() {
        assertBothLanguages {
            [NativeNotificationPermissionAuthorization.notDetermined, .denied, .authorized, .provisional, .ephemeral, .unknown(9)].map(\.label)
        }
    }

    func testReportReasonTitles() {
        assertBothLanguages { NativeChannelReportReason.allCases.map(\.title) }
    }

    func testRedemptionGuidance() {
        assertBothLanguages {
            [CityNodeRedemptionResult.unknownMessage, CityNodeRedemptionResult.unknownGuidance, CityNodeRedemptionResult.legacyGuidance]
        }
    }

    func testStampTabsAndAvailability() {
        assertBothLanguages {
            RoamReceivedStampTab.allCases.flatMap { [$0.title, $0.emptyTitle, $0.emptySubtitle] }
                + [RoamReceivedStampAvailability.signInRequired, .notConfigured].flatMap { [$0.statusTitle ?? "", $0.statusSubtitle ?? ""] }
        }
    }

    func testPublishingWizardCopy() {
        assertBothLanguages {
            [
                ActivityPublishingWizard.timeLocationLockedNotice, ActivityPublishingWizard.collaboratorSettlementNotice,
                ActivityPublishingWizard.merchantFreeTicketOnlyNotice, ActivityPublishingWizard.merchantPaidTicketBlockedMessage,
                ActivityPublishingWizard.createReviewHeading, ActivityPublishingWizard.editReviewHeading,
                ActivityPublishingWizard.createVisibilityNotice, ActivityPublishingWizard.editVisibilityNotice]
        }
    }

    func testCheckoutNoticesAndRefundSummaries() {
        assertBothLanguages {
            [FourShopCompensationPolicy.stopNewTicketSaleMessage, FourShopCompensationPolicy.soldContractFulfillmentNotice,
             RegistrationCoreLoopRules.explorePassPointsForbiddenMessage, RegistrationCoreLoopRules.soldOutMessage,
             CheckoutOrderRebuildRule.orderExpiredUserMessage, CheckoutOrderRebuildRule.quoteUpdatedUserMessage,
             NonRefundable24hNotice.badgeTitle, NonRefundable24hNotice.modalContent, NonRefundable24hNotice.cancelButtonTitle]
            + [(1, 4), (2, nil), (3, nil), (0, nil), (1, 0)].compactMap { status, payout in
                TicketExpiryAndOrderStatusRules.payoutSummary(status: status, payoutStatus: payout)
            }.flatMap { [$0.label, $0.hint] }
        }
    }
}
