import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// fix/1128c-ai-weather: the weather model the maps, play scenes and the AI guide share, and the
/// `GET api/play/environment` request / reply shape (`ApiPlayEnvironmentController`).
final class WeatherContextTests: XCTestCase {
    private final class Stub: HTTPTransport {
        var reply = #"{"code":200,"data":null}"#
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(reply.utf8), 200)
        }
    }

    // MARK: Kinds

    func testServerAppleAndStoryKindsMap() {
        XCTAssertEqual(WeatherSceneKind.server("rain"), .rain)
        XCTAssertEqual(WeatherSceneKind.server(" Windy "), .wind)
        XCTAssertNil(WeatherSceneKind.server("unknown"))
        XCTAssertNil(WeatherSceneKind.server(""))
        XCTAssertEqual(WeatherSceneKind.apple("heavyRain"), .rain)
        XCTAssertEqual(WeatherSceneKind.apple("scatteredThunderstorms"), .storm)
        XCTAssertEqual(WeatherSceneKind.apple("blowingSnow"), .snow)
        XCTAssertEqual(WeatherSceneKind.apple("foggy"), .fog)
        XCTAssertEqual(WeatherSceneKind.apple("blowingDust"), .sand)
        XCTAssertEqual(WeatherSceneKind.apple("breezy"), .wind)
        XCTAssertEqual(WeatherSceneKind.apple("mostlyCloudy"), .cloudy)
        XCTAssertEqual(WeatherSceneKind.apple("mostlyClear"), .clear)
        XCTAssertEqual(WeatherSceneKind.storyClimate("SAND"), .sand)
        XCTAssertEqual(WeatherSceneKind.storyClimate("STORM"), .storm)
        XCTAssertFalse(WeatherSceneKind.cloudy.drawsParticles)
        XCTAssertEqual(WeatherSceneKind.clear.symbolName(isDaylight: false), "moon.stars.fill")
        XCTAssertEqual(WeatherSceneKind.rain.titleKey, "weather.kind.rain")
    }

    func testDaypartUsesTheBackendCutPoints() {
        XCTAssertEqual(WeatherDaypart.at(hour: 5), .dawn)
        XCTAssertEqual(WeatherDaypart.at(hour: 8), .morning)
        XCTAssertEqual(WeatherDaypart.at(hour: 12), .afternoon)
        XCTAssertEqual(WeatherDaypart.at(hour: 17), .evening)
        XCTAssertEqual(WeatherDaypart.at(hour: 20), .night)
        XCTAssertEqual(WeatherDaypart.at(hour: 2), .night)
    }

    func testSolarPhaseInShanghai() {
        // 2026-06-21 04:00 UTC = 12:00 Shanghai (day); 16:00 UTC = 00:00 Shanghai (night).
        let noon = Date(timeIntervalSince1970: 1_782_014_400)
        let midnight = noon.addingTimeInterval(12 * 3600)
        XCTAssertEqual(SolarLight.phase(latitude: 31.23, longitude: 121.47, at: noon), .day)
        XCTAssertGreaterThan(SolarLight.elevation(latitude: 31.23, longitude: 121.47, at: noon), 70)
        XCTAssertEqual(SolarLight.phase(latitude: 31.23, longitude: 121.47, at: midnight), .night)
    }

    // MARK: Compose

    func testEnvironmentWinsOverMapAndDevice() throws {
        let now = Date(timeIntervalSince1970: 1_782_014_400)
        let device = DeviceWeatherReading(kind: .clear, temperatureCelsius: 27.6, isDaylight: true)
        let context = try XCTUnwrap(WeatherContext.compose(environmentWeather: "rain", environmentDaypart: "afternoon",
                                                           map: (kind: "fog", intensity: 0.4), device: device,
                                                           latitude: 31.23, longitude: 121.47, now: now))
        XCTAssertEqual(context.kind, .rain)
        XCTAssertEqual(context.source, .environment)
        XCTAssertEqual(context.daypart, .afternoon)
        XCTAssertEqual(context.temperatureCelsius, 27.6)
        XCTAssertTrue(context.usesAppleWeather)
        XCTAssertEqual(context.temperatureText(usesMetric: true), "28°")
        XCTAssertEqual(context.temperatureText(usesMetric: false), "82°")
        XCTAssertEqual(context.guideFacts["weather"], "rain")
        XCTAssertEqual(context.guideFacts["temperatureC"], "28")
        XCTAssertEqual(context.guideFacts["daylight"], "day")
        XCTAssertEqual(context.guideFacts["source"], "server.environment")
    }

    func testMapAmbienceThenDeviceThenSunOnly() throws {
        let now = Date(timeIntervalSince1970: 1_782_057_600)
        let map = try XCTUnwrap(WeatherContext.compose(map: (kind: "snow", intensity: 3), latitude: 31.23, longitude: 121.47, now: now))
        XCTAssertEqual(map.kind, .snow)
        XCTAssertEqual(map.intensity, 1)
        XCTAssertEqual(map.source, .mapAmbience)
        XCTAssertNil(map.temperatureCelsius)
        XCTAssertFalse(map.usesAppleWeather)
        XCTAssertNil(map.guideFacts["temperatureC"])

        let device = try XCTUnwrap(WeatherContext.compose(device: DeviceWeatherReading(kind: .wind, temperatureCelsius: 9, isDaylight: false),
                                                          latitude: 40.7, longitude: -74, now: now))
        XCTAssertEqual(device.kind, .wind)
        XCTAssertEqual(device.source, .weatherKit)
        XCTAssertEqual(device.isDaylight, false)
        XCTAssertTrue(device.usesAppleWeather)

        let sun = try XCTUnwrap(WeatherContext.compose(latitude: 31.23, longitude: 121.47, now: now))
        XCTAssertEqual(sun.source, .daylightOnly)
        XCTAssertFalse(sun.reportsCondition)
        XCTAssertNil(sun.guideFacts["weather"])
        XCTAssertNil(WeatherContext.compose(now: now))
        XCTAssertNil(WeatherContext.compose(latitude: 0, longitude: 0, now: now))
    }

    func testMapWeatherExpiresInTenMinutesAndEnvironmentInThirty() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        let map = WeatherContext(kind: .rain, daypart: .night, source: .mapAmbience, observedAt: at)
        XCTAssertEqual(WeatherContext.mapFreshFor, 10 * 60)
        XCTAssertTrue(map.isFresh(now: at.addingTimeInterval(WeatherContext.mapFreshFor - 1)))
        XCTAssertFalse(map.isFresh(now: at.addingTimeInterval(WeatherContext.mapFreshFor)))
        let kit = WeatherContext(kind: .rain, daypart: .night, source: .weatherKit, observedAt: at)
        XCTAssertFalse(kit.isFresh(now: at.addingTimeInterval(WeatherContext.mapFreshFor)))
        let server = WeatherContext(kind: .rain, daypart: .night, source: .environment, observedAt: at)
        XCTAssertEqual(WeatherContext.environmentFreshFor, 30 * 60)
        XCTAssertTrue(server.isFresh(now: at.addingTimeInterval(WeatherContext.environmentFreshFor - 1)))
        XCTAssertFalse(server.isFresh(now: at.addingTimeInterval(WeatherContext.environmentFreshFor)))
    }

    /// `cursor/1128-be-weather`: 20 cells/degree (~5.5 km), Hangzhou 30.2741,120.1551 → `map:weather:605:2403`,
    /// and the reply is kind + intensity. 2026-11-28 00:30Z is morning in Asia/Shanghai and night in UTC.
    func testMapWeatherIsKindAndIntensityOnTheShanghaiCell() async throws {
        XCTAssertEqual(MapSearchPlayerService.cellsPerDegree, 20)
        let cell = try XCTUnwrap(MapSearchPlayerService.cell(latitude: 30.2741, longitude: 120.1551))
        XCTAssertEqual(cell.0, 605)
        XCTAssertEqual(cell.1, 2403)
        let body = #"{"kind":"rain","intensity":0.6,"temperature":22,"city":"杭州"}"#
        let raw = try JSONDecoder().decode(SquareGovernanceJSON.self, from: Data(body.utf8))
        let parsed = try XCTUnwrap(MapSearchPlayerService.weather(raw))
        XCTAssertEqual(parsed, .init(kind: "rain", intensity: 0.6))
        XCTAssertNil(MapSearchPlayerService.weather(try JSONDecoder().decode(SquareGovernanceJSON.self, from: Data(#"{"kind":"clear","intensity":0,"temperature":22}"#.utf8))))

        let now = Date(timeIntervalSince1970: 1_795_825_800)
        let context = try XCTUnwrap(WeatherContext.compose(map: (kind: parsed.kind, intensity: parsed.intensity),
                                                           latitude: 30.2741, longitude: 120.1551, now: now))
        XCTAssertEqual(context.kind, .rain)
        XCTAssertEqual(context.daypart, .morning)
        XCTAssertNil(context.temperatureCelsius)
        XCTAssertEqual(context.guideFacts["daypart"], "morning")
        XCTAssertNil(context.guideFacts["temperatureC"])
        let utc = try XCTUnwrap(WeatherContext.compose(map: (kind: "rain", intensity: 0.6), latitude: 30.2741, longitude: 120.1551,
                                                       now: now, timeZone: TimeZone(secondsFromGMT: 0)!))
        XCTAssertEqual(utc.daypart, .night)

        let stub = Stub()
        stub.reply = #"{"code":200,"data":{"kind":"rain","intensity":0.6,"temperature":22,"city":"杭州"}}"#
        let client = PlayerCapabilityClient(baseURL: URL(string: "https://example.test/native/")!, token: "synthetic-token", transport: stub)
        let sent = await MapSearchPlayerService(client: client).weather(latitude: 30.2741, longitude: 120.1551)
        XCTAssertEqual(sent, .init(kind: "rain", intensity: 0.6))
        let request = try XCTUnwrap(stub.requests.last)
        let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items, [URLQueryItem(name: "lat", value: "30.275"), URLQueryItem(name: "lng", value: "120.175")])
        XCTAssertFalse(request.url?.query?.contains("temperature") == true)
    }

    @MainActor func testBoardKeepsTheLastValue() {
        let board = WeatherContextBoard()
        board.publish(nil)
        XCTAssertNil(board.latest)
        let context = WeatherContext(kind: .fog, daypart: .dawn, source: .mapAmbience, observedAt: Date())
        board.publish(context)
        XCTAssertEqual(board.current, context)
        let stale = WeatherContext(kind: .rain, daypart: .night, source: .mapAmbience,
                                   observedAt: Date().addingTimeInterval(-WeatherContext.mapFreshFor))
        board.publish(stale)
        XCTAssertEqual(board.latest, stale)
        XCTAssertNil(board.current)
        board.clear()
        XCTAssertNil(board.current)
    }

    // MARK: Story climate (MP look-fx CLIMATE / VOL)

    func testStoryClimateFollowsThePhaseTable() throws {
        XCTAssertNil(StoryClimate(style: "CYBER", climate: "RAIN", volatility: nil))
        let storm = try XCTUnwrap(StoryClimate(style: "SURVIVAL", climate: "STORM", volatility: "VIOLENT"))
        XCTAssertEqual(storm.kind, .storm)
        XCTAssertEqual(storm.cycle, (6 + 7 + 8 + 6) * 0.6, accuracy: 0.0001)
        let held = storm.sample(at: 6 * 0.6 + 2.5)
        XCTAssertEqual(held.wind, 2.8 * 1.4, accuracy: 0.0001)
        XCTAssertTrue(held.bolt)
        let fallback = try XCTUnwrap(StoryClimate(style: "survival", climate: "HAIL", volatility: "WILD"))
        XCTAssertEqual(fallback.kind, .rain)
        XCTAssertEqual(fallback.amplitude, 1)
        XCTAssertFalse(fallback.sample(at: 1).bolt)
    }

    func testLookTokensKeepSurvivalClimateOnly() {
        let survival = PlayThemeLookTokens(style: "SURVIVAL", palette: nil, neon: nil, climate: "sand", volatility: "calm")
        XCTAssertEqual(survival?.climate, "SAND")
        XCTAssertEqual(survival?.volatility, "CALM")
        let defaulted = PlayThemeLookTokens(style: "SURVIVAL", palette: nil, neon: nil)
        XCTAssertEqual(defaulted?.climate, "RAIN")
        XCTAssertEqual(defaulted?.volatility, "SHIFTING")
        let cyber = PlayThemeLookTokens(style: "CYBER", palette: nil, neon: nil, climate: "SAND", volatility: nil)
        XCTAssertNil(cyber?.climate)
    }

    // MARK: api/play/environment

    func testEnvironmentReadSendsTopicIdAndParsesEvents() async throws {
        let stub = Stub()
        stub.reply = """
        {"code":200,"data":{"topicId":4,"city":"上海","enabled":true,"keys":["weather","daypart"],
         "environment":{"weather":"rain","daypart":"night","weekpart":"weekend","season":"winter"},
         "sourceStatus":"AVAILABLE",
         "events":[{"id":2,"ruleName":"夜雨","conditionKey":"weather","conditionValues":["fog"],"unlockNodeId":9,
                    "active":false,"reason":"x","lockReason":"需在特定天气（fog）触发"},
                   {"id":1,"ruleName":"雨夜彩蛋","conditionKey":"weather","conditionValues":["rain"],"unlockNodeId":8,
                    "taskLabel":"去檐下听雨","active":true,"reason":"当前天气命中"}]}}
        """
        let client = PlayerCapabilityClient(baseURL: URL(string: "https://example.test/native/")!, token: "synthetic-token", transport: stub)
        let read = await PlayEnvironmentService(client: client).snapshot(topicID: 4)
        let snapshot = try XCTUnwrap(read)
        let request = try XCTUnwrap(stub.requests.last)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/native/api/play/environment")
        XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "topicId", value: "4")])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertEqual(snapshot.weather, "rain")
        XCTAssertEqual(snapshot.daypart, "night")
        XCTAssertEqual(snapshot.sourceStatus, .available)
        XCTAssertEqual(snapshot.orderedEvents.map(\.id), [1, 2])
        XCTAssertEqual(snapshot.orderedEvents.first?.taskLabel, "去檐下听雨")
        XCTAssertEqual(snapshot.orderedEvents.last?.lockReason, "需在特定天气（fog）触发")
        XCTAssertEqual(snapshot.orderedEvents.last?.unlockNodeID, 9)
    }

    func testEnvironmentFailuresReadAsNoSnapshot() async {
        let stub = Stub()
        let client = PlayerCapabilityClient(baseURL: URL(string: "https://example.test/")!, token: "synthetic-token", transport: stub)
        stub.reply = #"{"code":401,"msg":"请先登录","errorCode":"ENV_LOGIN_REQUIRED"}"#
        let rejected = await PlayEnvironmentService(client: client).snapshot(topicID: 4)
        XCTAssertNil(rejected)
        stub.reply = #"{"code":200,"data":{"topicId":5,"environment":{"weather":"rain"}}}"#
        let otherTopic = await PlayEnvironmentService(client: client).snapshot(topicID: 4)
        XCTAssertNil(otherTopic)
        stub.reply = #"{"code":200,"data":{"topicId":4,"enabled":true,"environment":{"weather":"unknown"},"sourceStatus":"FALLBACK_UNKNOWN","fallbackReason":"天气源暂不可用或未配置主题城市","events":[]}}"#
        let unknown = await PlayEnvironmentService(client: client).snapshot(topicID: 4)
        XCTAssertNil(unknown?.weather)
        XCTAssertEqual(unknown?.sourceStatus, .fallbackUnknown)
        let none = await PlayEnvironmentService(client: client).snapshot(topicID: 0)
        XCTAssertNil(none)
    }
}
