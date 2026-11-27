import XCTest
@testable import Questify

/// Components r1 R-island (plan Live Activity mapping, token request) and R-steps (`CYStepChecklistMath`).
@MainActor final class QuestPlanActivityAndChecklistTests: XCTestCase {
    private let localize: (String) -> String = { key in
        switch key {
        case "plan.teamInvite.note": return "%1$@ invited you to %2$@"
        case "plan.teamInvite.noteNoInviter": return "Invited to %@"
        case "plan.teamStatus.noteCount": return "%1$lld/%2$lld done"
        default: return key
        }
    }

    private func offer(_ id: String, state: String, canAct: Bool = true, recipient: Bool = true) throws -> NativeFriendTeamOffer {
        let value: [String: Any] = ["viewer_id": 7, "offer_id": id, "team_id": "42", "name": "Night Walkers", "state": state,
                                    "recipient": recipient, "can_act": canAct, "join_mode": 1]
        return try JSONDecoder().decode(NativeFriendTeamOffer.self, from: JSONSerialization.data(withJSONObject: value))
    }

    func testWaitingInviteBecomesPlanCardWithTeamLink() throws {
        let id = UUID().uuidString.lowercased()
        let plans = QuestPlanActivityMapping.teamInvites([try offer(id, state: "WAITING_CONFIRM")], localize: localize)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.planKey, "offer:" + id)
        XCTAssertEqual(plans.first?.targetID, 42)
        XCTAssertEqual(plans.first?.content.note, "Invited to Night Walkers")
        XCTAssertEqual(plans.first?.content.showsActions, true)
        XCTAssertEqual(QuestPlanLinks.join(kind: .teamInvite, targetID: 42)?.absoluteString,
                       "chein://mp/pages/team/detail/index?teamId=42")
    }

    func testAnsweredOrForeignInvitesAreNotShown() throws {
        let declined = try offer(UUID().uuidString.lowercased(), state: "DECLINED", canAct: false)
        let sent = try offer(UUID().uuidString.lowercased(), state: "WAITING_CONFIRM", recipient: false)
        XCTAssertTrue(QuestPlanActivityMapping.teamInvites([declined, sent], localize: localize).isEmpty)
        let joined = try offer(UUID().uuidString.lowercased(), state: "JOINED", canAct: false)
        XCTAssertEqual(QuestPlanActivityMapping.teamInvites([joined], localize: localize).first?.content.joined, true)
    }

    func testClubEventTodayNudgesAndOtherDaysDoNot() {
        let now = Date()
        let today = ClubEventDay(date: now)
        let tomorrow = ClubEventDay(date: now.addingTimeInterval(36 * 60 * 60))
        let events = [ClubCalendarEvent(id: 3, name: "Tomorrow", startDay: tomorrow), ClubCalendarEvent(id: 5, name: "River run", startDay: today)]
        let plan = QuestPlanActivityMapping.clubEvent(clubID: 9, clubName: "Runners", events: events, now: now, localize: localize)
        XCTAssertEqual(plan?.descriptor.planKey, "club-event:5")
        XCTAssertEqual(plan?.descriptor.content.note, "River run")
        XCTAssertGreaterThan(plan?.staleDate ?? .distantPast, now)
        XCTAssertNil(QuestPlanActivityMapping.clubEvent(clubID: 9, clubName: nil, events: [events[0]], now: now, localize: localize))
    }

    func testTeamStatusNamesTheMemberWhoseStatusChanged() {
        let before = [PlayPlayerTeamMember(id: 1, displayName: "Lena", roleCode: nil, status: .inProgress),
                      PlayPlayerTeamMember(id: 2, displayName: "Kai", roleCode: nil, status: .inProgress)]
        let after = [PlayPlayerTeamMember(id: 1, displayName: "Lena", roleCode: nil, status: .completed),
                     PlayPlayerTeamMember(id: 2, displayName: "Kai", roleCode: nil, status: .inProgress)]
        let plan = QuestPlanActivityMapping.teamStatus(scope: "77", title: nil, previous: before, current: after, localize: localize)
        XCTAssertEqual(plan?.planKey, "team-status:77")
        XCTAssertEqual(plan?.content.note, "Lena playerTeam.status.completed")
        XCTAssertEqual(plan?.content.done, 1)
        XCTAssertEqual(plan?.content.total, 2)
        let unchanged = QuestPlanActivityMapping.teamStatus(scope: "77", title: nil, previous: after, current: after, localize: localize)
        XCTAssertEqual(unchanged?.content.note, "1/2 done")
        XCTAssertNil(QuestPlanActivityMapping.teamStatus(scope: "77", title: nil, previous: [], current: [after[0]], localize: localize))
    }

    func testStickersAcceptSymbolsAndSingleEmojiOnly() {
        let content = QuestPlanContent(headline: "Walk tonight?", stickers: ["moon.stars.fill", "👋", "free text!"])
        XCTAssertEqual(content.visibleStickers, [.symbol("moon.stars.fill"), .emoji("👋")])
        XCTAssertNil(QuestPlanSticker("hello world"))
    }

    func testTuckedCardHidesActions() {
        var content = QuestPlanContent(headline: "Walk tonight?")
        XCTAssertTrue(content.showsActions)
        content.tucked = true
        XCTAssertFalse(content.showsActions)
    }

    func testTokenRequestEncodesHexAndValidatesScope() throws {
        let start = QuestPlanActivityTokenRequest(scope: .pushToStart, token: Data([0xab, 0x01]), planKey: nil, activityId: nil,
                                                  environment: "SANDBOX", bundleId: "com.example", locale: "zh_CN")
        XCTAssertEqual(start.token, "ab01")
        XCTAssertEqual(start.attributesType, "QuestPlanActivityAttributes")
        XCTAssertTrue(start.isValid)
        let activity = QuestPlanActivityTokenRequest(scope: .activity, token: Data([1]), planKey: nil, activityId: "a",
                                                     environment: "SANDBOX", bundleId: "b", locale: "en")
        XCTAssertFalse(activity.isValid)
        let ended = QuestPlanActivityTokenRequest(scope: .ended, token: nil, planKey: "offer:x", activityId: "a",
                                                  environment: "SANDBOX", bundleId: "b", locale: "en")
        XCTAssertTrue(ended.isValid)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(start)) as? [String: Any]
        XCTAssertEqual(json?["scope"] as? String, "PUSH_TO_START")
    }

    func testChecklistMathCountsAndPicksCurrent() {
        let steps = [CYChecklistStep(id: "a", title: "A", state: .done),
                     CYChecklistStep(id: "b", title: "B", state: .todo),
                     CYChecklistStep(id: "c", title: "C", state: .locked)]
        XCTAssertEqual(CYStepChecklistMath.doneCount(steps), 1)
        XCTAssertEqual(CYStepChecklistMath.fraction(steps), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(CYStepChecklistMath.currentID(steps), "b")
        XCTAssertEqual(CYStepChecklistMath.fraction([]), 0)
        XCTAssertNil(CYStepChecklistMath.currentID([CYChecklistStep(id: "x", title: "X", state: .done)]))
    }
}
