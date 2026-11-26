import SwiftUI

/// Screens r4 · Figma 237:71933 `GameplayPickerSheet` (CF-51, SR2-19; section 237:71932, detents `.fraction(0.62)` /
/// `.large`). The gameplay editor's 完成方式 is picked here: category chips, a two-column grid of preview tiles with the
/// name under each, the picked type's description in the footer. Tapping a tile selects it (neutral 1.5 pt border +
/// filled check, `.selection`); the **one** confirm is 完成 in the header (no bottom bar, no second black capsule).
/// While advanced games are on, every type moves into the collapsed unavailable group with the reason once.
struct TemplateGameplayPickerSheet: View {
    let current: TemplateAuthoringMethod
    var locked: Bool = false
    let commit: (TemplateAuthoringMethod) -> Void
    /// r9 C-T8b: MP pages/publish/utils/publish/node-game-catalog.js:27-33, :110-118 — the 推理 group
    /// (排序 / 连线 / 分类) is picked from the same sheet. A pick enables that advanced section; nil hides the group.
    let commitGame: ((TemplateAdvancedGame) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selection: String?

    init(current: TemplateAuthoringMethod, locked: Bool = false, commit: @escaping (TemplateAuthoringMethod) -> Void,
         commitGame: ((TemplateAdvancedGame) -> Void)? = nil) {
        self.current = current
        self.locked = locked
        self.commit = commit
        self.commitGame = commitGame
        _selection = State(initialValue: String(current.rawValue))
    }

    private static let gamePrefix = "game."
    private var picked: TemplateAuthoringMethod? { selection.flatMap(Int.init).flatMap(TemplateAuthoringMethod.init(rawValue:)) }
    private var pickedGame: TemplateAdvancedGame? {
        guard let selection, selection.hasPrefix(Self.gamePrefix) else { return nil }
        return TemplateAdvancedGame(rawValue: String(selection.dropFirst(Self.gamePrefix.count)))
    }

    var body: some View {
        EditorSheetPage(
            title: ConfigR4Text.text("config.gameplay.title"),
            leading: .close,
            doneEnabled: (picked != nil || pickedGame != nil) && !locked,
            onDone: {
                if let game = pickedGame, !locked {
                    // MP catalog: the 推理 games carry validationMethod 0 (manual).
                    if current != .manual { commit(.manual) }
                    commitGame?(game)
                } else if let picked, picked != current, !locked { commit(picked) }
                dismiss()
            }
        ) {
            EditorGameplayPickerGrid(choices: choices, selection: $selection)
                .accessibilityIdentifier("config.gameplay.grid")
        }
    }

    private var choices: [EditorGameplayChoice] { methodChoices + inferenceChoices }

    /// MP node-game-catalog.js:118 — 排序 / 连线 / 分类 under 推理 (Core `TemplateAuthoringGameplayCatalog.inference`).
    private var inferenceChoices: [EditorGameplayChoice] {
        guard commitGame != nil else { return [] }
        return TemplateAuthoringGameplayCatalog.inference.compactMap { game in
            guard let advanced = TemplateAdvancedGame(rawValue: game.key) else { return nil }
            return EditorGameplayChoice(
                id: Self.gamePrefix + game.key,
                title: appLocalized(String.LocalizationValue(stringLiteral: advanced.labelKey), locale: locale),
                summary: appLocalized(String.LocalizationValue(stringLiteral: "fixr9.ap.gameplay.summary." + game.key), locale: locale),
                systemImage: Self.inferenceSymbol(advanced),
                category: appLocalized("fixr9.ap.gameplay.category.inference", locale: locale),
                unavailableReason: locked ? ConfigR4Text.string("config.gameplay.locked", locale: locale) : nil
            )
        }
    }

    static func inferenceSymbol(_ game: TemplateAdvancedGame) -> String {
        switch game {
        case .sort: return "arrow.up.arrow.down"
        case .match: return "point.3.connected.trianglepath.dotted"
        case .classify: return "square.grid.2x2"
        default: return "gamecontroller"
        }
    }

    private var methodChoices: [EditorGameplayChoice] {
        TemplateAuthoringMethod.allCases.map { method in
            EditorGameplayChoice(
                id: String(method.rawValue),
                title: appLocalized(String.LocalizationValue(stringLiteral: method.labelKey), locale: locale),
                summary: ConfigR4Text.string("config.gameplay.summary.\(method.rawValue)", locale: locale),
                systemImage: Self.symbol(method),
                category: ConfigR4Text.string(Self.categoryKey(method), locale: locale),
                unavailableReason: locked ? ConfigR4Text.string("config.gameplay.locked", locale: locale) : nil
            )
        }
    }

    /// One monochrome SF Symbol per gameplay (CF-56: gameplay identity is always the same glyph).
    static func symbol(_ method: TemplateAuthoringMethod) -> String {
        switch method {
        case .manual: return "checkmark.seal"
        case .text: return "character.cursor.ibeam"
        case .photo: return "camera"
        case .choice: return "list.bullet"
        case .scan: return "qrcode.viewfinder"
        case .gps: return "location"
        case .preference: return "slider.horizontal.3"
        case .sensor: return "gyroscope"
        }
    }

    /// C-T8 (MP utils/publish/node-game-catalog.js CATEGORIES): 问答 / 互动 / 挑战. 拍照 sits with 问答 as in the MP;
    /// the on-site checks (scan, GPS) and the sensor game are 挑战. The 推理 games come from `inferenceChoices` (r9 C-T8b).
    static func categoryKey(_ method: TemplateAuthoringMethod) -> String {
        switch method {
        case .text, .choice, .photo: return "config.gameplay.category.quiz"
        case .manual, .preference: return "config.gameplay.category.interact"
        case .scan, .gps, .sensor: return "config.gameplay.category.challenge"
        }
    }
}
