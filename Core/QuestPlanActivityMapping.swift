import Foundation

/// Components r1 R-island: one plan card the app may show locally (the fallback when the server's push-to-start did not
/// arrive). Pure values; `QuestPlanActivityCenter` owns ActivityKit. Copy comes in through `localize` so Core stays
/// free of the app catalog; keys and their MP sources are listed in `docs/port/strings/comp-r1-island-steps.json`.
public struct QuestPlanDescriptor: Equatable, Sendable {
    public let kind: QuestPlanKind
    public let planKey: String
    public let title: String?
    public let targetID: Int?
    public var content: QuestPlanContent
    public init(kind: QuestPlanKind, planKey: String, title: String?, targetID: Int?, content: QuestPlanContent) {
        self.kind = kind; self.planKey = planKey; self.title = title; self.targetID = targetID; self.content = content
    }
}

public enum QuestPlanActivityMapping {
    /// Plan keys, shared with the server so a pushed card and a local copy of the same plan are one activity.
    public static func offerKey(_ offerID: String) -> String { "offer:" + offerID }
    public static func clubEventKey(_ eventID: Int) -> String { "club-event:\(eventID)" }
    public static func teamStatusKey(_ scope: String) -> String { "team-status:" + scope }

    /// Team invites waiting for me (MP 加入队伍; offer state `WAITING_CONFIRM`, I am the recipient and may act), newest
    /// first as the server sends them, at most `limit`. A `JOINED` offer is returned with `joined = true` so a card that is
    /// already up reads 已加入 before it leaves.
    public static func teamInvites(_ offers: [NativeFriendTeamOffer], limit: Int = 1,
                                   localize: (String) -> String) -> [QuestPlanDescriptor] {
        offers.filter { $0.recipient && (($0.canAct && $0.state == "WAITING_CONFIRM") || $0.state == "JOINED") }
            .prefix(max(0, limit))
            .map { offer in
                let inviter = offer.inviter?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let note = inviter.isEmpty
                    ? String(format: localize("plan.teamInvite.noteNoInviter"), offer.name)
                    : String(format: localize("plan.teamInvite.note"), inviter, offer.name)
                let content = QuestPlanContent(headline: localize("plan.teamInvite.headline"), note: note,
                                               stickers: ["person.2.fill", "👋"], joined: offer.state == "JOINED" ? true : nil)
                return QuestPlanDescriptor(kind: .teamInvite, planKey: offerKey(offer.offerID),
                                           title: offer.name.isEmpty ? nil : offer.name,
                                           targetID: Int(offer.teamID).flatMap { $0 > 0 ? $0 : nil }, content: content)
            }
    }

    /// Club event nudge: the first event of the club's calendar that starts today (MP 即将开始). The club calendar is
    /// day-granular, so there is no countdown; the card goes stale at the end of the day.
    public static func clubEvent(clubID: Int, clubName: String?, events: [ClubCalendarEvent], now: Date,
                                 localize: (String) -> String) -> (descriptor: QuestPlanDescriptor, staleDate: Date)? {
        let calendar = ClubEventDay.calendar
        let today = ClubEventDay(date: now)
        guard clubID > 0, let event = events.first(where: { $0.startDay == today && $0.id > 0 }),
              let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return nil }
        let name = event.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let club = clubName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = QuestPlanContent(headline: localize("plan.clubEvent.headline"),
                                       note: name?.isEmpty == false ? name : localize("plan.clubEvent.noteToday"),
                                       stickers: ["calendar.badge.clock", "🎉"])
        let descriptor = QuestPlanDescriptor(kind: .clubEvent, planKey: clubEventKey(event.id),
                                             title: club?.isEmpty == false ? club : nil, targetID: clubID, content: content)
        return (descriptor, endOfDay)
    }

    /// Live team status during a run. The note names the member whose status changed last ("Lena 已完成"); with no
    /// change since `previous` the note keeps the team count. Nil until there are at least two members.
    public static func teamStatus(scope: String, title: String?, previous: [PlayPlayerTeamMember],
                                  current: [PlayPlayerTeamMember], localize: (String) -> String) -> QuestPlanDescriptor? {
        guard current.count >= 2, !scope.isEmpty else { return nil }
        let finished: Set<PlayPlayerTeamMember.Status> = [.submitted, .completed, .fallbackCompleted]
        let done = current.filter { finished.contains($0.status) }.count
        let before = Dictionary(previous.map { ($0.id, $0.status) }, uniquingKeysWith: { first, _ in first })
        let changed = current.last { member in before[member.id].map { $0 != member.status } ?? false }
        let note: String
        if let changed {
            let name = changed.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let who = name.flatMap { $0.isEmpty ? nil : $0 } ?? localize("plan.teamStatus.teammate")
            note = who + " " + localize("playerTeam.status." + changed.status.rawValue.lowercased())
        } else {
            note = String(format: localize("plan.teamStatus.noteCount"), done, current.count)
        }
        let content = QuestPlanContent(headline: localize("plan.teamStatus.headline"), note: note,
                                       stickers: ["flag.checkered", "🏃"], done: done, total: current.count, tucked: nil)
        return QuestPlanDescriptor(kind: .teamStatus, planKey: teamStatusKey(scope), title: title, targetID: nil, content: content)
    }
}
