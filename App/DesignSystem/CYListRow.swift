import SwiftUI

/// Trailing accessory of a `CYListRow`.
enum CYListRowTrailing {
    case none
    case chevron
    /// Tabular value (money / counts). Pass "—" for unknown, never 0.
    case value(String)
    case valueChevron(String)
}

/// Row: leading icon or avatar, title, meta line, trailing value/chevron.
/// `card: true` wraps it in the 16pt-radius card surface; otherwise it is a plain row for use inside a List/card.
struct CYListRow<Leading: View>: View {
    private let title: LocalizedStringKey
    private let meta: LocalizedStringKey?
    private let verbatimTitle: String?
    private let verbatimMeta: String?
    private let trailing: CYListRowTrailing
    private let card: Bool
    private let leading: Leading

    @Environment(\.cyPalette) private var palette
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

    var body: some View {
        if card {
            row.cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: CYSpacing.md) {
            leading
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                titleText
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                if let verbatimMeta {
                    Text(verbatim: verbatimMeta)
                        .font(CYTypography.meta)
                        .foregroundStyle(palette.textTertiary)
                } else if let meta {
                    Text(meta)
                        .font(CYTypography.meta)
                        .foregroundStyle(palette.textTertiary)
                }
                // Accessibility sizes: the value moves under the text so the title keeps the full row width.
                if typeSize.isAccessibilitySize, let value = trailingValue { valueText(value) }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            if !typeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
            trailingView
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
        // One VoiceOver stop per row: "title, meta, value". Chevron and icon tile are decorative.
        .accessibilityElement(children: .combine)
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
            .foregroundStyle(palette.textSecondary)
    }
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.textTertiary)
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
    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .frame(width: 40, height: 40)
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
