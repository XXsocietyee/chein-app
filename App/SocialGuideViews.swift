import SwiftUI

@MainActor struct SocialPlayGuideView: View {
    let reader: any SocialAccountReading
    var onOpenDestination: ((SocialGuideDestination) -> Void)? = nil
    var templateReader: (any DiscoveryReading)? = nil
    var informationDestination: ((SocialInformation) -> AnyView)? = nil
    var body: some View {
        List {
            Section { SocialGuideXcxHero() }
            Section("social.guide.modes") {
                ForEach(SocialGuideMode.allCases) { mode in SocialGuideXcxModeRow(mode: mode, onOpen: onOpenDestination) }
            }
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
                            CYListRow(verbatim: row.title, meta: row.summary, trailing: .none) { CYRowIcon(systemImage: "doc.text") }
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
                        CYHeroHeader(verbatim: row.title).listRowBackground(Color.clear).listRowSeparator(.hidden)
                        if let created = SocialText.nonempty(row.createTime) { Text(verbatim: created).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("social.information.createTime").listRowBackground(Color.clear) }
                        if let summary = row.summary { Text(verbatim: summary).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).listRowBackground(Color.clear) }
                        if let contents = row.contents { SocialArticleContentView(contents: contents) }
                        else { CYEmptyState(systemImage: "doc.text", "social.guide.noContent") }
                    }
                }
            }
        }
        .cyGroupedSurface()
        .appNavigationTitle("guideXcx.detailTitle")
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainPageBackground()
        .themeDomain(.player)
        .tint(CYDomainPalette(.player).brand)
        .accessibilityIdentifier("social.information.detail")
    }
}
