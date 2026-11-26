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

/// Button style for interactive `CYListRow` cells (native r2): the label as-is with the system's dim on press,
/// the same feedback as `.buttonStyle(.plain)`. `cornerRadius` is kept for call sites only.
struct CYListRowButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
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

    /// Native r2: a system row. `Label` (title + secondary subtitle, leading icon) inside `LabeledContent` when
    /// there is a trailing value; the disclosure is the system chevron symbol in `.tertiary`. No custom
    /// heights, fills, dividers or press tracking: inside a `List` the system draws separators and highlight.
    /// `card: true` keeps the shared card surface (`cyDomainCard`, system grouped secondary background).
    var body: some View {
        if card {
            row
                .cyDomainCard(padding: CYSpacing.lg)
        } else {
            row
                .padding(.horizontal, horizontalPad ?? 0)
        }
    }

    private var row: some View {
        HStack(spacing: CYSpacing.sm) {
            LabeledContent {
                if let trailingValue {
                    Text(verbatim: trailingValue)
                        .monospacedDigit()
                }
            } label: {
                labelView
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(tone == .danger ? AnyShapeStyle(Color.red) : AnyShapeStyle(.primary))
        .opacity(effectiveDisabled ? 0.4 : 1)
        .contentShape(Rectangle())
        // One VoiceOver stop per row: "title, meta, value".
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var labelView: some View {
        if Leading.self == EmptyView.self {
            textStack
        } else {
            Label {
                textStack
            } icon: {
                leading
            }
        }
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleText
            if let verbatimMeta {
                Text(verbatim: verbatimMeta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let meta {
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var showsChevron: Bool {
        switch trailing {
        case .chevron, .valueChevron: return true
        default: return false
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
}

extension CYListRow where Leading == EmptyView {
    init(_ title: LocalizedStringKey, meta: LocalizedStringKey? = nil, trailing: CYListRowTrailing = .chevron, card: Bool = false) {
        self.init(title, meta: meta, trailing: trailing, card: card) { EmptyView() }
    }
    init(verbatim title: String, meta: String? = nil, trailing: CYListRowTrailing = .chevron, card: Bool = false) {
        self.init(verbatim: title, meta: meta, trailing: trailing, card: card) { EmptyView() }
    }
}

/// Leading icon of a `CYListRow` (native r2): the plain SF Symbol a `Label` shows in Settings-style rows,
/// tinted with the system accent. No tile behind it.
struct CYRowIcon: View {
    let systemImage: String
    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
}

private struct CYListRowPreviewBody: View {
    var body: some View {
        List {
            CYListRow("Wallet", meta: "Balance and coupons", trailing: .valueChevron("¥128.50")) {
                CYRowIcon(systemImage: "creditcard")
            }
            CYListRow("Tickets", meta: "3 active") { CYRowIcon(systemImage: "ticket") }
            CYListRow("Orders", trailing: .value("—"))
        }
    }
}
#Preview("Row") { CYListRowPreviewBody() }
