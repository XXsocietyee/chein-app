import XCTest
@testable import QuestifyCore

/// ADAPT-5 worker B. Real routes verified in hengyin@4ac8c249:
/// - `ApiLoginController` `@RequestMapping("/api")` + `@PostMapping("/sms/send")`: param `phone` (request param, no body), anonymous
///   (`SecurityConfig` permitAll), reply `AjaxResult{code,msg}`.
/// - `ApiRegistrationController` `@RequestMapping("/api/registration")` `@PostMapping("/pay")` and `("/pay/app")`: param `id`,
///   member token (`请先登录` otherwise; 410 for expired order on `/pay`), reply `AjaxResult{code,msg,data}`.
final class Adapt5HighRiskWriteSupplementTests: XCTestCase {
    private struct AjaxFixture: Decodable { let code: Int; let msg: String }

    func testSupplementNamesTheThreeRealRoutes() {
        XCTAssertEqual(Set(Adapt5HighRiskWriteSupplement.canonicalPaths),
                       ["/api/sms/send", "/api/registration/pay", "/api/registration/pay/app"])
    }

    func testOriginalDenyListIsUntouched() {
        XCTAssertEqual(Set(RegionalEndpointAllowlistAudit.requiredHighRiskWriteRoutes), [
            "/api/asset/withdraw", "/api/pay/create", "/api/npc/chat/delete",
            "/api/topic/like", "/api/user/sms/send", "/api/merchant/decor/save"])
        XCTAssertEqual(Adapt5HighRiskWriteSupplement.allBlockedPaths.count, 9)
    }

    func testEveryOriginalAndSupplementalPathIsBlockedByDefault() {
        for path in Adapt5HighRiskWriteSupplement.allBlockedPaths {
            XCTAssertTrue(Adapt5HighRiskWriteSupplement.isBlockedByDefault(path), path)
        }
        XCTAssertTrue(Adapt5HighRiskWriteSupplement.isBlockedByDefault("api/sms/send"))
        XCTAssertTrue(Adapt5HighRiskWriteSupplement.isBlockedByDefault("https://cn-api.example.com/api/registration/pay/app"))
        XCTAssertTrue(Adapt5HighRiskWriteSupplement.isBlockedByDefault("/api/user/sms/send"))
        XCTAssertFalse(Adapt5HighRiskWriteSupplement.isBlockedByDefault("/api/registration/info"))
        XCTAssertFalse(Adapt5HighRiskWriteSupplement.isBlockedByDefault("/api/login/phone"))
    }

    func testMatchAndNonMatch() {
        XCTAssertEqual(Adapt5HighRiskWriteSupplement.match("/api/registration/pay"), .registrationPay)
        XCTAssertNil(Adapt5HighRiskWriteSupplement.match("/api/registration/pay/other"))
    }

    func testRealBackendReplyShapesDecode() throws {
        let fixtures = [
            #"{"msg":"请先登录","code":500}"#,
            #"{"msg":"请先完成报名信息提供的单独同意","code":500}"#,
            #"{"msg":"订单已过期","code":410}"#,
        ]
        let codes = try fixtures.map { try JSONDecoder().decode(AjaxFixture.self, from: Data($0.utf8)).code }
        XCTAssertEqual(codes, [500, 500, 410])
    }
}
