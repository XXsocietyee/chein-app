import SwiftUI

// Design hand-off r1 · merchant & creator kit (docs/design/handoff-r1/review/full-merchant-creator.md §2).
// Light merchant theme: one button shape (black, radius 12, 46 high, pinned), chips 36 on 44,
// one status tag with an icon, unknown values as "—". Feature-local; nothing here edits
// App/DesignSystem or App/Theme. Copy lives in Resources/DesignR1Merchant.xcstrings.

/// One string from the r1 merchant catalog. Keys are written without the `r1merchant.` prefix.
func merchantR1(_ key: String, _ locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "r1merchant." + key),
                                              table: "DesignR1Merchant", locale: locale))
}

/// Unknown values read as an em dash.
func merchantR1Value(_ value: String?) -> String {
    let shown = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return shown.isEmpty ? "—" : shown
}

// MARK: - Buttons

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// Merchant/Button: radius 12, 46 high, full width. Primary black, secondary #EEEEEE, destructive red
/// (only for actions that cannot be undone). Press = scale .97, 80 ms, no haptic.
struct MerchantR1ButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary
    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        configuration.label
            .font(CYTypography.button)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, CYSpacing.lg)
            .background(shape.fill(background))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
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
        case .secondary: return palette.actionSecondaryBg
        case .destructive: return palette.actionDangerBg
        }
    }
}

// MARK: - Status

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// Merchant/Status Tag: needs me = amber, waiting on someone else = grey with a clock, live / done = green,
/// failed = red, info = grey. One tag with an icon; blue is not used.
enum MerchantR1Status: String, CaseIterable, Sendable {
    case needsMe, waiting, live, done, failed, info

    var tone: CYStatusTone {
        switch self {
        case .needsMe: return .warning
        case .waiting, .info: return .neutral
        case .live, .done: return .success
        case .failed: return .danger
        }
    }

    var symbol: String {
        switch self {
        case .needsMe: return "exclamationmark.circle"
        case .waiting: return "clock"
        case .live: return "dot.radiowaves.left.and.right"
        case .done: return "checkmark.circle"
        case .failed: return "xmark.octagon"
        case .info: return "info.circle"
        }
    }
}

struct MerchantR1StatusTag: View {
    let status: MerchantR1Status
    let text: String
    var body: some View {
        CYStatusChip(verbatim: text, tone: status.tone, systemImage: status.symbol)
    }
}

// MARK: - Chips

// HANDOFF-R1: replace with DS component from ui/d-r1-foundation-player
/// Merchant/Chip: 36 visual on a 44 target; unselected = #EEEEEE capsule with ink text; selected = black
/// capsule with white text. Never bare text.
struct MerchantR1Chip: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.xs) {
                Text(verbatim: title)
                if let count { Text(verbatim: "\(count)").monospacedDigit() }
            }
            .font(CYTypography.body.weight(.medium))
            .foregroundStyle(isSelected ? palette.actionPrimaryFg : palette.textPrimary)
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: 36)
            .background(Capsule(style: .continuous).fill(isSelected ? palette.actionPrimaryBg : palette.actionSecondaryBg))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Headers

/// Section header 18 Bold with an optional trailing ink action (with a chevron). Never blue.
struct MerchantR1SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: title)
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: CYSpacing.sm)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: CYSpacing.xxs) {
                        Text(verbatim: actionTitle)
                        Image(systemName: "chevron.right").font(CYTypography.caption.weight(.semibold))
                    }
                    .font(CYTypography.body.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .textCase(nil)
    }
}

// MARK: - Unknown outcome (MR-04)

/// Merchant/Outcome Unknown: a calm amber card, plain words, both actions secondary
/// (`查看结果` first, `重试` second). The request number sits behind ⋯ → 复制诊断信息.
struct MerchantR1OutcomeUnknownCard: View {
    let title: String
    let line: String
    let onCheck: () -> Void
    let onRetry: () -> Void
    var diagnostics: String?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                Image(systemName: "clock.badge.questionmark")
                    .foregroundStyle(palette.warning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(verbatim: title).font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                    Text(verbatim: line).font(CYTypography.body).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let diagnostics {
                    Menu {
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = diagnostics
                            #endif
                        } label: {
                            Label { Text(verbatim: merchantR1("outcome.copyDiagnostics", locale)) } icon: { Image(systemName: "doc.on.doc") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(palette.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(verbatim: merchantR1("common.more", locale)))
                }
            }
            HStack(spacing: CYSpacing.md) {
                Button(action: onCheck) { Text(verbatim: merchantR1("outcome.check", locale)) }
                    .buttonStyle(MerchantR1ButtonStyle(kind: .secondary))
                Button(action: onRetry) { Text(verbatim: merchantR1("outcome.retry", locale)) }
                    .buttonStyle(MerchantR1ButtonStyle(kind: .secondary))
            }
        }
        .padding(CYSpacing.lg)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.warningSoft))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Hand-offs (MR-07, MR-38; owner Q-A: keep the hand-offs, name them, show the next step)

