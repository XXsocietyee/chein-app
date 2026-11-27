import SwiftUI

enum E1ActivityAnchor: String, CaseIterable, Hashable {
    case overview
    case tickets
    case details
}

/// Poster hero for the activity detail (Template 4): full-bleed cover with bottom scrim,
/// experience category/status/price chips, bold title, and location/date summary.
struct E1ActivityHero: View {
    let summary: ActivitySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        Color.clear
            .aspectRatio(dynamicTypeSize.isAccessibilitySize ? 1.0 : 1.08, contentMode: .fit)
            .overlay {
                E1CoverArt(seed: summary.name, symbol: ["figure.walk", "music.note", "camera", "leaf", "building.2", "moon.stars", "map"][abs(summary.id) % 7],
                           imageURL: QuestifyCardArtwork.safeURL(summary.imageURL)?.absoluteString)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    // Accessibility sizes stack the chips so neither is squeezed or clipped over the photo.
                    let chipLayout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs)) : AnyLayout(HStackLayout(spacing: CYSpacing.xs))
                    chipLayout {
                        if let state = E1ActivityState.of(start: summary.startDate, end: summary.endDate) { state.chip(copy) }
                        if let a = summary.minimumAmount, a == 0 { CYStatusChip(verbatim: copy.t("免费", "Free"), tone: .success) }
                        else if let p = E1Money.yuan(summary.minimumAmount, locale: locale) { CYStatusChip(verbatim: copy.t("\(p) 起", "From \(p)")) }
                    }
                    Text(verbatim: ActivityPresentation.nonempty(summary.name) ?? "—")
                        .font(.system(dynamicTypeSize.isAccessibilitySize ? .title : .largeTitle, design: .default).weight(.bold))
                        .foregroundStyle(palette.onCoverFg)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("activity.detail.name")
                        .cyHeroTitleRise()
                    // Design pass explore P1/P2: the hero leads with the live time-to-start (or time left while it runs).
                    ExploreStartsInLine(startRaw: summary.startDate, endRaw: summary.endDate, tint: palette.onCoverFg)
                    if let place = ActivityPresentation.place(summary) {
                        Label {
                            Text(verbatim: place)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse").accessibilityHidden(true)
                        }
                        .cyText(.meta)
                        .foregroundStyle(palette.onCoverFgDim)
                    }
                }
                .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.lg).padding(.top, dynamicTypeSize.isAccessibilitySize ? CYSpacing.lg : 84)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.black.opacity(0.65), location: 0.45),
                            .init(color: Color.black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
            .accessibilityElement(children: .contain)
    }
}

/// Template 4 horizontal stats bar matching mini-program `statbar` with tabular metrics and hairline dividers.
struct E1ActivityStatsRow: View {
    let detail: ActivityDetail
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    private struct StatItem: Identifiable {
        let id: String
        let label: String
        let value: String
        let sub: String?
    }

    private var stats: [StatItem] {
        let facts = ActivityDetailHeaderFacts(detail: detail)
        let priceText: String = {
            if let amount = detail.summary.minimumAmount {
                if amount == 0 { return copy.t("免费", "Free") }
                if let p = E1Money.yuan(amount, locale: locale) { return p }
            }
            return "—"
        }()
        let durationText = Self.durationText(start: detail.summary.startDate, end: detail.summary.endDate, copy: copy)
        let regText = facts.registrationCount.map { String($0) } ?? "—"
        let placeText: String = {
            switch facts.meetingPoint {
            case .named(let p): return p
            case .mapOnly: return copy.t("见地图", "On map")
            case .unconfirmed: return "—"
            }
        }()
        return [
            StatItem(id: "type", label: copy.t("类型", "Type"), value: facts.categoryText ?? "—", sub: nil),
            StatItem(id: "where", label: copy.t("集合点", "Where"), value: placeText, sub: nil),
            StatItem(id: "duration", label: copy.t("时长", "Duration"), value: durationText, sub: QuestifyCardText.date(detail.summary.startDate, locale: locale, displayTimeZone: timeZone)),
            StatItem(id: "price", label: copy.t("起步价", "Price"), value: priceText, sub: nil),
            StatItem(id: "going", label: copy.t("已报名", "Going"), value: regText, sub: facts.registrationCount == nil ? nil : copy.t("人", "joined"))
        ]
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle()
                            .fill(palette.borderSubtle)
                            .frame(width: 0.5)
                            .padding(.vertical, CYSpacing.xs)
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(verbatim: item.label)
                            .cyText(.micro)
                            .foregroundStyle(palette.textTertiary)
                        Text(verbatim: item.value)
                            .cyText(.numericBody)
                            .monospacedDigit()
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(PageTemplateVoiceOver.spoken(item.value, locale: locale))
                        if let sub = item.sub {
                            Text(verbatim: sub)
                                .cyText(.micro)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 132 : 84, alignment: .leading)
                    .padding(.horizontal, CYSpacing.md)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("activity.detail.stat.\(item.id)")
                }
            }
            .padding(.vertical, CYSpacing.sm)
        }
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.xs)
        .accessibilityIdentifier("activity.detail.statBar")
    }

    private static func durationText(start: String?, end: String?, copy: CoreLoopCopy) -> String {
        let utc = TimeZone(secondsFromGMT: 0)!
        func parse(_ raw: String?) -> Date? { HomeFeedDate.parse(raw) ?? HomeFeedDate.parse(raw, sourceTimeZone: utc) }
        guard let sd = parse(start), let ed = parse(end), ed >= sd else { return "—" }
        let minutes = Int(ed.timeIntervalSince(sd) / 60)
        if minutes < 60 { return copy.t("\(minutes) 分钟", "\(minutes)m") }
        let hours = Double(minutes) / 60.0
        if minutes % 60 == 0 { return copy.t("\(minutes / 60) 小时", "\(minutes / 60)h") }
        return copy.t(String(format: "%.1f 小时", hours), String(format: "%.1fh", hours))
    }
}

