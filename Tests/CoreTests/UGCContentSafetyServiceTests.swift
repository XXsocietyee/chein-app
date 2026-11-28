import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Task 79. Exercises `UGCContentSafetyHTTPService` and `UGCBlockedUsersStore` as they exist on this tip.
/// There is no second safety service and no collection-filter API; feeds, chats, and comments share `isBlocked`.
private final class UGCRecordingTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var handler: (URLRequest) async throws -> (Data, Int)
    init(_ handler: @escaping (URLRequest) async throws -> (Data, Int)) { self.handler = handler }
    convenience init(_ payload: String, status: Int = 200) {
        self.init { _ in (Data(payload.utf8), status) }
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return try await handler(request)
    }
}

private final class UGCFakeSafety: UGCContentSafetyServing, @unchecked Sendable {
    var blockedIDs: [Int] = []
    var cursors: [Int64] = []
    var blockCalls: [Int] = []
    var unblockCalls: [Int] = []
    var blockError: Error?
    func fetchCapabilities(token: String) async throws -> UGCContentSafetyCapabilities {
        UGCContentSafetyCapabilities(
            policyVersion: UGCReportReasonOption.fallbackPolicyVersion,
            reasons: UGCReportReasonOption.fallbackTaxonomy
        )
    }
    func submitReport(
        target: UGCSafetyReportTarget,
        reason: UGCReportReasonOption,
        details: String,
        policyVersion: String,
        token: String
    ) async throws -> String? { nil }
    func blockUser(targetMemberID: Int, token: String) async throws {
        if let blockError { throw blockError }
        blockCalls.append(targetMemberID)
    }
    func unblockUser(targetMemberID: Int, token: String) async throws {
        unblockCalls.append(targetMemberID)
    }
    func fetchBlockedMemberIDs(cursor: Int64, token: String) async throws -> [Int] {
        cursors.append(cursor)
        return blockedIDs
    }
    func precheckContent(text: String, scene: String, token: String) async throws -> UGCPrecheckResult {
        UGCPrecheckResult(allowed: true, message: nil)
    }
}

@MainActor
final class UGCContentSafetyServiceTests: XCTestCase {
    private let token = "fixture-token"
    private let host = "8120.example.test"

