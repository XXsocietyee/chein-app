import SwiftUI

/// MC8-30-6: coop/list 再邀别人 → `pages/coop/nearby?topicId=` (MP `goInviteOthers`). The host injects the topic-scoped
/// nearby page; nil keeps the MP hint text only.
private struct CooperationTopicNearbyDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor (CoopNearbyTopicContext) -> AnyView)? = nil
}
extension EnvironmentValues {
    var cooperationTopicNearbyDestination: (@MainActor (CoopNearbyTopicContext) -> AnyView)? {
        get { self[CooperationTopicNearbyDestinationKey.self] }
        set { self[CooperationTopicNearbyDestinationKey.self] = newValue }
    }
}

/// MC8-30-8 (utils/coop-invite-view.js:33-45 `countdownOf`): a pending invite's validity, 邀约剩 N 天/小时有效 or 邀约已过期.
/// `expireTime` is the pending invite's own expiry, not the topic's recruiting deadline.
enum CoopInviteCountdown {
    enum Value: Equatable { case days(Int), hours(Int), expired }
    static func value(status: Int?, expire: CooperationSourceTime?, now: Date = Date()) -> Value? {
        guard status == 0, let expire, let end = date(expire) else { return nil }
        let diff = end.timeIntervalSince(now)
        if diff <= 0 { return .expired }
        let days = Int(diff / 86_400)
        return days > 0 ? .days(days) : .hours(Int(diff.truncatingRemainder(dividingBy: 86_400) / 3_600))
    }
    /// Server text is `yyyy-MM-dd HH:mm:ss` in China time (MP `toTimestamp`); epoch milliseconds are also accepted.
    static func date(_ time: CooperationSourceTime) -> Date? {
        switch time {
        case .milliseconds: return time.date
        case .text(let text):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: trimmed) { return date }
            }
            return nil
        }
    }
}

struct CoopInviteCountdownText: View {
    let value: CoopInviteCountdown.Value
    var body: some View {
        switch value {
        case .days(let days): Text("merchantCoop.list.countdown.days \(days)")
        case .hours(let hours): Text("merchantCoop.list.countdown.hours \(hours)")
        case .expired: Text("merchantCoop.list.countdown.expired")
        }
    }
}

/// MC8-33-8 (components/cy/merchant-card/index.wxml:4,7,15,21): the MP venue-card images. The nearby row has no
/// cover or logo yet (Core request), so the MP defaults show: `default-cover.png` with the `citylink.svg` brand mark,
/// the pin before the address and the chevron at the end.
struct NearbyMerchantCardChrome<Content: View>: View {
    @ScaledMetric(relativeTo: .body) private var scaledSide: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var chevronSide: CGFloat = 14
    /// a11y-dt: artwork grows with Dynamic Type but stops at 96 pt so the venue text keeps the row at AX5.
    private var side: CGFloat { min(scaledSide, 96) }
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            ZStack(alignment: .topLeading) {
                MPAsset.BannerCover.defaultCover.resizable().scaledToFill()
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
                MPAsset.FeatureIcon.citylink.resizable().scaledToFit()
                    .frame(width: side * 0.36, height: side * 0.36)
                    .padding(CYSpacing.xxs)
                    .accessibilityHidden(true)
            }
            content().frame(maxWidth: .infinity, alignment: .leading)
            MPAsset.FeatureIcon.chevron.resizable().scaledToFit()
                .frame(width: chevronSide, height: chevronSide)
                .accessibilityHidden(true)
        }
    }
}

struct NearbyMerchantAddressLine: View {
    let address: String
    @ScaledMetric(relativeTo: .footnote) private var pinSide: CGFloat = 12
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xxs) {
            MPAsset.FeatureIcon.pin.resizable().scaledToFit()
                .frame(width: pinSide, height: pinSide)
                .accessibilityHidden(true)
            Text(verbatim: address).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
    }
}

/// MC8-30-4 / MC8-30-5: coop/list 回邀约 (received application → club, type 1) and 发邀约 (confirmed registration →
/// merchant, type 0) open the new-invitation page with the recipient and topic fixed.
struct CoopListInvitePreset: Equatable {
    let target: CoopInviteLockedTarget
    let topicID: Int
}
