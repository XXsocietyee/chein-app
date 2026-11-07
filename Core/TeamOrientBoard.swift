import Foundation
import CoreFoundation

/// Port of `pages/team/detail/index.js` loadOrientBoard & loadRanking:
/// fetches `/api/orient/team/detail?teamId=...` (member × task matrix + `"全队已完成 X / Y 个节点"`)
/// and `/api/orient/team/ranking?ownerType=...&ownerId=...` (`"本场队伍排名"`, `_isMe`).
public struct TeamOrientTask: Equatable, Identifiable {
    public let id: Int
    public let title: String
    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

public struct TeamOrientMemberProgress: Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let completedTaskIDs: Set<Int>
    public init(id: Int, name: String, completedTaskIDs: Set<Int>) {
        self.id = id
        self.name = name
        self.completedTaskIDs = completedTaskIDs
    }
    public func hasCompleted(taskID: Int) -> Bool {
        completedTaskIDs.contains(taskID)
    }
}

public struct TeamOrientBoardDetail: Equatable {
    public let tasks: [TeamOrientTask]
    public let members: [TeamOrientMemberProgress]
    public let completedCount: Int

    public init(tasks: [TeamOrientTask], members: [TeamOrientMemberProgress], completedCount: Int) {
        self.tasks = tasks
        self.members = members
        self.completedCount = max(0, completedCount)
    }

    public var isEmpty: Bool { tasks.isEmpty }
    public var summaryText: String {
        guard !tasks.isEmpty else { return "当前场次暂无定向任务" }
        return "全队已完成 \(completedCount) / \(tasks.count) 个节点"
    }
}

public struct TeamOrientRankingRow: Equatable, Identifiable {
    public let id: Int
    public let rank: Int
    public let teamID: Int
    public let teamName: String
    public let completedCount: Int
    public let totalTasks: Int
    public let durationText: String?

    public init(rank: Int, teamID: Int, teamName: String, completedCount: Int, totalTasks: Int, durationText: String?) {
        self.id = teamID > 0 ? teamID : rank
        self.rank = rank
        self.teamID = teamID
        self.teamName = teamName
        self.completedCount = completedCount
        self.totalTasks = totalTasks
        self.durationText = durationText
    }

    public func isMyTeam(currentTeamID: Int) -> Bool {
        teamID > 0 && teamID == currentTeamID
    }
}

