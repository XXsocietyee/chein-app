import SwiftUI

/// Poster hero for the activity detail: cover, title over a scrim, status + price chips. Covers are full-bleed.
struct E1ActivityHero: View {
    let summary: ActivitySummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        Color.clear
            .aspectRatio(dynamicTypeSize.isAccessibilitySize ? 1.0 : 1.18, contentMode: .fit)
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
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("activity.detail.name")
                }
                .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.lg).padding(.top, dynamicTypeSize.isAccessibilitySize ? CYSpacing.lg : 72)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.82), location: 1)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
            .accessibilityElement(children: .contain)
    }
}

/// When / where / category / registered as icon rows in one card (replaces the label-value list).
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

    var body: some View {
        let facts = ActivityDetailHeaderFacts(detail: detail)
        VStack(spacing: 0) {
            row("calendar", copy.t("时间", "When"), whenText ?? "—")
            divider
            row("mappin.and.ellipse", copy.t("集合点", "Meeting point"), placeText(facts)).accessibilityIdentifier("activity.detail.meetingPoint")
            if let category = facts.categoryText {
                divider
                row("tag", copy.t("分类", "Category"), category).accessibilityIdentifier("activity.detail.category")
            }
            divider
            row("person.2", copy.t("已报名", "Registered"), facts.registrationCount.map { copy.t("\($0) 人", "\($0) going") } ?? "—")
                .accessibilityIdentifier("activity.detail.registeredCount")
        }
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
    }

    private func placeText(_ facts: ActivityDetailHeaderFacts) -> String {
        switch facts.meetingPoint {
        case .named(let p): return p
        case .mapOnly: return copy.t("见下方地图", "See map below")
        case .unconfirmed: return "—"
        }
    }
    private var divider: some View { Divider().overlay(palette.borderSubtle).padding(.leading, 52) }
    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                Text(verbatim: value).font(CYTypography.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
