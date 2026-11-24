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

/// Leading visual, headline, one supporting line, one trailing element. Minimum height 52.
struct ClubR1Row<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var initial: String?
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            if let initial {
                Text(verbatim: String(initial.prefix(1)))
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(palette.bgRaised))
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: clubR1Value(title))
                    .cyText(.bodyMedium)
                    .foregroundStyle(palette.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .cyText(.meta)
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, CYSpacing.lg)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

struct ClubR1AccessoryView: View {
    let accessory: ClubR1RowAccessory
    @Environment(\.cyPalette) private var palette

    var body: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .cyText(.label, weight: .semibold)
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
        case .check:
            Image(systemName: "checkmark.circle.fill")
                .accessibilityHidden(true).cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
        case .unchecked:
            Image(systemName: "circle")
                .accessibilityHidden(true).cyText(.cardTitle)
                .foregroundStyle(palette.textTertiary)
        case .tag(let text):
            CYStatusChip(verbatim: text)
        case .none:
            EmptyView()
        }
    }
}

/// Neutral switch row (owner-confirmed Q-B: neutral, not system green) with one explanation line.
struct ClubR1SwitchRow: View {
    let title: String
    let explanation: String
    @Binding var isOn: Bool
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: title)
                    .cyText(.bodyMedium)
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: explanation)
                    .cyText(.meta)
                    .foregroundStyle(palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(palette.textSecondary)
        .padding(.horizontal, CYSpacing.lg)
        .frame(minHeight: 52)
    }
}

/// Grouped card surface for rows (content layer, not glass).
struct ClubR1Group<Content: View>: View {
    var header: String?
    @ViewBuilder var content: () -> Content
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if let header {
                Text(verbatim: header)
                    .cyText(.meta, weight: .semibold)
                    .foregroundStyle(palette.textTertiary)
                    .padding(.horizontal, CYSpacing.lg)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).fill(palette.bgElevated))
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        }
    }
}

/// Switch label: the setting, then one explanation line (MC-13).
struct ClubR1SwitchLabel: View {
    let title: Text
    let explanation: String
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            title
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
            Text(verbatim: explanation)
                .cyText(.meta)
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
