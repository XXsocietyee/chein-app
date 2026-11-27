import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// City Monopoly kit tokens (Figma Library `City/*`, `Map/*`, `Moment/*`; skill-r2 SR2-31…33, SR2-49).
// Owner defaults: "mine" is WHITE on the map (Q1); district colours appear only on the deed band,
// the map cells and the district chip (Q11); status is a badge shape, never a hue on the map.

enum CityTokens {
    /// District band colours `district/1…6` (the dark-mode values of the Figma `District` collection).
    /// Band labels sit on them in near-black ink (`ink-inv`), 5.6–8.6:1.
    static func district(_ index: Int) -> Color { CYCityPalette.district(index) }

    /// Ink on a district band (`ink-inv`).
    static let bandInk = CYCityPalette.bandInk
    /// "You": the primary-button white (Q1).
    static let mine = CYCityPalette.mine
    /// The coin: the 积分 mark, the one warm accent in the kit.
    static let coin = CYCityPalette.coin
    static let gold = CYCityPalette.gold
    /// Fog over unlit ground: `bg` at 80 % with a 1 pt `sep` edge (SR2-31).
    static let fog = Color.black.opacity(0.8)
    static let fogEdge = Color.white.opacity(0.16)

    // Motion: aliases of the one token set in `CYMotion` (xrefs-1 B.0). Every row has a Reduce Motion fade of 200 ms.
    static let pressSpring = CYMotion.release
    static let sheetSpring = CYMotion.sheet
    static let deedSpring = CYMotion.moment
    static let sealSpring = CYMotion.seal
    static let heroSpring = CYMotion.hero
    static let reducedFade = CYMotion.reduced
    /// The property sheet's compact detent (Q3).
    static let propertyDetent: CGFloat = 420
}

/// zh / en copy for the City screens (verbatim, like the rest of the CITY surfaces).
struct CityCopy {
    let locale: Locale
    var chinese: Bool { ChannelCopy.isChinese(locale) }
    func callAsFunction(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    func points(_ value: Int64) -> String { CityMonopolyFormat.points(value, chinese: chinese) }
    func level(_ level: Int) -> String { "\(CityMonopolyLevel.name(level, chinese: chinese)) Lv\(level)" }
    func tier(_ tier: CityMonopolyTier?) -> String? { tier.map { $0.name(chinese: chinese) } }

    /// The server's district name (fix/city-gaps-r3, live on TEST). District names are public board metadata, so fogged
    /// tiles show them too. Without a real name: "街区 1" by colour slot.
    func district(_ place: CityPlace) -> String? {
        if let name = place.districtName { return name }
        guard place.districtIndex > 0 else { return nil }
        return chinese ? "街区 \(place.districtIndex)" : "District \(place.districtIndex)"
    }

    /// i18n r1: Chinese keeps `850 m` / `1.2 公里`; other languages follow the locale's road unit (`0.5 mi`).
    func distance(_ metres: Double?) -> String? {
        guard let metres, metres.isFinite else { return nil }
        guard chinese else { return LocaleDisplay.distance(meters: metres, locale: locale) }
        if metres < 1000 { return "\(Int(metres.rounded())) m" }
        return String(format: "%.1f 公里", metres / 1000)
    }

    func title(_ place: CityPlace) -> String {
        if place.ownership == .fogged { return self("未点亮的地点", "Unlit place") }
        return place.title ?? self("城市地产", "City place")
    }

    /// "今天 21:30" / "明天 14:20" in Asia/Shanghai.
    func clock(_ date: Date, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        // i18n r1: Chinese keeps `HH:mm` / `M月d日 HH:mm`; English uses the locale clock (`9:30 PM`, `Nov 27, 2:20 PM`).
        let time = LocaleDisplay.time(date, locale: locale, timeZone: calendar.timeZone)
        if calendar.isDate(date, inSameDayAs: now) { return self("今天 ", "today ") + time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return self("明天 ", "tomorrow ") + time
        }
        return LocaleDisplay.monthDayTime(date, locale: locale, timeZone: calendar.timeZone)
    }
}

/// The 积分 coin glyph (drawn, not the character 积 at 7 pt; SR2-41).
struct CityCoin: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle().fill(CityTokens.coin)
            Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
            Image(systemName: "sparkle").font(.system(.caption2, design: .rounded).weight(.black))
                .foregroundStyle(Color.black.opacity(0.55)).scaleEffect(0.8)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Status badge (shape + glyph + text; never colour alone). Warning is amber, error is red (SR2-45).
struct CityStatusTag: View {
    enum Tone { case neutral, warning, error, ok }
    let text: String
    var symbol: String? = nil
    var tone: Tone = .neutral
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).imageScale(.small).accessibilityHidden(true) }
            Text(verbatim: text).lineLimit(1)
        }
        .cyText(.caption, weight: .semibold)
        .foregroundStyle(foreground)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return palette.textSecondary
        case .warning: return palette.warning
        case .error: return palette.danger
        case .ok: return palette.success
        }
    }
    private var background: Color {
        switch tone {
        case .neutral: return palette.bgRaised
        case .warning: return palette.warningSoft
        case .error: return palette.dangerSoft
        case .ok: return palette.successSoft
        }
    }
}

/// District chip: the dot is the district colour, the text is ink (Q11).
struct CityDistrictChip: View {
    let index: Int
    let text: String
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(CityTokens.district(index)).frame(width: 7, height: 7).accessibilityHidden(true)
            Text(verbatim: text).lineLimit(1)
        }
        .cyText(.caption, weight: .medium)
        .foregroundStyle(palette.textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(palette.bgRaised, in: Capsule())
    }
}

/// A capsule fact chip used on moments and the challenge sheet (`Player/Chip` Kind=Info).
struct CityInfoChip: View {
    let text: String
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Text(verbatim: text)
            .cyText(.label)
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background(palette.bgRaised, in: Capsule())
    }
}

/// Glass circle control for map chrome (44 pt). Opaque under Reduce Transparency.
struct CityGlassCircle: View {
    let systemImage: String
    let label: String
    var badge: Int? = nil
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 44, height: 44)
                .background {
                    if reduceTransparency { Circle().fill(palette.bgElevated) } else { Circle().fill(.ultraThinMaterial) }
                }
                .overlay(Circle().strokeBorder(palette.borderStrong, lineWidth: 0.5))
                .overlay(alignment: .topTrailing) {
                    if let badge, badge > 0 {
                        Text(verbatim: String(badge)).cyText(.caption, weight: .bold).foregroundStyle(.white)
                            .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                            .background(palette.actionDangerBg, in: Capsule()).offset(x: 4, y: -4)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
    }
}

/// Plays one feedback when the view appears (moments land once).
private struct CityAppearFeedback: ViewModifier {
    let feedback: SensoryFeedback
    @State private var fired = false
    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: fired).onAppear { fired = true }
    }
}

extension View {
    func cityFeedbackOnAppear(_ feedback: SensoryFeedback) -> some View { modifier(CityAppearFeedback(feedback: feedback)) }
}
