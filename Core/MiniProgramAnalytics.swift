import Foundation

/// Call-site helper for `utils/analytics.js` `track`. The queue, allow-list, sanitizer, and
/// batch flush stay in `AnalyticsEventClient` (`maxQueue` 100, `maxBatch` 50, one batch in flight).
public enum MiniProgramAnalytics {
    /// `bizId || null`: a missing or non-positive id is omitted, matching the mini-program normalizer.
    public static func bizID(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    public static func amount(_ value: Decimal) -> PlayWireValue? {
        let number = NSDecimalNumber(decimal: value)
        guard number != .notANumber else { return nil }
        let double = number.doubleValue
        guard double.isFinite else { return nil }
        return .number(double)
    }

    @MainActor
    public static func track(_ client: AnalyticsEventClient?, _ eventName: String, bizType: String = "", bizID: Int? = nil,
                             pagePath: String, properties: [String: PlayWireValue] = [:], idempotencyKey: String? = nil) {
        client?.track(eventName, bizType: bizType, bizID: bizID, pagePath: pagePath, properties: properties, idempotencyKey: idempotencyKey)
    }
}
