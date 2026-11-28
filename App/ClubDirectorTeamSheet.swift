import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// One 队伍进度 row (MP topic-detail index.js:939-962 `refreshTeamRows`, director.js:78-114 `teamView`).
struct ClubDirectorTeamRow: Equatable, Identifiable {
    let id: String
    let title: String?
    /// Issue text, or 「done/total」 progress; nil when neither is known.
    let issue: String?
    let completed: Int?
    let total: Int?
    let statusCode: String
    let abnormal: Bool
    let stuckNode: String?
    let hintLevel: Int?
    let eventAction: String?
    let eventOutcome: String?
    let eventTime: String?
}

/// One 队伍协作 row (MP director.js:162-188 `broadcastView`).
struct ClubDirectorBroadcastRow: Equatable, Identifiable {
    let id: String
    let content: String?
    let targetName: String?
    let targetCode: String
    let receiptCode: String
}

enum ClubDirectorTeamSheetRows {
    static let teamCodes: Set<String> = ["PREPARING", "RUNNING", "COMPLETED", "BLOCKED", "PAUSED", "ERROR"]
    static let eventCodes: Set<String> = ["CONFIRM_ROLE", "PLAYER_CHOICE", "PLAYER_SUBMIT", "PLAYER_HINT", "PLAYER_REVEAL"]
    static let outcomeCodes: Set<String> = ["APPLIED", "FAILED"]
    static let targetCodes: Set<String> = ["ALL", "TEAM", "ROLE", "MEMBERS"]
    /// MP statusLabels: CONFIRMED / APPLIED / SUCCESS read 已确认送达, REJECTED / FAILED read 发送未生效.
    static let receiptAliases: [String: String] = [
        "CONFIRMED": "CONFIRMED", "APPLIED": "CONFIRMED", "SUCCESS": "CONFIRMED",
        "REJECTED": "REJECTED", "FAILED": "REJECTED",
        "PENDING": "PENDING", "SENDING": "SENDING", "SENT": "SENT", "PARTIAL": "PARTIAL",
    ]

    static func teams(_ projection: PlayDirectorProjection) -> [ClubDirectorTeamRow] {
        projection.teams.enumerated().map { index, team in
            let status = (team["status"].text ?? "").uppercased()
            let issue = text(team, ["blockedReason", "issue"])
            let abnormal = ["BLOCKED", "PAUSED", "ERROR"].contains(status) || team["blocked"].bool == true || issue != nil
            let event = team["recentEvent"]
            let title = text(team, ["name", "teamName"])
            let firstMember = team["members"].array?.first?["memberId"].integer
            let id: String
            if let teamID = team["teamId"].integer {
                id = String(teamID)
            } else if let firstMember {
                id = "m" + String(firstMember)
            } else {
                id = "i" + String(index)
            }
            return ClubDirectorTeamRow(
                id: id,
                title: title,
                issue: issue,
                completed: team["completedNodes"].integer,
                total: team["totalNodes"].integer,
                statusCode: teamCodes.contains(status) ? status : "unknown",
                abnormal: abnormal,
                stuckNode: text(team["currentStuckNode"], ["nodeName"]),
                hintLevel: team["hintLevel"].integer,
                eventAction: known(event["action"].text, eventCodes),
                eventOutcome: known(event["outcome"].text, outcomeCodes),
                eventTime: text(event, ["occurredAt"])
            )
        }
    }

    static func broadcasts(_ projection: PlayDirectorProjection) -> [ClubDirectorBroadcastRow] {
        let items = projection.club["broadcasts"].array ?? []
        return items.enumerated().map { index, item in
            let target = (item["targetType"].text ?? item["scope"].text ?? "").uppercased()
            let receipt = (item["receiptStatus"].text ?? item["status"].text ?? "").uppercased()
            var id = "b" + String(index)
            if let value = item["id"].integer ?? item["broadcastId"].integer { id = String(value) }
            return ClubDirectorBroadcastRow(
                id: id,
                content: text(item, ["content"]),
                targetName: text(item, ["targetName", "roleName"]),
                targetCode: targetCodes.contains(target) ? target : "unknown",
                receiptCode: receiptAliases[receipt] ?? "unknown"
            )
        }
    }

