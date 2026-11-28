import Foundation

/// fix/1128c: the owner-editable script for NPC and guide moments (owner 11-28: "We'll be revising the script later").
/// Views never carry these lines; they read them from `Resources/Story/StoryGuide.json` (en + zh-Hans) through this
/// catalog. Server text (reviewed NPC lines, place meaning, route story, NPC replies) always wins over this file.
/// Schema: docs/release/story-content.md.
public enum StoryContentLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public init(languageIdentifier: String) {
        self = languageIdentifier.lowercased().hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

/// Every script line a view may ask for. A new key needs both languages in the content file (unit-tested).
public enum StoryContentKey: String, CaseIterable, Sendable {
    case npcAIBadge = "npc.aiBadge"
    case npcFallbackGreeting = "npc.fallbackGreeting"
    case guideRoamIdentity = "guide.roam.identity"
    case guidePlayIdentity = "guide.play.identity"
    case guideQuiet = "guide.quiet"
    case guideFootprint = "guide.footprint"
}

/// Where a guide prompt may appear.
public enum StoryGuideSurface: String, Codable, CaseIterable, Sendable {
    case roam, play
}

/// The weather condition a prompt asks for. `any` always matches; the rest match the current weather context.
public enum StoryGuideWeather: String, Codable, CaseIterable, Sendable {
    case any, clear, cloudy, rain, snow, wind, hot, cold, night
}

public struct StoryLocalizedText: Codable, Equatable, Sendable {
    public let en: String
    public let zhHans: String
    enum CodingKeys: String, CodingKey { case en, zhHans = "zh-Hans" }
    public init(en: String, zhHans: String) { self.en = en; self.zhHans = zhHans }
    public func value(_ language: StoryContentLanguage) -> String {
        switch language { case .english: return en; case .simplifiedChinese: return zhHans }
    }
}

public struct StoryGuidePrompt: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let surface: StoryGuideSurface
    public let weather: StoryGuideWeather
    /// Optional node kind (`shop`) the current play node must have.
    public let node: String?
    public let text: StoryLocalizedText
}

public struct StoryContentCatalog: Equatable, Sendable {
    public static let resourceName = "StoryGuide"
    public static let supportedSchemaVersion = 1

    public let revision: String
    private let strings: [String: StoryLocalizedText]
    private let prompts: [StoryGuidePrompt]

    private struct File: Decodable {
        let schemaVersion: Int
        let revision: String
        let strings: [String: StoryLocalizedText]
        let guidePrompts: [StoryGuidePrompt]
    }

    /// Fails closed: an unknown schema, a duplicate prompt id or an empty line rejects the whole file, so a broken
    /// edit shows no script text rather than half of it.
    public static func decode(_ data: Data) throws -> StoryContentCatalog {
        let file = try JSONDecoder().decode(File.self, from: data)
        guard file.schemaVersion == supportedSchemaVersion else { throw APIError.malformedResponse }
        let blank: (StoryLocalizedText) -> Bool = { text in
            text.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || text.zhHans.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !file.strings.values.contains(where: blank), !file.guidePrompts.contains(where: { blank($0.text) }),
              Set(file.guidePrompts.map(\.id)).count == file.guidePrompts.count else { throw APIError.malformedResponse }
        return StoryContentCatalog(revision: file.revision, strings: file.strings, prompts: file.guidePrompts)
    }

    /// The copy shipped in the app bundle. Nil when the file is missing or invalid (the views then stay quiet).
    public static func bundled(_ bundle: Bundle = .main) -> StoryContentCatalog? {
        let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Story")
            ?? bundle.url(forResource: resourceName, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(data)
    }

    /// An empty string when the key is missing; callers hide the line.
    public func text(_ key: StoryContentKey, language: StoryContentLanguage) -> String {
        strings[key.rawValue]?.value(language) ?? ""
    }

    /// Prompts for a surface: the weather-specific ones first, then the general ones, in file order.
    public func guidePrompts(for surface: StoryGuideSurface, weather: StoryGuideWeather? = nil, node: String? = nil,
                             language: StoryContentLanguage) -> [String] {
        let matching = prompts.filter { prompt in
            guard prompt.surface == surface else { return false }
            if let kind = prompt.node, kind != node { return false }
            return prompt.weather == .any || prompt.weather == weather
        }
        let specific = matching.filter { $0.weather != .any }
        let general = matching.filter { $0.weather == .any }
        return (specific + general).map { $0.text.value(language) }
    }
}
