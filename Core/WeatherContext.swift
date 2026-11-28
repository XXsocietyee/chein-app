import Foundation
#if canImport(Combine)
import Combine
#endif

/// fix/1128c-ai-weather. One weather model for maps, play scenes, story looks and the AI guide / NPC worker
/// (`fix/1128c-ai-npc-guide` reads `WeatherContextBoard.shared.current?.guideFacts`).
///
/// Sources, in the order they win for the condition (inventory `docs/audits/1128-weather-inventory.md`):
/// 1. `GET api/play/environment?topicId=` (`TopicWeatherEventService.playerEnvironmentView`): the topic city's weather,
///    the same value the server's `weather_event_rule` gates use, so the scene never contradicts a game rule.
/// 2. `GET api/map/weather` (`MapWeatherVO`): rain / snow / fog ambience for the ~5.5 km cell, clear on any failure.
/// 3. Apple WeatherKit (owner build setting `CY_WEATHERKIT_ENABLED`): condition, temperature and daylight.
/// Temperature only ever comes from WeatherKit (the backend sends none). Day / night falls back to the sun's elevation.
public enum WeatherSceneKind: String, CaseIterable, Sendable {
    case clear, cloudy, rain, snow, fog, wind, storm, sand

    /// Backend values: map `rain/snow/fog/clear`, environment `clear cloudy rain snow fog wind storm` (and the
    /// author vocabulary `windy`). `unknown`, empty or anything else: nil (no claim about the weather).
    public static func server(_ raw: String?) -> WeatherSceneKind? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else { return nil }
        switch value {
        case "windy": return .wind
        case "sandstorm", "dust": return .sand
        default: return WeatherSceneKind(rawValue: value)
        }
    }

    /// Theme look SURVIVAL `params.climate` (MP `theme-look.js`): CLEAR / RAIN / STORM / SAND.
    public static func storyClimate(_ raw: String?) -> WeatherSceneKind? {
        switch raw?.uppercased() {
        case "CLEAR": return .clear
        case "RAIN": return .rain
        case "STORM": return .storm
        case "SAND": return .sand
        default: return nil
        }
    }

    /// WeatherKit `WeatherCondition.rawValue` (camelCase, e.g. `heavyRain`). Kept as a string so Core never links
    /// WeatherKit and the mapping is unit-tested.
    public static func apple(_ rawValue: String) -> WeatherSceneKind {
        let value = rawValue.lowercased()
        if value.contains("thunder") || value.contains("storm") || value.contains("hurricane") || value == "hail" { return .storm }
        if value.contains("snow") || value.contains("flurries") || value.contains("blizzard") || value.contains("sleet")
            || value.contains("wintrymix") { return .snow }
        if value.contains("rain") || value.contains("drizzle") || value.contains("showers") { return .rain }
        if value.contains("dust") || value.contains("sand") { return .sand }
        if value.contains("fog") || value.contains("haze") || value.contains("smok") { return .fog }
        if value.contains("wind") || value.contains("breez") { return .wind }
        if value.contains("cloud") { return .cloudy }
        return .clear
    }

    /// Precipitation or obscuration that the scene draws as particles / bands. Clear and cloudy only get light.
    public var drawsParticles: Bool { self != .clear && self != .cloudy }

    /// SF Symbol for the chip. Night variants for clear / cloudy.
    public func symbolName(isDaylight: Bool?) -> String {
        let night = isDaylight == false
        switch self {
        case .clear: return night ? "moon.stars.fill" : "sun.max.fill"
        case .cloudy: return night ? "cloud.moon.fill" : "cloud.sun.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .fog: return "cloud.fog.fill"
        case .wind: return "wind"
        case .storm: return "cloud.bolt.rain.fill"
        case .sand: return "sun.dust.fill"
        }
    }

    /// `Localizable.xcstrings` key, e.g. `weather.kind.rain` (晴 / 多云 / 雨 / 雪 / 雾 / 大风 / 雷暴 / 沙尘).
    public var titleKey: String { "weather.kind." + rawValue }

    /// Default strength when the source gives none.
    public var defaultIntensity: Double {
        switch self {
        case .clear, .cloudy: return 0
        case .storm: return 0.85
        case .sand: return 0.6
        default: return 0.5
        }
    }
}

/// Backend daypart (`TopicEnvironmentService.daypart`, Asia/Shanghai server clock): dawn 5–8, morning 8–12,
/// afternoon 12–17, evening 17–20, night otherwise. The device uses the same cut points in its own time zone.
public enum WeatherDaypart: String, CaseIterable, Sendable {
    case dawn, morning, afternoon, evening, night

