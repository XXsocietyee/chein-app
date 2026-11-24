import Foundation

/// One club row from `POST /api/club/settlement/summary`. Amounts stay the server's strings.
public struct CoopClubSettlementDetail: Equatable {
    public static let pendingNet = "待核算"
    public let topicID: Int
    public let name: String
    public let statusText: String
    public let amountLabel: String
    public let amountText: String
    public let lineTypeText: String
    public let originalAmountText: String
    public let executedAdjustmentText: String
    public let netAmountText: String
    public let arrivedText: String
    public let paidText: String

    public static func resolve(_ value: CoopFlowJSON) -> Self? {
        guard case .object(let fields) = value else { return nil }
        return resolve(anyRecord(fields))
    }

    public static func resolve(_ record: [String: Any]) -> Self? {
        guard isClubSettlement(record),
              let topicID = positiveInteger(record["topicId"]),
              let name = nonEmpty(record["name"]),
              let status = record["status"] as? String else { return nil }
        let amountStatus = record["amountStatus"] as? String
        let rawAmount = record["amountText"]
        let shown: String
        if amountStatus == "unverified" { shown = pendingNet }
        else if let text = nonEmpty(rawAmount) { shown = text }
        else { return nil }
        return Self(
            topicID: topicID, name: name,
            statusText: statusText(status: status, amountStatus: amountStatus),
            amountLabel: amountLabel(status),
            amountText: shown,
            lineTypeText: lineTypeText(record["lineType"] as? String),
            originalAmountText: nonEmpty(record["originalAmountText"]) ?? "",
            executedAdjustmentText: nonEmpty(record["executedAdjustmentText"]) ?? "",
            netAmountText: nonEmpty(record["netAmountText"]) ?? "",
            arrivedText: nonEmpty(record["arrivedText"]) ?? "",
            paidText: nonEmpty(record["paidText"]) ?? "")
    }

    static func isClubSettlement(_ record: [String: Any]) -> Bool {
        guard positiveInteger(record["topicId"]) != nil, nonEmpty(record["name"]) != nil,
              let status = record["status"] as? String,
              status == "pending" || status == "settled" || status == "void" else { return false }
        let texts = ["originalAmountText", "executedAdjustmentText", "netAmountText", "arrivedText", "paidText"]
        guard texts.allSatisfy({ nonEmpty(record[$0]) != nil }) else { return false }
        if record["amountStatus"] as? String == "unverified" {
            return status == "settled" && record.keys.contains("amountText") && record["amountText"] is NSNull
        }
        return record["amountStatus"] as? String == "verified" && nonEmpty(record["amountText"]) != nil
    }

    static func statusText(status: String, amountStatus: String?) -> String {
        if status == "void" { return "已作废" }
        if status == "pending" { return "待入账" }
        if amountStatus == "unverified" { return "待核验" }
        if status != "settled" { return "状态待确认" }
        return "已入账"
    }

    static func amountLabel(_ status: String) -> String {
        if status == "pending" { return "待入账金额" }
        if status == "void" { return "作废前核算净额" }
        return "已入账金额"
    }

    static func lineTypeText(_ value: String?) -> String {
        if value == "INITIATOR_GUARANTEE" { return "主办保底" }
        if value == "INITIATOR_MARGIN" { return "主办分成" }
        return ""
    }

    static func anyRecord(_ fields: [String: CoopFlowJSON]) -> [String: Any] {
        var record: [String: Any] = [:]
        for (key, value) in fields {
            switch value {
            case .null: record[key] = NSNull()
            case .string(let text): record[key] = text
            case .bool(let flag): record[key] = flag
            case .number(let number):
                let decimal = NSDecimalNumber(decimal: number)
                if let exact = Int(exactly: decimal.int64Value), decimal.doubleValue == Double(exact) { record[key] = exact }
                else { record[key] = decimal.stringValue }
            default: break
            }
        }
        return record
    }

    static func nonEmpty(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func positiveInteger(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull), !(value is Bool) else { return nil }
        if let exact = value as? Int { return exact > 0 ? exact : nil }
        if let number = value as? NSNumber {
            let exact = number.int64Value
            guard exact > 0, number.doubleValue == Double(exact), let value = Int(exactly: exact) else { return nil }
            return value
        }
        if let text = value as? String { return MerchantFinanceRoute.canonicalID(text) }
        return nil
    }
}
