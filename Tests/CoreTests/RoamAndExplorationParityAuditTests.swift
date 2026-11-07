import XCTest
@testable import QuestifyCore

final class RoamAndExplorationParityAuditTests: XCTestCase {
    func testBaselineAuditPassesAllFivePillars() {
        let report = RoamAndExplorationParityAudit.runAudit()
        XCTAssertTrue(report.isPassing)
        XCTAssertEqual(report.auditedPillars, RoamAndExplorationParityPillar.allCases)
        XCTAssertTrue(report.violations.isEmpty)
        XCTAssertFalse(PersonalFogFeature.revealSyncEnabled)
    }

    func testE0617StatusClassificationDistinguishes404And410GoneFrom503Error() {
        XCTAssertEqual(RoamAndExplorationParityAudit.classifySubpageStatus(code: 200), .ok)
        XCTAssertEqual(RoamAndExplorationParityAudit.classifySubpageStatus(code: 404), .gone)
        XCTAssertEqual(RoamAndExplorationParityAudit.classifySubpageStatus(code: 410), .gone)
        XCTAssertEqual(RoamAndExplorationParityAudit.classifySubpageStatus(code: 503), .error)
        XCTAssertEqual(RoamAndExplorationParityAudit.classifySubpageStatus(code: 500), .error)
    }

    func testI01ArrivalSampleThresholdsEnforce80mAdvisoryAnd100mOr30sInvalidAction() {
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: 45, ageSeconds: 10),
            .qualified
        )
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: 80, ageSeconds: 30),
            .qualified
        )
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: 85, ageSeconds: 12),
            .advisoryWarning
        )
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: 100, ageSeconds: 25),
            .advisoryWarning
        )
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: 101, ageSeconds: 10),
            .invalidAction
        )
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: 35, ageSeconds: 31),
            .invalidAction
        )
        XCTAssertEqual(
            RoamAndExplorationParityAudit.evaluateArrivalSample(accuracyMeters: -1, ageSeconds: 5),
            .invalidAction
        )
    }

    func testAuditFlagsMissingSubpagesDriftAndEnabledRevealSync() {
        let brokenEntries: [RoamExplorationPillarAuditEntry] = [
            RoamExplorationPillarAuditEntry(
                pillar: .w208RoamEntryMerchantAndSubpages,
                verifiedTypes: ["RoamSubpagePresentation"],
                e0617GoneMappedCorrectly: false
            ),
            RoamExplorationPillarAuditEntry(
                pillar: .w209PassportPrivateTools,
                verifiedTypes: ["RoamPassportPrivateToolsReading"],
                privateToolSubpagesCovered: [.capsule, .explorationGoals]
            ),
            RoamExplorationPillarAuditEntry(
                pillar: .fW14W15StoryWalkingAndFog,
                verifiedTypes: ["StoryWalkingNavigationHostBridge", "PersonalFogRoamOverlayProjection"],
                arrivalOpensVerificationOnly: false,
                revealSyncEnabledByDefault: true
            )
        ]

        let report = RoamAndExplorationParityAudit.runAudit(entries: brokenEntries)
        XCTAssertFalse(report.isPassing)
        XCTAssertTrue(report.violations.contains(.missingPillar(.i00I11ReceivedStamps)))
        XCTAssertTrue(report.violations.contains(.missingPillar(.i01PlayArrivalAccuracy)))
        XCTAssertTrue(report.violations.contains(.e0617MappingDrift))
        XCTAssertTrue(report.violations.contains(
            .missingPrivateToolSubpages([.explorationExport, .anniversary, .monthlyRecap])
        ))
        XCTAssertTrue(report.violations.contains(.arrivalAutoCompletesInsteadOfVerification))
        XCTAssertTrue(report.violations.contains(.revealSyncUnexpectedlyEnabled))
    }

    func testW5RoamTabFullFeatureParityAndCityStampExchangeRules() {
        let descriptor = RoamTabFullFeatureParityDescriptor()
        XCTAssertTrue(descriptor.isFullRoamTabParityReady)
        XCTAssertEqual(RoamTabFullFeatureParityDescriptor.nearbyDefaultRadiusMeters, 1_000)
        XCTAssertEqual(RoamTabFullFeatureParityDescriptor.stampCaptionMaxCharacters, 30)
        XCTAssertEqual(RoamTabFullFeatureParityDescriptor.stampTearThresholdPx, 80)
        XCTAssertEqual(RoamTabFullFeatureParityDescriptor.stampScratchCompleteRatio, 0.6, accuracy: 0.001)
        XCTAssertEqual(RoamTabFullFeatureParityDescriptor.badgeRingDotCount, 24)
        XCTAssertEqual(RoamTabFullFeatureParityDescriptor.objectCardsMaxPileCount, 40)

        let bars = RoamTabFullFeatureParityDescriptor.stampBarcodeHeights(forSerial: "CY20261107")
        XCTAssertEqual(bars.count, 28)
        XCTAssertTrue(bars.allSatisfy { (12...25).contains($0) })
        XCTAssertEqual(bars, RoamTabFullFeatureParityDescriptor.stampBarcodeHeights(forSerial: "CY20261107"))

        let progress = RoamTabFullFeatureParityDescriptor.evaluateStampExchangeProgress(
            caption: "外滩漫游打卡邮票",
            tearPixels: 85,
            scratchRatio: 0.65
        )
        XCTAssertTrue(progress.isCaptionValid)
        XCTAssertTrue(progress.isTorn)
        XCTAssertTrue(progress.isScratchRevealed)

        let overlong = RoamTabFullFeatureParityDescriptor.evaluateStampExchangeProgress(
            caption: String(repeating: "漫", count: 31),
            tearPixels: 79,
            scratchRatio: 0.59
        )
        XCTAssertFalse(overlong.isCaptionValid)
        XCTAssertFalse(overlong.isTorn)
        XCTAssertFalse(overlong.isScratchRevealed)
    }
}
