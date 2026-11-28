#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/activity/official-organizer/index` (主办控制台)
/// renders loading 正在确认主办身份, missing-param, no-permission 只有本场主办方可以使用控制台, load failure
/// 控制台加载失败 + 重试, and the ready page whose head card shows the control badge (正常 / 已暂停), 生命周期,
/// 暂停原因 or 最近恢复说明, then 发布活动 with the publish-check result and 风险：. The shared `t13-organizer`
/// fixtures cover a scheduled event (Chinese title in both languages) and the denied state only. These
/// fixtures mount the same `OfficialOrganizerConsoleView` with an offline access, titles in the UI language:
/// `t5-official-organizer` (draft, check passed with one risk), `-blocked` (draft, check blocked),
/// `-paused` (paused with a reason), `-error` (the load fails). No command reaches a server; a confirmed
/// command comes back rejected, so no recovery card is stored for a later launch.
@MainActor final class OfficialOrganizerDesignFixtureAccess: OfficialOrganizerAccess {
    enum Mode { case draft, blocked, paused, failure }
    let mode: Mode
    let accountID: Int? = 808
    let enabled = true

    init(mode: Mode) {
        self.mode = mode
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    func publishCheck(eventID: Int) async throws -> OfficialOrganizerCheckResult {
        switch mode {
        case .failure:
            throw APIError.httpStatus(503)
        case .blocked:
            let blockers = [
                Self.tt("Add a meeting point before publishing", "发布前请先填写集合地点"),
                Self.tt("Set at least one ticket type", "至少设置一个票种")
            ]
            return .allowed(OfficialOrganizerCheck(known: true, blockers: blockers, risks: [], risksKnown: true))
        case .draft:
            let risks = [Self.tt("Start time is within 24 hours; registered players get less notice", "开始时间不足 24 小时，已报名玩家的提醒时间较短")]
            return .allowed(OfficialOrganizerCheck(known: true, blockers: [], risks: risks, risksKnown: true))
        case .paused:
            return .allowed(OfficialOrganizerCheck(known: true, blockers: [], risks: [], risksKnown: true))
        }
    }

    func eventState(eventID: Int) async throws -> OfficialOrganizerEventState? {
        switch mode {
        case .failure:
            throw APIError.httpStatus(503)
        case .draft, .blocked:
            return OfficialOrganizerEventState(
                status: OfficialOrganizerEventState.draft,
                control: .normal,
                title: Self.tt("Canal Spring Orienteering", "运河春日定向赛")
            )
        case .paused:
            return OfficialOrganizerEventState(
                status: OfficialOrganizerEventState.scheduled,
                control: .paused,
                title: Self.tt("West Lake Lights Night Walk", "西湖灯光夜游"),
                pausedReason: Self.tt("Heavy rain warning tonight; we will reopen when it clears", "今晚暴雨预警，天气好转后恢复")
            )
        }
    }

    func command(_ command: OfficialOrganizerCommand, mode: OfficialOrganizerCommandMode) async throws -> OfficialOrganizerReceipt? {
        OfficialOrganizerReceipt(requestId: command.requestId, state: .rejected, message: Self.tt("Example only: nothing was sent", "示例页面：没有发送任何操作"))
    }
}

struct OfficialOrganizerDesignFixture: View {
    @State private var access: OfficialOrganizerDesignFixtureAccess
    private let eventID: Int

    init(mode: OfficialOrganizerDesignFixtureAccess.Mode) {
        _access = State(initialValue: OfficialOrganizerDesignFixtureAccess(mode: mode))
        eventID = mode == .paused ? 9101 : 9102
    }

    var body: some View {
        NavigationStack {
            OfficialOrganizerConsoleView(eventID: eventID, access: access)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
