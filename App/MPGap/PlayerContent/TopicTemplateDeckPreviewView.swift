import SwiftUI

/// `PC-A-7-2`: Topic template card deck preview (`pages/templatedetail/topic-preview/index`).
/// Uses native `TabView(.page)` + 3D flip (respecting Reduce Motion) + `.safeAreaInset` actions.
public struct TopicTemplateDeckPreviewView: View {
    public let preview: TopicTemplatePreviewData
    public var onViewDetail: () -> Void
    public var onUseTemplate: () -> Void

    @Environment(\.locale) private var locale
    /// R9-PC-A-N1: MP check / clock icons follow Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var checkIconSide: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote) private var clockIconSide: CGFloat = 14
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
                        .font(.title2.bold())

                    ForEach(Array(checkLines.enumerated()), id: \.offset) { _, check in
                        // Round 4 image parity: MP `art/tab/check.svg` (topic-preview/index.wxml:40).
                        Label {
                            Text(verbatim: check)
                        } icon: {
                            MPAsset.FeatureIcon.pagesTemplatedetailArtTabCheck.resizable().scaledToFit()
                                .accessibilityHidden(true)
                                .frame(width: checkIconSide, height: checkIconSide)
                        }
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let desc = preview.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, CYSpacing.xs)
                    }
                }
                .padding(.horizontal, CYSpacing.md)
            }
            .padding(.vertical, CYSpacing.md)
        }
        .cyPageTitle("topicPreview.title")
        .safeAreaInset(edge: .bottom) {
            // i18n r1: stacks the two actions when their English titles don't fit side by side.
            CYAdaptiveButtonRow(spacing: CYSpacing.sm) {
                Button(action: onViewDetail) {
                    Text("topicPreview.viewDetail").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if !preview.isReadonly {
                    Button(action: onUseTemplate) {
                        Text("topicPreview.useTemplate").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, CYSpacing.md)
            .padding(.vertical, CYSpacing.sm)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func deckCard(_ card: TopicTemplatePreviewCard) -> some View {
        let isFlipped = flippedCardID == card.id
        Button {
            withAnimation {
                flippedCardID = isFlipped ? nil : card.id
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
            .background(.background.secondary)
            // Cover photo card in a paged deck: clip like a system photo tile.
            .clipShape(.rect(cornerRadius: 12))
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
                Color.secondary.opacity(0.15)
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
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !footLine(card).isEmpty {
                    Text(verbatim: footLine(card))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private func backFace(_ card: TopicTemplatePreviewCard) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(card.title)
                .font(.headline)

            if card.steps.isEmpty {
                Text("topicPreview.cardBackEmpty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(card.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: CYSpacing.xs) {
                        Text(step == "…" ? "" : "\(idx + 1).")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(step)
                            .font(.subheadline)
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
                        .frame(width: clockIconSide, height: clockIconSide)
                }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
