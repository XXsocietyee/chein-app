import Foundation

/// Ids the participation payload already carries for one orienteering score read.
/// Missing or inconsistent ids stay nil. Nothing here copies the registration id,
/// an owner id, or a topic id into a different field.
public enum ParticipationOrientScoreEntry {
    public struct Keys: Equatable {
        public let topicID: Int?
        public let activityID: Int?
        public let productType: Int?
    }

    static func keys(raw: PlayWireValue, registrationID: Int) -> Keys {
        let productSource = raw["cmsActivity"].object != nil ? raw["cmsActivity"] : raw["cmsTopic"]
        let productType = exactInteger(productSource["productType"])
        guard positive(raw["id"]) == registrationID else {
            return Keys(topicID: nil, activityID: nil, productType: productType)
        }
        let owner = positive(raw["ownerId"])
        var topic: Int?
        var activity: Int?
        switch ownerCode(raw["ownerType"]) {
        case 1:
            let topicObject = raw["cmsTopic"]
            let cmsTopicID = topicObject.object == nil ? nil : positive(topicObject["id"])
            if let owner, let cmsTopicID, owner == cmsTopicID { topic = cmsTopicID }
            // Mini `_resultEntry`: ownerType 1 sends activityId 0. That is the self-play
            // filter, not an activity record id, and it is kept only after the topic id matches.
            if topic != nil { activity = 0 }
        case 2:
            let activityObject = raw["cmsActivity"]
            let cmsActivityID = activityObject.object == nil ? nil : positive(activityObject["id"])
            if let owner, let cmsActivityID, cmsActivityID == owner {
                activity = cmsActivityID
                topic = positive(activityObject["topicId"])
            }
        default:
            break
        }
        if let matched = topic, !isZeroOrNull(raw["topicId"]), positive(raw["topicId"]) != matched {
            topic = nil
            if ownerCode(raw["ownerType"]) == 1 { activity = nil }
        }
        return Keys(topicID: topic, activityID: activity, productType: productType)
    }

    /// Nil hides the score entry. The signed-in account must be the registration's `memberId`,
    /// the product type must be the integer 1, and both ids must already be on the detail.
    public static func request(_ detail: ParticipationDetail, accountID: Int?) -> (topicID: Int, activityID: Int)? {
        guard detail.productType == 1,
              let topicID = detail.topicID, topicID > 0,
              let activityID = detail.activityID, activityID >= 0,
              let memberID = detail.record.order.memberID, memberID > 0,
              accountID == memberID else { return nil }
        return (topicID, activityID)
    }

    /// True when the payload has enough fields that the signed-in session should be asked.
    /// The account match still happens in `request`.
    public static func canAskSession(_ detail: ParticipationDetail) -> Bool {
        detail.productType == 1 && detail.topicID != nil && detail.activityID != nil
            && (detail.record.order.memberID ?? 0) > 0
    }

    private static func ownerCode(_ value: PlayWireValue) -> Int? {
        switch value {
        case .integer(let number):
            guard number == 1 || number == 2 else { return nil }
            return Int(number)
        case .string(let text):
            guard text == "1" || text == "2" else { return nil }
            return Int(text)
        default:
            return nil
        }
    }

    /// Positive id in the mini `exactId` form: a JSON integer or a digit string, no leading zero,
    /// inside the safe-integer range. Bools, fractions, and zero are not ids.
    private static func positive(_ value: PlayWireValue) -> Int? {
        let digits: String
        switch value {
        case .integer(let number):
            guard number > 0, number <= 9_007_199_254_740_991 else { return nil }
            digits = String(number)
        case .string(let text):
            digits = text
        default:
            return nil
        }
        guard digits.range(of: #"^[1-9][0-9]{0,18}$"#, options: .regularExpression) != nil else { return nil }
        if digits.count == 19, digits > "9223372036854775807" { return nil }
        return Int(digits)
    }

    private static func exactInteger(_ value: PlayWireValue) -> Int? {
        switch value {
        case .integer(let number):
            guard number >= 0, number <= 9_007_199_254_740_991 else { return nil }
            return Int(number)
        case .string(let text):
            guard text.range(of: #"^(0|[1-9][0-9]{0,18})$"#, options: .regularExpression) != nil else { return nil }
            if text.count == 19, text > "9223372036854775807" { return nil }
            return Int(text)
        default:
            return nil
        }
    }

    private static func isZeroOrNull(_ value: PlayWireValue) -> Bool {
        if value == .null { return true }
        if case .integer(let number) = value, number == 0 { return true }
        return value.text == "0"
    }
}
