import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// U03 publish clarity. Two read-only author projections on the integration backend:
/// `GET api/topic/publish-check` answers "what would block publishing now" (rule list with
/// chapter / stop / block / field location) and `GET api/topic/publish-status` answers
/// "where is this topic now" as five separate facts (draft / review / visibility / sale /
/// playable). Neither is an approval, a sale permission or a write grant. Missing values
/// stay unknown; nothing here is inferred from one `status` field.
public enum TopicPublicationPath {
    public static let check = "api/topic/publish-check"
    public static let status = "api/topic/publish-status"
}

/// Exact GET shape for the two reads: `?topicId=<positive>&scope=<owner raw value>`, no body.
public enum TopicPublicationReadRoute: Equatable {
    case check(topicID: Int, owner: ProjectEditOwner)
    case status(topicID: Int, owner: ProjectEditOwner)

    public var path: String {
        switch self { case .check: return TopicPublicationPath.check; case .status: return TopicPublicationPath.status }
    }
    public var businessRoute: BusinessRuntimeRoute { get throws { try .init(method: "GET", path: path) } }
    private var fields: (topicID: Int, owner: ProjectEditOwner) {
        switch self { case .check(let id, let owner), .status(let id, let owner): return (id, owner) }
    }

    public func request(baseURL: URL, token: String) throws -> URLRequest {
        guard fields.topicID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        guard let url = Self.url(baseURL: baseURL, path: path, topicID: fields.topicID, owner: fields.owner) else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }

    private static func url(baseURL: URL, path: String, topicID: Int, owner: ProjectEditOwner) -> URL? {
        guard var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { return nil }
        parts.queryItems = [URLQueryItem(name: "topicId", value: String(topicID)), URLQueryItem(name: "scope", value: owner.rawValue)]
        return parts.url
    }

    /// Accepts only the canonical request this type builds; anything else is not this route.
    public init?(request: URLRequest, baseURL: URL) {
        guard request.httpMethod == "GET", request.httpBody == nil, request.httpBodyStream == nil, !request.httpShouldHandleCookies,
              request.value(forHTTPHeaderField: "Cookie") == nil, request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = parts.queryItems,
              items.count == 2, items[0].name == "topicId", items[1].name == "scope",
              let raw = items[0].value, let id = Int(raw), id > 0, String(id) == raw,
              let owner = ProjectEditOwner(rawValue: items[1].value ?? "") else { return nil }
        for (path, route) in [(TopicPublicationPath.check, Self.check(topicID: id, owner: owner)),
                              (TopicPublicationPath.status, Self.status(topicID: id, owner: owner))]
        where Self.url(baseURL: baseURL, path: path, topicID: id, owner: owner) == url {
            self = route; return
        }
        return nil
    }
}

// MARK: - publish-check

public struct TopicPublishCheckIssue: Equatable, Identifiable, Sendable {
    public enum Level: String, Sendable { case error, warn }
    public let id: Int
    public let level: Level
    public let code: String?
    public let message: String
    public let nodeID: Int?
    public let chapterID: Int?
    public let chapterTitle: String?
    public let nodeName: String?
    public let blockID: String?
    public let field: String?
    public let source: String?
    public var blocks: Bool { level == .error }

    public init(id: Int, level: Level, code: String?, message: String, nodeID: Int? = nil, chapterID: Int? = nil,
                chapterTitle: String? = nil, nodeName: String? = nil, blockID: String? = nil, field: String? = nil, source: String? = nil) {
        self.id = id; self.level = level; self.code = code; self.message = message; self.nodeID = nodeID
        self.chapterID = chapterID; self.chapterTitle = chapterTitle; self.nodeName = nodeName
        self.blockID = blockID; self.field = field; self.source = source
    }

    /// Mini-program `_topicPublishCheck`: every row needs a non-empty message and level error|warn,
    /// otherwise the whole answer is "check not completed". Location fields are additive.
    init(index: Int, raw: ProjectEditJSON) throws {
        guard let row = raw.object, let level = row["level"]?.text.flatMap(Level.init(rawValue:)),
              let message = row["message"]?.text, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectEditError.invalidContract
        }
        func positive(_ key: String) throws -> Int? {
            guard let value = row[key], value != .null else { return nil }
            guard let id = value.integer, id > 0 else { throw ProjectEditError.invalidContract }
            return id
        }
        func text(_ key: String) -> String? {
            guard let value = row[key]?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }
        self.init(id: index, level: level, code: text("code"), message: message, nodeID: try positive("nodeId"),
                  chapterID: try positive("chapterId"), chapterTitle: text("chapterTitle"), nodeName: text("nodeName"),
                  blockID: text("blockId"), field: text("field"), source: text("source"))
    }
}

