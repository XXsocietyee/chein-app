import Foundation

/// MP `pages/publishkit/components/reward-selector`: the two tabs 优惠券 / 体验卡 over one list.
/// 体验卡 is `couponType == 3`; everything else is a coupon (`applyRewardKind` in the MP).
public enum RewardCouponKind: String, CaseIterable, Sendable {
    case coupon
    case pass
}

/// One row of `POST /api/coupon/mypublishlist` (`is_select=1`), the author's own coupons.
public struct RewardCouponOption: Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let detail: String?
    public let couponType: Int
    public init(id: Int, name: String, detail: String?, couponType: Int) {
        self.id = id; self.name = name; self.detail = detail; self.couponType = couponType
    }
    public var kind: RewardCouponKind { couponType == 3 ? .pass : .coupon }
}

public enum RewardCouponSelectionError: Error, Equatable {
    case failed
    case signedOut
}

public enum RewardCouponSelectionContract {
    public static let path = "api/coupon/mypublishlist"
    /// The MP sends `{ is_select: 1, scope: '' }` for a player; an empty scope is the same as none.
    public static let fields: [String: String] = ["is_select": "1"]

    /// `res.data` is either the array or `{ rows: [...] }`; a non-200 code is a load error, never "no coupons" (L04-108).
    public static func decode(_ data: Data, status: Int) throws -> [RewardCouponOption] {
        if status == 401 { throw RewardCouponSelectionError.signedOut }
        guard (200..<300).contains(status),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw RewardCouponSelectionError.failed
        }
        let code = integer(root["code"])
        if code == 401 { throw RewardCouponSelectionError.signedOut }
        guard code == 200 else { throw RewardCouponSelectionError.failed }
        var rows: [Any] = []
        if let list = root["data"] as? [Any] {
            rows = list
        } else if let page = root["data"] as? [String: Any], let list = page["rows"] as? [Any] {
            rows = list
        }
        var seen = Set<Int>()
        var options: [RewardCouponOption] = []
        for item in rows {
            guard let row = item as? [String: Any], let id = integer(row["id"]), id > 0, !seen.contains(id) else { continue }
            seen.insert(id)
            let rawName = (row["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rawDetail = (row["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            options.append(RewardCouponOption(id: id, name: rawName, detail: rawDetail.isEmpty ? nil : rawDetail,
                                              couponType: integer(row["couponType"]) ?? 0))
        }
        return options
    }

    public static func visible(_ options: [RewardCouponOption], kind: RewardCouponKind) -> [RewardCouponOption] {
        options.filter { $0.kind == kind }
    }

    /// The MP opens on the tab that holds the selected coupon, so the author sees their pick.
    public static func initialKind(_ options: [RewardCouponOption], selected: Int?, current: RewardCouponKind) -> RewardCouponKind {
        guard let selected, selected > 0, let match = options.first(where: { $0.id == selected }) else { return current }
        return match.kind
    }

    static func integer(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let text = value as? String { return Int(text) }
        if let number = value as? Double, number.rounded() == number { return Int(number) }
        return nil
    }
}
