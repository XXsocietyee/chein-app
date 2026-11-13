import XCTest
@testable import QuestifyCore

final class BackendErrorCatalogTests: XCTestCase {
    func testUnknownCodeStaysGenericAndHidesServerText() {
        let generic = BackendErrorCatalog.generic
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "NOT_A_REAL_CODE", status: 401, message: "请先登录", language: .en),
            generic.en)
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "NOT_A_REAL_CODE", message: "请先登录", language: .zhHans),
            generic.zhHans)
        XCTAssertFalse(generic.en.contains("NOT_A_REAL_CODE"))
        XCTAssertFalse(BackendErrorCatalog.sentence(code: "NOPE", message: "raw server text", language: .en).contains("raw server text"))
    }

    func testKnownCodeMessageAndStatus() {
        XCTAssertEqual(BackendErrorCatalog.sentence(code: "FORBIDDEN", language: .en), "You don't have permission to do that.")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: "FORBIDDEN", language: .zhHans), "你没有权限执行此操作。")
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "UNKNOWN", language: .en),
            "The result is still unknown. Please try again later.")
        XCTAssertNotEqual(BackendErrorCatalog.sentence(code: "UNKNOWN", language: .en), BackendErrorCatalog.generic.en)
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, message: "请先登录", language: .zhHans), "请先登录")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, message: "请先登录", language: .en), "Sign in first.")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, status: 401, language: .zhHans), "登录已过期，请重新登录。")
        XCTAssertEqual(BackendErrorCatalog.sentence(code: nil, status: 418, language: .en), BackendErrorCatalog.generic.en)
        XCTAssertEqual(
            BackendErrorCatalog.sentence(code: "  FORBIDDEN  ", message: "请先登录", language: .en),
            "You don't have permission to do that.")
    }

    func testMissingConfigurationThrowsBeforeAnyRequest() {
        XCTAssertThrowsError(try BackendErrorCatalog.requireConfiguration(baseURL: "", realm: "realm")) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertThrowsError(try BackendErrorCatalog.requireConfiguration(baseURL: "https://example.invalid", realm: "")) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertThrowsError(try BackendErrorCatalog.requireConfiguration(baseURL: "  ", realm: "realm")) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertNoThrow(try BackendErrorCatalog.requireConfiguration(baseURL: "https://example.invalid", realm: "realm"))
    }
}