    private func configuration() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://8120.example.test")!)
    }

    private func service(_ transport: UGCRecordingTransport) throws -> UGCContentSafetyHTTPService {
        UGCContentSafetyHTTPService(configuration: try configuration(), transport: transport)
    }

    private func reason(_ code: String = "HARASSMENT", _ label: String = "人身攻击或骚扰") -> UGCReportReasonOption {
        UGCReportReasonOption(code: code, label: label, priority: "STANDARD")
    }

    private func assertTestHost(_ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.url?.host, host, file: file, line: line)
        XCTAssertFalse(request.url?.absoluteString.contains("www.chengyinhub.com") ?? false, file: file, line: line)
    }

    private func formFields(_ request: URLRequest) -> [String: String] {
        let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
        let rows = body.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        var fields: [String: String] = [:]
        var index = 0
        while index < rows.count {
            let row = rows[index]
            if let range = row.range(of: "name=\"") {
                let name = String(row[range.upperBound...].prefix { $0 != "\"" })
                let valueIndex = index + 2
                if valueIndex < rows.count {
                    fields[name] = rows[valueIndex]
                }
            }
            index += 1
        }
        return fields
    }

    private func jsonObject(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return Int(exactly: number.int64Value) }
        return nil
    }

    private func defaults() throws -> (String, UserDefaults) {
        let name = "ugc-safety-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }

    private struct SurfaceRow: Equatable {
        var memberID: Int?
        var authorName: String?
    }

    private func visible(_ rows: [SurfaceRow], store: UGCBlockedUsersStore) -> [SurfaceRow] {
        rows.filter { store.isBlocked(memberID: $0.memberID, authorName: $0.authorName) == false }
    }

    func testFallbackReportReasonsMatchTheCommunityTaxonomy() {
        XCTAssertEqual(UGCReportReasonOption.fallbackPolicyVersion, "COMMUNITY_REPORT_POLICY_V1")
        let reasons = UGCReportReasonOption.fallbackTaxonomy
        XCTAssertEqual(reasons.map(\.code), [
            "DANGEROUS", "MINOR_SAFETY", "SELF_HARM", "SEXUAL_CONTENT", "HARASSMENT", "HATE",
            "FRAUD", "IMPERSONATION", "FALSE_INFORMATION", "SPAM", "PRIVACY", "INTELLECTUAL_PROPERTY", "OTHER"
        ])
        XCTAssertEqual(reasons.map(\.label), [
            "现实人身危险或违法行为", "未成年人安全", "自伤或自杀风险", "色情低俗内容", "人身攻击或骚扰",
            "仇恨或歧视", "诈骗", "冒充他人", "虚假信息", "垃圾广告或站外导流", "隐私泄露", "知识产权或内容盗用", "其他"
        ])
        XCTAssertEqual(reasons.prefix(3).map { $0.priority ?? "" }, ["URGENT", "URGENT", "URGENT"])
        XCTAssertEqual(reasons.prefix(3).map(\.isEmergency), [true, true, true])
        XCTAssertTrue(reasons.dropFirst(3).allSatisfy { $0.priority == "STANDARD" && $0.isEmergency == false })
        XCTAssertEqual(reasons[4].id, "HARASSMENT::人身攻击或骚扰")
        XCTAssertEqual(UGCCommunityTargetType.content.rawValue, "CONTENT")
        XCTAssertEqual(UGCCommunityTargetType.safetyRating.rawValue, "SAFETY_RATING")
    }

    func testReportTargetRoutesStayOnTheExistingPaths() {
        XCTAssertEqual(UGCSafetyReportTarget.topic(id: 1).routePath, "api/topic/report")
        XCTAssertEqual(UGCSafetyReportTarget.template(id: 1).routePath, "api/template/report")
        XCTAssertEqual(UGCSafetyReportTarget.template(id: 1, personal: true).routePath, "api/template/personal-report")
        XCTAssertEqual(UGCSafetyReportTarget.creativeSquarePost(id: 1).routePath, "api/creativesquare/report")
        XCTAssertEqual(UGCSafetyReportTarget.comment(id: 1).routePath, "api/comment/report")
        XCTAssertEqual(UGCSafetyReportTarget.clubPost(clubID: 2, postID: 3).routePath, "api/club/post/report")
        XCTAssertEqual(UGCSafetyReportTarget.clubPostComment(commentID: 4).routePath, "api/club/post/comment/report")
        XCTAssertEqual(UGCSafetyReportTarget.community(targetType: .content, targetID: 5).routePath, "api/v1/community/reports")
        XCTAssertEqual(UGCSafetyReportTarget.community(targetType: .comment, targetID: 5).routePath, "api/v1/community/reports")
        XCTAssertEqual(UGCSafetyReportTarget.community(targetType: .club, targetID: 5).routePath, "api/community-trust/reports/submit")
        XCTAssertEqual(UGCSafetyReportTarget.member(memberID: 6).routePath, "api/community-trust/reports/submit")
        XCTAssertEqual(UGCSafetyReportTarget.activity(activityID: 7).routePath, "api/community-trust/reports/submit")
        XCTAssertEqual(UGCSafetyReportTarget.team(teamID: 8).routePath, "api/team/report")
        XCTAssertEqual(UGCSafetyReportTarget.mod(modID: 9).routePath, "api/mod-owned-report")
    }

    func testCapabilitiesReadServerReasonsAndANumericZeroCodeStaysRejected() async throws {
        let payload = """
        {"code":200,"data":{"reporting":{"policyVersion":"SERVER_POLICY","reasons":[
          {"code":"SPAM","label":" 垃圾广告或站外导流 ","priority":"STANDARD"},
          {"code":"","label":"其他","priority":"STANDARD","emergency":false},
          {"label":"人身攻击或骚扰","priority":"URGENT"},
          {"code":"HATE","label":"仇恨或歧视","priority":"URGENT","emergency":false},
          {"code":"SKIP","label":"   ","priority":"STANDARD"},
          {"code":"SKIP2","priority":"STANDARD"}
        ]}}}
        """
        let transport = UGCRecordingTransport(payload)
        let loaded = try await service(transport).fetchCapabilities(token: token)
        let request = try XCTUnwrap(transport.requests.first)
        assertTestHost(request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/v1/community/capabilities")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), token)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.httpShouldHandleCookies, false)
        XCTAssertEqual(loaded.policyVersion, "SERVER_POLICY")
        XCTAssertEqual(loaded.reasons.map(\.label), ["垃圾广告或站外导流", "其他", "人身攻击或骚扰", "仇恨或歧视"])
        XCTAssertEqual(loaded.reasons.map(\.code), ["SPAM", "其他", "人身攻击或骚扰", "HATE"])
        XCTAssertEqual(loaded.reasons.map(\.isEmergency), [false, false, true, false])
        XCTAssertEqual(loaded.reasons.count, 4, "a non-empty server list does not append the fallback taxonomy")

        let anonymous = UGCRecordingTransport(#"{"reporting":{"reasons":[{"code":"OTHER","label":"其他"}]}}"#)
        let offline = try await service(anonymous).fetchCapabilities(token: " ")
        XCTAssertNil(anonymous.requests.first?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(offline.policyVersion, UGCReportReasonOption.fallbackPolicyVersion)
        XCTAssertEqual(offline.reasons.map(\.code), ["OTHER"])

        let empty = UGCRecordingTransport(#"{"code":200,"data":{"reporting":{"policyVersion":"EMPTY","reasons":[]}}}"#)
        let fellBack = try await service(empty).fetchCapabilities(token: token)
        XCTAssertEqual(fellBack.policyVersion, "EMPTY")
        XCTAssertEqual(fellBack.reasons, UGCReportReasonOption.fallbackTaxonomy)

        let zero = UGCRecordingTransport(#"{"code":0,"msg":"closed"}"#)
        do {
            _ = try await service(zero).fetchCapabilities(token: token)
            XCTFail("code 0 is not success")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .serverRejected("closed"))
        }
        let broken = UGCRecordingTransport("[]", status: 200)
        do {
            _ = try await service(broken).fetchCapabilities(token: token)
            XCTFail("a non-object body is invalid")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testFormReportsSendTheLabelAndCommunityReportsSendTheDetailText() async throws {
        let formTargets: [(UGCSafetyReportTarget, String, String)] = [
            (.topic(id: 11), "api/topic/report", "11"),
            (.template(id: 12), "api/template/report", "12"),
            (.template(id: 13, personal: true), "api/template/personal-report", "13"),
            (.creativeSquarePost(id: 14), "api/creativesquare/report", "14"),
            (.comment(id: 15), "api/comment/report", "15"),
            (.clubPostComment(commentID: 16), "api/club/post/comment/report", "16"),
            (.team(teamID: 17), "api/team/report", "17")
        ]
        let transport = UGCRecordingTransport(#"{"code":200,"msg":"已收到"}"#)
        let api = try service(transport)
        for (target, path, id) in formTargets {
            let message = try await api.submitReport(
                target: target, reason: reason(), details: "补充", policyVersion: "POLICY-9", token: token
            )
            XCTAssertEqual(message, "已收到")
            let request = try XCTUnwrap(transport.requests.last)
            assertTestHost(request)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/" + path)
            let fields = formFields(request)
            XCTAssertEqual(fields["id"], id)
            XCTAssertEqual(fields["reason"], "人身攻击或骚扰")
            XCTAssertNil(fields["补充"])
            XCTAssertFalse(fields.values.contains { $0.contains("补充") })
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), token)
        }

        let club = try await api.submitReport(
            target: .clubPost(clubID: 3, postID: 18),
            reason: reason(),
            details: "补充",
            policyVersion: "POLICY-9",
            token: token
        )
        XCTAssertEqual(club, "已收到")
        XCTAssertEqual(formFields(try XCTUnwrap(transport.requests.last)), [
            "club_id": "3", "id": "18", "reason": "人身攻击或骚扰"
        ])
        _ = try await api.submitReport(
            target: .clubPost(clubID: 0, postID: 19),
            reason: reason(),
            details: "",
            policyVersion: "POLICY-9",
            token: token
        )
        let omittedClub = formFields(try XCTUnwrap(transport.requests.last))
        XCTAssertNil(omittedClub["club_id"])
        XCTAssertEqual(omittedClub["id"], "19")

        let longDetails = String(repeating: "字", count: 600)
        let communityTypes: [(UGCSafetyReportTarget, String, Int)] = [
            (.community(targetType: .content, targetID: 21), "CONTENT", 21),
            (.community(targetType: .merchant, targetID: 22), "MERCHANT", 22),
            (.community(targetType: .comment, targetID: 23), "COMMENT", 23),
            (.community(targetType: .safetyRating, targetID: 24), "SAFETY_RATING", 24),
            (.member(memberID: 25), "MEMBER", 25),
            (.activity(activityID: 26), "ACTIVITY", 26)
        ]
        for (target, targetType, targetID) in communityTypes {
            _ = try await api.submitReport(
                target: target, reason: reason("OTHER", "其他"), details: longDetails, policyVersion: "", token: token
            )
            let body = try jsonObject(try XCTUnwrap(transport.requests.last))
            XCTAssertEqual(body["targetType"] as? String, targetType)
            XCTAssertEqual(body["reasonCode"] as? String, "OTHER")
            XCTAssertEqual(body["policyVersion"] as? String, UGCReportReasonOption.fallbackPolicyVersion)
            let description = try XCTUnwrap(body["description"] as? String)
            XCTAssertEqual(description.count, 500)
            XCTAssertTrue(description.hasPrefix("其他 - 字"))
            let evidence = try XCTUnwrap(body["evidenceAssetIds"] as? [Any])
            XCTAssertTrue(evidence.isEmpty)
            let requestID = try XCTUnwrap(body["requestId"] as? String)
            XCTAssertEqual(requestID, requestID.lowercased())
            let postReport = targetType == "CONTENT" || targetType == "COMMENT"
            XCTAssertEqual(transport.requests.last?.url?.path, postReport ? "/api/v1/community/reports" : "/api/community-trust/reports/submit")
            XCTAssertEqual(intValue(body["targetId"]), Optional(targetID))
        }

        _ = try await api.submitReport(
            target: .mod(modID: 27), reason: reason(), details: "补充", policyVersion: "POLICY-9", token: token
        )
        let modBody = try jsonObject(try XCTUnwrap(transport.requests.last))
        XCTAssertEqual(intValue(modBody["mod_id"]), Optional(27))
        XCTAssertEqual(intValue(modBody["id"]), Optional(27))
        XCTAssertEqual(modBody["reason"] as? String, "人身攻击或骚扰 - 补充")
        XCTAssertEqual(transport.requests.last?.url?.path, "/api/mod-owned-report")
        XCTAssertNil(modBody["policyVersion"])
    }

    func testReportRejectsASignedOutCallerAnEmptyReasonAndAZeroIdentifier() async throws {
        let transport = UGCRecordingTransport(#"{"code":0,"msg":"no"}"#)
        let api = try service(transport)
        let picked = reason()
        do {
            _ = try await api.submitReport(target: .topic(id: 1), reason: picked, details: "", policyVersion: "POLICY-9", token: " ")
            XCTFail("blank token")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .signedOut)
        }
        do {
            _ = try await api.submitReport(
                target: .topic(id: 1),
                reason: UGCReportReasonOption(code: "OTHER", label: "  "),
                details: "x",
                policyVersion: "POLICY-9",
                token: token
            )
            XCTFail("blank label")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .invalidTarget)
        }
        let invalid: [UGCSafetyReportTarget] = [
            .topic(id: 0), .template(id: 0), .template(id: -1, personal: true), .creativeSquarePost(id: 0),
            .comment(id: 0), .clubPostComment(commentID: 0), .clubPost(clubID: 1, postID: 0),
            .community(targetType: .content, targetID: 0), .member(memberID: 0), .activity(activityID: 0),
            .team(teamID: 0), .mod(modID: 0)
        ]
        for target in invalid {
            do {
                _ = try await api.submitReport(target: target, reason: picked, details: "", policyVersion: "POLICY-9", token: token)
                XCTFail("identifier 0")
            } catch let error as UGCContentSafetyError {
                XCTAssertEqual(error, .invalidTarget)
            }
        }
        XCTAssertTrue(transport.requests.isEmpty)

        let accepted = UGCRecordingTransport(#"{"code":"200","message":"ok"}"#)
        let message = try await service(accepted).submitReport(
            target: .comment(id: 4), reason: picked, details: "", policyVersion: "POLICY-9", token: token
        )
        XCTAssertEqual(message, "ok")

        do {
            _ = try await service(transport).submitReport(
                target: .comment(id: 4), reason: picked, details: "", policyVersion: "POLICY-9", token: token
            )
            XCTFail("numeric code 0 stays rejected")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .serverRejected("no"))
        }
        let missing = UGCRecordingTransport(#"{"code":200}"#)
        let quiet = try await service(missing).submitReport(
            target: .comment(id: 4), reason: picked, details: "", policyVersion: "POLICY-9", token: token
        )
        XCTAssertNil(quiet)
    }

    func testBlockListKeepsCursorZeroAndDropsADecodedZeroMember() async throws {
        let transport = UGCRecordingTransport { request in
            let cursor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "cursor" }?.value
            if cursor == "0" {
                let payload = """
                {"code":200,"data":{"items":[
                  {"blockedMemberId":0,"memberId":7},
                  {"blocked_member_id":42},
                  {"targetMemberId":0},
                  {"member_id":-3},
                  {"nickname":"skip"}
                ]}}
                """
                return (Data(payload.utf8), 200)
            }
            let payload = """
            {"code":200,"data":{"records":[{"target_member_id":8}],"rows":[{"memberId":9}],"list":[{"blockedMemberId":10}]}}
            """
            return (Data(payload.utf8), 200)
        }
        let api = try service(transport)
        let page = try await api.fetchBlockedMemberIDs(cursor: 0, token: token)
        XCTAssertEqual(page, [42])
        let request = try XCTUnwrap(transport.requests.first)
        assertTestHost(request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/native/blacklist/list")
        XCTAssertEqual(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "cursor", value: "0")]
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), token)

        let second = try await api.fetchBlockedMemberIDs(cursor: 2, token: token)
        XCTAssertEqual(second, [8], "records wins over rows and list")

        let rooted = UGCRecordingTransport(#"{"code":200,"items":[{"memberId":11}]}"#)
        let awaited = try await service(rooted).fetchBlockedMemberIDs(cursor: 0, token: token)
        XCTAssertEqual(awaited, [11])

        let zero = UGCRecordingTransport(#"{"code":0,"msg":"closed"}"#)
        do {
            _ = try await service(zero).fetchBlockedMemberIDs(cursor: 0, token: token)
            XCTFail("code 0")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .serverRejected("closed"))
        }
        do {
            _ = try await api.fetchBlockedMemberIDs(cursor: 0, token: "")
            XCTFail("signed out")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .signedOut)
        }

        let block = UGCRecordingTransport(#"{"code":200}"#)
        let blocking = try service(block)
        try await blocking.blockUser(targetMemberID: 42, token: token)
        try await blocking.unblockUser(targetMemberID: 42, token: token)
        XCTAssertEqual(block.requests.map { $0.url?.path ?? "" }, ["/api/im/block", "/api/im/unblock"])
        XCTAssertEqual(block.requests.map { formFields($0) }, [["target_member_id": "42"], ["target_member_id": "42"]])
        for request in block.requests {
            assertTestHost(request)
            XCTAssertEqual(request.httpMethod, "POST")
        }
        do {
            try await blocking.blockUser(targetMemberID: 0, token: token)
            XCTFail("member 0")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .invalidTarget)
        }
        do {
            try await blocking.unblockUser(targetMemberID: 42, token: "bad\ntoken")
            XCTFail("token")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .signedOut)
        }
    }

    func testBlockedAuthorsDropOutOfFeedsChatsAndComments() async throws {
        let (name, storeDefaults) = try defaults()
        defer { storeDefaults.removePersistentDomain(forName: name) }
        let store = UGCBlockedUsersStore(defaults: storeDefaults)
        store.configureScope(accountID: 7, realm: " https://8120.example.test ")
        let fake = UGCFakeSafety()
        fake.blockedIDs = [0, 42]
        let channel = InMemoryChannelBlockedUsersStore()
        try await store.block(memberID: 42, authorName: " Spammer ", clubID: 9, channelStore: channel, token: token, service: fake)
        store.recordLocalBlock(memberID: 0, authorName: "   ")
        XCTAssertEqual(fake.blockCalls, [42])
        XCTAssertEqual(fake.cursors, [])
        XCTAssertEqual(channel.blockedUserIDs(clubID: 9, viewerMemberID: 7), Set([42]))
        XCTAssertFalse(store.blockedMemberIDs.contains(0))
        XCTAssertTrue(store.blockedAuthorNames.contains("spammer"))

        let feed = [
            SurfaceRow(memberID: 42, authorName: "A"),
            SurfaceRow(memberID: 7, authorName: "B"),
            SurfaceRow(memberID: nil, authorName: "spammer"),
            SurfaceRow(memberID: 0, authorName: "C")
        ]
        let chats = [
            SurfaceRow(memberID: 42, authorName: nil),
            SurfaceRow(memberID: 8, authorName: nil),
            SurfaceRow(memberID: nil, authorName: "  SPAMMER ")
        ]
        let comments = [
            SurfaceRow(memberID: 9, authorName: "ok"),
            SurfaceRow(memberID: 3, authorName: "Spammer"),
            SurfaceRow(memberID: 42, authorName: "other")
        ]
        XCTAssertEqual(visible(feed, store: store), [
            SurfaceRow(memberID: 7, authorName: "B"),
            SurfaceRow(memberID: 0, authorName: "C")
        ])
        XCTAssertEqual(visible(chats, store: store), [SurfaceRow(memberID: 8, authorName: nil)])
        XCTAssertEqual(visible(comments, store: store), [SurfaceRow(memberID: 9, authorName: "ok")])
        XCTAssertFalse(store.isBlocked(memberID: 0, authorName: nil))
        XCTAssertFalse(store.isBlocked(memberID: nil, authorName: "   "))

        await store.syncFromServerIfNeeded(accountID: 7, realm: "https://8120.example.test", token: token, service: fake)
        XCTAssertEqual(fake.cursors, [0])
        XCTAssertTrue(store.blockedMemberIDs.contains(42))
        XCTAssertTrue(store.blockedMemberIDs.contains(0), "the store unions the service list and does not rewrite a returned 0")
        XCTAssertFalse(store.isBlocked(memberID: 0))
        await store.syncFromServerIfNeeded(accountID: 7, realm: "https://8120.example.test", token: token, service: fake)
        XCTAssertEqual(fake.cursors, [0], "one server sync per account scope")

        let reloaded = UGCBlockedUsersStore(defaults: storeDefaults)
        reloaded.configureScope(accountID: 7, realm: "https://8120.example.test")
        XCTAssertTrue(reloaded.isBlocked(memberID: 42, authorName: nil))
        XCTAssertTrue(reloaded.isBlocked(memberID: nil, authorName: "SPAMMER"))
        reloaded.configureScope(accountID: 8, realm: "https://8120.example.test")
        XCTAssertFalse(reloaded.isBlocked(memberID: 42, authorName: "spammer"))

        fake.blockError = UGCContentSafetyError.serverRejected("no")
        do {
            try await store.block(memberID: 99, authorName: "Next", token: token, service: fake)
            XCTFail("failed block")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .serverRejected("no"))
        }
        XCTAssertFalse(store.isBlocked(memberID: 99, authorName: "Next"))

        try await store.unblock(memberID: 42, authorName: "Spammer", clubID: 9, channelStore: channel, token: token, service: fake)
        XCTAssertEqual(fake.unblockCalls, [42])
        XCTAssertTrue(channel.blockedUserIDs(clubID: 9, viewerMemberID: 7).isEmpty)
        XCTAssertEqual(visible(feed, store: store), feed)
        XCTAssertEqual(visible(chats, store: store), chats)
        XCTAssertEqual(visible(comments, store: store), comments)

        do {
            try await store.block(memberID: 5, authorName: nil, token: nil, service: fake)
            XCTFail("missing token")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .signedOut)
        }
        try await store.block(memberID: nil, authorName: "Only Name", token: nil, service: nil)
        XCTAssertTrue(store.isBlocked(memberID: nil, authorName: "only name"))
        XCTAssertEqual(fake.blockCalls, [42])
    }

    func testPrecheckPassesBlankTextAndReadsTheModerationFlags() async throws {
        let idle = UGCRecordingTransport(#"{"code":0}"#)
        let blank = try await service(idle).precheckContent(text: " \n\t ", scene: "feed", token: "")
        XCTAssertEqual(blank, UGCPrecheckResult(allowed: true, message: nil))
        XCTAssertTrue(idle.requests.isEmpty)
        XCTAssertNil(blank.message)

        do {
            _ = try await service(idle).precheckContent(text: "hello", scene: "feed", token: "bad\ntoken")
            XCTFail("signed out")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .signedOut)
        }
        XCTAssertTrue(idle.requests.isEmpty)

        let blocked = UGCRecordingTransport(#"{"code":200,"msg":"from-msg","data":{"allowed":false,"reason":"blocked"}}"#)
        let decision = try await service(blocked).precheckContent(text: "  hello  ", scene: "comment", token: token)
        XCTAssertEqual(decision, UGCPrecheckResult(allowed: false, message: "blocked"))
        let request = try XCTUnwrap(blocked.requests.first)
        assertTestHost(request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/ai/safety/precheck")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), token)
        let body = try jsonObject(request)
        // fix/1128c-ai-showcase (H-08b, deliberate): the wire is the backend AiSafetyPrecheckReq, not {content, scene}.
        XCTAssertEqual(Set(body.keys), ["title", "subtitle", "description", "nodes"])
        XCTAssertEqual(body["description"] as? String, "hello")
        XCTAssertEqual((body["nodes"] as? [Any])?.count, 0)
        XCTAssertNil(body["scene"])

        let passFlag = UGCRecordingTransport(#"{"code":200,"data":{"pass":false,"reason":""}}"#)
        let passed = try await service(passFlag).precheckContent(text: "x", scene: "chat", token: token)
        XCTAssertEqual(passed.allowed, false)
        XCTAssertEqual(passed.message, "")

        let allowedWins = UGCRecordingTransport(#"{"code":0,"data":{"allowed":true,"pass":false}}"#)
        let allowed = try await service(allowedWins).precheckContent(text: "x", scene: "", token: token)
        XCTAssertEqual(allowed, UGCPrecheckResult(allowed: true, message: nil))
        XCTAssertEqual(try jsonObject(try XCTUnwrap(allowedWins.requests.first))["description"] as? String, "x")

        let numericZero = UGCRecordingTransport(#"{"code":0,"msg":"held"}"#)
        let held = try await service(numericZero).precheckContent(text: "x", scene: "feed", token: token)
        XCTAssertEqual(held, UGCPrecheckResult(allowed: false, message: "held"))

        let open = UGCRecordingTransport(#"{"msg":""}"#)
        let openResult = try await service(open).precheckContent(text: "x", scene: "feed", token: token)
        XCTAssertEqual(openResult, UGCPrecheckResult(allowed: true, message: nil))

        let failed = UGCRecordingTransport(#"{"code":500,"msg":"down"}"#, status: 503)
        do {
            _ = try await service(failed).precheckContent(text: "x", scene: "feed", token: token)
            XCTFail("http status")
        } catch let error as UGCContentSafetyError {
            XCTAssertEqual(error, .serverRejected("down"))
        }
    }
}
