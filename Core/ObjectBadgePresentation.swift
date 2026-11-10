import Foundation

public enum ObjectBadgePresentation {
    public static func track(category: String) -> Int {
        switch category {
        case "CREATE": return 1
        case "ORGANIZE": return 2
        case "CONNECT": return 3
        case "CO_CREATE", "CO-CREATE", "COCREATE": return 4
        default: return 0
        }
    }
    public static func style(medal: ProfileMedal) -> String {
        medal.isAchievement || medal.style.isEmpty ? "glow" : medal.style
    }
    /// Backend naive dates are China calendar dates, never device-local dates.
    public static func date(_ value: String?) -> String? {
        guard let value else { return nil }
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2})(\.\d{1,3})?(Z|[+-]\d{2}:?\d{2})?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func part(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: s) else { return nil }; return String(s[range])
        }
        guard let year = part(1).flatMap(Int.init), let month = part(2).flatMap(Int.init), let day = part(3).flatMap(Int.init), year > 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let hour = part(4).flatMap(Int.init) ?? 0, minute = part(5).flatMap(Int.init) ?? 0, second = part(6).flatMap(Int.init) ?? 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { return nil }
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let naive = calendar.date(from: components) else { return nil }
        let checked = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: naive)
        guard checked.year == year, checked.month == month, checked.day == day,
              checked.hour == hour, checked.minute == minute, checked.second == second else { return nil }
        var date = naive
        if let zone = part(8) {
            var seconds = 0
            if zone != "Z" {
                let digits = zone.dropFirst().replacingOccurrences(of: ":", with: "")
                guard let h = Int(digits.prefix(2)), let m = Int(digits.suffix(2)), h <= 23, m <= 59 else { return nil }
                seconds = (h * 3600 + m * 60) * (zone.hasPrefix("-") ? -1 : 1)
            }
            date = naive.addingTimeInterval(TimeInterval(8 * 3600 - seconds))
        }
        let output = DateFormatter(); output.calendar = calendar; output.timeZone = calendar.timeZone
        output.locale = Locale(identifier: "en_US_POSIX"); output.dateFormat = "yyyy-MM-dd"
        return output.string(from: date)
    }
}

/// Screen facts for `subpackageP3/pages/badge-3d/index`.
/// The only contract in this repo is the existing `/badge` query route. There is no mesh,
/// model-url, or owned-detail endpoint, so a 3D asset stays hidden and this type never marks a route live.
public enum ObjectBadge3DPreviewState: Equatable {
    case loading
    case empty
    case error(ObjectBadge3DPreviewIssue)
    case unknown(ObjectBadge3DPreviewContent)
    case ready(ObjectBadge3DPreviewContent)

    /// Missing and non-canonical numbers render as this mark. A literal zero stays "0".
    public static let unknownMark = "—"

    public var accessibilityIdentifier: String {
        switch self {
        case .loading: return "objects.badge3d.loading"
        case .empty: return "objects.badge3d.empty"
        case .error(.sessionChanged): return "objects.badge3d.error.session"
        case .error(.malformed): return "objects.badge3d.error.malformed"
        case .unknown: return "objects.badge3d.unknown"
        case .ready: return "objects.badge3d.ready"
        }
    }

    public var messageKey: String {
        switch self {
        case .loading: return "objects.loading"
        case .empty: return "profile.badges.empty"
        case .error(let issue): return issue.messageKey
        case .unknown: return Self.unknownMark
        case .ready(let content): return content.staticPreviewKey
        }
    }

    /// Rarity caption for this screen. Non-ready screens and unknown rarity are "—", never 0.
    public var rarityText: String {
        switch self {
        case .ready(let content), .unknown(let content): return content.rarityText
        case .loading, .empty, .error: return Self.unknownMark
        }
    }
}

public enum ObjectBadge3DPreviewIssue: Equatable {
    case sessionChanged
    case malformed
    public var messageKey: String {
        switch self {
        case .sessionChanged: return "objects.sessionChanged"
        case .malformed: return "nativeNav.error.title"
        }
    }
}

public struct ObjectBadge3DPreviewContent: Equatable {
    public let name, subtitle, image, style, glyph, rarityText: String
    public let hintKey: String?
    public let staticPreviewKey = "objects.staticPreview"
    /// No reviewed mesh contract exists. Callers cannot turn this on.
    public let showsMesh: Bool
    public let reducedMotion: Bool
    public static let rarityAccessibilityIdentifier = "objects.badge3d.rarity"
    public static let staticPreviewAccessibilityIdentifier = "objects.badge3d.staticPreview"

    init(name: String, subtitle: String, image: String, style: String, glyph: String, rarityText: String, hintKey: String?, reducedMotion: Bool) {
        self.name = name; self.subtitle = subtitle; self.image = image; self.style = style; self.glyph = glyph
        self.rarityText = rarityText; self.hintKey = hintKey; self.showsMesh = false; self.reducedMotion = reducedMotion
    }

