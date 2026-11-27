import SwiftUI

/// `PC-A-7-2`: Topic template card deck preview (`pages/templatedetail/topic-preview/index`).
/// Uses native `TabView(.page)` + 3D flip (respecting Reduce Motion) + `.safeAreaInset` actions.
public struct TopicTemplateDeckPreviewView: View {
    public let preview: TopicTemplatePreviewData
    public var onViewDetail: () -> Void
    public var onUseTemplate: () -> Void
    /// MP topic-preview `intro.chapters` (intro.js `buildIntro`): named chapters, each with its short guide.
    public var introChapters: [TopicTemplateIntroChapter] = []

    @Environment(\.locale) private var locale
    /// R9-PC-A-N1: MP check / clock icons follow Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var checkIconSide: CGFloat = 18
    @ScaledMetric(relativeTo: .footnote) private var clockIconSide: CGFloat = 14
    @State private var selectedIndex = 0
    @State private var flippedCardID: String?

    public init(
        preview: TopicTemplatePreviewData,
        onViewDetail: @escaping () -> Void,
        onUseTemplate: @escaping () -> Void,
        introChapters: [TopicTemplateIntroChapter] = []
    ) {
        self.introChapters = introChapters
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

                    // mp-r3-publish: MP `tp-intro__ch` — each chapter's heading (第一章 · name / 终章) and its guide.
                    ForEach(Array(introChapters.enumerated()), id: \.element.id) { index, chapter in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: chapterHeading(index, count: introChapters.count, name: chapter.name))
                                .font(.subheadline.weight(.semibold))
                            if !chapter.guide.isEmpty {
                                Text(verbatim: chapter.guide)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .padding(.top, index == 0 ? CYSpacing.xs : 0)
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

    /// MP intro.js `heading`: a name that already says which chapter it is stays as it is; otherwise 第N章 · name,
    /// and the last of three or more is 终章.
    private func chapterHeading(_ index: Int, count: Int, name: String) -> String {
        let selfOrdinal = #"^(第\s*[0-9一二三四五六七八九十百零两]+\s*章|结局|终章|序章|尾声)"#
        if name.range(of: selfOrdinal, options: .regularExpression) != nil { return name }
        let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        let isFinal = index == count - 1 && count > 2
        let zhLead = isFinal ? "终章" : "第" + (index < numerals.count ? numerals[index] : String(index + 1)) + "章"
        let enLead = isFinal ? "Final chapter" : "Chapter \(index + 1)"
        let lead = locale.pick(zhLead, enLead)
        return name.isEmpty ? lead : lead + " · " + name
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
            .clipShape(.rect(cornerRadius: CYRadius.card))
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

/// One chapter line of the topic-template preview intro (MP topic-preview/intro.js).
public struct TopicTemplateIntroChapter: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let guide: String
    public init(id: String, name: String, guide: String) {
        self.id = id
        self.name = name
        self.guide = guide
    }

    /// MP intro.js `guide`: the chapter description up to the first puzzle marker, whitespace collapsed, at most
    /// 60 characters (cut at the last sentence end when that keeps 12+ characters, else trimmed with an ellipsis).
    public static func guide(_ raw: String?) -> String {
        var text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let puzzleMark = #"【\s*(题目|观察位置|谜题|提示|线索|密码表?|密文|答案)[^】]*】|(?:^|\s)(?:题目|观察位置)[:：]|密码表|对照表|[A-Z]\s*=\s*\d"#
        if let range = text.range(of: puzzleMark, options: .regularExpression) {
            text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard text.count > 60 else { return text }
        let head = String(text.prefix(60))
        if let cut = head.lastIndex(where: { "。！？.".contains($0) }), head.distance(from: head.startIndex, to: cut) >= 12 {
            return String(head[...cut])
        }
        return head.replacingOccurrences(of: #"[，,、；;\s]+$"#, with: "", options: .regularExpression) + "…"
    }
}
