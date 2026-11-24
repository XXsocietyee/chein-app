import Foundation

/// MP `OWNER_STAGE_COPY` (`pages/club/detail/index.js`). Display copy only.
/// The Now card in App still reads `ClubLeadPrimaryAction`; it should switch to `ClubOwnerStageMachine`.
public enum ClubOwnerStage: String, Equatable, CaseIterable, Sendable {
    case publish, invite, pending, accepted, executionAccepted
    case coopInvite, review, run, recruit, price, saleReview, contract
    case loading, error, admin

    public var label: String {
        switch self {
        case .publish: return "发布主题"
        case .invite: return "邀请商家"
        case .pending: return "查看邀请进度"
        case .accepted: return "管理项目"
        case .executionAccepted: return "活动运营"
        case .coopInvite: return "查看合作邀约"
        case .review: return "主题审核中"
        case .run: return "开一场"
        case .recruit: return "去招商"
        case .price: return "确认终价"
        case .saleReview: return "开售审核中"
        case .contract: return "发邀约"
        case .loading: return "读取管理进度…"
        case .error: return "重试管理进度"
        case .admin: return "带好眼下这一场"
        }
    }

    public var hint: String {
        switch self {
        case .publish: return "先发布一个俱乐部项目"
        case .invite: return "选择一个项目，开始对接商家"
        case .pending: return "邀请已发出，等待商家回应"
        case .accepted: return "商家已接受，进入项目主办视图"
        case .executionAccepted: return "已承接项目，可查看全部项目的场次运营"
        case .loading: return "正在确认项目与邀请状态"
        case .error: return "暂时无法确认当前阶段"
        case .admin: return "管理员：成员与现场执行"
        case .coopInvite, .review, .run, .recruit, .price, .saleReview, .contract: return ""
        }
    }
}

public struct ClubOwnerStageTopic: Equatable, Sendable {
    public var id: Int
    public var productType: Int?
    public var mode: Int?
    public var lifecycle: Int?
    public var saleReviewPending: Bool
    public var name: String
    public var uncontractedStations: [String]
    public init(id: Int, productType: Int? = nil, mode: Int? = nil, lifecycle: Int? = nil,
                saleReviewPending: Bool = false, name: String = "", uncontractedStations: [String] = []) {
        self.id = id; self.productType = productType; self.mode = mode; self.lifecycle = lifecycle
        self.saleReviewPending = saleReviewPending; self.name = name; self.uncontractedStations = uncontractedStations
    }
}

public struct ClubOwnerStageProject: Equatable, Sendable {
    public var clubID: Int
    public var acceptStatus: String
    public var bizType: String
    public var state: String
    public init(clubID: Int, acceptStatus: String, bizType: String = "topic", state: String = "") {
        self.clubID = clubID; self.acceptStatus = acceptStatus; self.bizType = bizType; self.state = state
    }
}

public struct ClubOwnerStageInvite: Equatable, Sendable {
    public var topicID: Int
    public var status: Int
    public init(topicID: Int, status: Int) { self.topicID = topicID; self.status = status }
}

public struct ClubOwnerStageMessage: Equatable, Sendable {
    public var status: Int
    public var toType: String
    public var toID: Int
    public var topicID: Int?
    public init(status: Int, toType: String, toID: Int, topicID: Int? = nil) {
        self.status = status; self.toType = toType; self.toID = toID; self.topicID = topicID
    }
}

/// Facts `updateOwnerStage` already has. It does not fetch them.
public struct ClubOwnerStageInput: Equatable, Sendable {
    public var isOwner: Bool
    public var canGovern: Bool
    public var clubID: Int
    /// `loading`, `ready`, or `error`.
    public var topicState: String
    public var ownerProjectState: String
    public var inviteFeedbackState: String
    public var topics: [ClubOwnerStageTopic]
    public var manageTopicIDs: Set<Int>
    public var projects: [ClubOwnerStageProject]
    public var sentInvites: [ClubOwnerStageInvite]
    public var messages: [ClubOwnerStageMessage]
    public init(isOwner: Bool, canGovern: Bool, clubID: Int, topicState: String = "ready",
                ownerProjectState: String = "ready", inviteFeedbackState: String = "ready",
                topics: [ClubOwnerStageTopic] = [], manageTopicIDs: Set<Int> = [],
                projects: [ClubOwnerStageProject] = [], sentInvites: [ClubOwnerStageInvite] = [],
                messages: [ClubOwnerStageMessage] = []) {
        self.isOwner = isOwner; self.canGovern = canGovern; self.clubID = clubID
        self.topicState = topicState; self.ownerProjectState = ownerProjectState
        self.inviteFeedbackState = inviteFeedbackState; self.topics = topics
        self.manageTopicIDs = manageTopicIDs; self.projects = projects
        self.sentInvites = sentInvites; self.messages = messages
    }
}

