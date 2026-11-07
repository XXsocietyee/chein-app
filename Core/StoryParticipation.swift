import Foundation
import Observation

// MARK: - Story & Topic Participation: Project Join, Roles & Club Topic Story Linkage
// Ported from `pages/topic/components/project-join/index.js` and `pages/club/topic-story/index.js`.
// Coordinates via shared models without touching W6 chat bubble files.

public struct StoryProjectStation: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { stationId }
    public let stationId: Int
    public let name: String
    public let address: String
    public let roleName: String
    public let merchantId: Int?
    public let status: Int

    public init(
        stationId: Int,
        name: String,
        address: String = "",
        roleName: String = "",
        merchantId: Int? = nil,
        status: Int = 1
    ) {
        self.stationId = stationId
        self.name = name
        self.address = address
        self.roleName = roleName
        self.merchantId = merchantId
        self.status = status
    }
}

public enum StoryParticipantRole: String, Codable, Equatable, Sendable {
    case player = "user"
    case merchant = "merchant"
    case host = "host"
    case director = "director"
}

public struct StoryProjectJoinState: Equatable, Sendable {
    public let topicId: Int
    public let role: StoryParticipantRole
    public let isMerchant: Bool
    public let myJoined: Bool
    public let myApplyState: Int // 0 = not applied, 1 = pending, 2 = approved, 3 = rejected
    public let stations: [StoryProjectStation]
    public var selectedStationIndex: Int

    public init(
        topicId: Int,
        role: StoryParticipantRole = .player,
        myJoined: Bool = false,
        myApplyState: Int = 0,
        stations: [StoryProjectStation] = [],
        selectedStationIndex: Int = 0
    ) {
        self.topicId = topicId
        self.role = role
        self.isMerchant = (role == .merchant)
        self.myJoined = myJoined
        self.myApplyState = myApplyState
        self.stations = stations
        self.selectedStationIndex = stations.indices.contains(selectedStationIndex) ? selectedStationIndex : 0
    }

    public var currentStation: StoryProjectStation? {
        guard stations.indices.contains(selectedStationIndex) else { return nil }
        return stations[selectedStationIndex]
    }

    public var joinActionTitle: String {
        if isMerchant {
            switch myApplyState {
            case 1: return W8Text.t("入驻审核中", "Onboarding under review")
            case 2: return W8Text.t("已入驻站点", "Station onboarded")
            case 3: return W8Text.t("重新申请入驻", "Reapply to onboard")
            default: return W8Text.t("商家申请入驻", "Apply as merchant")
            }
        }
        return myJoined ? W8Text.t("已加入故事", "Joined story") : W8Text.t("立即参与故事", "Join the story")
    }

    public var canSubmitJoin: Bool {
        if isMerchant {
            return myApplyState == 0 || myApplyState == 3
        }
        return !myJoined
    }

    public mutating func switchStation(to index: Int) {
        guard stations.indices.contains(index) else { return }
        selectedStationIndex = index
    }
}

// MARK: - Club Topic Story Chapters & Node Answer Flow (Ported from pages/club/topic-story/index.js)

public struct StoryTopicNodeOption: Codable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let label: String

    public init(key: String, label: String) {
        self.key = key
        self.label = label
    }
}

public struct StoryTopicNode: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { nodeId }
    public let nodeId: Int
    public let chapterNo: Int
    public let chapterTitle: String
    public let name: String
    public let storyContent: String
    public let questionType: Int // 1 = single choice, 3 = text answer
    public let questionTitle: String
    public let options: [StoryTopicNodeOption]
    public let distanceMeters: Int
    public let durationMinutes: Int
    public let walkText: String
    public let durationText: String
    public var answered: Bool
    public var myAnswer: String

    public var isAnswerable: Bool {
        StoryClubTopicRules.answerableTypes.contains(questionType)
    }
}

public struct StoryTopicChapter: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { chapterNo }
    public let chapterNo: Int
    public let title: String
    public var nodes: [StoryTopicNode]
}

public enum StoryClubTopicRules {
    /// `ANSWERABLE = [1, 3]` from `pages/club/topic-story/index.js`.
    public static let answerableTypes: Set<Int> = [1, 3]