/// A named hand-off: what happens, where it happens, the numbered next steps, and what to expect after.
struct MerchantR1HandOffCard: View {
    let title: String
    let line: String
    let steps: [String]
    var expectation: String?
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: title).font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                Text(verbatim: line).font(CYTypography.body).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    Text(verbatim: "\(index + 1)")
                        .font(CYTypography.label.weight(.bold).monospacedDigit())
                        .foregroundStyle(palette.actionPrimaryFg)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(palette.actionPrimaryBg))
                        .accessibilityHidden(true)
                    Text(verbatim: step).font(CYTypography.body).foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let expectation {
                Label { Text(verbatim: expectation) } icon: { Image(systemName: "clock") }
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgSurface))
        .accessibilityElement(children: .combine)
    }
}

/// Money screens are built in full but stay TEST-only until the owner says "money on".
struct MerchantR1TestOnlyBadge: View {
    @Environment(\.locale) private var locale
    var body: some View {
        CYStatusChip(verbatim: merchantR1("money.testOnly", locale), tone: .warning, systemImage: "hammer")
            .accessibilityIdentifier("merchant.r1.money.testOnly")
    }
}

// MARK: - Workbench today (MR-20, owner Q-C: today's three numbers; cumulative moves to 账本)

/// 今日核销 · 今日收入 · 待处理. A number the server does not report for today is "—", never a guess.
struct MerchantR1Today: Equatable {
    let redemptions: String
    let income: String
    let pending: String

    /// - todayRedemptions: a date-scoped count when the server sends one (it does not yet: nil → "—").
    static func make(revenue7d: [MerchantRevenuePoint], pendingOrders: Int?, todayRedemptions: Int? = nil,
                     now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> MerchantR1Today {
        MerchantR1Today(redemptions: todayRedemptions.map { "\(max(0, $0))" } ?? "—",
                        income: todayIncome(revenue7d, now: now, calendar: calendar),
                        pending: pendingOrders.map { "\(max(0, $0))" } ?? "—")
    }

    /// The `revenue7d` point dated today (`yyyy-MM-dd`, `yyyy/MM/dd` or `MM-dd`), formatted as money.
    static func todayIncome(_ points: [MerchantRevenuePoint], now: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return "—" }
        let full = String(format: "%04d-%02d-%02d", year, month, day)
        let short = String(format: "%02d-%02d", month, day)
        for point in points {
            let date = point.date.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/", with: "-")
            if date == full || date == short || date.hasPrefix(full + " ") || date.hasPrefix(full + "T") {
                return MerchantMoney.display(point.amount)
            }
        }
        return "—"
    }
}

/// Merchant/Today Card: three tiles with the data hero type; each tile names its number.
struct MerchantR1TodayCard: View {
    let today: MerchantR1Today
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let keys = ["today.redemptions", "today.income", "today.pending"]
        let values = [today.redemptions, today.income, today.pending]
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: merchantR1("today.title", locale))
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.md) { ForEach(0..<3, id: \.self) { tile(keys[$0], values[$0]) } }
                } else {
                    HStack(alignment: .top, spacing: CYSpacing.md) { ForEach(0..<3, id: \.self) { tile(keys[$0], values[$0]) } }
                }
            }
            if today.redemptions == "—" || today.income == "—" {
                Text(verbatim: merchantR1("today.unknownReason", locale))
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgSurface))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("merchant.r1.today")
    }

    private func tile(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: value)
                .font(CYTypography.dataXL)
                .foregroundStyle(palette.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: merchantR1(key, locale))
                .font(CYTypography.label)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 账本 (MR-21): one page, a view switcher, and the cumulative total that left the workbench hero

private struct MerchantR1CumulativeRevenueKey: EnvironmentKey {
    static let defaultValue: String?? = nil
}

extension EnvironmentValues {
    /// `.some(raw)` when the workbench knows the cumulative revenue (raw may itself be nil = unknown).
    var merchantR1CumulativeRevenue: String?? {
        get { self[MerchantR1CumulativeRevenueKey.self] }
        set { self[MerchantR1CumulativeRevenueKey.self] = newValue }
    }
}

/// The ledger's view switcher: 核销 (entries) · 结算 (batches).
enum MerchantR1LedgerView: String, CaseIterable, Identifiable {
    case redemptions, settlements
    var id: String { rawValue }
}

/// 累计收入 row at the top of 账本 (owner Q-C). Unknown is "—".
struct MerchantR1CumulativeRow: View {
    let raw: String?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: merchantR1("ledger.cumulative", locale))
                .font(CYTypography.body)
                .foregroundStyle(palette.textSecondary)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: MerchantMoney.display(raw))
                .font(CYTypography.dataXL)
                .foregroundStyle(palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("merchant.ledger.cumulative")
    }
}
