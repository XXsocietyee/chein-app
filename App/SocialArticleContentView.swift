import SwiftUI

/// Native selectable text only. The projection contains no URLs or executable markup.
struct SocialArticleContentView: View {
    let article: SocialArticleContent
    init(contents: String) { article = SocialArticleContent(contents) }
    var body: some View {
        Group {
            if article.blocks.isEmpty { ContentUnavailableView("social.guide.noContent", systemImage: "doc.text") }
            ForEach(Array(article.blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("social.article.block.\(index)")
            }
            if article.isLimited {
                Label("social.article.limited", systemImage: "scissors")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("social.article.limited")
            }
        }
    }
    @ViewBuilder private func blockView(_ block: SocialArticleContent.Block) -> some View {
        switch block.kind {
        case .paragraph: text(block)
        case .heading(let level):
            text(block).font(level <= 2 ? Font.title3.weight(.semibold) : Font.headline)
                .accessibilityAddTraits(.isHeader)
        case .listItem(let marker, let depth):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: marker)
                text(block)
            }.padding(.leading, CGFloat(min(depth, 4)) * 12)
                .accessibilityElement(children: .combine)
        case .quote:
            text(block).padding(.leading, 12).foregroundStyle(.secondary)
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
