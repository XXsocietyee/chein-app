import Foundation

// Money-critical rules ported 1:1 from the mini-program (chengyinhub-xcx) and the Java services it calls.
// Everything here is pure: money is integer minor units (fen), time is epoch milliseconds (Int64).
// No Float/Double is used for amounts. Audit table: docs/parity/logic-parity-money.md.

/// Port of `utils/datetime.js` `toTimestamp` / `chinaDateKey` (bare strings are China time, UTC+8).
public enum MoneyParityTime {
    public static let chinaOffsetMs: Int64 = 8 * 3_600_000
    public static let dayMs: Int64 = 86_400_000
    /// JS Date range: +-8.64e15 ms.
    static let maxEpochMs: Int64 = 8_640_000_000_000_000

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    static func isValidCalendar(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Bool {
        guard mo >= 1, mo <= 12 else { return false }
        let days = [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard d >= 1, d <= days[mo - 1] else { return false }
        return h >= 0 && h <= 23 && mi >= 0 && mi <= 59 && s >= 0 && s <= 59
    }

    /// Days since 1970-01-01 for a proleptic Gregorian civil date.
    static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int64 {
        let y = Int64(month <= 2 ? year - 1 : year)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = Int64(month > 2 ? month - 3 : month + 9)
        let doy = (153 * mp + 2) / 5 + Int64(day) - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func inRange(_ ms: Int64) -> Bool { ms >= -maxEpochMs && ms <= maxEpochMs }

    private static func captures(_ pattern: String, _ text: String, options: NSRegularExpression.Options = []) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        var out: [String?] = []
        for i in 1..<m.numberOfRanges {
            let r = m.range(at: i)
            out.append(r.location == NSNotFound ? nil : ns.substring(with: r))
        }
        return out
    }

    /// `toTimestamp` for a string. nil == NaN (fail closed): empty, 0-sentinel-like garbage, invalid calendar,
    /// out-of-range. 10 digits = seconds, 13 digits = milliseconds, bare strings = China time, offset ISO kept.
    public static func timestamp(_ raw: String?) -> Int64? {
        guard let raw else { return nil }
        let str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.isEmpty { return nil }
        if str.count == 10, str.allSatisfy({ $0 >= "0" && $0 <= "9" }), let v = Int64(str) {
            return inRange(v * 1000) ? v * 1000 : nil
        }
        if str.count == 13, str.allSatisfy({ $0 >= "0" && $0 <= "9" }), let v = Int64(str) {
            return inRange(v) ? v : nil
        }
        if let last = str.last, last == "z" || last == "Z" || endsWithOffset(str) { return parseOffsetIso(str) }
        return parseChinaString(str)
    }

    /// `toTimestamp` for a number. 0 / non-finite fail closed; positive 10-digit integers are seconds.
    public static func timestamp(number value: Double) -> Int64? {
        guard value.isFinite, value != 0 else { return nil }
        let isTenDigitInteger = value.rounded(.down) == value && value > 0 && String(Int64(exactly: value) ?? 0).count == 10
        let ms = isTenDigitInteger ? value * 1000 : value
        guard abs(ms) <= Double(maxEpochMs), let out = Int64(exactly: ms.rounded(.down)) else { return nil }
        return out
    }

    private static func endsWithOffset(_ s: String) -> Bool {
        captures("[+-][0-9]{2}:?[0-9]{2}$", s) != nil
    }

    private static func parseChinaString(_ str: String) -> Int64? {
        let pattern = "^([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})(?:[ T]([0-9]{1,2}):([0-9]{1,2})(?::([0-9]{1,2})(?:\\.[0-9]{1,9})?)?)?$"
        guard let c = captures(pattern, str), let y = Int(c[0] ?? ""), let mo = Int(c[1] ?? ""), let d = Int(c[2] ?? "") else { return nil }
        let h = Int(c[3] ?? "") ?? 0
        let mi = Int(c[4] ?? "") ?? 0
        let s = Int(c[5] ?? "") ?? 0
        guard isValidCalendar(y, mo, d, h, mi, s) else { return nil }
        let local = daysFromCivil(y, mo, d) * dayMs + Int64(h) * 3_600_000 + Int64(mi) * 60_000 + Int64(s) * 1000
        let ms = local - chinaOffsetMs
        return inRange(ms) ? ms : nil
    }

    private static func parseOffsetIso(_ str: String) -> Int64? {
        let pattern = "^([0-9]{4})-([0-9]{2})-([0-9]{2})[T ]([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\\.([0-9]{1,9}))?)?(Z|[+-][0-9]{2}:?[0-9]{2})$"
        guard let c = captures(pattern, str, options: [.caseInsensitive]),
              let y = Int(c[0] ?? ""), let mo = Int(c[1] ?? ""), let d = Int(c[2] ?? ""),
              let h = Int(c[3] ?? ""), let mi = Int(c[4] ?? "") else { return nil }
        let s = Int(c[5] ?? "") ?? 0
        guard isValidCalendar(y, mo, d, h, mi, s) else { return nil }
        var fractionMs: Int64 = 0
        if let frac = c[6] {
            fractionMs = Int64(String((frac + "00").prefix(3))) ?? 0
        }
        var offsetMs: Int64 = 0
        if let zone = c[7], zone.uppercased() != "Z" {
            let digits = zone.dropFirst().replacingOccurrences(of: ":", with: "")
            guard digits.count == 4, let hh = Int64(digits.prefix(2)), let mm = Int64(digits.suffix(2)) else { return nil }
            offsetMs = (hh * 60 + mm) * 60_000 * (zone.hasPrefix("-") ? -1 : 1)
        }
        let local = daysFromCivil(y, mo, d) * dayMs + Int64(h) * 3_600_000 + Int64(mi) * 60_000 + Int64(s) * 1000 + fractionMs
        let ms = local - offsetMs
        return inRange(ms) ? ms : nil
    }

    /// Floor division that is correct for negative numerators.
    static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    /// Day index in China calendar (`chinaDateKey` equivalent as an integer).
    public static func chinaDayIndex(_ ms: Int64) -> Int64 { floorDiv(ms + chinaOffsetMs, dayMs) }
}

/// Port of `utils/ticket-window.js` (CU-C-32: a session stops selling when it starts).
public enum MoneyTicketWindow {
    public enum State: String, Equatable { case available = "", started, ended, closed }

    /// Millisecond core. `nil` start/end/deadline == unparsable (NaN in the source).
    public static func state(startMs: Int64?, endMs: Int64?, signupDeadlineMs: Int64?, selfGuided: Bool, nowMs: Int64) -> State {
        if selfGuided {
            guard let endMs, nowMs < endMs else { return .ended }
            if let signupDeadlineMs, nowMs >= signupDeadlineMs { return .closed }
            return .available
        }
        if let startMs {
            if nowMs < startMs { return .available }
            if let endMs, nowMs > endMs { return .ended }
            return .started
        }
        if let endMs { return nowMs > endMs ? .ended : .available }
        return .available
    }

    public static func state(startTime: String?, endTime: String?, signupDeadline: String?, selfGuided: Bool, nowMs: Int64) -> State {
        state(startMs: MoneyParityTime.timestamp(startTime), endMs: MoneyParityTime.timestamp(endTime),
              signupDeadlineMs: MoneyParityTime.timestamp(signupDeadline), selfGuided: selfGuided, nowMs: nowMs)
    }

    /// `ticketWindowText`: user-facing sentence, empty when sellable.
    public static func text(_ state: State) -> String {
        switch state {
        case .ended: return "场次已结束"
        case .started: return "场次已开始"
        case .closed: return "报名已截止"
        case .available: return ""
        }
    }

    /// baoming.js `ticketSignupClosed`: only the ticket `endTime` passing (strictly after) closes signup.
    public static func signupClosed(endTime: String?, nowMs: Int64) -> Bool {
        guard let endMs = MoneyParityTime.timestamp(endTime) else { return false }
        return nowMs > endMs
    }
}

/// Port of `utils/ticket-expiry.js` (V-02): only tickets expiring within 7 calendar days show text.
public enum MoneyPassExpiry {
    public static let windowDays = 7

    /// Natural-day count (China calendar). Today == 0. Already past `until` (instant) or no date == nil.
    public static func daysLeft(until: String?, nowMs: Int64) -> Int? {
        guard let untilMs = MoneyParityTime.timestamp(until) else { return nil }
        if untilMs < nowMs { return nil }
        return Int(MoneyParityTime.chinaDayIndex(untilMs) - MoneyParityTime.chinaDayIndex(nowMs))
    }

    public static func text(until: String?, nowMs: Int64) -> String {
        guard let days = daysLeft(until: until, nowMs: nowMs) else { return "" }
        if days <= 0 { return "今天过期" }
        return days <= windowDays ? "\(days) 天内过期" : ""
    }
}

/// Port of `utils/order-actual-pay.js`. All amounts are integer fen; `nil` == null/undefined.
public enum MoneyActualPay {
    /// Cash actually paid: wechat amount, else payable, else total. 0 is a legal value (never `||`).
    public static func resolveActualPaidMinor(wechat: Int64?, payable: Int64?, total: Int64?) -> Int64? {
        if let wechat { return wechat }
        if let payable { return payable }
        return total
    }

    /// `isFreeOrder`: total and payable explicitly zero, and any present point/wechat amount zero.
    public static func isFreeOrder(total: Int64?, payable: Int64?, point: Int64?, wechat: Int64?) -> Bool {
        total == 0 && payable == 0 && (point == nil || point == 0) && (wechat == nil || wechat == 0)
    }
}

/// Port of `payoutSummary` in `utils/order-status.js` (refund payout truth = refund_application).
public enum MoneyRefundPayout {
    public enum Key: String, Equatable { case refunded, refunding }
    public struct Summary: Equatable {
        public let key: Key
        public let text: String
        public let refundText: String
    }

    /// `applicationPresent` is `application != null`. status: 0 pending / 1 approved / 2 rejected.
    /// payoutStatus: 0 accepted / 1 paid / 2 manual-pending / 3 manual-refunded / 4 reviewed / 5,6 internal.
    public static func summary(applicationPresent: Bool, status: Int?, payoutStatus: Int?, refundAmountMinor: Int64?) -> Summary? {
        guard applicationPresent else { return nil }
        if payoutStatus == 1 || payoutStatus == 4 {
            return Summary(key: .refunded, text: "已退款", refundText: "退款已原路退回")
        }
        if payoutStatus == 2 {
            return Summary(key: .refunding, text: "退款处理中", refundText: "原路退款异常，平台正在人工处理")
        }
        if payoutStatus == 3 {
            return Summary(key: .refunding, text: "退款处理中", refundText: "人工退款已处理，等待复核确认")
        }
        if let amount = refundAmountMinor, !(amount > 0) { return nil }
        if status == 2 { return nil }
        if status == 0 {
            return Summary(key: .refunding, text: "退款审核中", refundText: "退款申请已提交，等待平台审核")
        }
        if payoutStatus == 0 {
            return Summary(key: .refunding, text: "退款处理中", refundText: "微信已受理原路退款，到账以微信退款通知为准")
        }
        if status == 1 {
            return Summary(key: .refunding, text: "退款处理中", refundText: "退款已批准，正在提交原路退款")
        }
        return Summary(key: .refunding, text: "退款处理中", refundText: "退款进度更新中，请以微信退款通知为准")
    }

    /// `canRequestOrderRefund`.
    public static func canRequestRefund(manualRefundCasePresent: Bool, payout: Summary?, registrationStatus: Int?,
                                        paymentStatus: Int?, verificationStatus: Int?, refundable: Bool?) -> Bool {
        !manualRefundCasePresent && payout == nil && registrationStatus == 2 && paymentStatus == 2
            && verificationStatus != 1 && refundable == true
    }
}

/// Port of `RefundPolicy.evaluate` (Java `chengyinhub-system/.../util/RefundPolicy.java`), activity-session and ticket-mode paths.
public enum MoneyRefundPolicy {
    /// Java `PurchaseKind.EXPLORE_PASS`.
    public static let explorePassPurchaseKind = 3
    /// 集合前 24 小时.
    public static let sessionRefundWindowMs: Int64 = 24 * 3_600_000

    public struct Verdict: Equatable {
        public let refundable: Bool
        public let deadlineMs: Int64?
        public let manualReview: Bool
        public let reason: String
    }

    public static func sessionRefundDeadline(assemblyMs: Int64?) -> Int64? {
        assemblyMs.map { $0 - sessionRefundWindowMs }
    }

    /// ownerType 2 = activity session ticket; otherwise ticketMode 2 = free exploration (ticket end), else ticket start.
    public static func evaluate(ownerType: Int?, paymentStatus: Int?, verificationStatus: Int?, ticketMode: Int?,
                                ticketStartMs: Int64?, ticketEndMs: Int64?, activityStartMs: Int64?,
                                snapshotDeadlineMs: Int64?, payableMinor: Int64?, pointUsed: Int64?, nowMs: Int64?,
                                purchaseKind: Int? = nil) -> Verdict {
        guard paymentStatus == 2 else { return Verdict(refundable: false, deadlineMs: nil, manualReview: false, reason: "未支付订单无需退款") }
        // RefundPolicy.verifiedVerdict: a verified free-exploration pass (PurchaseKind.EXPLORE_PASS) goes to manual
        // review; every other kind (and legacy orders with purchaseKind == nil) is a hard refusal.
        if verificationStatus == 1 {
            if purchaseKind == explorePassPurchaseKind {
                return Verdict(refundable: false, deadlineMs: nil, manualReview: true, reason: "已核销订单需人工核实,请联系客服")
            }
            return Verdict(refundable: false, deadlineMs: nil, manualReview: false, reason: "已核销报名不可退款")
        }
        if ownerType == 2, payableMinor == 0, pointUsed == 0 {
            guard let activityStartMs, let nowMs else {
                return Verdict(refundable: false, deadlineMs: nil, manualReview: true, reason: "集合时间缺失，需人工核实，请联系客服")
            }
            return nowMs < activityStartMs
                ? Verdict(refundable: true, deadlineMs: activityStartMs, manualReview: false, reason: "可取消报名并释放名额")
                : Verdict(refundable: false, deadlineMs: activityStartMs, manualReview: false, reason: "场次已开始，不可取消报名")
        }
        let deadline: Int64?
        if let snapshotDeadlineMs { deadline = snapshotDeadlineMs }
        else if ownerType == 2 { deadline = sessionRefundDeadline(assemblyMs: activityStartMs) }
        else if ticketMode == 2 { deadline = ticketEndMs }
        else { deadline = ticketStartMs }
        guard let deadline else {
            return Verdict(refundable: false, deadlineMs: nil, manualReview: true, reason: "退款截止时间缺失,需人工核实,请联系客服")
        }
        if let nowMs, nowMs > deadline {
            return Verdict(refundable: false, deadlineMs: deadline, manualReview: false, reason: "已过退款截止时间")
        }
        return Verdict(refundable: true, deadlineMs: deadline, manualReview: false, reason: "可全额退款,原路退回")
    }
}

/// Port of `CmsRegistrationServiceImpl.computePrice` (Java) with the platform `PointsValuePolicy`.
/// Amounts are fen (1/100 yuan). The point rate is yuan-per-point in micro-yuan (0.02 yuan == 20_000) so a
/// configured fractional-fen rate stays exact. The backend never applies a coupon to the registration price
/// ("券为商家核销型，不抵扣报名支付"), so there is deliberately no coupon input.
public enum MoneyPricing {
    /// CmsConstants.POINT_DEDUCT_RATE = 0.02 yuan per point.
    public static let defaultRateMicroYuan: Int64 = 20_000
    /// CmsConstants.MAX_POINT_DEDUCT_AMOUNT = 50.00 yuan per order (once per order, never per ticket).
    public static let defaultMaxPerOrderMinor: Int64 = 5_000
    static let microPerFen: Int64 = 10_000

    public struct Breakdown: Equatable {
        public let originalMinor: Int64
        public let totalMinor: Int64
        public let memberDiscountMinor: Int64
        public let pointDeductMinor: Int64
        public let pointUsed: Int64
        public let payableMinor: Int64
        /// 0 = points only, 1 = wechat only, 2 = points + wechat.
        public let paymentType: Int
        public let pointPaymentMinor: Int64
        public let wechatPaymentMinor: Int64
    }

    /// Divide rounding half-up for non-negative operands.
    static func divHalfUp(_ n: Int64, _ d: Int64) -> Int64 { (n + d / 2) / d }
    static func divCeil(_ n: Int64, _ d: Int64) -> Int64 { (n + d - 1) / d }

    /// `unitMinor` is the ticket list price; `memberUnitMinor` the club member price (effective = min of the two
    /// when the viewer is a club member, otherwise nil). Negative or zero quantity is clamped like a 1-ticket order.
    public static func compute(unitMinor: Int64, memberUnitMinor: Int64? = nil, quantity: Int, userPoints: Int64,
                               usePoints: Bool, rateMicroYuan: Int64 = defaultRateMicroYuan,
                               maxPerOrderMinor: Int64 = defaultMaxPerOrderMinor) -> Breakdown {
        let qty = Int64(max(1, quantity))
        let unit = max(0, unitMinor)
        let effective = memberUnitMinor.map { min(unit, max(0, $0)) } ?? unit
        let original = unit * qty
        let total = effective * qty
        let memberDiscount = original - total
        let rate = rateMicroYuan > 0 ? rateMicroYuan : defaultRateMicroYuan
        let cap = maxPerOrderMinor > 0 ? maxPerOrderMinor : defaultMaxPerOrderMinor

        var deductMicro: Int64 = 0
        var pointUsed: Int64 = 0
        if usePoints, userPoints > 0 {
            let capMicro = min(cap, total) * microPerFen
            let balanceMicro = userPoints * rate
            deductMicro = min(balanceMicro, capMicro)
            pointUsed = divCeil(deductMicro, rate)
        }
        // Quote result scales to 2 decimals, HALF_UP.
        let deductMinor = divHalfUp(deductMicro, microPerFen)
        let payable = total - deductMinor
        let type: Int
        let pointPay: Int64
        let wechatPay: Int64
        if usePoints {
            if payable <= 0 { type = 0; pointPay = total; wechatPay = 0 }
            else { type = 2; pointPay = deductMinor; wechatPay = payable }
        } else { type = 1; pointPay = 0; wechatPay = total }
        return Breakdown(originalMinor: original, totalMinor: total, memberDiscountMinor: memberDiscount,
                      pointDeductMinor: deductMinor, pointUsed: pointUsed, payableMinor: payable,
                      paymentType: type, pointPaymentMinor: pointPay, wechatPaymentMinor: wechatPay)
    }

    /// baoming.js refreshQuote: a points toggle that comes back with a 0 deduction must be switched off,
    /// with the real reason ("暂无可用积分" when the user has no points, else "该票不支持积分抵扣").
    public static func pointsToggleNotice(usePoints: Bool, quotedDeductMinor: Int64, userPoints: Int64) -> String? {
        guard usePoints, quotedDeductMinor <= 0 else { return nil }
        return userPoints > 0 ? "该票不支持积分抵扣" : "暂无可用积分"
    }
}

/// Port of the host-cancel flow in `scene-play-activity-detail/index.js` (openCancel / submitCancel).
public enum MoneyHostCancelParity {
    /// `ok(res)`: code is 200 as number or "200" as string. Booleans / other values are not ok.
    public static func responseCode(_ value: Any?) -> Int? {
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
            return n.doubleValue == Double(n.intValue) ? n.intValue : nil
        }
        if let s = value as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(t)
        }
        return nil
    }

