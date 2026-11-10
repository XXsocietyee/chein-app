import SwiftUI

/// Native selectable text only. The projection contains no URLs or executable markup.
struct SocialArticleContentView: View {
    let article: SocialArticleContent
    @Environment(\.cyPalette) private var palette
    init(contents: String) { article = SocialArticleContent(contents) }
    var body: some View {
        Group {
            if article.blocks.isEmpty { CYEmptyState(systemImage: "doc.text", "social.guide.noContent") }
            ForEach(Array(article.blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("social.article.block.\(index)")
            }
            if article.isLimited {
                CYStatusChip("social.article.limited", tone: .neutral, systemImage: "scissors")
                    .accessibilityIdentifier("social.article.limited")
            }
        }
    }
    @ViewBuilder private func blockView(_ block: SocialArticleContent.Block) -> some View {
        switch block.kind {
        case .paragraph: text(block).font(CYTypography.body).foregroundStyle(palette.textPrimary)
        case .heading(let level):
            text(block).font(level <= 2 ? CYTypography.sectionTitle : CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
        case .listItem(let marker, let depth):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: marker)
                text(block)
            }.font(CYTypography.body).foregroundStyle(palette.textPrimary).padding(.leading, CGFloat(min(depth, 4)) * 12)
                .accessibilityElement(children: .combine)
        case .quote:
            text(block).font(CYTypography.body).padding(.leading, CYSpacing.md).foregroundStyle(palette.textSecondary)
        }
    }
    private func text(_ block: SocialArticleContent.Block) -> Text {
        block.runs.reduce(Text(verbatim: "")) { result, run in
            var span = Text(verbatim: run.text)
            if run.bold { span = span.bold() }
            if run.italic { span = span.italic() }
            return result + span
        }
    }
}
