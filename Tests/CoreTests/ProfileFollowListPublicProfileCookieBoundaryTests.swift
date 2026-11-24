import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Canonical service requests cross the unchanged production read policy on a synthetic wire.
/// No writer, alternate decoder, network session, or additional approval is supplied.
@MainActor final class ProfileFollowListPublicProfileCookieBoundaryTests: XCTestCase {
    private func context(account: Int = 7, epoch: UInt64 = 1, role: String = "player",
                         token: String = "synthetic-cookie-boundary",
                         namespace: String = "follow-cookie-fixture",
                         base: String = "https://example.test/follow-cookie") throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: base)!, role: role,
              session: try .init(accountID: account, epoch: epoch, namespace: namespace, token: token))
    }
    private func grant(_ value: RuntimeDependencyContext) throws -> ProfileFollowListApproval {
        try .init(endpoint: .init(baseURL: value.baseURL, namespace: value.session.namespace,
            accountID: value.session.accountID, paths: ProfileFollowListApproval.paths), expiresAt: .distantFuture)
    }
    private static let profile = Data(#"{"code":200,"data":{"id":8,"nickname":"Synthetic member","isFollow":true}}"#.utf8)
    @MainActor private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var operation: @MainActor (URLRequest) async throws -> (Data, Int) = { _ in (ProfileFollowListPublicProfileCookieBoundaryTests.profile, 200) }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request); return try await operation(request)
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
            XCTFail("Canonical request did not reach the synthetic wire"); throw APIError.invalidRequest
        }
        func finish(_ outcome: Int) {
            let continuation = pending; pending = nil
            if outcome == 2 { continuation?.resume(throwing: APIError.unauthorized) }
            else if outcome == 1 { continuation?.resume(returning: (Data(#"{"code":401}"#.utf8), 401)) }
            else { continuation?.resume(returning: (ProfileFollowListPublicProfileCookieBoundaryTests.profile, 200)) }
        }
        func drain() { pending?.resume(throwing: CancellationError()); pending = nil }
    }
    func testCanonicalPublicProfilePassesOriginalPolicyWithoutChangingTokenMultipartOrTarget() async throws {
        let value = try context(), approved = try grant(value), wire = Wire()
        wire.operation = { request in
            guard ProfileFollowListTransportPolicy.accepts(request, context: value, approval: approved) else {
                throw APIError.notConfigured
            }
            return (Self.profile, 200)
        }
        let service = SocialAccountService(configuration: try APIConfiguration(baseURL: value.baseURL), transport: wire)
        let result = try await service.profile(memberID: 8, token: value.session.token)
        XCTAssertEqual(result.id, 8); XCTAssertEqual(result.isFollowed, true)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), value.session.token)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, value.baseURL.appendingPathComponent(ProfilePublicInfoReadRoute.path))
        XCTAssertNil(request.url?.query); XCTAssertNil(request.httpBodyStream)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.timeoutInterval, 20)
        XCTAssertEqual(ProfilePublicInfoReadRoute(request: request, baseURL: value.baseURL)?.memberID, 8)
        let type = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(type.hasPrefix("multipart/form-data; boundary="))
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        let expected = "--\(boundary)\r\nContent-Disposition: form-data; name=\"member_id\"\r\n\r\n8\r\n--\(boundary)--\r\n"
        XCTAssertEqual(request.httpBody, Data(expected.utf8))
    }
    func testOriginalPolicyStillRejectsCookiesForeignOriginCredentialsAndApprovalScope() async throws {
        let value = try context(), approved = try grant(value), wire = Wire()
        _ = try await SocialAccountService(configuration: APIConfiguration(baseURL: value.baseURL), transport: wire)
            .profile(memberID: 8, token: value.session.token)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertTrue(ProfileFollowListTransportPolicy.accepts(request, context: value, approval: approved))
        var cookies = request; cookies.httpShouldHandleCookies = true
        var token = request; token.setValue("other-token", forHTTPHeaderField: "Authorization")
        var origin = request; origin.url = URL(string: "https://foreign.test/api/user/public-info")
        var path = request; path.url = value.baseURL.appendingPathComponent("api/user/info")
        var query = request; query.url = URL(string: request.url!.absoluteString + "?member_id=9")
        var body = request; body.httpBody = Data("member_id=8&owner_id=99".utf8)
        for forged in [cookies, token, origin, path, query, body] {
            XCTAssertFalse(ProfileFollowListTransportPolicy.accepts(forged, context: value, approval: approved))
        }
        for foreign in [try context(account: 99), try context(namespace: "foreign"),
                        try context(base: "https://foreign.test/follow-cookie")] {
            XCTAssertFalse(ProfileFollowListTransportPolicy.accepts(request, context: value, approval: try grant(foreign)))
        }
        XCTAssertFalse(ProfileFollowListTransportPolicy.accepts(request, context: try context(token: "other-token"), approval: approved))
    }
    func testOtherAccountReadsRetainOriginalCookieAndBodySemantics() async throws {
        let value = try context(), wire = Wire()
        wire.operation = { request in
            switch request.url?.lastPathComponent {
            case "infomation_detail": return (Data(#"{"code":200,"data":null}"#.utf8), 200)
            case "list": return (Data(#"{"code":200,"data":{"rows":[],"total":0}}"#.utf8), 200)
            default: return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
            }
        }
        let service = SocialAccountService(configuration: try APIConfiguration(baseURL: value.baseURL), transport: wire)
        _ = try await service.informationList()
        _ = try await service.information(id: 1)
        _ = try await service.invitations(page: 1, token: value.session.token)
        _ = try await service.rewards(token: value.session.token)
        XCTAssertEqual(wire.requests.count, 4)
        XCTAssertTrue(wire.requests.allSatisfy(\.httpShouldHandleCookies))
        let listBody = String(data: wire.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(listBody.contains("name=\"pageNum\"\r\n\r\n1\r\n"))
        XCTAssertTrue(listBody.contains("name=\"pageSize\"\r\n\r\n10\r\n"))
        XCTAssertNil(wire.requests[0].value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(wire.requests.dropFirst().allSatisfy { $0.httpBody != nil })
        XCTAssertTrue(wire.requests.suffix(2).allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == value.session.token })
    }
    func testActualListSelectionProfileAndReturnRebuildOnlyUseApprovedReads() async throws {
        let value = try context(), approved = try grant(value), wire = Wire(); var listReads = 0
        wire.operation = { request in
            XCTAssertTrue(ProfileFollowListTransportPolicy.accepts(request, context: value, approval: approved))
            if request.url?.lastPathComponent == "public-info" { return (Self.profile, 200) }
            XCTAssertEqual(request.httpMethod, "GET"); listReads += 1
            let rows = listReads == 1 ? #"{"id":8,"nickname":"Synthetic member","isFollow":true}"# : ""
            return (Data("{\"code\":200,\"data\":{\"owner_id\":7,\"kind\":\"following\",\"rows\":[\(rows)],\"has_more\":false,\"next_cursor\":null}}".utf8), 200)
        }
        let service = try ProfileFollowListService(context: value, approval: approved, transport: wire,
            current: { value }, currentApproval: { approved })
        let flow = ProfileFollowListFlow(reader: service); defer { flow.retire() }
        await flow.appear(foreground: true)?.value
        XCTAssertNil(flow.error)
        let selected = try XCTUnwrap(flow.open(try XCTUnwrap(flow.visibleRows.first)))
        let profile = try XCTUnwrap(flow.memberReader(for: selected)); flow.suspend(); profile.appear(foreground: true)
        let loaded = try await profile.publicProfile(memberID: 8); XCTAssertEqual(loaded.id, 8)
        do { _ = try await profile.publicProfile(memberID: 9); XCTFail("The selected target must stay exact") }
        catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        profile.disappear(); flow.close(selected.id); await flow.appear(foreground: true)?.value
        XCTAssertTrue(flow.hasLoaded); XCTAssertTrue(flow.visibleRows.isEmpty); XCTAssertNil(flow.error)
        XCTAssertFalse(profile.isCurrent); XCTAssertEqual(listReads, 2)
        XCTAssertEqual(wire.requests.map { $0.url?.lastPathComponent }, ["follow-list", "public-info", "follow-list"])
        XCTAssertTrue(wire.requests.allSatisfy { ProfileFollowListTransportPolicy.accepts($0, context: value, approval: approved) })
    }
    func testChangedOwnerEpochRoleTokenNamespaceOrOriginRejectsBeforeWireAndCannotRevive() async throws {
        let value = try context(), approved = try grant(value)
        let replacements: [RuntimeDependencyContext?] = [nil, try context(account: 99), try context(epoch: 2),
            try context(role: "merchant"), try context(token: "changed-token"), try context(namespace: "changed"),
            try context(base: "https://other.test/follow-cookie")]
        for replacement in replacements {
            let wire = Wire(); var current: RuntimeDependencyContext? = value
            let service = try ProfileFollowListService(context: value, approval: approved, transport: wire,
                current: { current }, currentApproval: { approved })
            let profile = try XCTUnwrap(service.makePublicProfileReader(memberID: 8, isCurrent: { true }))
            profile.appear(foreground: true); current = replacement
            do { _ = try await profile.publicProfile(memberID: 8); XCTFail() }
            catch { XCTAssertTrue(error is CancellationError) }
            XCTAssertTrue(wire.requests.isEmpty); current = value; XCTAssertFalse(profile.isCurrent)
            XCTAssertNil(service.makePublicProfileReader(memberID: 8, isCurrent: { true }))
        }
    }
    func testRevokedReplacedOrExpiredApprovalCannotDispatchSelectedProfile() async throws {
        let value = try context(), approved = try grant(value)
        let expired = try ProfileFollowListApproval(endpoint: approved.endpoint, expiresAt: .distantPast)
        let replacements: [ProfileFollowListApproval?] = [nil, try grant(value), expired]
        for replacement in replacements {
            let wire = Wire(); var current: ProfileFollowListApproval? = approved
            let service = try ProfileFollowListService(context: value, approval: approved, transport: wire,
                current: { value }, currentApproval: { current })
            let profile = try XCTUnwrap(service.makePublicProfileReader(memberID: 8, isCurrent: { true }))
            profile.appear(foreground: true); current = replacement
            do { _ = try await profile.publicProfile(memberID: 8); XCTFail() }
            catch { XCTAssertTrue(error is CancellationError) }
            XCTAssertTrue(wire.requests.isEmpty); current = approved; XCTAssertFalse(profile.isCurrent)
        }
    }
    func testLateProfileSuccessAnd401CannotCrossSelectionGrantOwnerOrVisibilityLifetime() async throws {
        for retirement in 0..<5 {
            for outcome in 0..<3 {
                let value = try context(), approved = try grant(value), wire = HeldWire()
                var current: RuntimeDependencyContext? = value, lease: ProfileFollowListApproval? = approved
                var selected = true, expired = 0
                defer { wire.drain() }
                let service = try ProfileFollowListService(context: value, approval: approved, transport: wire,
                    current: { current }, currentApproval: { lease }, onUnauthorized: { _ in expired += 1 })
                let profile = try XCTUnwrap(service.makePublicProfileReader(memberID: 8, isCurrent: { selected }))
                profile.appear(foreground: true)
                let read = Task { try await profile.publicProfile(memberID: 8) }
                try await wire.wait()
                XCTAssertTrue(ProfileFollowListTransportPolicy.accepts(try XCTUnwrap(wire.requests.first), context: value, approval: approved))
                switch retirement {
                case 0: selected = false
                case 1: lease = nil
                case 2: current = try context(epoch: 2)
                case 3: profile.setForeground(false)
                default: profile.disappear()
                }
                wire.finish(outcome)
                do { _ = try await read.value; XCTFail("Retired results must not reach the profile or expire its replacement") }
                catch { XCTAssertTrue(error is CancellationError) }
                XCTAssertEqual(expired, 0); XCTAssertEqual(wire.requests.count, 1)
                if retirement >= 3 {
                    profile.appear(foreground: true)
                    let fresh = Task { try await profile.publicProfile(memberID: 8) }
                    try await wire.wait(); wire.finish(0)
                    let loaded = try await fresh.value; XCTAssertEqual(loaded.id, 8)
                    XCTAssertEqual(wire.requests.count, 2)
                } else { XCTAssertFalse(profile.isCurrent) }
            }
        }
    }
    func testCurrentProfile401AndWrongResponseIdentityKeepOriginalFailureSemantics() async throws {
        let value = try context(), approved = try grant(value), wire = Wire(); var expired: RuntimeDependencyContext?
        let service = try ProfileFollowListService(context: value, approval: approved, transport: wire,
            current: { value }, currentApproval: { approved }, onUnauthorized: { expired = $0 })
        let profile = try XCTUnwrap(service.makePublicProfileReader(memberID: 8, isCurrent: { true }))
        profile.appear(foreground: true)
        wire.operation = { _ in (Data(#"{"code":401}"#.utf8), 401) }
        do { _ = try await profile.publicProfile(memberID: 8); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .unauthorized) }
        XCTAssertEqual(expired, value)
        wire.operation = { _ in (Data(#"{"code":200,"data":{"id":9,"nickname":"Other"}}"#.utf8), 200) }
        do { _ = try await profile.publicProfile(memberID: 8); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
        XCTAssertEqual(wire.requests.count, 2)
    }
}
