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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selection: String?

    init(current: TemplateAuthoringMethod, locked: Bool = false, commit: @escaping (TemplateAuthoringMethod) -> Void) {
        self.current = current
        self.locked = locked
        self.commit = commit
        _selection = State(initialValue: String(current.rawValue))
    }

    private var picked: TemplateAuthoringMethod? { selection.flatMap(Int.init).flatMap(TemplateAuthoringMethod.init(rawValue:)) }

    var body: some View {
        EditorSheetPage(
            title: ConfigR4Text.text("config.gameplay.title"),
            leading: .close,
            doneEnabled: picked != nil && !locked,
            onDone: {
                if let picked, picked != current, !locked { commit(picked) }
                dismiss()
            }
        ) {
            EditorGameplayPickerGrid(choices: choices, selection: $selection)
                .accessibilityIdentifier("config.gameplay.grid")
        }
    }

    private var choices: [EditorGameplayChoice] {
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

    static func categoryKey(_ method: TemplateAuthoringMethod) -> String {
        switch method {
        case .text, .choice: return "config.gameplay.category.quiz"
        case .photo, .scan, .gps: return "config.gameplay.category.onSite"
        case .manual, .preference, .sensor: return "config.gameplay.category.other"
        }
    }
}
