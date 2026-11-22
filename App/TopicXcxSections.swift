import SwiftUI

/// Mini-program `pages/topic/index` sections layered onto the existing topic detail list.
enum TopicXcxTab: Int, CaseIterable, Identifiable {
    case details, nodes, route
    var id: Int { rawValue }
    /// Free exploration names the third tab 地点; city orienteering keeps 路线.
    /// Same keys as `titleKey`, for `appLocalized` (CYTabs takes resolved titles).
    func titleKeyString(productType: Int) -> String {
        switch self {
        case .details: return "topicXcx.tab.details"
        case .nodes: return "topicXcx.tab.nodes"
        case .route: return productType == 2 ? "topicXcx.tab.places" : "topicXcx.tab.route"
        }
    }
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
    @State private var ownSelection: TopicXcxTab = .details
    /// Shared selection, so the inline and the pinned copy of the tabs show the same tab.
    private var shared: Binding<TopicXcxTab>?

    init(proxy: ScrollViewProxy, productType: Int = 0) {
        self.proxy = proxy; self.productType = productType
    }

    /// Binds the selected tab to a value the page owns (the pinned copy reads the same one).
    func selection(_ binding: Binding<TopicXcxTab>) -> Self { var copy = self; copy.shared = binding; return copy }

    private var selection: Binding<TopicXcxTab> { shared ?? $ownSelection }

