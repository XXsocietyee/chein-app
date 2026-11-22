#if DEBUG
import SwiftUI

/// HANDOVER 28. DEBUG hosts for screens that had no design fixture: parity-a, G6, the mount-g45
/// batch, be-gap desks, and external-game review. Each name mounts the real view. A missing or
/// unknown fact stays an em dash. Money, payout, merchant writes and password login are not opened.
/// `--design-fixture cur2-<name>`. The table is `docs/release/receipts/ui-cur-fixtures-2.md`.
enum CurFixtures2 {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur2-deeplink": return frame("Deep link · reveal", Cur2LinkHost(page: "subpackagePass/reveal/index"))
        case "cur2-deeplink-unavailable": return frame("Deep link · unavailable", Cur2LinkHost(page: "subpackageMember/market/membership/index"))
        case "cur2-team-report": return frame("Team report · picker", TeamReportReasonSheet(teamID: 4).environment(\.teamOrientBoardAccess, Cur2ReportAccess()))
        case "cur2-team-report-hidden": return page("Team report · no access") { TeamReportEntryButton(teamID: 4) }
        case "cur2-walking-author": return frame("Story walking author · full edit", Cur2EditorHost(full: true))
        case "cur2-walking-author-readonly": return frame("Story walking author · whitelist", Cur2EditorHost(full: false))
        case "cur2-aigc": return page("AIGC label") { Cur2AIGCHost(generated: true) }
        case "cur2-aigc-unlabeled": return page("AIGC · unlabeled") { Cur2AIGCHost(generated: false) }
        case "cur2-g6-promo": return g6("Promotions", Cur2.promo, Cur2PromoHost(activityID: 8))
        case "cur2-g6-promo-empty": return g6("Promotions · empty catalog", Cur2.envelope("{\"offers\":[],\"promotions\":[],\"tiers\":[]}"), Cur2PromoHost(activityID: 8))
        case "cur2-g6-revenue": return g6("Revenue allocations", Cur2.revenue, G6RevenueAllocationsEntry())
        case "cur2-g6-revenue-failed": return g6("Revenue allocations · unavailable", nil, G6RevenueAllocationsEntry())
        case "cur2-g6-characters": return g6("Topic characters", Cur2.npc, Cur2CharactersHost())
        case "cur2-g6-characters-empty": return g6("Topic characters · none", nil, Cur2CharactersHost())
        case "cur2-g6-npc": return npc("NPC prompt", true)
        case "cur2-g6-npc-off": return npc("NPC prompt · flag off", false)
        case "cur2-g6-ai": return g6("AI draft history", Cur2.recovery, G6AIThemeDraftRecoverySection())
        case "cur2-g6-ai-hidden": return page("AI draft history · signed out") { G6AIThemeDraftRecoverySection() }
        case "cur2-square-posts": return square("My posts", SquareMineListView(list: .posts, service: Cur2.square(Cur2.body(Cur2.post)), token: Cur2.token))
        case "cur2-square-posts-failed": return square("My posts · failed", SquareMineListView(list: .posts, service: Cur2.square(Cur2.down()), token: Cur2.token))
        case "cur2-square-bookmarks": return square("Bookmarks", SquareMineListView(list: .bookmarks, service: Cur2.square(Cur2.body(Cur2.post)), token: Cur2.token))
        case "cur2-square-bookmarks-empty": return square("Bookmarks · empty", SquareMineListView(list: .bookmarks, service: Cur2.square(Cur2.body(Cur2.emptyFeed)), token: Cur2.token))
        case "cur2-square-links": return roam("My posts entry", Cur2.body(Cur2.post)) { SquareMineAccountLinks() }
        case "cur2-square-links-hidden": return page("My posts entry · signed out") { SquareMineAccountLinks() }
        case "cur2-safety-summary": return page("Safety summary") { MerchantSafetySummaryRow(merchantID: 12, client: Cur2.player(Cur2.body(Cur2.safetyOK))) }
        case "cur2-safety-summary-hidden": return page("Safety summary · insufficient") { MerchantSafetySummaryRow(merchantID: 12, client: Cur2.player(Cur2.body(Cur2.safetyLow))) }
        case "cur2-correction": return frame("Merchant correction", MerchantCorrectionSheet(merchantID: 12, client: Cur2.player(Cur2.body(Cur2.issues))))
        case "cur2-correction-failed": return frame("Merchant correction · unread", MerchantCorrectionSheet(merchantID: 12, client: Cur2.player(Cur2.down())))
        case "cur2-safety-rating": return frame("Safety rating", MerchantSafetyRatingSheet(merchantID: 12, client: Cur2.player(Cur2.body(Cur2.levels))))
        case "cur2-safety-rating-failed": return frame("Safety rating · unread", MerchantSafetyRatingSheet(merchantID: 12, client: Cur2.player(Cur2.down())))
        case "cur2-appeal": return page("Report appeal") { ReportAppealSection(reportID: 4, client: Cur2.player(Cur2.body(Cur2.emptyOK)), stageLabel: { _ in nil }, readBack: {}) }
        case "cur2-appeal-unconfirmed": return page("Report appeal · lost") { ReportAppealSection(reportID: 4, client: Cur2.player(Cur2.down()), stageLabel: { _ in nil }, readBack: {}) }
        case "cur2-geocode": return page("Geocode") { GeocodedAddressButton(name: "断桥", address: "白堤", city: "杭州", client: Cur2.player(Cur2.body(Cur2.geo))) }
        case "cur2-geocode-empty": return page("Geocode · no address") { GeocodedAddressButton(name: "断桥", address: "", city: "杭州", client: Cur2.player(Cur2.down())) }
        case "cur2-visitors": return page("Shop visitors") { RoamShopVisitorsStack(source: .init(sourceType: 1, sourceID: 9), visitors: Cur2.visitors) }
        case "cur2-visitors-none": return page("Shop visitors · none") { RoamShopVisitorsStack(source: .init(sourceType: 1, sourceID: 9), visitors: nil) }
        case "cur2-weather": return frame("Map weather", MapWeatherOverlay(weather: .init(kind: "rain", intensity: 0.6)).frame(height: 240))
        case "cur2-weather-clear": return frame("Map weather · none", MapWeatherOverlay(weather: nil).frame(height: 240))
        case "cur2-share-revoke": return page("Share revoke") { Cur2RevokeHost(ok: true) }
        case "cur2-share-revoke-failed": return page("Share revoke · kept pending") { Cur2RevokeHost(ok: false) }
        case "cur2-template-adopt": return page("Adopt template") { TemplateAdoptButton(sourceTemplateID: 12, accountID: 990001, scope: "", client: Cur2.player(Cur2.body(Cur2.source))) }
        case "cur2-template-adopt-refused": return page("Adopt template · unconfirmed") { TemplateAdoptButton(sourceTemplateID: 12, accountID: 990001, scope: "", client: Cur2.player(Cur2.down())) }
        case "cur2-location-todos": return page("Location todos") { Cur2TodosHost(body: Cur2.todos) }
        case "cur2-location-todos-unread": return page("Location todos · unread") { Cur2TodosHost(body: nil) }
        case "cur2-save-as-template": return page("Save as template") { TemplateProjectActions(id: 7, title: "夜航", kind: .topic, scope: "", client: Cur2.player(Cur2.body(Cur2.emptyOK))) }
        case "cur2-save-as-template-refused": return page("Save as template · refused") { TemplateProjectActions(id: 7, title: "夜航", kind: .topic, scope: "", client: Cur2.player(Cur2.down())) }
        case "cur2-unified-search": return frame("Unified search", UnifiedSearchResultsView(keyword: "西湖", cityCode: "330100", includePosts: false, client: Cur2.player(Cur2.body(Cur2.search))))
        case "cur2-unified-search-unavailable": return frame("Unified search · not open", UnifiedSearchResultsView(keyword: "西湖", cityCode: "330100", includePosts: false, client: Cur2.player(Cur2.status(503))))
        case "cur2-place-search": return roam("Place search", Cur2.body(Cur2.places)) { Cur2PlacesHost() }
        case "cur2-place-search-unavailable": return roam("Place search · unavailable", Cur2.down()) { Cur2PlacesHost() }
        case "cur2-merchant-trust": return roam("Public merchant trust", Cur2.body(Cur2.safetyOK)) { PublicMerchantTrustSection(merchantID: 12) }
        case "cur2-merchant-trust-hidden": return page("Public merchant trust · signed out") { PublicMerchantTrustSection(merchantID: 12) }
        case "cur2-im": return frame("IM desk", Cur2IMHost(clubID: 4))
        case "cur2-im-missing": return frame("IM desk · missing id", Cur2IMHost(clubID: 0))
        case "cur2-club": return frame("Club gap", ClubGapBoardView(client: ClubGapClient(baseURL: Cur2.base, transport: Cur2.body(Cur2.emptyOK)), token: Cur2.token, apiHost: Cur2.productionHost, chinese: true))
        case "cur2-club-withheld": return frame("Club gap · withheld", ClubGapBoardView(client: ClubGapClient(baseURL: Cur2.base, transport: Cur2.down()), token: nil, apiHost: Cur2.productionHost, chinese: true))
        case "cur2-rewards": return frame("Reward pledges", Cur2RewardsHost(open: true, fail: false))
        case "cur2-rewards-failed": return frame("Reward pledges · failed", Cur2RewardsHost(open: true, fail: true))
        case "cur2-rewards-closed": return frame("Reward pledges · not open", Cur2RewardsHost(open: false, fail: false))
        case "cur2-ws-purchased": return frame("Purchased workshop · reads off", Cur2PurchasedHost())
        case "cur2-ws-purchased-unavailable": return page("Purchased workshop · no browser") { WorkshopPurchasedAccountLink(browser: nil) }
        case "cur2-ws-install": return page("Paid install") { Cur2InstallHost() }
        case "cur2-ws-install-unconfigured": return page("Paid install · no controller") { Cur2InstallHost() }
        case "cur2-merchant": return frame("Merchant gap", BeGapMerchantHubView())
        case "cur2-merchant-unknown": return frame("Merchant gap · unknown fields", BeGapMerchantHubView())
        case "cur2-playgap": return frame("Play gap", Cur2SessionHost { PlayGapMiscSurfaces().environmentObject($0) })
        case "cur2-playgap-device": return frame("Play gap · device unknown", Cur2SessionHost { PlayGapDevicePage(session: $0) })
        case "cur2-ext-catalog": return frame("External catalog", Cur2CatalogHost(failed: false))
        case "cur2-ext-catalog-failed": return frame("External catalog · failed", Cur2CatalogHost(failed: true))
        case "cur2-ext-submit": return frame("External submit · no session", Cur2SubmitHost())
        case "cur2-ext-submit-unknown": return frame("External submit · result unknown", Cur2SubmissionsHost(failed: false, unknown: true))
        case "cur2-ext-submissions": return frame("My submissions", Cur2SubmissionsHost(failed: false, unknown: false))
        case "cur2-ext-submissions-failed": return frame("My submissions · failed", Cur2SubmissionsHost(failed: true, unknown: false))
        case "cur2-ext-report": return frame("External report", Cur2ReportHost())
        case "cur2-ext-report-unknown": return frame("External report · result unknown", Cur2SubmissionsHost(failed: false, unknown: true))
        default: return nil
        }
    }

    @MainActor private static func page<V: View>(_ title: String, @ViewBuilder _ view: @escaping () -> V) -> AnyView {
        AnyView(Cur2Page(title: title, content: view))
    }
    @MainActor private static func frame<V: View>(_ title: String, _ view: V) -> AnyView {
        AnyView(Cur2Frame(title: title) { view })
    }
    @MainActor private static func g6<V: View>(_ title: String, _ body: String?, _ view: V) -> AnyView {
        let caps = Cur2.capabilities(body.map(Cur2.body) ?? Cur2.down())
        return AnyView(Cur2Page(title: title) { view }.environment(\.g6Capabilities, caps))
    }
    @MainActor private static func npc(_ title: String, _ on: Bool) -> AnyView {
        let transport = Cur2.routes([
            ("api/config/features", on ? Cur2.flagsOn : Cur2.flagsOff, 200),
            ("api/ai/npc", Cur2.npc, 200)
        ])
        return AnyView(Cur2Frame(title: title) {
            Text(verbatim: "漫游").frame(maxWidth: .infinity, minHeight: 280)
                .modifier(G6RoamNPCPromptModifier(walking: true, finished: false, uniqueTiles: nil))
        }.environment(\.g6Capabilities, Cur2.capabilities(transport)))
    }
    @MainActor private static func square<V: View>(_ title: String, _ view: V) -> AnyView {
        AnyView(Cur2Frame(title: title) { view })
    }
    @MainActor private static func roam<V: View>(_ title: String, _ transport: Cur2Transport, @ViewBuilder _ view: @escaping () -> V) -> AnyView {
        AnyView(Cur2Page(title: title, content: view).environment(\.socialRoamCapabilities, Cur2.roam(transport)))
    }
}

