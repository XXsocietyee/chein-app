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
    private let title: Text
    private let meta: Text?
    private let trailing: CYListRowTrailing
    private let card: Bool
    private let leading: Leading

    @Environment(\.cyPalette) private var palette

    init(
        _ title: LocalizedStringKey,
        meta: LocalizedStringKey? = nil,
        trailing: CYListRowTrailing = .chevron,
        card: Bool = false,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = Text(title)
        self.meta = meta.map { Text($0) }
        self.trailing = trailing
        self.card = card
        self.leading = leading()
    }

    /// Server-supplied titles stay verbatim. They are not looked up as catalog keys.
    init(
        verbatim title: String,
        meta: String? = nil,
        trailing: CYListRowTrailing = .chevron,
        card: Bool = false,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = Text(verbatim: title)
        self.meta = meta.map { Text(verbatim: $0) }
        self.trailing = trailing
        self.card = card
        self.leading = leading()
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
                title
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                if let meta {
                    meta
                        .font(CYTypography.meta)
                        .foregroundStyle(palette.textTertiary)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            trailingView
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .none: EmptyView()
        case .chevron: chevron
        case .value(let value): valueText(value)
        case .valueChevron(let value):
            HStack(spacing: CYSpacing.xs) { valueText(value); chevron }
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
