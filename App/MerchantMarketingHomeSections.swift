import SwiftUI

/// Parity marketing P1: the 营销 root's navigations that have no `MerchantInsightDestination` (source
/// index.js:570-603): 发活动 → activity publisher, 我的内容 / 管理 → my projects, coupon deck → coupon management,
/// 合作机会 → coop center. Supplied by the merchant root; nil keeps the element static (never a dead tap).
struct MerchantMarketingLinks {
    let activityPublisher: @MainActor () -> AnyView
    let projects: @MainActor () -> AnyView
    let coupons: @MainActor () -> AnyView
    let coopCenter: (@MainActor () -> AnyView)?
}
private struct MerchantMarketingLinksKey: EnvironmentKey { static let defaultValue: MerchantMarketingLinks? = nil }
enum MerchantMarketingPush: Hashable, Identifiable {
    case activity, projects, coupons, coopCenter
    var id: Self { self }
}
extension MerchantMarketingLinks {
    @MainActor @ViewBuilder func destination(_ push: MerchantMarketingPush) -> some View {
        switch push {
        case .activity: activityPublisher()
        case .projects: projects()
        case .coupons: coupons()
        case .coopCenter: if let coopCenter { coopCenter() }
        }
    }
}
extension EnvironmentValues {
    var merchantMarketingLinks: MerchantMarketingLinks? {
        get { self[MerchantMarketingLinksKey.self] }
        set { self[MerchantMarketingLinksKey.self] = newValue }
    }
}

