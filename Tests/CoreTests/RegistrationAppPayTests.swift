#if DEBUG
import XCTest
@testable import QuestifyCore

/// Owner check 11-28 05:35 (mp-activity P0): in-app pay uses `pay/app`, and one readback decides the result.
final class RegistrationAppPayTests: XCTestCase {
    func testInAppChannelIsTheAppRoute() {
        XCTAssertEqual(RegistrationAppPayResolver.inAppChannel, .app)
        XCTAssertEqual(RegistrationAppPayResolver.inAppChannel.routePath, "/api/registration/pay/app")
    }

    func testPaidReadbackWinsOverAnyProviderReturn() {
        for providerReturn in [TopicSelfPlayProviderReturn.returned, .cancelled, .failed, .unknown] {
            XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: providerReturn, paymentStatus: 2), .paid)
        }
    }

    func testCancelledOrFailedWithoutPaymentOffersPayAgain() {
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .cancelled, paymentStatus: 0), .cancelled)
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .failed, paymentStatus: nil), .cancelled)
    }

    func testProviderReturnIsNeverProofOfPayment() {
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .returned, paymentStatus: 0), .checking)
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .unknown, paymentStatus: nil), .checking)
    }

    /// fix/1128-cn-pay P0-2: backend `ApiRegistrationController.payApp(String id)` — POST form field `id`, no query.
    func testPayAppRequestShapeMatchesTheBackend() throws {
        let previous = ReleaseMoneyWriteSwitch.testDerivation
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        defer { ReleaseMoneyWriteSwitch.testDerivation = previous }
        let configuration = try APIConfiguration(baseURL: URL(string: "https://api.example.com/prod-api/")!)
        let request = try RegistrationPayService.makeRequest(configuration: configuration, token: "fixture-account-one-token",
                                                             registrationID: 41, channel: RegistrationAppPayResolver.inAppChannel)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/prod-api/api/registration/pay/app")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "fixture-account-one-token")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"id\"\r\n\r\n41\r\n"))
        XCTAssertFalse(body.contains("payChannel"))
    }

    func testPayAppRequestIsRefusedWhilePaymentIsOff() throws {
        let previous = ReleaseMoneyWriteSwitch.testDerivation
        ReleaseMoneyWriteSwitch.testDerivation = { _ in false }
        defer { ReleaseMoneyWriteSwitch.testDerivation = previous }
        let configuration = try APIConfiguration(baseURL: URL(string: "https://api.example.com/prod-api/")!)
        XCTAssertThrowsError(try RegistrationPayService.makeRequest(configuration: configuration, token: "fixture-account-one-token",
                                                                    registrationID: 41, channel: .app))
    }

    /// The APP params (`WechatPaymentSdkGateway` seven keys) reach the SDK hand-off unchanged; a response without
    /// params is not a paid verdict (the pay step reads `api/registration/info` once).
    func testPayAppResponseKeepsTheAppParamsAndNoParamsIsNotPaid() throws {
        let body = #"{"code":200,"msg":"ok","data":{"registrationId":41,"paymentStatus":1,"payParams":{"appId":"wxSynthetic01","partnerId":"1900000109","prepayId":"wx-prepay","packageValue":"Sign=WXPay","nonceStr":"n","timeStamp":"1764300000","sign":"s"}}}"#
        guard case .paidOrParametersReceived(let response) = RegistrationPayService.decode(Data(body.utf8), status: 200, registrationID: 41) else {
            return XCTFail("expected params")
        }
        XCTAssertEqual(response.payParams?["prepayId"], "wx-prepay")
        XCTAssertEqual(response.payParams?.count, 7)
        let bare = #"{"code":200,"msg":"ok","data":{"registrationId":41}}"#
        guard case .paidOrParametersReceived(let none) = RegistrationPayService.decode(Data(bare.utf8), status: 200, registrationID: 41) else {
            return XCTFail("expected a response")
        }
        XCTAssertFalse(none.hasPaymentParameters)
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: none.paymentStatus), .checking)
    }

    func testRefreshOnlyMovesToPaidOnPaidStatus() {
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: 2), .paid)
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: 1), .checking)
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: nil), .checking)
    }
}
#endif
