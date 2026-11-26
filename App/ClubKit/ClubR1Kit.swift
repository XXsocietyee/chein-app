import SwiftUI

// Design hand-off r1 · member & club kit (docs/design/handoff-r1/review/full-member-club.md §2,
// review/full-player.md §2). Feature-local: nothing here edits App/DesignSystem or App/Theme.
// Copy lives in Resources/DesignR1Club.xcstrings (built by tools/build_design_r1_localizations.py).

/// One string from the r1 club catalog. Keys are written without the `r1club.` prefix.
func clubR1(_ key: String, _ locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "r1club." + key),
                                              table: "DesignR1Club", locale: locale))
}

/// Unknown values read as an em dash (player kit §2 "Unknown value").
func clubR1Value(_ value: String?) -> String {
    let shown = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return shown.isEmpty ? "—" : shown
}

// MARK: - Status

/// Club status words (§2 "Status Tag"): 进行中 green · 待处理 amber · 已结束 grey · 未通过 red. No blue.
/// Drawn with the shared `CYStatusTag` (design r1 foundation); this enum only maps club states onto it.
/// Buttons use the shared `CYPillButtonStyle` / `CYDestructiveButtonStyle`, sheets the shared
/// `CYResizableSheet` and `CYSheetHeader`.
enum ClubR1Status: String, CaseIterable, Sendable {
    case live, pending, ended, rejected

    var tagState: CYStatusTagState {
        switch self {
        case .live: return .live
        case .pending: return .warning
        case .ended: return .neutral
        case .rejected: return .failed
        }
    }

    var tone: CYStatusTone { tagState.tone }
    var symbol: String { tagState.systemImage }
}

/// `spring(response: 0.38, dampingFraction: 0.86)` between detents and for state morphs; nil under Reduce Motion.
enum ClubR1Motion {
    static func spring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)
    }
    static func fade(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.22)
    }
}

// MARK: - Rows

/// One trailing element per row (§2 "Row").
enum ClubR1RowAccessory: Equatable {
    case chevron, check, unchecked, none
    case tag(String)
}

/// Native list row: leading symbol or initial, title, one supporting line, one trailing element.
struct ClubR1Row<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var initial: String?
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        LabeledContent {
            trailing()
        } label: {
            Label {
                Text(verbatim: clubR1Value(title))
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle).lineLimit(1)
                }
            } icon: {
                if let initial {
                    Text(verbatim: String(initial.prefix(1)))
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background(.fill.tertiary, in: Circle())
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct ClubR1AccessoryView: View {
    let accessory: ClubR1RowAccessory

    var body: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .check:
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        case .unchecked:
            EmptyView()
        case .tag(let text):
            Text(verbatim: text).foregroundStyle(.secondary)
        case .none:
            EmptyView()
        }
    }
}

/// System switch row with one explanation line.
struct ClubR1SwitchRow: View {
    let title: String
    let explanation: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(verbatim: title)
            Text(verbatim: explanation)
        }
    }
}

/// A grouped section of rows; place inside a `List` or `Form`.
struct ClubR1Group<Content: View>: View {
    var header: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            if let header { Text(verbatim: header) }
        }
    }
}

/// Switch label: the setting, then one explanation line (MC-13).
struct ClubR1SwitchLabel: View {
    let title: Text
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            Text(verbatim: explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
