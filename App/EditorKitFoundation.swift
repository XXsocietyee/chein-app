import SwiftUI

// Design hand-off r1 · Editor kit (review/full-config.md section 2, revise/kit1.js – kit3.js).
// Feature-local to the creator editors (topic editor, gameplay template editor, publishing).
// Colours come only from `CYDomainPalette`, so the same kit renders the light editor
// theme and the dark player entry sheets (CF-42) without new tokens.

/// Localized text in the `EditorKit` string table.
enum EditorKitText {
    static let table = "EditorKit"
    static func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(key), table: table, locale: locale))
    }
}

/// Section 2 "Surfaces": a field inside a white card uses the filled input token; a field on the grey sheet
/// (or inside a page-grey list-item panel) is white.
enum EditorKitSurface: Sendable {
    case onCard
    case onGrey

    func fieldFill(_ palette: CYDomainPalette) -> Color {
        switch self {
        case .onCard: return palette.inputFilledBg
        case .onGrey: return palette.bgElevated
        }
    }
}

/// kit-prelude / kit1–3 geometry (pt). Visual sizes; every control still gets a 44 pt hit area (CF-15).
enum EditorKitMetric {
    static let hit: CGFloat = 44
    static let fieldHeight: CGFloat = 44
    static let areaHeight: CGFloat = 88
    static let numberFieldWidth: CGFloat = 132
    static let fieldPaddingX: CGFloat = 14
    static let fieldRadius: CGFloat = 12
    static let cardRadius: CGFloat = 12
    static let rowMinHeight: CGFloat = 50
    static let closeVisual: CGFloat = 32
    static let doneHeight: CGFloat = 44
    static let donePaddingX: CGFloat = 18
    static let grabberWidth: CGFloat = 36
    static let grabberHeight: CGFloat = 5
    static let switchRowMinHeight: CGFloat = 44
    static let secondaryVisual: CGFloat = 36
    static let selectedBorder: CGFloat = 1.5
    static let stepperCircle: CGFloat = 32
    static let optionRowHeight: CGFloat = 52
    static let optionThumb: CGFloat = 36
    static let toastMaxWidth: CGFloat = 329
    static let toastBottomGap: CGFloat = 12
    static let sectionBarHeight: CGFloat = 44
    static let stateIconTile: CGFloat = 64
    static let seamCircle: CGFloat = 28
    static let sheetCornerRadius: CGFloat = 24
}

/// Section 3.2 and CF-64 as SwiftUI animations. Reduce Motion turns springs into 200 ms cross-fades.
enum EditorKitMotion {
    static func detent(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: EditorMotionSpec.reduceMotionCrossFade)
            : .spring(response: EditorMotionSpec.detentResponse, dampingFraction: EditorMotionSpec.detentDamping)
    }
    static func reveal(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: EditorMotionSpec.reduceMotionCrossFade) : .easeOut(duration: EditorMotionSpec.revealSeconds)
    }
    static func collapse(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: EditorMotionSpec.reduceMotionCrossFade) : .easeOut(duration: EditorMotionSpec.collapseSeconds)
    }
    static func move(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: EditorMotionSpec.reduceMotionCrossFade)
            : .spring(response: EditorMotionSpec.moveResponse, dampingFraction: EditorMotionSpec.moveDamping)
    }
    static func drop(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: EditorMotionSpec.reduceMotionCrossFade)
            : .spring(response: EditorMotionSpec.dropResponse, dampingFraction: EditorMotionSpec.dropDamping)
    }
    static func press(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: EditorMotionSpec.pressSeconds)
    }
}

extension View {
    /// CF-15: a 44 × 44 hit area around a smaller visual.
    func editorHitTarget() -> some View {
        frame(minWidth: EditorKitMetric.hit, minHeight: EditorKitMetric.hit).contentShape(Rectangle())
    }
}

/// native-a r3: editor buttons are the system styles directly (`.borderedProminent` primary, `.bordered`
/// secondary, `.controlSize(.large)` for full-width rows); the former `editorPrimary` / `editorSecondary` wrappers are gone.

/// Section 2 "Selected state": neutral 1.5 pt border plus a filled check. No tint, no fill.
struct EditorKitSelectedBorder: ViewModifier {
    let isSelected: Bool
    var radius: CGFloat = EditorKitMetric.cardRadius
    @Environment(\.cyPalette) private var palette
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isSelected ? palette.textPrimary : palette.borderSubtle,
                              lineWidth: isSelected ? EditorKitMetric.selectedBorder : 1)
        )
    }
}

extension View {
    func editorSelectedBorder(_ isSelected: Bool, radius: CGFloat = EditorKitMetric.cardRadius) -> some View {
        modifier(EditorKitSelectedBorder(isSelected: isSelected, radius: radius))
    }

    /// Section 2 card: white, radius 12, no stroke.
    func editorCardSurface(padding: CGFloat = CYSpacing.lg) -> some View {
        modifier(EditorKitCardSurface(padding: padding))
    }
}

struct EditorKitCardSurface: ViewModifier {
    let padding: CGFloat
    @Environment(\.cyPalette) private var palette
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: EditorKitMetric.cardRadius, style: .continuous).fill(palette.bgElevated))
    }
}
