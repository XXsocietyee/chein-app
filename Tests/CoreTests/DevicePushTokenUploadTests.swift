import XCTest
@testable import QuestifyCore

final class DevicePushTokenUploadTests: XCTestCase {
    func testRequestShapeIsSortedJSONWithLowercaseHex() throws {
        let token = Data(repeating: 0xab, count: 31) + Data([0x01])
        let body = try XCTUnwrap(DevicePushTokenUploadRequest(token: token, environment: DevicePushTokenUpload.sandbox,
                                                              bundleId: "com.chengyinhub.chengyinApp"))
        XCTAssertEqual(body.token, String(repeating: "ab", count: 31) + "01")
        XCTAssertEqual(body.environment, "SANDBOX")
        let encoded = try DevicePushTokenUpload.encoder.encode(body)
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertEqual(text, #"{"bundleId":"com.chengyinhub.chengyinApp","environment":"SANDBOX","token":"\#(body.token)"}"#)
        let configuration = try APIConfiguration(baseURL: URL(string: "https://upload.example.test")!)
        let request = try XCTUnwrap(DevicePushTokenUpload.urlRequest(for: body, configuration: configuration, sessionToken: "session-token"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/device/push-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "session-token")
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertEqual(request.httpBody, encoded)
    }

    func testRejectsFixtureLabelShortTokenAndBadEnvironment() {
        let bytes = Data(repeating: 0x10, count: 32)
        XCTAssertNil(DevicePushTokenUploadRequest(token: Data(repeating: 0x10, count: 31), environment: "SANDBOX", bundleId: "com.chengyinhub.chengyinApp"))
        XCTAssertNil(DevicePushTokenUploadRequest(token: bytes, environment: "PRODUCTION_LABEL", bundleId: "com.chengyinhub.chengyinApp"))
        XCTAssertNil(DevicePushTokenUploadRequest(token: bytes, environment: "LIVE", bundleId: "com.chengyinhub.chengyinApp"))
        XCTAssertNil(DevicePushTokenUploadRequest(token: bytes, environment: "SANDBOX", bundleId: ""))
        XCTAssertNil(DevicePushTokenUploadRequest(token: bytes, environment: "SANDBOX", bundleId: "has space"))
        XCTAssertFalse(DevicePushTokenUploadRequest.isDeviceTokenHex("fixture-token-c09"))
        XCTAssertFalse(DevicePushTokenUploadRequest.isDeviceTokenHex(String(repeating: "AB", count: 32)))
        XCTAssertNotNil(DevicePushTokenUploadRequest(token: bytes, environment: DevicePushTokenUpload.production, bundleId: "com.chengyinhub.chengyinApp"))
    }

    func testCompositionRefusesTheUploadSoNothingIsDeliverable() throws {
        XCTAssertFalse(DevicePushTokenUpload.compositionAdmitsUpload())
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: "/api/device/push-token"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/device/push-token"))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/device/push-token"))
        let body = try XCTUnwrap(DevicePushTokenUploadRequest(token: Data(repeating: 0x22, count: 32),
                                                              environment: "PRODUCTION", bundleId: "com.chengyinhub.chengyinApp"))
        let configuration = try APIConfiguration(baseURL: URL(string: "https://upload.example.test")!)
        XCTAssertNil(DevicePushTokenUpload.deliverableRequest(for: body, configuration: configuration, sessionToken: "session-token"))
        XCTAssertNil(DevicePushTokenUpload.urlRequest(for: body, configuration: configuration, sessionToken: " bad"))
        XCTAssertNil(DevicePushTokenUpload.urlRequest(for: body, configuration: configuration, sessionToken: nil))
    }
}
