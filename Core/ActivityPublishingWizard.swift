import Foundation

/// Step grouping from hengyin `chengyinhub-xcx/pages/publish/activity/index.js` STEPS
/// (blob `062721fd2b9e5d9804191e76a10bea899d84cc94`) and the `wx:if="{{step === N}}"` blocks
/// in `index.wxml` (blob `020247df65efefc61b015b6dd392127a823d4c2b`).
/// Progress, clamp and field lookup follow `pages/publish/utils/publish/step-form.js`.
/// A step passes only when the same predicates `ActivityPublishDraft.wire()` already uses
/// accept that step's fields. This type does not publish and does not read capability.
public enum ActivityPublishingWizard {
    public struct Step: Equatable {
        public let index: Int
        public let key: String
        public let title: String
        public let heading: String
        public let fields: [String]
    }
    public struct Mark: Equatable, Identifiable {
        public var id: String { key }
        public let key: String
        public let title: String
        public let index: Int
        /// `done`, `current`, or `todo`, matching `buildProgress`.
        public let state: String
    }
    public static let steps: [Step] = [
        Step(index: 0, key: "basic", title: "基本信息", heading: "这场活动叫什么、在哪儿办？", fields: ["name", "addressName", "startDate", "endDate", "categoryIds"]),
        Step(index: 1, key: "content", title: "活动内容", heading: "这场活动玩什么？", fields: ["description", "imgUrl", "templateId"]),
        Step(index: 2, key: "ticket", title: "票务与合作", heading: "这场活动怎么卖票？", fields: ["ticket*"]),
    ]

    public static func clamp(_ next: Int) -> Int {
        guard !steps.isEmpty else { return 0 }
        return min(max(next, 0), steps.count - 1)
    }

    /// `-1` keeps the caller on the current step. `ticket*` matches `ticketName0` and the other ticket keys.
    public static func resolveStep(of key: String) -> Int {
        for (index, step) in steps.enumerated() {
            for pattern in step.fields {
                if pattern.hasSuffix("*") {
                    let prefix = String(pattern.dropLast())
                    if !prefix.isEmpty && key.hasPrefix(prefix) { return index }
                } else if pattern == key {
                    return index
                }
            }
        }
        return -1
    }

    public static func progress(_ current: Int) -> [Mark] {
        let active = clamp(current)
        return steps.enumerated().map { index, step in
            Mark(key: step.key, title: step.title, index: index,
                 state: index < active ? "done" : index == active ? "current" : "todo")
        }
    }

    public static func isComplete(_ step: Int, _ draft: ActivityPublishDraft) -> Bool {
        switch clamp(step) {
        case 0: return basic(draft)
        case 1: return content(draft)
        default: return tickets(draft)
        }
    }

    /// First incomplete step. When every step passes, the last step, where review lives.
    public static func resumeIndex(_ draft: ActivityPublishDraft) -> Int {
        for index in steps.indices where !isComplete(index, draft) { return index }
        return steps.count - 1
    }

    /// One step forward, and only when this step and every earlier step already pass.
    public static func advance(from step: Int, draft: ActivityPublishDraft) -> Int? {
        let current = clamp(step)
        guard current + 1 < steps.count, (0...current).allSatisfy({ isComplete($0, draft) }) else { return nil }
        return current + 1
    }

    public static func retreat(from step: Int) -> Int { max(clamp(step) - 1, 0) }

    /// Resume at the saved step. A missing saved step still opens the first incomplete step.
    public static func resume(savedStep: Int?, draft: ActivityPublishDraft) -> Int {
        if let savedStep { return clamp(savedStep) }
        return resumeIndex(draft)
    }

    /// A requested index cannot land past the first incomplete step.
    public static func located(_ requested: Int, draft: ActivityPublishDraft) -> Int {
        min(clamp(requested), resumeIndex(draft))
    }

    public static func blockingField(_ step: Int, _ draft: ActivityPublishDraft) -> String? {
        guard !isComplete(step, draft) else { return nil }
        return reason(clamp(step), draft) ?? "ticket"
    }