public enum TeamOrientBoardRules {
    public static func formatDuration(seconds: Int?) -> String? {
        guard let seconds, seconds >= 0 else { return nil }
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remMin = minutes % 60
            return "\(hours)h \(remMin)m"
        }
        return minutes > 0 ? "\(minutes)m \(secs)s" : "\(secs)s"
    }

    public static func decodeDetail(_ data: Any?) -> TeamOrientBoardDetail? {
        guard let map = data as? [String: Any] else { return nil }
        let rawTasks = (map["tasks"] as? [[String: Any]]) ?? (map["nodes"] as? [[String: Any]]) ?? []
        let tasks: [TeamOrientTask] = rawTasks.enumerated().compactMap { idx, item in
            let id = intValue(item["id"]) ?? intValue(item["nodeId"]) ?? intValue(item["taskId"]) ?? (idx + 1)
            guard id > 0 else { return nil }
            let rawTitle = (item["name"] as? String) ?? (item["title"] as? String) ?? ""
            let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return TeamOrientTask(id: id, title: trimmed.isEmpty ? "#\(idx + 1)" : trimmed)
        }
        let rawMembers = (map["members"] as? [[String: Any]]) ?? []
        let members: [TeamOrientMemberProgress] = rawMembers.enumerated().compactMap { idx, item in
            let id = intValue(item["memberId"]) ?? intValue(item["id"]) ?? (idx + 1)
            guard id > 0 else { return nil }
            let rawName = (item["nickname"] as? String) ?? (item["memberName"] as? String) ?? (item["name"] as? String) ?? ""
            let idsArray = (item["completedTaskIds"] as? [Any]) ?? (item["completedNodeIds"] as? [Any]) ?? []
            let completed = Set(idsArray.compactMap(intValue))
            return TeamOrientMemberProgress(id: id, name: rawName.trimmingCharacters(in: .whitespacesAndNewlines), completedTaskIDs: completed)
        }
        let allCompletedTaskIDs = members.reduce(into: Set<Int>()) { $0.formUnion($1.completedTaskIDs) }
        let explicitCompleted = intValue(map["completedCount"]) ?? intValue(map["teamCompletedCount"])
        let completedCount = explicitCompleted ?? tasks.filter { allCompletedTaskIDs.contains($0.id) }.count
        return TeamOrientBoardDetail(tasks: tasks, members: members, completedCount: completedCount)
    }

    public static func decodeRanking(_ data: Any?) -> [TeamOrientRankingRow] {
        let rows: [[String: Any]]
        if let list = data as? [[String: Any]] {
            rows = list
        } else if let map = data as? [String: Any], let list = (map["list"] as? [[String: Any]]) ?? (map["records"] as? [[String: Any]]) {
            rows = list
        } else {
            return []
        }
        return rows.enumerated().compactMap { idx, item in
            let rank = intValue(item["rank"]) ?? (idx + 1)
            let teamID = intValue(item["teamId"]) ?? intValue(item["id"]) ?? 0
            let rawName = (item["teamName"] as? String) ?? (item["title"] as? String) ?? ""
            let completed = intValue(item["completedCount"]) ?? 0
            let total = intValue(item["totalTasks"]) ?? intValue(item["totalCount"]) ?? 0
            let duration = (item["durationText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? formatDuration(seconds: intValue(item["durationSeconds"]) ?? intValue(item["duration"]))
            return TeamOrientRankingRow(
                rank: rank,
                teamID: teamID,
                teamName: rawName.trimmingCharacters(in: .whitespacesAndNewlines),
                completedCount: completed,
                totalTasks: total,
                durationText: duration?.isEmpty == true ? nil : duration
            )
        }
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() {
            return n.intValue
        }
        if let s = raw as? String, let v = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return v
        }
        return nil
    }
}

@MainActor public protocol TeamOrientBoardAccess: AnyObject {
    var enabled: Bool { get }
    func loadBoard(teamID: Int) async throws -> TeamOrientBoardDetail?
    func loadRanking(ownerType: Int, ownerID: Int) async throws -> [TeamOrientRankingRow]
}

@MainActor public final class TeamOrientBoardHTTPAccess: TeamOrientBoardAccess {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let session: @MainActor () -> (accountID: Int, token: String)?
    public var enabled: Bool { session() != nil }

    public init(
        configuration: APIConfiguration,
        transport: any HTTPTransport,
        session: @escaping @MainActor () -> (accountID: Int, token: String)?
    ) {
        self.configuration = configuration
        self.transport = transport
        self.session = session
    }

    private func get(_ path: String, query: [URLQueryItem]) async throws -> Any? {
        guard let token = session()?.token, AuthRequestBuilder.isValidToken(token) else {
            throw APIError.unauthorized
        }
        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        components.queryItems = query
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, status) = try await transport.send(request)
        guard (200..<300).contains(status),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = obj["code"] as? NSNumber,
              code.intValue == 200 else {
            return nil
        }
        return obj["data"]
    }

    public func loadBoard(teamID: Int) async throws -> TeamOrientBoardDetail? {
        guard teamID > 0 else { return nil }
        let data = try await get("api/orient/team/detail", query: [URLQueryItem(name: "teamId", value: String(teamID))])
        return TeamOrientBoardRules.decodeDetail(data)
    }

    public func loadRanking(ownerType: Int, ownerID: Int) async throws -> [TeamOrientRankingRow] {
        guard ownerType > 0, ownerID > 0 else { return [] }
        let data = try await get("api/orient/team/ranking", query: [
            URLQueryItem(name: "ownerType", value: String(ownerType)),
            URLQueryItem(name: "ownerId", value: String(ownerID))
        ])
        return TeamOrientBoardRules.decodeRanking(data)
    }
}