private enum Cur2 {
    static let base = URL(string: "https://fixture.example")!
    static let token = "synthetic-fixture-token"
    static let productionHost = "www.chengyinhub.com"
    static let hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    static let api = try! APIConfiguration(baseURL: base)
    static let emptyOK = #"{"code":200,"msg":"ok","data":{}}"#
    static let emptyFeed = #"{"code":200,"data":{"items":[],"hasMore":false}}"#
    static let post = #"{"code":200,"data":{"items":[{"id":41,"body":"夜路留神"}],"hasMore":false}}"#
    static let safetyOK = #"{"code":200,"data":{"sampleStatus":"SUFFICIENT","level":"NEUTRAL","sampleCount":7,"windowDays":30}}"#
    static let safetyLow = #"{"code":200,"data":{"sampleStatus":"INSUFFICIENT","level":"NEUTRAL","sampleCount":0}}"#
    static let issues = #"{"code":200,"data":{"contributionTypes":["ISSUE_REPORT"],"issueTypes":["CLOSED","OTHER"]}}"#
    static let levels = #"{"code":200,"data":{"levels":["SAFE","NEUTRAL"]}}"#
    static let geo = #"{"code":200,"data":{"lat":30.258,"lng":120.148}}"#
    static let search = #"{"code":200,"data":{"rows":[{"type":"topic","id":3,"name":"西湖","addressName":"断桥"}],"total":1}}"#
    static let places = #"{"code":200,"data":[{"name":"断桥","address":"白堤","lat":30.258,"lng":120.148}]}"#
    static let source = #"{"code":200,"data":{"originalTemplateId":"12","sourceVersion":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}}"#
    static let awards = #"{"code":200,"data":[{"awardId":"a1","versionId":"v1","ruleVersion":"r1","rewardScope":"THEME","factRef":"THEME:9:session:3","state":"AWARDED","requestId":"req-1"}]}"#
    static let npc = #"{"code":200,"data":{"line":"夜路留神。","npcs":[{"profileId":"npc-1","name":"守夜人"}]}}"#
    static let flagsOn = #"{"code":200,"data":{"roamNpcEvent":true}}"#
    static let flagsOff = #"{"code":200,"data":{"roamNpcEvent":false}}"#
    static let promo = #"{"code":200,"data":{"serverNow":"2030-01-01 10:00:00","offers":[{"offerCode":"BUNDLE","name":"夜航套餐","available":true,"differenceAmount":"12.5"},{"name":"未解锁","available":false,"reasonCode":"ALREADY_USED"}],"promotions":[{"promoCode":"P","name":"限时","eligible":true,"windowEndsAt":"2030-01-04 10:00:00"}],"tiers":[{"tierCode":"T1","minQuantity":2,"maxQuantity":4,"unitPrice":88}]}}"#
    static let revenue = #"{"code":200,"data":[{"allocationId":5,"orderType":1,"statusText":"accrued","settleableAt":"2030-02-03 00:00:00","currency":"CNY","lines":[{"entryType":1,"role":"author","amountFen":1230},{"entryType":1,"role":"referrer","amount":null}]}]}"#
    static let recovery = #"{"code":200,"data":{"items":[{"cursor":"9","prepareKey":"0f8fad5b-d9cb-469f-a165-70867728950e","requestId":"td2_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","state":"FAILED","reasonCode":null,"productType":1,"createdAt":"2030-01-01T08:00:00Z","executeBefore":"2030-01-01T09:00:00Z","resultExpiresAt":null}],"nextCursor":null}}"#
    static let chaptersJSON = #"[{"id":1,"name":"第一章","nodes":[{"id":11,"name":"钟楼","registrationMerchantList":[{"memberId":1}]}]}]"#
    static let todos = #"{"code":200,"data":{"sourceTemplateTopicId":"12","contract":{"locationSlots":[{"slotKey":"loc-1","title":"钟楼","alternativePolicy":"NONE"},{"slotKey":"loc-2","title":"码头","alternativePolicy":"ALTERNATE_NODE"}],"locationBindings":[{"slotKey":"loc-1","nodeId":"11","bindingRevision":1,"verificationStatus":"BOUND_UNVERIFIED"}]},"bindingIssues":[{"slotKey":"loc-2","level":"error","message":"必填地点未重绑"}]}}"#
    static let paidItemJSON = #"{"licenseId":"w18-paid-1","moduleId":"harbor","purchasedVersionId":"v1","contentHash":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","acquiredAt":"2026-11-13T02:00:00Z","termsVersion":"t1","termsHash":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","status":"ACTIVE","commercialUse":"PROHIBITED","adaptation":"BIND_RESOURCES_ONLY","translation":"PROHIBITED","allowedRegions":["CN"],"themeLimit":{"unlimited":false,"maximum":1},"merchantLimit":{"unlimited":true,"maximum":0},"runLimit":{"unlimited":false,"maximum":3},"acquisition":"PAID","buyerKind":"INDIVIDUAL","useDuration":"PERPETUAL_PURCHASED_VERSION","updates":"EXACT_PURCHASED_VERSION","redistribution":"PROHIBITED","contentUseStatus":"PAID_INSTALL_AUTHORITY_UNAVAILABLE","purchaseActionStatus":"CHANNEL_APPROVAL_REQUIRED"}"#

