import Foundation

/// i18n r1 (locale lane, 2026-11-27): the one presentation-only formatter for the China + US launch.
///
/// Rules:
/// - Server values never change here. Every function takes a value the app already holds and
///   returns display text for the given `Locale` (pass SwiftUI's `@Environment(\.locale)`).
/// - Chinese (`zh`) keeps the exact look the owner approved (`¥12.50`, `yyyy-MM-dd HH:mm`,
///   `1.2 公里`) so the CN launch does not move; every other language uses Apple's locale-aware
///   formatting (`¥12.50` for CNY / `$12.50` for USD, `Nov 27, 2026 at 3:05 PM`, `0.7 mi`).
/// - Currency always comes from the order or price (`currencyCode`), never from the device locale.
///   CNY is the default only because the current wire contracts carry no currency field.
/// - Distance follows the locale's measurement system for road usage: miles/feet in the US, km/m in CN.
public enum LocaleDisplay {
    /// Shared default for wire contracts without a currency field (see `MoneyDisplay`).
    public static let defaultCurrencyCode = "CNY"

    public static func isChinese(_ locale: Locale) -> Bool {
        if let code = locale.language.languageCode?.identifier { return code == "zh" }
        return locale.identifier.lowercased().hasPrefix("zh")
    }

    // MARK: Money

    /// `¥12.50` for CNY and `$12.50` for USD in every locale (US r2: the order's currency, not the locale, picks the symbol). Always two fraction digits (owner 2026-11-24).
    public static func money(_ amount: Decimal, currencyCode: String? = nil, locale: Locale) -> String {
        let code = normalizedCurrency(currencyCode)
        if isChinese(locale), code == "CNY" { return MoneyDisplay.yuan(amount) }
        var rounded = Decimal(), value = amount
        NSDecimalRound(&rounded, &value, 2, .plain)
        // US r2: the currency's own narrow symbol (`¥` for CNY, `$` for USD) in every locale; never re-labelled by locale.
        let style = Decimal.FormatStyle.Currency(code: code, locale: locale).presentation(.narrow).precision(.fractionLength(2))
        return style.format(rounded)
    }

    /// Integer minor units (fen / cents). A negative amount keeps its sign (`-¥2.55`).
    public static func money(fen: Int, currencyCode: String? = nil, locale: Locale) -> String {
        let code = normalizedCurrency(currencyCode)
        if isChinese(locale), code == "CNY" { return MoneyDisplay.yuan(fen: fen) }
        let amount = Decimal(fen) / Decimal(100)
        return money(amount, currencyCode: code, locale: locale)
    }

    /// Finance rows that print the sign themselves with U+2212 (`−¥2.55`); `amount` is shown as its magnitude.
    public static func money(_ amount: Decimal, negative: Bool, currencyCode: String? = nil, locale: Locale) -> String {
        let magnitude = amount < 0 ? -amount : amount
        if isChinese(locale), normalizedCurrency(currencyCode) == "CNY" {
            return (negative ? "−¥" : "¥") + CoopMoneyPlain.text(magnitude)
        }
        return (negative ? "−" : "") + money(magnitude, currencyCode: currencyCode, locale: locale)
    }

    /// Server decimal text (`"12.5"`). Chinese keeps `MoneyDisplay.text`'s lexical path (no rounding);
    /// other languages parse with a POSIX locale and format; anything unparsable is shown as given.
    public static func money(text raw: String, currencyCode: String? = nil, locale: Locale) -> String {
        let code = normalizedCurrency(currencyCode)
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil else { return raw }
        if isChinese(locale), code == "CNY" { return "¥" + MoneyDisplay.text(trimmed) }
        guard let value = Decimal(string: trimmed, locale: posix) else { return raw }
        return money(value, currencyCode: code, locale: locale)
    }

