import Foundation

/// MP `pages/coop/nearby/index.js` `stationTermsText` (owner 2026-10-31: every station has one terms tier, and the
/// invitation states that tier and its condition). Read only; shown after the chapter name in 可承接 · ….
/// - TRAFFIC → (引流档 · 到店打卡)
/// - REVSHARE → (计酬档 · 俱乐部付 ≤ ¥X / 人次), a missing fee reads ¥0 as in the MP (`Number(x) || 0`)
/// - PERK → (权益档 · ≥ ¥X 权益) when the threshold is above 0, else (权益档)
/// - any other / missing mode → no suffix
/// Amounts use the shared `MoneyDisplay` rule (owner 11-24: ¥12.50 everywhere).
public enum CoopNearbyStationTerms: Equatable, Sendable {
    case traffic
    case revshare(maxPerHeadFee: Decimal)
    case perk(minValue: Decimal?)

    public init?(mode: String?, maxPerHeadFee: MerchantContentValue, perkMinValue: MerchantContentValue) {
        switch mode {
        case "TRAFFIC": self = .traffic
        case "REVSHARE": self = .revshare(maxPerHeadFee: Self.amount(maxPerHeadFee) ?? 0)
        case "PERK":
            if let value = Self.amount(perkMinValue), value > 0 { self = .perk(minValue: value) } else { self = .perk(minValue: nil) }
        default: return nil
        }
    }

    public init?(row: MerchantContentValue) {
        self.init(mode: row["termsMode"].text, maxPerHeadFee: row["maxPerHeadFee"], perkMinValue: row["perkMinValue"])
    }

    public func text(chinese: Bool) -> String {
        switch self {
        case .traffic:
            return chinese ? "(引流档 · 到店打卡)" : " (traffic tier · in-store check-in)"
        case .revshare(let fee):
            let money = MoneyDisplay.yuan(fee < 0 ? 0 : fee)
            return chinese ? "(计酬档 · 俱乐部付 ≤ \(money) / 人次)" : " (paid tier · club pays up to \(money) per visit)"
        case .perk(let minValue):
            guard let minValue else { return chinese ? "(权益档)" : " (perk tier)" }
            let money = MoneyDisplay.yuan(minValue)
            return chinese ? "(权益档 · ≥ \(money) 权益)" : " (perk tier · perks worth \(money) or more)"
        }
    }

    /// Chapter name plus the terms suffix (MP `r.chapterName + stationTermsText(r)`).
    public static func label(chapter: String, terms: CoopNearbyStationTerms?, chinese: Bool) -> String {
        guard let terms else { return chapter }
        return chapter + terms.text(chinese: chinese)
    }

    static func amount(_ value: MerchantContentValue) -> Decimal? {
        switch value {
        case .integer(let v): return Decimal(v)
        case .decimal(let v): return v
        case .string(let v):
            let trimmed = v.trimmingCharacters(in: .whitespaces)
            guard trimmed.range(of: #"^-?[0-9]+(\.[0-9]+)?$"#, options: .regularExpression) != nil else { return nil }
            return Decimal(string: trimmed)
        default: return nil
        }
    }
}