    public static func server(_ raw: String?) -> WeatherDaypart? {
        raw.flatMap { WeatherDaypart(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
    }

    public static func at(hour: Int) -> WeatherDaypart {
        switch hour {
        case 5..<8: return .dawn
        case 8..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        default: return .night
        }
    }

    public static func at(_ date: Date, timeZone: TimeZone = .current) -> WeatherDaypart {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return at(hour: calendar.component(.hour, from: date))
    }
}

/// Sun position for the day / night light (NOAA low-precision formulas, within ~1° of the true elevation, which is
/// enough to tell day, twilight and night). Pure function of the coordinate and the instant.
public enum SolarLight {
    public enum Phase: String, Sendable { case day, twilight, night }

    /// Elevation of the sun's centre in degrees.
    public static func elevation(latitude: Double, longitude: Double, at date: Date) -> Double {
        let rad = Double.pi / 180
        let n = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let meanLongitude = (280.460 + 0.985_647_4 * n).truncatingRemainder(dividingBy: 360)
        let anomaly = (357.528 + 0.985_600_3 * n).truncatingRemainder(dividingBy: 360) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly)) * rad
        let obliquity = (23.439 - 0.000_000_4 * n) * rad
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)) / rad
        var siderealHours = (18.697_374_558 + 24.065_709_824_419_08 * n).truncatingRemainder(dividingBy: 24)
        if siderealHours < 0 { siderealHours += 24 }
        let hourAngle = (siderealHours * 15 + longitude - rightAscension) * rad
        let lat = latitude * rad
        let sine = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return asin(max(-1, min(1, sine))) / rad
    }

    /// Day above −0.833° (sunrise / sunset), civil twilight down to −6°, night below.
    public static func phase(latitude: Double, longitude: Double, at date: Date) -> Phase {
        let value = elevation(latitude: latitude, longitude: longitude, at: date)
        if value > -0.833 { return .day }
        if value > -6 { return .twilight }
        return .night
    }
}

/// Device reading from WeatherKit, already reduced to plain values (the App target owns the WeatherKit import).
public struct DeviceWeatherReading: Equatable, Sendable {
    public let kind: WeatherSceneKind
    public let intensity: Double
    public let temperatureCelsius: Double?
    public let isDaylight: Bool?

    public init(kind: WeatherSceneKind, intensity: Double? = nil, temperatureCelsius: Double?, isDaylight: Bool?) {
        self.kind = kind
        self.intensity = intensity.map { max(0, min(1, $0)) } ?? kind.defaultIntensity
        self.temperatureCelsius = temperatureCelsius.flatMap { $0.isFinite ? $0 : nil }
        self.isDaylight = isDaylight
    }

    /// WeatherKit `precipitationIntensity` in mm/h → 0…1 (0.5 mm/h drizzle ≈ 0.2, 8 mm/h heavy ≈ 1).
    public static func intensity(precipitationMillimetresPerHour value: Double?, kind: WeatherSceneKind) -> Double {
        guard let value, value.isFinite, value > 0 else { return kind.defaultIntensity }
        return max(0.15, min(1, 0.15 + value / 9))
    }
}

public struct WeatherContext: Equatable, Sendable {
    public enum Source: String, Sendable {
        case environment = "server.environment"
        case mapAmbience = "server.map"
        case weatherKit = "apple.weatherkit"
        case story = "story.look"
        case daylightOnly = "device.sun"
    }

    public let kind: WeatherSceneKind
    /// 0…1 (map ambience is clamped 0.15…1 like `weather-core.js`).
    public let intensity: Double
    /// Only from WeatherKit. Nil means "do not show a temperature".
    public let temperatureCelsius: Double?
    public let isDaylight: Bool?
    public let solarPhase: SolarLight.Phase?
    public let daypart: WeatherDaypart
    public let source: Source
    /// True when any value on screen came from Apple Weather: the Apple Weather mark and legal link must show.
    public let usesAppleWeather: Bool
    public let observedAt: Date

    public init(kind: WeatherSceneKind, intensity: Double? = nil, temperatureCelsius: Double? = nil, isDaylight: Bool? = nil,
                solarPhase: SolarLight.Phase? = nil, daypart: WeatherDaypart, source: Source, usesAppleWeather: Bool = false,
                observedAt: Date) {
        self.kind = kind
        self.intensity = max(0, min(1, intensity ?? kind.defaultIntensity))
        self.temperatureCelsius = temperatureCelsius
        self.isDaylight = isDaylight
        self.solarPhase = solarPhase ?? isDaylight.map { $0 ? .day : .night }
        self.daypart = daypart
        self.source = source
        self.usesAppleWeather = usesAppleWeather
        self.observedAt = observedAt
    }

