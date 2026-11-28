#if DEBUG
import SwiftUI

/// G1 / G7-G8 / parity-b player views on a synthetic transport. Every fixture mounts the REAL view; the transport
/// answers with mini-program envelopes (`{code, msg, data}`) copied from the Core stub tests, so nothing reaches a
/// backend. Each view has its normal state plus one non-happy state (empty, unknown, refused or hidden capability).
/// Reachable with `--design-fixture g-<name>`; the id table is in `docs/release/receipts/fixtures-g.md`.
enum GParityFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        // MARK: G7/G8 official events
        case "g-signup": return gap("Official signup", GParitySignupSeed.idle(), OfficialSignupCommandSection(eventID: GParitySignupSeed.eventID))
        case "g-signup-unknown": return gap("Official signup · unknown", GParitySignupSeed.pending(), OfficialSignupCommandSection(eventID: GParitySignupSeed.eventID))
        case "g-roam-events": return gap("Roam official events", GParityReplies.roamEvents(empty: false), OfficialRoamActiveCardView())
        case "g-roam-events-empty": return gap("Roam official events · none open", GParityReplies.roamEvents(empty: true), OfficialRoamActiveCardView())
        // MARK: team
        case "g-team-qr": return gap("Team invite code", GParityReplies.teamQR(refused: false), TeamInviteQRSection(teamID: 4))
        case "g-team-qr-refused": return gap("Team invite code · refused", GParityReplies.teamQR(refused: true), TeamInviteQRSection(teamID: 4))
        case "g-team-trail": return gap("Team trail · consent", GParityReplies.teamTrail(available: true), TeamTrailSection(activityID: 5))
        case "g-team-trail-unavailable": return gap("Team trail · unavailable", GParityReplies.teamTrail(available: false), TeamTrailSection(activityID: 5))
        case "g-lead-member": return gap("Lead member actions", GParityReplies.leadMember(refused: false), LeadMemberActionsSection(activityID: 5, meArrived: false))
        case "g-lead-member-refused": return gap("Lead member actions · refused", GParityReplies.leadMember(refused: true), LeadMemberActionsSection(activityID: 5, meArrived: true))
        // MARK: profile, city, media, cards
        case "g-player-code": return gap("Player code and join", GParityReplies.playerCode(joined: true), PlayerCodeAndJoinSection())
        case "g-player-code-empty": return gap("Player code · no join, no code", GParityReplies.playerCode(joined: false), PlayerCodeAndJoinSection())
        case "g-city-favorites": return gap("City favorite nodes", GParityReplies.cityFavorites(empty: false), CityFavoriteNodesSection())
        case "g-city-favorites-empty": return gap("City favorite nodes · empty", GParityReplies.cityFavorites(empty: true), CityFavoriteNodesSection())
        case "g-merchant-node": return gap("Merchant city node", GParityReplies.merchantNode(hidden: false), MerchantCityNodeFavoriteRow(merchantID: 12))
        case "g-merchant-node-hidden": return gap("Merchant city node · no node", GParityReplies.merchantNode(hidden: true), MerchantCityNodeFavoriteRow(merchantID: 12))
        case "g-asset-credit": return gap("Asset credit", GParityReplies.assetCredit(hidden: false), AssetCreditText(reference: "media/hz-gate.jpg"))
        case "g-asset-credit-hidden": return gap("Asset credit · unreviewed", GParityReplies.assetCredit(hidden: true), AssetCreditText(reference: "media/hz-gate.jpg"))
        case "g-card-rename": return gap("Object card rename", GParityReplies.cardRename(refused: false), ObjectCardRenameButton(cardID: 9, title: "Lantern"))
        case "g-card-rename-refused": return gap("Object card rename · refused", GParityReplies.cardRename(refused: true), ObjectCardRenameButton(cardID: 9, title: "Lantern"))
        // MARK: publish, club
        case "g-publish-precheck": return gap("Publish precheck", GParityReplies.publishPrecheck(denied: false), ActivityPublishPrecheckGate { GParityPublishBody() })
        case "g-publish-precheck-denied": return gap("Publish precheck · denied", GParityReplies.publishPrecheck(denied: true), ActivityPublishPrecheckGate { GParityPublishBody() })
        case "g-like-state": return gap("Club post like readback", GParityReplies.likeState(resolved: true), ClubPostLikeStateButton(postID: 5, clubID: 2))
        case "g-like-state-unresolved": return gap("Club post like readback · unresolved", GParityReplies.likeState(resolved: false), ClubPostLikeStateButton(postID: 5, clubID: 2))
        case "g-host-request": return gap("Club host request", GParityReplies.hostRequest(refused: false), ClubHostRequestButton(activityID: 3, ticketID: 8))
        case "g-host-request-refused": return gap("Club host request · refused", GParityReplies.hostRequest(refused: true), ClubHostRequestButton(activityID: 3, ticketID: 8))
        // MARK: parity-b
        case "g-passport": return host("Roam passport server stats", nil, RoamPassportServerSummarySection(reader: GParityPassportReader(.known)))
        case "g-passport-unknown": return host("Roam passport · unknown counts", nil, RoamPassportServerSummarySection(reader: GParityPassportReader(.unknownCounts)))
        case "g-passport-failed": return host("Roam passport · read failed", nil, RoamPassportServerSummarySection(reader: GParityPassportReader(.failed)))
        case "g-shared-control": return gap("Shared run control", GParityReplies.sharedControl(organiser: true), SharedRunControlSection(activityID: 5))
        case "g-shared-control-hidden": return gap("Shared run control · not organiser", GParityReplies.sharedControl(organiser: false), SharedRunControlSection(activityID: 5))
        case "g-shared-entry": return gap("Shared run entry", GParityReplies.sharedControl(organiser: true), SharedRunControlEntry(activityID: 5))
        case "g-shared-entry-hidden": return gap("Shared run entry · not organiser", GParityReplies.sharedControl(organiser: false), SharedRunControlEntry(activityID: 5))
        case "g-lead-scan": return gap("Lead member ticket scan", [:], LeadMemberTicketScanButton(activityID: 5))
        case "g-lead-scan-hidden": return host("Lead member ticket scan · no grant", nil, LeadMemberTicketScanButton(activityID: 5))
        case "g-orient-alt": return gap("Orienteering alternatives", GParityReplies.orientAlternatives(loaded: true), OrientAlternativeEditorSection(topicID: 12, taskID: 34))
        case "g-orient-alt-unread": return gap("Orienteering alternatives · unread", GParityReplies.orientAlternatives(loaded: false), OrientAlternativeEditorSection(topicID: 12, taskID: 34))
        case "g-circle-host": return gap("Circle theme host", GParityReplies.circleHost(host: true), CircleThemeHostSection(topicID: 12))
        case "g-circle-host-hidden": return gap("Circle theme host · not host", GParityReplies.circleHost(host: false), CircleThemeHostSection(topicID: 12))
        case "g-circle-configure": return sheet(GParityReplies.circleConfigure, CircleThemeConfigureSheet(topicID: 12, themeCode: "FITNESS", reload: {}))
        case "g-circle-configure-unsupported": return sheet(GParityReplies.circleConfigure, CircleThemeConfigureSheet(topicID: 12, themeCode: "UNKNOWN", reload: {}))
        // MARK: G1 play runtime
        case "g-play-prep": return host("Pre-game prep", nil, GParityPrepHost(failed: false))
        case "g-play-prep-failed": return host("Pre-game prep · read failed", nil, GParityPrepHost(failed: true))
        case "g-play-gameplay": return host("Theme gameplay reward preview", nil, GParityGameplayHost(overflow: false))
        case "g-play-gameplay-overflow": return host("Theme gameplay · backpack full", nil, GParityGameplayHost(overflow: true))
        case "g-coop-help": return AnyView(GParityCoopHelpHost(stale: false).themeDomain(.player))
        case "g-coop-help-stale": return AnyView(GParityCoopHelpHost(stale: true).themeDomain(.player))
        case "g-trade-preview": return AnyView(GParityTradeHost(stale: false).themeDomain(.player))
        case "g-trade-preview-stale": return AnyView(GParityTradeHost(stale: true).themeDomain(.player))
        default: return nil
        }
    }

    static let accountID = 990_001

    @MainActor static func service(_ transport: GParityTransport) -> PlayerGapService {
        PlayerGapService(baseURL: URL(string: "https://fixture.example")!, accountID: accountID, token: { "synthetic-fixture-token" },
                         transport: transport)
    }

    @MainActor static func client(_ transport: GParityTransport) -> PlayRuntimeClient? {
        try? PlayRuntimeClient(configuration: APIConfiguration(baseURL: URL(string: "https://fixture.example")!), transport: transport,
                               token: "synthetic-fixture-token")
    }

    /// A `PlayerGapService` on the synthetic transport, injected the way `SessionRootView` injects the real one.
    @MainActor private static func gap<V: View>(_ title: String, _ replies: [String: GParityTransport.Reply], _ view: V) -> AnyView {
        host(title, service(GParityTransport(replies)), view)
    }
    @MainActor private static func gap<V: View>(_ title: String, _ transport: GParityTransport, _ view: V) -> AnyView {
        host(title, service(transport), view)
    }

    @MainActor private static func host<V: View>(_ title: String, _ service: PlayerGapService?, _ view: V) -> AnyView {
        AnyView(GParityHost(title: title, service: service) { view }.themeDomain(.player))
    }

    /// Views that own their `NavigationStack` (sheets) only need the service.
    @MainActor private static func sheet<V: View>(_ replies: [String: GParityTransport.Reply], _ view: V) -> AnyView {
        AnyView(view.environment(\.playerGapService, service(GParityTransport(replies))).themeDomain(.player))
    }
}

