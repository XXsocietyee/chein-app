import XCTest
@testable import QuestifyCore

final class Port6TemplateBrowserTests: XCTestCase {
    func testCoverURLAcceptsOnlyPlainHTTPS() {
        XCTAssertEqual(TemplateBrowserPort.coverURL("https://cdn.example.com/c.jpg")?.host, "cdn.example.com")
        XCTAssertNil(TemplateBrowserPort.coverURL(nil))
        XCTAssertNil(TemplateBrowserPort.coverURL("  "))
        XCTAssertNil(TemplateBrowserPort.coverURL("http://cdn.example.com/c.jpg"))
        XCTAssertNil(TemplateBrowserPort.coverURL("https://u:p@cdn.example.com/c.jpg"))
    }
    func testSyncingLineOnlyOverLoadedRows() {
        XCTAssertTrue(TemplateBrowserPort.showsSyncingLine(isLoading: true, hasLoadedRows: true))
        XCTAssertFalse(TemplateBrowserPort.showsSyncingLine(isLoading: true, hasLoadedRows: false))
        XCTAssertFalse(TemplateBrowserPort.showsSyncingLine(isLoading: false, hasLoadedRows: true))
    }
    func testOtherTemplatesHint() {
        XCTAssertTrue(TemplateBrowserPort.showsOtherTemplatesHint(otherCount: 1))
        XCTAssertFalse(TemplateBrowserPort.showsOtherTemplatesHint(otherCount: 0))
    }
}
