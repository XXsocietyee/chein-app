import XCTest
@testable import Questify

/// fix/1128c-ai-weather: the weather systems are ON in the shipped (Release) composition
/// (`RegionalLaunchConfiguration.reviewedDeployment` → `shippedComposition`): both weather reads are admitted by the
/// China route gate and by the player grant transport, the effect layer and story climate are built from the Release
/// readings, and WeatherKit stays an owner switch that is off until the capability exists.
@MainActor final class Fix1128cWeatherReleaseCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    private final class Recorder: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
        }
        var lastPath: String {
            requests.last?.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? ""
        }
    }

    private func context(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    func testReleaseDeploymentIsTheReviewedProductionOne() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        XCTAssertTrue(deployment.productionGatesEnabled)
        XCTAssertTrue(deployment.playerWritesEnabled)
    }

    func testReleaseAdmitsBothWeatherReads() async throws {
        for path in [MapSearchPlayerService.weatherPath, PlayEnvironmentService.path] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(ReviewedProductionGateLeases.capabilityReadPaths.contains(path), path)
            XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/" + path), path)
        }

        let recorder = Recorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try context(composition)
        XCTAssertNotNil(composition.playerWriteGrant(player))
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        // Same construction as `AppSession.playerCapabilityClient()` (PlayerCapabilityHost.swift).
        let client = PlayerCapabilityClient(context: player, transport: transport)

        _ = await PlayEnvironmentService(client: client).snapshot(topicID: 4)
        XCTAssertEqual(recorder.lastPath, "api/play/environment")
        XCTAssertEqual(recorder.requests.last?.httpMethod, "GET")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(recorder.requests.last?.url), resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "topicId" })?.value, "4")

        _ = await MapSearchPlayerService(client: client).weather(latitude: 31.23, longitude: 121.47)
        XCTAssertEqual(recorder.lastPath, "api/map/weather")
    }

    func testSceneLayerAndStoryClimateAreBuiltFromReleaseReadings() throws {
        let overlay = MapWeatherOverlay(weather: .init(kind: "rain", intensity: 0.6))
        XCTAssertEqual(overlay.spec?.kind, .rain)
        XCTAssertNil(MapWeatherOverlay(weather: nil).spec)

        let look = try XCTUnwrap(CYThemeLook(style: "SURVIVAL", climate: "STORM", volatility: "VIOLENT"))
        XCTAssertEqual(look.storyClimate?.kind, .storm)
        XCTAssertNil(CYThemeLook(style: "CYBER", climate: "STORM")?.storyClimate)

        let painted = CYWeatherPainter.mix(.init(kind: .storm, intensity: 0.9), time: 3)
        XCTAssertTrue(painted.bolt)
        XCTAssertGreaterThan(painted.rain, 0.5)
        XCTAssertEqual(CYWeatherPainter.mix(.init(kind: .cloudy, intensity: 0.5), time: 3), CYWeatherPainter.Mix())
    }

    func testReloadRereadsMapWeatherInsideTheTenMinuteWindow() async {
        final class Rain: HTTPTransport {
            var count = 0
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                count += 1
                return (Data(#"{"code":200,"data":{"kind":"fog","intensity":0.4,"temperature":18}}"#.utf8), 200)
            }
        }
        let rain = Rain()
        let client = PlayerCapabilityClient(baseURL: URL(string: "https://example.test/native/")!, token: "synthetic-token", transport: rain)
        let model = SceneWeatherModel()
        let now = Date(timeIntervalSince1970: 1_795_825_800)
        await model.refresh(latitude: 30.2741, longitude: 120.1551, topicID: nil, client: client, now: now)
        await model.refresh(latitude: 30.2741, longitude: 120.1551, topicID: nil, client: client, now: now.addingTimeInterval(60))
        XCTAssertEqual(rain.count, 1)
        XCTAssertEqual(SceneWeatherModel.ttl, WeatherContext.mapFreshFor)
        XCTAssertEqual(WeatherKitReader.ttl, WeatherContext.mapFreshFor)
        await model.reload(latitude: 30.2741, longitude: 120.1551, topicID: nil, client: client, now: now.addingTimeInterval(60))
        XCTAssertEqual(rain.count, 2)
        XCTAssertEqual(model.context?.kind, .fog)
        XCTAssertNil(model.context?.temperatureCelsius)
        XCTAssertEqual(model.context?.daypart, .morning)
    }

    func testWeatherKitIsAnOwnerSwitchThatDefaultsOff() {
        XCTAssertFalse(WeatherKitReader.isEnabled(info: [:]))
        XCTAssertFalse(WeatherKitReader.isEnabled(info: [WeatherKitReader.infoKey: "NO"]))
        XCTAssertFalse(WeatherKitReader.isEnabled(info: [WeatherKitReader.infoKey: ""]))
        XCTAssertTrue(WeatherKitReader.isEnabled(info: [WeatherKitReader.infoKey: "YES"]))
        XCTAssertTrue(WeatherKitReader.isEnabled(info: [WeatherKitReader.infoKey: true]))
    }
}
