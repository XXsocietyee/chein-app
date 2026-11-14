import SwiftUI

/// Trailing accessory of a `CYListRow`.
enum CYListRowTrailing {
    case none
    case chevron
    /// Tabular value (money / counts). Pass "—" for unknown, never 0.
    case value(String)
    case valueChevron(String)
}

enum CYListRowTone: Sendable {
    case standard
    case danger
}

enum CYListRowTokens {
    struct Resolved {
        let title: Color
        let meta: Color
        let value: Color
        let chevron: Color
        let leadingForeground: Color
        let leadingOpacity: Double
        let background: Color
        let divider: Color
    }

    static func resolve(
        tone: CYListRowTone,
        isDisabled: Bool,
        isPressed: Bool,
        in palette: CYDomainPalette
    ) -> Resolved {
        Resolved(
            title: isDisabled ? palette.textDisabled : (tone == .danger ? palette.danger : palette.textPrimary),
            meta: isDisabled ? palette.textDisabled : palette.textTertiary,
            value: isDisabled ? palette.textDisabled : palette.textSecondary,
            chevron: isDisabled ? palette.textDisabled : palette.textTertiary,
            leadingForeground: tone == .danger ? palette.danger : palette.textPrimary,
            leadingOpacity: isDisabled ? 0.4 : 1.0,
            background: isPressed && !isDisabled ? palette.bgSurfaceSubtle : Color.clear,
            divider: palette.borderSubtle
        )
    }
}

/// Button style for interactive `CYListRow` cells: applies `--cy-color-bg-surface-subtle` (`#141416` / `#EEEEEE`)
/// on press with zero layout bounce.
struct CYListRowButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 0
    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(
                shape.fill(configuration.isPressed && isEnabled ? palette.bgSurfaceSubtle : Color.clear)
            )
            .contentShape(shape)
    }
}