    /// Only the currency symbol for the locale (`¥` in Chinese, `CN¥` / `$` elsewhere), for inputs whose
    /// prefix sits outside the text field.
    public static func currencySymbol(currencyCode: String? = nil, locale: Locale) -> String {
        let code = normalizedCurrency(currencyCode)
        if isChinese(locale), code == "CNY" { return "¥" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency; formatter.locale = locale; formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    /// i18n r2: re-labels each `¥<amount>` inside text a Core/MP formatter already built (`首发价 ¥9.9`,
    /// `Fixed fee · ¥30 per check-in`, `¥1.20（6%）`). Chinese is returned unchanged; other languages get
    /// the CNY amount through `money(text:)` (`CN¥9.90`). A `¥` right after a letter (`CN¥`) is left alone,
    /// so already-formatted text is never re-labelled twice.
    public static func yuanAmounts(in text: String, locale: Locale) -> String {
        guard !isChinese(locale), text.contains("¥") else { return text }
        guard let expression = try? NSRegularExpression(pattern: "(?<![A-Za-z])¥\\s?([0-9]+(?:\\.[0-9]+)?)") else { return text }
        let source = text as NSString
        let output = NSMutableString(string: text)
        let matches = expression.matches(in: text, range: NSRange(location: 0, length: source.length))
        for match in matches.reversed() {
            let digits = source.substring(with: match.range(at: 1))
            output.replaceCharacters(in: match.range, with: money(text: digits, currencyCode: "CNY", locale: locale))
        }
        return output as String
    }

    static func normalizedCurrency(_ code: String?) -> String {
        let value = (code ?? "").trimmingCharacters(in: .whitespaces).uppercased()
        if value.isEmpty || value == "RMB" { return defaultCurrencyCode }
        return value
    }

    // MARK: Numbers

    /// Grouped integer (`12,480` / `12,480`), locale digits and separators.
    public static func number(_ value: Int, locale: Locale) -> String {
        IntegerFormatStyle<Int>(locale: locale).format(value)
    }

    public static func number(_ value: Double, fractionDigits: ClosedRange<Int> = 0...2, locale: Locale) -> String {
        FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(fractionDigits)).format(value)
    }

    /// `fraction` is 0...1 (`0.125` -> `12.5%`).
    public static func percent(_ fraction: Double, fractionDigits: ClosedRange<Int> = 0...1, locale: Locale) -> String {
        FloatingPointFormatStyle<Double>.Percent(locale: locale).precision(.fractionLength(fractionDigits)).format(fraction)
    }

    // MARK: Dates and times

    /// Chinese keeps `zhPattern` exactly (for example `yyyy-MM-dd HH:mm`); other languages use the
    /// localized form of `template` (`yMMMdjmm` -> `Nov 27, 2026, 3:05 PM`). `timeZone` nil = device zone.
    public static func date(_ date: Date, zhPattern: String, template: String, locale: Locale, timeZone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        if let timeZone { formatter.timeZone = timeZone }
        if isChinese(locale) {
            formatter.locale = Locale(identifier: "zh_Hans_CN")
            formatter.dateFormat = zhPattern
        } else {
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate(template)
        }
        return formatter.string(from: date)
    }

    /// Calendar day: `2026-11-27` (zh) / `Nov 27, 2026` (en).
    public static func day(_ value: Date, locale: Locale, timeZone: TimeZone? = nil) -> String {
        date(value, zhPattern: "yyyy-MM-dd", template: "yMMMd", locale: locale, timeZone: timeZone)
    }

    /// Day and time: `2026-11-27 15:05` (zh) / `Nov 27, 2026, 3:05 PM` (en).
    public static func dayTime(_ value: Date, locale: Locale, timeZone: TimeZone? = nil) -> String {
        date(value, zhPattern: "yyyy-MM-dd HH:mm", template: "yMMMdjmm", locale: locale, timeZone: timeZone)
    }

    /// Month and day with time, no year: `11月27日 15:05` (zh) / `Nov 27, 3:05 PM` (en).
    public static func monthDayTime(_ value: Date, locale: Locale, timeZone: TimeZone? = nil) -> String {
        date(value, zhPattern: "M月d日 HH:mm", template: "MMMdjmm", locale: locale, timeZone: timeZone)
    }

    /// Month and day, no year: `11月27日` (zh) / `Nov 27` (en).
    public static func monthDay(_ value: Date, locale: Locale, timeZone: TimeZone? = nil) -> String {
        date(value, zhPattern: "M月d日", template: "MMMd", locale: locale, timeZone: timeZone)
    }

    /// Server wall-clock parts (no zone) printed with `monthDay` / `monthDayTime` in one fixed zone, never shifted.
    /// nil when the parts are not a real calendar date.
    public static func monthDay(month: Int, day: Int, year: Int = 2000, hour: Int? = nil, minute: Int? = nil, locale: Locale) -> String? {
        let utc = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let parts = DateComponents(year: year, month: month, day: day, hour: hour ?? 0, minute: minute ?? 0)
        guard parts.isValidDate(in: calendar), let value = calendar.date(from: parts) else { return nil }
        if hour == nil { return monthDay(value, locale: locale, timeZone: utc) }
        return monthDayTime(value, locale: locale, timeZone: utc)
    }

    /// Clock time: `15:05` (zh) / `3:05 PM` (en-US) / `15:05` (en-GB).
    public static func time(_ value: Date, locale: Locale, timeZone: TimeZone? = nil) -> String {
        date(value, zhPattern: "HH:mm", template: "jmm", locale: locale, timeZone: timeZone)
    }

    /// Month: `2026-11` (zh) / `Nov 2026` (en).
    public static func month(_ value: Date, locale: Locale, timeZone: TimeZone? = nil) -> String {
        date(value, zhPattern: "yyyy-MM", template: "yMMM", locale: locale, timeZone: timeZone)
    }

    /// Re-renders server civil text (`yyyy-MM-dd[ HH:mm[:ss]]`) for the locale. The server text is the
    /// wall time it means, so it is parsed and printed in one fixed zone and never shifted. Chinese
    /// and any unparsable text return the input unchanged, except that Chinese drops server seconds
    /// (`2026-11-06 18:20:00` -> `2026-11-06 18:20`, the `dayTime` shape; the MP never shows seconds).
    public static func civil(_ raw: String, locale: Locale) -> String {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return raw }
        let utc = TimeZone(secondsFromGMT: 0)!
        if isChinese(locale) { return civilChineseMinutes(text, raw: raw, zone: utc) }
        let shapes: [(String, String)] = [
            ("yyyy-MM-dd HH:mm:ss", "yMMMdjmm"), ("yyyy-MM-dd'T'HH:mm:ss", "yMMMdjmm"), ("yyyy-MM-dd HH:mm", "yMMMdjmm"), ("yyyy-MM-dd'T'HH:mm", "yMMMdjmm"), ("yyyy/MM/dd HH:mm", "yMMMdjmm"),
            ("yyyy-MM-dd", "yMMMd"), ("yyyy/MM/dd", "yMMMd"), ("yyyy.MM.dd", "yMMMd"), ("yyyy-MM", "yMMM"),
        ]
        for (pattern, template) in shapes {
            let parser = DateFormatter()
            parser.calendar = Calendar(identifier: .gregorian); parser.locale = posix
            parser.timeZone = utc; parser.dateFormat = pattern; parser.isLenient = false
            guard let parsed = parser.date(from: text), parser.string(from: parsed) == text else { continue }
            return date(parsed, zhPattern: pattern, template: template, locale: locale, timeZone: utc)
        }
        return raw
    }

