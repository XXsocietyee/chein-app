import SwiftUI

/// Source pages/merchant/marketing/index.wxml: hero, permission-filtered tools, my content,
/// coupon deck, cooperation banner and the all-zero empty state. Counts never render as a dash and
/// no funnel percentage is shown; the only ratio is the same-batch "verified after receiving" coupon rate.
@MainActor struct MerchantMarketingHomeSections: View {
    let home: MerchantMarketingHome
    let access: MerchantMarketingAccess
    var onRetry: () -> Void = {}
    var onInsight: () -> Void = {}
    var onRoute: (MerchantInsightDestination) -> Void = { _ in }
    var body: some View {
        if home.isAllZero {
            Section {
                Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.empty.title")).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("merchantOps.marketing.empty")
                if access.canManageProjects {
                    Button(MerchantOpsCopy.text("merchantOps.marketing.empty.cta")) { onRoute(.content) }
                        .buttonStyle(.cyPrimary)
                        .accessibilityIdentifier("merchantOps.marketing.firstContent")
                }
            }
        }
        hero
        // Source tiles: up to four round tools under the hero.
        Section {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                if access.canReadMarketing {
                    QuestifyRoundAction(title: tool("merchantOps.marketing.tool.insight"), systemImage: "chart.bar.xaxis", action: onInsight)
                        .accessibilityIdentifier("merchantOps.marketing.tool.insight")
                }
                if access.canManageCoop {
                    QuestifyRoundAction(title: tool("merchantOps.marketing.tool.decor"), systemImage: "paintbrush") { onRoute(.decoration) }
                        .accessibilityIdentifier("merchantOps.marketing.tool.decor")
                }
                QuestifyRoundAction(title: tool("merchantOps.marketing.tool.topic"), systemImage: "square.and.pencil") { onRoute(.content) }
                    .accessibilityIdentifier("merchantOps.marketing.tool.topic")
                QuestifyRoundAction(title: tool("merchantOps.marketing.tool.activity"), systemImage: "calendar.badge.plus") { onRoute(.topicCooperation) }
                    .accessibilityIdentifier("merchantOps.marketing.tool.activity")
            }
            .padding(.vertical, CYSpacing.xs)
        }
        // Source `.mine`: three number tiles, the number is the graphic, label underneath.
        Section(MerchantOpsCopy.text("merchantOps.marketing.myContent")) {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                mineTile("merchantMarketing.topics", home.content.topicCount)
                mineTile("merchantMarketing.exploration", home.content.freeExploreCount)
                mineTile("merchantMarketing.activities", home.content.activityCount)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        Section("merchantMarketing.coupons") {
            if home.hasCouponDeck {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.live %lld", home.coupons.couponCount)).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.counts %lld %lld", home.coupons.received, home.coupons.verified)).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    if let rate = home.verifiedAfterReceivePercent {
                        Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.rate %lld", rate)).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                            .accessibilityIdentifier("merchantOps.marketing.coupon.rate")
                    }
                }
                .cyCardSurface(variant: .accentTint, radius: CYRadius.lg, padding: CYSpacing.lg)
                .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: 0, bottom: CYSpacing.xs, trailing: 0))
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.marketing.couponDeck")
                LabeledContent("merchantMarketing.claimed", value: String(home.coupons.received))
                LabeledContent("merchantMarketing.redeemed", value: String(home.coupons.verified))
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.empty.title")).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coupon.empty.body")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("merchantOps.marketing.coupon.empty")
            }
        }
        Section(MerchantOpsCopy.text("merchantOps.marketing.coop.title")) {
            Button { onRoute(.topicCooperation) } label: {
                LabeledContent {
                    if home.recruiting.count > 0 {
                        Text(verbatim: MerchantOpsCopy.text("merchantOps.marketing.coop.count %lld", home.recruiting.count))
                            .font(CYTypography.numericBody)
                            .monospacedDigit()
                            .foregroundStyle(CYColor.textPrimary)
                    }
                } label: {
                    Text("merchant.marketing.enterCoop").font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                }
            }.accessibilityIdentifier("merchantOps.marketing.coop")
        }
    }
    /// MerchantOps copy is already resolved for the current language; wrap it for QuestifyRoundAction.
    private func tool(_ key: String) -> LocalizedStringKey { LocalizedStringKey(MerchantOpsCopy.text(key)) }
    private func mineTile(_ key: String, _ count: Int) -> some View {
        VStack(spacing: CYSpacing.xs) {
            Text(verbatim: String(count))
                .font(CYTypography.dataXL)
                .monospacedDigit()
                .foregroundStyle(CYColor.textPrimary)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(LocalizedStringKey(key)).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
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
                    .font(CYTypography.body).foregroundStyle(CYColor.textTertiary)
                Text(verbatim: heroDisplay)
                    .font(CYTypography.data2XL).foregroundStyle(CYColor.textPrimary)
                    .minimumScaleFactor(0.6).lineLimit(1)
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
                .font(CYTypography.label).foregroundStyle(CYColor.textTertiary)
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
                .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).accessibilityIdentifier("merchantOps.insight.delta")
        }
        if isEmpty {
            Text(verbatim: MerchantOpsCopy.text("merchantOps.insight.empty.body")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
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