    static func envelope(_ data: String) -> String { #"{"code":200,"msg":"ok","data":"# + data + "}" }
    static func body(_ json: String) -> Cur2Transport { Cur2Transport([("", json, 200)]) }
    static func down() -> Cur2Transport { Cur2Transport([("", "", 0)]) }
    static func status(_ code: Int) -> Cur2Transport { Cur2Transport([("", #"{"code":503,"msg":"closed","data":null}"#, code)]) }
    static func routes(_ rows: [(String, String, Int)]) -> Cur2Transport { Cur2Transport(rows) }
    static func player(_ transport: Cur2Transport) -> PlayerCapabilityClient {
        PlayerCapabilityClient(baseURL: base, token: token, transport: transport)
    }
    static func square(_ transport: Cur2Transport) -> SquareService { SquareService(configuration: api, transport: transport) }
    @MainActor static func capabilities(_ transport: Cur2Transport) -> G6Capabilities {
        G6Capabilities(
            source: { G6CapabilitySource(configuration: api, transport: transport) },
            token: { token },
            member: { "990001" },
            flags: { LaunchFeatureFlagsReader(configuration: api, transport: transport, approved: true, currentIdentity: { "990001" }) }
        )
    }
    @MainActor static func roam(_ transport: Cur2Transport) -> SocialRoamCapabilities {
        SocialRoamCapabilities(client: player(transport), accountID: 990001, squareMine: square(transport), token: token,
                               communityOpen: true, merchantHome: DisabledPublicMerchantHomeReader())
    }
    static func chapters() -> [TopicChapter] {
        (try? JSONDecoder().decode([TopicChapter].self, from: Data(chaptersJSON.utf8))) ?? []
    }
    static var visitors: RoamPlayerExtrasService.Visitors? {
        guard let face = URL(string: "https://fixture.example/face.png") else { return nil }
        return .init(faces: [face], total: 2)
    }
    static func paidItem() -> WorkshopPurchasedItem? {
        try? JSONDecoder().decode(WorkshopPurchasedItem.self, from: Data(paidItemJSON.utf8))
    }
    static func catalogFact() -> ExternalGameCatalogFact {
        ExternalGameCatalogFact(submissionID: "sub-1", gameID: "harbor", version: "1.0.0", name: "夜航", author: nil, summary: nil,
                                 contentRating: "4+", permissions: [], allowedDomains: [], sha256: hash, monetization: "NONE",
                                 packageBytes: nil, fileCount: nil, downloadPath: nil, downloadExpiresAt: nil)
    }
    static func submissionFact() -> ExternalGameSubmissionFact {
        ExternalGameSubmissionFact(submissionID: "sub-1", gameID: "harbor", version: "1.0.0", name: "夜航", status: .pending,
                                    rejectReason: nil, canCancel: false, canResubmit: false, reviewDueAt: nil)
    }
    static func manifest() -> ExternalGameManifest {
        ExternalGameManifest(id: "harbor", name: "夜航", version: "1.0.0", entry: "index.html", sha256: hash, signature: "fixture-signature")
    }
    @MainActor static func gameStore() -> ExternalGameStore {
        ExternalGameStore(rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("cur2-ext", isDirectory: true))
    }
}

final class Cur2Transport: HTTPTransport, @unchecked Sendable {
    private let routes: [(String, String, Int)]
    init(_ routes: [(String, String, Int)]) { self.routes = routes }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        guard let hit = routes.first(where: { $0.0.isEmpty || path.contains($0.0) }) else { throw URLError(.notConnectedToInternet) }
        if hit.2 == 0 { throw URLError(.notConnectedToInternet) }
        return (Data(hit.1.utf8), hit.2)
    }
}

@MainActor private final class Cur2ReportAccess: TeamOrientBoardAccess {
    let enabled = true
    func loadBoard(teamID: Int) async throws -> TeamOrientBoardDetail? { nil }
    func loadRanking(ownerType: Int, ownerID: Int) async throws -> [TeamOrientRankingRow] { [] }
    func reportTeam(teamID: Int, reason: String) async throws {}
}

@MainActor private struct Cur2Page<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        NavigationStack {
            List {
                content()
                Section {} footer: {
                    Text(verbatim: "DEBUG fixture · synthetic").accessibilityIdentifier("cur2.fixture.footer")
                }
            }
            .navigationTitle(Text(verbatim: title)).navigationBarTitleDisplayMode(.inline)
        }
        .themeDomain(.player)
    }
}

@MainActor private struct Cur2Frame<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            content()
            Text(verbatim: title + " · DEBUG fixture · synthetic")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.sm)
                .accessibilityIdentifier("cur2.fixture.footer")
        }
        .themeDomain(.player)
    }
}

