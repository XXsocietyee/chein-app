import Foundation

/// Port-2: the merchantinfo detail tab shows the topic subtitle, "主题介绍" description and an
/// "活动内容" list built by `buildContentIncludes` (pages/topic/merchantinfo/merchantinfo.js).
/// Pure projection of the already-read topic object; it never reads or writes anything.
public struct MerchantTopicIntro: Equatable {
    public enum Include: Equatable {
        case chapters(Int), stations(Int), plays(Int)
        case audio(minutes: Int?)
        case medal(name: String?)
        case completionCoupon
    }
    public let subtitle: String?
    public let introduction: String?
    public let includes: [Include]
    public var isEmpty: Bool { subtitle == nil && introduction == nil && includes.isEmpty }

    /// The source treats the literal string "null" as absent text.
    static func clean(_ value: MerchantContentValue) -> String? {
        guard let text = value.display?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, text != "null" else { return nil }
        return text
    }
    private static func positive(_ value: MerchantContentValue) -> Int? {
        guard let number = value.integer, number > 0 else { return nil }
        return number
    }
    public init(topic: MerchantContentValue) {
        subtitle = Self.clean(topic["subtitle"])
        introduction = Self.clean(topic["description"])
        var list: [Include] = []
        if let n = Self.positive(topic["totalChapterCount"]) { list.append(.chapters(n)) }
        if let n = Self.positive(topic["locationCount"]) { list.append(.stations(n)) }
        if let n = Self.positive(topic["templateCount"]) { list.append(.plays(n)) }
        if Self.clean(topic["audioUrl"]) != nil {
            let seconds = topic["audioDuration"].display.flatMap { Double($0) }
            let minutes = seconds.flatMap { $0.isFinite ? Int(($0 / 60).rounded()) : nil }
            list.append(.audio(minutes: (minutes ?? 0) > 0 ? minutes : nil))
        }
        let medalName = Self.clean(topic["finishMedalName"])
        if medalName != nil || Self.clean(topic["finishMedalImg"]) != nil { list.append(.medal(name: medalName)) }
        if Self.positive(topic["completeRewardCouponId"]) != nil { list.append(.completionCoupon) }
        includes = list
    }
}
