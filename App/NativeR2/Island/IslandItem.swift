import SwiftUI

/// Tone of a `.status` island (the old `cyToast` tones plus error).
enum IslandTone: Equatable, Sendable {
    case info, success, warning, error

    var systemImage: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info: return .white
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

/// What the island is about. Each kind has its own SF Symbol, tint and default actions (spec M4).
enum IslandKind: Equatable, Sendable {
    /// Team / club / game / cooperation invite.
    case invitation
    /// IM or club channel message.
    case message
    /// Game or story hint ladder.
    case hint
    /// Story audio or video.
    case media
    /// Replaces every `.cyToast`.
    case status(IslandTone)
    /// Orientation punch available or stamp unlocked.
    case arrival

    var systemImage: String {
        switch self {
        case .invitation: return "person.2.fill"
        case .message: return "message.fill"
        case .hint: return "lightbulb.fill"
        case .media: return "waveform"
        case .status(let tone): return tone.systemImage
        case .arrival: return "mappin.and.ellipse"
        }
    }

    var tint: Color {
        switch self {
        case .invitation: return .accentColor
        case .message: return .green
        case .hint: return .yellow
        case .media: return .accentColor
        case .status(let tone): return tone.tint
        case .arrival: return .green
        }
    }

    /// Spoken before the title so VoiceOver users know where the pop-up came from.
    var accessibilityKindKey: String {
        switch self {
        case .invitation: return "island.kind.invitation"
        case .message: return "island.kind.message"
        case .hint: return "island.kind.hint"
        case .media: return "island.kind.media"
        case .status: return "island.kind.status"
        case .arrival: return "island.kind.arrival"
        }
    }
}

/// A catalog key, a runtime `LocalizedStringKey` (from `cyToast`), or an already localized string.
enum IslandText {
    case key(String)
    case localized(LocalizedStringKey)
    case verbatim(String)

    var text: Text {
        switch self {
        case .key(let key): return Text(LocalizedStringKey(key))
        case .localized(let key): return Text(key)
        case .verbatim(let value): return Text(verbatim: value)
        }
    }

    /// Plain string for the VoiceOver announcement. A `LocalizedStringKey` with interpolated arguments cannot be
    /// resolved outside a `Text`, so it returns nil and the announcement falls back to the kind name.
    func resolved(locale: Locale) -> String? {
        switch self {
        case .key(let key): return appLocalized(String.LocalizationValue(stringLiteral: key), locale: locale)
        case .verbatim(let value): return value
        case .localized(let key):
            let children = Mirror(reflecting: key).children
            guard let raw = children.first(where: { $0.label == "key" })?.value as? String else { return nil }
            if let arguments = children.first(where: { $0.label == "arguments" })?.value as? [Any], !arguments.isEmpty { return nil }
            return appLocalized(String.LocalizationValue(stringLiteral: raw), locale: locale)
        }
    }
}

/// One button on the expanded card (at most two are shown).
struct IslandAction: Identifiable {
    let id = UUID()
    let title: IslandText
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    var prominent: Bool = false
    /// Keeps the island on screen after the action (play / pause). Everything else dismisses it.
    var keepsIsland: Bool = false
    let handler: @MainActor () -> Void
}

/// Live media facts for a `.media` island.
struct IslandMedia: Equatable {
    var isPlaying: Bool
    /// Wall-clock start of the current playing stretch, for the elapsed `Text(timerInterval:)`.
    var playingSince: Date?
}

/// One pop-up. `dedupeKey` lets a source update its island in place (media state, a second hint) instead of queueing.
struct IslandItem: Identifiable {
    var id = UUID()
    var kind: IslandKind
    var title: IslandText
    var subtitle: IslandText? = nil
    /// Overrides the kind's symbol.
    var systemImage: String? = nil
    var actions: [IslandAction] = []
    /// Tap on the expanded card (open the chat, the full player, the hint ladder). Nil: tap only expands.
    var open: (@MainActor () -> Void)? = nil
    /// Auto-dismiss delay. Nil keeps the island until it is swiped away or replaced.
    var lifetime: Duration? = .seconds(4)
    var media: IslandMedia? = nil
    var dedupeKey: String? = nil
    /// Start expanded (invitations and hints carry their actions up front).
    var startsExpanded: Bool = false

    var symbol: String { systemImage ?? kind.systemImage }
}
