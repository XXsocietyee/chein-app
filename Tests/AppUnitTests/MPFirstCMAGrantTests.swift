import XCTest
@testable import Questify

/// MP-first rule (owner 2026-11-25): writes the mini-program sends are on in the shipped China composition;
/// the server's own checks decide. Money stays closed (G6CapabilityGrantTests and the money suites pin that).
@MainActor final class MPFirstCMAGrantTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    /// A3-01 (MP gerenziliao.js:781-812 avatar, :354 探索作品, :383 联系二维码 → app.js:654-668 `uploadOSS`).
    func testA3_01ProfileImageUploadGrantIsOnForTheShippedPlayer() async throws {
        let recorder = MPFirstCMARecorder()
        let composition = shipped(recorder)
        let player = try playerContext(composition)
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        XCTAssertTrue(grant.avatar.nativePicker)
        XCTAssertEqual(grant.avatar.accountID, player.session.accountID)
        XCTAssertEqual(grant.avatar.namespace, player.session.namespace)
        let host = try XCTUnwrap(player.baseURL.host)
        // The upload answers with an absolute image URL; its origin (not the API base string) must be approved.
        XCTAssertTrue(grant.avatar.approvedOrigins.contains("https://" + host.lowercased()))
        XCTAssertTrue(grant.profile.paths.contains(ProfileAvatarUploadClient.path))

        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        var upload = URLRequest(url: player.baseURL.appendingPathComponent(ProfileAvatarUploadClient.path))
        upload.httpMethod = "POST"
        upload.setValue("multipart/form-data; boundary=ProfileAvatar-fixture", forHTTPHeaderField: "Content-Type")
        upload.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        upload.httpBody = Data("--ProfileAvatar-fixture\r\nContent-Disposition: form-data; name=\"bizType\"\r\n\r\nimage_1_1\r\n--ProfileAvatar-fixture--\r\n".utf8)
        _ = try await transport.send(upload)
        XCTAssertEqual(recorder.paths.last, "api/common/uploadOSS")
        XCTAssertEqual(recorder.methods.last, "POST")
    }

    /// C-F6 (MP pages/publish/fabu/theme-fe-visit.js:40 GET ?topicId=, :87 POST {nodeId, visitCheck, visitRadius}).
    func testC_F6VisitConfigReadAndSaveAreGrantedOnProduction() async throws {
        XCTAssertTrue(PlayRuntimePortRouteGate.freeExploreVisitConfigRead)
        XCTAssertTrue(PlayRuntimePortRouteGate.freeExploreVisitConfigWrite)
        let production = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let routes = ReviewedProductionGateLeases.projectEditorRoutes(baseURL: production)
        XCTAssertTrue(routes[.projectRead]?.contains(try BusinessRuntimeRoute.get(FreeExplorationVisitConfigService.path)) == true)
        XCTAssertTrue(routes[.projectWrite]?.contains(try BusinessRuntimeRoute.post(FreeExplorationVisitConfigService.path)) == true)

        let recorder = MPFirstCMARecorder()
        let composition = shipped(recorder)
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        var parts = try XCTUnwrap(URLComponents(url: player.baseURL.appendingPathComponent(FreeExplorationVisitConfigService.path), resolvingAgainstBaseURL: false))
        parts.queryItems = [URLQueryItem(name: "topicId", value: "41")]
        var read = URLRequest(url: try XCTUnwrap(parts.url))
        read.httpMethod = "GET"
        read.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        read.setValue("application/json", forHTTPHeaderField: "Accept")
        _ = try await transport.send(read)
        XCTAssertEqual(recorder.paths.last, "api/topic/free-explore/visit-config")
        XCTAssertEqual(recorder.methods.last, "GET")
        var save = URLRequest(url: player.baseURL.appendingPathComponent(FreeExplorationVisitConfigService.path))
        save.httpMethod = "POST"
        save.httpBody = Data(#"{"nodeId":7,"visitCheck":"GPS","visitRadius":400}"#.utf8)
        save.setValue("application/json", forHTTPHeaderField: "Content-Type")
        save.setValue("application/json", forHTTPHeaderField: "Accept")
        save.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(save)
        XCTAssertEqual(recorder.methods.last, "POST")
        XCTAssertEqual(recorder.paths.last, "api/topic/free-explore/visit-config")
    }

    /// C-D12 (MP team/detail/index.wxml:5-14, utils/team-event-command.js:90-92): the recovery writer exists for the shipped player.
    func testC_D12TeamCommandWriterIsComposedForTheShippedPlayer() throws {
        let composition = shipped(MPFirstCMARecorder())
        let player = try playerContext(composition)
        let writer = try XCTUnwrap(composition.teamCommandWriter(context: player, transport: composition.transport()))
        XCTAssertTrue(TeamCommandWriter.paths.isSubset(of: writer.approval.paths))
    }

    /// C-F17 (MP fabu/index.js:7893-7894 sends `/api/topic/v2/create|update` directly). On production the edit-request
    /// envelope is not granted, so the editor sends the original route, which the player grant carries.
    func testC_F17ProductionGrantsTheOriginalRoutesTheMPSends() throws {
        let production = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let write = ReviewedProductionGateLeases.projectEditorRoutes(baseURL: production)[.projectWrite] ?? []
        XCTAssertFalse(write.contains(where: { $0.path == ProjectEditRequestContract.submitPath }))
        for path in ["api/topic/v2/create", "api/topic/v2/update"] where ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path) {
            XCTAssertTrue(write.contains(where: { $0.path == path && $0.method == "POST" }), path)
        }
    }

    private func shipped(_ recorder: MPFirstCMARecorder) -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
    }

    private func playerContext(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }
}

private final class MPFirstCMARecorder: HTTPTransport {
    var paths: [String] = []
    var methods: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        methods.append(request.httpMethod ?? "")
        return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
    }
}