@MainActor private struct Cur2LinkHost: View {
    @StateObject private var session = AppSession()
    let page: String
    var body: some View {
        if let link = MiniProgramPageLink(path: page, query: [:]) {
            MPParityPageEntry(link: link, session: session, goHome: {})
        } else {
            Text(verbatim: "—")
        }
    }
}

@MainActor private struct Cur2AIGCHost: View {
    let generated: Bool
    var body: some View {
        if generated, AIGCDisclosure.isAIGenerated(publishMode: "ai_simple") {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                AIGCLabel()
                AIGCFilingNumberText()
            }
            .environment(\.aigcFilingNumber, "网信算备 00000000000000000000 号")
        }
    }
}

@MainActor private struct Cur2EditorHost: View {
    @StateObject private var model: Cur2EditorModel
    init(full: Bool) { _model = StateObject(wrappedValue: Cur2EditorModel(full: full)) }
    var body: some View { ProjectEditView(coordinator: model.coordinator, sessionRevision: 1) }
}

@MainActor private final class Cur2EditorModel: ObservableObject {
    let coordinator: ProjectEditCoordinator
    init(full: Bool) {
        let session = try! ProjectEditSession(accountID: 901, epoch: 1, storageNamespace: "synthetic-project-editor")
        let service = ProjectEditSyntheticService()
        service.snapshot = ProjectEditSyntheticFixtures.snapshot(scope: full ? .full : .whitelist)
        let held = Cur2SessionBox(session)
        coordinator = ProjectEditCoordinator(initial: service.snapshot, service: service,
                                             store: ProjectEditLocalStore(storage: ProjectEditMemoryStorage()),
                                             currentSession: { held.session })
    }
}

