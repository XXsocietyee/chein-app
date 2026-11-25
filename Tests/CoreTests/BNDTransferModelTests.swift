import XCTest
@testable import QuestifyCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// All values synthetic. No network, no clock, no Keychain. Backend EP-BND-24 does not exist: every
// "server" here is a test double living only in this file.

@MainActor final class BNDTransferMemoryStorage: TemplateAuthoringStorage {
    var values: [String: Data] = [:]
    var writes: [Data] = []
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws { writes.append(data); values[key] = data }
    func remove(_ key: String) throws { values[key] = nil }
}

@MainActor final class BNDTransferStub: BundleTransferServing {
    var previewResult: Result<BundleTransferPreview, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var sendResult: Result<BundleTransferSendResult, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var receiptResult: Result<BundleTransferReceipt, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var revokeResult: Result<BundleTransferRecord, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var claimResult: Result<BundleTransferClaimResult, Error> = .failure(FreeExploreLaunchFailure.disabled)
    var sendCommands: [BundleTransferSendCommand] = []
    var claimKeys: [String] = []
    var receiptKeys: [String] = []
    func preview(registrationID: FreeExploreLaunchID) async throws -> BundleTransferPreview { try previewResult.get() }
    func send(_ command: BundleTransferSendCommand) async throws -> BundleTransferSendResult {
        sendCommands.append(command); return try sendResult.get()
    }
    func receipt(idempotencyKey: String) async throws -> BundleTransferReceipt {
        receiptKeys.append(idempotencyKey); return try receiptResult.get()
    }
    func transfers(registrationID: FreeExploreLaunchID) async throws -> [BundleTransferRecord] { [] }
    func revoke(transferID: FreeExploreLaunchID) async throws -> BundleTransferRecord { try revokeResult.get() }
    func claim(_ command: BundleTransferClaimCommand) async throws -> BundleTransferClaimResult {
        claimKeys.append(command.idempotencyKey); return try claimResult.get()
    }
}

@MainActor final class BNDTransferModelTests: XCTestCase {
    private let secret = "ZX93-SECRET-CODE"
    private let phone = "13800138000"

