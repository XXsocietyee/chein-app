#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/activity/official-detail/index` shows the event card,
/// category + 城瘾官方, the facts strip, title / intro / city, the attendance block (集合与联系, 到场签到), the story,
/// 活动任务 with the eligibility chip, rewards + collective progress, the leaderboard and the CTA bar; plus the
/// paused line, the ended CTA, the missing-event shell (返回列表) and the load failure with 重试. The page had no design
/// fixture, only the UI-test host (English "Synthetic city lights" data, guest / account buttons on top). These fixtures
/// mount the same `OfficialEventDetailView` the activity list pushes, offline, text in the UI language, no debug
/// controls: `t5-official-detail`, `-signup`, `-paused`, `-ended`, `-unavailable`, `-error`.
@MainActor final class OfficialDetailDesignFixtureReader: OfficialEventReading {
    enum Mode { case running, signup, paused, ended, unavailable, failure }
    let mode: Mode
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { false }

    init(mode: Mode) {
        self.mode = mode
    }

    static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    func events(city: String?) async throws -> [OfficialEvent] {
        []
    }

    func detail(id: Int) async throws -> OfficialEvent {
        switch mode {
        case .unavailable: throw OfficialReadFailure.unavailable
        case .failure: throw APIError.httpStatus(503)
        default: return try Self.event(id: id, mode: mode)
        }
    }

    func myEvents() async throws -> [OfficialEvent] {
        []
    }

    func partyInbox() async throws -> [OfficialPartyInvite] {
        []
    }

    func canPublish() async throws -> Bool { false }

    func myPublished() async throws -> OfficialPublished {
        try JSONDecoder().decode(OfficialPublished.self, from: Data("{}".utf8))
    }

    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats {
        try JSONDecoder().decode(OfficialBroadcastStats.self, from: Data("{}".utf8))
    }

    /// A v2 city-light event: running and signed (2 of 3 tasks done), open for signup, paused with a reason, or ended.
    private static func event(id: Int, mode: Mode) throws -> OfficialEvent {
        let hour: Double = 60 * 60 * 1000
        let day: Double = 24 * hour
        let now = Date().timeIntervalSince1970 * 1000
        var start = now - 2 * hour
        var end = now + 3 * day
        var status = 3
        var signed = true
        var progress = 2
        if mode == .signup {
            start = now + 5 * day
            end = now + 7 * day
            status = 2
            signed = false
            progress = 0
        } else if mode == .ended {
            start = now - 9 * day
            end = now - 2 * day
            status = 5
            progress = 3
        }
        let missions: [[String: Any]] = [
            ["missionCode": "lantern-gate", "missionType": "EVENT_POINT_ARRIVAL", "complete": progress >= 1,
             "title": tt("Reach the Lantern Gate", "抵达灯笼石门"),
             "description": tt("Check in within 100 m of the gate.", "在石门 100 米内打卡。")],
            ["missionCode": "tea-street", "missionType": "EVENT_POINT_ARRIVAL", "complete": progress >= 2,
             "title": tt("Tea Street corner", "茶街转角"),
             "description": tt("Find the old teahouse sign and check in.", "找到老茶馆招牌并打卡。")],
            ["missionCode": "bridge-finish", "missionType": "EVENT_POINT_ARRIVAL", "complete": progress >= 3,
             "canVerifyArrival": mode == .running,
             "title": tt("Finish at Gongchen Bridge", "拱宸桥终点"),
             "description": tt("Light the last lantern at the bridge.", "在桥头点亮最后一盏灯。")]
        ]
        var raw: [String: Any] = [
            "id": id, "status": status, "contractVersion": 2, "category": "city_light",
            "title": tt("West Lake Lights Night Walk", "西湖灯光夜游"),
            "subtitle": tt("Light up the old town, one lantern at a time", "一盏一盏点亮老城"),
            "city": tt("Hangzhou", "杭州"),
            "story": tt("When the lake goes dark, the lanterns along the old streets wait to be lit. Walk the route, reach each stop and light it for the whole city.",
                        "湖面暗下来以后，老街上的灯笼等着被点亮。沿着路线走到每一站，为整座城市点亮它。"),
            "participants": 128, "signed": signed, "myProgress": progress, "eligible": signed,
            "activityStart": start, "activityEnd": end, "roamEnabled": true, "bannerEnabled": "1",
            "paused": mode == .paused,
            "rewardJson": "{\"settleBadge\":true,\"settleXp\":50}",
            "missions": missions,
            "collective": ["enabled": true, "current": mode == .ended ? 100 : 64, "threshold": 100,
                           "pct": mode == .ended ? 100 : 64, "reached": mode == .ended]
        ]
        if mode == .paused {
            raw["pausedReason"] = tt("Heavy rain tonight. The walk resumes tomorrow at 19:00.", "今晚有大雨，明天 19:00 继续。")
        }
        if mode == .running || mode == .ended {
            raw["leaderboard"] = [
                "enabled": true, "myRank": 4, "final": mode == .ended,
                "rows": [
                    ["rank": 1, "name": tt("Mia", "小米"), "doneCount": 3, "totalCount": 3, "elapsedSeconds": 2710],
                    ["rank": 2, "name": tt("Leo Chen", "陈乐"), "doneCount": 3, "totalCount": 3, "elapsedSeconds": 3105],
                    ["rank": 3, "name": tt("Nina Zhou", "周宁"), "doneCount": 2, "totalCount": 3, "elapsedSeconds": 1980]
                ]
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(OfficialEvent.self, from: data)
    }

    /// MP event-attendance: meeting point with the organizer phone, check-in open now (running only).
    static func attendance() -> OfficialAttendanceSnapshot {
        let hour: Double = 60 * 60 * 1000
        let now = Date().timeIntervalSince1970 * 1000
        let raw: [String: Any] = [
            "dutyState": "ACTIVE", "configVersion": 1, "activeParticipation": true, "serverNow": now,
            "config": [
                "meetingName": tt("Broken Bridge east entrance", "断桥东入口"),
                "meetingAddress": tt("Beishan Street, Hangzhou", "杭州北山街"),
                "latitude": 30.2587, "longitude": 120.1512, "phone": "13900000000",
                "meetingAt": now + hour, "checkinOpenAt": now - hour, "checkinCloseAt": now + 2 * hour
            ],
            "mine": ["bib": "128"]
        ]
        return OfficialAttendanceSnapshot(raw: raw)
    }
}

/// Pushed page inside a stack, like the activity list fixtures.
struct OfficialDetailDesignFixture: View {
    @State private var reader: OfficialDetailDesignFixtureReader

    init(mode: OfficialDetailDesignFixtureReader.Mode) {
        _reader = State(initialValue: OfficialDetailDesignFixtureReader(mode: mode))
    }

    private var actions: PopupCloseEnvironmentActions {
        var actions = PopupCloseEnvironmentActions()
        if reader.mode == .running {
            actions.loadAttendance = { (_: Int, _: Bool) async -> OfficialAttendanceSnapshot? in
                OfficialDetailDesignFixtureReader.attendance()
            }
            actions.loadOfficialContact = { (_: Int) async -> OfficialPlayContact? in
                OfficialPlayContact(name: OfficialDetailDesignFixtureReader.tt("Lantern crew desk", "灯笼队服务台"),
                                    phone: "13900000000")
            }
        }
        return actions
    }

    var body: some View {
        NavigationStack {
            OfficialEventDetailView(id: 71, reader: reader)
        }
        .environment(\.popupCloseActions, actions)
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