    /// The existing create review. False when `wire()` rejects the draft.
    public static func acceptsReview(_ draft: ActivityPublishDraft) -> Bool {
        (try? draft.wire()) != nil
    }

    // MARK: - Mini-Program `pages/publish/activity` Parity Rules

    public static var timeLocationLockedNotice: String { W8Text.t("已售出，时间和地点不可改", "Tickets have been sold, so the time and place can’t be changed") }
    public static var collaboratorSettlementNotice: String { W8Text.t("合作者可编辑内容，不参与结算", "Collaborators can edit the content but don’t share in earnings") }
    public static var merchantFreeTicketOnlyNotice: String { W8Text.t("商家活动暂时只支持免费票", "Merchant activities only support free tickets for now") }
    public static var merchantPaidTicketBlockedMessage: String { W8Text.t("商家主办活动还没开通收款，票价只能是 0", "Payments aren’t enabled for merchant-hosted activities yet, so the ticket price must be 0") }
    public static var createReviewHeading: String { W8Text.t("发布前摘要", "Review before publishing") }
    public static var editReviewHeading: String { W8Text.t("修改摘要", "Summary of changes") }
    public static var createVisibilityNotice: String { W8Text.t("默认公开：发布后会在活动列表展示，继续即按当前公开范围发布。", "Public by default: once published it appears in the activity list, and continuing publishes it with the current visibility.") }
    public static var editVisibilityNotice: String { W8Text.t("本次保存只更新上面这些内容，不会改变活动的公开范围。", "This save only updates the items above and doesn’t change who can see the activity.") }

    /// Returns the conversational step heading from `pages/publish/activity/index.js` STEPS.
    public static func heading(for step: Int) -> String {
        steps[clamp(step)].heading
    }

    /// Validates the mini-program merchant-host ticket pricing rule (`pages/publish/activity/index.js`):
    /// when `merchantHost == true`, all tickets must have price == 0 (`"商家主办活动还没开通收款，票价只能是 0"`).
    public static func validateMerchantHostTickets(
        _ draft: ActivityPublishDraft,
        merchantHost: Bool
    ) -> Result<Void, PublishModesError> {
        guard merchantHost else { return .success(()) }
        for ticket in draft.tickets {
            guard let price = ProjectEditValidation.decimal(ticket.price), price == .zero else {
                return .failure(.rejected(merchantPaidTicketBlockedMessage))
            }
        }
        return .success(())
    }

    /// Returns true when the draft has at least one paid ticket (`price > 0`) and is not merchant-hosted,
    /// matching `pages/publish/activity/index.js` `totalPrice > 0 && !this.data.merchantHost` identity check trigger.
    public static func requiresPublisherIdentityVerification(
        _ draft: ActivityPublishDraft,
        merchantHost: Bool
    ) -> Bool {
        guard !merchantHost else { return false }
        let totalPrice = draft.tickets.reduce(Decimal.zero) { partial, ticket in
            let price = ProjectEditValidation.decimal(ticket.price) ?? .zero
            return partial + max(.zero, price)
        }
        return totalPrice > .zero
    }

    /// Merges the activity owner (`ownerMemberID`, fixed first with `isOwner == true`) and additional collaborators,
    /// deduplicating by `memberID` and preserving order, matching `mergeCollaboratorsWithOwner` in `pages/publish/activity/index.js`.
    public struct CollaboratorEntry: Equatable, Identifiable {
        public let memberID: Int
        public let isOwner: Bool
        public var id: Int { memberID }

        public init(memberID: Int, isOwner: Bool) {
            self.memberID = memberID
            self.isOwner = isOwner
        }
    }

    public static func mergeCollaboratorsWithOwner(
        ownerMemberID: Int?,
        collaboratorMemberIDs: [Int]
    ) -> [CollaboratorEntry] {
        var result: [CollaboratorEntry] = []
        var seen = Set<Int>()
        if let ownerMemberID, ownerMemberID > 0 {
            seen.insert(ownerMemberID)
            result.append(CollaboratorEntry(memberID: ownerMemberID, isOwner: true))
        }
        for id in collaboratorMemberIDs where id > 0 {
            if seen.insert(id).inserted {
                result.append(CollaboratorEntry(memberID: id, isOwner: false))
            }
        }
        return result
    }

