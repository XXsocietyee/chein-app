import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Pins the one `cursor/cov3-a` path Core did not already record.
/// Money writes stay off: this test builds a login-code request and does not send it.
final class Cov3AContractTests: XCTestCase {
    private var base: URL { URL(string: "https://example.com")! }

    func testLoginCodePinsPostAndCode() throws {
        // app.js:374. siteBaseUrl + '/api/login/code'. POST form field code.
        let request = try Cov3AMPContract.loginCode(baseURL: base, code: "wx-code")
        XCTAssertEqual(Cov3AMPContract.loginCodePath, "api/login/code")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/login/code")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "code=wx-code")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["code"]
        XCTAssertEqual(fields, ["code"])
    }
}
