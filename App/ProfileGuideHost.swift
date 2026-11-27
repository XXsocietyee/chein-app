import SwiftUI

/// One stable guide owner; pushing an article preserves its accepted-list receipt.
@MainActor struct ProfileGuideHost: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var reader: ProfileGuideListReader?
    let makeArticleReader: (ProfileGuideArticleSelection) -> ProfileGuideArticleReader
    var onOpenDestination: ((SocialGuideDestination) -> Void)? = nil
    var templateReader: (any DiscoveryReading)? = nil
    init(reader: ProfileGuideListReader?, makeArticleReader: @escaping (ProfileGuideArticleSelection) -> ProfileGuideArticleReader,
         onOpenDestination: ((SocialGuideDestination) -> Void)? = nil, templateReader: (any DiscoveryReading)? = nil) {
        _reader = State(initialValue: reader); self.makeArticleReader = makeArticleReader
        self.onOpenDestination = onOpenDestination; self.templateReader = templateReader
    }
    var body: some View {
        ZStack {
            if let reader {
                if reader.hasAppeared {
                    SocialPlayGuideView(reader: reader, onOpenDestination: onOpenDestination, templateReader: templateReader,
                        informationDestination: { row in AnyView(ProfileGuideArticleDestination(row: row, reader: reader, makeReader: makeArticleReader)) })
                        .socialGuideSessionCatalog(templateReader as? AppSession)
                } else { ProgressView("social.loading") }
            } else { SocialIssueView(error: APIError.unauthorized) }
        }
        .onAppear { reader?.appear(foreground: scenePhase == .active) }
        .onDisappear { reader?.disappear() }
        .onChange(of: scenePhase) { _, phase in reader?.setForeground(phase == .active) }
        .refreshable { reader?.refresh() }
    }
}

@MainActor struct ProfileGuideArticleDestination: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var reader: ProfileGuideArticleReader?
    init(row: SocialInformation, reader: ProfileGuideListReader, makeReader: (ProfileGuideArticleSelection) -> ProfileGuideArticleReader) {
        _reader = State(initialValue: reader.select(row).map(makeReader))
    }
    var body: some View {
        ZStack {
            if let reader {
                if reader.hasAppeared { SocialInformationView(id: reader.selection.row.id, reader: reader) }
                else { ProgressView("social.loading") }
            } else { SocialIssueView(error: SocialActionBlock.changed) }
        }
        .onAppear { reader?.appear(foreground: scenePhase == .active) }
        .onDisappear { reader?.disappear() }
        .onChange(of: scenePhase) { _, phase in reader?.setForeground(phase == .active) }
    }
}

private struct SocialGuideTemplateCatalogKey: EnvironmentKey { static let defaultValue: (@MainActor () -> AnyView)? = nil }
extension EnvironmentValues {
    /// R7-PC-A2-7: the guide's 更多玩法 catalog as the full template tab (应用 / 发布 / 搜索). Nil keeps the read-only browser.
    var socialGuideTemplateCatalog: (@MainActor () -> AnyView)? {
        get { self[SocialGuideTemplateCatalogKey.self] }
        set { self[SocialGuideTemplateCatalogKey.self] = newValue }
    }
}
extension View {
    /// Same factories as the `pages/template/index` route (MPReviewedPageScreen).
    @MainActor func socialGuideSessionCatalog(_ session: AppSession?) -> some View {
        environment(\.socialGuideTemplateCatalog, session.map { session in
            {
                AnyView(DiscoveryTemplateBrowserView(
                    reader: session,
                    authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                    authoringRevision: session.sessionRevision,
                    authoringCompletion: session.templateAuthoringCompletionContext,
                    publishDestination: {
                        AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch))
                    },
                    searchDestination: { AnyView(SessionLinkedSearchView().environmentObject(session)) }
                ).id(session.templateAuthoringViewIdentity))
            }
        })
    }
}