    /// Pre-publish / edit review summary matching `pages/publish/activity/index.wxml` lines 163-189.
    public struct ReviewSummary: Equatable {
        public let isEditMode: Bool
        public let heading: String
        public let nameText: String
        public let timeText: String
        public let addressText: String
        public let templateText: String
        public let ticketSummaryText: String?
        public let visibilityNotice: String
    }

    public static func reviewSummary(
        draft: ActivityPublishDraft,
        templateTitle: String? = nil,
        isEditMode: Bool = false
    ) -> ReviewSummary {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = draft.addressName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStart = draft.start.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = draft.end.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = templateTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let resolvedTemplate: String
        if !trimmedTemplate.isEmpty {
            resolvedTemplate = trimmedTemplate
        } else if let templateID = draft.playTemplateID {
            resolvedTemplate = "#\(templateID.rawValue)"
        } else if isEditMode {
            resolvedTemplate = W8Text.t("保持当前关联模板不变", "Keep the linked template unchanged")
        } else {
            resolvedTemplate = W8Text.t("未选择", "Not selected")
        }

        return ReviewSummary(
            isEditMode: isEditMode,
            heading: isEditMode ? editReviewHeading : createReviewHeading,
            nameText: trimmedName.isEmpty ? W8Text.t("未填写名称", "No name entered") : trimmedName,
            timeText: "\(trimmedStart) ~ \(trimmedEnd)",
            addressText: trimmedAddress.isEmpty ? W8Text.t("未选择地点", "No place selected") : trimmedAddress,
            templateText: resolvedTemplate,
            ticketSummaryText: isEditMode ? nil : (W8Text.isChinese ? "\(draft.tickets.count) 个票种" : "\(draft.tickets.count) ticket type" + (draft.tickets.count == 1 ? "" : "s")),
            visibilityNotice: isEditMode ? editVisibilityNotice : createVisibilityNotice
        )
    }

    private static func filled(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private static func window(_ draft: ActivityPublishDraft) -> (String, String)? {
        guard let start = ProjectEditValidation.dateTime(draft.start),
              let end = ProjectEditValidation.dateTime(draft.end), end > start else { return nil }
        return (start, end)
    }
    private static func basic(_ draft: ActivityPublishDraft) -> Bool {
        window(draft) != nil && filled(draft.name) && filled(draft.addressName)
            && !draft.categoryIDs.isEmpty && draft.categoryIDs.allSatisfy { $0 > 0 }
    }
    private static func content(_ draft: ActivityPublishDraft) -> Bool {
        filled(draft.description) && filled(draft.coverURL) && draft.playTemplateID != nil
    }
    private static func tickets(_ draft: ActivityPublishDraft) -> Bool {
        guard let span = window(draft),
              draft.collaboratorMemberIDs.allSatisfy({ $0 > 0 }),
              Set(draft.collaboratorMemberIDs).count == draft.collaboratorMemberIDs.count,
              !draft.tickets.isEmpty else { return false }
        return draft.tickets.allSatisfy { (try? $0.wire(activityStart: span.0, activityEnd: span.1)) != nil }
    }
    private static func reason(_ step: Int, _ draft: ActivityPublishDraft) -> String? {
        switch step {
        case 0:
            if !filled(draft.name) { return "name" }
            if !filled(draft.addressName) { return "addressName" }
            if ProjectEditValidation.dateTime(draft.start) == nil { return "startDate" }
            if ProjectEditValidation.dateTime(draft.end) == nil { return "endDate" }
            if window(draft) == nil { return "endDate" }
            if draft.categoryIDs.isEmpty || !draft.categoryIDs.allSatisfy({ $0 > 0 }) { return "categoryIds" }
            return nil
        case 1:
            if !filled(draft.description) { return "description" }
            if draft.playTemplateID == nil { return "templateId" }
            if !filled(draft.coverURL) { return "imgUrl" }
            return nil
        default:
            if !draft.collaboratorMemberIDs.allSatisfy({ $0 > 0 })
                || Set(draft.collaboratorMemberIDs).count != draft.collaboratorMemberIDs.count { return "collaborators" }
            if draft.tickets.isEmpty { return "ticket" }
            guard let span = window(draft) else { return "startDate" }
            for (index, ticket) in draft.tickets.enumerated() {
                if !filled(ticket.name) { return "ticketName\(index)" }
                if ProjectEditValidation.decimal(ticket.price).map({ $0 >= 0 }) != true { return "ticketPrice\(index)" }
                if Int(ticket.stock).map({ $0 > 0 }) != true { return "ticketStock\(index)" }
                // r10 C-A8b: MP pages/publish/activity/index.wxml:158-186 has no per-ticket 开始 / 结束; submit overwrites
                // every ticket window with the activity span (PublishModesDomain.wire), so only that span is checked.
                if (try? ticket.wire(activityStart: span.0, activityEnd: span.1)) == nil { return "ticketEnd\(index)" }
            }
            return nil
        }
    }
}

/// Readiness for `pages/publish/activity/index`. It classifies reads the wizard already performs.
/// It does not publish, does not add a route, and does not change a route mark.
/// Unknown numbers display as an em dash. A literal zero stays zero.
public enum ActivityPublishingPageReadiness {
    public static let unknownDisplay = "—"