/// Source pages/merchant/marketing/index.wxml: hero, permission-filtered tools, my content,
/// coupon deck, cooperation banner and the all-zero empty state. Counts never render as a dash and
/// no funnel percentage is shown; the only ratio is the same-batch "verified after receiving" coupon rate.
@MainActor struct MerchantMarketingHomeSections: View {
    let home: MerchantMarketingHome
    let access: MerchantMarketingAccess
    var onRetry: () -> Void = {}
    var onInsight: () -> Void = {}
    var onRoute: (MerchantInsightDestination) -> Void = { _ in }
    @Environment(\.merchantMarketingLinks) private var links
    /// Pushes are owned by the List's host (`MerchantMarketingView`): a destination modifier inside a List is ignored.
    var onPush: (MerchantMarketingPush) -> Void = { _ in }
    var body: some View {
        hero
        // Source tiles: up to four round tools under the hero. SR2-15 (`182:8065`): four distinct glyphs, as the
        // Figma's Icon/chart · Icon/store · Icon/route · Icon/cal.
        Section {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                if access.canReadMarketing {
                    QuestifyRoundAction(title: tool("merchantOps.marketing.tool.insight"), systemImage: "chart.bar.xaxis", action: onInsight)
                        .accessibilityIdentifier("merchantOps.marketing.tool.insight")
                }
                if access.canManageCoop {
                    QuestifyRoundAction(title: tool("merchantOps.marketing.tool.decor"), systemImage: "storefront") { onRoute(.decoration) }
                        .accessibilityIdentifier("merchantOps.marketing.tool.decor")
                }
                QuestifyRoundAction(title: tool("merchantOps.marketing.tool.topic"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") { onRoute(.content) }
                    .accessibilityIdentifier("merchantOps.marketing.tool.topic")
                // Parity marketing P1: 发活动 (not 接活动) opens the activity publisher and needs canManageProjects.
                if access.canManageProjects, links != nil {
                    QuestifyRoundAction(title: tool("merchantOps.marketing.tool.activity"), systemImage: "calendar.badge.plus") { onPush(.activity) }
                        .accessibilityIdentifier("merchantOps.marketing.tool.activity")
                }
            }
            .padding(.vertical, CYSpacing.xs)
        }
        // Source `.mine` (M-10, owner 2026-11-02): two tiles 主题 · 活动; free explore counts under 主题.
        // A tile opens the list when it has items, the matching create flow when it is 0 (canManageProjects).
        Section {
            // MC7-10-5 (marketing/index.wxml:79-82): an all-zero home shows 还没有主题和活动 in place of the tiles.
            if home.isAllZero {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.empty.title")).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        .accessibilityIdentifier("merchantOps.marketing.empty")
                    if access.canManageProjects {
                        Button(MerchantOpsCopy.text("merchantOps.marketing.empty.cta")) { onRoute(.content) }
                            .buttonStyle(.cyPrimary)
                            .accessibilityIdentifier("merchantOps.marketing.firstContent")
                    }
                }
            } else {
                HStack(alignment: .top, spacing: CYSpacing.sm) {
                    mineTile("merchantMarketing.topics", home.content.topicCount + home.content.freeExploreCount, create: { onRoute(.content) })
                    mineTile("merchantMarketing.activities", home.content.activityCount, create: links == nil ? nil : { onPush(.activity) })
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        } header: {
            HStack {
                Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.myContent"))
                Spacer(minLength: CYSpacing.sm)
                if access.canManageProjects, links != nil {
                    Button { onPush(.projects) } label: { Text("merchant.marketing.manage").cyText(.label) }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("merchantOps.marketing.manage")
                }
            }
        }
        Section("merchantMarketing.coupons") {
            if home.hasCouponDeck {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.live %lld", home.coupons.couponCount)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.counts %lld %lld", home.coupons.received, home.coupons.verified)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    if let rate = home.verifiedAfterReceivePercent {
                        Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.rate %lld", rate)).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                            .accessibilityIdentifier("merchantOps.marketing.coupon.rate")
                    }
                }
                .cyCardSurface(variant: .accentTint, radius: CYRadius.lg, padding: CYSpacing.lg)
                .contentShape(Rectangle())
                // Parity marketing P1: the deck opens coupon management (source coupon?scope=MERCHANT).
                .onTapGesture { if links != nil { onPush(.coupons) } }
                .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.marketing.couponDeck")
                .accessibilityAddTraits(links != nil ? .isButton : [])
                LabeledContent("merchantMarketing.claimed", value: String(home.coupons.received))
                LabeledContent("merchantMarketing.redeemed", value: String(home.coupons.verified))
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.empty.title")).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.empty.body")).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.marketing.coupon.empty")
            }
        }
        Section(MerchantOpsCopy.text("merchantOps.marketing.coop.title")) {
            // Parity marketing P1: the row's open-opportunity count comes from the coop center, so it opens there.
            Button { if links?.coopCenter != nil { onPush(.coopCenter) } else { onRoute(.topicCooperation) } } label: {
              VStack(alignment: .leading, spacing: CYSpacing.sm) {
                // Round 2 MP asset (marketing/index.wxml:135): the coop entry leads with merchant_coop_banner.jpg.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .overlay { MPAsset.BannerCover.merchantCoopBanner.resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityHidden(true)
                LabeledContent {
                    if home.recruiting.count > 0 {
                        Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coop.count %lld", home.recruiting.count))
                            .cyText(.numericBody)
                            .monospacedDigit()
                            .foregroundStyle(CYColor.textPrimary)
                    }
                } label: {
                    Text("merchant.marketing.enterCoop").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                }
              }
            }.accessibilityIdentifier("merchantOps.marketing.coop")
        }
    }
    /// MerchantOps copy is already resolved for the current language; wrap it for QuestifyRoundAction.
    private func tool(_ key: String) -> LocalizedStringKey { LocalizedStringKey(MerchantOpsCopy.text(key)) }
    private func mineTile(_ key: String, _ count: Int, create: (() -> Void)?) -> some View {
        let action: (() -> Void)? = access.canManageProjects
            ? (count > 0 ? (links != nil ? { onPush(.projects) } : nil) : create) : nil
        return Button { action?() } label: { mineTileLabel(key, count) }
            .buttonStyle(.plain)
            .disabled(action == nil)
            .accessibilityIdentifier("merchantOps.marketing.tile." + key)
    }
    private func mineTileLabel(_ key: String, _ count: Int) -> some View {
        VStack(spacing: CYSpacing.xs) {
            Text(verbatim: String(count))
                .cyText(.display)
                .monospacedDigit()
                .foregroundStyle(CYColor.textPrimary)
                .cyWrapText(alignment: .center)
            Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        .cyCardSurface(variant: .surface, radius: CYRadius.md, padding: CYSpacing.md)
        .accessibilityElement(children: .combine)
    }
    /// Hero number: when the analytics block (or its SIGNUP stage) is missing the value is UNKNOWN, shown as an em dash, never 0.
    private var heroDisplay: String {
        home.analytics?.stage("SIGNUP") == nil ? "\u{2014}" : home.heroValue
    }
    /// Source `.hero`: left-aligned label, one large tabular number, quiet sub line.
    @ViewBuilder private var hero: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.hero.label %lld", MerchantMarketingHome.windowDays))
                    .cyText(.body).foregroundStyle(CYColor.textTertiary)
                Text(verbatim: heroDisplay)
                    .cyText(.data2XL).foregroundStyle(CYColor.textPrimary)
                    .cyWrapText(alignment: .center)
                    .accessibilityIdentifier("merchantOps.marketing.hero.value")
                Group {
                    if home.analytics == nil {
                        Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.analytics.unavailable")).foregroundStyle(CYColor.warningText)
                    } else {
                        switch home.heroSubtitle {
                        case .noSignup: Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.hero.noSignup"))
                        case .noVerification: Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.hero.noVerification"))
                        case .verified(let count): Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.hero.verified %@", count))
                        }
                    }
                }
                .cyText(.label).foregroundStyle(CYColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, CYSpacing.sm)
            .accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.marketing.hero")
            if home.analytics == nil {
                Button(MerchantOpsCopy.text("merchantOps.marketing.analytics.retry"), action: onRetry)
                    .buttonStyle(.cySecondary)
                    .accessibilityIdentifier("merchantOps.marketing.analytics.retry")
            }
        }
    }
}

/// Source ai-insight value card delta and the explicit all-zero guidance.
struct MerchantInsightParityRows: View {
    let facts: MerchantMarketingValue
    let isEmpty: Bool
    var onCoopCenter: (() -> Void)? = nil
    var body: some View {
        if let delta = MerchantInsightParity.visitorDelta(facts) {
            Text(verbatim: MerchantOpsCopy.text("merchantOps.insight.delta %@", (delta > 0 ? "+" : "") + String(delta)))
                .cyText(.meta).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("merchantOps.insight.delta")
        }
        if isEmpty {
            Text(verbatim: MerchantOpsCopy.text("merchantOps.insight.empty.body")).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                .accessibilityIdentifier("merchantOps.insight.empty")
            if let onCoopCenter,
               let cta = MerchantInsightParity.emptyCTATitle(isEmpty: isEmpty, canOpenCoopCenter: true) {
                Button(action: onCoopCenter) {
                    Text(verbatim: cta)
                }
                .accessibilityIdentifier("merchantOps.insight.emptyGuidance.cta")
            }
        }
    }
}