    /// Ported from `chapterTitle(no, rawTitle)` in `pages/club/topic-story/index.js`.
    public static func chapterTitle(chapterNo: Int, rawTitle: String?) -> String {
        let trimmed = (rawTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return W8Text.t("第 \(max(1, chapterNo)) 章", "Chapter \(max(1, chapterNo))")
    }

    /// Ported from `durationText(minutes)` in `pages/club/topic-story/index.js`.
    public static func durationText(minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "" }
        if minutes < 60 {
            return W8Text.t("约 \(minutes) 分钟", "About \(minutes) min")
        }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem > 0 ? W8Text.t("约 \(hours) 小时 \(rem) 分钟", "About \(hours) h \(rem) min") : W8Text.t("约 \(hours) 小时", "About \(hours) h")
    }

    /// Ported from `walkText(meters)` in `pages/club/topic-story/index.js` (80m/min walking speed).
    public static func walkText(meters: Int?) -> String {
        guard let meters, meters > 0 else { return "" }
        let walkMins = max(1, Int(ceil(Double(meters) / 80.0)))
        if meters >= 1000 {
            let km = String(format: "%.1f", Double(meters) / 1000.0)
            return W8Text.t("\(km) km · 步行约 \(walkMins) 分钟", "\(km) km · about \(walkMins) min walk")
        }
        return W8Text.t("\(meters) m · 步行约 \(walkMins) 分钟", "\(meters) m · about \(walkMins) min walk")
    }

    /// Ported from `parseOptions(raw)` in `pages/club/topic-story/index.js`.
    public static func parseOptions(_ raw: PlayWireValue) -> [StoryTopicNodeOption] {
        if let arr = raw.array {
            return arr.enumerated().compactMap { idx, item in
                if let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    let key = String(UnicodeScalar(65 + (idx % 26))!)
                    return StoryTopicNodeOption(key: key, label: text)
                }
                guard item.object != nil else { return nil }
                let key = item["key"].text ?? item["id"].text ?? String(UnicodeScalar(65 + (idx % 26))!)
                let label = (item["label"].text ?? item["text"].text ?? item["title"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty else { return nil }
                return StoryTopicNodeOption(key: key, label: label)
            }
        }
        if let text = raw.text, !text.isEmpty,
           let data = text.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(PlayWireValue.self, from: data),
           decoded.array != nil {
            return parseOptions(decoded)
        }
        return []
    }

    /// Ported from `buildChapters(nodes)` in `pages/club/topic-story/index.js`.
    public static func buildChapters(_ rawNodes: [PlayWireValue]) -> [StoryTopicChapter] {
        var chapterMap: [Int: StoryTopicChapter] = [:]
        var chapterOrder: [Int] = []

        for (index, raw) in rawNodes.enumerated() {
            guard raw.object != nil else { continue }
            let nodeId = raw["nodeId"].tolerantInteger ?? raw["id"].tolerantInteger ?? (index + 1)
            let chapterNo = max(1, raw["chapterNo"].tolerantInteger ?? raw["chapterId"].tolerantInteger ?? 1)
            let rawChTitle = raw["chapterTitle"].text ?? raw["chapterName"].text
            let chTitle = chapterTitle(chapterNo: chapterNo, rawTitle: rawChTitle)
            let dist = raw["distance"].tolerantInteger ?? raw["distanceMeters"].tolerantInteger ?? 0
            let dur = raw["duration"].tolerantInteger ?? raw["durationMinutes"].tolerantInteger ?? 0
            let qType = raw["questionType"].tolerantInteger ?? raw["taskType"].tolerantInteger ?? 0
            let opts = parseOptions(raw["options"] != .null ? raw["options"] : raw["questionOptions"])
            let myAns = raw["myAnswer"].text ?? raw["userAnswer"].text ?? ""
            let node = StoryTopicNode(
                nodeId: nodeId,
                chapterNo: chapterNo,
                chapterTitle: chTitle,
                name: raw["name"].text ?? raw["nodeName"].text ?? W8Text.t("站点 \(index + 1)", "Station \(index + 1)"),
                storyContent: raw["storyContent"].text ?? raw["content"].text ?? raw["description"].text ?? "",
                questionType: qType,
                questionTitle: raw["questionTitle"].text ?? raw["question"].text ?? "",
                options: opts,
                distanceMeters: dist,
                durationMinutes: dur,
                walkText: walkText(meters: dist),
                durationText: durationText(minutes: dur),
                answered: raw["answered"].bool == true || !myAns.isEmpty,
                myAnswer: myAns
            )
            if chapterMap[chapterNo] == nil {
                chapterOrder.append(chapterNo)
                chapterMap[chapterNo] = StoryTopicChapter(chapterNo: chapterNo, title: chTitle, nodes: [node])
            } else {
                chapterMap[chapterNo]?.nodes.append(node)
            }
        }

        return chapterOrder.compactMap { chapterMap[$0] }
    }

    /// Resolves the backend answer endpoint matching `pages/club/topic-story/index.js`:
    /// - When `from == "topic"` (host/self-play mode): `/api/topic/host-node-answer`
    /// - Otherwise (club activity story mode): `/api/club/topic-node-answer`
    public static func answerEndpoint(from source: String?) -> String {
        source == "topic" ? "api/topic/host-node-answer" : "api/club/topic-node-answer"
    }
}

@available(macOS 14.0, *)
@MainActor @Observable public final class StoryParticipationCoordinator {
    public let topicId: Int
    public let activityId: Int?
    public let fromSource: String
    public var joinState: StoryProjectJoinState
    public private(set) var chapters: [StoryTopicChapter] = []
    public var expandedChapterNo: Int?
    public var activeNodeId: Int?
    public var draftAnswers: [Int: String] = [:]
    public private(set) var errorMessage: String = ""
    public private(set) var submittingNodeId: Int?

