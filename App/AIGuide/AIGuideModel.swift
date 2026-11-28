import SwiftUI
import Observation

// fix/1128c-ai-npc-guide: the AI guide / roam companion (planning 漫游AI基座 无形象伴随式). The guide never invents
// facts: it shows what the server reviewed for this walk (prompt-layer lines, place meaning, route story) and the
// owner's data-file prompts for the current surface and weather. No avatar or name in roam (planning §7.1).

/// Script text for NPC / guide moments, read once from the bundled content file (docs/release/story-content.md).
@MainActor enum AIStoryContent {
    static let catalog: StoryContentCatalog? = StoryContentCatalog.bundled()

    static func language(_ locale: Locale) -> StoryContentLanguage {
        StoryContentLanguage(languageIdentifier: locale.identifier)
    }

    /// Empty when the file or key is missing; callers hide the line.
    static func text(_ key: StoryContentKey, locale: Locale) -> String {
        catalog?.text(key, language: language(locale)) ?? ""
    }
}

/// One line the guide can show. Server kinds come only from reviewed backend fields.
struct AIGuideEntry: Identifiable, Equatable {
    enum Kind: String, Equatable { case hint, meaning, story, footprint, prompt }
    let id: String
    let kind: Kind
    let text: String
    let place: String?

    var isServerText: Bool { kind == .hint || kind == .meaning || kind == .story }
    var labelKey: LocalizedStringKey { LocalizedStringKey("aiGuide.kind." + kind.rawValue) }
}

/// The guide's memory for one screen visit: reviewed lines as they arrive and the weather of the current cell.
@MainActor @Observable final class AIGuideJournal {
    private(set) var entries: [AIGuideEntry] = []
    private(set) var mapWeather: MapSearchPlayerService.Weather?
    private(set) var arrivals = 0

    /// Keeps the newest 20 distinct lines; a repeated line is not added twice.
    func record(_ kind: AIGuideEntry.Kind, text: String, place: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !entries.contains(where: { $0.kind == kind && $0.text == trimmed }) else { return }
        entries.insert(AIGuideEntry(id: "\(kind.rawValue)-\(entries.count)-\(trimmed.hashValue)", kind: kind, text: trimmed, place: place), at: 0)
        if entries.count > 20 { entries.removeLast(entries.count - 20) }
        arrivals += 1
    }

    func updateWeather(_ weather: MapSearchPlayerService.Weather?) {
        guard weather != mapWeather else { return }
        mapWeather = weather
    }

    func reset() {
        entries = []
        mapWeather = nil
    }
}

/// What the guide knows about "now": the surface, the place or stop, and the weather.
struct AIGuideContext: Equatable {
    let surface: StoryGuideSurface
    var place: String?
    var stop: String?
    /// `shop` when the current play stop has an in-store NPC.
    var nodeKind: String?
    var weather: StoryGuideWeather?
}

/// The small seam the ai-weather worker's `WeatherContext` (Core/WeatherContext.swift) can conform to when it lands.
protocol AIGuideWeatherProviding {
    var guideWeather: StoryGuideWeather? { get }
}

enum AIGuideWeatherMapping {
    /// MP `cy-map-weather` kinds (rain | snow | fog), then night by the local clock; nil when nothing is known.
    static func weather(_ map: MapSearchPlayerService.Weather?, now: Date = Date(), calendar: Calendar = .current) -> StoryGuideWeather? {
        switch map?.kind ?? "" {
        case "rain": return .rain
        case "snow": return .snow
        case "fog": return .cloudy
        default:
            let hour = calendar.component(.hour, from: now)
            return hour >= 19 || hour < 6 ? .night : nil
        }
    }

    static func symbol(_ weather: StoryGuideWeather) -> String {
        switch weather {
        case .any, .clear: return "sun.max"
        case .cloudy: return "cloud.fog"
        case .rain: return "cloud.rain"
        case .snow: return "cloud.snow"
        case .wind: return "wind"
        case .hot: return "thermometer.sun"
        case .cold: return "thermometer.snowflake"
        case .night: return "moon.stars"
        }
    }
}

private struct AIGuideJournalKey: EnvironmentKey {
    static let defaultValue: AIGuideJournal? = nil
}

extension EnvironmentValues {
    /// The live screen's guide journal; the map weather reader and the prompt layer write into it.
    var aiGuideJournal: AIGuideJournal? {
        get { self[AIGuideJournalKey.self] }
        set { self[AIGuideJournalKey.self] = newValue }
    }
}

/// Feeds the roam guide journal from the server-confirmed live state: the place meaning after a verified discover
/// (BE `poi/discover` → `meaning`) and the route story after settlement (BE `roam/finish` → `routeStory`).
struct RoamGuideJournalFeed: ViewModifier {
    let journal: AIGuideJournal
    let placeName: String?
    let placeText: String?
    let routeStory: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: placeText, initial: true) { _, text in
                if let text { journal.record(.meaning, text: text, place: placeName) }
            }
            .onChange(of: routeStory, initial: true) { _, story in
                if let story { journal.record(.story, text: story) }
            }
    }
}

/// Play: the current stop's in-store NPC greeting is the only server line the guide repeats.
struct PlayGuideJournalFeed: ViewModifier {
    let journal: AIGuideJournal
    let stop: String?
    let greeting: String?

    func body(content: Content) -> some View {
        content.onChange(of: greeting, initial: true) { _, line in
            if let line { journal.record(.hint, text: line, place: stop) }
        }
    }
}
