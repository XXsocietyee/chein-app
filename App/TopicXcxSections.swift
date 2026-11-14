import SwiftUI

/// Mini-program `pages/topic/index` sections layered onto the existing topic detail list.
enum TopicXcxTab: Int, CaseIterable, Identifiable {
    case details, nodes, route
    var id: Int { rawValue }
    /// Free exploration names the third tab 地点; city orienteering keeps 路线.
    func titleKey(productType: Int) -> LocalizedStringKey {
        switch self {
        case .details: return "topicXcx.tab.details"
        case .nodes: return "topicXcx.tab.nodes"
        case .route: return productType == 2 ? "topicXcx.tab.places" : "topicXcx.tab.route"
        }
    }
    var anchor: String { "topicXcx.anchor.\(rawValue)" }
}

/// Mini-program 详情 / 故事 / 路线 sticky underline tabs using shared `CYTabs(.sticky)`;
/// jumps to each section cleanly so every row stays reachable. Free exploration uses 地点 for the third tab.
struct TopicXcxTabs: View {
    let proxy: ScrollViewProxy
    var productType: Int = 0
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var selection: TopicXcxTab = .details

    var body: some View {
        let items = TopicXcxTab.allCases.map { tab in
            CYTabItem(id: tab, title: appLocalized(tab.titleKey(productType: productType), locale: locale))
        }
        CYTabs(items: items, selection: $selection, variant: .sticky)
            .accessibilityIdentifier("topic.tabs")
            .onChange(of: selection) { _, tab in
                withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(tab.anchor, anchor: .top)
                }
            }
    }
}

struct TopicXcxHero: View {
    let topic: TopicDetail
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(topic.productType == 2 ? "topicXcx.type.explore" : "topicXcx.type.orienteering", tone: .info)
            if !topic.categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(topic.categoryNames, id: \.self) { name in
                            Text(verbatim: name)
                                .font(CYTypography.label)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, CYSpacing.sm)
                                .padding(.vertical, CYSpacing.xxs)
                                .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        }
                    }
                }
            }
            if let club = topic.clubName { Label { Text("topicXcx.clubHost \(club)") } icon: { Image(systemName: "person.3").accessibilityHidden(true) }.font(CYTypography.meta).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct TopicXcxStatBar: View {
    let cells: [TopicXcxFacts.StatCell]
    @Environment(\.cyPalette) private var palette
    var body: some View {
        if !cells.isEmpty {
            // Mini-program `statbar`: horizontal strip, hairline between cells, each "label / big number / unit".
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        if index > 0 {
                            Rectangle()
                                .fill(palette.borderSubtle)
                                .frame(width: 0.5)
                                .padding(.vertical, CYSpacing.xs)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            switch cell {
                            case .rating(let value, let stars):
                                Text("topicXcx.stat.rating").font(CYTypography.micro).foregroundStyle(palette.textTertiary)
                                Text(verbatim: String(format: "%.1f", value)).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(palette.textPrimary)
                                HStack(spacing: 1) { ForEach(0..<stars, id: \.self) { _ in Image(systemName: "star.fill").font(.caption2).foregroundStyle(palette.warning) } }.accessibilityHidden(true)
                            case .hours(let text):
                                Text("topicXcx.stat.hours").font(CYTypography.micro).foregroundStyle(palette.textTertiary)
                                Text(verbatim: text).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(palette.textPrimary)
                                Text("topicXcx.stat.hoursUnit").font(CYTypography.micro).foregroundStyle(palette.textSecondary)
                            case .open(let start, let end):
                                Text("topicXcx.stat.open").font(CYTypography.micro).foregroundStyle(palette.textTertiary)
                                Text(verbatim: start + "-" + end).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(palette.textPrimary)
                            case .mileage(let text):
                                Text("topicXcx.stat.mileage").font(CYTypography.micro).foregroundStyle(palette.textTertiary)
                                Text(verbatim: text).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(palette.textPrimary)
                                Text("topicXcx.stat.mileageUnit").font(CYTypography.micro).foregroundStyle(palette.textSecondary)
                            case .merchants(let count):
                                Text("topicXcx.stat.merchants").font(CYTypography.micro).foregroundStyle(palette.textTertiary)
                                Text(verbatim: String(count)).font(CYTypography.numericBody).monospacedDigit().foregroundStyle(palette.textPrimary)
                                Text("topicXcx.stat.merchantsUnit").font(CYTypography.micro).foregroundStyle(palette.textSecondary)
                            }
                        }
                        .padding(.horizontal, CYSpacing.md)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, CYSpacing.sm)
            }
            .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.xs)
            .accessibilityIdentifier("topic.statBar")
        }
    }
}