/// Where a problem sits, in the author's words. Server location wins; otherwise the
/// mini-program `previewIssueWhere(field)` mapping (tickets / chapter N / story / topic settings).
public enum TopicPublishIssueWhere: Equatable, Sendable {
    case stop(chapter: String?, stop: String)
    case chapterTitle(String)
    case chapterNumber(Int)
    case tickets
    case story
    case topicSettings
    case unlocated

    public static func of(_ issue: TopicPublishCheckIssue) -> Self {
        if let stop = issue.nodeName { return .stop(chapter: issue.chapterTitle, stop: stop) }
        if let chapter = issue.chapterTitle { return .chapterTitle(chapter) }
        return fromField(issue.field)
    }

    public static func fromField(_ field: String?) -> Self {
        let f = field ?? ""
        guard !f.isEmpty else { return .unlocated }
        if f.hasPrefix("ticket") || f.hasPrefix("tickets") || f.hasPrefix("sale") || f.hasPrefix("identity") { return .tickets }
        if f.hasPrefix("chapter") {
            let rest = f.drop(while: { $0.isLetter })
            if let mark = rest.first, ":.[".contains(mark) {
                let digits = rest.dropFirst().prefix(while: { $0.isNumber })
                if let index = Int(digits), !digits.isEmpty { return .chapterNumber(index + 1) }
            }
            return .story
        }
        if ["templat", "node", "runtime", "themeState"].contains(where: { f.hasPrefix($0) }) { return .story }
        return .topicSettings
    }
}

public struct TopicPublishCheckReport: Equatable, Sendable {
    public let topicID: Int
    public let issues: [TopicPublishCheckIssue]
    public var blocking: [TopicPublishCheckIssue] { issues.filter(\.blocks) }
    public var advisory: [TopicPublishCheckIssue] { issues.filter { !$0.blocks } }
    /// Structure only: the saved version passes the server's publish rules. Not a review,
    /// not a rehearsal and not an on-site check.
    public var structurePassed: Bool { blocking.isEmpty }

    public init(topicID: Int, issues: [TopicPublishCheckIssue]) { self.topicID = topicID; self.issues = issues }

    public static func decode(_ data: Data, status: Int, topicID: Int) throws -> Self {
        let envelope = try? OperationAdapterHTTP.envelope(data)
        if status == 401 || envelope?["code"]?.integer == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status), envelope?["code"]?.integer == 200,
              let rows = envelope?["data"]?.array, rows.count <= 4096 else { throw ProjectEditError.invalidContract }
        return .init(topicID: topicID, issues: try rows.enumerated().map { try TopicPublishCheckIssue(index: $0.offset, raw: $0.element) })
    }
}

public extension TopicPublishCheckIssue {
    /// Exact editor destination for a server issue, by server ids carried in the loaded draft
    /// (`chapter.preserved["id"]`, `node.localMetadata["id"]`). Ambiguous or missing ids stay unlocated.
    func location(in draft: ProjectEditDraft) -> ProjectEditIssueLocation? {
        if let nodeID {
            var hits: [ProjectEditIssueLocation] = []
            for chapter in draft.chapters {
                for node in chapter.nodes where node.localMetadata["id"]?.integer == nodeID {
                    let gameplay = blockID != nil || (field ?? "").contains("template") || (field ?? "").contains("block")
                    hits.append(.node(chapterID: chapter.id, nodeID: node.id, anchor: "project-issue-anchor-" + (gameplay ? "gameplay" : "nodeName")))
                }
            }
            return hits.count == 1 && hits[0].exists(in: draft) ? hits[0] : nil
        }
        if let chapterID {
            let hits = draft.chapters.filter { $0.preserved["id"]?.integer == chapterID }
            guard hits.count == 1 else { return nil }
            let story = (field ?? "").contains("block") || (field ?? "").contains("story")
            return .chapter(id: hits[0].id, anchor: "project-issue-anchor-" + (story ? "storyFlow" : "chapterSettings"))
        }
        let roots = ["name": "name", "description": "description", "imgUrl": "cover", "cover": "cover", "categoryIds": "categories",
                     "startDate": "start", "endDate": "end", "recruitDeadline": "deadline", "completeRuleJson": "completionRules",
                     "completionRules": "completionRules", "chapters": "chapters"]
        if let field, let anchor = roots[field] { return .root(anchor: "project-issue-anchor-" + anchor) }
        return nil
    }
}

