import SwiftUI

@MainActor struct SocialPlayGuideView: View {
    let reader: any SocialAccountReading
    var onOpenDestination: ((SocialGuideDestination) -> Void)? = nil
    var templateReader: (any DiscoveryReading)? = nil
    var informationDestination: ((SocialInformation) -> AnyView)? = nil
    var body: some View {
        List {
            // Mini-program order: the three mode cards right under 城瘾玩法 (no hero line, no section title),
            // then 现成玩法, then 玩法文档.
            Section {
                ForEach(SocialGuideMode.allCases) { mode in
                    SocialGuideXcxModeRow(mode: mode, onOpen: onOpenDestination)
                        .listRowInsets(EdgeInsets(top: 6, leading: CYSpacing.lg, bottom: 6, trailing: CYSpacing.lg))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            }
            SocialGuideTemplateSection(reader: templateReader)
            Section {
                SocialReadScreen(reader: reader, requestKey: "information-list", load: { try await reader.informationList() }) { decoded in
                    // PlayGuideInformationListPage keeps only usable rows; an all-unusable list is the empty phase.
                    let rows = decoded.filter(\.isUsable)
                    if rows.isEmpty {
                        CYEmptyState(systemImage: "tray", "guideXcx.docsEmpty", messageIdentifier: "social.guide.docsEmpty")
                            .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                    }
                    ForEach(rows) { row in
                        NavigationLink {
                            if let informationDestination { informationDestination(row) }
                            else { AnyView(SocialInformationView(id: row.id, reader: reader)) }
                        } label: {
                            CYListRow(verbatim: row.title, meta: row.summary, trailing: .none) { SocialInformationArt(id: row.id).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)) }
                        }.accessibilityIdentifier("social.information.\(row.id)")
                    }
                }
            } header: {
                Text("guideXcx.docs")
            }
        }
        .cyDomainPageBackground()
        .cyPageTitle("social.guide.title") // PC-D-2-3
        .accessibilityIdentifier("social.guide")
    }
}
@MainActor struct SocialInformationView: View {
    let id: Int
    let reader: any SocialAccountReading
    @Environment(\.dismiss) private var dismiss
    /// R7-PC-D3-1 (MP infomationdetail.js:90-94 `setNavigationBarTitle(detail.title)`): the bar shows the article title.
    @State private var articleTitle: String?
    var body: some View {
        List {
            // Mini-program missing-param shell: 链接已失效 with one 返回.
            if id <= 0 { CYEmptyState(systemImage: "info.circle", "mp.common.linkExpired", actionTitle: "roamSub.w208.voucher.back", action: { dismiss() }) }
            else {
                SocialReadScreen(reader: reader, requestKey: "information-\(id)", load: { try await reader.information(id: id) }) { row in
                    // subpackageA/pages/infomationdetail: removed, mismatched, or blank documents never render as an article.
                    let page = InformationDetailPageModel(readCapabilityPresent: true, path: InformationDetailPageModel.contractPath,
                                                          requestedID: id, outcome: .article(row))
                    switch page.phase {
                    case .ready(let article):
                        SocialInformationCover(id: article.id, title: article.title, created: page.createTimeDisplay)
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .onAppear { articleTitle = article.title }
                        if let contents = article.contents, page.bodyKey == nil {
                            SocialArticleContentView(contents: contents)
                            // R7-PC-D3-2 (MP infomationdetail.js:116-125 rich-text keeps <img> and <a>): the text renderer stays
                            // literal; the article's https images and links follow it as native blocks.
                            let media = SocialArticleMediaBlocks.extract(contents)
                            if !media.isEmpty {
                                SocialArticleRichBlocksView(blocks: media)
                                    .listRowBackground(Color.clear)
                                    .accessibilityIdentifier("social.article.media")
                            }
                        }
                        else { CYEmptyState(systemImage: "doc.text", LocalizedStringKey(InformationDetailPageModel.Copy.noContent)) }
                    case .empty(.removed):
                        // R7-PC-D3-4 (MP infomationdetail.wxml:21-23): the removed state leads back to the list.
                        CYEmptyState(systemImage: "doc", LocalizedStringKey(InformationDetailPageModel.Copy.removed),
                                     actionTitle: "guideXcx.backToList", action: { dismiss() })
                            .accessibilityIdentifier(page.accessibilityIdentifier ?? "")
                    case .empty(.incompleteLink):
                        CYEmptyState(systemImage: "link", LocalizedStringKey(InformationDetailPageModel.Copy.incompleteLink))
                            .accessibilityIdentifier(page.accessibilityIdentifier ?? "")
                    case .unknown:
                        CYEmptyState(systemImage: "questionmark.folder", LocalizedStringKey(InformationDetailPageModel.Copy.unknown))
                            .accessibilityIdentifier(page.accessibilityIdentifier ?? "")
                    case .loading, .error, nil:
                        EmptyView()
                    }
                }
            }
        }
        .cyGroupedSurface()
        .modifier(SocialInformationTitle(articleTitle: articleTitle))
        .cyDomainPageBackground()
        .themeDomain(.player)
        .tint(CYDomainPalette(.player).brand)
        .accessibilityIdentifier("social.information.detail")
    }
}

