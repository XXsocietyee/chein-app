#if DEBUG
import SwiftUI

/// DEBUG design fixtures for the Hydrogen new-feature screens & view models:
/// RoamTerritoryView, PlayAudioClipStreamView, PlayKitNewGameForms (+ CYScratchCard),
/// PublishTabRootView, ExternalGameCreatorMonetizationSheet / Catalog, and weather-locked CharacterSheet.
/// All data is synthetic Simplified Chinese copy; unknown values render as "—".
enum NewFeatureFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "hfeat-roam-territory-nearby":
            return AnyView(HFeatRoamTerritoryHost(initialTab: .nearby))
        case "hfeat-roam-territory-mine":
            return AnyView(HFeatRoamTerritoryHost(initialTab: .mine))
        case "hfeat-roam-territory-leaderboard":
            return AnyView(HFeatRoamTerritoryHost(initialTab: .leaderboard))
        case "hfeat-roam-territory-unavailable":
            return AnyView(NavigationStack { RoamTerritoryView(service: nil) })
        case "hfeat-audio-clip":
            return AnyView(HFeatAudioClipHost(canWrite: true))
        case "hfeat-audio-clip-readonly":
            return AnyView(HFeatAudioClipHost(canWrite: false))
        case "hfeat-playkit-truefalse":
            return AnyView(HFeatPlayKitHost(kind: .trueFalse, completed: false))
        case "hfeat-playkit-truefalse-complete":
            return AnyView(HFeatPlayKitHost(kind: .trueFalse, completed: true))
        case "hfeat-playkit-imageguess":
            return AnyView(HFeatPlayKitHost(kind: .imageGuess, completed: false))
        case "hfeat-playkit-jigsaw":
            return AnyView(HFeatPlayKitHost(kind: .jigsaw, completed: false))
        case "hfeat-playkit-scratchcard":
            return AnyView(HFeatPlayKitHost(kind: .scratchCard, completed: false))
        case "hfeat-playkit-scratchcard-revealed":
            return AnyView(HFeatPlayKitHost(kind: .scratchCard, completed: true))
        case "hfeat-publish-tab-root":
            return AnyView(NavigationStack { PublishTabRootView().environmentObject(AppSession()) })
        case "hfeat-external-game-monetization":
            return AnyView(HFeatExternalGameHost(sheet: true))
        case "hfeat-external-game-catalog":
            return AnyView(HFeatExternalGameHost(sheet: false))
        case "hfeat-weather-character":
            return AnyView(HFeatWeatherCharacterHost())
        default:
            return nil
        }
    }
}

// MARK: - Roam Territory Fixture

@MainActor private struct HFeatRoamTerritoryHost: View {
    let initialTab: RoamTerritoryView.Tab
    @State private var service: RoamTerritoryService?
    @State private var cityGameService: CityGameHTTPService?

