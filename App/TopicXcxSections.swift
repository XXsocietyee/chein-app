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
    /// `TopicDetail.ownerReviewLabel` is the MP's Chinese `ownerStateText`; each value has its own catalog key.
    static func reviewKey(_ label: String) -> String {
        switch label {
        case "审核中": return "topicXcx.review.pending"
        case "未通过": return "topicXcx.review.rejected"
        default: return "topicXcx.review.unlisted"
        }
    }
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
            // R7-PC-B1-9 (MP index.wxml:89-91, 101): publisher row (avatar + name + 发布) and the owner-only review chip.
            if topic.publisher != nil || topic.ownerReviewLabel != nil {
                HStack(spacing: CYSpacing.sm) {
                    if let publisher = topic.publisher {
                        CYAvatarView(url: publisher.avatar.flatMap(URL.init(string:)), name: publisher.name, size: .xs)
                            .accessibilityHidden(true)
                        Text(verbatim: publisher.name)
                            .cyText(.label)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                        Text("topicXcx.publisher.posted")
                            .cyText(.label)
                            .foregroundStyle(palette.textSecondary)
                    }
                    if let review = topic.ownerReviewLabel {
                        Text(LocalizedStringKey(TopicXcxHero.reviewKey(review)))
                            .cyText(.label)
                            .foregroundStyle(palette.textSecondary)
                            .padding(.horizontal, CYSpacing.sm)
                            .padding(.vertical, CYSpacing.xxs)
                            .background(palette.bgRaised, in: Capsule())
                            .accessibilityIdentifier("topic.ownerReviewState")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("topic.publisher")
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

struct TopicXcxLineup: View {
    @Environment(\.ugcSafetySubjectID) private var safetySubjectID
    @Environment(\.topicLineupClubDestination) private var clubDestination
    let members: [TopicXcxFacts.LineupMember]
    /// R7-PC-B1-10 (MP `lineup-row` tap → club detail / merchant home). Nil context leaves merchant cards static.
    var publicMerchant: PublicMerchantHomeContext? = nil

    @ViewBuilder private func destination(_ member: TopicXcxFacts.LineupMember) -> some View {
        switch member.kind {
        case .club:
            if member.targetID > 0, let clubDestination { clubDestination(member.targetID) }
        case .merchant:
            if let owner = PublicMerchantOwnerID(member.targetID), let publicMerchant {
                PublicMerchantHomeView(target: .ownerMemberID(owner), context: publicMerchant)
            }
        }
    }
    private func opens(_ member: TopicXcxFacts.LineupMember) -> Bool {
        switch member.kind {
        case .club: return member.targetID > 0 && clubDestination != nil
        case .merchant: return PublicMerchantOwnerID(member.targetID) != nil && publicMerchant != nil
        }
    }

    private var lineupReportTarget: UGCSafetyReportTarget {
        .topic(id: max(1, safetySubjectID ?? 1))
    }

    var body: some View {
        // Mini-program `lineup-row`: horizontal scroll of avatar / name / role cards.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    UGCBlockedFilterContainer(authorName: member.name) {
                        let card = VStack(spacing: CYSpacing.xs) {
                            CYAvatarView(name: member.name, size: .lg)
                            Text(verbatim: member.name).cyText(.label).foregroundStyle(CYColor.textPrimary).cyWrapText(alignment: .center)
                            Text(member.kind == .club ? "topicXcx.lineup.club" : "topicXcx.lineup.merchant").cyText(.micro).foregroundStyle(CYColor.textTertiary)
                        }
                        .frame(width: 88)
                        Group {
                            if opens(member) {
                                NavigationLink { destination(member) } label: { card }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("topic.lineup.\(member.kind == .club ? "club" : "merchant").\(member.targetID)")
                            } else {
                                card
                            }
                        }
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
    var openEditor: (() -> Void)? = nil
    /// `via=session`: the bar opens the session picker before self-play.
    var preferSession = false
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
            else { Text(verbatim: MoneyDisplay.yuan(amount)) }  // owner decision 9: ¥12.50
        }
    }

    @ViewBuilder private var priceColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch TopicXcxFacts.action(topic, preferSession: preferSession) {
            case .ticketWallet:
                Text("topicXcx.bar.signedUp").cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
            case .locked, .closed:
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
                    switch TopicXcxFacts.action(topic, preferSession: preferSession) {
                    case .ticketWallet:
                        if let openTickets {
                            Button(action: openTickets) {
                                Label("topicXcx.bar.toTickets", systemImage: "ticket").frame(minWidth: 132)
                            }
                            .buttonStyle(.cyPrimary)
                            .modifier(TopicBarHeroSource(sheet: .tickets, namespace: heroNamespace))
                            // R7-PC-B1-23 (r1 PC-B-1-17): the spoken label is the visible 去票夹.
                            .accessibilityIdentifier("topic.cta.tickets")
                        } else {
                            Label("topicXcx.cta.ticketWallet", systemImage: "ticket").foregroundStyle(palette.textSecondary)
                        }
                    case .locked(let lifecycle):
                        switch TopicXcxFacts.ownerSaleRoute(topic) {
                        case .pricing where openPricing != nil:
                            Button(action: { openPricing?() }) { Text("topicXcx.cta.confirmPrice").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                                .modifier(TopicBarHeroSource(sheet: .pricing, namespace: heroNamespace))
                                .pageTemplateControl(label: Text("topicXcx.cta.confirmPrice"), traits: .isButton)
                                .accessibilityIdentifier("topic.cta.pricing")
                        case .editor where openEditor != nil:
                            // R7-PC-B1-19 (MP index.js:1177-1182): 去设置票价 opens the editor for a free-explore owner.
                            Button(action: { openEditor?() }) { Text("topicXcx.cta.editPrice").frame(maxWidth: .infinity) }.buttonStyle(.cyPrimary)
                                .pageTemplateControl(label: Text("topicXcx.cta.editPrice"), traits: .isButton)
                                .accessibilityIdentifier("topic.cta.editor")
                        default:
                            Text(LocalizedStringKey("topicXcx.cta.locked." + String(lifecycle))).frame(maxWidth: .infinity).foregroundStyle(CYColor.textSecondary)
                        }
                    case .closed:
                        // PC-B-1-3: after the sale deadline the bar only states 已截止 (MP is-off pill); no buy entry.
                        Text("topicXcx.cta.closed").frame(maxWidth: .infinity).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("topic.cta.closed")
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
    /// R7-PC-B1-22 (MP index.wxml:545 `cy-share-card`): the share card beside the system share; nil hides it.
    var posterCover: String? = nil
    var posterSubtitle: String? = nil
    @State private var showsPoster = false
    var body: some View {
        HStack(spacing: 0) {
            if let shareURL, let shareTitle {
                Button { showsPoster = true } label: {
                    Image(systemName: "photo.on.rectangle")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(Text("topicShare.poster"))
                .accessibilityIdentifier("topic.cta.poster")
                .sheet(isPresented: $showsPoster) {
                    NavigationStack {
                        ScrollView {
                            VStack(spacing: CYSpacing.lg) {
                                TopicSharePosterCardView(coverURL: posterCover, topicName: shareTitle, subtitle: posterSubtitle,
                                                         shareURLString: shareURL.absoluteString)
                                ShareLink(item: shareURL, subject: Text(verbatim: shareTitle)) {
                                    Label("mp.common.share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("topic.poster.share")
                            }
                            .padding(CYSpacing.pageHorizontal)
                        }
                        .navigationTitle(Text("topicShare.poster"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { showsPoster = false } } }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    // Round 4 image parity: MP hero-fav `icon_bm_on.svg` / `icon_bm.svg` (topic/index.wxml:97).
                    (isFavorited == true ? MPAsset.FeatureIcon.iconBmOn : MPAsset.FeatureIcon.iconBm)
                        .resizable().scaledToFit()
                        .accessibilityHidden(true)
                        .frame(width: 22, height: 22)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(Text(LocalizedStringKey(isFavorited == true ? "topic.favorite.remove" : "topic.favorite.add"))) // MP aria 取消收藏 / 收藏主题
                .accessibilityIdentifier("topic.cta.favorite")
            }
            if let shareURL {
                ShareLink(item: shareURL, subject: shareTitle.map { Text(verbatim: $0) }) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityLabel(Text("topic.share.mp")) // MP topic/index.wxml:113 aria 分享主题
                .accessibilityIdentifier("topic.cta.share")
            }
        }
    }
}

private struct TopicPricingDestinationKey: EnvironmentKey { static let defaultValue: ((Int) -> AnyView)? = nil }
private struct TopicPricingScopeKey: EnvironmentKey { static let defaultValue: String? = nil }
private struct TopicEditorDestinationKey: EnvironmentKey { static let defaultValue: ((Int, String?) -> AnyView)? = nil }
extension EnvironmentValues {
    /// Owner-only final-price page (source `pages/topic/pricing`); nil hides the entry.
    var topicPricingDestination: ((Int) -> AnyView)? {
        get { self[TopicPricingDestinationKey.self] }
        set { self[TopicPricingDestinationKey.self] = newValue }
    }
    /// R7-PC-B4-6 (MP topic index.js:1178 `&scope=MERCHANT`): the owner sale route's scope for the pricing page.
    var topicPricingScope: String? {
        get { self[TopicPricingScopeKey.self] }
        set { self[TopicPricingScopeKey.self] = newValue }
    }
    /// Owner lifecycle-2 free explore opens `pages/publish/fabu/index`. Nil hides the entry. This does not grant pricing.
    var topicEditorDestination: ((Int, String?) -> AnyView)? {
        get { self[TopicEditorDestinationKey.self] }
        set { self[TopicEditorDestinationKey.self] = newValue }
    }
}

/// Source tab "路线": every stop in order with its walking estimate.
struct TopicXcxRouteSection: View {
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.openURL) private var openURL
    let topic: TopicDetail
    private var routeNoteText: String {
        let zh = locale.language.languageCode?.identifier == "zh"
        let separator = zh ? "，" : ", "
        let end = zh ? "。" : "."
        if topic.productType == 2 {
            let shops = topic.merchantCount ?? 0
            return shops > 0 ? appLocalized("topicXcx.routeNote.freeShops \(shops)", locale: locale)
                             : appLocalized("topicXcx.routeNote.free", locale: locale)
        }
        var parts = [appLocalized("topicXcx.routeNote.inOrder", locale: locale)]
        let stops = topic.chapters.reduce(0) { $0 + $1.nodes.count }
        if stops > 0 { parts.append(appLocalized("topicXcx.routeNote.stops \(stops)", locale: locale)) }
        if let km = topic.totalMileage, km > 0 {
            let value = km.formatted(.number.precision(.fractionLength(0...1)))
            parts.append(appLocalized("topicXcx.routeNote.walk \(value)", locale: locale))
        }
        let gifts = TopicXcxFacts.giftStopCount(topic)
        if gifts > 0 { parts.append(appLocalized("topicXcx.routeNote.gifts \(gifts)", locale: locale)) }
        return parts.joined(separator: separator) + end
    }
    /// Flow gap PC-B-1-5 (MP index.wxml route `<map>`): every stop with a usable coordinate, numbered in route order.
    static func mapPins(_ topic: TopicDetail) -> [TopicRouteNodePin] {
        var pins: [TopicRouteNodePin] = []
        var sequence = 0
        for chapter in topic.chapters {
            for node in chapter.nodes {
                sequence += 1
                guard let lat = node.latitude, let lng = node.longitude, (-90...90).contains(lat), (-180...180).contains(lng),
                      lat != 0 || lng != 0 else { continue }
                pins.append(TopicRouteNodePin(id: "\(chapter.id)-\(node.id)-\(sequence)", sequence: sequence, name: node.name,
                                              latitude: lat, longitude: lng, address: node.address))
            }
        }
        return pins
    }
    var body: some View {
        Section {
            // Flow gap PC-B-1-5: the route map. Progress / teams need a play read, so they stay off on the detail.
            let pins = Self.mapPins(topic)
            if !pins.isEmpty {
                TopicRouteMapAndTeamsSection(pins: pins, completedCount: 0, totalCount: 0, isFreeExplore: topic.productType == 2,
                                             onSelectPin: { pin in
                                                 let node = topic.chapters.flatMap(\.nodes).first { $0.name == pin.name && $0.latitude == pin.latitude && $0.longitude == pin.longitude }
                                                 if let node, let url = TopicStopMapsLink.url(for: node) { openURL(url) }
                                             })
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("topic.route.map")
            }
            // Source `route-note`: 固定路线 for city orienteering, 没有固定路线 for free explore.
            Text(topic.productType == 2 ? "u9cde.topic.routeNote.free" : "u9cde.topic.routeNote.fixed")
                .cyText(.label, weight: .semibold)
                .foregroundStyle(topic.productType == 2 ? CYColor.textSecondary : CYNight.ink0)
                .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                .background(Capsule().fill(topic.productType == 2 ? CYNight.glassFill : CYNight.lantern))
                .accessibilityIdentifier("topic.route.note")
            // R7-PC-B1-18, MP pages/topic/utils/topic-motion.js routeNote: the gift count is in the sentence.
            Text(verbatim: routeNoteText)
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("topic.route.noteText")
            if topic.chapters.allSatisfy({ $0.nodes.isEmpty }) {
                Text("u9cde.topic.routeConfiguring").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("topic.route.empty")
                // R7-PC-B1-17 (MP index.wxml:358, js:1120 `goTopicList` → pages/template/index, the 发布/模板 tab).
                if rootTabSwitch.isAvailable {
                    Button { rootTabSwitch(.publish) } label: {
                        Text("topicXcx.route.browseOthers").frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .accessibilityIdentifier("topic.route.browseOthers")
                }
            }
            ForEach(Array(topic.chapters.enumerated()), id: \.offset) { _, chapter in
                if !chapter.nodes.isEmpty { Text(verbatim: chapter.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                ForEach(TopicChapterItinerary(chapter: chapter).stops) { stop in
                    VStack(alignment: .leading, spacing: 2) {
                        // PC-B-1-7: the API has no walking time; say only the straight-line distance (MP 直线约 X).
                        if let meters = stop.straightLineMeters {
                            Text("topicXcx.route.straightLine \(TopicChapterItinerary.distanceText(meters: meters, chinese: locale.language.languageCode?.identifier == "zh"))")
                                .cyText(.label).foregroundStyle(.secondary)
                        }
                        HStack(alignment: .top) {
                            Text(verbatim: String(stop.id + 1)).cyText(.label, weight: .bold, monospacedDigit: true).frame(minWidth: 24, minHeight: 24).background(Circle().fill(palette.bgRaised)).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: stop.node.name)
                                if let hours = stop.node.businessTime { Text(verbatim: hours).cyText(.meta) }
                                // R7-PC-B1-18: MP stop row opens the place in the map app.
                                if let gift = stop.node.shopGift {
                                    Text(verbatim: appLocalized("topicXcx.stop.gift \(gift)", locale: locale))
                                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                        .accessibilityIdentifier("topic.route.stop.\(stop.id).gift")
                                }
                                if let address = stop.node.address {
                                    if let url = TopicStopMapsLink.url(for: stop.node) {
                                        Link(destination: url) {
                                            Label { Text(verbatim: address).lineLimit(1) } icon: { Image(systemName: "mappin") }.font(.caption)
                                        }
                                        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                                        .accessibilityHint(Text("accountCollection.coupon.openInMaps"))
                                        .accessibilityIdentifier("topic.route.stop.\(stop.id).map")
                                    } else {
                                        Label { Text(verbatim: address).lineLimit(1) } icon: { Image(systemName: "mappin") }.font(.caption)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                            // R7-PC-B1-18: MP stop image.
                            if let image = stop.node.images.first, let url = QuestifyCardArtwork.safeURL(image) {
                                PlayerFeedRemoteImage(url: url, maxPixel: 160, placeholder: { CYColor.bgSurfaceStrong }, failure: { CYColor.bgSurfaceStrong })
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                                    .accessibilityHidden(true)
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

/// 「出发前」 (MP `index.wxml` `topic-includes`, `pages/topic/utils/depart-notes.js`, 2026-11-21; port plan r1 C13):
/// one short line per fact the route already has. Nothing shows when nothing is known.
struct TopicDepartSection: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    let items: [TopicDepartNotes.Item]

    var body: some View {
        if !items.isEmpty {
            Section("topic.depart") {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    row(item)
                        .cyText(.bodyCompact)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("topic.depart.\(index)")
                }
            }
        }
    }

    @ViewBuilder private func row(_ item: TopicDepartNotes.Item) -> some View {
        switch item {
        case .price(let name, let amount, let from, let sharedBy):
            // REV-B B-02: the one money switch (`MoneyDisplay`), not a locale currency formatter.
            let price = MoneyDisplay.yuan(amount)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                if let name { Text(verbatim: name) } else { Text("topic.depart.selfPlay") }
                Spacer(minLength: CYSpacing.sm)
                VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                    Group {
                        if from { Text("topic.depart.priceFrom \(price)") } else { Text(verbatim: price) }
                    }
                    .monospacedDigit()
                    if let sharedBy {
                        Text("topic.depart.sharedBy \(sharedBy)").cyText(.caption).foregroundStyle(palette.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        case .includes(let parts):
            Text("topic.depart.includes \(includesText(parts))")
        case .pauseResume:
            Text("topic.depart.pauseResume")
        case .badge(let name):
            if let name { Text("topic.depart.badge \(name)") } else { Text("topic.depart.badgeUnnamed") }
        case .coupon:
            Text("topic.depart.coupon")
        case .note(let line):
            Text(verbatim: line)
        }
    }

    /// 含 N 个章节、N 个站点、N 个玩法、语音导览: the same include copy as the rest of the page, joined like the MP.
    private func includesText(_ parts: [TopicXcxFacts.Include]) -> String {
        let texts: [String] = parts.compactMap { part in
            switch part {
            case .chapters(let n): return appLocalized("topicXcx.include.chapters \(n)", locale: locale)
            // REV-B B-06 (MP depart-notes.js:73): 出发前 says 「N 个章节」 (story + endings, no breakdown) and 「N 个节点」.
            case .chapterBreakdown(let story, let endings):
                return appLocalized("topicXcx.include.chapters \(story + endings)", locale: locale)
            case .stops(let n): return appLocalized("topic.depart.stops \(n)", locale: locale)
            case .plays(let n): return appLocalized("topicXcx.include.plays \(n)", locale: locale)
            case .audioMinutes(let n): return appLocalized("topicXcx.include.audioMinutes \(n)", locale: locale)
            case .audio: return appLocalized("topicXcx.include.audio", locale: locale)
            case .medal, .coupon: return nil
            }
        }
        return texts.joined(separator: appLocalized("topic.depart.separator", locale: locale))
    }
}

private struct TopicLineupClubDestinationKey: EnvironmentKey { static let defaultValue: ((Int) -> AnyView)? = nil }
extension EnvironmentValues {
    /// Club detail for a topic lineup card (club id). Nil leaves club cards static.
    var topicLineupClubDestination: ((Int) -> AnyView)? {
        get { self[TopicLineupClubDestinationKey.self] }
        set { self[TopicLineupClubDestinationKey.self] = newValue }
    }
}

/// Apple Maps link for a topic stop: coordinate when present, else the address text.
enum TopicStopMapsLink {
    static func url(for node: TopicNode) -> URL? {
        if let lat = node.latitude, let lng = node.longitude, (-90...90).contains(lat), (-180...180).contains(lng), lat != 0 || lng != 0 {
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "ll", value: "\(lat),\(lng)"), URLQueryItem(name: "q", value: node.name)]
            return components?.url
        }
        return HomeFeedMapsLink.url(for: node.address)
    }
}

private struct TopicLineupMerchantDestinationKey: EnvironmentKey { static let defaultValue: ((Int) -> AnyView)? = nil }
extension EnvironmentValues {
    /// Public merchant home for a partner owner member id. Nil hides 查看 on merchant partner pages.
    var topicLineupMerchantDestination: ((Int) -> AnyView)? {
        get { self[TopicLineupMerchantDestinationKey.self] }
        set { self[TopicLineupMerchantDestinationKey.self] = newValue }
    }
}
