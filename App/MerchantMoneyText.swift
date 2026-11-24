import Foundation

/// Owner decision #9 (2026-11-24): money shows two decimals with the yuan sign (¥12.50), through the one shared
/// switch `MoneyDisplay` (Core/RegistrationUIForm.swift). Server text is reformatted lexically (no rounding drift).
/// Non-CNY amounts keep the currency code, as before.
extension MerchantBusinessMoney {
    var yuanDisplay: String {
        guard let raw else { return "—" }
        guard currency == "CNY" else { return display }
        let negative = raw.hasPrefix("-")
        let digits = negative || raw.hasPrefix("+") ? String(raw.dropFirst()) : raw
        return (negative ? "-¥" : "¥") + MoneyDisplay.text(digits)
    }
}
