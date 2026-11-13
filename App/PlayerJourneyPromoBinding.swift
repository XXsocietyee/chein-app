import Foundation
import SwiftUI

/// Read-only affiliate summary for the shipped China composition.
/// `GET /api/marketing/affiliate/summary?limit=20`. No referral token, gift claim, withdraw, or payout.
@MainActor @Observable final class PlayerJourneyPromoModel: JourneyPromoBinding {
    private(set) var phase: JourneyPromoPhase = .loading
    private let source: JourneyLoopSource
    private let token: () -> String?

    init(source: JourneyLoopSource, token: @escaping () -> String?) {
        self.source = source
        self.token = token
    }

    func load() {
        phase = .loading
        Task { await reload() }
    }

    func signIn() { PlayerJourneySignInBridge.shared.request() }

    func reload() async {
        guard let session = token(), AuthRequestBuilder.isValidToken(session) else {
            phase = .auth
            return
        }
        do {
            phase = PlayerJourneyPromoProjection.phase(try await source.affiliate(token: session))
        } catch {
            phase = .failed
        }
    }
}

enum PlayerJourneyPromoProjection {
    static func phase(_ envelope: JourneyEnvelope) -> JourneyPromoPhase {
        if envelope.code == "401" || envelope.httpStatus == 401 { return .auth }
        if envelope.unconfirmed || envelope.netFail || !envelope.ok { return .failed }
        guard let object = jsonObject(envelope.dataJSON) else { return .failed }
        return .ready(content(object))
    }

    /// Mini-program `affiliateView`. Amounts come only from `netAmount`. `held.amountFen` is not a balance.
    static func content(_ object: [String: Any]) -> JourneyPromoContent {
        let allocations = object["allocations"] as? [String: Any] ?? [:]
        let rows = JourneyPromoBucket.Kind.allCases.map { kind -> JourneyPromoBucket in
            let bucket = allocations[kind.rawValue] as? [String: Any]
            return JourneyPromoBucket(kind: kind, amountText: amount(bucket).text, multiCurrency: amount(bucket).multi,
                                      count: bucket.flatMap { integral($0["allocationCount"]) })
        }
        let hasAllocations = rows.contains { ($0.count ?? 0) > 0 }
        let held = (object["held"] as? [String: Any]).flatMap { integral($0["orders"]) }.flatMap { $0 > 0 ? $0 : nil }
        return JourneyPromoContent(buckets: hasAllocations ? rows : [], heldOrders: held,
                                   campaigns: campaigns(object["campaigns"]), links: links(object["credentials"]))
    }

    private static func amount(_ bucket: [String: Any]?) -> (text: String?, multi: Bool) {
        guard let bucket else { return (nil, false) }
        if text(bucket["amountUnavailableReason"]) == PWaveAffiliateSummaryFact.multipleCurrenciesReason {
            return (nil, true)
        }
        guard let number = finite(bucket["netAmount"]), let formatted = yuan(number) else { return (nil, false) }
        return (formatted, false)
    }

    /// Two fraction digits, the page's `toFixed(2)`. A non-finite or non-number stays nil so the row draws an em dash.
    private static func yuan(_ value: Double) -> String? {
        guard value.isFinite, abs(value) <= 9_007_199_254_740_991 else { return nil }
        let negative = value < 0
        let scaled = (abs(value) * 100).rounded()
        guard scaled.isFinite, scaled <= Double(Int64.max) else { return nil }
        let cents = Int64(scaled)
        let fraction = cents % 100
        return "\(negative ? "-" : "")¥\(cents / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    private static func campaigns(_ value: Any?) -> [JourneyPromoCampaign] {
        guard let rows = value as? [Any] else { return [] }
        return rows.enumerated().compactMap { index, item in
            guard let row = item as? [String: Any] else { return nil }
            let key = text(row["campaignKey"]) ?? ""
            let target = idText(row["targetId"]) ?? ""
            let id = key.isEmpty && target.isEmpty ? "campaign-\(index)" : "\(key):\(target)"
            return JourneyPromoCampaign(id: id, title: text(row["targetTitle"]),
                                        attributed: integral(row["attributedOrders"]),
                                        paid: integral(row["paidOrders"]),
                                        refunded: integral(row["refundedOrders"]))
        }
    }

    private static func links(_ value: Any?) -> [JourneyPromoLink] {
        guard let rows = value as? [Any] else { return [] }
        return rows.enumerated().compactMap { index, item in
            guard let row = item as? [String: Any] else { return nil }
            let type = idText(row["targetType"]) ?? ""
            let target = idText(row["targetId"]) ?? ""
            let issued = text(row["issuedAt"]) ?? ""
            let id = type.isEmpty && target.isEmpty && issued.isEmpty ? "link-\(index)" : "\(type):\(target):\(issued)"
            return JourneyPromoLink(id: id, title: text(row["targetTitle"]), active: jsonBool(row["active"]) == true,
                                    expiresText: day(row["expiresAt"]))
        }
    }

    private static func day(_ value: Any?) -> String? {
        guard let raw = text(value), let match = raw.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else { return nil }
        return raw[match].replacingOccurrences(of: "-", with: ".")
    }

    private static func jsonObject(_ data: Data?) -> [String: Any]? {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private static func text(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    private static func idText(_ value: Any?) -> String? {
        if let raw = text(value) { return raw }
        if let number = integral(value) { return String(number) }
        return nil
    }

    private static func integral(_ value: Any?) -> Int? {
        guard let number = finite(value), number.rounded() == number, abs(number) <= Double(Int.max) else { return nil }
        return Int(number)
    }

    private static func finite(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    private static func jsonBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}

private extension JourneyPromoBucket.Kind {
    static var allCases: [JourneyPromoBucket.Kind] { [.pending, .confirmed, .paid, .reversed] }
}