/// Decorative generated art for information articles (no remote image in the contract): tonal gradient keyed by id.
struct SocialInformationArt: View {
    let id: Int
    var large = false
    @Environment(\.cyPalette) private var palette
    var body: some View {
        RoundedRectangle(cornerRadius: large ? CYRadius.card : CYRadius.inner, style: .continuous)
            .fill(palette.bgElevated)
            .overlay(alignment: large ? .topTrailing : .center) {
                Image(systemName: abs(id) % 2 == 0 ? "text.book.closed" : "doc.text")
                    .font(large ? .largeTitle.weight(.thin) : .title3.weight(.light))
                    .foregroundStyle(palette.textTertiary)
                    .padding(large ? CYSpacing.lg : 0)
            }
            .accessibilityHidden(true)
    }
}

/// Article header as in `infomationdetail`: title, create time, a hairline, the tutorial disclaimer, a hairline.
struct SocialInformationCover: View {
    let id: Int
    let title: String
    let created: String?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let created {
                    Text(verbatim: created).cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("social.information.createTime")
                }
            }
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
            // R7-PC-D3-5 MP-first: infomationdetail.wxml:30-41 is title + createTime, then the content; no disclaimer row.
            Divider().overlay(CYColor.borderSubtle)
        }
        .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
    }
}

/// R7-PC-D3-1: 玩法详情 while loading, then the article's own title (inline).
private struct SocialInformationTitle: ViewModifier {
    let articleTitle: String?
    func body(content: Content) -> some View {
        if let articleTitle, !articleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.cyPageTitle(verbatim: articleTitle)
        } else {
            content.cyPageTitle("guideXcx.detailTitle")
        }
    }
}

/// R7-PC-D3-2: `<img src>` and `<a href>` from a CMS article, https only, capped. Text stays with `SocialArticleContent`.
enum SocialArticleMediaBlocks {
    static let maximumBlocks = 24
    static func extract(_ html: String) -> [SocialArticleRichBlock] {
        guard html.utf16.count <= 65_536 else { return [] }
        let pattern = #"<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["'][^>]*>|<a\b[^>]*?\bhref\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = html as NSString
        var blocks: [SocialArticleRichBlock] = []
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            if blocks.count >= maximumBlocks { break }
            func group(_ index: Int) -> String? {
                let range = match.range(at: index)
                return range.location == NSNotFound ? nil : ns.substring(with: range)
            }
            if let src = group(1).flatMap(secureURL) {
                blocks.append(.image(id: "img-\(blocks.count)", url: src))
            } else if let href = group(2).flatMap(secureURL) {
                let label = (group(3) ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                blocks.append(.link(id: "a-\(blocks.count)", title: label.isEmpty ? href : String(label.prefix(120)), url: href))
            }
        }
        return blocks
    }
    private static func secureURL(_ raw: String) -> String? {
        let value = raw.replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 2_048, let url = URL(string: value), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return value
    }
}