/// Row: leading icon or avatar, title, meta line, trailing value/chevron.
/// Spec dimensions: 1-line minHeight 48pt, 2-line minHeight 64pt, 12pt horizontal item gap, 4pt title/meta gap.
/// Supports `standard` / `danger` tone, `disabled`, pressed surface highlight, and optional 0.5pt bottom hairline.
/// `card: true` wraps it in the 16pt-radius card surface; otherwise it is a plain row for use inside a List/card.
struct CYListRow<Leading: View>: View {
    private let title: LocalizedStringKey
    private let meta: LocalizedStringKey?
    private let verbatimTitle: String?
    private let verbatimMeta: String?
    private let trailing: CYListRowTrailing
    private let card: Bool
    private var tone: CYListRowTone = .standard
    private var isDisabledRow: Bool = false
    private var isPressedState: Bool = false
    private var showsDivider: Bool = false
    private var horizontalPad: CGFloat? = nil
    private let leading: Leading

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var envIsEnabled
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        _ title: LocalizedStringKey,
        meta: LocalizedStringKey? = nil,
        trailing: CYListRowTrailing = .chevron,
        card: Bool = false,
        verbatimTitle: String? = nil,
        verbatimMeta: String? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.meta = meta
        self.verbatimTitle = verbatimTitle
        self.verbatimMeta = verbatimMeta
        self.trailing = trailing
        self.card = card
        self.leading = leading()
    }

    /// Server text stays verbatim. An empty title renders as an em dash.
    init(verbatim title: String, meta: String? = nil, trailing: CYListRowTrailing = .chevron, card: Bool = false, @ViewBuilder leading: () -> Leading) {
        let shown = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(LocalizedStringKey(""), meta: nil, trailing: trailing, card: card, verbatimTitle: shown.isEmpty ? "—" : shown, verbatimMeta: meta, leading: leading)
    }

    func danger(_ enabled: Bool = true) -> CYListRow {
        var copy = self; copy.tone = enabled ? .danger : .standard; return copy
    }

    func rowDisabled(_ disabled: Bool = true) -> CYListRow {
        var copy = self; copy.isDisabledRow = disabled; return copy
    }

    func rowPressed(_ pressed: Bool = true) -> CYListRow {
        var copy = self; copy.isPressedState = pressed; return copy
    }

    func rowDivider(_ visible: Bool = true) -> CYListRow {
        var copy = self; copy.showsDivider = visible; return copy
    }

    func rowPadding(_ horizontal: CGFloat = CYSpacing.lg) -> CYListRow {
        var copy = self; copy.horizontalPad = horizontal; return copy
    }

    private var effectiveDisabled: Bool { isDisabledRow || !envIsEnabled }
    private var hasMeta: Bool { verbatimMeta != nil || meta != nil }
    private var rowMinHeight: CGFloat { hasMeta ? 64 : 48 }

    private var resolvedTokens: CYListRowTokens.Resolved {
        CYListRowTokens.resolve(
            tone: tone,
            isDisabled: effectiveDisabled,
            isPressed: isPressedState,
            in: palette
        )
    }

    var body: some View {
        // cyPressTracking is gesture-free (it only reads a CYPressButtonStyle's pressed state), so a List NavigationLink row
        // keeps its tap; there the system row highlight is the feedback.
        if card {
            row
                .overlay(alignment: .bottom) { dividerLine }
                .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
                .cyPressTracking()
        } else {
            row
                .padding(.horizontal, horizontalPad ?? 0)
                .background(resolvedTokens.background)
                .overlay(alignment: .bottom) { dividerLine }
                .cyPressTracking()
        }
    }

    private var row: some View {
        let tokens = resolvedTokens
        return HStack(spacing: CYSpacing.md) {
            leading
                .opacity(tokens.leadingOpacity)
                .foregroundStyle(tokens.leadingForeground)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                titleText
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(tokens.title)
                if let verbatimMeta {
                    Text(verbatim: verbatimMeta)
                        .font(CYTypography.meta)
                        .foregroundStyle(tokens.meta)
                } else if let meta {
                    Text(meta)
                        .font(CYTypography.meta)
                        .foregroundStyle(tokens.meta)
                }
                // Accessibility sizes: the value moves under the text so the title keeps the full row width.
                if typeSize.isAccessibilitySize, let value = trailingValue { valueText(value) }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            .layoutPriority(1)
            if !typeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            trailingView
                .frame(maxWidth: 160, alignment: .trailing)
        }
        .frame(minHeight: rowMinHeight)
        .contentShape(Rectangle())
        // One VoiceOver stop per row: "title, meta, value". Chevron and icon tile are decorative.
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var dividerLine: some View {
        if showsDivider {
            Rectangle()
                .fill(resolvedTokens.divider)
                .frame(height: 0.5)
        }
    }

    private var trailingValue: String? {
        switch trailing {
        case .value(let value), .valueChevron(let value): return value
        default: return nil
        }
    }

    @ViewBuilder private var titleText: some View {
        if let verbatimTitle { Text(verbatim: verbatimTitle) } else { Text(title) }
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .none: EmptyView()
        case .chevron: chevron
        case .value(let value): if !typeSize.isAccessibilitySize { valueText(value) }
        case .valueChevron(let value):
            HStack(spacing: CYSpacing.xs) { if !typeSize.isAccessibilitySize { valueText(value) }; chevron }
        }
    }
    private func valueText(_ value: String) -> some View {
        Text(verbatim: value)
            .font(CYTypography.numericBody)
            .foregroundStyle(resolvedTokens.value)
            .lineLimit(1)
            .truncationMode(.tail)
    }
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(resolvedTokens.chevron)
            .accessibilityHidden(true)
    }
}

extension CYListRow where Leading == EmptyView {
    init(_ title: LocalizedStringKey, meta: LocalizedStringKey? = nil, trailing: CYListRowTrailing = .chevron, card: Bool = false) {
        self.init(title, meta: meta, trailing: trailing, card: card) { EmptyView() }
    }
    init(verbatim title: String, meta: String? = nil, trailing: CYListRowTrailing = .chevron, card: Bool = false) {
        self.init(verbatim: title, meta: meta, trailing: trailing, card: card) { EmptyView() }
    }
}

/// Rounded-square SF Symbol tile for the leading slot of `CYListRow`.
struct CYRowIcon: View {
    let systemImage: String
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    private var side: CGFloat { typeSize.isAccessibilitySize ? 56 : 40 }
    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.bgRaised))
            .accessibilityHidden(true)
    }
}

private struct CYListRowPreviewBody: View {
    var body: some View {
        VStack(spacing: CYSpacing.md) {
            CYListRow("Wallet", meta: "Balance and coupons", trailing: .valueChevron("¥128.50"), card: true) {
                CYRowIcon(systemImage: "creditcard")
            }
            CYListRow("Tickets", meta: "3 active", card: true) { CYRowIcon(systemImage: "ticket") }
            CYListRow("Orders", trailing: .value("—"), card: true) {
                CYAvatarView(name: "Orders", size: .md)
            }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
    }
}
#Preview("Row · player dark") { CYListRowPreviewBody().themeDomain(.player) }
#Preview("Row · merchant light") { CYListRowPreviewBody().themeDomain(.merchant) }