struct TopicXcxDurationText: View {
    let seconds: Int?
    var body: some View {
        // pages/topic/index: a missing duration is an em dash, never "0 h". A literal 0 keeps the zero copy.
        if let seconds, seconds >= 0 { known(seconds) } else { Text(verbatim: "—") }
    }
    @ViewBuilder private func known(_ seconds: Int) -> some View {
        switch TopicXcxFacts.duration(seconds: seconds) {
        case .zero: Text("topicXcx.duration.zero")
        case .underMinute: Text("topicXcx.duration.underMinute")
        case .minutes(let m): Text("topicXcx.duration.minutes \(m)")
        case .hours(let h): Text("topicXcx.duration.hours \(h)")
        case .hoursMinutes(let h, let m): Text("topicXcx.duration.hoursMinutes \(h) \(m)")
        }
    }
}

struct TopicXcxIncludes: View {
    let rows: [TopicXcxFacts.Include]
    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            switch row {
            case .chapters(let n): Label { Text("topicXcx.include.chapters \(n)") } icon: { Image(systemName: "book") }
            case .chapterBreakdown(let story, let endings):
                Label {
                    Text(story > 0 ? "topicXcx.include.storyAndEndings \(story) \(endings)" : "topicXcx.include.endings \(endings)")
                } icon: { Image(systemName: "book") }
            case .stops(let n): Label { Text("topicXcx.include.stops \(n)") } icon: { Image(systemName: "mappin.and.ellipse") }
            case .plays(let n): Label { Text("topicXcx.include.plays \(n)") } icon: { Image(systemName: "gamecontroller") }
            case .audioMinutes(let n): Label { Text("topicXcx.include.audioMinutes \(n)") } icon: { Image(systemName: "headphones") }
            case .audio: Label("topicXcx.include.audio", systemImage: "headphones")
            case .medal(let name?): Label { Text("topicXcx.include.medal \(name)") } icon: { Image(systemName: "medal") }
            case .medal(nil): Label("topicXcx.include.medalFallback", systemImage: "medal")
            case .coupon: Label("topicXcx.include.coupon", systemImage: "ticket")
            }
        }
    }
}

struct TopicXcxLineup: View {
    @Environment(\.ugcSafetySubjectID) private var safetySubjectID
    let members: [TopicXcxFacts.LineupMember]

    private var lineupReportTarget: UGCSafetyReportTarget {
        .topic(id: max(1, safetySubjectID ?? 1))
    }

    var body: some View {
        // Mini-program `lineup-row`: horizontal scroll of avatar / name / role cards.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    UGCBlockedFilterContainer(authorName: member.name) {
                        VStack(spacing: CYSpacing.xs) {
                            CYAvatarView(name: member.name, size: .lg)
                            Text(verbatim: member.name).font(CYTypography.label).foregroundStyle(CYColor.textPrimary).cyWrapText(alignment: .center)
                            Text(member.kind == .club ? "topicXcx.lineup.club" : "topicXcx.lineup.merchant").font(CYTypography.micro).foregroundStyle(CYColor.textTertiary)
                        }
                        .frame(width: 88)
                        .accessibilityElement(children: .combine)
                        .contextMenu {
                            UGCReviewSafetyFooter(
                                target: lineupReportTarget,
                                subjectTitle: member.name,
                                authorName: member.name
                            )
                        }
                    }
                }
            }
        }
    }
}

