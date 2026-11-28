import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-journey r3: MP `pages/play/components/ai-score-card` (AI 参考分, Figma v5.1 node 47:319) on the stop card.
/// MP layout: score over its label on the leading side, a hairline rule, then the comment over the note.
/// Display only (the MP card has no tap: 最终以商家审核为准), so it is one combined VoiceOver element.
@MainActor struct PlayAIScoreSection: View {
    let card: PlayAIScoreCard

    var body: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    scoreColumn
                    Divider()
                    remarkColumn
                }
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    scoreColumn
                    remarkColumn
                }
            }
            .padding(.vertical, CYSpacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("playx.aiScore.\(card.nodeID)")
        }
    }

    private var scoreText: String {
        card.score.formatted(.number.precision(.fractionLength(0...1)))
    }

    private var scoreColumn: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: scoreText)
                .font(.title.weight(.semibold))
                .monospacedDigit()
            Text("playx.aiScore.label")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var remarkColumn: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            if !card.comment.isEmpty {
                Text(verbatim: card.comment)
                    .font(.subheadline)
            }
            if let note = card.note {
                Text(verbatim: note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("playx.aiScore.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
