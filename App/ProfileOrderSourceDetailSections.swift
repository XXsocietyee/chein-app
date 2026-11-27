import SwiftUI

/// Source scene-member-order-detail sections after 支付明细: 订单进度 timeline, 支付信息
/// (报名信息 when free, paid orders only), 报名人信息 and 凭证与有效期. Presentation only:
/// the enclosing ProfileReadScreen owns the read; nothing here sends a request.
struct ProfileOrderSourceDetailSections: View {
    let order: ProfileOrder
    /// i18n r2: China-time `yyyy-MM-dd HH:mm` reads `Nov 27, 2026, 3:05 PM` in English (same wall clock).
    @Environment(\.locale) private var locale
    private func civil(_ text: String?) -> String? { text.map { LocaleDisplay.civil($0, locale: locale) } }
    /// mp-mine r3: MP scene-member-order-detail order — 和队友一起出发 before 订单进度, 商家消息 before 支付信息,
    /// 发票 before 报名人信息. The host passes those sections in; nil keeps the slot empty.
    var beforeTimeline: AnyView? = nil
    var beforePaymentInfo: AnyView? = nil
    var beforeRegistrant: AnyView? = nil
    func mpSlots(beforeTimeline: AnyView?, beforePaymentInfo: AnyView?, beforeRegistrant: AnyView?) -> ProfileOrderSourceDetailSections {
        var copy = self
        copy.beforeTimeline = beforeTimeline; copy.beforePaymentInfo = beforePaymentInfo; copy.beforeRegistrant = beforeRegistrant
        return copy
    }
    var body: some View {
        if let beforeTimeline { beforeTimeline }
        Section("orderLifecycle.timeline.title") {
            ForEach(order.sourceTimeline()) { step in
                ProfileOrderTimelineStepRow(step: step)
            }
        }.accessibilityIdentifier("profile.order.detail.timeline")
        if let beforePaymentInfo { beforePaymentInfo }
        if order.showsSourcePaymentInfo {
            Section(LocalizedStringKey(order.isSourceFreeOrder ? "profile.orderParity.section.registrationInfo" : "profile.orderParity.section.paymentInfo")) {
                if let time = order.sourcePaymentTimeText {
                    LabeledContent(LocalizedStringKey(order.isSourceFreeOrder ? "profile.orderParity.registrationTime" : "profile.orders.paymentTime")) {
                        Text(verbatim: LocaleDisplay.civil(time, locale: locale)).monospacedDigit()
                    }
                }
                if let key = order.sourcePaymentTypeLabelKey {
                    LabeledContent("profile.orders.paymentType") { Text(LocalizedStringKey(key)) }
                } else {
                    ProfileOptionalRow(key: "profile.orders.paymentType", value: order.paymentTypeLabel)
                }
                if order.showsSourceWechatPay, let amount = order.wechatPaymentAmount {
                    LabeledContent("profile.orderParity.wechatPaid") { Text(verbatim: OwnedOrderMoneyText.string(amount)).monospacedDigit() }
                }
                if order.showsSourcePointPay, let amount = order.pointPaymentAmount {
                    LabeledContent("profile.orderParity.pointsPaid") { Text(verbatim: OwnedOrderMoneyText.string(amount)).monospacedDigit() }
                }
                ProfileOptionalRow(key: "profile.orderParity.transactionID", value: order.detailFacts.transactionID)
            }.accessibilityIdentifier("profile.order.detail.paymentInfo")
        }
        if let beforeRegistrant { beforeRegistrant }
        if order.realName?.isEmpty == false || order.phone?.isEmpty == false || order.sourceParticipateDateText != nil {
            Section("profile.orderParity.section.registrant") {
                ProfileOptionalRow(key: "profile.participants.name", value: order.realName)
                ProfileOptionalRow(key: "profile.orderParity.mobile", value: order.phone)
                ProfileOptionalRow(key: "profile.orderParity.registrationDate", value: civil(order.sourceParticipateDateText))
            }
        }
        if order.sourceVerificationTimeText != nil || order.sourceExpiresAtText != nil {
            Section("profile.orderParity.section.voucher") {
                ProfileOptionalRow(key: "profile.orderParity.verifiedAt", value: civil(order.sourceVerificationTimeText))
                ProfileOptionalRow(key: "profile.orderParity.entitlementExpires", value: civil(order.sourceExpiresAtText))
            }
        }
        if let party = ProfileOrderSettlementCopy.party(order.party) {
            Section("profile.order.party") {
                party.accessibilityIdentifier("profile.order.party")
            }
        }
        if order.walletExpired {
            Section {
                Text("profile.order.walletExpired").accessibilityIdentifier("profile.order.walletExpired")
            }
        }
    }
}