/// U03-01 "local check and server check disagree → sync and check again".
public enum TopicPublishCheckAgreement: Equatable, Sendable {
    case agrees
    /// The editor holds changes the server has not saved; the server answer covers the saved version.
    case savedVersionDiffers
    case serverOnlyBlocks
    case localOnlyBlocks

    public static func of(_ report: TopicPublishCheckReport, localIssueCount: Int, draftMatchesSaved: Bool) -> Self {
        if !draftMatchesSaved { return .savedVersionDiffers }
        if !report.blocking.isEmpty && localIssueCount == 0 { return .serverOnlyBlocks }
        if report.blocking.isEmpty && localIssueCount > 0 { return .localOnlyBlocks }
        return .agrees
    }
}

/// Structure, rehearsal and on-site are separate facts. Only structure has a server answer
/// here; rehearsal and on-site have no recorded fact on this path and are never shown as passed.
public enum TopicVerificationStage: String, CaseIterable, Sendable { case structure, rehearsal, onSite }
public enum TopicVerificationState: String, Sendable { case passed, blocked, unknown, notRecorded }

public enum TopicVerificationSummary {
    public static func state(_ stage: TopicVerificationStage, report: TopicPublishCheckReport?) -> TopicVerificationState {
        switch stage {
        case .structure:
            guard let report else { return .unknown }
            return report.structurePassed ? .passed : .blocked
        case .rehearsal, .onSite: return .notRecorded
        }
    }
}

// MARK: - publish-status (five facts)

public struct TopicPublicationStatus: Equatable, Codable, Sendable {
    public struct Draft: Equatable, Codable, Sendable {
        public var isDraft: Bool?
        public var editable: Bool?
        public var editBlockedReason: String?
        enum CodingKeys: String, CodingKey { case isDraft = "draft", editable, editBlockedReason }
        public init(isDraft: Bool? = nil, editable: Bool? = nil, editBlockedReason: String? = nil) {
            self.isDraft = isDraft; self.editable = editable; self.editBlockedReason = editBlockedReason
        }
    }
    public struct Review: Equatable, Codable, Sendable {
        public var state: String?
        public var label: String?
        public var passed: Bool?
        public var pending: Bool?
        public var auditTaskID: Int?
        public var detail: String?
        enum CodingKeys: String, CodingKey { case state, label, passed, pending, auditTaskID = "auditTaskId", detail }
        public init(state: String? = nil, label: String? = nil, passed: Bool? = nil, pending: Bool? = nil, auditTaskID: Int? = nil, detail: String? = nil) {
            self.state = state; self.label = label; self.passed = passed; self.pending = pending; self.auditTaskID = auditTaskID; self.detail = detail
        }
    }
    public struct Visibility: Equatable, Codable, Sendable {
        public var visible: Bool?
        public var reason: String?
        public init(visible: Bool? = nil, reason: String? = nil) { self.visible = visible; self.reason = reason }
    }
    public struct Sale: Equatable, Codable, Sendable {
        public var onSale: Bool?
        public var lifecycleSaleOpen: Bool?
        public var awaitingReview: Bool?
        public var nextStep: String?
        public var blockReason: String?
        public init(onSale: Bool? = nil, lifecycleSaleOpen: Bool? = nil, awaitingReview: Bool? = nil, nextStep: String? = nil, blockReason: String? = nil) {
            self.onSale = onSale; self.lifecycleSaleOpen = lifecycleSaleOpen; self.awaitingReview = awaitingReview
            self.nextStep = nextStep; self.blockReason = blockReason
        }
    }
    public struct Playable: Equatable, Codable, Sendable {
        public var playable: Bool?
        public var reason: String?
        public var publishedConfigVersion: Int?
        public var beta: Bool?
        public var gate: String?
        public init(playable: Bool? = nil, reason: String? = nil, publishedConfigVersion: Int? = nil, beta: Bool? = nil, gate: String? = nil) {
            self.playable = playable; self.reason = reason; self.publishedConfigVersion = publishedConfigVersion; self.beta = beta; self.gate = gate
        }
    }
    public var draft: Draft?
    public var review: Review?
    public var visibility: Visibility?
    public var sale: Sale?
    public var playable: Playable?