    /// Chinese civil text with seconds re-rendered at minute precision; everything else unchanged.
    static func civilChineseMinutes(_ text: String, raw: String, zone: TimeZone) -> String {
        let patterns: [String] = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"]
        for pattern in patterns {
            let parser = DateFormatter()
            parser.calendar = Calendar(identifier: .gregorian); parser.locale = posix
            parser.timeZone = zone; parser.dateFormat = pattern; parser.isLenient = false
            guard let parsed = parser.date(from: text), parser.string(from: parsed) == text else { continue }
            return date(parsed, zhPattern: "yyyy-MM-dd HH:mm", template: "yMMMdjmm", locale: Locale(identifier: "zh_Hans_CN"), timeZone: zone)
        }
        return raw
    }

    /// `in 3 hours` / `3小时后`, `yesterday` / `昨天`.
    public static func relative(_ value: Date, to reference: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(for: value, relativeTo: reference)
    }

    /// `1 hr 5 min` / `1小时5分钟`. Negative or non-finite input returns nil.
    public static func duration(seconds: Double, allowsSeconds: Bool = false, locale: Locale) -> String? {
        guard seconds.isFinite, seconds >= 0 else { return nil }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = allowsSeconds ? [.hour, .minute, .second] : [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        if seconds < 60, !allowsSeconds { formatter.allowedUnits = [.minute]; formatter.zeroFormattingBehavior = .pad }
        return formatter.string(from: seconds)
    }

    // MARK: Distance

    /// Road distance in the locale's system: `850 m` / `1.2 km` (CN), `0.5 mi` / `500 ft` (US).
    public static func distance(meters: Double, locale: Locale) -> String? {
        guard meters.isFinite, meters >= 0 else { return nil }
        let number = FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(0...1))
        let style = Measurement<UnitLength>.FormatStyle(width: .abbreviated, locale: locale, usage: .road, numberFormatStyle: number)
        return style.format(Measurement(value: meters, unit: UnitLength.meters))
    }

