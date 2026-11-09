import XCTest
@testable import QuestifyCore

/// The flag defaults off. A location trail, a token sample, and an account-id sample
/// passed into the recorder must not appear in any record.
final class CB51LocalDiagnosticsTests: XCTestCase {
    private let secret = "secret-token-sample account-id-sample 31.230416,121.473701"

    func testEmptyEnvironmentIsOffAndDropsTheSecret() {
        var diagnostics = CB51LocalDiagnostics(environment: [:])
        diagnostics.measure(.mapFrame, secret)
        diagnostics.recordMetric(.crashDiagnostic, count: 1, secret)
        XCTAssertFalse(diagnostics.enabled)
        XCTAssertTrue(diagnostics.records.isEmpty)
        XCTAssertEqual(diagnostics.rendered(), "")
        XCTAssertFalse(diagnostics.rendered().contains("secret-token-sample"))
        XCTAssertFalse(diagnostics.rendered().contains("account-id-sample"))
        XCTAssertFalse(diagnostics.rendered().contains("31.230416"))
        XCTAssertFalse(diagnostics.rendered().contains("121.473701"))
    }

    func testOtherFlagValuesStayOff() {
        for value in ["", "0", "true", "yes", "YES", "1 "] {
            var diagnostics = CB51LocalDiagnostics(environment: [CB51LocalDiagnostics.debugFlag: value])
            diagnostics.measure(.imageDecode, secret)
            diagnostics.recordMetric(.hangDiagnostic, count: 4, secret)
            XCTAssertFalse(diagnostics.enabled, value)
            XCTAssertTrue(diagnostics.records.isEmpty, value)
            XCTAssertFalse(diagnostics.rendered().contains("secret-token-sample"), value)
        }
    }

    func testFlagOnRecordsStaticNameAndCountOnly() {
        var diagnostics = CB51LocalDiagnostics(environment: [CB51LocalDiagnostics.debugFlag: "1"])
        diagnostics.measure(.listScroll, secret)
        diagnostics.recordMetric(.cpuExceptionDiagnostic, count: 3, secret)
        XCTAssertTrue(diagnostics.enabled)
        XCTAssertEqual(diagnostics.records, [
            CB51DiagnosticRecord(name: "cb51.listScroll", count: 1),
            CB51DiagnosticRecord(name: "cpuExceptionDiagnostic", count: 3)
        ])
        let rendered = diagnostics.rendered()
        XCTAssertEqual(rendered, "cb51.listScroll 1\ncpuExceptionDiagnostic 3")
        XCTAssertFalse(rendered.contains("secret-token-sample"))
        XCTAssertFalse(rendered.contains("account-id-sample"))
        XCTAssertFalse(rendered.contains("31.230416"))
        XCTAssertFalse(rendered.contains("121.473701"))
    }

    func testNegativeMetricCountIsDroppedWithTheSecret() {
        var diagnostics = CB51LocalDiagnostics(environment: [CB51LocalDiagnostics.debugFlag: "1"])
        diagnostics.recordMetric(.diskWriteExceptionDiagnostic, count: -1, secret)
        XCTAssertTrue(diagnostics.records.isEmpty)
        XCTAssertFalse(diagnostics.rendered().contains("account-id-sample"))
    }

    func testRecordedFieldsAreNameAndCount() {
        XCTAssertEqual(CB51LocalDiagnostics.recordedFields, ["name", "count"])
        XCTAssertEqual(CB51LocalDiagnostics.subsystem, "Questify.CB51")
        XCTAssertEqual(CB51Signpost.allCases.map(\.rawValue), [
            "cb51.mapFrame", "cb51.listScroll", "cb51.imageDecode", "cb51.metricSummary"
        ])
    }
}