    var body: some View {
        let items = TopicXcxTab.allCases.map { tab in
            CYTabItem(id: tab, title: appLocalized(String.LocalizationValue(tab.titleKeyString(productType: productType)), locale: locale))
        }
        CYTabs(items: items, selection: selection, variant: .sticky)
            .accessibilityIdentifier("topic.tabs")
            .onChange(of: selection.wrappedValue) { _, tab in
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
            // skill-r2 hand-off / verify-r1 3.1 (`169:6954`): no blue type chip; the type is the eyebrow over the title.
            if !topic.categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(topic.categoryNames, id: \.self) { name in
                            Text(verbatim: name)
                                .cyText(.label)
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

/// verify-r1 3.1 / PL-23 (`169:6954`): up to four equal stat cells in one card, value at 20 pt over a 13 pt label.
/// Only known facts appear (a missing duration or distance is left out, never `—` or `0`).
struct TopicXcxStatBar: View {
    let cells: [TopicXcxFacts.StatCell]
    var stops: Int? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Tile: Identifiable {
        let id: String
        let value: String
        let label: LocalizedStringKey
        var unit: LocalizedStringKey? = nil
    }
    private var tiles: [Tile] {
        var out: [Tile] = []
        for cell in cells {
            switch cell {
            case .rating(let value, _): out.append(Tile(id: "rating", value: String(format: "%.1f", value), label: "topicXcx.stat.rating"))
            case .hours(let text): out.append(Tile(id: "hours", value: text, label: "topicXcx.stat.hours", unit: "topicXcx.stat.hoursUnit"))
            case .open(let start, let end): out.append(Tile(id: "open", value: start + "-" + end, label: "topicXcx.stat.open"))
            case .mileage(let text): out.append(Tile(id: "mileage", value: text, label: "topicXcx.stat.mileage", unit: "topicXcx.stat.mileageUnit"))
            case .merchants(let count): out.append(Tile(id: "merchants", value: String(count), label: "topicXcx.stat.merchants"))
            }
        }
        if let stops, stops > 0 {
            out.insert(Tile(id: "stops", value: String(stops), label: "topicXcx.stat.stops"), at: min(out.count, 2))
        }
        return Array(out.prefix(4))
    }

    var body: some View {
        let tiles = tiles
        if !tiles.isEmpty {
            let columns = typeSize.isAccessibilitySize ? 2 : tiles.count
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CYSpacing.sm, alignment: .topLeading), count: columns),
                      alignment: .leading, spacing: CYSpacing.md) {
                ForEach(tiles) { tile in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(verbatim: tile.value)
                                .cyText(.sectionTitle)
                                .monospacedDigit()
                                .foregroundStyle(palette.textPrimary)
                            if let unit = tile.unit {
                                Text(unit).cyText(.meta).foregroundStyle(palette.textPrimary)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        Text(tile.label).cyText(.meta).foregroundStyle(palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, CYSpacing.md)
            .padding(.horizontal, CYSpacing.lg)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityElement(children: .contain)
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
                            Text(verbatim: member.name).cyText(.label).foregroundStyle(CYColor.textPrimary).cyWrapText(alignment: .center)
                            Text(member.kind == .club ? "topicXcx.lineup.club" : "topicXcx.lineup.merchant").cyText(.micro).foregroundStyle(CYColor.textTertiary)
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
/// verify-r1 3.1 / PL-23 (`169:6954`): the sticky bar is the price on the left (with one caption line) and one
/// primary on the right. 查看场次 is a quiet text action under the price; share and favourite live in the navigation bar.
struct TopicXcxActionBar: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    let topic: TopicDetail
    var openSessions: () -> Void
    var openSelfPlay: () -> Void
    var openPricing: (() -> Void)?
    var openTickets: (() -> Void)? = nil
    var shareURL: URL? = nil
    var shareTitle: String? = nil
    var isFavorited: Bool? = nil
    var onToggleFavorite: (() -> Void)? = nil
    /// Continuity r1 (6): the host's namespace. Each bar button is the zoom source of the sheet it opens; nil keeps plain buttons.
    var heroNamespace: Namespace.ID? = nil

    /// The cheapest known ticket, for 「¥X 起」 / 免费 on a sign-up topic. Unknown prices are left out.
    private var lowestTicketPrice: Decimal? { topic.tickets.compactMap(\.price).min() }

    @ViewBuilder private func priceText(_ amount: Decimal?) -> some View {
        if let amount {
            if amount == 0 { Text("topicXcx.bar.free") }
            else { Text(amount, format: .currency(code: "CNY").precision(.fractionLength(0...2)).locale(locale)) }
        }
    }

    @ViewBuilder private var priceColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch TopicXcxFacts.action(topic) {
            case .ticketWallet:
                Text("topicXcx.bar.signedUp").cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
            case .locked:
                EmptyView()
            case .selfPlay(let price):
                priceText(price).cyText(.sectionTitle).foregroundStyle(palette.textPrimary).monospacedDigit()
                Button(action: openSessions) {
                    HStack(spacing: 2) {
                        Text("topicXcx.cta.sessions")
                        Image(systemName: "chevron.forward").font(.caption2.weight(.semibold)).accessibilityHidden(true)
                    }
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .modifier(TopicBarHeroSource(sheet: .sessions, namespace: heroNamespace, cornerRadius: CYRadius.sm))
                .pageTemplateControl(label: Text("topicXcx.cta.sessions"), traits: .isButton)
                .pageTemplateReadingOrder(2)
                .accessibilityIdentifier("topic.cta.sessions")
            case .signUp:
                if let lowest = lowestTicketPrice {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        priceText(lowest).cyText(.sectionTitle).monospacedDigit()
                        if lowest > 0 { Text("topicXcx.bar.from").cyText(.meta) }
                    }
                    .foregroundStyle(palette.textPrimary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    var body: some View {
        CYFooterBar {
            VStack(spacing: 6) {
                if topic.merchantClosed && !topic.isSignUp { Text("topicXcx.merchantClosed").cyText(.bodyCompact).foregroundStyle(palette.warning) }
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    priceColumn
                    Spacer(minLength: CYSpacing.sm)
                    switch TopicXcxFacts.action(topic) {
                    case .ticketWallet:
                        if let openTickets {
                            Button(action: openTickets) {
                                Label("topicXcx.bar.toTickets", systemImage: "ticket").frame(minWidth: 132)
                            }
                            .buttonStyle(.cyPrimary)
                            .modifier(TopicBarHeroSource(sheet: .tickets, namespace: heroNamespace))
                            .accessibilityLabel(Text("topicXcx.cta.ticketWallet"))
                            .accessibilityIdentifier("topic.cta.tickets")
                        } else {
                            Label("topicXcx.cta.ticketWallet", systemImage: "ticket").foregroundStyle(palette.textSecondary)
                        }
                    case .locked(let lifecycle):
                        if TopicXcxFacts.opensPricing(topic), let openPricing {
                            Button(action: openPricing) { Text("topicXcx.cta.confirmPrice").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                                .modifier(TopicBarHeroSource(sheet: .pricing, namespace: heroNamespace))
                                .pageTemplateControl(label: Text("topicXcx.cta.confirmPrice"), traits: .isButton)
                                .accessibilityIdentifier("topic.cta.pricing")
                        } else {
                            Text(LocalizedStringKey("topicXcx.cta.locked." + String(lifecycle))).frame(maxWidth: .infinity).foregroundStyle(CYColor.textSecondary)
                        }
                    case .selfPlay:
                        Button(action: openSelfPlay) {
                            Text("topicXcx.cta.selfPlayNoPrice").frame(minWidth: 132)
                        }.buttonStyle(.cyPrimary).disabled(!topic.canOfferPurchase)
                            .modifier(TopicBarHeroSource(sheet: .selfPlay, namespace: heroNamespace))
                            .accessibilityAddTraits(.isButton)
                            .pageTemplateReadingOrder(1)
                            .accessibilityIdentifier("topic.cta.selfPlay")
                    case .signUp:
                        Button(action: openSessions) { Text("topicXcx.cta.signUp").frame(minWidth: 132) }.buttonStyle(.cyPrimary)
                            .modifier(TopicBarHeroSource(sheet: .sessions, namespace: heroNamespace))
                            .pageTemplateControl(label: Text("topicXcx.cta.signUp"), traits: .isButton)
                            .disabled(topic.merchantClosed)
                            .accessibilityIdentifier("topic.cta.signUp")
                    }
                }
                .controlSize(.large)
                .accessibilityIdentifier("topic.actionBar")
            }
        }
    }
}

/// The sheets the topic bottom bar opens. Each is the zoom id that pairs a bar button with its sheet (continuity r1 item 6).
/// 立即报名 and 查看场次 both open the session sheet but never show together (sign-up vs self-play states), so one id is unique.
enum TopicBarSheet: Hashable { case sessions, selfPlay, tickets, pricing }

/// `cyHeroSource` for a bar button when the host passed a namespace. Primary buttons clip at the button radius (`CYRadius.md`).
private struct TopicBarHeroSource: ViewModifier {
    let sheet: TopicBarSheet
    let namespace: Namespace.ID?
    var cornerRadius: CGFloat = CYRadius.md
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace { content.cyHeroSource(sheet, in: namespace, cornerRadius: cornerRadius) } else { content }
    }
}

/// The sheet's side of the pair: `cyHeroDestination` only when the bar opened this sheet (`origin`). Other openers of the
/// same sheet (paywall 解锁, contact save) keep the plain slide-up, so a sheet never zooms out of a button it did not come from.
struct TopicBarHeroDestination: ViewModifier {
    let sheet: TopicBarSheet
    let origin: TopicBarSheet?
    let namespace: Namespace.ID
    @ViewBuilder func body(content: Content) -> some View {
        if origin == sheet { content.cyHeroDestination(sheet, in: namespace) } else { content }
    }
}

/// The topic page behind a bar sheet recedes (scale 0.96, corners to `CYRadius.xl`) while the sheet zooms out of its
/// button. The sheets use fractional detents, so the system never recedes the page itself. Apply it to the scroll content
/// BEFORE the bottom bar inset: the bar (the zoom source) stays still, so the zoom lands back on the real button.
/// At rest (`active == false`) scale 1 and radius 0, identical to before. Reduce Motion: no scale; the sheet dim remains.
struct TopicBarRecede: ViewModifier {
    let active: Bool
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        let receded = active && !reduceMotion
        content
            .clipShape(RoundedRectangle(cornerRadius: receded ? CYRadius.xl : 0, style: .continuous))
            .scaleEffect(receded ? 0.96 : 1)
            .animation(reduceMotion ? nil : CYMotion.standard, value: receded)
    }
}

/// Share and favourite for the topic, as glass circles in the navigation bar (`169:6954` top-trailing).
struct TopicXcxToolbarActions: View {
    var shareURL: URL?
    var shareTitle: String?
    var isFavorited: Bool? = nil
    var onToggleFavorite: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 0) {
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorited == true ? "bookmark.fill" : "bookmark")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(Text(isFavorited == true ? "roam.favorited" : "roamSub.w208.poi.favorite"))
                .accessibilityIdentifier("topic.cta.favorite")
            }
            if let shareURL {
                ShareLink(item: shareURL, subject: shareTitle.map { Text(verbatim: $0) }) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(Text("mp.common.share"))
                .accessibilityIdentifier("topic.cta.share")
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
                .cyText(.label, weight: .semibold)
                .foregroundStyle(topic.productType == 2 ? CYColor.textSecondary : CYNight.ink0)
                .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                .background(Capsule().fill(topic.productType == 2 ? CYNight.glassFill : CYNight.lantern))
                .accessibilityIdentifier("topic.route.note")
            if topic.chapters.allSatisfy({ $0.nodes.isEmpty }) {
                Text("u9cde.topic.routeConfiguring").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("topic.route.empty")
            }
            ForEach(Array(topic.chapters.enumerated()), id: \.offset) { _, chapter in
                if !chapter.nodes.isEmpty { Text(verbatim: chapter.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                ForEach(TopicChapterItinerary(chapter: chapter).stops) { stop in
                    VStack(alignment: .leading, spacing: 2) {
                        if let minutes = stop.estimatedWalkingMinutes { Text("topicXcx.route.walk \(minutes)").cyText(.label).foregroundStyle(.secondary) }
                        HStack(alignment: .top) {
                            Text(verbatim: String(stop.id + 1)).cyText(.label, weight: .bold, monospacedDigit: true).frame(minWidth: 24, minHeight: 24).background(Circle().fill(palette.bgRaised)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: stop.node.name)
                                if let hours = stop.node.businessTime { Text(verbatim: hours).cyText(.meta) }
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
            }.cyText(.label, weight: .semibold, monospacedDigit: true).accessibilityElement(children: .combine).accessibilityIdentifier("topic.sessionChip")
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
                                    .cyText(.cardTitle)
                                    .foregroundStyle(palette.textPrimary)
                                    .cyWrapText()
                                if let players = template.players {
                                    Text(verbatim: players)
                                        .cyText(.caption)
                                        .foregroundStyle(palette.textSecondary)
                                }
                                Text("topicXcx.templateMinutes \(TopicXcxFacts.templateMinutes(template))")
                                    .cyText(.caption)
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
                if foot.merchantCount > 1 { Text("topicXcx.moreMerchants \(foot.merchantCount)").cyText(.meta).foregroundStyle(.secondary) }
            }.accessibilityIdentifier("topic.nodeFoot")
        }
    }
}

/// PC-B-1-2: topic 收藏 on the detail page, as MP `pages/topic/index` `_loadFav` / `toggleFav` (index.js:642-686).
/// State comes from `POST api/topic/like_list {pageNum:1,pageSize:200}`; the write is `POST api/topic/like {id,type}`
/// with an explicit final state (`TopicLikeOperationFactory`). Both go through the session's composition transport, so
/// the reviewed player-write lease still decides whether the request may leave the device.
@MainActor struct TopicFavoriteAccess {
    /// Nil = unknown (signed out, read failed): the bookmark is hidden rather than guessed.
    let load: @MainActor (_ topicID: Int) async -> Bool?
    let set: @MainActor (_ topicID: Int, _ liked: Bool) async -> TopicLikeWriteOutcome
}

extension AppSession {
    func topicFavoriteAccess() -> TopicFavoriteAccess? {
        guard isSignedIn, let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        let transport = compositionTransport
        return TopicFavoriteAccess(
            load: { [weak self] topicID in
                guard let self, let token = self.token, topicID > 0,
                      let request = try? AuthRequestBuilder.makeFormRequest(
                        url: configuration.baseURL.appendingPathComponent("api/topic/like_list"),
                        fields: ["pageNum": "1", "pageSize": "200"], token: token),
                      let response = try? await transport.send(request), (200..<300).contains(response.1) else { return nil }
                return TopicFavoriteList.contains(topicID, in: response.0)
            },
            set: { [weak self] topicID, liked in
                guard let self, let token = self.token,
                      let request = try? TopicLikeOperationFactory(configuration: configuration)
                        .request(topicID: topicID, direction: TopicLikeDirection(liked: liked), token: token) else { return .rejected(nil) }
                guard let response = try? await transport.send(request) else { return .unknown }
                return TopicLikeWriteOutcome.decode(data: response.0, status: response.1)
            })
    }
}

/// `like_list` envelope `{code:200,data:{rows:[{id}]}}`. Anything else is unknown (nil), never "not favourited".
enum TopicFavoriteList {
    static func contains(_ topicID: Int, in data: Data) -> Bool? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              String(describing: object["code"] ?? "") == "200",
              let body = object["data"] as? [String: Any], let rows = body["rows"] as? [[String: Any]] else { return nil }
        return rows.contains { row in
            if let id = row["id"] as? Int { return id == topicID }
            if let id = row["id"] as? String { return id == String(topicID) }
            return false
        }
    }
}