    public var titleKey: String? { name.isEmpty ? "profile.badges.detail" : nil }
    public var styleKey: String {
        switch style {
        case "glow": return "objects.glow"
        case "pin": return "objects.pin"
        default: return "objects.enamel"
        }
    }
    /// Nil when rarity is the unknown mark. A canonical 0 still maps to `objects.rarity.0`.
    public var rarityKey: String? {
        guard let value = Int(rarityText), (0...4).contains(value), String(value) == rarityText else { return nil }
        return "objects.rarity.\(value)"
    }
}

/// Hint at 3s and flat artwork at 6s, using the durations already recorded for this page.
public enum ObjectBadge3DFallbackPhase: Equatable { case preparing, hint, flat }

public enum ObjectBadge3DPreviewCoordinator {
    /// `settled == false` is loading and does not read the route, so a later number cannot leak early.
    public static func state(route: String?, scopeMatches: Bool, reducedMotion: Bool, settled: Bool) -> ObjectBadge3DPreviewState {
        guard settled else { return .loading }
        guard let route else { return .empty }
        guard let intent = NativeNavigationContract.parseInternal(route) else { return .error(.malformed) }
        return state(intent: intent, rarityQuery: rarityQuery(in: route), scopeMatches: scopeMatches, reducedMotion: reducedMotion, settled: true)
    }

    /// In-app badge parameters already exist. A non-badge intent stays hidden. Glyph on the URL is not
    /// a navigation key (`NativeNavigationContract` still rejects it), so this does not open a new route.
    public static func state(intent: NativeEntryIntent?, rarityQuery: String?, scopeMatches: Bool, reducedMotion: Bool, settled: Bool) -> ObjectBadge3DPreviewState {
        guard settled else { return .loading }
        guard let intent else { return .empty }
        switch intent {
        case .routeError: return .error(.malformed)
        case .badge(let parameters):
            guard scopeMatches else { return .error(.sessionChanged) }
            guard hasPreview(parameters) else { return .empty }
            let value = content(parameters, rarityQuery: rarityQuery, reducedMotion: reducedMotion)
            return canonicalRarity(rarityQuery) == nil ? .unknown(value) : .ready(value)
        default: return .empty
        }
    }

    /// Nil and negative elapsed are unknown ("—"). A real zero stays "0".
    public static func elapsedText(_ milliseconds: Int?) -> String {
        guard let milliseconds, milliseconds >= 0 else { return ObjectBadge3DPreviewState.unknownMark }
        return String(milliseconds)
    }

    public static func fallbackPhase(elapsedMs: Int?, reducedMotion: Bool) -> ObjectBadge3DFallbackPhase? {
        guard let elapsedMs, elapsedMs >= 0 else { return nil }
        if reducedMotion || elapsedMs >= RoamTabFullFeatureParityDescriptor.badge3DAutoFallbackMs { return .flat }
        if elapsedMs >= RoamTabFullFeatureParityDescriptor.badge3DFallbackHintMs { return .hint }
        return .preparing
    }

    private static func content(_ parameters: ObjectBadgeDetailParameters, rarityQuery: String?, reducedMotion: Bool) -> ObjectBadge3DPreviewContent {
        let table = ObjectBadgeTurntable(style: parameters.style, reducedMotion: reducedMotion)
        return ObjectBadge3DPreviewContent(
            name: parameters.name, subtitle: parameters.subtitle, image: parameters.image,
            style: parameters.style, glyph: parameters.glyph,
            rarityText: canonicalRarity(rarityQuery) ?? ObjectBadge3DPreviewState.unknownMark,
            hintKey: table.hintKey, reducedMotion: reducedMotion)
    }

    /// Canonical rarity is the digits 0...4 exactly. Anything else, including a clamped stand-in, is unknown.
    private static func canonicalRarity(_ raw: String?) -> String? {
        guard let raw, let value = Int(raw), (0...4).contains(value), String(value) == raw else { return nil }
        return String(value)
    }

    private static func hasPreview(_ parameters: ObjectBadgeDetailParameters) -> Bool {
        !parameters.name.isEmpty || !parameters.subtitle.isEmpty || !parameters.image.isEmpty
    }

    private static func rarityQuery(in route: String) -> String? {
        guard let items = URLComponents(string: route)?.queryItems else { return nil }
        let matches = items.filter { $0.name == "rarity" }
        guard matches.count == 1 else { return nil }
        return matches[0].value
    }
}

#if DEBUG
/// Offline route strings for the 3D badge preview. Hosts are labels only; nothing contacts them.
public enum ObjectBadge3DPreviewFixtureData {
    public static let readyRoute = "/badge?name=Synthetic%20badge&sub=Example&style=enamel&rarity=2&img=https://fixtures.invalid/badge.png"
    public static let explicitZeroRoute = "/badge?name=Synthetic%20badge&rarity=0"
    public static let unknownRarityRoute = "/badge?name=Synthetic%20badge&style=pin"
    public static let emptyRoute = "/badge"
    public static let malformedRoute = "/badge?ownerId=1"
    public static let glyphRoute = "/badge?name=Synthetic%20badge&glyph=Star&rarity=1"
    public static let nonBadgeRoute = "/team/join?code=SYNTHETIC"
}
#endif
