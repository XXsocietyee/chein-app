import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exercises the canonical builders/services through the real single-attempt transport.
/// Synthetic responses only: no network session, new operation grant, or alternate parser.
@MainActor final class ProfileParticipantMultipartCRLFBoundaryTests: XCTestCase {
    private let base = URL(string: "https://example.test/participant-crlf")!
    private let token = "synthetic-participant-crlf"
    private let requestID = UUID(uuidString: "12345678-1234-4234-8234-123456789abc")!
    private let phone = "13900000009"
    private func context(account: Int = 7, epoch: UInt64 = 1, role: String = "player",
                         credential: String = "synthetic-participant-crlf", namespace: String = "participant-crlf",
                         origin: URL? = nil) throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: origin ?? base, role: role,
            session: try .init(accountID: account, epoch: epoch, namespace: namespace, token: credential, role: role))
    }
    private func request(_ leaf: String, fields: [String: String]? = nil) throws -> URLRequest {
        try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/user/address/" + leaf),
            fields: fields ?? [:], token: token, includesBody: fields != nil, boundary: "participant-crlf-boundary")
    }
    private func createdFields(_ name: String) -> [String: String] {
        ["fullName": name, "mobilePhone": phone, "isDefault": "0", "requestId": requestID.uuidString.lowercased()]
    }
    @MainActor private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply: (Data, Int) = (Data(#"{"code":200}"#.utf8), 200)
        var failure: Error?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if let failure { throw failure }
            return reply
        }
    }
    @MainActor private final class HeldWire: HTTPTransport {
        var requests: [URLRequest] = []
        var pending: CheckedContinuation<(Data, Int), Error>?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        func wait() async throws {
            for _ in 0..<2000 { if pending != nil { return }; await Task.yield() }
            XCTFail("The original underlying send must actually be entered"); throw APIError.invalidRequest
        }
        func finish(status: Int, data: Data? = nil) {
            let held = pending; pending = nil
            held?.resume(returning: (data ?? Data("{\"code\":\(status)}".utf8), status))
        }
        func drain() { pending?.resume(throwing: CancellationError()); pending = nil }
    }
    private func transport(_ owner: RuntimeDependencyContext, _ access: ProfileParticipantAccess,
                           _ wire: any HTTPTransport) -> ProfileParticipantTransport {
        .init(context: owner, access: access, underlying: wire, current: { owner }, stillCurrent: { true })
    }
    private func assertBody(_ request: URLRequest, fields: [String: String]) throws {
        let prefix = "multipart/form-data; boundary="
        let type = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(type.hasPrefix(prefix))
        let boundary = String(type.dropFirst(prefix.count))
        let expected = try AuthRequestBuilder.makeFormRequest(url: XCTUnwrap(request.url), fields: fields,
            token: token, boundary: boundary)
        XCTAssertEqual(request.httpBody, expected.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), token)
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertNil(request.httpBodyStream)
    }
    func testSingleCharacterIDsAndDefaultsPreserveEveryUnicodePayloadByte() async throws {
        XCTAssertEqual("\r\n".count, 1)
        let owner = try context(), access = try ProfileParticipantAccess(context: owner, permitsWrites: true,
            expiresAt: Date().addingTimeInterval(60))
        defer { access.revoke() }
        var cases: [(URLRequest, ProfileParticipantRoute.Operation)] = [
            (try request("list"), .list), (try request("info", fields: ["id": "1"]), .info(1)),
            (try request("delete", fields: ["id": "9"]), .delete(9))]
        for name in ["A", "ASCII-Z", "名字", "e\u{301}", "尾👩🏽‍💻", "A\r\nB"] {
            cases.append((try request("action", fields: createdFields(name)), .create(requestID)))
            for flag in ["0", "1"] {
                let fields = ["id": "1", "fullName": name, "mobilePhone": phone, "isDefault": flag,
                              "province": "P e\u{301}", "detailAddress": "尾🏳️‍🌈"]
                cases.append((try request("action", fields: fields), .edit(1)))
            }
        }
        for (original, operation) in cases {
            let originalBody = original.httpBody, wire = Wire(), attempt = transport(owner, access, wire)
            XCTAssertEqual(ProfileParticipantRoute.parse(original, baseURL: base)?.operation, operation)
            _ = try await attempt.send(original)
            XCTAssertTrue(attempt.hasForwardedRequest); XCTAssertEqual(wire.requests.count, 1)
            XCTAssertEqual(wire.requests.first?.httpBody, originalBody)
            do { _ = try await attempt.send(original); XCTFail("A parsed request still gets only one attempt") }
            catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
            XCTAssertEqual(wire.requests.count, 1)
        }
    }
    func testOriginalProfileAndParticipantServicesReachAllFourAddressRoutesWithExactBodies() async throws {
        let owner = try context(), access = try ProfileParticipantAccess(context: owner, permitsWrites: true,
            expiresAt: Date().addingTimeInterval(60)), wire = Wire()
        defer { access.revoke() }
        let config = try APIConfiguration(baseURL: base)
        wire.reply = (Data(#"{"code":200,"data":{"rows":[]}}"#.utf8), 200)
        let list = try await ProfileService(configuration: config, transport: transport(owner, access, wire)).participants(token: token)
        XCTAssertTrue(list.isEmpty); XCTAssertNil(wire.requests.last?.httpBody)
        wire.reply = (try JSONSerialization.data(withJSONObject: ["code": 200, "data":
            ["id": 1, "fullName": "林 e\u{301}👩🏽‍💻", "mobilePhone": phone, "isDefault": 1,
             "province": "省", "detailAddress": "楼🏳️‍🌈"]]), 200)
        let detail = try await ProfileService(configuration: config, transport: transport(owner, access, wire))
            .participant(id: 1, token: token)
        XCTAssertEqual(detail.mobilePhone, phone); XCTAssertTrue(detail.isDefault)
        try assertBody(XCTUnwrap(wire.requests.last), fields: ["id": "1"])
        var draft = ParticipantFormDraft(); draft.fullName = "新 e\u{301}👩🏽‍💻"; draft.mobilePhone = phone
        wire.reply = (try JSONSerialization.data(withJSONObject: ["code": 200, "data":
            ["id": 2, "fullName": draft.fullName, "mobilePhone": phone, "isDefault": 0]]), 200)
        let created = try await ParticipantService(configuration: config, transport: transport(owner, access, wire))
            .performReturningParticipant(.save(draft), requestID: requestID, token: token)
        XCTAssertEqual(created?.id, 2); XCTAssertEqual(created?.mobilePhone, phone)
        try assertBody(XCTUnwrap(wire.requests.last), fields: createdFields(draft.fullName))
        XCTAssertEqual(ProfileParticipantRoute.parse(try XCTUnwrap(wire.requests.last), baseURL: base)?.operation, .create(requestID))
        let edit = ParticipantFormDraft(detail: detail)
        wire.reply = (Data(#"{"code":200}"#.utf8), 200)
        try await ParticipantService(configuration: config, transport: transport(owner, access, wire)).perform(.save(edit), token: token)
        try assertBody(XCTUnwrap(wire.requests.last), fields: edit.fields())
        try await ParticipantService(configuration: config, transport: transport(owner, access, wire)).perform(.delete(id: 1), token: token)
        try assertBody(XCTUnwrap(wire.requests.last), fields: ["id": "1"])
        XCTAssertEqual(wire.requests.map { $0.url?.lastPathComponent }, ["list", "info", "action", "action", "delete"])
        XCTAssertTrue(wire.requests.allSatisfy { ProfileParticipantRoute.parse($0, baseURL: base) != nil })
    }
    func testMalformedSeparatorsDuplicatesExtraFieldsHeadersAndNoncanonicalBodiesStillRejectBeforeWire() async throws {
        let owner = try context(), access = try ProfileParticipantAccess(context: owner, permitsWrites: true,
            expiresAt: Date().addingTimeInterval(60)), wire = Wire()
        defer { access.revoke() }
        let original = try request("info", fields: ["id": "1"])
        var bad = [try request("info", fields: ["id": "1", "owner_id": "7"]),
                   try request("info", fields: ["id": "01"]), try request("list", fields: [:]),
                   try request("action", fields: ["id": "1", "fullName": "Name", "mobilePhone": phone, "isDefault": "0", "requestId": requestID.uuidString.lowercased()]),
                   try request("setDefault", fields: ["id": "1", "isDefault": "1"])]
        for name in [" Name", "Name ", "Name\r\n"] { bad.append(try request("action", fields: createdFields(name))) }
        var uppercase = createdFields("Name"); uppercase["requestId"] = requestID.uuidString
        bad.append(try request("action", fields: uppercase))
        for suffix in ["?id=1", "#fragment"] { var value = original; value.url = URL(string: original.url!.absoluteString + suffix); bad.append(value) }
        var origin = original; origin.url = URL(string: "https://foreign.test/participant-crlf/api/user/address/info"); bad.append(origin)
        for path in ["api/registration/info", "api/badge/wall-v2", "api/merchant/address/info", "api/user/address/result"] {
            var value = original; value.url = base.appendingPathComponent(path); bad.append(value)
        }
        var method = original; method.httpMethod = "GET"; bad.append(method)
        for (key, value) in [("Cookie", "unexpected"), ("X-Owner", "7"), ("Accept", "application/json, application/json"), ("Content-Type", "application/json")] {
            var altered = original; altered.setValue(value, forHTTPHeaderField: key); bad.append(altered)
        }
        var stream = original; stream.httpBodyStream = InputStream(data: Data()); bad.append(stream)
        let text = String(decoding: try XCTUnwrap(original.httpBody), as: UTF8.self)
        let part = "--participant-crlf-boundary\r\nContent-Disposition: form-data; name=\"id\"\r\n\r\n1\r\n"
        let closing = "--participant-crlf-boundary--\r\n"
        for body in [text.replacingOccurrences(of: "\r\n", with: "\n"), text + "junk", "\r\n" + text,
                     String(text.dropLast()), text.replacingOccurrences(of: "1\r\n--", with: "1\n--"),
                     part + part + closing, text.replacingOccurrences(of: "Content-Disposition: ", with: "Content-Disposition:"),
                     "id=1", text.replacingOccurrences(of: "1\r\n--", with: "1\r\n\r\n--")] {
            var altered = original; altered.httpBody = Data(body.utf8); bad.append(altered)
        }
        let fields = createdFields("Name")
        var reordered = try request("action", fields: fields)
        let parts = fields.keys.sorted().reversed().map {
            "--participant-crlf-boundary\r\nContent-Disposition: form-data; name=\"\($0)\"\r\n\r\n\(fields[$0]!)\r\n"
        }.joined()
        reordered.httpBody = Data((parts + closing).utf8); bad.append(reordered)
        for value in bad {
            XCTAssertNil(ProfileParticipantRoute.parse(value, baseURL: base))
            let attempt = transport(owner, access, wire)
            do { _ = try await attempt.send(value); XCTFail("Malformed requests must never reach the original wire") }
            catch { XCTAssertEqual(error as? APIError, .notConfigured) }
            XCTAssertFalse(attempt.hasForwardedRequest)
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }
    func testCredentialContextAndReadOnlyBoundariesDoNotBecomeGenericPostAuthority() async throws {
        let owner = try context(), wire = Wire(), req = try request("delete", fields: ["id": "1"])
        XCTAssertEqual(ProfileParticipantRoute.parse(req, baseURL: base)?.operation, .delete(1))
        let access = try ProfileParticipantAccess(context: owner, permitsWrites: true, expiresAt: Date().addingTimeInterval(60))
        defer { access.revoke() }
        let replacements: [RuntimeDependencyContext?] = [nil, try context(account: 8), try context(epoch: 2),
            try context(role: "merchant"), try context(credential: "replacement"), try context(namespace: "other"),
            try context(origin: URL(string: "https://other.test/participant-crlf")!)]
        for replacement in replacements {
            let attempt = ProfileParticipantTransport(context: owner, access: access, underlying: wire,
                current: { replacement }, stillCurrent: { true })
            do { _ = try await attempt.send(req); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
            XCTAssertFalse(attempt.hasForwardedRequest)
        }
        for credential in ["replacement", token + ", " + token] {
            var value = req; value.setValue(credential, forHTTPHeaderField: "Authorization")
            let attempt = transport(owner, access, wire)
            do { _ = try await attempt.send(value); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
            XCTAssertFalse(attempt.hasForwardedRequest)
        }
        let stale = ProfileParticipantTransport(context: owner, access: access, underlying: wire, current: { owner }, stillCurrent: { false })
        do { _ = try await stale.send(req); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(wire.requests.isEmpty)
        let readOnly = try ProfileParticipantAccess(context: owner, permitsWrites: false, expiresAt: Date().addingTimeInterval(60))
        defer { readOnly.revoke() }
        for value in [req, try request("action", fields: createdFields("Name")),
                      try request("action", fields: ["id": "1", "fullName": "Name", "mobilePhone": phone, "isDefault": "1"])] {
            let attempt = transport(owner, readOnly, wire)
            do { _ = try await attempt.send(value); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
            XCTAssertFalse(attempt.hasForwardedRequest)
        }
        XCTAssertTrue(wire.requests.isEmpty)
        for leaf in ["list", "info"] {
            _ = try await transport(owner, readOnly, wire).send(request(leaf, fields: leaf == "list" ? nil : ["id": "1"]))
        }
        XCTAssertEqual(wire.requests.count, 2)
    }
    func testWithdrawnAndExpiredAccessRejectPreviouslyCanonicalBodyRequests() async throws {
        let owner = try context(), wire = Wire(), req = try request("info", fields: ["id": "1"])
        XCTAssertNotNil(ProfileParticipantRoute.parse(req, baseURL: base))
        let revoked = try ProfileParticipantAccess(context: owner, permitsWrites: true, expiresAt: Date().addingTimeInterval(60))
        revoked.revoke()
        let expiresAt = Date().addingTimeInterval(0.05)
        let expiring = try ProfileParticipantAccess(context: owner, permitsWrites: true, expiresAt: expiresAt)
        defer { expiring.revoke() }
        XCTAssertFalse(expiring.matches(owner, now: expiresAt))
        try await Task.sleep(nanoseconds: 100_000_000)
        for access in [revoked, expiring] {
            let attempt = transport(owner, access, wire)
            do { _ = try await attempt.send(req); XCTFail() } catch { XCTAssertEqual(error as? APIError, .notConfigured) }
            XCTAssertFalse(attempt.hasForwardedRequest)
        }
        XCTAssertTrue(wire.requests.isEmpty)
    }
    func testLateRevocationOwnerOrVisitChangeDropsSuccessAnd401AfterUnderlyingSend() async throws {
        for retirement in 0..<3 {
            for status in [200, 401] {
                let owner = try context(), access = try ProfileParticipantAccess(context: owner, permitsWrites: true,
                    expiresAt: Date().addingTimeInterval(60)), wire = HeldWire()
                var current: RuntimeDependencyContext? = owner, visible = true
                defer { access.revoke(); wire.drain() }
                let attempt = ProfileParticipantTransport(context: owner, access: access, underlying: wire,
                    current: { current }, stillCurrent: { visible })
                let service = ParticipantService(configuration: try APIConfiguration(baseURL: base), transport: attempt)
                let read = Task { try await service.perform(.delete(id: 1), token: token) }
                try await wire.wait()
                XCTAssertTrue(attempt.hasForwardedRequest); XCTAssertEqual(wire.requests.count, 1)
                XCTAssertEqual(ProfileParticipantRoute.parse(try XCTUnwrap(wire.requests.first), baseURL: base)?.operation, .delete(1))
                if retirement == 0 { access.revoke() }
                else if retirement == 1 { current = try context(epoch: 2) }
                else { visible = false }
                wire.finish(status: status)
                do { try await read.value; XCTFail("A late reply cannot become a current write result") }
                catch { XCTAssertEqual(error as? ParticipantWriteError, .outcomeUnknown(.cancelled)) }
                XCTAssertEqual(wire.requests.count, 1)
            }
        }
    }
    func testLateInfoReadCannotPublishPrivateRowAfterOriginalAccessRevocation() async throws {
        let owner = try context(), access = try ProfileParticipantAccess(context: owner, permitsWrites: false,
            expiresAt: Date().addingTimeInterval(60)), wire = HeldWire()
        defer { access.revoke(); wire.drain() }
        let attempt = transport(owner, access, wire)
        let service = ProfileService(configuration: try APIConfiguration(baseURL: base), transport: attempt)
        let read = Task { try await service.participant(id: 1, token: token) }
        try await wire.wait()
        XCTAssertTrue(attempt.hasForwardedRequest); XCTAssertEqual(wire.requests.count, 1)
        let data = try JSONSerialization.data(withJSONObject: ["code": 200, "data":
            ["id": 1, "fullName": "Private synthetic name", "mobilePhone": phone]])
        access.revoke(); wire.finish(status: 200, data: data)
        do { _ = try await read.value; XCTFail("A fully valid old row must not escape retirement") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(wire.requests.count, 1)
    }
    func testTimeoutKeepsOriginalCreateUUIDAndExplicitRetryBodyWithoutAutomaticResend() async throws {
        let owner = try context(), access = try ProfileParticipantAccess(context: owner, permitsWrites: true,
            expiresAt: Date().addingTimeInterval(60)), wire = Wire(), config = try APIConfiguration(baseURL: base)
        defer { access.revoke() }
        var draft = ParticipantFormDraft(); draft.fullName = "原请求👩🏽‍💻"; draft.mobilePhone = phone
        wire.failure = URLError(.timedOut)
        let originalAttempt = transport(owner, access, wire)
        let service = ParticipantService(configuration: config, transport: originalAttempt)
        do { _ = try await service.performReturningParticipant(.save(draft), requestID: requestID, token: token); XCTFail() }
        catch { XCTAssertEqual(error as? ParticipantWriteError, .outcomeUnknown(.transport)) }
        XCTAssertTrue(originalAttempt.hasForwardedRequest); XCTAssertEqual(wire.requests.count, 1)
        try assertBody(XCTUnwrap(wire.requests.first), fields: createdFields(draft.fullName))
        wire.failure = nil; wire.reply = (try JSONSerialization.data(withJSONObject: ["code": 200, "data":
            ["id": 1, "fullName": draft.fullName, "mobilePhone": phone]]), 200)
        // This explicit service invocation supplies the same immutable original UUID/payload.
        // It does not assert that a current read acknowledges an UNKNOWN coordinator lock.
        let retried = try await ParticipantService(configuration: config, transport: transport(owner, access, wire))
            .performReturningParticipant(.save(draft), requestID: requestID, token: token)
        XCTAssertEqual(retried?.fullName, draft.fullName); XCTAssertEqual(wire.requests.count, 2)
        try assertBody(XCTUnwrap(wire.requests.last), fields: createdFields(draft.fullName))
        for value in wire.requests {
            XCTAssertEqual(ProfileParticipantRoute.parse(value, baseURL: base)?.operation, .create(requestID))
        }
    }
}