private final class Cur2SessionBox {
    let session: ProjectEditSession
    init(_ session: ProjectEditSession) { self.session = session }
}

@MainActor private struct Cur2PromoHost: View {
    let activityID: Int
    var body: some View {
        Group {
            Text(verbatim: "报名").modifier(G6PromotionCatalogLoader(activityID: activityID))
            G6PromotionCatalogSection(activityID: activityID)
        }
    }
}

@MainActor private struct Cur2CharactersHost: View {
    private let rows = Cur2.chapters()
    var body: some View {
        Group {
            Text(verbatim: "主题").modifier(G6TopicCharactersLoader(chapters: rows))
            G6TopicCharactersSection(chapters: rows)
        }
    }
}

@MainActor private struct Cur2RevokeHost: View {
    let ok: Bool
    init(ok: Bool) {
        self.ok = ok
        UserDefaults.standard.set(true, forKey: "roam.share.revokePending.990001")
    }
    var body: some View {
        RoamShareRevokeRow(client: Cur2.player(ok ? Cur2.body(Cur2.emptyOK) : Cur2.down()), accountID: 990001)
    }
}

@MainActor private struct Cur2TodosHost: View {
    @StateObject private var store = TemplateLocationTodosStore()
    let bodyJSON: String?
    init(body: String?) { self.bodyJSON = body }
    var body: some View {
        let client = Cur2.player(bodyJSON.map(Cur2.body) ?? Cur2.down())
        TemplateLocationTodosSection(topicID: 7, scope: "", client: client, bindableNodes: [(id: 11, label: "钟楼 · 中山路")], store: store)
            .task { await store.load(topicID: 7, scope: "", client: client) }
    }
}