/// Template 4 sticky underline tabs (`详情 / 票种 / 更多与评价`) built on shared `CYTabs`.
struct E1ActivitySectionTabs: View {
    let proxy: ScrollViewProxy
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var selection: E1ActivityAnchor = .overview
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        CYTabs(
            items: [
                CYTabItem(id: .overview, title: copy.t("详情", "Overview")),
                CYTabItem(id: .tickets, title: copy.t("票种", "Tickets")),
                CYTabItem(id: .details, title: copy.t("评价与更多", "Details"))
            ],
            selection: $selection,
            variant: .sticky
        )
        .accessibilityIdentifier("activity.detail.tabs")
        .onChange(of: selection) { _, anchor in
            withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) {
                proxy.scrollTo(anchor.rawValue, anchor: .top)
            }
        }
    }
}

/// Template 4 info card ordered strictly: what -> where -> how long/when -> price -> who it suits.
struct E1ActivityInfoCard: View {
    let detail: ActivityDetail
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.cyPalette) private var palette
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    private var whenText: String? {
        let s = QuestifyCardText.date(detail.summary.startDate, locale: locale, displayTimeZone: timeZone)
        var e = QuestifyCardText.date(detail.summary.endDate, locale: locale, displayTimeZone: timeZone)
        // Same calendar day: the end shows the time only.
        let utc = TimeZone(secondsFromGMT: 0)!
        func parse(_ raw: String?) -> Date? { HomeFeedDate.parse(raw) ?? HomeFeedDate.parse(raw, sourceTimeZone: utc) }
        let zone = HomeFeedDate.parse(detail.summary.endDate) == nil ? utc : timeZone
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        if let sd = parse(detail.summary.startDate), let ed = parse(detail.summary.endDate), cal.isDate(sd, inSameDayAs: ed) {
            var style = Date.FormatStyle.dateTime.hour().minute().locale(locale); style.timeZone = zone
            e = ed.formatted(style)
        }
        switch (s, e) {
        case let (s?, e?): return s == e ? s : s + " – " + e
        case let (s?, nil): return s
        case let (nil, e?): return e
        default: return nil
        }
    }

    private var priceSummaryText: String? {
        if let amount = detail.summary.minimumAmount {
            if amount == 0 { return copy.t("免费参与", "Free") }
            if let p = E1Money.yuan(amount, locale: locale) { return copy.t("\(p) 起", "From \(p)") }
        }
        return nil
    }

    var body: some View {
        let facts = ActivityDetailHeaderFacts(detail: detail)
        // PC-C-1-10 (hand-off PL-24): a row whose value is unknown is hidden, never printed as "—".
        let rows: [InfoRow] = [
            InfoRow(id: "activity.detail.category", icon: "tag", label: copy.t("体验类型", "Experience"), value: facts.categoryText),
            InfoRow(id: "activity.detail.meetingPoint", icon: "mappin.and.ellipse", label: copy.t("集合点", "Where"), value: placeText(facts)),
            InfoRow(id: "activity.detail.when", icon: "calendar", label: copy.t("时间与时长", "When"), value: whenText),
            InfoRow(id: "activity.detail.price", icon: "ticket", label: copy.t("费用", "Price"), value: priceSummaryText),
            InfoRow(id: "activity.detail.registeredCount", icon: "person.2", label: copy.t("适合与已报名", "Who & Joined"),
                    value: facts.registrationCount.map { copy.t("\($0) 人已报名", "\($0) going") }),
        ].filter { $0.value?.isEmpty == false }
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { divider }
                    row(item.icon, item.label, item.value ?? "").accessibilityIdentifier(item.id)
                }
            }
            .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
        }
    }
    private struct InfoRow { let id: String; let icon: String; let label: String; let value: String? }

    private func placeText(_ facts: ActivityDetailHeaderFacts) -> String? {
        switch facts.meetingPoint {
        case .named(let p): return p
        case .mapOnly: return copy.t("见下方地图", "See map below")
        case .unconfirmed: return nil
        }
    }
    private var divider: some View { Divider().overlay(palette.borderSubtle).padding(.leading, 52) }
    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label).cyText(.meta).foregroundStyle(palette.textTertiary)
                Text(verbatim: value)
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(PageTemplateVoiceOver.spoken(value, locale: locale))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