    /// i18n r2: argument for a catalog value that no longer spells its unit (`距你 %@` / `%@ away`).
    /// Chinese gets `zhText`, exactly the number and unit the old key printed, so the CN look is
    /// byte-identical; other languages get `distance(meters:)` (`0.7 mi`, `500 ft`, `1.2 km`).
    public static func distanceArgument(meters: Double, zhText: String, locale: Locale) -> String {
        if isChinese(locale) { return zhText }
        return distance(meters: meters, locale: locale) ?? zhText
    }

    /// True where road distances read in miles (US English). Chinese always reads kilometres.
    public static func usesMiles(_ locale: Locale) -> Bool {
        !isChinese(locale) && locale.measurementSystem != .metric
    }

    /// Kilometres converted to the number that sits beside the locale's unit label (`km` or `mi`).
    public static func roadNumber(kilometers: Double, locale: Locale) -> Double {
        usesMiles(locale) ? kilometers / 1.609344 : kilometers
    }

    /// Kilometres the server sent (for example a walked total) in the locale's road unit.
    public static func distance(kilometers: Double, locale: Locale) -> String? {
        distance(meters: kilometers * 1000, locale: locale)
    }

    /// Search/filter radius: always a whole number in the locale's large road unit (`3 km` / `2 mi`).
    public static func radius(meters: Double, locale: Locale) -> String? {
        guard meters.isFinite, meters >= 0 else { return nil }
        let number = FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(0...1))
        let style = Measurement<UnitLength>.FormatStyle(width: .abbreviated, locale: locale, usage: .asProvided, numberFormatStyle: number)
        let usesMetric = locale.measurementSystem == .metric
        let measure = Measurement(value: meters, unit: UnitLength.meters).converted(to: usesMetric ? .kilometers : .miles)
        return style.format(measure)
    }

    /// Speed (`12 km/h` / `7.5 mph`).
    public static func speed(metersPerSecond: Double, locale: Locale) -> String? {
        guard metersPerSecond.isFinite, metersPerSecond >= 0 else { return nil }
        let number = FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(0...1))
        let style = Measurement<UnitSpeed>.FormatStyle(width: .abbreviated, locale: locale, usage: .general, numberFormatStyle: number)
        return style.format(Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond))
    }

    // MARK: Lists and names

    /// `A, B, and C` (en) / `A、B和C` (zh). Empty items are dropped.
    public static func list(_ items: [String], locale: Locale) -> String {
        let values = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: values) ?? values.joined(separator: ", ")
    }

    /// Family-first for Chinese, given-first for English. A Chinese name typed as one string is shown as given.
    public static func personName(given: String?, family: String?, locale: Locale) -> String {
        var components = PersonNameComponents()
        components.givenName = given?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        components.familyName = family?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        return PersonNameComponents.FormatStyle(style: .medium, locale: locale).format(components)
    }

    // MARK: Addresses

    /// Joins address parts in the locale's reading order. Chinese reads large-to-small with no separator
    /// (`上海市黄浦区南京东路1号`); English reads small-to-large with commas (`1 Nanjing Rd E, Huangpu, Shanghai`).
    /// `parts` are given large-to-small (province, city, district, street) as the server sends them.
    public static func address(_ parts: [String?], locale: Locale) -> String {
        let values = parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var deduped: [String] = []
        for value in values where deduped.last != value { deduped.append(value) }
        return isChinese(locale) ? deduped.joined() : deduped.reversed().joined(separator: ", ")
    }

    static let posix = Locale(identifier: "en_US_POSIX")
}