    public init(draft: Draft? = nil, review: Review? = nil, visibility: Visibility? = nil, sale: Sale? = nil, playable: Playable? = nil) {
        self.draft = draft; self.review = review; self.visibility = visibility; self.sale = sale; self.playable = playable
    }

    /// Present-but-wrong-typed values are a contract failure; absent or null values stay unknown.
    public static func decode(_ value: ProjectEditJSON?) throws -> Self {
        guard let value, value.object != nil else { throw ProjectEditError.invalidContract }
        do { return try JSONDecoder().decode(Self.self, from: JSONEncoder().encode(value)) }
        catch { throw ProjectEditError.invalidContract }
    }

    public static func decodeResponse(_ data: Data, status: Int) throws -> Self {
        let envelope = try? OperationAdapterHTTP.envelope(data)
        if status == 401 || envelope?["code"]?.integer == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status), envelope?["code"]?.integer == 200 else { throw ProjectEditError.invalidContract }
        return try decode(envelope?["data"])
    }
}

/// One headline shared by the publish result, the project status page and the "My projects" card.
/// Visible-while-reviewing is never "approved"; commercial review pending is never "on sale".
public enum TopicPublicationHeadline: String, Equatable, Sendable {
    case draft, rejected, inReview, publicAwaitingReview, live, approvedHidden
    /// From the list only: visible to players; the list does not carry the review result.
    case listedPublic
    /// From the list only: taken offline; review result is read on the status page.
    case listedOffline
    case ended
    case unknown

    public var titleKey: String { "headline." + rawValue }

    public static func of(_ status: TopicPublicationStatus) -> Self {
        let state = status.review?.state
        if state == "REJECTED" { return .rejected }
        if status.draft?.isDraft == true || state == "DRAFT" { return .draft }
        guard let visible = status.visibility?.visible, let review = status.review else { return .unknown }
        let pendingReview = review.pending == true || state == "PENDING" || state == "ESCALATED" || state == "AWAITING"
        if visible {
            if review.passed == true { return .live }
            if review.passed == false || pendingReview { return .publicAwaitingReview }
            return .unknown
        }
        if review.passed == true { return .approvedHidden }
        if pendingReview { return .inReview }
        return .unknown
    }

    /// `api/project/my` topic `state` (server `lifecycleState`): draft > rejected > pending > offline > time bucket.
    /// `status=1` can be visible before review passes, so a time-bucket state is "public", not "approved".
    public static func ofListState(_ state: String?) -> Self {
        switch state {
        case "draft": return .draft
        case "rejected": return .rejected
        case "pending": return .inReview
        case "running", "notStarted": return .listedPublic
        case "offline": return .listedOffline
        case "completed": return .ended
        default: return .unknown
        }
    }

    /// Immediate publish acknowledgment: the five-fact projection when present, otherwise the
    /// flat mirror fields the mini-program reads (`commercialAwaitingReview`, `reviewState`, `published`).
    public static func of(_ ack: ProjectEditBundleAcknowledgment) -> Self {
        if let status = ack.publicationStatus {
            let value = of(status)
            if value != .unknown { return value }
        }
        if ack.reviewState == "DRAFT" { return .draft }
        let pending = ack.commercialAwaitingReview == true || ack.reviewState == "PENDING" || ack.reviewState == "ESCALATED"
        let visible = ack.publicVisible ?? ack.published
        if ack.reviewPassed == true { return visible ? .live : .approvedHidden }
        if pending { return visible ? .publicAwaitingReview : .inReview }
        return visible ? .listedPublic : .unknown
    }

    public var isFailure: Bool { self == .rejected }
}

/// Server-worded next step for a publish result. Server text first; a localized fallback key otherwise.
public struct TopicPublishNextStep: Equatable, Sendable {
    public let serverText: String?
    public let fallbackKey: String?