    /// `Number.isInteger(Number(paidPlayers)) && n >= 0`. Numeric strings are accepted like the source;
    /// the JS coercion quirks (null, "", true -> 0/1) are deliberately NOT mirrored: an unknown count must
    /// block the confirmation instead of telling the host that 0 players will be refunded.
    public static func paidPlayers(_ value: Any?) -> Int? {
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
            let d = n.doubleValue
            guard d.isFinite, d >= 0, d == d.rounded(), d <= Double(Int32.max) else { return nil }
            return Int(d)
        }
        if let s = value as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, let d = Double(t), d.isFinite, d >= 0, d == d.rounded(), d <= Double(Int32.max) else { return nil }
            return Int(d)
        }
        return nil
    }
}

/// Opt-in adapters so callers can move to the fen-exact money rules without a flag day. Nothing calls them yet:
/// `RegistrationCoreLoopRules.computeOrderPrice` stays the live path until the owner decides on coupon deduction
/// (`ActivityRegistrationParityW206Tests` pins it). Compile-time shapes mirror the legacy `Decimal`-yuan API.
public enum MoneyPricingAdapter {
    public struct Output: Equatable {
        /// Same shape as the legacy result; `couponDeductYuan` is always 0 (the backend never deducts coupons).
        public let price: RegistrationCoreLoopRules.ComputedOrderPrice
        /// Fen-exact breakdown including `paymentType` and the points/wechat split.
        public let breakdown: MoneyPricing.Breakdown
    }