    public enum Phase: String, Equatable, Sendable {
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    /// A counted fact. Missing, blank, and non-integral values stay unknown. A literal 0 stays 0.
    public struct Count: Equatable, Sendable {
        public let value: Int?
        public var isUnknown: Bool { value == nil }
        public var display: String { value.map(String.init) ?? ActivityPublishingPageReadiness.unknownDisplay }

        public init(value: Int?) { self.value = value }

        public init(json: ProjectEditJSON?) {
            switch json {
            case .number?:
                self.value = json?.integer
            case .string(let raw)?:
                self.value = Self.canonicalInteger(raw)
            default:
                self.value = nil
            }
        }

        private static func canonicalInteger(_ raw: String) -> Int? {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text != "—", text != "-", text.uppercased() != "UNKNOWN" else { return nil }
            guard let value = Int(text), String(value) == text else { return nil }
            return value
        }
    }

    public struct OptionList: Equatable {
        public let phase: Phase
        public let rows: [PublishingOption]
        public let messageKey: String?

        public init(phase: Phase, rows: [PublishingOption], messageKey: String?) {
            self.phase = phase
            self.rows = rows
            self.messageKey = messageKey
        }

        /// Loading wins. A failed read is an error with no invented rows. No rows is empty.
        public static func resolve(loading: Bool, failed: Bool, rows: [PublishingOption]) -> OptionList {
            if loading { return OptionList(phase: .loading, rows: rows, messageKey: nil) }
            if failed { return OptionList(phase: .error, rows: [], messageKey: "publishModes.readFailed") }
            if rows.isEmpty { return OptionList(phase: .empty, rows: [], messageKey: "publishModes.empty") }
            return OptionList(phase: .ready, rows: rows, messageKey: nil)
        }
    }

    public struct Snapshot: Equatable {
        public let options: OptionList
        public let submission: Phase

        public var phase: Phase {
            if submission == .unknown { return .unknown }
            if options.phase == .loading { return .loading }
            if submission == .error || options.phase == .error { return .error }
            if options.phase == .empty { return .empty }
            return .ready
        }
    }

    /// Club activity publishing from an already-fetched home body. Money and merchant choice stay off.
    public struct CapabilityGate: Equatable, Sendable {
        public let activityAllowed: Bool
        public let remaining: Count
        public var showsMerchantChoice: Bool { false }
        public var paymentEnabled: Bool { false }
        public var payoutEnabled: Bool { false }
        public var withdrawalEnabled: Bool { false }
        public var virtualGoodsEnabled: Bool { false }