    var body: some View {
        NavigationStack {
            RoamTerritoryView(
                service: service,
                cityGameService: cityGameService,
                boardId: "board-hz-01",
                initialCoordinate: RoamCoordinate(latitude: 30.2586, longitude: 120.1502),
                captureFix: {
                    try RoamDeviceFix(
                        coordinate: RoamCoordinate(latitude: 30.2586, longitude: 120.1502)!,
                        accuracyMeters: 12,
                        measuredAt: Date(),
                        datum: .gcj02
                    )
                },
                initialTab: initialTab
            )
            .navigationTitle(Text(verbatim: initialTab == .mine ? "我的领地（调试样例）" : "漫游领地与棋盘（调试样例）"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { buildServicesIfNeeded() }
    }

    private func buildServicesIfNeeded() {
        guard service == nil,
              let base = URL(string: "https://fixture.example/prod-api/"),
              let config = try? APIConfiguration(baseURL: base),
              let lease = CityGameProductionLease(host: "fixture.example", regionID: "hz") else { return }
        let transport = HFeatRoamTerritoryTransport()
        service = try? RoamTerritoryService(
            configuration: config,
            token: "synthetic-fixture-token",
            lease: lease,
            transport: transport,
            isCurrent: { true }
        )
        cityGameService = try? CityGameHTTPService(
            configuration: config,
            token: "synthetic-fixture-token",
            lease: lease,
            transport: transport,
            isCurrent: { true }
        )
    }
}

private final class HFeatRoamTerritoryTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        let payload: Any
        if path.hasSuffix("api/roam/territory/nearby") {
            payload = [
                "boardId": "board-hz-01",
                "seasonId": "s2026w4",
                "revenueMode": "POINTS",
                "items": [
                    [
                        "territoryId": "tile-hz-101",
                        "poiId": 1001,
                        "boardId": "board-hz-01",
                        "seasonId": "s2026w4",
                        "propertyId": "prop-101",
                        "pointId": "断桥残雪碑",
                        "title": "断桥南口石碑",
                        "latitude": 30.2591,
                        "longitude": 120.1514,
                        "radiusM": 120,
                        "trackIndex": 6,
                        "distanceM": 120.0,
                        "claimed": true,
                        "ownerMemberId": 8801,
                        "ownerNickname": "西湖守望者",
                        "ownerRevenuePoints": 25,
                        "checkinTollPoints": 5,
                        "checkinCount": 14,
                        "revenueTotalPoints": 350,
                        "status": "已占领",
                        "isProtected": false,
                    ],
                    [
                        "territoryId": "tile-hz-102",
                        "poiId": 1002,
                        "boardId": "board-hz-01",
                        "seasonId": "s2026w4",
                        "propertyId": "prop-102",
                        "pointId": "雷峰夕照坪",
                        "title": "雷峰塔北广场",
                        "latitude": 30.2314,
                        "longitude": 120.1489,
                        "radiusM": 150,
                        "trackIndex": 14,
                        "distanceM": 480.0,
                        "claimed": false,
                        "ownerRevenuePoints": 30,
                        "checkinTollPoints": 10,
                        "checkinCount": 0,
                        "revenueTotalPoints": 0,
                        "status": "待占领",
                        "isProtected": false,
                    ],
                ],
            ] as [String: Any]
        } else if path.hasSuffix("api/roam/territory/my") {
            payload = [
                [
                    "territoryId": "terr-hz-01",
                    "pointId": "柳浪闻莺",
                    "title": "柳浪闻莺茶座",
                    "ownerRevenuePoints": 40,
                    "checkinTollPoints": 8,
                    "revenueMode": "POINTS",
                    "checkinCount": 18,
                    "revenueTotalPoints": 720,
                ]
            ] as [[String: Any]]
        } else if path.hasSuffix("api/roam/territory/leaderboard") {
            payload = [
                "boardId": "board-hz-01",
                "seasonId": "s2026w4",
                "revenueMode": "POINTS",
                "leaders": [
                    [
                        "ownerMemberId": 8801,
                        "ownerNickname": "西湖守望者",
                        "territoryCount": 4,
                        "totalRevenuePoints": 1260,
                        "totalCheckins": 34,
                    ],
                    [
                        "ownerMemberId": 8809,
                        "ownerNickname": "拱宸桥夜行客",
                        "territoryCount": 2,
                        "totalRevenuePoints": 680,
                        "totalCheckins": 19,
                    ],
                ],
                "topTerritories": [],
            ]
        } else if path.hasSuffix("api/city-game/dice/audit") {
            payload = [
                "boardId": "board-hz-01",
                "regionId": "hz",
                "teamId": "team-9",
                "diceId": "d6",
                "rolls": [
                    [
                        "rollId": "roll-hz-1",
                        "sourcePath": "UNIFIED_DICE_ROLL",
                        "faceValue": 5,
                        "previousPosition": 1,
                        "newPosition": 6,
                    ]
                ],
            ]
        } else {
            return (Data(#"{"code":404,"errorCode":"NOT_FOUND"}"#.utf8), 404)
        }
        let data = try JSONSerialization.data(withJSONObject: ["code": 200, "msg": "ok", "data": payload])
        return (data, 200)
    }
}

// MARK: - Audio Clip Fixture

@MainActor private struct HFeatAudioClipHost: View {
    let canWrite: Bool
    var body: some View {
        NavigationStack {
            if let config = try? PlayAudioClipConfiguration(minDurationSeconds: 5) {
                PlayAudioClipStreamView(
                    configuration: config,
                    canWrite: canWrite,
                    uploadAudio: { _, _ in "https://fixture.example/audio/hangzhou-clip.m4a" },
                    onSubmit: { _ in }
                )
            } else {
                Text(verbatim: "—")
                    .accessibilityLabel(Text("growth.unknownValue"))
            }
        }
    }
}

// MARK: - PlayKit New Game Forms Fixture

@MainActor private struct HFeatPlayKitHost: View {
    let kind: PlayKitScreenKind
    @State private var model: PlayAdvancedCoordinator

    init(kind: PlayKitScreenKind, completed: Bool) {
        self.kind = kind
        let session = try! PlayExperienceSession(accountID: 1, epoch: 1, namespace: "synthetic-hfeat", token: "synthetic-token")
        let service = PlayExperienceService(
            configuration: try! APIConfiguration(baseURL: URL(string: "https://example.com")!),
            transport: HFeatPlayKitTransport(completed: completed),
            enabled: [.reads, .advanced]
        )
        _model = State(initialValue: PlayAdvancedCoordinator(
            activityID: 41,
            topicID: 71,
            nodeID: 701,
            service: service,
            currentSession: { session }
        ))
    }

    var body: some View {
        NavigationStack { PlayKitScreen(model: model, kind: kind) }
            .task { await model.start() }
    }
}

@MainActor private final class HFeatPlayKitTransport: HTTPTransport {
    let completed: Bool
    init(completed: Bool) { self.completed = completed }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        if request.url?.path.hasSuffix("/action") == true { throw PlayExperienceError.invalidAction }
        let trueFalse: PlayWireValue = .object([
            "title": .string("西湖十景中的“苏堤春晓”由苏轼主持修筑。"),
            "finished": .bool(completed),
            "explanation": .string("北宋元祐五年，苏轼任杭州知州时疏浚西湖，用葑草与淤泥筑成南北长堤。"),
        ])
        let imageGuess: PlayWireValue = .object([
            "title": .string("根据局部景观线索，猜出这处西湖古迹"),
            "revealPercent": .int(completed ? 100 : 45),
            "revealLevel": .int(2),
            "totalClues": .int(4),
            "revealedClues": .array([.string("清晨可见湖面薄雾"), .string("位于孤山东麓放鹤亭畔")]),
            "answer": .string("林和靖墓与放鹤亭"),
            "finished": .bool(completed),
        ])
        let jigsaw: PlayWireValue = .object([
            "title": .string("拼合南宋御街手绘地图"),
            "rows": .int(2),
            "cols": .int(2),
            "order": .array([.int(2), .int(0), .int(3), .int(1)]),
            "moves": .int(3),
            "solved": .bool(completed),
            "finished": .bool(completed),
        ])
        let scratchCard: PlayWireValue = .object([
            "title": .string("河坊街茶馆密信"),
            "coverLabel": .string("轻滑刮开茶馆隐藏线索"),
            "prizeText": .string("解锁隐藏支线：拱宸桥夜茶与运河密函"),
            "threshold": .number(0.5),
            "revealed": .bool(completed),
            "finished": .bool(completed),
        ])
        let state: PlayWireValue = .object([
            "sessionId": .int(1),
            "activityId": .int(41),
            "topicId": .int(71),
            "nodeId": .int(701),
            "version": .int(1),
            "status": .string("RUNNING"),
            "readyForBase": .bool(false),
            "playKit": .object([
                "trueFalse": trueFalse,
                "imageGuess": imageGuess,
                "jigsaw": jigsaw,
                "scratchCard": scratchCard,
            ]),
        ])
        return (try JSONEncoder().encode(PlayWireValue.object(["code": .int(200), "data": state])), 200)
    }
}

// MARK: - External Game Monetization & Catalog Fixture

@MainActor private struct HFeatExternalGameHost: View {
    let sheet: Bool
    @State private var store = ExternalGameStore()
    @State private var model: ExternalGameReviewModel?

    private var fixtureSession: ExternalGameSessionBridge? {
        guard let url = URL(string: "https://www.chengyinhub.com") else { return nil }
        return ExternalGameSessionBridge(baseURL: url, token: "synthetic-fixture-token", transport: HFeatExternalGameTransport())
    }

    var body: some View {
        NavigationStack {
            if let model {
                if sheet {
                    ExternalGameCreatorMonetizationSheet(model: model, session: fixtureSession)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            ExternalGameCatalogSection(model: model, session: fixtureSession) {}
                        }
                        .padding(CYSpacing.md)
                    }
                    .cyDomainPageBackground()
                }
            } else {
                Text(verbatim: "—")
                    .accessibilityLabel(Text("growth.unknownValue"))
            }
        }
        .task { await prepare() }
    }