/// Source bottom bar. Purchase/sign-up keep their existing flows; nothing here dispatches a write.
struct TopicXcxActionBar: View {
    @Environment(\.cyPalette) private var palette
    let topic: TopicDetail
    var openSessions: () -> Void
    var openSelfPlay: () -> Void
    var openPricing: (() -> Void)?
    var openTickets: (() -> Void)? = nil
    var shareURL: URL? = nil
    var shareTitle: String? = nil
    var isFavorited: Bool? = nil
    var onToggleFavorite: (() -> Void)? = nil
    var body: some View {
        CYFooterBar {
            VStack(spacing: 6) {
                if topic.merchantClosed && !topic.isSignUp { Text("topicXcx.merchantClosed").font(.footnote).foregroundStyle(palette.warning) }
                HStack {
                    switch TopicXcxFacts.action(topic) {
                    case .ticketWallet:
                        if let openTickets {
                            Button(action: openTickets) {
                                Label("topicXcx.cta.ticketWallet", systemImage: "ticket").frame(maxWidth: .infinity)
                            }
                            .accessibilityIdentifier("topic.cta.tickets")
                        } else {
                            Label("topicXcx.cta.ticketWallet", systemImage: "ticket").frame(maxWidth: .infinity)
                        }
                    case .locked(let lifecycle):
                        if TopicXcxFacts.opensPricing(topic), let openPricing {
                            Button(action: openPricing) { Text("topicXcx.cta.confirmPrice").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                                .accessibilityIdentifier("topic.cta.pricing")
                        } else {
                            Text(LocalizedStringKey("topicXcx.cta.locked." + String(lifecycle))).frame(maxWidth: .infinity).foregroundStyle(CYColor.textSecondary)
                        }
                    case .selfPlay(let price):
                        Button(action: openSessions) { Text("topicXcx.cta.sessions").frame(maxWidth: .infinity) }.buttonStyle(.bordered).frame(minHeight: 44)
                            .accessibilityIdentifier("topic.cta.sessions")
                        Button(action: openSelfPlay) {
                            if let price { Text("topicXcx.cta.selfPlay \(NSDecimalNumber(decimal: price).stringValue)").frame(maxWidth: .infinity) }
                            else { Text("topicXcx.cta.selfPlayNoPrice").frame(maxWidth: .infinity) }
                        }.buttonStyle(.cyPrimary).disabled(!topic.canOfferPurchase)
                            .accessibilityIdentifier("topic.cta.selfPlay")
                    case .signUp:
                        Button(action: openSessions) { Text("topicXcx.cta.signUp").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                            .disabled(topic.merchantClosed)
                            .accessibilityIdentifier("topic.cta.signUp")
                    }
                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorited == true ? "bookmark.fill" : "bookmark")
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text(isFavorited == true ? "roam.favorited" : "roamSub.w208.poi.favorite"))
                        .accessibilityIdentifier("topic.cta.favorite")
                    }
                    if let shareURL {
                        ShareLink(item: shareURL, subject: shareTitle.map { Text(verbatim: $0) }) {
                            Image(systemName: "square.and.arrow.up")
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text("mp.common.share"))
                        .accessibilityIdentifier("topic.cta.share")
                    }
                }
                .controlSize(.large)
                .accessibilityIdentifier("topic.actionBar")
            }
        }
    }
}

private struct TopicPricingDestinationKey: EnvironmentKey { static let defaultValue: ((Int) -> AnyView)? = nil }
extension EnvironmentValues {
    /// Owner-only final-price page (source `pages/topic/pricing`); nil hides the entry.
    var topicPricingDestination: ((Int) -> AnyView)? {
        get { self[TopicPricingDestinationKey.self] }
        set { self[TopicPricingDestinationKey.self] = newValue }
    }
}

