#if DEBUG
import SwiftUI

/// E2 city / play-kit fixture hosts. They feed synthetic decoded values into the same Content views the real pages use
/// (the controllers behind them need live grants and transports that a fixture cannot honestly provide). DEBUG-only.
private func decoded<T: Decodable>(_ json: String) -> T? { try? JSONDecoder().decode(T.self, from: Data(json.utf8)) }

private let boardJSON = #"{"gameId":"g1","boardId":"b-hz-01","regionId":"hz","seasonId":"s2026w4","rulesReleaseId":"r-17","rulesHash":"0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0","lifecycle":"FROZEN","title":"杭州城市探索 · 第四轮","revision":3}"#
private let bindingJSON = #"{"releaseId":17,"revision":3,"regionId":"hz","boardId":"b-hz-01","seasonId":"s2026w4","rulesReleaseId":"r-17","contentHash":"0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0","title":"杭州城市探索 · 第四轮","rules":{"mode":"CITY_TEAM","joinPolicy":"INVITE_CODE","rosterPolicy":"CAPTAIN_LOCK_THEN_EACH_MEMBER_CONFIRM","replacementPolicy":"FORBIDDEN_AFTER_LOCK","reentryPolicy":"RESUME_ORIGINAL_SESSION","roundPolicy":"FIXED_PUBLISHED_ROUND","roundId":"round-4","minMembers":2,"maxMembers":5}}"#