    private func prepare() async {
        guard model == nil else { return }
        let next = ExternalGameReviewModel(store: store)
        if let fixtureSession {
            await next.reload(session: fixtureSession)
            await next.loadCreatorSummary(session: fixtureSession)
        }
        model = next
    }
}

private final class HFeatExternalGameTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        let obj: [String: Any]
        if path == ExternalGameReviewPaths.signingKey {
            obj = ["code": 200, "data": ["configured": false]]
        } else if path == ExternalGameReviewPaths.catalog {
            obj = [
                "code": 200,
                "data": [
                    "items": [
                        [
                            "submissionId": "sub-hz-1",
                            "gameId": "westlake-treasure",
                            "version": "1.2.0",
                            "name": "西湖寻宝罗盘",
                            "author": "杭城匠人",
                            "summary": "基于湖滨步行的 HTML5 方位寻宝小游戏。",
                            "contentRating": "ALL_AGES",
                            "permissions": ["getMetadata", "submitResult"],
                            "allowedDomains": [],
                            "sha256": "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0",
                            "monetization": "NONE",
                        ]
                    ],
                    "hasMore": false,
                ],
            ]
        } else if path == ExternalGameReviewPaths.mine {
            obj = ["code": 200, "data": ["items": []]]
        } else if path == ExternalGameReviewPaths.monetization("westlake-treasure") {
            obj = [
                "code": 200,
                "data": [
                    "gameId": "westlake-treasure",
                    "gameName": "西湖寻宝罗盘",
                    "pricingMode": "PAID",
                    "priceFen": 600,
                    "currency": "CNY",
                    "creatorShareBps": 7000,
                    "channelFeeBearer": 0,
                    "trafficRewardMode": "POINTS",
                    "rewardPerPlayPoints": 15,
                    "rewardPerPlayFen": 0,
                    "dailyUserCap": 5,
                    "dailyGameCap": 200,
                    "minDurationMs": 15000,
                    "reviewStatus": "APPROVED",
                    "entitled": false,
                    "isOwner": true,
                    "moneyGateOpen": false,
                ],
            ]
        } else if path == ExternalGameReviewPaths.creatorSummary {
            obj = [
                "code": 200,
                "data": [
                    "paidOrders": 12,
                    "grossSalesFen": 7200,
                    "creatorSalesNetFen": 5040,
                    "trafficValidPlays": 86,
                    "trafficSettledPoints": 1290,
                    "trafficSettledFen": 0,
                    "moneyGateOpen": false,
                    "payoutGateOpen": false,
                    "configs": [],
                ],
            ]
        } else {
            obj = ["code": 404, "msg": "not found"]
        }
        return (try JSONSerialization.data(withJSONObject: obj), obj["code"] as? Int == 200 ? 200 : 404)
    }
}