    /// Merges the readings (see the type comment for precedence). Nil when there is nothing true to say.
    public static func compose(environmentWeather: String? = nil, environmentDaypart: String? = nil,
                               map: (kind: String, intensity: Double)? = nil, device: DeviceWeatherReading? = nil,
                               latitude: Double? = nil, longitude: Double? = nil,
                               now: Date = Date(), timeZone: TimeZone = .current) -> WeatherContext? {
        let solar: SolarLight.Phase? = {
            guard let latitude, let longitude, latitude.isFinite, longitude.isFinite,
                  abs(latitude) <= 90, abs(longitude) <= 180, !(latitude == 0 && longitude == 0) else { return nil }
            return SolarLight.phase(latitude: latitude, longitude: longitude, at: now)
        }()
        let daylight = device?.isDaylight ?? solar.map { $0 == .day }
        let daypart = WeatherDaypart.server(environmentDaypart) ?? WeatherDaypart.at(now, timeZone: timeZone)
        let temperature = device?.temperatureCelsius
        let appleShown = device != nil

        if let kind = WeatherSceneKind.server(environmentWeather) {
            let intensity = map.flatMap { WeatherSceneKind.server($0.kind) == kind ? $0.intensity : nil }
                ?? (device?.kind == kind ? device?.intensity : nil)
            return WeatherContext(kind: kind, intensity: intensity, temperatureCelsius: temperature, isDaylight: daylight,
                                  solarPhase: solar, daypart: daypart, source: .environment,
                                  usesAppleWeather: appleShown && (temperature != nil || device?.isDaylight != nil), observedAt: now)
        }
        if let map, let kind = WeatherSceneKind.server(map.kind), kind != .clear {
            return WeatherContext(kind: kind, intensity: max(0.15, min(1, map.intensity)), temperatureCelsius: temperature,
                                  isDaylight: daylight, solarPhase: solar, daypart: daypart, source: .mapAmbience,
                                  usesAppleWeather: appleShown && (temperature != nil || device?.isDaylight != nil), observedAt: now)
        }
        if let device {
            return WeatherContext(kind: device.kind, intensity: device.intensity, temperatureCelsius: temperature,
                                  isDaylight: daylight, solarPhase: solar, daypart: daypart, source: .weatherKit,
                                  usesAppleWeather: true, observedAt: now)
        }
        if let map, WeatherSceneKind.server(map.kind) == .clear {
            return WeatherContext(kind: .clear, intensity: 0, isDaylight: daylight, solarPhase: solar, daypart: daypart,
                                  source: .mapAmbience, observedAt: now)
        }
        if let solar {
            return WeatherContext(kind: .clear, intensity: 0, isDaylight: solar == .day, solarPhase: solar, daypart: daypart,
                                  source: .daylightOnly, observedAt: now)
        }
        return nil
    }

    /// The chip only states a condition a source actually reported (not the sun-only fallback).
    public var reportsCondition: Bool { source != .daylightOnly }

    /// Rounded °C or °F for the chip, by the locale's measurement system ("12°" / "54°"). Nil without a temperature.
    public func temperatureText(usesMetric: Bool) -> String? {
        guard let celsius = temperatureCelsius, celsius.isFinite else { return nil }
        let value = usesMetric ? celsius : celsius * 9 / 5 + 32
        return "\(Int(value.rounded()))°"
    }

    /// Neutral, verifiable facts for the AI guide / NPC worker (AI base doc §6: facts only, no forecast, silence when
    /// unknown). Keys: `weather`, `intensity` (low / medium / high), `temperatureC`, `daylight` (day / twilight /
    /// night), `daypart`, `source`. A key is omitted when its value is unknown.
    public var guideFacts: [String: String] {
        var out: [String: String] = ["daypart": daypart.rawValue, "source": source.rawValue]
        if reportsCondition {
            out["weather"] = kind.rawValue
            if kind.drawsParticles { out["intensity"] = intensity < 0.4 ? "low" : intensity < 0.75 ? "medium" : "high" }
        }
        if let temperatureCelsius, temperatureCelsius.isFinite { out["temperatureC"] = String(Int(temperatureCelsius.rounded())) }
        if let solarPhase { out["daylight"] = solarPhase.rawValue }
        return out
    }

    /// Fresh for 30 minutes, the backend environment cache window (`WEATHER_TTL_MILLIS`).
    public static let freshFor: TimeInterval = 30 * 60
    public func isFresh(now: Date = Date()) -> Bool { now.timeIntervalSince(observedAt) < Self.freshFor }
}

#if canImport(Combine)
/// Last weather any map or play scene resolved. The AI guide / NPC layer reads it; it never fetches on its own.
@MainActor public final class WeatherContextBoard: ObservableObject {
    public static let shared = WeatherContextBoard()
    @Published public private(set) var latest: WeatherContext?

    public init() {}

    /// Nil once older than `WeatherContext.freshFor`, so a guide line never states stale weather.
    public var current: WeatherContext? { latest.flatMap { $0.isFresh() ? $0 : nil } }

