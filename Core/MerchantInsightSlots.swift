import Foundation

/// `pages/merchant/marketing/ai-insight` `_buildSlots`: `facts.checkin.slotBuckets`, not `hourBuckets`.
public struct MerchantInsightSlotBar: Equatable {
    public let slot: String
    public let count: Int
    public let pct: String
    public let height: Int
    public let isPeak: Bool
}

public struct MerchantInsightSlots: Equatable {
    public let bars: [MerchantInsightSlotBar]
    public let total: Int
    public let peakText: String

    public static func build(_ facts: MerchantMarketingValue) -> Self? {
        guard let buckets = facts["checkin"]["slotBuckets"].array, !buckets.isEmpty else { return nil }
        let counts = buckets.map { $0["count"].integer ?? 0 }
        let total = counts.reduce(0, +)
        guard total > 0, let maxCount = counts.max(), maxCount > 0 else { return nil }
        var peak = ""
        let bars = zip(buckets, counts).map { bucket, count -> MerchantInsightSlotBar in
            let slot = bucket["slot"].text ?? ""
            let isPeak = count == maxCount
            if isPeak && peak.isEmpty { peak = slot }
            return MerchantInsightSlotBar(
                slot: slot, count: count,
                pct: "\(jsRound(Double(count) / Double(total) * 100))%",
                height: max(6, jsRound(Double(count) / Double(maxCount) * 100)),
                isPeak: isPeak)
        }
        let word = ["早": "早上", "午": "中午", "晚": "晚上", "夜": "夜里"][peak] ?? peak
        return Self(bars: bars, total: total, peakText: peak.isEmpty ? "" : word + "到店最多")
    }

    /// `Math.round` for a non-negative value: half rounds away from zero.
    private static func jsRound(_ value: Double) -> Int { Int(floor(value + 0.5)) }
}
