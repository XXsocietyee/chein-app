#if DEBUG
import SwiftUI

/// D7 design fixtures (synthetic data, debug only): publish tab sheet, publish menu, template browser and detail.
/// All reuse the real views with the existing offline fixture readers; themed as the player domain (dark).
enum PublishDesignFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "publish-sheet": return wrap(sheet(#"{"role":"club","quota":{"themesRemaining":3}}"#))
        case "publish-sheet-locked": return wrap(sheet(nil))
        case "publish-sheet-quota": return wrap(sheet(#"{"role":"player","quota":{"themesRemaining":0}}"#))
        case "publish-menu": return wrap(PublishingModesFixtureHost())
        case "publish-menu-pro":
            return wrap(NavigationStack {
                PublishingModesView(service: nil, account: nil, placeSearch: nil, openProfessional: { _ in }, openResource: { _ in },
                                    makeProfessional: { _ in AnyView(EmptyView()) }, makeTemplateAuthoring: { AnyView(EmptyView()) })
            })
        case "publish-projects":
            return wrap(NavigationStack { PublishingProjectsView(service: nil, account: nil, openResource: { _ in }) })
        case "publish-projects-rows", "publish-projects-empty", "publish-projects-loading":
            let mode = name.hasSuffix("rows") ? "rows" : name.hasSuffix("empty") ? "empty" : "loading"
            return wrap(NavigationStack { PublishingProjectsView(service: nil, account: nil, openResource: { _ in }, designPreview: mode) })
        case "publish-quick":
            return wrap(NavigationStack { QuickPublishingView(placeSearch: nil, account: nil, openProfessional: { _ in }) })
        case "publish-activity":
            return wrap(NavigationStack { ActivityPublishingView(service: nil, account: nil, placeSearch: nil) })
        case "rep3-merchant-publish":
            return wrapMerchant(NavigationStack { ActivityPublishingView(service: nil, account: nil, placeSearch: nil) })
        case "rep3-merchant-publish-missing":
            return wrapMerchant(NavigationStack { Rep3MerchantPublishMissingHost() })
        case "template-topics": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: DiscoveryFixtureReader()) })
        case "template-games": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: DiscoveryFixtureReader(), startOnGames: true) })
        case "template-detail":
            return wrap(NavigationStack { DiscoveryTemplateDetailView(id: 7, reader: TemplateDetailParityFixtureReader(scenario: "public")) })
        case "topic-preview":
            // Synthetic public topic template (PublicTopicTemplateFixtures), debug only.
            let coordinator = PublicTopicTemplateCoordinator(id: 801) { _ in
                try JSONDecoder().decode(PublicTopicTemplateDetail.self, from: Data(PublicTopicTemplateFixtures.content(merchant: false).utf8))
            }
            return wrap(NavigationStack { DiscoveryTopicTemplatePreview(coordinator: coordinator) })
        case "publish-cover":
            return wrap(NavigationStack { Form { Section { ActivityCoverAuthoringSection(owner: ActivityCoverAuthoringOwner()) } header: { CYSectionHeader("publishModes.coverSection") } }
                .scrollContentBackground(.hidden).navigationTitle(Text(verbatim: "Cover (debug fixture)")).navigationBarTitleDisplayMode(.inline) })
        case "publish-template-select":
            let owner = ActivityTemplateSelectionOwner()
            let rows = [(1, "Sample city walk (debug fixture)", ""), (2, "Sample museum trail (debug fixture)", ""), (3, "Sample album template (debug fixture)", #","advancedConfigJson":"{}""#)]
                .compactMap { try? ActivityTemplateChoice(JSONDecoder().decode(ProjectEditJSON.self, from: Data(#"{"id":\#($0.0),"title":"\#($0.1)"\#($0.2)}"#.utf8))) }
            owner.designPreviewRows(rows, selected: 1)
            return wrap(NavigationStack { Form { ActivityTemplateSelectionSection(owner: owner, apply: { _ in true }, createAvailable: true) }
                .scrollContentBackground(.hidden).navigationTitle(Text(verbatim: "Template (debug fixture)")).navigationBarTitleDisplayMode(.inline) })
        case "publish-timerange":
            let draft = ActivityPublishingTimeRangeDraft(source: ActivityPublishDraft(), now: Date())!
            let presentation = ActivityPublishingTimeRangeOwner.Presentation(generation: UUID(), source: Data(), draft: draft, timeZoneID: TimeZone.autoupdatingCurrent.identifier)
            var sheet = ActivityPublishingTimeRangeSheet(owner: ActivityPublishingTimeRangeOwner(), original: presentation, apply: { _ in true })
            sheet.designPreview = true
            return wrap(sheet)
        default: return nil
        }
    }

    /// Synthetic rows, clearly labelled as a debug fixture (titles start with "Sample").
    static var sampleProjects: [PublishingProject] {
        let rows = [
            #"{"bizType":"topic","id":9001,"title":"Sample topic (debug fixture)","state":"running","stateText":"Online","publishStatus":"online","ownerType":"member","signupCount":0}"#,
            #"{"bizType":"activity","id":9002,"title":"Sample activity with a rather long title that wraps (debug fixture)","state":"notStarted","stateText":"Not started","publishStatus":"online","ownerType":"club","signupCount":12}"#,
            #"{"bizType":"topic","id":9003,"title":"Sample draft (debug fixture)","state":"draft","stateText":"Draft","ownerType":"member","signupCount":0}"#,
            #"{"bizType":"template","id":9004,"title":"Sample template (debug fixture)","state":"rejected","stateText":"Rejected","ownerType":"member","signupCount":0}"#,
        ]
        return rows.compactMap { try? JSONDecoder().decode([String: ProjectEditJSON].self, from: Data($0.utf8)) }.compactMap { try? PublishingProject($0) }
    }

    @MainActor private static func sheet(_ capabilityJSON: String?) -> some View {
        let capability = capabilityJSON.flatMap { try? JSONDecoder().decode([String: ProjectEditJSON].self, from: Data($0.utf8)) }.map(PublishingCapability.init)
        return PublishTabFloatingSheetView(presentation: PublishTabFloatingSheetParity.presentation(capability: capability), onSelectAction: { _ in })
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player))
    }

    @MainActor private static func wrapMerchant<V: View>(_ view: V) -> AnyView {
        AnyView(view.cyDomainScreen(.merchant).preferredColorScheme(.light))
    }
}

/// Non-happy Merchant LIGHT publish fixture showing missing-field blockers, failed draft save, and preview summary.
@MainActor private struct Rep3MerchantPublishMissingHost: View {
    @State private var step = 0
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale

    var body: some View {
        let issues = [
            CYPublishValidationIssue(id: "name", stepIndex: 0, message: "请填写活动标题"),
            CYPublishValidationIssue(id: "description", stepIndex: 1, message: "请补充活动内容与封面"),
            CYPublishValidationIssue(id: "ticket", stepIndex: 2, message: "请至少配置 1 种有效票券")
        ]
        var draft = ActivityPublishDraft()
        draft.addressName = "西湖茶室集合点（示例）"
        return ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                ActivityPublishingWizardChrome(
                    step: step,
                    block: "name",
                    issues: issues,
                    saveState: .saveFailed(reason: "本地草稿保存失败（离线只读示例）", onRetry: {}),
                    isSubmittingReview: false,
                    onSelectStep: { step = $0 },
                    onSubmitReview: {}
                )
                ActivityPublishingReviewSummaryCard(
                    summary: ActivityPublishingWizard.reviewSummary(draft: draft),
                    merchantHost: true
                )
            }
            .padding(CYSpacing.pageHorizontal)
        }
        .background(palette.bgPage)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CYFooterBar {
                ActivityPublishingWizardNavigation(step: step, enabled: true, onCancel: {}, onBack: { step = max(0, step - 1) }, onNext: { step = min(2, step + 1) }, onReview: {})
            }
        }
        .navigationTitle(Text("publishModes.activity"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