@MainActor private struct Cur2PlacesHost: View {
    @State private var keyword = "西湖"
    private var area: RoamSearchArea? {
        RoamCoordinate(latitude: 30.25, longitude: 120.16).map { RoamSearchArea(coordinate: $0, label: "杭州") }
    }
    var body: some View {
        TextField("地点", text: $keyword)
            .modifier(MapPlaceSuggestions(keyword: keyword, area: area))
    }
}

@MainActor private struct Cur2IMHost: View {
    @StateObject private var session = AppSession()
    let clubID: Int64
    var body: some View { BeGapImDesk(clubID: clubID, session: session) }
}

@MainActor private struct Cur2SessionHost<Content: View>: View {
    @StateObject private var session = AppSession()
    let content: (AppSession) -> Content
    var body: some View { content(session) }
}

@MainActor private struct Cur2RewardsHost: View {
    let entry: RewardPledgeEntry
    init(open: Bool, fail: Bool) {
        let caller = RewardPledgeCaller(accountID: "990001", epoch: 1, region: "CN", token: Cur2.token,
                                         read: open, claim: false, preview: false, redeem: false)
        let journal = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cur2-rewards-absent.json")
        try? FileManager.default.removeItem(at: journal)
        let client = RewardPledgeClient(configuration: Cur2.api, transport: fail ? Cur2.down() : Cur2.body(Cur2.awards))
        entry = RewardPledgeEntry(client: client, journalURL: journal, current: { caller })
    }
    var body: some View { RewardPledgeClaimHost(entry: entry) }
}