    public func publish(_ context: WeatherContext?) {
        guard let context else { return }
        if latest != context { latest = context }
    }

    /// Sign-out / account switch.
    public func clear() { latest = nil }
}
#endif

/// Theme look SURVIVAL (末世) weather that changes by itself (MP `pages/play/utils/look-fx.js` `CLIMATE` / `VOL`,
/// owner 2026-10-30: 晴 / 雨 / 雷暴 / 沙尘暴; `bolt` = this phase has lightning). Pure timeline, sampled by the scene.
public struct StoryClimate: Equatable, Sendable {
    public struct Phase: Equatable, Sendable {
        public let seconds: Double
        public let wind: Double, rain: Double, dust: Double, debris: Double
        public let bolt: Bool, gust: Bool
        init(_ seconds: Double, wind: Double = 0, rain: Double = 0, dust: Double = 0, debris: Double = 0, bolt: Bool = false, gust: Bool = false) {
            self.seconds = seconds; self.wind = wind; self.rain = rain; self.dust = dust; self.debris = debris; self.bolt = bolt; self.gust = gust
        }
    }
    public struct Mix: Equatable, Sendable {
        public let wind: Double, rain: Double, dust: Double, debris: Double
        public let bolt: Bool
    }

    public let kind: WeatherSceneKind
    public let phases: [Phase]
    /// `VOL[volatility]`: amplitude and phase-length factor.
    public let amplitude: Double
    public let lengthFactor: Double

    /// Nil for a non-SURVIVAL look. Unknown climate → RAIN and unknown volatility → SHIFTING (MP defaults).
    public init?(style: String?, climate: String?, volatility: String?) {
        guard style?.uppercased() == "SURVIVAL" else { return nil }
        let climateKey = ["CLEAR", "RAIN", "STORM", "SAND"].contains(climate?.uppercased() ?? "") ? climate!.uppercased() : "RAIN"
        kind = WeatherSceneKind.storyClimate(climateKey) ?? .rain
        phases = Self.table[climateKey] ?? Self.table["RAIN"]!
        switch volatility?.uppercased() {
        case "CALM": amplitude = 0.5; lengthFactor = 1.6
        case "VIOLENT": amplitude = 1.4; lengthFactor = 0.6
        default: amplitude = 1; lengthFactor = 1
        }
    }

    static let table: [String: [Phase]] = [
        "CLEAR": [Phase(8, wind: 0.25, dust: 0.06), Phase(7, wind: 0.7, dust: 0.1), Phase(7, wind: 0.15)],
        "RAIN": [Phase(7, wind: 0.4, rain: 0.55), Phase(7, wind: 1.2, rain: 0.9), Phase(6, wind: 0.2, rain: 0.35), Phase(7, wind: -0.8, rain: 0.75)],
        "STORM": [Phase(6, wind: 0.9, rain: 0.6, bolt: true), Phase(7, wind: 2.8, rain: 0.8, debris: 0.6, bolt: true, gust: true),
                  Phase(8, wind: 1.6, rain: 1, bolt: true), Phase(6, wind: -2.4, rain: 0.85, debris: 0.4, bolt: true, gust: true)],
        "SAND": [Phase(7, wind: 0.6, dust: 0.45), Phase(6, wind: 1.9, dust: 0.8, debris: 0.35, gust: true),
                 Phase(8, wind: 3.2, dust: 1, debris: 0.5, gust: true), Phase(6, wind: 1, dust: 0.55)]
    ]

    /// One full cycle in seconds.
    public var cycle: Double { phases.reduce(0) { $0 + $1.seconds * lengthFactor } }

    /// Mix at `elapsed` seconds: each phase eases in from the previous one over its first 2 s (the MP eases toward the
    /// phase target every frame), then holds. Amplitude scales wind / rain / dust / debris; rain and dust cap at 1.
    public func sample(at elapsed: Double) -> Mix {
        let total = cycle
        guard total > 0, elapsed.isFinite else { return Mix(wind: 0, rain: 0, dust: 0, debris: 0, bolt: false) }
        var t = elapsed.truncatingRemainder(dividingBy: total)
        if t < 0 { t += total }
        var index = 0
        while index < phases.count - 1, t >= phases[index].seconds * lengthFactor {
            t -= phases[index].seconds * lengthFactor
            index += 1
        }
        let current = phases[index]
        let previous = phases[(index + phases.count - 1) % phases.count]
        let k = min(1, t / 2)
        func blend(_ a: Double, _ b: Double) -> Double { (a + (b - a) * k) * amplitude }
        return Mix(wind: blend(previous.wind, current.wind),
                   rain: min(1, blend(previous.rain, current.rain)),
                   dust: min(1, blend(previous.dust, current.dust)),
                   debris: min(1, blend(previous.debris, current.debris)),
                   bolt: current.bolt)
    }
}