public struct ClubOwnerStageResolution: Equatable, Sendable {
    public let stage: ClubOwnerStage
    public let label: String
    public let hint: String
}

public enum ClubOwnerStageMachine {
    public static func resolve(_ input: ClubOwnerStageInput) -> ClubOwnerStageResolution {
        if input.canGovern, !input.isOwner {
            return resolution(.admin, hint: nil)
        }
        var stage: ClubOwnerStage = .loading
        var receivedPending = 0
        var stageTopic: ClubOwnerStageTopic?
        var execution = false
        if input.topicState == "error" {
            stage = .error
        } else if input.topicState == "ready" {
            let topicIDs = Set(input.topics.map(\.id))
            let accepted = input.projects.contains { $0.clubID == input.clubID && $0.acceptStatus == "merchantAccepted" }
            execution = input.messages.contains {
                $0.status == 1 && $0.toType == "club" && $0.toID == input.clubID && $0.topicID.map(input.manageTopicIDs.contains) == true
            }
            let pending = input.sentInvites.contains { topicIDs.contains($0.topicID) && $0.status == 0 }
            let reviewing = input.ownerProjectState == "ready" && input.projects.contains { $0.bizType == "topic" && $0.state == "pending" }
            let allOrienteering = input.topics.allSatisfy { ($0.productType ?? $0.mode) == 1 }
            func lifecycle(_ topic: ClubOwnerStageTopic) -> Int? { topic.lifecycle }
            let recruiting = input.topics.first { lifecycle($0) == 1 }
            let pricing = input.topics.first { lifecycle($0) == 2 && !$0.saleReviewPending }
                ?? input.topics.first { lifecycle($0) == 2 }
            let projectReviewing = input.topics.contains { lifecycle($0) == 7 }
            let sellable = input.topics.contains {
                let life = lifecycle($0)
                return life == nil || life == 0 || life == 3 || life == 4
            }
            if topicIDs.isEmpty { stage = reviewing ? .review : .publish }
            else if execution || (input.ownerProjectState == "ready" && accepted) { stage = .accepted }
            else if input.ownerProjectState == "error" { stage = .error }
            else if input.ownerProjectState == "ready", input.inviteFeedbackState == "error" { stage = .error }
            else if input.ownerProjectState == "ready", input.inviteFeedbackState == "ready" {
                stage = pending ? .pending : (reviewing ? .review : (allOrienteering ? .run : .invite))
            }
            if !execution, [.run, .invite, .review, .pending, .accepted].contains(stage) {
                if let recruiting { stage = .recruit; stageTopic = recruiting }
                else if let pricing {
                    stage = pricing.saleReviewPending ? .saleReview : .price
                    stageTopic = pricing
                } else if stage == .run, !sellable, projectReviewing { stage = .review }
                else if stage == .accepted, input.topics.contains(where: { let life = lifecycle($0); return life == 3 || life == 4 }) {
                    stage = .run
                }
                if let hold = input.topics.first(where: {
                    let life = lifecycle($0)
                    return (life == 1 || life == 2) && !$0.uncontractedStations.isEmpty
                }), [.recruit, .price, .saleReview].contains(stage) {
                    stage = .contract
                    stageTopic = hold
                }
            }
            receivedPending = input.messages.filter { $0.status == 0 && $0.toType == "club" && $0.toID == input.clubID }.count
            if receivedPending > 0, [.publish, .review, .invite, .run, .pending].contains(stage) { stage = .coopInvite }
        }
        var shown = stage
        if stage == .accepted, execution { shown = .executionAccepted }
        var hint: String? = nil
        if stage == .coopInvite { hint = "有 \(receivedPending) 条合作邀约待确认" }
        if (stage == .recruit || stage == .price || stage == .saleReview), let stageTopic { hint = stageTopic.name }
        if stage == .contract, let stageTopic {
            hint = stageTopic.uncontractedStations.joined(separator: "、") + " 还没有合作单，不能开售"
        }
        return resolution(shown, hint: hint)
    }

    private static func resolution(_ stage: ClubOwnerStage, hint: String?) -> ClubOwnerStageResolution {
        ClubOwnerStageResolution(stage: stage, label: stage.label, hint: hint ?? stage.hint)
    }
}
