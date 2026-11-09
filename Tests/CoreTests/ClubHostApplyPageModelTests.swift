import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// pages/club/apply/index. Loading, empty, error, and UNKNOWN stay distinct.
/// UNKNOWN is an em dash. A missing capability and the player-first entry stay hidden.
final class ClubHostApplyPageModelTests: XCTestCase {
    private let emDash = "—"

    private func model(loading: Bool = false, failure: ClubGovernanceFailure? = nil,
                       snapshot: ClubGovernanceSnapshot? = nil, capability: Bool = true,
                       playerFirst: Bool = false, flags: [String: Bool]? = nil,
                       sizes: [String: String] = [:], allowance: ClubGovernanceValue = .null) -> ClubHostApplyPageModel {
        ClubHostApplyPageModel(loading: loading, failure: failure, snapshot: snapshot,
                               capabilityGranted: capability, playerFirstEntry: playerFirst,
                               draftFlags: flags, draftSizes: sizes, allowance: allowance)
    }

    func testExistingHostStatusAndBecomeLeaderContractsAreTheOnlyPaths() {
        XCTAssertEqual(ClubHostApplyPageModel.page, "pages/club/apply/index")
        XCTAssertEqual(ClubHostApplyPageModel.statusPath, "api/publisher/identity/status")
        XCTAssertEqual(ClubHostApplyPageModel.submitPath, "api/club/become-leader")
        XCTAssertEqual(ClubHostApplyPageModel.read, .hostStatus)
        XCTAssertEqual(ClubHostApplyPageModel.mutation, .hostApply)
        XCTAssertEqual(ClubHostApplyPageModel.mutation.reviewRead, .hostStatus)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/become-leader"), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/publisher/identity/status"), .liveInProduction)
        XCTAssertFalse(ClubHostApplyPageModel.showsOnPlayerFirstEntry)
        XCTAssertFalse(ClubHostApplyPageModel.showsMerchantChoice)
    }

    func testMissingCapabilityAndPlayerFirstEntryStayHidden() {
        XCTAssertFalse(ClubHostApplyPageModel.capabilityGranted(baseURL: nil))
        let china = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL)
        XCTAssertTrue(ClubHostApplyPageModel.capabilityGranted(baseURL: china))
        XCTAssertFalse(ChinaReviewedRouteCapability.offersFeature("/api/club/channels", baseURL: china))
        let hidden = model(snapshot: ClubHostApplyFixtureData.player, capability: false)
        XCTAssertEqual(hidden.phase, .hidden)
        XCTAssertEqual(hidden.accessibilityIdentifier, "club.host.apply.hidden")
        XCTAssertEqual(hidden.allowance.displayText, emDash)
        XCTAssertNotEqual(hidden.allowance.displayText, "0")
        XCTAssertNil(hidden.allowance.literal)
        let playerFirst = model(snapshot: ClubHostApplyFixtureData.player, playerFirst: true)
        XCTAssertEqual(playerFirst.phase, .hidden)
        XCTAssertFalse(ClubHostApplyPageModel.isVisible(capabilityGranted: true, playerFirstEntry: true))
        XCTAssertTrue(ClubHostApplyPageModel.isVisible(capabilityGranted: true, playerFirstEntry: false))
    }

    func testLoadingEmptyErrorAndUnknownStayDistinct() {
        let loading = model(loading: true, snapshot: ClubHostApplyFixtureData.player)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.messageKey, "club.host.apply.loading")
        XCTAssertEqual(loading.allowance.displayText, emDash)
        XCTAssertEqual(loading.selectedCount.displayText, emDash)

        let empty = model(snapshot: nil)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.messageKey, "club.gov.empty")
        XCTAssertEqual(empty.allowance.displayText, emDash)

        let unregistered = model(snapshot: ClubHostApplyFixtureData.unregistered)
        XCTAssertEqual(unregistered.phase, .empty)
        XCTAssertEqual(unregistered.allowance.displayText, emDash)

        let denied = model(failure: .forbidden, snapshot: ClubHostApplyFixtureData.player)
        XCTAssertEqual(denied.phase, .error)
        XCTAssertEqual(denied.messageKey, "club.gov.denied")
        XCTAssertEqual(denied.accessibilityIdentifier, "club.host.apply.error")
        XCTAssertEqual(denied.allowance.displayText, emDash)
        XCTAssertNotEqual(denied.allowance.displayText, "0")

        let unsettled = model(failure: .unknown(message: nil), allowance: .integer(0))
        XCTAssertEqual(unsettled.phase, .unknown)
        XCTAssertEqual(unsettled.messageKey, "club.gov.unknown")
        XCTAssertEqual(unsettled.allowance.displayText, emDash)
        XCTAssertNil(unsettled.allowance.literal)

        XCTAssertEqual(model(snapshot: ClubHostApplyFixtureData.missingRegistered).phase, .unknown)
        XCTAssertEqual(model(snapshot: ClubHostApplyFixtureData.unknownRole).phase, .unknown)
        XCTAssertEqual(model(snapshot: ClubHostApplyFixtureData.unknownRole).messageKey, "club.gov.unknownValue")
        XCTAssertEqual(model(snapshot: ClubHostApplyFixtureData.otherRead).phase, .unknown)
        XCTAssertEqual(model(snapshot: ClubHostApplyFixtureData.otherRead).allowance.displayText, emDash)
    }

    func testUnknownNumbersAreAnEmDashAndExplicitZeroStaysZero() {
        XCTAssertEqual(ClubHostApplyCount.parse(.string("UNKNOWN")).displayText, emDash)
        XCTAssertEqual(ClubHostApplyCount.parse(.null).displayText, emDash)
        XCTAssertEqual(ClubHostApplyCount.parse(.string("0")).displayText, emDash)
        XCTAssertEqual(ClubHostApplyCount.parse(.bool(false)).displayText, emDash)
        XCTAssertEqual(ClubHostApplyCount.parse(.decimal(2)).displayText, emDash)
        XCTAssertNil(ClubHostApplyCount.parse(.string("0")).literal)
        XCTAssertNotEqual(ClubHostApplyCount.parse(.string("UNKNOWN")).displayText, "0")
        XCTAssertEqual(ClubHostApplyCount.parse(.integer(0)).displayText, "0")
        XCTAssertEqual(ClubHostApplyCount.parse(.integer(0)).literal, 0)

        let host = model(snapshot: ClubHostApplyFixtureData.host)
        XCTAssertEqual(host.phase, .host)
        XCTAssertEqual(host.accessibilityIdentifier, "club.host.apply.host")
        XCTAssertEqual(host.allowance.displayText, emDash)
        XCTAssertNotEqual(host.allowance.displayText, "2")
        XCTAssertNotEqual(host.allowance.displayText, "0")

        let suppliedZero = model(snapshot: ClubHostApplyFixtureData.host, allowance: .integer(0))
        XCTAssertEqual(suppliedZero.allowance.displayText, "0")
        let suppliedStringZero = model(snapshot: ClubHostApplyFixtureData.host, allowance: .string("0"))
        XCTAssertEqual(suppliedStringZero.allowance.displayText, emDash)
        let suppliedUnknown = model(snapshot: ClubHostApplyFixtureData.host, allowance: .string("UNKNOWN"))
        XCTAssertEqual(suppliedUnknown.allowance.displayText, emDash)
        let suppliedTwo = model(snapshot: ClubHostApplyFixtureData.host, allowance: .integer(2))
        XCTAssertEqual(suppliedTwo.allowance.literal, 2)
    }

    func testIntroMerchantAndDraftCountsDoNotGuess() {
        let intro = model(snapshot: ClubHostApplyFixtureData.player, flags: [:])
        XCTAssertEqual(intro.phase, .intro)
        XCTAssertEqual(intro.accessibilityIdentifier, "club.host.apply.intro")
        XCTAssertEqual(intro.selectedCount.displayText, "0")
        XCTAssertEqual(intro.maxEventSize.displayText, emDash)
        XCTAssertEqual(intro.avgEventSize.displayText, emDash)
        XCTAssertEqual(model(snapshot: ClubHostApplyFixtureData.player).selectedCount.displayText, emDash)

        let selected = model(snapshot: ClubHostApplyFixtureData.player, flags: ["canNpc": true, "canDesignRoute": true, "hasGuideCert": true, "canDesignTask": false], sizes: ["maxEventSize": "40", "avgEventSize": "0"])
        XCTAssertEqual(selected.selectedCount.displayText, "2")
        XCTAssertEqual(selected.maxEventSize.displayText, "40")
        XCTAssertEqual(selected.avgEventSize.displayText, "0")
        let rejected = model(snapshot: ClubHostApplyFixtureData.player, flags: [:], sizes: ["maxEventSize": "many", "avgEventSize": "-1"])
        XCTAssertEqual(rejected.maxEventSize.displayText, emDash)
        XCTAssertEqual(rejected.avgEventSize.displayText, emDash)
        XCTAssertNotEqual(rejected.maxEventSize.displayText, "0")

        let merchant = model(snapshot: ClubHostApplyFixtureData.merchant, flags: ["canNpc": true], allowance: .integer(2))
        XCTAssertEqual(merchant.phase, .merchantBlocked)
        XCTAssertEqual(merchant.accessibilityIdentifier, "club.host.apply.merchantBlocked")
        XCTAssertEqual(merchant.selectedCount.displayText, emDash)
        XCTAssertEqual(merchant.allowance.displayText, "2")
    }

    func testStringCatalogCoversStatesAndBothLocales() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/release/ui-strings-pages-club-apply-index.json")
        let data = try Data(contentsOf: url)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["page"] as? String, ClubHostApplyPageModel.page)
        XCTAssertEqual(object["showsOnPlayerFirstEntry"] as? Bool, false)
        XCTAssertEqual(object["showsMerchantChoice"] as? Bool, false)
        let rows = try XCTUnwrap(object["strings"] as? [[String: String]])
        var identifiers = Set<String>()
        for row in rows {
            XCTAssertFalse((row["key"] ?? "").isEmpty)
            XCTAssertFalse((row["en"] ?? "").isEmpty)
            XCTAssertFalse((row["zh-Hans"] ?? "").isEmpty)
            identifiers.insert(try XCTUnwrap(row["accessibilityIdentifier"]))
        }
        let required = [
            "club.host.apply.hidden", "club.host.apply.loading", "club.host.apply.empty",
            "club.host.apply.error", "club.host.apply.unknown", "club.host.apply.intro",
            "club.host.apply.merchantBlocked", "club.host.apply.host",
            ClubHostApplyPageModel.allowanceIdentifier, ClubHostApplyPageModel.selectedCountIdentifier
        ]
        for identifier in required { XCTAssertTrue(identifiers.contains(identifier), identifier) }
        let unknown = try XCTUnwrap(rows.first { $0["key"] == "club.host.apply.unknownCount" })
        XCTAssertEqual(unknown["en"], emDash)
        XCTAssertEqual(unknown["zh-Hans"], emDash)
        XCTAssertNotEqual(unknown["en"], "0")
    }
}
#endif