/// Team, open seats, and club from the order. Follow posts `api/user/follow/action` and does not pay.
/// FIN-17-4: MP order detail 和队友一起出发 (D:125-145, `startOrderTeam` → team create), 同行席位
/// (D:205-214, `goSeats` → `subpackageJourney/pages/seats`) and the host club follow (`followClub` → /api/user/follow/action).
/// The club row opens the club page (which sends join / apply / leave through `ClubActionCoordinator`) when it is configured.
struct ProfileOrderTeamSeatClubSection: View {
    let order: ProfileOrder
    @EnvironmentObject private var session: AppSession
    @Environment(\.mpParity) private var bindings
    @State private var followed = false

    var body: some View {
        Group {
            if order.teamOpen, let activityID = order.ownerID, activityID > 0 {
                Section {
                    NavigationLink { SessionTeamCreateView(activityID: activityID, registrationID: order.id) } label: {
                        Label("orderDetail.inviteTeammates", systemImage: "person.2.badge.plus")
                    }
                    .accessibilityIdentifier("profile.order.teamOpen")
                } header: {
                    Text("orderDetail.teamAndSeats")
                } footer: {
                    Text("orderDetail.team.note")
                }
            } else if order.teamOpen {
                Section {
                    Text("orderDetail.inviteTeammates")
                        .accessibilityIdentifier("profile.order.teamOpen")
                }
            }
            if order.seatsOpen {
                Section("orderDetail.seatsEntry") {
                    if bindings.journeySeats != nil {
                        NavigationLink { MPParityDestination(route: .journeySeats(registrationID: String(order.id))) } label: {
                            LabeledContent("orderDetail.seats.manage") {
                                Text("orderDetail.seats.count \(order.orderNum ?? 0)")
                            }
                        }
                        .accessibilityIdentifier("profile.order.seatsOpen")
                    } else {
                        LabeledContent("orderDetail.seats.manage") {
                            Text("orderDetail.seats.count \(order.orderNum ?? 0)")
                        }
                        .accessibilityIdentifier("profile.order.seatsOpen")
                    }
                }
            }
            if let club = order.club {
                Section("orderDetail.club.section") {
                    clubRow(club)
                    if let leader = club.leaderMemberID, leader > 0, !followed {
                        Button("orderDetail.club.follow") { Task { await follow(leader) } }
                            .accessibilityIdentifier("profile.order.follow")
                    }
                }
            }
        }
    }

    @ViewBuilder private func clubRow(_ club: ProfileOrderClub) -> some View {
        let name = Text(verbatim: club.name.isEmpty ? "—" : club.name)
        if session.clubActionCoordinator.isConfigured {
            NavigationLink {
                ClubDetailView(
                    id: club.id,
                    reader: session,
                    actionCoordinator: session.clubActionCoordinator,
                    management: session.clubManagementContext,
                    community: session.clubCommunityContext,
                    publicRoster: session.clubPublicRosterReader
                )
            } label: {
                LabeledContent("profile.order.club") { name }
            }
            .accessibilityIdentifier("profile.order.club")
        } else {
            LabeledContent("profile.order.club") { name }
                .accessibilityIdentifier("profile.order.club")
        }
    }

