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
    public static var collaboratorSettlementNotice: String { W8Text.t("合作者可编辑内容，不参与结算", "Collaborators can edit content but don’t take part in settlement") }
    public static var merchantFreeTicketOnlyNotice: String { W8Text.t("商家活动暂时只支持免费票", "Merchant activities only support free tickets for now") }
    public static var merchantPaidTicketBlockedMessage: String { W8Text.t("商家主办活动还没开通收款，票价只能是 0", "Payments aren’t enabled for merchant-hosted activities yet, so the ticket price must be 0") }
    public static var createReviewHeading: String { W8Text.t("发布前摘要", "Summary before publishing") }
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
                if ProjectEditValidation.dateTime(ticket.start) == nil { return "ticketStart\(index)" }
                if ProjectEditValidation.dateTime(ticket.end) == nil { return "ticketEnd\(index)" }
                if (try? ticket.wire(activityStart: span.0, activityEnd: span.1)) == nil { return "ticketEnd\(index)" }
            }
            return nil
        }
    }
}
