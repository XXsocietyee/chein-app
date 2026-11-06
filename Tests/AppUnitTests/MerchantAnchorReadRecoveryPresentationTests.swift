import XCTest
@testable import Questify

@MainActor final class MerchantAnchorReadRecoveryPresentationTests:XCTestCase {
    func testCurrentFailureAndVerifiedReceiptHaveDistinctCatalogMessages() {
        let table="MerchantAnchorReadRecovery"
        let current=Bundle.main.localizedString(forKey:"failed",value:nil,table:table)
        let known=Bundle.main.localizedString(forKey:"known",value:nil,table:table)
        let unknown=Bundle.main.localizedString(forKey:"unknown",value:nil,table:table)
        XCTAssertNotEqual(current,known);XCTAssertNotEqual(current,unknown);XCTAssertNotEqual(known,unknown)
        XCTAssertNotEqual(current,"failed");XCTAssertNotEqual(known,"known");XCTAssertNotEqual(unknown,"unknown")
    }
    func testActualReadAndUnconfiguredAnchorCatalogStatesResolve() {
        for key in ["loading","working","failed","notConfigured","denied","unconfigured","readonly","original.anchor","confirmation.anchor","cancel"] {
            let value=Bundle.main.localizedString(forKey:key,value:nil,table:"MerchantAnchorReadRecovery")
            XCTAssertFalse(value.isEmpty);XCTAssertNotEqual(value,key)
        }
    }
}