/// Two fixed decimals, no grouping, POSIX digits (the cooperation finance look: `1234.50`).
enum CoopMoneyPlain {
    static func text(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? MoneyDisplay.plain(amount)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// i18n r1: phone sign-in country codes for the CN + US launch. The national number the person types is
/// presentation; `wireValue` is what goes to the server. China keeps the bare 11-digit mobile number the
/// current API takes (unchanged); the US sends E.164 (`+1XXXXXXXXXX`) for the US login method once configured.
public enum PhoneCountryCode: String, CaseIterable, Identifiable, Sendable {
    case china = "CN"
    case unitedStates = "US"

    public var id: String { rawValue }
    /// `+86` / `+1`.
    public var dialCode: String { self == .china ? "+86" : "+1" }
    public var nationalDigits: Int { self == .china ? 11 : 10 }
    /// Regional-indicator flag for the picker row.
    public var flag: String { self == .china ? "🇨🇳" : "🇺🇸" }
    /// Catalog key for the country name in the picker.
    public var nameKey: String { self == .china ? "auth.phone.country.cn" : "auth.phone.country.us" }

    /// Market default: the US build starts on +1, everything else on +86.
    public static func `default`(marketCode: String?) -> PhoneCountryCode {
        (marketCode ?? "").uppercased() == "US" ? .unitedStates : .china
    }

    /// US launch r1: the picker default. The device region wins when it is US or CN (`Locale.current.region`);
    /// any other region falls back to the storefront market.
    public static func `default`(region: String?, marketCode: String?) -> PhoneCountryCode {
        switch (region ?? "").uppercased() {
        case "US": return .unitedStates
        case "CN": return .china
        default: return .default(marketCode: marketCode)
        }
    }

    /// Field text while typing: the US groups as `(555) 123-4567`; China keeps the bare digits it always showed.
    public func fieldText(_ raw: String) -> String {
        let digits = sanitize(raw)
        return self == .unitedStates ? display(digits) : digits
    }

    /// Draft value for a form that stores the server string (register, participants). China keeps the bare
    /// digits; the US stores `+1` and the digits typed so far. No digits stays empty.
    public func draftWire(_ raw: String) -> String {
        let digits = sanitize(raw)
        guard !digits.isEmpty else { return "" }
        return self == .china ? digits : dialCode + digits
    }

    /// Splits a stored server value: `+1…` is a US number, anything else is the China bare-digit form.
    public static func split(wire: String) -> (country: PhoneCountryCode, national: String) {
        let trimmed = wire.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+1") { return (.unitedStates, unitedStates.sanitize(String(trimmed.dropFirst(2)))) }
        if trimmed.hasPrefix("+86") { return (.china, china.sanitize(String(trimmed.dropFirst(3)))) }
        return (.china, trimmed)
    }

    /// True for a complete E.164 US number (`+1` and a valid 10-digit NANP number).
    public static func isValidUnitedStatesWire(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+1") else { return false }
        return unitedStates.isValid(String(trimmed.dropFirst(2)))
    }

    /// Keeps ASCII digits only, capped at the national length (a pasted leading `1` / `86` country code is dropped).
    public func sanitize(_ raw: String) -> String {
        var digits = raw.filter { $0.isASCII && $0.isNumber }
        if self == .unitedStates, digits.count == 11, digits.hasPrefix("1") { digits.removeFirst() }
        if self == .china, digits.count == 13, digits.hasPrefix("86") { digits.removeFirst(2) }
        return String(digits.prefix(nationalDigits))
    }

    public func isValid(_ national: String) -> Bool {
        let digits = Array(national.utf8)
        guard digits.count == nationalDigits, digits.allSatisfy({ (48...57).contains($0) }) else { return false }
        switch self {
        case .china: return digits[0] == 49 // leading 1
        case .unitedStates: return digits[0] >= 50 && digits[3] >= 50 // NANP: area and exchange start 2-9
        }
    }

    /// Server value. nil when the number is not valid for this country.
    public func wireValue(_ national: String) -> String? {
        guard isValid(national) else { return nil }
        return self == .china ? national : dialCode + national
    }

    /// Grouped for reading: `138 0013 8000` / `(415) 555-0132`. Partial input is grouped as far as it goes.
    public func display(_ national: String) -> String {
        let d = Array(national)
        switch self {
        case .china:
            guard d.count > 3 else { return national }
            let head = String(d[0..<3]), mid = String(d[3..<min(7, d.count)])
            return d.count > 7 ? head + " " + mid + " " + String(d[7...]) : head + " " + mid
        case .unitedStates:
            guard d.count > 3 else { return national }
            let area = "(" + String(d[0..<3]) + ") "
            guard d.count > 6 else { return area + String(d[3...]) }
            return area + String(d[3..<6]) + "-" + String(d[6...])
        }
    }
}
