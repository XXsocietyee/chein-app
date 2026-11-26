import XCTest
import SwiftUI
@testable import Questify

@MainActor final class GrowthBadgeExploreViewTests: XCTestCase {
    private final class Marker {}
    private let reader = Marker()
    private let key = GrowthCenterLoadKey(scope: UUID())
    private let presentation = UUID()
    private func center(empty: Bool = true, points: Int = 4) throws -> GrowthCenterRecord {
        let badges = empty ? "[]" : #"[{"badgeCode":"explorer"}]"#
        return try JSONDecoder().decode(GrowthCenterRecord.self,
            from: Data("{\"growth\":{},\"points\":\(points),\"badges\":\(badges),\"missions\":[]}".utf8))
    }
    private func selection(empty: Bool = true) throws -> GrowthBadgeExploreSelection {
        .init(readerID: ObjectIdentifier(reader), key: key, center: try center(empty: empty), presentationID: presentation)
    }
    private func accepts(_ value: GrowthBadgeExploreSelection, center: GrowthCenterRecord?,
                         key: GrowthCenterLoadKey? = nil, readerID: ObjectIdentifier? = nil,
                         presentationID: UUID? = nil, visible: Bool = true,
                         authenticated: Bool = true, configured: Bool = true,
                         loading: Bool = false, hasIssue: Bool = false) -> Bool {
        value.accepts(readerID: readerID ?? ObjectIdentifier(reader), key: key ?? self.key, center: center,
            presentationID: presentationID ?? presentation, visible: visible, authenticated: authenticated,
            configured: configured, loading: loading, hasIssue: hasIssue)
    }
    func testCurrentSuccessfulEmptyBadgesCanUseExistingHomeAction() throws {
        XCTAssertTrue(accepts(try selection(), center: try center()))
    }
    func testMissingFailedLoadingAndUnauthorizedNeverEstablishEmptyBadges() throws {
        let value = try selection(), center = try center()
        XCTAssertFalse(accepts(value, center: nil))
        XCTAssertFalse(accepts(value, center: center, hasIssue: true))
        XCTAssertFalse(accepts(value, center: center, loading: true))
        XCTAssertFalse(accepts(value, center: center, authenticated: false))
        XCTAssertFalse(accepts(value, center: center, configured: false))
    }
    func testMissingNullAndMalformedBadgePayloadsAreNotSuccessfulEmptyRecords() {
        for json in [#"{"growth":{},"missions":[]}"#,
                     #"{"growth":{},"badges":null,"missions":[]}"#,
                     #"{"growth":{},"badges":{},"missions":[]}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(GrowthCenterRecord.self, from: Data(json.utf8)))
        }
    }
    func testPartialOverviewUsesOnlyCurrentSuccessfulCenterForBadgeEmptiness() throws {
        let value = try selection(), record = try center()
        let partial = GrowthCenterOverview(center: .content(record), progress: .failure(.network),
            completed: .failure(.unavailable), rank: .failure(.failed))
        XCTAssertTrue(accepts(value, center: partial.center.value, hasIssue: partial.center.issue != nil))
        let failed = GrowthCenterOverview(center: .failure(.network), progress: .failure(.network),
            completed: .failure(.unavailable), rank: .failure(.failed))
        XCTAssertFalse(accepts(value, center: failed.center.value, hasIssue: failed.center.issue != nil))
    }
    func testNonemptyAndReplacedEmptyRecordsRejectOldAction() throws {
        XCTAssertFalse(accepts(try selection(empty: false), center: try center(empty: false)))
        XCTAssertFalse(accepts(try selection(), center: try center(empty: false)))
        XCTAssertFalse(accepts(try selection(), center: try center(points: 5)))
    }
    func testReaderScopeAndPresentationReplacementRejectOldCallback() throws {
        let value = try selection(), record = try center(), other = Marker()
        XCTAssertFalse(accepts(value, center: record, readerID: ObjectIdentifier(other)))
        XCTAssertFalse(accepts(value, center: record, key: .init(scope: UUID())))
        XCTAssertFalse(accepts(value, center: record, presentationID: UUID()))
        XCTAssertFalse(accepts(value, center: record, visible: false))
    }
    func testFootprintHidesOnlyWhenEveryShownCountIsARealZero() throws {
        XCTAssertTrue(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: "[]")))
        XCTAssertTrue(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: #"[{"topicId":0}]"#)))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "null", mileage: "0", topics: "[]")))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "null", topics: "[]")))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "-1", topics: "[]")))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "-3", mileage: "0", topics: "[]")))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "1", mileage: "0", topics: "[]")))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0.4", topics: "[]")))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: #"[{"topicId":3}]"#)))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: "[]", badges: #"[{"badgeCode":"explorer"}]"#)))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: "[]", centerFailed: true)))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: "[]", progressFailed: true)))
        XCTAssertFalse(GrowthCenterView.footprintEmpty(try footprint(exp: "0", mileage: "0", topics: "[]", completedFailed: true)))
    }
    private func footprint(exp: String, mileage: String, topics: String, badges: String = "[]",
                           centerFailed: Bool = false, progressFailed: Bool = false, completedFailed: Bool = false) throws -> GrowthCenterOverview {
        let center = try JSONDecoder().decode(GrowthCenterRecord.self, from: Data("""
        {"growth":{"expValue":\(exp)},"points":0,"badges":\(badges),"missions":[]}
        """.utf8))
        let progress = try JSONDecoder().decode(GrowthPlayProgress.self, from: Data("{\"totalMileage\":\(mileage)}".utf8))
        let completed = try JSONDecoder().decode([GrowthCompletedActivity].self, from: Data(topics.utf8))
        return GrowthCenterOverview(center: centerFailed ? .failure(.unavailable) : .content(center),
                                     progress: progressFailed ? .failure(.network) : .content(progress),
                                     completed: completedFailed ? .failure(.failed) : .content(completed),
                                     rank: .failure(.unavailable))
    }
}
