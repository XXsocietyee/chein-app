import Foundation
import XCTest
@testable import QuestifyCore

final class WP07DisclosurePolicyTests: XCTestCase {
    func testNPCReplyAlwaysCarriesAIIdentity() {
        for surface in AIIdentitySurface.allCases {
            for pay in [false, true] {
                let policy = SafetyDisclosurePolicy(surface: surface, nodeSafety: .open, hasPayAction: pay)
                XCTAssertEqual(policy.aiIdentity.titleKey, "opsSafety.ai.title")
                XCTAssertTrue(policy.aiIdentity.boundaryKeys.contains("opsSafety.ai.notHuman"))
                XCTAssertTrue(policy.aiIdentity.boundaryKeys.contains("opsSafety.ai.noCommitments"))
            }
        }
    }

    func testOfflineNodeShowsUnknownSafetyWhenNoSignal() {
        let policy = SafetyDisclosurePolicy(surface: .themeNPC, nodeSafety: nil)
        XCTAssertEqual(policy.effectiveNodeSafety, .unknown)
        XCTAssertFalse(policy.effectiveNodeSafety.permitsStart)
        // A malformed or mismatched server answer is also "unknown", never open.
        let bad = OfflineNodeSafetyDecoder.decode(Data("{}".utf8), expectedNodeID: 7)
        XCTAssertEqual(SafetyDisclosurePolicy(surface: .themeNPC, nodeSafety: bad).effectiveNodeSafety, .unknown)
        XCTAssertEqual(SafetyDisclosurePolicy(surface: .themeNPC, nodeSafety: .open).effectiveNodeSafety, .open)
    }

    func testNoAutoFundsClauseShownBeforePayAction() {
        XCTAssertEqual(SafetyDisclosurePolicy(surface: .publicMerchantNPC, hasPayAction: true).noAutoFundsClauseKey,
                       SafetyDisclosurePolicy.noAutoFundsKey)
        XCTAssertNil(SafetyDisclosurePolicy(surface: .publicMerchantNPC, hasPayAction: false).noAutoFundsClauseKey)
    }
}