        public static func parse(_ body: [String: ProjectEditJSON]?) -> CapabilityGate {
            let allowed = body.map { PublishingCapability($0).activity } ?? false
            return CapabilityGate(activityAllowed: allowed, remaining: Count(json: body?["quota"]?.object?["themesRemaining"]))
        }
    }

    /// Reads this page already uses. Each one must already be live. This list does not add a path.
    public static func supportingReads() -> [PublishingRead] {
        [.capability, .identityStatus, .categories(activity: true), .collaborators(keyword: ""), .templates(keyword: "", scope: "")]
    }

    public static func supportingReadIsLive(_ read: PublishingRead) -> Bool {
        let path = read.request.path
        return ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(path)
    }

    /// Original create-request recovery stays hidden while those paths are not live.
    public static var createRequestPaths: [String] {
        [ActivityCreateRequestContract.submitPath, ActivityCreateRequestContract.readPath, ActivityCreateRequestContract.resumePath]
    }

    public static func createRequestPathStaysHidden(_ path: String) -> Bool {
        ChinaReviewedRouteCapability.mark(for: path) != .liveInProduction
            && ChinaReviewedRouteCapability.isHiddenFromChinaReviewed(path)
    }

    public static var createRequestRecoveryHidden: Bool {
        createRequestPaths.allSatisfy(createRequestPathStaysHidden)
    }

    public static var createRequestRecoveryOffered: Bool { false }

    public static func submissionPhase(_ outcome: PublishingWriteOutcome?) -> Phase {
        switch outcome {
        case .unknown: return .unknown
        case .notSent, .rejected: return .error
        case .acknowledged: return .ready
        case nil: return .ready
        }
    }

    public static func snapshot(options: OptionList, submission: PublishingWriteOutcome?) -> Snapshot {
        Snapshot(options: options, submission: submissionPhase(submission))
    }

    /// Decodes an existing options payload. An invalid payload stays an error, not an empty list of guesses.
    public static func options(kind: PublishingRead, payload: ProjectEditJSON) throws -> OptionList {
        let rows = try PublishingContracts.options(payload, kind: kind)
        return OptionList.resolve(loading: false, failed: false, rows: rows)
    }

    /// Collaborator follow count. Unknown is an em dash, including a literal UNKNOWN token. Zero stays 0.
    public static func collaboratorFollowText(_ object: [String: ProjectEditJSON]) -> String {
        Count(json: object["followNum"]).display
    }

    public static func draftQuantity(_ raw: String) -> String {
        Count(json: .string(raw)).display
    }

    public static func messageKey(for phase: Phase) -> String? {
        switch phase {
        case .loading, .ready: return nil
        case .empty: return "publishModes.empty"
        case .error: return "publishModes.readFailed"
        case .unknown: return "publishModes.unknown"
        }
    }
}

#if DEBUG
/// Synthetic payloads for the activity wizard. Debug builds only. No network and no credentials.
public enum ActivityPublishingFixtureData {
    public static let categories = #"[{"id":1,"categoryName":"Synthetic walk"}]"#
    public static let emptyCategories = "[]"
    public static let collaboratorsUnknownFollow = #"{"rows":[{"id":7,"nickname":"Synthetic guest"}]}"#
    public static let collaboratorsZeroFollow = #"{"rows":[{"id":8,"nickname":"Synthetic guest","followNum":0}]}"#
    public static let collaboratorsUnknownWord = #"{"rows":[{"id":9,"nickname":"Synthetic guest","followNum":"UNKNOWN"}]}"#
    public static let capabilityKnown = #"{"role":"club","quota":{"themesRemaining":3},"permission":{"canSimplePublish":true,"canProPublish":true}}"#
    public static let capabilityUnknownQuota = #"{"role":"club","permission":{"canSimplePublish":true,"canProPublish":true}}"#
    public static let capabilityZeroQuota = #"{"role":"club","quota":{"themesRemaining":0}}"#
    public static let malformedOptions = #"{"rows":"not-a-list"}"#

    public static func json(_ text: String) throws -> ProjectEditJSON {
        try JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8))
    }
}
#endif