    public static func of(_ ack: ProjectEditBundleAcknowledgment) -> Self {
        let headline = TopicPublicationHeadline.of(ack)
        let server = [ack.publicationStatus?.sale?.nextStep, ack.commercialNextStep, ack.publicationStatus?.review?.detail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        switch headline {
        case .inReview, .publicAwaitingReview: return .init(serverText: server, fallbackKey: server == nil ? "next.review" : nil)
        case .draft: return .init(serverText: nil, fallbackKey: "next.draft")
        case .rejected: return .init(serverText: server, fallbackKey: "next.rejected")
        case .live, .listedPublic: return .init(serverText: server, fallbackKey: server == nil ? "next.live" : nil)
        case .approvedHidden, .listedOffline, .ended: return .init(serverText: server, fallbackKey: server == nil ? "next.status" : nil)
        case .unknown: return .init(serverText: nil, fallbackKey: "next.unknown")
        }
    }
}

/// Per-segment rows for the status page. `nil` facts render as unknown, never as "no" or 0.
public enum TopicPublicationFactRow: Equatable, Sendable {
    public enum Value: Equatable, Sendable { case yes, no, unknown }
    case editable(Value, reason: String?)
    case review(state: String?, label: String?, passed: Value, auditTaskID: Int?, detail: String?)
    case visible(Value, reason: String?)
    case sale(Value, awaitingReview: Value, nextStep: String?, blockReason: String?)
    case playable(Value, reason: String?, publishedConfigVersion: Int?, beta: Bool)

    static func value(_ flag: Bool?) -> Value { flag.map { $0 ? .yes : .no } ?? .unknown }

    public static func rows(_ status: TopicPublicationStatus) -> [Self] {
        [.editable(value(status.draft?.editable), reason: status.draft?.editBlockedReason),
         .review(state: status.review?.state, label: status.review?.label, passed: value(status.review?.passed),
                 auditTaskID: status.review?.auditTaskID, detail: status.review?.detail),
         .visible(value(status.visibility?.visible), reason: status.visibility?.reason),
         .sale(value(status.sale?.onSale), awaitingReview: value(status.sale?.awaitingReview),
               nextStep: status.sale?.nextStep, blockReason: status.sale?.blockReason),
         .playable(value(status.playable?.playable), reason: status.playable?.reason,
                   publishedConfigVersion: status.playable?.publishedConfigVersion, beta: status.playable?.beta == true)]
    }
}

/// Reads used by the editor and the result page. Implemented by the HTTP adapter; disabled
/// services leave both unavailable and the UI says so instead of guessing.
@MainActor public protocol TopicPublicationReading: AnyObject {
    var supportsPublishCheck: Bool { get }
    var supportsPublicationStatus: Bool { get }
    func publishCheck(topicID: Int, session: ProjectEditSession) async throws -> TopicPublishCheckReport
    func publicationStatus(topicID: Int, session: ProjectEditSession) async throws -> TopicPublicationStatus
}

/// U03-03 "My projects" topic card: the same headline mapping as the publish result and the status
/// page, plus the edit-scope notice for sold topics. Offline, stop-sale (cancel) and delete stay
/// separate operations in `MyProjectListPresentation.card`; nothing here grants one.
public struct MyProjectTopicFact: Equatable, Sendable {
    public let headline: TopicPublicationHeadline
    /// Tickets already sold (or the count is unknown) on a topic that still opens the editor:
    /// the editor's server read decides what can change, so the card says so before opening it.
    public let editScopeNoticeKey: String?

    public static func of(_ project: CreatorContentProject) -> MyProjectTopicFact? {
        guard project.bizType == "topic" else { return nil }
        let headline = TopicPublicationHeadline.ofListState(project.state)
        let opensEditor = ["draft", "rejected", "offline"].contains(project.state ?? "")
        let notice: String?
        switch project.signupCountFact {
        case .value(let count) where count > 0: notice = opensEditor || headline == .listedPublic ? "list.soldEditScope" : nil
        case .unknown: notice = opensEditor ? "list.unknownSoldEditScope" : nil
        default: notice = nil
        }
        return .init(headline: headline, editScopeNoticeKey: notice)
    }
}

/// Exact owner-scoped project reads that each need their own GET/POST grant: the original author
/// inputs and the U03 publication reads. Matching never borrows another feature's grant.
public struct ProjectExactReadRoute: Equatable {
    public let feature: BusinessRuntimeFeature
    public let route: BusinessRuntimeRoute
    public var businessRoute: BusinessRuntimeRoute { get throws { route } }
    public init?(request: URLRequest, baseURL: URL) {
        if let input = ProjectAuthorInputReadRoute(request: request, baseURL: baseURL), let route = try? input.businessRoute {
            feature = .projectAuthorInputRead; self.route = route; return
        }
        if let read = TopicPublicationReadRoute(request: request, baseURL: baseURL), let route = try? read.businessRoute {
            feature = .projectPublicationRead; self.route = route; return
        }
        return nil
    }
}
