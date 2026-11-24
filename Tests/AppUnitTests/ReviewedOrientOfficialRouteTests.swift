import XCTest
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

/// Finding 2: the orient / official / preset-route / host-cancel / team-report requests built by the Core access
/// types are admitted by the reviewed composition by exact route, and stay refused when unconfigured.
@MainActor
final class ReviewedOrientOfficialRouteTests: XCTestCase {
    private static let base = "https://api.example.com"

    private final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{"paidPlayers":2,"requestId":"","routes":[],"blockers":[]}}"#.utf8), 200)
        }
    }

    private let viewer = CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: 7, role: "player", token: "synthetic-7", viewerRevision: 1)

    private func composition(gates: Bool, wire: Wire) throws -> AppCompositionRoot {
        let suite = "orient-official-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "orient-" + UUID().uuidString.lowercased())
        let deployment = try ReviewedAppDeployment(market: .china, baseURL: Self.base, approvedBaseURLs: [.china: [Self.base]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: "com.questify.ios", realm: build.realm!,
            reads: [], productionGatesEnabled: gates)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }
    private func unconfigured(wire: Wire) throws -> AppCompositionRoot {
        let suite = "orient-unconf-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: nil,
            build: .init(market: "CN", baseURL: Self.base, bundleIdentifier: "com.questify.ios", realm: "orient-unconf"),
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }

    /// Every request the Core access types can build for the reviewed routes.
    private func drive(_ transport: CompositionHTTPTransport) async -> [(String, Result<Void, Error>)] {
        let api = try! APIConfiguration(baseURL: URL(string: Self.base)!)
        let session: @MainActor () -> (accountID: Int, token: String)? = { (7, "synthetic-7") }
        let cancel = ActivityHostCancelHTTPAccess(configuration: api, transport: transport, enabled: { true }, session: session)
        let merchantCancel = ActivityHostCancelHTTPAccess(configuration: api, transport: transport, enabled: { true }, session: session)
        merchantCancel.operationScope = .merchant
        let orient = TeamOrientBoardHTTPAccess(configuration: api, transport: transport, session: session)
        let official = OfficialOrganizerHTTPAccess(configuration: api, transport: transport, enabled: { true }, session: session)
        let roam = RoamService(configuration: api, transport: transport)
        let requestID = String(repeating: "ab", count: 16)
        func run(_ name: String, _ body: () async throws -> Void) async -> (String, Result<Void, Error>) {
            do { try await body(); return (name, .success(())) } catch { return (name, .failure(error)) }
        }
        var out: [(String, Result<Void, Error>)] = []
        out.append(await run("api/activity/cancel_preview") { _ = try await cancel.preview(activityID: 5) })
        out.append(await run("api/activity/cancel_preview+scope") { _ = try await merchantCancel.preview(activityID: 5) })
        out.append(await run("api/activity/cancel") { _ = try await cancel.cancel(activityID: 5, reason: "weather") })
        out.append(await run("api/orient/team/detail") { _ = try await orient.loadBoard(teamID: 3) })
        out.append(await run("api/orient/team/ranking") { _ = try await orient.loadRanking(ownerType: 2, ownerID: 9) })
        out.append(await run("api/team/report") { try await orient.reportTeam(teamID: 3, reason: "spam") })
        out.append(await run("api/official/v2/events/4/publish-check") { _ = try await official.publishCheck(eventID: 4) })
        out.append(await run("api/official/command") {
            _ = try await official.command(.init(eventID: 4, action: .schedule, requestId: requestID, fields: ["title": "t"]), mode: .submit)
        })
        out.append(await run("api/official/command/query") {
            _ = try await official.command(.init(eventID: 4, action: .schedule, requestId: requestID, fields: [:]), mode: .query)
        })
        out.append(await run("api/official/command/cancel") {
            _ = try await official.command(.init(eventID: 4, action: .pause, requestId: requestID, fields: [:]), mode: .cancel)
        })
        out.append(await run("api/preset/route/list") { _ = try await roam.officialRoutes(token: "synthetic-7") })
        out.append(await run("api/preset/route/info") { _ = try await roam.officialRoute(id: "12", token: "synthetic-7") })
        return out
    }

    func testUnconfiguredCompositionStillRefusesEveryRoute() async throws {
        let wire = Wire()
        let transport = try unconfigured(wire: wire).transport()
        transport.current = { self.viewer }
        let results = await drive(transport)
        XCTAssertEqual(results.count, 12)
        XCTAssertTrue(wire.requests.isEmpty, "unconfigured composition must not send anything")
    }

    func testReviewedCompositionAllowsExactlyThoseRoutes() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .hostCancelRefund }
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { self.viewer }
        let results = await drive(transport)
        let sentPaths = Set(wire.requests.compactMap { $0.url?.path })
        for (name, _) in results {
            let path = "/" + (name.components(separatedBy: "+").first ?? name)
            XCTAssertTrue(sentPaths.contains(path), "reviewed composition must admit \(name)")
        }
        XCTAssertEqual(wire.requests.count, 12)
    }

    func testWritesAreRefusedWhenProductionGatesAreOffButReadsStillWork() async throws {
        let wire = Wire()
        let transport = try composition(gates: false, wire: wire).transport()
        transport.current = { self.viewer }
        _ = await drive(transport)
        let methods = Dictionary(grouping: wire.requests, by: { $0.httpMethod ?? "" })
        XCTAssertNil(methods["POST"], "no POST may pass with productionGatesEnabled == false")
        XCTAssertEqual(Set(wire.requests.compactMap { $0.url?.path }),
                       ["/api/orient/team/detail", "/api/orient/team/ranking", "/api/official/v2/events/4/publish-check",
                        "/api/preset/route/list", "/api/preset/route/info"])
    }

    func testSignedOutViewerIsRefused() async throws {
        let wire = Wire()
        let transport = try composition(gates: true, wire: wire).transport()
        transport.current = { CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil, viewerRevision: 1) }
        _ = await drive(transport)
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testNearbyButDifferentRequestsAreRefused() throws {
        let base = URL(string: Self.base)!
        let token = "synthetic-7"
        func get(_ path: String, query: String? = nil) -> URLRequest {
            var r = URLRequest(url: URL(string: Self.base + "/" + path + (query.map { "?" + $0 } ?? ""))!)
            r.httpMethod = "GET"; r.setValue(token, forHTTPHeaderField: "Authorization"); r.setValue("application/json", forHTTPHeaderField: "Accept")
            return r
        }
        func post(_ path: String, _ body: String, host: String = Self.base) -> URLRequest {
            var r = URLRequest(url: URL(string: host + "/" + path)!)
            r.httpMethod = "POST"; r.httpBody = Data(body.utf8)
            r.setValue(token, forHTTPHeaderField: "Authorization"); r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return r
        }
        func kind(_ r: URLRequest) -> ReviewedOrientOfficialRoute.Kind? { ReviewedOrientOfficialRoute.kind(r, baseURL: base, token: token) }

        // accepted
        XCTAssertEqual(kind(get("api/orient/team/detail", query: "teamId=3")), .read)
        XCTAssertEqual(kind(get("api/orient/team/ranking", query: "ownerType=2&ownerId=9")), .read)
        XCTAssertEqual(kind(get("api/preset/route/info", query: "id=12")), .read)
        XCTAssertEqual(kind(post("api/activity/cancel_preview", #"{"id":5}"#)), .write)
        XCTAssertEqual(kind(post("api/activity/cancel", #"{"id":5,"reason":"weather"}"#)), .write)
        // refused: other paths, extra/missing query, bad ids, extra body keys, wrong methods, other hosts
        XCTAssertNil(kind(get("api/orient/team/other", query: "teamId=3")))
        XCTAssertNil(kind(get("api/orient/team/detail")))
        XCTAssertNil(kind(get("api/orient/team/detail", query: "teamId=3&x=1")))
        XCTAssertNil(kind(get("api/orient/team/detail", query: "teamId=0")))
        XCTAssertNil(kind(get("api/orient/team/ranking", query: "ownerId=9&ownerType=2")))
        XCTAssertNil(kind(get("api/preset/route/info", query: "id=abc")))
        XCTAssertNil(kind(get("api/preset/route/list", query: "x=1")))
        XCTAssertNil(kind(get("api/official/v2/events/0/publish-check")))
        XCTAssertNil(kind(get("api/official/v2/events/4/other")))
        XCTAssertNil(kind(get("api/official/events/4")), "the public official read keeps its own gate")
        XCTAssertNil(kind(post("api/activity/cancel_preview", #"{"id":5,"x":1}"#)))
        XCTAssertNil(kind(post("api/activity/cancel_preview", #"{"id":5,"scope":"OTHER"}"#)))
        XCTAssertNil(kind(post("api/activity/cancel", #"{"id":5}"#)))
        XCTAssertNil(kind(post("api/activity/cancel", #"{"id":5,"reason":" padded "}"#)))
        XCTAssertNil(kind(post("api/activity/cancel", #"{"reason":"weather","id":5}"#)), "non-canonical key order")
        XCTAssertNil(kind(post("api/team/report", #"{"reason":"x","teamId":-1}"#)))
        XCTAssertNil(kind(post("api/official/command/query", #"{"requestId":"short"}"#)))
        XCTAssertNil(kind(post("api/official/command", #"{"action":"delete","requestId":"abababababababababababababababab","targetId":"4"}"#)))
        XCTAssertNil(kind(post("api/official/delete", #"{"id":1}"#)))
        XCTAssertNil(kind(post("api/activity/cancel_preview", #"{"id":5}"#, host: "https://evil.example.org")))
        var wrongMethod = get("api/orient/team/detail", query: "teamId=3"); wrongMethod.httpMethod = "PUT"
        XCTAssertNil(kind(wrongMethod))
        var noAccept = get("api/orient/team/detail", query: "teamId=3"); noAccept.setValue(nil, forHTTPHeaderField: "Accept")
        XCTAssertNil(kind(noAccept))
        var otherToken = get("api/orient/team/detail", query: "teamId=3"); otherToken.setValue("other-token", forHTTPHeaderField: "Authorization")
        XCTAssertNil(kind(otherToken))
    }
}

/// Finding 4: Chinese-only strings now have English.
@MainActor
final class Finding4LocalizationTests: XCTestCase {
    private let en = CoreLoopCopy(locale: Locale(identifier: "en"))
    private let zh = CoreLoopCopy(locale: Locale(identifier: "zh-Hans"))

    func testCoreFixedStringsHaveEnglishAndChineseIsUnchanged() {
        let strings = ["当前场次暂无定向任务", "全队已完成 3 / 5 个节点", "未支付订单无需退款", "已核销报名不可退款", "已过退款截止时间",
                       "可全额退款,原路退回", "场次已开始，不可取消报名", "可取消报名并释放名额"]
        for s in strings {
            XCTAssertNotEqual(en.tr(s), s, "missing English for \(s)")
            XCTAssertNil(en.tr(s).range(of: "[\\u4e00-\\u9fff]", options: .regularExpression), "still Chinese: \(en.tr(s))")
            XCTAssertEqual(zh.tr(s), s)
        }
        XCTAssertEqual(en.tr("全队已完成 3 / 5 个节点"), "Team completed 3 / 5 nodes")
        let detail = TeamOrientBoardDetail(tasks: [], members: [], completedCount: 0)
        XCTAssertNotEqual(en.tr(detail.summaryText), detail.summaryText)
        XCTAssertEqual(MoneyRefundPolicy.evaluate(ownerType: nil, paymentStatus: 1, verificationStatus: nil, ticketMode: nil,
            ticketStartMs: nil, ticketEndMs: nil, activityStartMs: nil, snapshotDeadlineMs: nil, payableMinor: nil, pointUsed: nil, nowMs: nil).reason, "未支付订单无需退款")
    }

    func testAssetPointsLedgerEnglishTextsAndPinnedChineseTexts() {
        let raw = Data(#"[{"id":501,"registrationNo":"ORD-501","pointUsed":200,"pointsReturned":200},{"id":502,"registrationNo":"ORD-502","pointUsed":150},{"id":503,"registrationNo":"ORD-503","pointUsed":100,"pointsReturned":10}]"#.utf8)
        let orders = try! JSONDecoder().decode([ProfileOrder].self, from: raw)
        let snapshot = AssetPointsAndOrderCancellationSnapshot(ownerScope: "s", authoritativeBalancePoints: 600, orders: orders)
        for row in snapshot.rows {
            XCTAssertNil(row.deltaSummary(english: true).range(of: "[\\u4e00-\\u9fff]", options: .regularExpression))
            XCTAssertNil(row.noteText(english: true).range(of: "[\\u4e00-\\u9fff]", options: .regularExpression), row.noteText(english: true))
            XCTAssertEqual(row.noteText(english: false), row.note)
            XCTAssertEqual(row.deltaSummary(english: false), row.deltaSummaryText)
        }
        XCTAssertNil(snapshot.balanceDisplay(english: true).range(of: "[\\u4e00-\\u9fff]", options: .regularExpression))
        XCTAssertNil(snapshot.summary(english: true).range(of: "[\\u4e00-\\u9fff]", options: .regularExpression))
        XCTAssertEqual(snapshot.summary(english: false), snapshot.summaryText)
        XCTAssertNil(AssetPointsAndOrderCancellationSnapshot.empty.balanceDisplay(english: true).range(of: "[\\u4e00-\\u9fff]", options: .regularExpression))
    }
}
