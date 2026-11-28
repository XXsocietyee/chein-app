import Foundation

/// fix/1128c-ai-showcase (owner 11-28 ~12:25 UTC "highlight AI in our build process and homepage"), step 3: the neutral
/// hand-off between the home AI showcase / AI creation flow and the two sibling AI branches.
///
/// - `fix/1128c-ai-weather` publishes `WeatherContext.guideFacts` (`["weather": "rain", "temperatureC": "12",
///   "daypart": "night", "source": "server"]`, see its `docs/audits/1128-weather-inventory.md` §E). The showcase reads
///   only that string map, so this branch never names a type of the weather branch.
/// - `fix/1128c-ai-npc-guide` owns the AI guide chip / sheet and the NPC surfaces. It plugs in through
///   `AIExperienceLinking` (installed as the `aiExperienceLink` environment value in the app target).
///
/// Nothing here is fetched or invented: the guide states only the facts it is given (AI base doc §6), and with no
/// facts the showcase falls back to its own reviewed catalog line.
public struct AIShowcaseWeather: Equatable, Sendable {
    /// The backend `TopicEnvironmentService.WEATHER_VALUES` and `/api/map/weather` kinds, plus the weather branch's
    /// `WeatherSceneKind.sand` (story climate / WeatherKit haze).
    public enum Condition: String, CaseIterable, Sendable {
        case clear, cloudy, rain, snow, fog, wind, storm, sand
    }
    /// The backend daypart (Asia/Shanghai server clock) or the weather branch's solar daypart.
    public enum Daypart: String, CaseIterable, Sendable {
        case dawn, morning, afternoon, evening, night
    }
    public let condition: Condition
    public let temperatureC: Int?
    public let daypart: Daypart?

    public init(condition: Condition, temperatureC: Int? = nil, daypart: Daypart? = nil) {
        self.condition = condition
        self.temperatureC = temperatureC
        self.daypart = daypart
    }

    /// Reads the weather branch's `WeatherContext.guideFacts`. Unknown or missing `weather` gives nil (silence).
    public init?(guideFacts: [String: String]?) {
        guard let facts = guideFacts, let raw = facts["weather"]?.lowercased(),
              let condition = Condition(rawValue: raw) else { return nil }
        self.condition = condition
        if let text = facts["temperatureC"], let value = Double(text), value.isFinite, abs(value) < 80 {
            self.temperatureC = Int(value.rounded())
        } else {
            self.temperatureC = nil
        }
        self.daypart = facts["daypart"].flatMap { Daypart(rawValue: $0.lowercased()) }
    }
}

/// A reviewed NPC the guide branch can offer near the player (server text only: name and one reviewed line).
public struct AIShowcaseNPC: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let line: String
    public let placeName: String?

    public init(id: String, name: String, line: String, placeName: String? = nil) {
        self.id = id
        self.name = name
        self.line = line
        self.placeName = placeName
    }
}

/// The guide / NPC branch implements this; the showcase only calls it. Every member is optional in effect: a nil
/// launcher (the default) keeps the showcase on its own catalog copy and opens the 漫游 tab, where the reviewed roam
/// prompt layer already runs (planning audit R-18).
@MainActor public protocol AIExperienceLinking: AnyObject {
    /// Opens the AI guide (roam companion). False hides nothing: the showcase then opens the 漫游 tab instead.
    var canStartGuide: Bool { get }
    func startGuide()
    /// A reviewed nearby NPC, if the guide branch has one for this viewer right now.
    var nearbyNPC: AIShowcaseNPC? { get }
    func chatWithNPC(_ npc: AIShowcaseNPC)
    /// The guide's reviewed prompt for today from its content file; nil uses `AIShowcaseCatalog`.
    func todaySuggestion(for weather: AIShowcaseWeather?) -> String?
    /// The weather branch's `WeatherContext.guideFacts` as last published, nil when nothing was observed.
    func currentWeatherFacts() -> [String: String]?
}

/// Content slots of the home AI showcase. The copy lives in `Resources/Localizable.xcstrings` (en + zh-Hans) under
/// these keys, so the owner revises it there without a code change (brief "story content must be data-driven").
public enum AIShowcaseCatalog {
    public static let suggestionsPerSlot = 3

    /// `aiShowcase.guide.<condition|any>.<1...3>`, rotated by the day of the year so it changes daily.
    public static func suggestionKey(for weather: AIShowcaseWeather?, dayOfYear: Int) -> String {
        let slot = weather?.condition.rawValue ?? "any"
        let index = ((dayOfYear % suggestionsPerSlot) + suggestionsPerSlot) % suggestionsPerSlot + 1
        return "aiShowcase.guide.\(slot).\(index)"
    }

    public static func weatherLabelKey(_ condition: AIShowcaseWeather.Condition) -> String {
        "aiShowcase.weather." + condition.rawValue
    }

    /// SF Symbol for the condition (night variants after dusk); `sparkles` when no weather is known.
    public static func symbol(for weather: AIShowcaseWeather?) -> String {
        guard let weather else { return "sparkles" }
        let night = weather.daypart == .night || weather.daypart == .evening
        switch weather.condition {
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

    /// Every content key the catalog can produce, for the localization check.
    public static var allSuggestionKeys: [String] {
        let slots = ["any"] + AIShowcaseWeather.Condition.allCases.map(\.rawValue)
        return slots.flatMap { slot in (1...suggestionsPerSlot).map { "aiShowcase.guide.\(slot).\($0)" } }
    }
}
