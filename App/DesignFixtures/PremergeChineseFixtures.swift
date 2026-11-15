#if DEBUG
import SwiftUI

/// Premerge Groups A-D Simplified Chinese design fixtures (DEBUG only, strictly offline synthetic data).
/// Unknown or unconfirmed numeric/text values are represented explicitly as "—" (never 0 or 0/0).
/// Launch with `--design-fixture premerge-<variant>`.
enum PremergeChineseFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "premerge-e1-activity":
            return wrapPlayer(PremergeActivityPartsFixture(unknown: false))
        case "premerge-e1-activity-unknown":
            return wrapPlayer(PremergeActivityPartsFixture(unknown: true))
        case "premerge-play-task":
            return wrapPlayer(PremergePlayTaskFixture(unknown: false))
        case "premerge-play-task-unknown":
            return wrapPlayer(PremergePlayTaskFixture(unknown: true))
        case "premerge-task-status-cards":
            return wrapPlayer(PremergeTaskStatusCardsFixture())
        case "premerge-team-pool":
            return wrapPlayer(PremergeTeamPoolFixture(unknownScore: false))
        case "premerge-team-pool-unknown":
            return wrapPlayer(PremergeTeamPoolFixture(unknownScore: true))
        default:
            return nil
        }
    }

    @MainActor private static func wrapPlayer<V: View>(_ view: V) -> AnyView {
        AnyView(
            view
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .themeDomain(.player)
                .cyDomainPageBackground()
                .preferredColorScheme(.dark)
        )
    }
}

@MainActor private struct PremergeActivityPartsFixture: View {
    let unknown: Bool

    private var detail: ActivityDetail? {
        let json: String
        if unknown {
            json = #"""
            {
              "id": 9102,
              "name": "杭州宋韵古城夜游（未知数据预览）",
              "categoryName": null,
              "startDate": null,
              "endDate": null,
              "address": null,
              "signUpNum": null,
              "omsTicketList": []
            }
            """#
        } else {
            json = #"""
            {
              "id": 9101,
              "name": "杭州宋韵古城文化探秘夜游",
              "categoryName": "城市实景解谜",
              "startDate": "2026-11-20T18:30:00Z",
              "endDate": "2026-11-20T20:30:00Z",
              "address": "杭州市上城区清河坊南宋御街鼓楼广场",
              "signUpNum": 18,
              "omsTicketList": [
                {"id": 1, "name": "单人畅玩票", "price": 128.0, "stock": 12}
              ]
            }
            """#
        }
        return try? JSONDecoder().decode(ActivityDetail.self, from: Data(json.utf8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if let detail {
                    E1ActivityStatsRow(detail: detail)
                    E1ActivityInfoCard(detail: detail)
                }
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }
}

@MainActor private struct PremergePlayTaskFixture: View {
    let unknown: Bool

    private var snapshot: PlaySnapshot? {
        let json: String
        if unknown {
            json = #"""
            {
              "topicId": 88,
              "topicName": "西湖十景城市漫游（进度未知）",
              "mode": 1,
              "playable": true,
              "registered": true,
              "total": null,
              "doneCount": null,
              "nodes": [
                {"id": 1, "name": "断桥残雪打卡点", "done": false, "needScan": true}
              ],
              "chapters": []
            }
            """#
        } else {
            json = #"""
            {
              "topicId": 88,
              "topicName": "西湖十景城市漫游",
              "mode": 1,
              "playable": true,
              "registered": true,
              "total": 5,
              "doneCount": 2,
              "nodes": [
                {"id": 1, "name": "断桥残雪", "done": true},
                {"id": 2, "name": "白堤锦带", "done": true},
                {"id": 3, "name": "平湖秋月", "done": false, "needGPS": true, "arrived": true}
              ],
              "chapters": []
            }
            """#
        }
        guard let result = try? JSONDecoder().decode(PlayNodesResult.self, from: Data(json.utf8)) else { return nil }
        return try? PlaySnapshot(scope: .topic(88), result: result)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if let snapshot {
                    PlayTaskSummaryView(snapshot: snapshot, phase: unknown ? "unknown" : "ready")
                }
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }
}

@MainActor private struct PremergeTaskStatusCardsFixture: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYTaskStatusCard(
                    title: "第一站 · 鼓楼钟声解谜",
                    state: .completed(receiptNo: "CY-20261114-01", completedAt: "14:20", onViewReceipt: {})
                )
                CYTaskStatusCard(
                    title: "第二站 · 清河坊茶寮打卡",
                    state: .available(methodLabel: "线索解谜 · 已到达", ctaTitle: "开始打卡", onStart: {})
                )
                CYTaskStatusCard(
                    title: "第三站 · 万松书院碑刻",
                    state: .submitting(requestId: "req-hangzhou-03")
                )
                CYTaskStatusCard(
                    title: "第四站 · 雷峰夕照终章",
                    state: .locked(requirement: "请先完成前三站线索验证", prereqTitle: "万松书院碑刻", onOpenPrereq: {})
                )
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }
}

private struct PremergeTeamPoolStubTransport: HTTPTransport {
    let unknownScore: Bool
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let scoreField = unknownScore ? "null" : "320"
        let json = """
        {
          "code": 200,
          "msg": "ok",
          "data": {
            "teamId": 1001,
            "topicId": 88,
            "activityId": 9101,
            "enabled": true,
            "hintsTotal": 3,
            "hintsUsed": 1,
            "hintsLeft": 2,
            "skipsTotal": 2,
            "skipsUsed": 0,
            "skipsLeft": 2,
            "timerLimitSec": 1800,
            "teamScore": \(scoreField),
            "solvedNodeIds": [1, 2]
          }
        }
        """
        return (Data(json.utf8), 200)
    }
}

@MainActor private struct PremergeTeamPoolFixture: View {
    @State private var model: TeamPoolHintModel?
    let unknownScore: Bool

    var body: some View {
        Form {
            if let model {
                TeamPoolRunStatusSection(model: model)
            }
        }
        .scrollContentBackground(.hidden)
        .task {
            guard model == nil,
                  let config = try? APIConfiguration(baseURL: URL(string: "https://example.test")!) else { return }
            let service = TeamPoolService(
                configuration: config,
                transport: PremergeTeamPoolStubTransport(unknownScore: unknownScore),
                token: { "fixture-token" }
            )
            let instance = TeamPoolHintModel(service: service, nodeID: 3, resolveTeam: { 1001 })
            await instance.load()
            model = instance
        }
    }
}
#endif
