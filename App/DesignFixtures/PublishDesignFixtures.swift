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
            return wrapCreator(NavigationStack { QuickPublishingView(placeSearch: nil, account: nil, openProfessional: { _ in }) })
        case "publish-activity":
            return wrapCreator(NavigationStack { ActivityPublishingView(service: nil, account: nil, placeSearch: nil) })
        case "rep3-merchant-publish":
            return wrapMerchant(NavigationStack { ActivityPublishingView(service: nil, account: nil, placeSearch: nil) })
        case "rep3-merchant-publish-missing":
            return wrapMerchant(NavigationStack { Rep3MerchantPublishMissingHost() })
        case "t11-fabu":
            return wrapCreator(NavigationStack { T11ProjectEditFixtureHost(signedIn: true) })
        case "t11-fabu-blocked":
            return wrapCreator(NavigationStack { T11ProjectEditFixtureHost(signedIn: false) })
        case "t11-quick-ai":
            return wrapCreator(PublishingAIDraftSheet(client: nil, product: .city, initialIdea: "示例：西湖苏堤夜游漫步（设计预览）", accept: { _ in }))
        case "t11-quick-error":
            return wrapCreator(NavigationStack { QuickPublishingView(placeSearch: nil, account: nil, openProfessional: { _ in }).disabled(true) })
        case "t11-template-author":
            return wrapCreator(NavigationStack { T11TemplateAuthorFixtureHost(signedIn: true) })
        case "t11-template-author-locked":
            return wrapCreator(NavigationStack { T11TemplateAuthorFixtureHost(signedIn: false) })
        case "t11-template-intro":
            return wrapCreator(NavigationStack { T11TemplateIntroFixtureHost(configured: true) })
        case "t11-template-intro-empty":
            return wrapCreator(NavigationStack { T11TemplateIntroFixtureHost(configured: false) })
        case "t11-activity-locked":
            return wrapCreator(NavigationStack { ActivityPublishingView(service: nil, account: nil, placeSearch: nil).disabled(true) })
        case "t11-coupon-create":
            return wrapCreator(CouponManagementFixtureHost(showsHarness: false))
        case "t11-coupon-unknown":
            return wrapCreator(NavigationStack { CouponManagementView(coordinator: CouponManagementCoordinator(adapter: .init(transport: nil, syntheticWritesEnabled: false), authorizer: CouponPublisherUnavailable(), locks: CouponManagementAppLocks(), currentSession: { nil }), sessionKey: nil, isSourceVisible: true) })
        case "template-topics": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: DiscoveryFixtureReader()) })
        case "template-topics-offline": return wrap(NavigationStack { DiscoveryTemplateBrowserView(reader: DiscoveryFixtureReader(scenario: .unconfigured)) })
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
                .scrollContentBackground(.hidden).navigationTitle(Text(verbatim: "封面设置（设计预览）")).navigationBarTitleDisplayMode(.inline) })
        case "publish-template-select":
            let owner = ActivityTemplateSelectionOwner()
            let rows = [(1, "示例：西湖夜游漫步（设计预览）", #","players":"2-4人","duration":45"#), (2, "示例：运河博物寻踪（设计预览）", #","players":"3人""#), (3, "示例：老街图集模板（设计预览）", #","advancedConfigJson":"{}""#)]
                .compactMap { try? ActivityTemplateChoice(JSONDecoder().decode(ProjectEditJSON.self, from: Data(#"{"id":\#($0.0),"title":"\#($0.1)"\#($0.2)}"#.utf8))) }
            owner.designPreviewRows(rows, selected: 1)
            return wrap(NavigationStack { Form { ActivityTemplateSelectionSection(owner: owner, apply: { _ in true }, createAvailable: true) }
                .scrollContentBackground(.hidden).navigationTitle(Text(verbatim: "模板选择（设计预览）")).navigationBarTitleDisplayMode(.inline) })
        // fix/r3-account-publish-b: the pass reveal with the MP key frame sheets (paid plays the full intro every time).
        case "fr3-pass-reveal-paid":
            return wrap(NavigationStack { PassRevealView(paid: PassRevealPaidFacts(count: 12, untilText: "2027-11-24"), accountKey: "fixture") })
        case "fr3-pass-reveal-first":
            return wrap(NavigationStack { PassRevealView(paid: nil, accountKey: "fixture-\(UUID().uuidString)") })
        case "publish-timerange":
            let draft = ActivityPublishingTimeRangeDraft(source: ActivityPublishDraft(), now: Date())!
            let presentation = ActivityPublishingTimeRangeOwner.Presentation(generation: UUID(), source: Data(), draft: draft, timeZoneID: TimeZone.autoupdatingCurrent.identifier)
            var sheet = ActivityPublishingTimeRangeSheet(owner: ActivityPublishingTimeRangeOwner(), original: presentation, apply: { _ in true })
            sheet.designPreview = true
            return wrap(sheet)
        default: return nil
        }
    }

    /// Synthetic rows, clearly labelled as a debug fixture.
    static var sampleProjects: [PublishingProject] {
        let rows = [
            #"{"bizType":"topic","id":9001,"title":"示例主题：南宋御街寻踪（设计预览）","state":"running","stateText":"进行中","publishStatus":"online","ownerType":"member","signupCount":0}"#,
            #"{"bizType":"activity","id":9002,"title":"示例活动：良渚古城遗址深度解谜研学长标题换行预览（设计预览）","state":"notStarted","stateText":"未开始","publishStatus":"online","ownerType":"club","signupCount":12}"#,
            #"{"bizType":"topic","id":9003,"title":"示例草稿：北山街建筑故事（设计预览）","state":"draft","stateText":"草稿","ownerType":"member","signupCount":null}"#,
            #"{"bizType":"template","id":9004,"title":"示例模板：宋韵非遗体验（设计预览）","state":"rejected","stateText":"已驳回","ownerType":"member","signupCount":null}"#,
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

    @MainActor private static func wrapCreator<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.topicEditor).cyDomainPageBackground())
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

@MainActor private struct T11ProjectEditFixtureHost: View {
    @StateObject private var state: Holder
    init(signedIn: Bool) { _state = StateObject(wrappedValue: Holder(signedIn: signedIn)) }
    var body: some View { ProjectEditView(coordinator: state.coordinator, sessionRevision: 1) }

    @MainActor private final class Holder: ObservableObject {
        let coordinator: ProjectEditCoordinator
        private let heldSession: ProjectEditSession?
        init(signedIn: Bool) {
            let session = signedIn ? (try? ProjectEditSession(accountID: 901, epoch: 1, storageNamespace: "synthetic-t11-fabu")) : nil
            heldSession = session
            let service = ProjectEditSyntheticService()
            service.snapshot = ProjectEditSyntheticFixtures.snapshot(scope: .full)
            coordinator = ProjectEditCoordinator(
                initial: service.snapshot,
                service: service,
                store: ProjectEditLocalStore(storage: ProjectEditMemoryStorage()),
                currentSession: { session }
            )
        }
    }
}

@MainActor private struct T11TemplateAuthorFixtureHost: View {
    @StateObject private var state: Holder
    init(signedIn: Bool) { _state = StateObject(wrappedValue: Holder(signedIn: signedIn)) }
    var body: some View {
        // CF-44: the cover section with no upload service (as `publish-cover`): the picker is shown, opening is disabled.
        TemplateAuthoringView(coordinator: state.coordinator, sessionRevision: 1, metadataReader: state.reader, makeCoverService: { nil })
    }

    @MainActor private final class Holder: ObservableObject {
        let coordinator: TemplateAuthoringCoordinator
        let reader = DiscoveryFixtureReader()
        init(signedIn: Bool) {
            let session = signedIn ? (try? TemplateAuthoringSession(accountID: 901, namespace: "synthetic-t11-temp", epoch: 1, authorizationRevision: "member-fixture")) : nil
            let coord = TemplateAuthoringCoordinator(
                adapter: .init(transport: TemplateAuthoringSyntheticTransport()),
                store: TemplateAuthoringLocalStore(storage: TemplateAuthoringMemoryStorage()),
                currentSession: { session }
            )
            coord.open(seed: TemplateAuthoringSyntheticFixtures.draft())
            self.coordinator = coord
        }
    }
}

@MainActor private struct T11TemplateIntroFixtureHost: View {
    @StateObject private var state = Holder()
    let configured: Bool
    var body: some View {
        Form {
            Section {
                TemplateAuthoringIntroExperience(model: state.model, reader: configured ? state.reader : nil, onContinue: {})
            }
        }
        .formStyle(.grouped)
        .cyGroupedSurface()
        .cyDomainScreen(.topicEditor)
    }

    @MainActor private final class Holder: ObservableObject {
        let model: TemplateAuthoringModel
        let reader = DiscoveryFixtureReader()
        init() {
            let session = try? TemplateAuthoringSession(accountID: 901, namespace: "synthetic-t11-intro", epoch: 1, authorizationRevision: "member-fixture")
            let coord = TemplateAuthoringCoordinator(
                adapter: .init(transport: TemplateAuthoringSyntheticTransport()),
                store: TemplateAuthoringLocalStore(storage: TemplateAuthoringMemoryStorage()),
                currentSession: { session }
            )
            coord.open(seed: TemplateAuthoringSyntheticFixtures.draft())
            self.model = TemplateAuthoringModel(coordinator: coord)
        }
    }
}
#endif