    private func follow(_ memberID: Int) async {
        guard let base = session.currentRuntimeDependencyContext?.baseURL else { return }
        let service = MemberRound2Service(baseURL: base, token: { [weak session] in session?.token }, transport: session.runtimeHTTPTransport)
        let reply = await service.followClubOwner(memberID: memberID)
        if case .ok = reply { followed = true }
    }
}

/// One unpaid marketing-consent row for this order's merchant, after the existing marketing GET.
/// Display only. The consent write is not sent from this page.
struct ProfileOrderConsentSection: View {
    let order: ProfileOrder
    @EnvironmentObject private var session: AppSession
    @State private var offer: ComplianceMarketingConsent?

    var body: some View {
        Group {
            if let offer {
                Section("orderDetail.merchantConsent.section") {
                    if let name = offer.merchantName, !name.isEmpty {
                        Text(verbatim: name)
                            .cyText(.body)
                            .accessibilityIdentifier("profile.order.consent.name")
                    }
                    Text("profile.order.consent")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityIdentifier("profile.order.consent")
            }
        }
        .task { if offer == nil { await load() } }
    }

    private func load() async {
        guard let pair = session.complianceSignupContext() else { return }
        let rows = (try? await pair.0.marketing(session: pair.1)) ?? []
        offer = ProfileOrderConsentOffer.pick(rows: rows, ownerMemberID: order.merchantOwnerMemberID)
    }
}

private struct ProfileOrderTimelineStepRow: View {
    let step: ProfileOrderTimelineStep
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: step.state == .done ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(step.state == .done ? CYColor.brand : CYColor.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let label = step.label { Text(verbatim: label) }
                else if let key = step.labelKey { Text(LocalizedStringKey(key)) }
                if let time = step.time { Text(verbatim: LocaleDisplay.civil(time, locale: locale)).cyText(.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit() }
                else if let key = step.timeKey { Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.order.timeline.\(step.id)")
    }
}

/// R9-MEM-17-2: MP order detail (scene-member-order-detail D:110-123 settlement, D:260-275 party) copy keyed in the
/// catalog so English does not show Core's Chinese. Core keeps its zh text; unknown text stays verbatim.
enum ProfileOrderSettlementCopy {
    private static let stageKeys: [String: String] = [
        "退款审核中": "profile.order.settlement.stage.underReview",
        "已批准，等待原路退回": "profile.order.settlement.stage.payoutPending",
        "人工退款处理中": "profile.order.settlement.stage.manualPayout",
        "已原路退回": "profile.order.settlement.stage.completed",
        "退款未通过": "profile.order.settlement.stage.rejected",
        "售后处理中": "profile.order.settlement.stage.manualReview",
        "退款状态待确认": "profile.order.settlement.stage.unknown"
    ]
    private static let rowKeys: Set<String> = ["pending", "processing", "completed", "total", "entitlement"]

    static func stage(_ text: String) -> Text {
        if let key = stageKeys[text] { return Text(LocalizedStringKey(key)) }
        return Text(verbatim: text)
    }

    static func label(_ row: ProfileOrderSettlementView.Row) -> Text {
        if rowKeys.contains(row.key) { return Text(LocalizedStringKey("profile.order.settlement.row." + row.key)) }
        return Text(verbatim: row.label)
    }

    static func value(_ row: ProfileOrderSettlementView.Row) -> Text {
        if row.value == "金额待确认" { return Text("profile.order.settlement.amountPending") }
        return Text(verbatim: row.value)
    }

    /// Same rule as `ProfileOrderParty.text`: nothing without children.
    static func party(_ party: ProfileOrderParty?) -> Text? {
        guard let party, party.childCount > 0 else { return nil }
        let counts = Text("profile.order.party.counts \(party.adultCount) \(party.childCount)")
        if let age = party.childAge, !age.isEmpty {
            return counts + Text("profile.order.party.childAge \(age)")
        }
        return counts
    }
}