/// Answers by path suffix, or through a closure when the reply must echo the request (request ids, trade keys).
/// An unrouted path is a lost connection, so the view shows its own unknown state.
final class GParityTransport: HTTPTransport, @unchecked Sendable {
    typealias Reply = (body: String, status: Int)
    private let route: (URLRequest) -> Reply?

    init(_ replies: [String: Reply]) {
        route = { request in
            let path = request.url?.path ?? ""
            return replies.first { path.hasSuffix($0.key) }?.value
        }
    }
    init(route: @escaping (URLRequest) -> Reply?) { self.route = route }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard let reply = route(request) else { throw URLError(.notConnectedToInternet) }
        return (Data(reply.body.utf8), reply.status)
    }

    static func ok(_ data: String, msg: String = "ok") -> Reply { (#"{"code":200,"msg":"\#(msg)","data":\#(data)}"#, 200) }
    static func refused(_ code: Int, _ msg: String) -> Reply { (#"{"code":\#(code),"msg":"\#(msg)"}"#, 200) }
    static func json(_ request: URLRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
    }
}

/// Mini-program reply bodies per route, from `PlayerGapRoutesTests` / `PlayerParityBRoutesTests`.
enum GParityReplies {
    typealias T = GParityTransport

    static func roamEvents(empty: Bool) -> [String: T.Reply] {
        ["api/official/active-for-roam": T.ok(empty ? "[]" : #"[{"id":5,"title":"西湖春日徒步","coverImg":""},{"id":6,"title":"运河夜灯跑"}]"#)]
    }
    static func teamQR(refused: Bool) -> [String: T.Reply] {
        ["api/team/invite-qrcode": refused ? T.refused(403, "你不是该队伍成员") : T.ok(#"{"teamId":4,"inviteCode":"AB23CD","qrState":"UNAVAILABLE"}"#)]
    }
    static func teamTrail(available: Bool) -> [String: T.Reply] {
        ["api/team/trail/state": T.ok(available ? #"{"available":true,"share":true,"decided":false}"# : #"{"available":false}"#),
         "api/team/trail/consent": T.ok(#"{"available":true,"share":true}"#),
         "api/team/trail/sync": T.ok(#"{"available":true,"share":true,"teams":[{"key":"t1","name":"狐狸队","done":2,"pts":[[30.25,120.15],[30.26,120.16]]},{"key":"t2","name":"白鹭队","done":1,"pts":[[30.24,120.14]]}]}"#)]
    }
    static func leadMember(refused: Bool) -> [String: T.Reply] {
        ["api/club/lead/arrive": T.ok("{}", msg: "已签到"),
         "api/club/lead/broadcast": refused ? T.refused(429, "发送太频繁，请稍后再试") : T.ok("{}", msg: "已发送给领队")]
    }
    static func playerCode(joined: Bool) -> [String: T.Reply] {
        ["api/registration/join_info": T.ok(joined ? #"{"id":31,"title":"西湖春日徒步 · 第二场"}"# : "null"),
         // Only an http(s) `data.qr` counts; the fixture never loads a remote image, so both states show the MP 个人码加载失败 · 重新生成 state.
         "api/user/player-code": T.ok(#"{"qr":"data:image/png;base64,xx"}"#)]
    }
    static func cityFavorites(empty: Bool) -> [String: T.Reply] {
        ["api/city/nodes/favorites": T.ok(empty ? "[]" : #"[{"poiId":3,"name":"断桥残雪","address":"杭州市西湖区北山街"},{"poiId":4,"name":"拱宸桥"}]"#)]
    }
    static func merchantNode(hidden: Bool) -> [String: T.Reply] {
        ["api/city/nodes/merchant/12": hidden ? T.refused(404, "not found") : T.ok(#"{"poiId":3,"name":"断桥残雪","favorited":false}"#),
         "api/city/nodes/3/favorite": T.ok(#"{"favorited":true}"#)]
    }
    static func assetCredit(hidden: Bool) -> [String: T.Reply] {
        ["api/media/asset/attribution": T.ok(hidden ? "{}" : #"{"attribution":"摄影 · 林夕","aiGenerated":false}"#)]
    }
    static func cardRename(refused: Bool) -> [String: T.Reply] {
        ["api/object-card/rename": refused ? T.refused(400, "标题不能超过 12 个字") : T.ok(#"{"title":"Lamp"}"#)]
    }
    static func publishPrecheck(denied: Bool) -> [String: T.Reply] {
        ["api/activity/publish_precheck": denied ? T.refused(403, "仅认证发布者可发布活动") : T.ok("{}")]
    }
    static func likeState(resolved: Bool) -> [String: T.Reply] {
        ["api/club/post/like-state": T.ok(resolved ? #"{"id":5,"clubId":2,"isLiked":true,"likeCount":4}"# : #"{"id":6,"clubId":2,"isLiked":true}"#)]
    }
    static func hostRequest(refused: Bool) -> [String: T.Reply] {
        ["api/club/event-ops/host/request": refused ? T.refused(409, "当前没有可分配的主持人") : T.ok("{}")]
    }

    private static let hashA = String(repeating: "a1", count: 32), hashB = String(repeating: "b2", count: 32)
    static func sharedControl(organiser: Bool) -> [String: T.Reply] {
        guard organiser else {
            return ["api/game/session/shared/control": (#"{"code":403,"msg":"仅活动所属俱乐部主理人可执行","data":{"reasonCode":"GAME_FORBIDDEN"}}"#, 200)]
        }
        return ["api/game/session/shared/control": T.ok(#"{"revision":3,"run":{"authorityEpoch":2,"operationStatus":"RUNNING","authorityMode":"ONLINE"},"teams":[{},{},{}],"stations":[{},{},{},{}],"availableActions":["OFFLINE_ANCHOR"],"offlineAnchorAvailable":true}"#),
                "api/game/session/shared/export": T.ok(#"{"revision":3,"authorityEpoch":2,"activityId":5,"sessionId":41,"configHash":"\#(hashA)","highWaterHash":"\#(hashB)","manual":{"needsReview":false,"nextSequence":4}}"#)]
    }
    static func orientAlternatives(loaded: Bool) -> [String: T.Reply] {
        ["api/topic/author-saved-detail": T.ok(loaded
            ? #"{"topic":{"id":12},"chapters":[{"cmsTopicNodeList":[{"id":34}]}],"nodeAlternativeConfigsLoaded":true,"nodeAlternativeConfigs":{"34":[{"type":"QUIZ","enabled":true,"promptText":"断桥东侧石碑上刻着哪四个字？","answerConfigured":true},{"type":"PHOTO","enabled":false,"promptText":null,"answerConfigured":true}]}}"#
            : #"{"topic":{"id":12},"chapters":[],"nodeAlternativeConfigsLoaded":false}"#),
         "api/orient/task/alternative": T.ok("{}")]
    }
    static func circleHost(host: Bool) -> [String: T.Reply] {
        ["api/project/home": T.ok(host ? #"{"host":{"recruit":{}},"topic":{"circleThemeCode":"FITNESS","circleReviewedAt":"2026-11-01 09:00:00"}}"#
                                       : #"{"join":{},"topic":{"circleThemeCode":"FITNESS"}}"#)]
    }
    static let circleConfigure: [String: T.Reply] = ["api/circle-theme/instance/configure": T.ok("{}")]
}

/// The persisted signup slot `OfficialSignupCommandSection` reads; seeding it is how a lost reply looks on relaunch.
enum GParitySignupSeed {
    static let eventID = 902
    private static var key: String { "cy-team-event-command-v1:\(GParityFixtures.accountID):SIGNUP:\(eventID)" }

    /// The submit receipt names the request id the flow persisted, so the flow settles as APPLIED.
    static func idle() -> GParityTransport {
        _ = OfficialSignupCommandDefaultsStore().clear(key: key)
        return GParityTransport(route: { request in
            guard request.url?.path.hasSuffix("api/official/signup-command") == true,
                  let id = GParityTransport.json(request)["requestId"] as? String else { return nil }
            return GParityTransport.ok(#"{"requestId":"\#(id)","state":"APPLIED"}"#)
        })
    }
    static func pending() -> GParityTransport {
        if let command = OfficialSignupCommand(eventID: eventID, requestID: String(repeating: "f", count: 32)) {
            _ = OfficialSignupCommandDefaultsStore().save(command, key: key)
        }
        // No route answers query / retry / cancel: the slot stays unknown, as with no network.
        return GParityTransport([:])
    }
}

@MainActor private struct GParityHost<Content: View>: View {
    let title: String
    let service: PlayerGapService?
    @ViewBuilder let content: () -> Content
    var body: some View {
        NavigationStack {
            List {
                content()
                Section {} footer: {
                    Text(verbatim: "DEBUG fixture · synthetic transport" + (service == nil ? " · no player grant" : ""))
                        .accessibilityIdentifier("g.fixture.footer")
                }
            }
            .navigationTitle(Text(verbatim: title)).navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.playerGapService, service)
    }
}

private struct GParityPublishBody: View {
    var body: some View { Text(verbatim: "Publish form (allowed by the server precheck)").accessibilityIdentifier("g.publish.body") }
}

@MainActor private final class GParityPassportReader: RoamPassportHistoryReading {
    enum Kind { case known, unknownCounts, failed }
    let kind: Kind
    let scope = UUID()
    init(_ kind: Kind) { self.kind = kind }
    var identity: RoamExperienceIdentity? { nil }
    var isConfigured: Bool { true }
    func page(before: String?) async throws -> RoamPassportHistoryPage { throw APIError.httpStatus(503) }
    func record(sessionID: String) async throws -> RoamPassportHistoryFact { throw APIError.httpStatus(503) }
    func summary() async throws -> RoamPassportServerSummary {
        let json: String
        switch kind {
        case .known: json = #"{"trips":12,"distanceM":48250,"days":9,"shops":5}"#
        // A missing count is an em dash, never zero.
        case .unknownCounts: json = #"{"trips":3,"distanceM":null,"days":null,"shops":0}"#
        case .failed: throw APIError.httpStatus(503)
        }
        return try JSONDecoder().decode(RoamPassportServerSummary.self, from: Data(json.utf8))
    }
}

// MARK: G1 hosts

@MainActor private struct GParityPrepHost: View {
    let client: PlayRuntimeClient?
    init(failed: Bool) {
        client = GParityFixtures.client(GParityTransport(["api/play/setup": failed ? GParityTransport.refused(500, "x")
            : GParityTransport.ok(#"{"prepItems":["带一瓶水","手机电量 50% 以上","舒适的步行鞋"],"playWindow":{"mode":"day"},"openNow":true}"#)]))
    }
    var body: some View {
        let make: @MainActor () -> PlayRuntimeClient? = { [client] in client }
        return PlayTopicPrepSection(topicID: 12).environment(\.playRuntimeTopicClient, make)
    }
}

@MainActor private struct GParityGameplayHost: View {
    let client: PlayRuntimeClient?
    let view: PlayWireValue
    @State private var flow = PlayThemeGameplayFlow()
    init(overflow: Bool) {
        view = (try? PlayExperienceSyntheticFixtures.wire(#"{"sessionId":41,"version":6,"world":{"itemCatalog":[{"id":"rope","name":"麻绳"},{"id":"lamp","name":"灯笼"}]}}"#)) ?? .null
        let pack = overflow
            ? #"{"sessionId":41,"version":6,"previewVersion":"pv-2","overflow":true,"grants":{"lamp":2,"rope":3},"finalUsed":8,"capacity":6}"#
            : #"{"sessionId":41,"version":6,"previewVersion":"pv-1","overflow":false,"grants":{"lamp":1,"rope":1},"finalUsed":4,"capacity":6}"#
        client = GParityFixtures.client(GParityTransport(["api/play/theme/gameplay-preview": GParityTransport.ok(pack),
                                                          "api/play/theme/gameplay-action": GParityTransport.ok(#"{"sessionId":41,"version":7}"#)]))
    }
    var body: some View {
        PlayThemeGameplayFlowSection(flow: flow, view: view, client: { [client] in client }, applied: { _ in })
            .task {
                guard flow.preview == nil else { return }
                await flow.start(operation: "QUEST_RESOLVE", contentID: "q1", costOption: nil, choiceKey: nil, view: view,
                                 client: client, applied: { _ in })
            }
    }
}

@MainActor private struct GParityCoopHelpHost: View {
    @State private var flow: PlayCoopHelpFlow
    init(stale: Bool) {
        let cooperation = (try? PlayExperienceSyntheticFixtures.wire(#"{"gameSessionId":61,"authorityEpoch":2,"questions":[{"questKey":"q1","nodeId":34,"runtimeInstance":"r1"}]}"#)) ?? .null
        let client = GParityFixtures.client(GParityTransport(route: { request in
            switch GParityTransport.json(request)["operation"] as? String {
            case "VIEW": return GParityTransport.ok(#"{"levels":[{"level":1,"type":"TEXT","usable":true,"free":true},{"level":2,"type":"ANSWER","usable":true,"costPoints":5},{"level":3,"type":"SKIP","usable":true}],"remainingFreeUses":2}"#)
            case "USE": return GParityTransport.ok(#"{"content":"看看桥头石碑的背面","chargedPoints":0}"#)
            case "SKIP": return GParityTransport.ok("{}")
            default: return nil
            }
        }))
        // A quest key the cooperation no longer lists is the stale state: nothing is sent.
        _flow = State(initialValue: PlayCoopHelpFlow(activityID: 5, cooperation: cooperation, questKey: stale ? "q-gone" : "q1", client: { client }))
    }
    var body: some View {
        PlayCoopHelpSheet(flow: flow, close: {}).task { await flow.open() }
    }
}

@MainActor private struct GParityTradeHost: View {
    private let snapshot: PlayTeamBackpackSnapshot?
    private let form: PlayThemeTradeForm?
    private let client: PlayRuntimeClient?

    private static let projection = #"{"activityId":5,"sessionId":61,"revision":7,"status":"RUNNING","availableActions":["TRADE_OPEN"],"perspective":"PLAYER","player":{"playMode":"ROUTE","scope":"TEAM","teamId":3,"authorityEpoch":2,"hp":8,"hpMax":10,"used":1,"capacity":6,"contents":[{"kind":"ITEM","id":"rope","name":"麻绳","quantity":1}],"cooperation":{"gameSessionId":61,"authorityEpoch":2,"questions":[{"questKey":"q1","nodeId":34,"runtimeInstance":"r1"}]},"quests":[],"world":{"itemCatalog":[{"id":"rope","name":"麻绳"}],"tradeTargets":[{"teamId":4,"disabled":false}]}}}"#

    init(stale: Bool) {
        let snapshot = (try? PlayExperienceSyntheticFixtures.wire(Self.projection)).flatMap { PlayTeamBackpackSnapshot(projection: $0, activityID: 5) }
        self.snapshot = snapshot
        var form = snapshot.flatMap { s in s.trade.tradeTargets.first.flatMap { PlayTeamTradePreview.form(target: $0, snapshot: s) } }
        if form?.items.isEmpty == false { form?.items[0].give = "1" }
        self.form = form
        // The preview echoes this request's trade key and rows; a revision ahead of the backpack is the stale state.
        client = GParityFixtures.client(GParityTransport(route: { request in
            guard request.url?.path.hasSuffix("api/game/session/shared/preview") == true,
                  let payload = GParityTransport.json(request)["payload"] as? [String: Any],
                  let key = payload["tradeKey"] as? String,
                  let rows = try? JSONSerialization.data(withJSONObject: payload["give"] ?? [Any]()),
                  let give = String(data: rows, encoding: .utf8) else { return nil }
            return GParityTransport.ok(#"{"previewOnly":true,"expectedRevision":\#(stale ? 8 : 7),"authorityEpoch":2,"result":{"preview":true,"tradeKey":"\#(key)","toTeamId":4,"fromTeamId":3,"give":\#(give),"take":[],"fromUsed":0,"toUsed":2,"capacity":6}}"#)
        }))
    }
    var body: some View {
        if let snapshot, let form {
            PlayTeamTradePreviewSheet(form: form, snapshot: snapshot, client: { [client] in client }, reload: { nil })
        } else {
            Text(verbatim: "Synthetic TEAM projection did not decode").accessibilityIdentifier("g.trade.decodeFailed")
        }
    }
}
#endif