struct E2RulesHost: View {
    private var snapshot: CityPlayerRulesSnapshot? {
        decoded(#"{"contract":"CITY_PLAYER_RULES_V1","scope":"CITY","status":"AVAILABLE","board":\#(boardJSON),"releaseId":17,"grantsParticipation":false,"grantsAction":false,"eligibility":{"status":"FORMING","teamId":"t-9","teamVersion":4,"present":true,"confirmed":false,"memberCount":3,"presentCount":3,"confirmedCount":1},"sections":[{"id":"rules","status":"PUBLISHED","rows":[{"key":"rulesId","value":"rules-hz-4"},{"key":"text","value":"每支队伍在本轮内共享行动点数。到达点位后需要商家当面确认，才能解锁点位任务。"}]},{"id":"dice","status":"PUBLISHED","rows":[{"key":"diceId","value":"d20"},{"key":"faces","value":"[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]"}]},{"id":"participation","status":"PUBLISHED","rows":[{"key":"mode","value":"CITY_TEAM"},{"key":"minMembers","value":"2"},{"key":"maxMembers","value":"5"},{"key":"joinPolicy","value":"INVITE_CODE"},{"key":"roundId","value":"round-4"}]},{"id":"actionBudget","status":"PUBLISHED","rows":[{"key":"scope","value":"TEAM_ROUND"},{"key":"unit","value":"ACTION"},{"key":"totalUnits","value":"12"},{"key":"rollCost","value":"1"}]},{"id":"settlement","status":"INTERNAL_BUDGET_ONLY","rows":[]}]}"#)
    }
    var body: some View {
        NavigationStack {
            CityPlayerRulesContent(phase: .ready, snapshot: snapshot, canRefresh: true, refresh: {})
                .navigationTitle(Text("cityRules.title", tableName: "CityPlayerRules")).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct E2ParticipationHost: View {
    let stage: Int
    @State private var invite = ""
    var body: some View {
        NavigationStack {
            CityParticipationContent(display: display, inviteCode: $invite, inviteChanged: {}, readInvite: {}, prepare: { _ in }, confirm: {}, cancel: {}, recheck: {}, reload: {})
                .navigationTitle("城市队伍参与").navigationBarTitleDisplayMode(.inline)
        }
    }
    private var display: CityParticipationDisplay {
        var d = CityParticipationDisplay(title: "杭州城市探索 · 第四轮", hasState: true, team: (3, true, false), writeOpen: true,
                                         kinds: [.confirm, .lock, .exit], canPrepare: true)
        if stage == 1 { d.prepared = .confirm }
        if stage == 2 { d.team = nil; d.kinds = [.create, .join]; d.invitationMembers = 3 }
        return d
    }
}

struct E2NeutralHost: View {
    @State private var selections: [String: String] = ["n-2": "o-b"]
    private var snapshot: CityNeutralTaskSnapshot? {
        decoded(#"{"contract":"C","scope":"CITY","status":"AVAILABLE","writeApproved":true,"binding":\#(bindingJSON),"teamId":"t-9","sessionId":"s-1","teamVersion":4,"tasks":[{"definition":{"taskId":"n-1","title":"西湖十景问答","type":"QA_PICK","access":"REMOTE_NEUTRAL","arrivalRequirement":"NONE","scope":"TEAM_ROUND","question":"“断桥残雪”属于西湖十景中的哪一个季节景观？","options":[{"id":"o-a","label":"春"},{"id":"o-b","label":"冬"}],"maxAttempts":3,"pointCost":0,"pointReward":0,"actionCost":0},"status":"NOT_ACCEPTED","version":1,"attempts":0},{"definition":{"taskId":"n-2","title":"雷峰塔小测","type":"QA_PICK","access":"REMOTE_NEUTRAL","arrivalRequirement":"NONE","scope":"TEAM_ROUND","question":"雷峰塔重建于哪一年？","options":[{"id":"o-a","label":"1924 年"},{"id":"o-b","label":"2002 年"},{"id":"o-c","label":"1999 年"}],"maxAttempts":3,"pointCost":0,"pointReward":0,"actionCost":0},"status":"ACTIVE","version":2,"attempts":1},{"definition":{"taskId":"n-3","title":"苏堤春晓","type":"QA_PICK","access":"REMOTE_NEUTRAL","arrivalRequirement":"NONE","scope":"TEAM_ROUND","question":"苏堤由哪位文人主持修筑？","options":[{"id":"o-a","label":"苏轼"},{"id":"o-b","label":"白居易"}],"maxAttempts":3,"pointCost":0,"pointReward":0,"actionCost":0},"status":"COMPLETED","version":3,"attempts":1,"result":{"resultId":"res-1","outcome":"RECORDED","requestId":"req-1","createdAt":"2026-11-09T10:24:00Z","verifier":"SERVER","attemptNumber":1}}]}"#)
    }
    var body: some View {
        NavigationStack {
            CityNeutralTaskContent(snapshot: snapshot, messageKey: "cityNeutral.status.ready", busy: false, pendingRequestID: nil, receipt: nil,
                                   allows: { _ in true }, selections: $selections, reload: {}, accept: { _ in }, submit: { _ in }, selectionChanged: {},
                                   recover: {}, canRecover: true, openResult: {})
                .navigationTitle(Text("cityNeutral.title", tableName: "CityNeutralTask")).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct E2OnsiteHost: View {
    @State private var selections: [String: String] = [:]
    private var snapshot: CityOnsiteTaskSnapshot? {
        let def = { (id: String, title: String, q: String) in #"{"taskId":"\#(id)","pointId":"p-lake","title":"\#(title)","type":"QA_PICK","access":"ONSITE_ZERO_EFFECT","arrivalRequirement":"MERCHANT_ATTESTED","scope":"MEMBER_POINT_TEAM_ROUND","question":"\#(q)","acceptanceReason":"商家当面确认到场","evidencePolicy":"SAME_EVIDENCE_VALID_ON_ACCEPT_AND_EACH_SUBMIT","evidenceUse":"SINGLE_TASK_INSTANCE","reviewerPolicy":"CURRENT_STORE_PERMISSION_AND_REVIEWER_VERIFY","effectsPolicy":"NONE","options":[{"id":"o-a","label":"柜台左侧的青铜钟"},{"id":"o-b","label":"门口的石狮"},{"id":"o-c","label":"二楼楼梯口的壁画"}],"maxAttempts":3,"pointCost":0,"pointReward":0,"actionCost":0}"# }
        let evidence = #","evidence":{"evidenceId":"ev-7","pointId":"p-lake","teamId":"t-9","sessionId":"s-1","contentHash":"x","policyHash":"y","roundId":"round-4","expiresAt":"2026-11-09T18:00:00.000Z","assurance":"MERCHANT_ATTESTED","memberId":7,"merchantId":5,"placeId":9,"releaseId":17}"#
        return decoded(#"{"contract":"C","scope":"CITY","status":"AVAILABLE","writeApproved":true,"binding":\#(bindingJSON),"teamId":"t-9","sessionId":"s-1","teamVersion":4,"memberId":7,"tasks":[{"definition":\#(def("t-1","茶馆里的老物件","店里哪件物品最能代表这家茶馆的历史？")),"status":"ACTIVE","eligibility":"ELIGIBLE","canAct":true,"version":2,"attempts":1\#(evidence)}]}"#)
    }
    var body: some View {
        NavigationStack {
            CityOnsiteTaskContent(snapshot: snapshot, messageKey: "cityOnsite.status.ready", busy: false, interactive: true, selectedResult: nil,
                                  originalRequestID: nil, pendingRequestID: nil, receipt: nil, allows: { _ in true }, selections: $selections,
                                  reload: {}, accept: { _ in }, submit: { _ in }, selectionChanged: {}, readResult: { _ in }, closeResult: {}, recover: {}) {
                Label { CityArrivalCopy.text("playerEntry") } icon: { Image(systemName: "checkmark.shield") }
            }
            .navigationTitle(Text("cityOnsite.title", tableName: "CityOnsiteTask")).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct E2ArrivalHost: View {
    private func point(_ id: String, _ title: String, challenge: Bool) -> CityArrivalPoint? {
        let ch = challenge ? #","challenge":{"challengeId":"c-1","requestId":"q-1","pointId":"\#(id)","teamId":"t-9","sessionId":"s-1","contentHash":"x","state":"ISSUED","expiresAt":"2026-11-09T11:30:00Z","regionId":"hz","boardId":"b","seasonId":"s","roundId":"round-4","rulesReleaseId":"r-17","policyHash":"y","memberId":7,"merchantId":5,"placeId":9,"releaseId":17,"version":1,"ordinal":1}"# : ""
        return decoded(#"{"pointId":"\#(id)","title":"\#(title)","availability":"AVAILABLE","merchantId":5,"placeId":9,"rules":{"pointId":"\#(id)","method":"SERVER_CHALLENGE_MEMBER_SUBMIT_STAFF_CONFIRM","assurance":"MERCHANT_ATTESTED","assuranceReason":"商家当面确认","evidenceScope":"MEMBER_POINT_TEAM_ROUND","effectsPolicy":"EVIDENCE_ONLY_NO_AUTOMATIC_EFFECTS","renewalPolicy":"NO_REISSUE_AFTER_EVIDENCE","placeRef":{"domain":"POI","source":"roam_poi","id":"9"},"challengeTtlSeconds":600,"evidenceTtlSeconds":7200,"maxChallenges":3},"attemptVersion":1,"canIssue":true\#(ch)}"#)
    }
    var body: some View {
        NavigationStack {
            CYCardPage {
                CYArtCoverHeader(title: CityArrivalCopy.text("title"), subtitle: CityArrivalCopy.text("boundary"), symbol: "mappin.and.ellipse", seed: "arrival") { EmptyView() }
            } content: {
                if let a = point("p-tea", "湖滨茶馆", challenge: false) {
                    CityArrivalPointCard(point: a, code: nil, canWrite: true, busy: false, current: true, issue: {}, submit: {}, readProof: {})
                }
                if let b = point("p-lake", "断桥石碑", challenge: true) {
                    CityArrivalPointCard(point: b, code: "482 913", canWrite: true, busy: false, current: true, issue: {}, submit: {}, readProof: {})
                }
            }
            .navigationTitle(CityArrivalCopy.text("title")).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct E2OrderedMapHost: View {
    @State private var selected: String? = "p-02"
    private var snapshot: CityCurrentSnapshot? {
        let pt = { (id: String, title: String, avail: String, own: String, lat: String, lon: String, mine: Bool) in
            #"{"pointId":"\#(id)","title":"\#(title)","latitude":\#(lat),"longitude":\#(lon),"domain":"POI","datum":"GCJ02","collectedAt":"2026-11-01","coordinateAssurance":"PLATFORM_REVIEWED_METADATA","availability":"\#(avail)","merchantVersion":1,"platformVersion":1,"mine":\#(mine),"ownership":"\#(own)","grantsNavigation":false,"grantsAction":false}"#
        }
        let b = #"{"south":30.2,"west":120.1,"north":30.3,"east":120.2}"#
        return decoded(#"{"contract":"CITY_CURRENT_SNAPSHOT_V1","scope":"CITY","mode":"CURRENT_SNAPSHOT","deltaStatus":"DELTAS_UNAVAILABLE","deltaReason":"AUTHORIZATION_LIFETIME_UNAVAILABLE","board":{"gameId":"g1","boardId":"b","regionId":"hz","seasonId":"s","rulesReleaseId":"r-17","rulesHash":"x","lifecycle":"FROZEN","title":"杭州城市探索 · 第四轮","revision":3},"boardVersion":3,"membership":"JOINED","points":[\#(pt("p-01","断桥石碑","AVAILABLE","OUR_TEAM","30.2591","120.1493",true)),\#(pt("p-02","湖滨茶馆","AVAILABLE","UNOWNED","30.2562","120.1601",false)),\#(pt("p-03","雷峰塔下","PAUSED","OTHER_TEAM","30.2312","120.1487",false)),\#(pt("p-04","苏堤春晓","AVAILABLE","UNOWNED","30.2440","120.1380",false))],"mapRead":{"contract":"CITY_BOUNDED_MAP_V1","datum":"GCJ02","initialViewport":\#(b),"initialZoom":14,"maxViewportSpanDegrees":0.5,"minZoom":10,"maxZoom":18,"pageSize":50,"maxPages":4},"viewport":\#(b),"datum":"GCJ02","zoom":14,"layers":["POI"],"complete":true,"capturedAtMillis":1792382400000,"grantsNavigation":false,"grantsAction":false}"#)
    }
    var body: some View {
        NavigationStack {
            if let snapshot {
                CityOrderedMapContent(snapshot: snapshot, selected: snapshot.points.first(where: { $0.pointId == selected }),
                                      select: { selected = $0 }, refresh: {}, canRefresh: true)
                    .navigationTitle("城市地图更新").navigationBarTitleDisplayMode(.inline)
            } else { Text(verbatim: "DEBUG: snapshot JSON failed to decode") }
        }
    }
}

// MARK: - Free-explore bundle (real view + real model on an in-memory service)

struct E2BundleHost: View {
    @State private var model: FreeExploreBundleLaunchModel?
    var body: some View {
        NavigationStack {
            if let model { FreeExploreBundleLaunchView(model: model) } else { CYSkeleton().padding(CYSpacing.pageHorizontal) }
        }
        .task {
            guard model == nil, let service = try? E2BundleService() else { return }
            let m = try? FreeExploreBundleLaunchModel(topicID: FreeExploreLaunchID(88), registrationID: FreeExploreLaunchID(41), service: service,
                                                      pending: FreeExploreLaunchPendingStore(storage: E2MemStore(), session: service.session), dispatchAllowed: { true })
            await m?.load(); model = m
        }
    }
}
private final class E2MemStore: TemplateAuthoringStorage {
    var values: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws { values[key] = data }
    func remove(_ key: String) throws { values.removeValue(forKey: key) }
}
@MainActor private final class E2BundleService: FreeExploreLaunchServing {
    let session: FreeExploreLaunchSession
    var isCurrent: Bool { true }
    var permitsReservationDispatch: Bool { true }
    init() throws {
        session = try .init(baseURL: URL(string: "https://example.test")!, accountID: 7, market: "CN", namespace: "fixture", role: "player", epoch: 1, token: "synthetic-token")
    }
    private func decode<T: Decodable>(_ value: Any) throws -> T { try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value)) }
    func catalog(topicID: FreeExploreLaunchID) async throws -> FreeExploreLaunchCatalog {
        try decode(["topicId": 88, "topicName": "杭州 · 周末自由探索包", "productType": 2, "saleEnabled": false, "reservationEnabled": true, "items": [
            ["chapterId": 3, "name": "章节一 · 老城茶事", "termsMode": "任选一家门店预约", "unitsPerHolder": 1, "stores": [["offerId": 29, "merchantName": "湖滨茶馆", "validEnd": "2026-12-31"], ["offerId": 30, "merchantName": "河坊街点心铺", "validEnd": "2026-12-31"]]],
            ["chapterId": 4, "name": "章节二 · 运河黄昏", "termsMode": "任选一家门店预约", "unitsPerHolder": 1, "stores": [["offerId": 41, "merchantName": "拱宸桥咖啡", "validEnd": "2026-12-31"]]]]])
    }
    func order(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchOrder {
        try decode(["registrationId": 41, "bundle": ["order": ["registrationId": 41, "holderMemberId": 7, "topicId": 88],
            "units": [["id": 17, "registrationId": 41, "holderMemberId": 7, "chapterId": 3, "status": "AVAILABLE"], ["id": 18, "registrationId": 41, "holderMemberId": 7, "chapterId": 4, "status": "AVAILABLE"]],
            "reservations": []]])
    }
    func reserve(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation { throw URLError(.cancelled) }
    func receipt(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation? { nil }
    func refundQuote(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchRefundQuote { throw FreeExploreLaunchFailure.disabled }
}

/// DEBUG-only host for the real `PlayKitScreen` forms: a static synthetic transport serves one node state, so the
/// play-kit cards, choice rows and fields are shot as shipped. Never writes (every action is rejected).
@MainActor private final class E2PlayKitTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        if request.url?.path.hasSuffix("/action") == true { throw PlayExperienceError.invalidAction }
        func opt(_ id: String, _ label: String) -> PlayWireValue { .object(["id": .string(id), "label": .string(label)]) }
        let qa: PlayWireValue = .object(["title": .string("断桥的名字从哪里来？"), "mode": .string("PICK"), "maxAttempts": .int(3), "attempts": .int(0), "remainingAttempts": .int(3),
            "options": .array([opt("a", "雪后初晴时桥面残雪未消"), opt("b", "桥因战乱被拦腰折断"), opt("c", "桥下常年没有水流")])])
        let profile: PlayWireValue = .object(["title": .string("给这趟旅程留个名片"), "avatar": .object(["enabled": .bool(false)]),
            "questions": .array([
                .object(["key": .string("mood"), "label": .string("今天的心情"), "kind": .string("pick"), "options": .array([.object(["key": .string("calm"), "label": .string("安静")]), .object(["key": .string("bold"), "label": .string("想多走走")])])]),
                .object(["key": .string("word"), "label": .string("用一句话形容西湖"), "kind": .string("text"), "maxLength": .int(40)]),
                .object(["key": .string("pace"), "label": .string("你的步调"), "kind": .string("text"), "maxLength": .int(20)])])])
        let note: PlayWireValue = .object(["title": .string("留一句话给下一位旅人"), "maxLength": .int(80), "presets": .array([.string("湖边的风很舒服"), .string("推荐傍晚来")]),
            "previous": .array([.object(["text": .string("桥头的桂花糕值得排队。"), "at": .number(1_792_382_400_000)])])])
        let photo: PlayWireValue = .object(["title": .string("拍下今天的断桥"), "shotNote": .string("让桥身和水面同时入镜"), "tries": .int(1), "maxTries": .int(3)])
        let state: PlayWireValue = .object(["sessionId": .int(1), "activityId": .int(41), "topicId": .int(71), "nodeId": .int(701), "version": .int(1), "status": .string("RUNNING"), "readyForBase": .bool(false),
            "playKit": .object(["qa": qa, "profile": profile, "note": note, "photoCheck": photo])])
        return (try JSONEncoder().encode(PlayWireValue.object(["code": .int(200), "data": state])), 200)
    }
}

@MainActor struct E2PlayKitHost: View {
    let kind: PlayKitScreenKind
    @State private var model: PlayAdvancedCoordinator
    init(kind: PlayKitScreenKind) {
        self.kind = kind
        let session = try! PlayExperienceSession(accountID: 1, epoch: 1, namespace: "synthetic-e2", token: "synthetic-token")
        let service = PlayExperienceService(configuration: try! APIConfiguration(baseURL: URL(string: "https://example.com")!), transport: E2PlayKitTransport(), enabled: [.reads, .advanced])
        _model = State(initialValue: PlayAdvancedCoordinator(activityID: 41, topicID: 71, nodeID: 701, service: service, currentSession: { session }))
    }
    var body: some View {
        NavigationStack { PlayKitScreen(model: model, kind: kind) }.task { await model.start() }
    }
}
#endif