@MainActor private final class Cur2PurchasedReader: WorkshopPurchasedReading {
    func list(before: Int64?, lifetime: WorkshopPurchasedReadLifetime) async throws -> WorkshopPurchasedPage {
        throw WorkshopPurchasedIssue.disabled
    }
    func detail(licenseId: String, lifetime: WorkshopPurchasedReadLifetime) async throws -> WorkshopPurchasedDetail {
        throw WorkshopPurchasedIssue.disabled
    }
}

@MainActor private struct Cur2PurchasedHost: View {
    @StateObject private var session = AppSession()
    private let browser: WorkshopPurchasedBrowser?
    init() {
        guard let play = try? PlayExperienceSession(accountID: 7, epoch: 1, namespace: "synthetic", token: Cur2.token) else {
            browser = nil
            return
        }
        let context = RuntimeDependencyContext(market: .china, baseURL: Cur2.base, role: "player", session: play)
        browser = WorkshopPurchasedBrowser(reader: Cur2PurchasedReader(), lease: ContentDraftSessionLease(context: context, current: { context }))
    }
    var body: some View {
        if let browser {
            WorkshopPurchasedLibraryView(browser: browser).environmentObject(session)
        } else {
            Text(verbatim: "—")
        }
    }
}

@MainActor private struct Cur2InstallHost: View {
    var body: some View {
        if let item = Cur2.paidItem() {
            WorkshopPaidInstallEntry(item: item, makeController: { _ in nil })
        } else {
            Text(verbatim: "—")
        }
    }
}

