import SwiftUI

// MC8-11-1 … MC8-11-5, MC8-11-7, MC8-11-8 (pages/merchant/marketing/ai-insight/index.wxml:19-70,131-143,252-272,
// index.js:428-520,636-650, pages/merchant/utils/grow-tips.js): the 店铺参谋 page header and main card, built from the
// insight read the page already makes (`insight.metadata` keeps the whole response: `profile`, `trends`, `facts`).
// Nothing here reads or writes on its own; switching 近7/30/90天 or 到店/打卡/核销 only re-draws, as in the MP.

/// MC8-11-1: 早上好，店名 + the store logo (MP `_syncGreeting`, `profile.storeName` / `profile.logo`).
struct MerchantInsightGreeting: View {
    let profile: MerchantMarketingValue
    var now: Date = Date()

    private var storeName: String { (profile["storeName"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    private var logoURL: URL? {
        guard let raw = profile["logo"].text, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
    /// MP greetWord by China-time hour: <5 晚上好, <11 早上好, <13 中午好, <18 下午好, else 晚上好.
    private var greetingKey: LocalizedStringKey {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let hour = calendar.component(.hour, from: now)
        if hour < 5 { return "merchantInsight.greet.evening" }
        if hour < 11 { return "merchantInsight.greet.morning" }
        if hour < 13 { return "merchantInsight.greet.noon" }
        if hour < 18 { return "merchantInsight.greet.afternoon" }
        return "merchantInsight.greet.evening"
    }

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(greetingKey).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                if !storeName.isEmpty {
                    Text(verbatim: storeName).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                }
            }
            Spacer(minLength: 0)
            CYAvatarView(url: logoURL, name: storeName.isEmpty ? "城" : storeName, size: .lg)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("merchant.insight.greeting")
    }
}

/// The three MP trend metrics (`TREND_METRICS`).
enum MerchantInsightTrendMetric: String, CaseIterable, Identifiable {
    case visitors, checkins, redeems
    var id: String { rawValue }
    var labelKey: LocalizedStringKey { LocalizedStringKey("merchantInsight.metric." + rawValue) }
    var unitKey: String { "merchantInsight.unit." + rawValue }
    var shortKey: String { "merchantInsight.short." + rawValue }
    var prevKey: String { "prev" + rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// MP `_indexTrends` + `_buildHero`: windows 7/30/90 from `trends.windows` (all three, each with a full `daily`), else
/// the 30-day attribution numbers with an all-lightest 30-cell grid and no window switch.
struct MerchantInsightHero: Equatable {
    static let windows = [7, 30, 90]
    struct Cell: Equatable { let level: Int; let label: String }
    struct TrioItem: Equatable { let metric: MerchantInsightTrendMetric; let value: Int }

    let hasTrend: Bool
    let windowDays: Int
    let windowText: String?
    let value: Int
    let deltaPercent: Int?
    let previous: Int?
    let cells: [Cell]
    let columns: Int
    let axisFrom: String
    let trio: [TrioItem]

    static func indexedTrends(_ trends: MerchantMarketingValue) -> [Int: MerchantMarketingValue]? {
        var out: [Int: MerchantMarketingValue] = [:]
        for window in trends["windows"].array ?? [] {
            guard let days = window["days"].integer, windows.contains(days), let daily = window["daily"].array, daily.count == days else { continue }
            out[days] = window
        }
        return out.count == windows.count ? out : nil
    }

    init(facts: MerchantMarketingValue, trends: MerchantMarketingValue, window: Int, metric: MerchantInsightTrendMetric,
         now: Date = Date()) {
        let indexed = Self.indexedTrends(trends)
        let source = indexed?[window] ?? facts["attribution"]
        hasTrend = indexed != nil
        windowDays = window
        windowText = indexed != nil ? nil : facts["window"].text
        value = source[metric.rawValue].integer ?? 0
        previous = source[metric.prevKey].integer
        deltaPercent = source["changeRates"][metric.rawValue].decimal.map { Int(($0 * 100).rounded()) }
        if let daily = indexed?[window]?["daily"].array {
            let values = daily.map { max(0, $0[metric.rawValue].integer ?? 0) }
            let top = values.max() ?? 0
            cells = zip(daily, values).map { day, v in
                Cell(level: v <= 0 || top <= 0 ? 0 : min(3, Int((Double(v) / Double(top) * 3).rounded(.up))),
                     label: (day["date"].text ?? "") + " " + String(v))
            }
            columns = window == 7 ? 7 : 15
            axisFrom = daily.first?["date"].text ?? ""
        } else {
            cells = Array(repeating: Cell(level: 0, label: ""), count: 30)
            columns = 15
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
            let from = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            axisFrom = "\(calendar.component(.month, from: from))/\(calendar.component(.day, from: from))"
        }
        trio = MerchantInsightTrendMetric.allCases.map { TrioItem(metric: $0, value: source[$0.rawValue].integer ?? 0) }
    }
}

/// MC8-11-2 / -3 / -4 / -8: one hero number (selected metric) with 环比 and 上期, the 近7/30/90天 switch (only with
/// trends), the daily heat grid with its axis, and the 到店 · 打卡 · 核销 trio that selects the hero metric.
struct MerchantInsightHeroSection: View {
    let facts: MerchantMarketingValue
    let trends: MerchantMarketingValue
    @State private var window = 30
    @State private var metric: MerchantInsightTrendMetric = .visitors
    @Environment(\.locale) private var locale

    var body: some View {
        let hero = MerchantInsightHero(facts: facts, trends: trends, window: window, metric: metric)
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        if let text = hero.windowText {
                            Text("merchantInsight.hero.titleText \(text)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        } else {
                            Text("merchantInsight.hero.title \(hero.windowDays)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xxs) {
                            Text(verbatim: String(hero.value)).cyText(.display).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                            Text(verbatim: appLocalized(String.LocalizationValue(metric.unitKey), locale: locale))
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                        if let delta = hero.deltaPercent {
                            Group {
                                if delta == 0 { Text("merchantInsight.delta.flat") }
                                else { Text(verbatim: (delta > 0 ? "+" : "") + String(delta) + "%") }
                            }
                            .cyText(.meta).monospacedDigit()
                            .foregroundStyle(delta < 0 ? CYColor.warningText : CYColor.brandStrong)
                        }
                        if let previous = hero.previous {
                            Text(verbatim: appLocalized("merchantInsight.previous", locale: locale) + " " + String(previous)
                                 + appLocalized(String.LocalizationValue(metric.shortKey), locale: locale))
                                .cyText(.caption).foregroundStyle(CYColor.textTertiary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchant.insight.hero")
                if hero.hasTrend {
                    Picker("merchantInsight.window.label", selection: $window) {
                        ForEach(MerchantInsightHero.windows, id: \.self) { days in
                            Text("merchantInsight.window \(days)").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("merchant.insight.window")
                }
                MerchantInsightHeatGrid(cells: hero.cells, columns: hero.columns, axisFrom: hero.axisFrom)
                HStack(spacing: CYSpacing.xs) {
                    ForEach(hero.trio, id: \.metric) { item in
                        Button { metric = item.metric } label: {
                            VStack(spacing: CYSpacing.xxs) {
                                Text(item.metric.labelKey).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                                Text(verbatim: String(item.value)).cyText(.cardTitle).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                            }
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(item.metric == metric ? CYColor.brandSoft : CYColor.bgRaised))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("merchantInsight.metric.show \(appLocalized(String.LocalizationValue("merchantInsight.metric." + item.metric.rawValue), locale: locale))"))
                        .accessibilityValue(Text(verbatim: String(item.value)))
                        .accessibilityAddTraits(item.metric == metric ? .isSelected : [])
                        .accessibilityIdentifier("merchant.insight.metric.\(item.metric.rawValue)")
                    }
                }
            }
            .padding(.vertical, CYSpacing.xs)
        }
    }
}

/// The daily heat grid (decorative in the MP: `aria-hidden`), four levels, with 起始日 · 今天 under it.
struct MerchantInsightHeatGrid: View {
    let cells: [MerchantInsightHero.Cell]
    let columns: Int
    let axisFrom: String

    var body: some View {
        VStack(spacing: CYSpacing.xxs) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: max(columns, 1)), spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(CYColor.brand.opacity([0.10, 0.35, 0.65, 1.0][min(max(cell.level, 0), 3)]))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .accessibilityHidden(true)
            HStack {
                Text(verbatim: axisFrom)
                Spacer()
                Text("merchantInsight.axis.today")
            }
            .cyText(.caption).foregroundStyle(CYColor.textTertiary)
            .accessibilityHidden(true)
        }
        .accessibilityIdentifier("merchant.insight.heat")
    }
}

/// MC8-11-5: 客源主题 (MP `_buildSources`): rows with a name and count > 0, top five, bar width vs the first row,
/// share of the total.
struct MerchantInsightSourcesSection: View {
    struct Row: Identifiable, Equatable { let name: String; let count: Int; let width: Double; let percent: Int; var id: String { name } }
    let rows: [Row]
    let windowText: String?

    init(facts: MerchantMarketingValue) {
        let list = (facts["sources"].array ?? []).compactMap { row -> (String, Int)? in
            guard let name = row["name"].text, !name.isEmpty, let count = row["count"].integer, count > 0 else { return nil }
            return (name, count)
        }
        let total = list.reduce(0) { $0 + $1.1 }
        let top = list.first?.1 ?? 0
        rows = list.prefix(5).map { name, count in
            Row(name: name, count: count, width: top > 0 ? Double(count) / Double(top) : 0,
                percent: total > 0 ? Int((Double(count) / Double(total) * 100).rounded()) : 0)
        }
        windowText = facts["window"].text
    }

    var body: some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    HStack(spacing: CYSpacing.sm) {
                        Text(verbatim: String(row.name.trimmingCharacters(in: .whitespaces).prefix(1)))
                            .cyText(.cardTitle).foregroundStyle(CYColor.brandStrong)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(CYColor.brandSoft))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            HStack {
                                Text(verbatim: row.name).cyText(.body).foregroundStyle(CYColor.textPrimary)
                                Spacer()
                                Text("merchantInsight.sources.count \(row.count)").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(CYColor.bgRaised)
                                    Capsule().fill(CYColor.brand).frame(width: proxy.size.width * row.width)
                                }
                            }
                            .frame(height: 4)
                            .accessibilityHidden(true)
                            Text(verbatim: "\(row.percent)%").cyText(.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                HStack {
                    Text("merchantInsight.sources.title")
                    Spacer()
                    if let windowText { Text(verbatim: windowText) } else { Text("merchantInsight.window 30") }
                }
            }
            .accessibilityIdentifier("merchant.insight.sources")
        }
    }
}

/// MC8-11-7: 经营优化 (pages/merchant/utils/grow-tips.js): one card per action the current role can take. The app
/// has native destinations for 承接一条主题路线 (合作中心) and 发一张到店券 (优惠券) on this page; 把门店设成打卡点 and
/// AI 店铺角色 have no destination in the marketing environment yet, so they are not drawn (no dead entries, as the MP).
struct MerchantInsightGrowTipsSection: View {
    enum Tip: String, CaseIterable, Identifiable {
        case coop, coupon
        var id: String { rawValue }
    }
    let access: MerchantMarketingAccess?
    let canOpenCoop: Bool
    let canOpenCoupons: Bool
    let open: (Tip) -> Void

    private var tips: [Tip] {
        guard let access, access.active else { return [] }
        return Tip.allCases.filter { tip in
            switch tip {
            case .coop: return canOpenCoop
            case .coupon: return canOpenCoupons && access.permissions.contains(MerchantAccess.Permission.couponManage.rawValue)
            }
        }
    }

    var body: some View {
        let visible = tips
        if !visible.isEmpty {
            Section("merchantInsight.grow.title") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(visible) { tip in
                            Button { open(tip) } label: {
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    (tip == .coop ? MPAsset.BannerCover.oldMovie : MPAsset.BannerCover.midlifeDay).resizable().scaledToFill()
                                        .frame(width: 220, height: 110).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .accessibilityHidden(true)
                                    Text(LocalizedStringKey("merchantInsight.grow.\(tip.rawValue).title")).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                    Text(LocalizedStringKey("merchantInsight.grow.\(tip.rawValue).sub")).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    Text(LocalizedStringKey("merchantInsight.grow.\(tip.rawValue).cta")).cyText(.meta).foregroundStyle(CYColor.brandStrong)
                                }
                                .frame(width: 220, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("merchant.insight.grow.\(tip.rawValue)")
                        }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.md, bottom: 0, trailing: CYSpacing.md))
            }
        }
    }
}
