import XCTest
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

/// Accessibility and hardening wave (FP-A*, FP-M5..M7, FP-M12).
@MainActor
final class AccessibilityHardeningWaveTests: XCTestCase {
    // FP-A4
    func testLocationMapValueJoinsDistinctNonEmptyParts() {
        XCTAssertEqual(ActivityLocationAccessibility.value(name: "Park", addressName: "North Gate", address: "1 Main St"),
                       "Park, North Gate, 1 Main St")
        XCTAssertEqual(ActivityLocationAccessibility.value(name: "Park", addressName: " Park ", address: nil), "Park")
        XCTAssertEqual(ActivityLocationAccessibility.value(name: " ", addressName: "", address: "1 Main St"), "1 Main St")
        XCTAssertEqual(ActivityLocationAccessibility.value(name: "", addressName: nil, address: nil), "")
    }
}