/// Source tab "路线": every stop in order with its walking estimate.
struct TopicXcxRouteSection: View {
    @Environment(\.cyPalette) private var palette
    let topic: TopicDetail
    var body: some View {
        Section {
            // Source `route-note`: 固定路线 for city orienteering, 没有固定路线 for free explore.
            Text(topic.productType == 2 ? "u9cde.topic.routeNote.free" : "u9cde.topic.routeNote.fixed")
                .font(CYTypography.label.weight(.semibold))
                .foregroundStyle(topic.productType == 2 ? CYColor.textSecondary : CYNight.ink0)
                .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                .background(Capsule().fill(topic.productType == 2 ? CYNight.glassFill : CYNight.lantern))
                .accessibilityIdentifier("topic.route.note")
            if topic.chapters.allSatisfy({ $0.nodes.isEmpty }) {
                Text("u9cde.topic.routeConfiguring").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("topic.route.empty")
            }
            ForEach(Array(topic.chapters.enumerated()), id: \.offset) { _, chapter in
                if !chapter.nodes.isEmpty { Text(verbatim: chapter.title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                ForEach(TopicChapterItinerary(chapter: chapter).stops) { stop in
                    VStack(alignment: .leading, spacing: 2) {
                        if let minutes = stop.estimatedWalkingMinutes { Text("topicXcx.route.walk \(minutes)").font(Theme.Font.label).foregroundStyle(.secondary) }
                        HStack(alignment: .top) {
                            Text(verbatim: String(stop.id + 1)).font(Theme.Font.label.weight(.bold).monospacedDigit()).frame(minWidth: 24, minHeight: 24).background(Circle().fill(palette.bgRaised)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: stop.node.name)
                                if let hours = stop.node.businessTime { Text(verbatim: hours).font(.caption) }
                                if let address = stop.node.address { Label { Text(verbatim: address).lineLimit(1) } icon: { Image(systemName: "mappin") }.font(.caption) }
                            }
                        }
                    }
                }
            }
        } header: {
            Text(topic.productType == 2 ? "topicXcx.tab.places" : "topicXcx.tab.route")
        }
    }
}

/// Source session chip: `周X M.D HH:mm` (time omitted at 00:00).
struct TopicXcxSessionChip: View {
    let startDate: String?
    var body: some View {
        if let chip = TopicXcxFacts.sessionChip(startDate) {
            HStack(spacing: 4) {
                Text(LocalizedStringKey("topicXcx.weekday." + String(chip.weekday)))
                Text(verbatim: chip.monthDay)
                if let time = chip.time { Text(verbatim: time) }
            }.font(Theme.Font.label.weight(.semibold).monospacedDigit()).accessibilityElement(children: .combine).accessibilityIdentifier("topic.sessionChip")
        }
    }
}

/// Source 节点介绍: horizontal template cards (title, players, minutes). Images stay behind the gated gallery.
struct TopicXcxTemplatesSection: View {
    @Environment(\.cyPalette) private var palette
    let templates: [TopicTemplate]
    var body: some View {
        if !templates.isEmpty {
            Section("topicXcx.section.nodeIntro") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(templates, id: \.id) { template in
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text(verbatim: template.title)
                                    .font(CYTypography.cardTitle)
                                    .foregroundStyle(palette.textPrimary)
                                    .cyWrapText()
                                if let players = template.players {
                                    Text(verbatim: players)
                                        .font(CYTypography.caption)
                                        .foregroundStyle(palette.textSecondary)
                                }
                                Text("topicXcx.templateMinutes \(TopicXcxFacts.templateMinutes(template))")
                                    .font(CYTypography.caption)
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .frame(width: 152, alignment: .leading)
                            .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("topic.nodeIntro.\(template.id)")
                            .contextMenu {
                                UGCReviewSafetyFooter(
                                    target: .template(id: template.id),
                                    subjectTitle: template.title
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Source node card foot: `{商家}（{节点}）` plus `等 N 家`.
struct TopicXcxNodeFootView: View {
    let node: TopicNode
    var body: some View {
        let foot = TopicXcxFacts.nodeFoot(node)
        if let merchant = foot.merchant {
            HStack(spacing: 4) {
                Text(verbatim: merchant + "（" + foot.node + "）").font(.subheadline)
                if foot.merchantCount > 1 { Text("topicXcx.moreMerchants \(foot.merchantCount)").font(.caption).foregroundStyle(.secondary) }
            }.accessibilityIdentifier("topic.nodeFoot")
        }
    }
}