    private func session() throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                     namespace: "test", role: "player", epoch: 1, token: "synthetic-test-credential")
    }
    private func id(_ n: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }
    private func preview(eligible: Bool, code: String? = nil, channels: [String] = ["IN_APP"]) throws -> BundleTransferPreview {
        let codeJSON = code.map { "\"\($0)\"" } ?? "null"
        let list = channels.map { "\"\($0)\"" }.joined(separator: ",")
        let json = "{\"registrationId\":11,\"eligible\":\(eligible),\"ineligibleCode\":\(codeJSON),\"channels\":[\(list)],\"impact\":[\"line-1\",\"line-2\"]}"
        return try JSONDecoder().decode(BundleTransferPreview.self, from: Data(json.utf8))
    }
    private func record(_ status: BundleTransferState, id value: Int64 = 90) throws -> BundleTransferRecord {
        BundleTransferRecord(id: try id(value), registrationId: try id(11), state: status, expiresAt: nil)
    }
    private func sendModel(_ stub: BNDTransferStub, _ storage: BNDTransferMemoryStorage) throws -> BundleTransferSendModel {
        BundleTransferSendModel(service: stub, pending: BundleTransferPendingStore(storage: storage, session: try session()),
                                makeKey: { "bt-key-1" })
    }
    private func claimModel(_ stub: BNDTransferStub, _ storage: BNDTransferMemoryStorage) throws -> BundleTransferClaimModel {
        BundleTransferClaimModel(service: stub, pending: BundleTransferPendingStore(storage: storage, session: try session()),
                                 makeKey: { "bc-key-1" })
    }
    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private let sourceFiles = ["Core/BundleTransferClient.swift", "Core/BundleTransferModel.swift", "Core/BundleTransferPendingStore.swift",
                               "App/BundleTransferSendView.swift", "App/BundleTransferClaimView.swift", "App/BundleTransferTransport.swift"]
    private func codeLines(_ path: String) throws -> [String] {
        let text = try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
        return text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    // MARK: required

    func testCodeNeverWrittenToStorageOrLogs() async throws {
        let stub = BNDTransferStub(); let storage = BNDTransferMemoryStorage()
        stub.previewResult = .success(try preview(eligible: true))
        stub.sendResult = .success(BundleTransferSendResult(record: try record(.pending), code: try BundleTransferOneTimeCode(secret)))
        let model = try sendModel(stub, storage)
        await model.loadPreview(registrationID: try id(11))
        await model.confirm(phone: phone, channel: .inApp)
        XCTAssertEqual(model.oneTimeCode?.reveal(), secret)
        // Nothing durable contains the code or the receiver phone, at any point.
        XCTAssertFalse(storage.writes.isEmpty)
        for data in storage.writes + Array(storage.values.values) {
            let text = String(decoding: data, as: UTF8.self)
            XCTAssertFalse(text.contains(secret)); XCTAssertFalse(text.contains(phone))
        }
        // Every textual rendering is redacted.
        let code = try XCTUnwrap(model.oneTimeCode)
        var dumped = ""; dump(code, to: &dumped)
        for rendering in ["\(code)", String(describing: code), String(reflecting: code), dumped] {
            XCTAssertFalse(rendering.contains(secret))
        }
        // A claim with an unknown outcome persists only its key.
        let claimStub = BNDTransferStub(); claimStub.claimResult = .failure(FreeExploreLaunchFailure.outcomeUnknown)
        let claimStorage = BNDTransferMemoryStorage()
        let claim = try claimModel(claimStub, claimStorage)
        await claim.claim(code: secret)
        XCTAssertEqual(claim.phase, .outcomeUnknown)
        XCTAssertFalse(claimStorage.writes.isEmpty)
        for data in claimStorage.writes { XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(secret)) }
        // Leaving the screen discards the in-memory code.
        model.leave()
        XCTAssertNil(model.oneTimeCode)
        // No logging or durable-UI-state API appears in any IWP-8c source line.
        let banned = ["print(", "debugPrint(", "NSLog(", "os_log", "Logger(", "dump(", "UserDefaults", "@AppStorage", "@SceneStorage", "Keychain"]
        for path in sourceFiles {
            for line in try codeLines(path) { for word in banned { XCTAssertFalse(line.contains(word), "\(path): \(line)") } }
        }
    }

    func testClaimErrorsAreIndistinguishable() async throws {
        let failures: [FreeExploreLaunchFailure] = [
            .response(status: 200, code: 400, businessCode: BundleTransferBusinessCode.codeInvalid, message: nil),
            .response(status: 404, code: 404, businessCode: BundleTransferBusinessCode.codeInvalid, message: nil),
            .response(status: 400, code: 400, businessCode: BundleTransferBusinessCode.phoneMismatch, message: nil),
            .response(status: 400, code: 400, businessCode: BundleTransferBusinessCode.selfTransfer, message: nil)
        ]
        var phases: [BundleTransferClaimPhase] = []
        for failure in failures {
            let stub = BNDTransferStub(); stub.claimResult = .failure(failure)
            let storage = BNDTransferMemoryStorage()
            let model = try claimModel(stub, storage)
            await model.claim(code: secret)
            phases.append(model.phase)
            // A definite rejection releases the key.
            XCTAssertNil(try BundleTransferPendingStore(storage: storage, session: try session()).load())
        }
        XCTAssertEqual(Set(phases.map { "\($0)" }).count, 1)
        XCTAssertEqual(phases.first, .codeNotAccepted)
        // Control: an unrelated server code is NOT collapsed into the generic state.
        let other = BNDTransferStub(); other.claimResult = .failure(FreeExploreLaunchFailure.response(status: 500, code: 500, businessCode: "OTHER", message: nil))
        let model = try claimModel(other, BNDTransferMemoryStorage())
        await model.claim(code: secret)
        XCTAssertEqual(model.phase, .failed(code: "OTHER"))
    }

    func testTransferUnavailableWhenAnyUnitUsedPerServerEligibility() async throws {
        let stub = BNDTransferStub(); let storage = BNDTransferMemoryStorage()
        stub.previewResult = .success(try preview(eligible: false, code: BundleTransferBusinessCode.notEligible))
        let model = try sendModel(stub, storage)
        await model.loadPreview(registrationID: try id(11))
        XCTAssertEqual(model.phase, .ineligible(code: BundleTransferBusinessCode.notEligible))
        await model.confirm(phone: phone, channel: .inApp)
        XCTAssertTrue(stub.sendCommands.isEmpty)
        XCTAssertTrue(storage.writes.isEmpty)
        // The server may also refuse at create time; the model just reports it.
        let late = BNDTransferStub()
        late.previewResult = .success(try preview(eligible: true))
        late.sendResult = .failure(FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: BundleTransferBusinessCode.notEligible, message: nil))
        let lateModel = try sendModel(late, BNDTransferMemoryStorage())
        await lateModel.loadPreview(registrationID: try id(11))
        await lateModel.confirm(phone: phone, channel: .inApp)
        XCTAssertEqual(lateModel.phase, .ineligible(code: BundleTransferBusinessCode.notEligible))
        XCTAssertNil(lateModel.oneTimeCode)
        // The shipped default is unavailable and never invents data.
        let unavailable = try sendModel(BNDTransferStub(), BNDTransferMemoryStorage())
        await unavailable.loadPreview(registrationID: try id(11))
        XCTAssertEqual(unavailable.phase, .unavailable)
    }

    func testPayerStillSeesRefundQuoteAfterTransferIsServerDriven() async throws {
        let json = #"{"route":"ORIGINAL_METHOD","amount":"49.75","totalValue":"199","remainingValue":"199","remainingRatio":"1","afterSalesForMerchantBreach":false,"reason":"R","policyVersion":"p1"}"#
        let quote = try JSONDecoder().decode(FreeExploreLaunchRefundQuote.self, from: Data(json.utf8))
        // Transfer is claimed; the payer model neither receives nor consults that fact.
        let shown = BundleTransferPayerRefundQuoteModel(quote: { _ in quote })
        await shown.load(registrationID: try id(11))
        XCTAssertEqual(shown.state, .shown(quote))
        let refused = BundleTransferPayerRefundQuoteModel(quote: { _ in
            throw FreeExploreLaunchFailure.response(status: 200, code: 404, businessCode: "BUNDLE_NOT_FOUND", message: nil)
        })
        await refused.load(registrationID: try id(11))
        XCTAssertEqual(refused.state, .unavailable(code: "BUNDLE_NOT_FOUND"))
    }

    func testNoReuseOfInviteOrCouponTypes() throws {
        let pattern = "Invit|Coupon|Licen[cs]e|Reward"
        for path in sourceFiles {
            let lines = try codeLines(path)
            XCTAssertFalse(lines.isEmpty, path)
            for line in lines { XCTAssertNil(line.range(of: pattern, options: .regularExpression), "\(path): \(line)") }
        }
    }

    // MARK: extra

    func testPendingSendRecordHoldsNoCodeOrPhoneAndUnknownOutcomeReadsBackBySameKey() async throws {
        let stub = BNDTransferStub(); let storage = BNDTransferMemoryStorage()
        stub.previewResult = .success(try preview(eligible: true))
        stub.sendResult = .failure(FreeExploreLaunchFailure.outcomeUnknown)
        let model = try sendModel(stub, storage)
        await model.loadPreview(registrationID: try id(11))
        await model.confirm(phone: phone, channel: .inApp)
        XCTAssertEqual(model.phase, .outcomeUnknown)
        let store = BundleTransferPendingStore(storage: storage, session: try session())
        XCTAssertEqual(try store.load(), BundleTransferPendingOperation.send(registrationId: try id(11), channel: .inApp, idempotencyKey: "bt-key-1"))
        for data in storage.writes { XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(phone)) }
        // NOT_FOUND is not proof of "nothing happened": the record stays.
        stub.receiptResult = .success(BundleTransferReceipt(idempotencyKey: "bt-key-1", transfer: nil))
        await model.recover()
        XCTAssertEqual(model.phase, .outcomeUnknown)
        XCTAssertNotNil(try store.load())
        stub.receiptResult = .success(BundleTransferReceipt(idempotencyKey: "bt-key-1", transfer: try record(.pending)))
        await model.recover()
        XCTAssertEqual(stub.receiptKeys, ["bt-key-1", "bt-key-1"])
        XCTAssertEqual(model.phase, .recovered(try record(.pending)))
        XCTAssertNil(model.oneTimeCode)
        XCTAssertNil(try store.load())
    }

    func testSMSOnlyWhenServerAdvertisesAndLoginLossKeepsPending() async throws {
        let stub = BNDTransferStub(); let storage = BNDTransferMemoryStorage()
        stub.previewResult = .success(try preview(eligible: true, channels: ["IN_APP"]))
        let model = try sendModel(stub, storage)
        await model.loadPreview(registrationID: try id(11))
        await model.confirm(phone: phone, channel: .sms)
        XCTAssertTrue(stub.sendCommands.isEmpty)
        XCTAssertEqual(model.phase, .failed(code: nil))
        // Login loss (business 409 + LOGIN_REQUIRED) must not clear the pending command.
        let login = BNDTransferStub(); let loginStorage = BNDTransferMemoryStorage()
        login.previewResult = .success(try preview(eligible: true))
        login.sendResult = .failure(FreeExploreLaunchFailure.response(status: 200, code: 409, businessCode: BundleTransferBusinessCode.loginRequired, message: nil))
        let loginModel = try sendModel(login, loginStorage)
        await loginModel.loadPreview(registrationID: try id(11))
        await loginModel.confirm(phone: phone, channel: .inApp)
        XCTAssertNotNil(try BundleTransferPendingStore(storage: loginStorage, session: try session()).load())
    }

    func testHTTPClientRefusesWritesByDefaultAndSendsExactBodyWhenAllowed() async throws {
        let transport = BNDTransport()
        let s = try session()
        let blocked = try BundleTransferHTTPClient(session: s, authorization: "synthetic-test-credential", transport: transport,
                                                   currentSession: { s })
        let command = try BundleTransferSendCommand(registrationId: try id(11), receiverPhone: phone, channel: .inApp, idempotencyKey: "bt-key-1")
        do { _ = try await blocked.send(command); XCTFail("expected disabled") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .disabled) }
        XCTAssertTrue(transport.requests.isEmpty)
        let allowed = try BundleTransferHTTPClient(session: s, authorization: "synthetic-test-credential", transport: transport,
                                                   currentSession: { s }, writeAllowed: { true })
        transport.handler = { _ in
            (Data(#"{"code":200,"msg":"ok","data":{"id":90,"status":"PENDING","expiresAt":1700000000000,"claimCode":"ZX93-SECRET-CODE"}}"#.utf8), 200)
        }
        let result = try await allowed.send(command)
        XCTAssertEqual(result.code.reveal(), secret)
        XCTAssertEqual(result.record.state, .pending)
        let request = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/free-explore/bundle/transfer")
        XCTAssertEqual(String(decoding: request.httpBody ?? Data(), as: UTF8.self),
                       #"{"channel":"IN_APP","idempotencyKey":"bt-key-1","receiverPhone":"13800138000","registrationId":11}"#)
        // A transport failure on a write is "unknown", never "failed".
        transport.handler = { _ in throw URLError(.timedOut) }
        do { _ = try await allowed.send(command); XCTFail("expected unknown") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .outcomeUnknown) }
    }

    func testSendCommandRejectsBadPhoneAndKey() throws {
        XCTAssertThrowsError(try BundleTransferSendCommand(registrationId: try id(11), receiverPhone: "12", channel: .inApp, idempotencyKey: "k"))
        XCTAssertThrowsError(try BundleTransferSendCommand(registrationId: try id(11), receiverPhone: phone, channel: .inApp, idempotencyKey: "bad key"))
        XCTAssertNoThrow(try BundleTransferSendCommand(registrationId: try id(11), receiverPhone: "+8613800138000", channel: .sms, idempotencyKey: "k_1-2"))
    }
}