    private static func known(_ code: String?, _ codes: Set<String>) -> String? {
        let upper = (code ?? "").uppercased()
        return codes.contains(upper) ? upper : nil
    }

    private static func text(_ value: PlayWireValue, _ keys: [String]) -> String? {
        for key in keys {
            if let text = value[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        }
        return nil
    }
}

/// MP `club-director-team-sheet` (D5, topic-detail wxml:366-370; level C): a read-only half sheet with the team rows
/// (name, issue or progress, status; abnormal teams add 卡点节点 / 提示层级 / 最近有效事件, 待确认 when the server sent
/// nothing) and, when there are broadcasts, 队伍协作 (content, target, delivery). Close is the only action.
struct ClubDirectorTeamSheet: View {
    let teams: [ClubDirectorTeamRow]
    let broadcasts: [ClubDirectorBroadcastRow]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(teams) { row in teamRow(row) }
                }
                if !broadcasts.isEmpty {
                    Section {
                        ForEach(broadcasts) { row in broadcastRow(row) }
                    } header: {
                        Text("club.director.teamSheet.collaboration")
                    }
                }
            }
            .navigationTitle(Text("club.director.tool.teamProgress"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                        .accessibilityIdentifier("club.topic.director.teamSheet.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("club.topic.director.teamSheet")
    }

    private func teamRow(_ row: ClubDirectorTeamRow) -> some View {
        LabeledContent {
            Text(LocalizedStringKey("club.director.teamStatus." + row.statusCode))
                .foregroundStyle(row.abnormal ? Color.orange : Color.secondary)
        } label: {
            if let title = row.title { Text(verbatim: title) } else { Text("club.director.team.unnamed") }
            VStack(alignment: .leading, spacing: 2) {
                subtitle(row)
                if row.abnormal { details(row) }
            }
        }
    }

    @ViewBuilder private func subtitle(_ row: ClubDirectorTeamRow) -> some View {
        if let issue = row.issue {
            Text(verbatim: issue)
        } else if let done = row.completed, let total = row.total {
            Text("club.director.ready.progress \(done) \(total)")
        }
    }

    @ViewBuilder private func details(_ row: ClubDirectorTeamRow) -> some View {
        detail("club.director.team.stuckNode", value: row.stuckNode.map { Text(verbatim: $0) })
        detail("club.director.team.hintLevel", value: hintText(row.hintLevel))
        detail("club.director.team.recentEvent", value: eventText(row))
    }

    private func detail(_ label: LocalizedStringKey, value: Text?) -> some View {
        LabeledContent {
            if let value { value } else { Text("club.director.teamStatus.unknown") }
        } label: {
            Text(label)
        }
        .font(.footnote)
    }

    private func hintText(_ level: Int?) -> Text? {
        switch level {
        case 1: return Text("club.director.team.hint1")
        case 2: return Text("club.director.team.hint2")
        default: return nil
        }
    }

    /// MP: 「动作 · 结果 · 时间」 only when both the action and the outcome are known.
    private func eventText(_ row: ClubDirectorTeamRow) -> Text? {
        guard let action = row.eventAction, let outcome = row.eventOutcome else { return nil }
        var text = Text(LocalizedStringKey("club.director.team.event." + action))
            + Text(verbatim: " · ")
            + Text(LocalizedStringKey("club.director.team.outcome." + outcome))
        if let time = row.eventTime { text = text + Text(verbatim: " · " + time) }
        return text
    }

    private func broadcastRow(_ row: ClubDirectorBroadcastRow) -> some View {
        LabeledContent {
            Text(LocalizedStringKey("club.director.broadcast.receipt." + row.receiptCode))
        } label: {
            if let content = row.content { Text(verbatim: content) } else { Text("club.director.broadcast.contentPending") }
            if let name = row.targetName {
                Text(verbatim: name)
            } else if row.targetCode != "unknown" {
                Text(LocalizedStringKey("club.director.broadcast.target." + row.targetCode))
            }
        }
    }
}
