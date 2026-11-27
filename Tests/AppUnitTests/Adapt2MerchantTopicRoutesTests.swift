import XCTest
@testable import Questify

/// Fixtures copied from hengyin controller response shapes (AjaxResult {code,msg,data}).
@MainActor final class Adapt2MerchantTopicRoutesTests: XCTestCase {
    private let base = URL(string: "https://example.invalid/")!
    private let token = "synthetic-token"

    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply: (Data, Int) = (Data(), 200)
        var fail = false
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if fail { throw URLError(.timedOut) }
            return reply
        }
    }

    func testRoutesAndLegacyReplacements() {
        XCTAssertEqual(Adapt2MerchantTopicRoute.legacyReplacements["api/merchant/insight"]?.rawValue, "api/ai/merchant/insight")
        XCTAssertEqual(Adapt2MerchantTopicRoute.legacyReplacements["api/merchant/poi/detail"]?.rawValue, "api/merchant/public-detail")
        XCTAssertEqual(Adapt2MerchantTopicRoute.legacyReplacements["api/merchant/shop/apply"]?.rawValue, "api/merchant/merchant_registration")
        // Round 3 contract cleanup: the dead api/topic/detail literal is dropped; topic reads call .topicInfoToUser directly.
        XCTAssertNil(Adapt2MerchantTopicRoute.legacyReplacements["api/topic/detail"])
        XCTAssertEqual(Adapt2MerchantTopicRoute.legacyReplacements["api/merchant/npc/voice/revoke"]?.rawValue, "api/merchant/npc/voice/reset")
        for legacy in Adapt2MerchantTopicRoute.legacyReplacements.keys {
            XCTAssertNil(Adapt2MerchantTopicRoute(rawValue: legacy))
        }
    }

    func testNoBodyRoutesPostWithRawTokenAndRefuseBodies() throws {
        let builder = Adapt2MerchantTopicRequestBuilder(baseURL: base)
        for route in [Adapt2MerchantTopicRoute.merchantInsight, .npcVoiceReset] {
            let request = try builder.make(route, token: token)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/" + route.rawValue)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), token)
            XCTAssertNil(request.httpBody)
            XCTAssertThrowsError(try builder.make(route, token: token, form: ["id": "1"]))
            XCTAssertThrowsError(try builder.make(route, token: nil))
        }
    }

    func testPublicDetailIsJSONWithIdOnlyAndAnonymous() throws {
        let request = try Adapt2MerchantTopicRequestBuilder(baseURL: base).publicDetail(merchantID: 31)
        XCTAssertEqual(request.url?.path, "/api/merchant/public-detail")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), #"{"id":31}"#)
        XCTAssertThrowsError(try Adapt2MerchantTopicRequestBuilder(baseURL: base).publicDetail(merchantID: 0))
    }

    func testTopicInfoIsFormEncodedWithId() throws {
        let request = try Adapt2MerchantTopicRequestBuilder(baseURL: base).topicInfo(topicID: 88, token: token)
        XCTAssertEqual(request.url?.path, "/api/topic/info-to-user")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), "id=88")
        XCTAssertThrowsError(try Adapt2MerchantTopicRequestBuilder(baseURL: base).topicInfo(topicID: 88, token: " "))
    }

    func testRegistrationRequiresTokenAndJSONObject() throws {
        let builder = Adapt2MerchantTopicRequestBuilder(baseURL: base)
        let body = Data(#"{"merchantName":"Synthetic"}"#.utf8)
        let request = try builder.make(.merchantRegistration, token: token, json: body)
        XCTAssertEqual(request.url?.path, "/api/merchant/merchant_registration")
        XCTAssertEqual(request.httpBody, body)
        XCTAssertThrowsError(try builder.make(.merchantRegistration, token: nil, json: body))
        XCTAssertThrowsError(try builder.make(.merchantRegistration, token: token, json: Data("[1]".utf8)))
        XCTAssertThrowsError(try builder.make(.merchantRegistration, token: token))
    }

    func testEnvelopeUnwrap() throws {
        let ok = try Adapt2AjaxEnvelope.unwrap(status: 200, body: Data(#"{"code":200,"msg":"已清除"}"#.utf8))
        XCTAssertEqual(ok.message, "已清除"); XCTAssertNil(ok.data)
        let withData = try Adapt2AjaxEnvelope.unwrap(status: 200, body: Data(#"{"code":200,"msg":"操作成功","data":{"a":1}}"#.utf8))
        XCTAssertEqual(withData.data, Data(#"{"a":1}"#.utf8))
        XCTAssertThrowsError(try Adapt2AjaxEnvelope.unwrap(status: 200, body: Data(#"{"code":500,"msg":"声音未清除，请重试"}"#.utf8))) {
            XCTAssertEqual($0 as? Adapt2Failure, .rejected(code: 500, message: "声音未清除，请重试"))
        }
        XCTAssertThrowsError(try Adapt2AjaxEnvelope.unwrap(status: 200, body: Data("nope".utf8))) { XCTAssertEqual($0 as? Adapt2Failure, .malformed) }
        XCTAssertThrowsError(try Adapt2AjaxEnvelope.unwrap(status: 502, body: Data())) { XCTAssertEqual($0 as? Adapt2Failure, .unknownOutcome) }
        XCTAssertThrowsError(try Adapt2AjaxEnvelope.unwrap(status: 401, body: Data())) { XCTAssertEqual($0 as? Adapt2Failure, .unauthorized) }
    }

    func testVoiceResetDefaultGateOffNeverSends() async {
        let wire = Wire()
        let client = Adapt2MerchantNPCVoiceResetClient(baseURL: base, token: { self.token }, transport: wire)
        do { _ = try await client.reset(); XCTFail("must be disabled") }
        catch { XCTAssertEqual(error as? MerchantNPCFailure, .disabled) }
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testVoiceResetSuccessSendsOneBodylessPost() async throws {
        let wire = Wire(); wire.reply = (Data(#"{"code":200,"msg":"已清除"}"#.utf8), 200)
        let client = Adapt2MerchantNPCVoiceResetClient(baseURL: base, token: { self.token }, transport: wire, allowed: { true })
        let receipt = try await client.reset()
        XCTAssertEqual(receipt, .accepted(message: "已清除"))
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/merchant/npc/voice/reset")
        XCTAssertNil(wire.requests[0].httpBody)
    }

    func testVoiceResetFailureMapping() async {
        let wire = Wire()
        let client = Adapt2MerchantNPCVoiceResetClient(baseURL: base, token: { self.token }, transport: wire, allowed: { true })
        wire.reply = (Data(#"{"code":500,"msg":"声音未清除，请重试"}"#.utf8), 200)
        do { _ = try await client.reset(); XCTFail() } catch { XCTAssertEqual(error as? MerchantNPCFailure, .rejected(code: 500, message: "声音未清除，请重试")) }
        wire.fail = true
        do { _ = try await client.reset(); XCTFail() } catch { XCTAssertEqual(error as? MerchantNPCFailure, .unknownOutcome) }
        let noToken = Adapt2MerchantNPCVoiceResetClient(baseURL: base, token: { nil }, transport: wire, allowed: { true })
        wire.fail = false; wire.requests = []
        do { _ = try await noToken.reset(); XCTFail() } catch { XCTAssertEqual(error as? MerchantNPCFailure, .invalid) }
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
