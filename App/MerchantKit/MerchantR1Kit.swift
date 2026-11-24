import SwiftUI

// Design hand-off r1 · merchant & creator kit (docs/design/handoff-r1/review/full-merchant-creator.md §2).
// Light merchant theme: shared pill buttons and status tags from the design r1 foundation,
// unknown values as "—". Feature-local; nothing here edits App/DesignSystem or App/Theme. Copy lives in Resources/DesignR1Merchant.xcstrings.

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

// MARK: - Status

/// Merchant/Status Tag: needs me = amber, waiting on someone else = grey with a clock, live / done = green,
/// failed = red, info = grey. Drawn with the shared `CYStatusTag` (design r1 foundation); this enum only maps
/// merchant states onto it. Buttons use the shared `CYPillButtonStyle`. Blue is not used.
enum MerchantR1Status: String, CaseIterable, Sendable {
    case needsMe, waiting, live, done, failed, info

    var tagState: CYStatusTagState {
        switch self {
        case .needsMe: return .warning
        case .waiting, .info: return .neutral
        case .live: return .live
        case .done: return .done
        case .failed: return .failed
        }
    }

    var tone: CYStatusTone { tagState.tone }
    var symbol: String { tagState.systemImage }
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
                .cyText(.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: CYSpacing.sm)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: CYSpacing.xxs) {
                        Text(verbatim: actionTitle)
                        Image(systemName: "chevron.right").cyText(.meta, weight: .semibold)
                    }
                    .cyText(.bodyMedium)
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
                    Text(verbatim: title).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                    Text(verbatim: line).cyText(.body).foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let diagnostics {
                    Menu {
                        Button {
                            LocalPasteboard.copy(diagnostics)
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
                    .buttonStyle(CYPillButtonStyle(style: .secondary))
                Button(action: onRetry) { Text(verbatim: merchantR1("outcome.retry", locale)) }
                    .buttonStyle(CYPillButtonStyle(style: .secondary))
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
                Text(verbatim: title).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                Text(verbatim: line).cyText(.body).foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    Text(verbatim: "\(index + 1)")
                        .cyText(.label, weight: .bold, monospacedDigit: true)
                        .foregroundStyle(palette.actionPrimaryFg)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(palette.actionPrimaryBg))
                        .accessibilityHidden(true)
                    Text(verbatim: step).cyText(.body).foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let expectation {
                Label { Text(verbatim: expectation) } icon: { Image(systemName: "clock") }
                    .cyText(.meta)
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
    var weekIncome: String = "—"
    var weekAverage: String = "—"

    /// - todayRedemptions: a date-scoped count when the server sends one (it does not yet: nil → "—").
    static func make(revenue7d: [MerchantRevenuePoint], pendingOrders: Int?, todayRedemptions: Int? = nil,
                     now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> MerchantR1Today {
        MerchantR1Today(redemptions: todayRedemptions.map { "\(max(0, $0))" } ?? "—",
                        income: todayIncome(revenue7d, now: now, calendar: calendar),
                        pending: pendingOrders.map { "\(max(0, $0))" } ?? "—",
                        weekIncome: weekTotal(revenue7d).map { MerchantMoney.display(NSDecimalNumber(decimal: $0).stringValue) } ?? "—",
                        weekAverage: weekTotal(revenue7d).map { total in
                            // 近 7 天日均 is over the 7-day window; a day the server leaves out had no revenue.
                            var average = total / Decimal(7)
                            var rounded = Decimal()
                            NSDecimalRound(&rounded, &average, 2, .plain)
                            return MerchantMoney.display(NSDecimalNumber(decimal: rounded).stringValue)
                        } ?? "—")
    }

    /// verify-r1 2.8 / owner Q4: until the server has day-scoped counts, the card shows 7-day numbers.
    /// nil when there are no points or any point's amount is not a number (never a partial sum).
    static func weekTotal(_ points: [MerchantRevenuePoint]) -> Decimal? {
        guard !points.isEmpty else { return nil }
        var total = Decimal()
        for point in points {
            guard let raw = point.amount?.trimmingCharacters(in: .whitespacesAndNewlines),
                  raw.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
                  let amount = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
            total += amount
        }
        return total
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

    // verify-r1 2.8 / N-07 / owner Q4: never a hero of dashes. 待处理 is the large number (it is the thing to act on);
    // the two numbers under it are the last 7 days, labelled as such, until the server has day-scoped counts.
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(verbatim: merchantR1("today.pending", locale))
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    Text(verbatim: today.pending)
                        .cyText(.data2XL)
                        .foregroundStyle(palette.textPrimary)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    if today.pending != "—" {
                        Text(verbatim: merchantR1("today.pendingCaption", locale))
                            .cyText(.label)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchant.r1.today.pending")
            }
            Rectangle().fill(palette.borderSubtle).frame(height: 0.5).accessibilityHidden(true)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        tile("week.income", today.weekIncome); tile("week.average", today.weekAverage)
                    }
                } else {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        tile("week.income", today.weekIncome); tile("week.average", today.weekAverage)
                    }
                }
            }
            if today.weekIncome == "—" && today.pending == "—" {
                Text(verbatim: merchantR1("today.unknownReason", locale))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
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
            // Secondary to the 待处理 hero: one step down from the data type.
            Text(verbatim: value)
                .cyText(.sectionTitle, monospacedDigit: true)
                .foregroundStyle(palette.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: merchantR1(key, locale))
                .cyText(.label)
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
                .cyText(.body)
                .foregroundStyle(palette.textSecondary)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: MerchantMoney.display(raw))
                .cyText(.dataXL)
                .foregroundStyle(palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("merchant.ledger.cumulative")
    }
}

/// MR-07: 签约 opens in WeChat. Say so, number the steps, offer 打开微信 once the link is copied.
struct MerchantR1SigningHandOff: View {
    let copied: Bool
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            MerchantR1HandOffCard(title: merchantR1("signing.title", locale),
                                  line: merchantR1("signing.line", locale),
                                  steps: [merchantR1("signing.step1", locale), merchantR1("signing.step2", locale), merchantR1("signing.step3", locale)],
                                  expectation: merchantR1("signing.after", locale))
            if copied, let wechat = URL(string: "weixin://") {
                Button { openURL(wechat) } label: { Text(verbatim: merchantR1("signing.openWeChat", locale)) }
                    .buttonStyle(CYPillButtonStyle(style: .secondary))
                    .accessibilityIdentifier("merchant.r1.signing.openWeChat")
            }
        }
    }
}

/// MR-38 / MC-29: withdrawal is handled by platform support — named, with the steps and reply time.
struct MerchantR1WithdrawalHandOff: View {
    @Environment(\.locale) private var locale

    var body: some View {
        MerchantR1HandOffCard(title: merchantR1("withdraw.title", locale),
                              line: merchantR1("withdraw.line", locale),
                              steps: [merchantR1("withdraw.step1", locale), merchantR1("withdraw.step2", locale)],
                              expectation: merchantR1("withdraw.after", locale))
            .accessibilityIdentifier("merchant.r1.withdraw.handOff")
    }
}
