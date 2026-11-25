import SwiftUI

/// `PC-A-7-2`: Topic template card deck preview (`pages/templatedetail/topic-preview/index`).
/// Uses native `TabView(.page)` + 3D flip (respecting Reduce Motion) + `.safeAreaInset` actions.
public struct TopicTemplateDeckPreviewView: View {
    public let preview: TopicTemplatePreviewData
    public var onViewDetail: () -> Void
    public var onUseTemplate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var selectedIndex = 0
    @State private var flippedCardID: String?

    public init(
        preview: TopicTemplatePreviewData,
        onViewDetail: @escaping () -> Void,
        onUseTemplate: @escaping () -> Void
    ) {
        self.preview = preview
        self.onViewDetail = onViewDetail
        self.onUseTemplate = onUseTemplate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if !preview.cards.isEmpty {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(preview.cards.enumerated()), id: \.element.id) { index, card in
                            deckCard(card)
                                .padding(.horizontal, CYSpacing.md)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 280)
                }

                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(preview.name)
                        .cyText(.pageTitle)
                        .foregroundStyle(CYColor.textPrimary)

                    ForEach(Array(checkLines.enumerated()), id: \.offset) { _, check in
                        // Round 4 image parity: MP `art/tab/check.svg` (topic-preview/index.wxml:40).
                        Label {
                            Text(verbatim: check)
                        } icon: {
                            MPAsset.FeatureIcon.pagesTemplatedetailArtTabCheck.resizable().scaledToFit()
                                .accessibilityHidden(true)
                                .frame(width: 18, height: 18)
                        }
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                    }

                    if let desc = preview.description, !desc.isEmpty {
                        Text(desc)
                            .cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                            .padding(.top, CYSpacing.xs)
                    }
                }
                .padding(.horizontal, CYSpacing.md)
            }
            .padding(.vertical, CYSpacing.md)
        }
        .background(CYColor.bgPage)
        .cyPageTitle("topicPreview.title")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: CYSpacing.sm) {
                Button("topicPreview.viewDetail", action: onViewDetail)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                if !preview.isReadonly {
                    Button("topicPreview.useTemplate", action: onUseTemplate)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, CYSpacing.md)
            .padding(.vertical, CYSpacing.sm)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func deckCard(_ card: TopicTemplatePreviewCard) -> some View {
        let isFlipped = flippedCardID == card.id
        Button {
            if reduceMotion {
                flippedCardID = isFlipped ? nil : card.id
            } else {
                withAnimation(.spring(duration: 0.35)) {
                    flippedCardID = isFlipped ? nil : card.id
                }
            }
        } label: {
            ZStack {
                if !isFlipped {
                    frontFace(card)
                } else {
                    backFace(card)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYColor.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (isFlipped ? 180 : 0)),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.isCover ? preview.name : card.title)
        .accessibilityHint(Text("topicPreview.tapToFlip"))
    }

    @ViewBuilder
    private func frontFace(_ card: TopicTemplatePreviewCard) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let coverURL = preview.coverURL, !coverURL.isEmpty {
                CYCachedAsyncImage(coverURL, role: .cover)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Round 4 image parity: MP `fc__err` shows `/images/cover-route.svg` centred (topic-preview/index.wxml:21).
                CYColor.coverFallback
                    .overlay {
                        MPAsset.BannerCover.coverRoute
                            .resizable()
                            .scaledToFit()
                            .accessibilityHidden(true)
                            .frame(width: 64, height: 64)
                    }
                    .clipped()
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(card.isCover ? preview.name : card.title)
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                if !footLine(card).isEmpty {
                    Text(verbatim: footLine(card))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func backFace(_ card: TopicTemplatePreviewCard) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(card.title)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)

            if card.steps.isEmpty {
                Text("topicPreview.cardBackEmpty")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
            } else {
                ForEach(Array(card.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: CYSpacing.xs) {
                        Text(step == "…" ? "" : "\(idx + 1).")
                            .cyText(.meta, monospacedDigit: true)
                            .foregroundStyle(CYColor.textSecondary)
                        Text(step)
                            .cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textPrimary)
                    }
                }
            }

            Spacer(minLength: 0)

            if !footLine(card).isEmpty {
                // Round 4 image parity: MP `art/tab/clock.svg` (topic-preview/index.wxml:30).
                Label {
                    Text(verbatim: footLine(card))
                } icon: {
                    MPAsset.FeatureIcon.pagesTemplatedetailArtTabClock.resizable().scaledToFit()
                        .accessibilityHidden(true)
                        .frame(width: 14, height: 14)
                }
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
    }

    /// Catalog `footCopy` / `checkCopies`. An unresolved key keeps the Chinese sentence already on the model.
    private func rendered(_ copy: TopicTemplatePreviewCopy, fallback: String) -> String {
        let format = appLocalized(String.LocalizationValue(copy.key), locale: locale)
        guard format != copy.key else { return fallback }
        guard !copy.arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: copy.arguments.map { $0 as CVarArg })
    }

    private var checkLines: [String] {
        let renderedLines = preview.checkCopies.enumerated().map { index, copy in
            let fallback = preview.checks.indices.contains(index) ? preview.checks[index] : ""
            return rendered(copy, fallback: fallback)
        }.filter { !$0.isEmpty }
        return renderedLines.isEmpty ? preview.checks : renderedLines
    }

    private func footLine(_ card: TopicTemplatePreviewCard) -> String {
        rendered(card.footCopy, fallback: card.footText)
    }
}