    static func fen(_ yuan: Decimal) -> Int64 {
        var input = yuan * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func yuan(_ fen: Int64) -> Decimal { Decimal(fen) / 100 }

    /// Points use `MoneyPricing.defaultRateMicroYuan` (the port of `CmsConstants.POINT_DEDUCT_RATE`).
    /// Callers cannot pass a client yuan-per-point rate. `maxPointsDeductPerOrderYuan` caps once per order.
    public static func compute(unitPrice: Decimal, quantity: Int = 1, memberUnitPrice: Decimal? = nil,
                               usePoints: Bool = false, pointsUsableForProduct: Bool = true, userAvailablePoints: Int = 0,
                               maxPointsDeductPerOrderYuan: Decimal = 50) -> Output {
        let b = MoneyPricing.compute(
            unitMinor: fen(unitPrice), memberUnitMinor: memberUnitPrice.map(fen), quantity: quantity,
            userPoints: Int64(max(0, userAvailablePoints)), usePoints: usePoints && pointsUsableForProduct,
            rateMicroYuan: MoneyPricing.defaultRateMicroYuan,
            maxPerOrderMinor: fen(maxPointsDeductPerOrderYuan))
        let price = RegistrationCoreLoopRules.ComputedOrderPrice(
            orderTotalYuan: yuan(b.originalMinor), memberDiscountYuan: yuan(b.memberDiscountMinor),
            couponDeductYuan: 0, pointsDeductYuan: yuan(b.pointDeductMinor), pointsUsed: Int(b.pointUsed),
            payAmount: yuan(b.payableMinor))
        return Output(price: price, breakdown: b)
    }
}

/// Date-based entry to `MoneyRefundPolicy.evaluate` (the rule itself takes epoch ms).
public enum MoneyRefundPolicyAdapter {
    static func ms(_ date: Date?) -> Int64? { date.map { Int64(($0.timeIntervalSince1970 * 1000).rounded(.down)) } }

    public static func evaluate(ownerType: Int?, paymentStatus: Int?, verificationStatus: Int?, ticketMode: Int?,
                                purchaseKind: Int?, ticketStart: Date?, ticketEnd: Date?, activityStart: Date?,
                                snapshotDeadline: Date?, payableMinor: Int64?, pointUsed: Int64?,
                                now: Date?) -> MoneyRefundPolicy.Verdict {
        MoneyRefundPolicy.evaluate(
            ownerType: ownerType, paymentStatus: paymentStatus, verificationStatus: verificationStatus,
            ticketMode: ticketMode, ticketStartMs: ms(ticketStart), ticketEndMs: ms(ticketEnd),
            activityStartMs: ms(activityStart), snapshotDeadlineMs: ms(snapshotDeadline), payableMinor: payableMinor,
            pointUsed: pointUsed, nowMs: ms(now), purchaseKind: purchaseKind)
    }
}