@MainActor private struct Cur2CatalogHost: View {
    @State private var model: ExternalGameReviewModel
    init(failed: Bool) {
        let model = ExternalGameReviewModel(store: Cur2.gameStore())
        if failed {
            model.catalogFailed = true
        } else {
            model.catalog = [Cur2.catalogFact()]
        }
        _model = State(initialValue: model)
    }
    var body: some View { ExternalGameCatalogSection(model: model, session: nil, onSubmissions: {}) }
}

@MainActor private struct Cur2SubmissionsHost: View {
    @State private var model: ExternalGameReviewModel
    init(failed: Bool, unknown: Bool) {
        let model = ExternalGameReviewModel(store: Cur2.gameStore())
        if failed {
            model.submissionsFailed = true
        } else {
            model.submissions = [Cur2.submissionFact()]
        }
        if unknown { model.unconfirmedRequestID = "req-unknown" }
        _model = State(initialValue: model)
    }
    var body: some View { ExternalGameSubmissionsScreen(model: model, session: nil) }
}

@MainActor private struct Cur2ReportHost: View {
    var body: some View {
        ExternalGameReportSheet(manifest: Cur2.manifest(), onSend: { _ in }, onCancel: {})
    }
}

@MainActor private struct Cur2SubmitHost: View {
    private let store = Cur2.gameStore()
    var body: some View { ExternalGameLibrarySection(store: store, session: nil) }
}
#endif