// MARK: - Weather & Environment Character Sheet Fixture

@MainActor private struct HFeatWeatherCharacterHost: View {
    @StateObject private var session = AppSession()
    @State private var model: CharacterCardReadback?

    var body: some View {
        NavigationStack {
            if let model {
                CharacterCardReadbackView(session: session, model: model)
            } else {
                Text(verbatim: "—")
                    .accessibilityLabel(Text("growth.unknownValue"))
            }
        }
        .task { start() }
    }

    private func start() {
        guard model == nil,
              let base = URL(string: "https://fixture.example/native/"),
              let config = try? APIConfiguration(baseURL: base),
              let play = try? PlayExperienceSession(accountID: 1, epoch: 1, namespace: "synthetic-hfeat", token: "synthetic-fixture-token") else { return }
        let service = PlayExperienceService(configuration: config, transport: HFeatWeatherTransport(), enabled: [.reads])
        model = CharacterCardReadback(topicID: 71, activityID: nil, service: service, currentSession: { play })
    }
}

private final class HFeatWeatherTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let json = #"{"code":200,"data":{"topicId":71,"created":true,"running":true,"attributes":[{"stateKey":"insight","label":"洞察","value":6,"min":1,"max":10,"displayType":"BAR","persistScope":"TOPIC"},{"stateKey":"stamina","label":"体魄","value":7,"min":1,"max":10,"displayType":"BAR","persistScope":"TOPIC"}],"environment":{"weather":"rain","daypart":"evening","weekpart":"weekend","season":"unknown"}}}"#
        return (Data(json.utf8), 200)
    }
}
#endif
