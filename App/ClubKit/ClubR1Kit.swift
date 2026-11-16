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

// MARK: - Primary / secondary pills

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// White pill, 44 high (52 on full-screen moments), 16 semibold label, full width. One per screen.
struct ClubR1PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary
    var tall = false
    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CYTypography.button)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: tall ? 52 : 44)
            .padding(.horizontal, CYSpacing.lg)
            .background(Capsule(style: .continuous).fill(background))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Capsule(style: .continuous))
    }

    private var foreground: Color {
        guard isEnabled else { return palette.textDisabled }
        switch kind {
        case .primary: return palette.actionPrimaryFg
        case .secondary: return palette.textPrimary
        case .destructive: return palette.actionDangerFg
        }
    }

    private var background: Color {
        guard isEnabled else { return palette.bgSurfaceSubtle }
        switch kind {
        case .primary: return palette.actionPrimaryBg
        case .secondary: return palette.bgElevated
        case .destructive: return palette.actionDangerBg
        }
    }
}

// MARK: - Status tag

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// Soft fill, 12 pt icon, text. Never a dot alone. 进行中 green · 待处理 amber · 已结束 grey · 未通过 red. No blue.
enum ClubR1Status: String, CaseIterable, Sendable {
    case live, pending, ended, rejected

    var tone: CYStatusTone {
        switch self {
        case .live: return .success
        case .pending: return .warning
        case .ended: return .neutral
        case .rejected: return .danger
        }
    }

    var symbol: String {
        switch self {
        case .live: return "dot.radiowaves.left.and.right"
        case .pending: return "clock"
        case .ended: return "checkmark.circle"
        case .rejected: return "xmark.octagon"
        }
    }
}

struct ClubR1StatusTag: View {
    let status: ClubR1Status
    let text: String
    var body: some View {
        CYStatusChip(verbatim: text, tone: status.tone, systemImage: status.symbol)
    }
}

// MARK: - Sheet chrome

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// Sheet header: title left 20 Bold, round ✕ right (32 visual, 44 target). The grabber is the system one.
struct ClubR1SheetHeader: View {
    let title: String
    let onClose: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            Text(verbatim: title)
                .font(CYTypography.sheetTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(CYTypography.label.weight(.bold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(palette.bgSurfaceSubtle))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: clubR1("common.close", locale)))
        }
    }
}

/// Section 3 detents. `fit` opens at the content height capped at 62 %.
enum ClubR1SheetSize {
    case fit(CGFloat)
    case mediumLarge
    case fitLarge(CGFloat)
    case largeOnly

    var detents: Set<PresentationDetent> {
        switch self {
        case .fit(let height): return [.height(min(height, 520))]
        case .mediumLarge: return [.medium, .large]
        case .fitLarge(let height): return [.height(min(height, 520)), .large]
        case .largeOnly: return [.large]
        }
    }
}

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// Resizable scrollable sheet: smallest detent first, grows by drag, scrolls at the largest detent.
struct ClubR1SheetStyle: ViewModifier {
    let size: ClubR1SheetSize
    var interactiveDismissDisabled = false
    func body(content: Content) -> some View {
        content
            .presentationDetents(size.detents)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.resizes)
            .presentationCornerRadius(CYRadius.sheet)
            .interactiveDismissDisabled(interactiveDismissDisabled)
    }
}

extension View {
    func clubR1Sheet(_ size: ClubR1SheetSize, interactiveDismissDisabled: Bool = false) -> some View {
        modifier(ClubR1SheetStyle(size: size, interactiveDismissDisabled: interactiveDismissDisabled))
    }
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
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(palette.bgRaised))
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: clubR1Value(title))
                    .font(CYTypography.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(CYTypography.meta)
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
                .font(CYTypography.label.weight(.semibold))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
        case .check:
            Image(systemName: "checkmark.circle.fill")
                .font(CYTypography.cardTitle)
                .foregroundStyle(palette.textPrimary)
        case .unchecked:
            Image(systemName: "circle")
                .font(CYTypography.cardTitle)
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
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: title)
                    .font(CYTypography.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: explanation)
                    .font(CYTypography.meta)
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
                    .font(CYTypography.meta.weight(.semibold))
                    .foregroundStyle(palette.textTertiary)
                    .padding(.horizontal, CYSpacing.lg)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgElevated))
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
    }
}