    public init(
        topicId: Int,
        activityId: Int? = nil,
        fromSource: String = "club",
        joinState: StoryProjectJoinState? = nil
    ) {
        self.topicId = topicId
        self.activityId = activityId
        self.fromSource = fromSource
        self.joinState = joinState ?? StoryProjectJoinState(topicId: topicId)
    }

    public func loadStoryNodes(_ rawNodes: [PlayWireValue]) {
        let built = StoryClubTopicRules.buildChapters(rawNodes)
        self.chapters = built
        if expandedChapterNo == nil {
            expandedChapterNo = built.first?.chapterNo
        }
        for ch in built {
            for node in ch.nodes where !node.myAnswer.isEmpty {
                draftAnswers[node.nodeId] = node.myAnswer
            }
        }
    }

    public func selectAnswer(nodeId: Int, value: String) {
        draftAnswers[nodeId] = value
        errorMessage = ""
    }

    public func buildAnswerRequest(nodeId: Int) throws -> (endpoint: String, payload: [String: PlayWireValue]) {
        guard let chapter = chapters.first(where: { $0.nodes.contains(where: { $0.nodeId == nodeId }) }),
              let node = chapter.nodes.first(where: { $0.nodeId == nodeId }) else {
            throw PlayExperienceError.invalidAction
        }
        guard node.isAnswerable else {
            throw NSError(domain: "StoryParticipation", code: 1, userInfo: [NSLocalizedDescriptionKey: W8Text.t("该章节节点无需作答", "This station needs no answer")])
        }
        let ans = (draftAnswers[nodeId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ans.isEmpty else {
            throw NSError(domain: "StoryParticipation", code: 2, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请先选择或填写答案", "Choose or enter an answer first")])
        }
        if node.questionType == 1 && !node.options.isEmpty {
            guard node.options.contains(where: { $0.key == ans || $0.label == ans }) else {
                throw NSError(domain: "StoryParticipation", code: 3, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请选择有效选项", "Choose a valid option")])
            }
        }
        var payload: [String: PlayWireValue] = [
            "topicId": .int(topicId),
            "nodeId": .int(nodeId),
            "answer": .string(ans),
        ]
        if let activityId, activityId > 0 {
            payload["activityId"] = .int(activityId)
        }
        return (StoryClubTopicRules.answerEndpoint(from: fromSource), payload)
    }

    public func markNodeAnswered(nodeId: Int, answer: String) {
        for cIdx in chapters.indices {
            if let nIdx = chapters[cIdx].nodes.firstIndex(where: { $0.nodeId == nodeId }) {
                chapters[cIdx].nodes[nIdx].answered = true
                chapters[cIdx].nodes[nIdx].myAnswer = answer
            }
        }
    }
}
