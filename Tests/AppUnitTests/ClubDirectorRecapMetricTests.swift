import XCTest
@testable import Questify

/// MP topic-detail director.js:280-291 (`recapMetricView`, first three as tiles, the rest in 完成情况).
@MainActor final class ClubDirectorRecapMetricTests: XCTestCase {
    func testRecapMetricsDropItemsWithoutLabelOrValue() throws {
        let recap = try PlayExperienceSyntheticFixtures.wire(#"{"metrics":[{"key":"arrived","label":"Arrived","value":12,"unit":"people"},{"name":"Teams","value":"3"},{"key":"done","value":5},{"label":"No value"},{"label":"","value":2}]}"#)
        let metrics = ClubTopicDirectorToolsSection.recapMetrics(recap)
        XCTAssertEqual(metrics, [
            ClubDirectorRecapMetric(label: "Arrived", value: "12", unit: "people"),
            ClubDirectorRecapMetric(label: "Teams", value: "3", unit: ""),
            ClubDirectorRecapMetric(label: "done", value: "5", unit: ""),
        ])
    }
}
