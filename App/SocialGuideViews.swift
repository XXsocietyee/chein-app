import SwiftUI

@MainActor struct SocialPlayGuideView: View {
    let reader: any SocialAccountReading
    var onOpenDestination: ((SocialGuideDestination) -> Void)? = nil
    var templateReader: (any DiscoveryReading)? = nil
    var informationDestination: ((SocialInformation) -> AnyView)? = nil
    var body: some View {
        List {
            Section { SocialGuideXcxHero() }
            Section {
                ForEach(SocialGuideMode.allCases) { mode in
                    SocialGuideXcxModeRow(mode: mode, onOpen: onOpenDestination)
                        .listRowInsets(EdgeInsets(top: 6, leading: CYSpacing.lg, bottom: 6, trailing: CYSpacing.lg))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            } header: { Text("social.guide.modes") }
            SocialGuideTemplateSection(reader: templateReader)
            Section {
                SocialReadScreen(reader: reader, requestKey: "information-list", load: { try await reader.informationList() }) { rows in
                    if rows.isEmpty {
                        CYEmptyState(systemImage: "doc.text", "guideXcx.docsEmpty", detail: "guideXcx.docsEmptyDetail", messageIdentifier: "social.guide.docsEmpty")
                            .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                    }
                    ForEach(rows) { row in
                        NavigationLink {
                            if let informationDestination { informationDestination(row) }
                            else { AnyView(SocialInformationView(id: row.id, reader: reader)) }
                        } label: {
                            CYListRow(verbatim: row.title, meta: row.summary, trailing: .none) { SocialInformationArt(id: row.id).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                        }.accessibilityIdentifier("social.information.\(row.id)")
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("guideXcx.docs")
                    Text("guideXcx.docsHint").font(.caption).textCase(nil)
                }
            }
        }.appNavigationTitle("social.guide.title").accessibilityIdentifier("social.guide")
    }
}
@MainActor struct SocialInformationView: View {
    let id: Int
    let reader: any SocialAccountReading
    var body: some View {
        List {
            if id <= 0 { CYEmptyState(systemImage: "link", "social.incompleteLink") }
            else {
                SocialReadScreen(reader: reader, requestKey: "information-\(id)", load: { try await reader.information(id: id) }) { row in
                    if row.isRemoved { CYEmptyState(systemImage: "doc", "social.guide.removed") }
                    else {
                        SocialInformationCover(id: row.id, title: row.title, created: SocialText.nonempty(row.createTime))
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                        if let summary = row.summary { Text(verbatim: summary).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).listRowBackground(Color.clear) }
                        if let contents = row.contents { SocialArticleContentView(contents: contents) }
                        else { CYEmptyState(systemImage: "doc.text", "social.guide.noContent") }
                    }
                }
            }
        }
        .appNavigationTitle("guideXcx.detailTitle")
        .navigationBarTitleDisplayMode(.inline)
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
    private var tones: [Color] {
        switch abs(id) % 3 {
        case 0: return [Color(red: 0.10, green: 0.16, blue: 0.30), Color(red: 0.16, green: 0.36, blue: 0.42)]
        case 1: return [Color(red: 0.30, green: 0.16, blue: 0.14), Color(red: 0.46, green: 0.30, blue: 0.16)]
        default: return [Color(red: 0.09, green: 0.22, blue: 0.20), Color(red: 0.14, green: 0.18, blue: 0.34)]
        }
    }
    var body: some View {
        LinearGradient(colors: tones, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: large ? .topTrailing : .center) {
                Image(systemName: "text.book.closed").font(large ? .system(size: 56, weight: .thin) : .title3.weight(.light))
                    .foregroundStyle(.white.opacity(large ? 0.25 : 0.7)).padding(large ? CYSpacing.lg : 0)
            }
            .accessibilityHidden(true)
    }
}

/// Article header: art banner with eyebrow, large title and date over a bottom scrim.
struct SocialInformationCover: View {
    let id: Int
    let title: String
    let created: String?
    var body: some View {
        SocialInformationArt(id: id, large: true).frame(minHeight: 260)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("guideXcx.detailTitle").font(.caption.weight(.semibold)).textCase(.uppercase).opacity(0.8)
                    Text(verbatim: title).font(.largeTitle.weight(.semibold)).lineLimit(4).minimumScaleFactor(0.8)
                    if let created { Text(verbatim: created).font(CYTypography.meta).opacity(0.8).accessibilityIdentifier("social.information.createTime") }
                }
                .foregroundStyle(.white).padding(CYSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            }
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}
