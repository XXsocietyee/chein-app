import SwiftUI

/// Source scene-member-order-detail sections after 支付明细: 订单进度 timeline, 支付信息
/// (报名信息 when free, paid orders only), 报名人信息 and 凭证与有效期. Presentation only:
/// the enclosing ProfileReadScreen owns the read; nothing here sends a request.
struct ProfileOrderSourceDetailSections: View {
    let order: ProfileOrder
    var body: some View {
        Section("orderLifecycle.timeline.title") {
            ForEach(order.sourceTimeline()) { step in
                ProfileOrderTimelineStepRow(step: step)
            }
        }.accessibilityIdentifier("profile.order.detail.timeline")
        if order.showsSourcePaymentInfo {
            Section(LocalizedStringKey(order.isSourceFreeOrder ? "profile.orderParity.section.registrationInfo" : "profile.orderParity.section.paymentInfo")) {
                if let time = order.sourcePaymentTimeText {
                    LabeledContent(LocalizedStringKey(order.isSourceFreeOrder ? "profile.orderParity.registrationTime" : "profile.orders.paymentTime")) {
                        Text(verbatim: time).monospacedDigit()
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
        if order.realName?.isEmpty == false || order.phone?.isEmpty == false || order.sourceParticipateDateText != nil {
            Section("profile.orderParity.section.registrant") {
                ProfileOptionalRow(key: "profile.participants.name", value: order.realName)
                ProfileOptionalRow(key: "profile.orderParity.mobile", value: order.phone)
                ProfileOptionalRow(key: "profile.orderParity.registrationDate", value: order.sourceParticipateDateText)
            }
        }
        if order.sourceVerificationTimeText != nil || order.sourceExpiresAtText != nil {
            Section("profile.orderParity.section.voucher") {
                ProfileOptionalRow(key: "profile.orderParity.verifiedAt", value: order.sourceVerificationTimeText)
                ProfileOptionalRow(key: "profile.orderParity.entitlementExpires", value: order.sourceExpiresAtText)
            }
        }
        if let party = order.party?.text {
            Section("profile.order.party") {
                Text(verbatim: party).accessibilityIdentifier("profile.order.party")
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
            }
            if order.seatsOpen, bindings.journeySeats != nil {
                Section("orderDetail.seatsEntry") {
                    NavigationLink { MPParityDestination(route: .journeySeats(registrationID: String(order.id))) } label: {
                        LabeledContent("orderDetail.seats.manage") {
                            Text("orderDetail.seats.count \(order.orderNum ?? 0)")
                        }
                    }
                    .accessibilityIdentifier("profile.order.seatsOpen")
                }
            }
            if let club = order.club {
                Section("orderDetail.club.section") {
                    LabeledContent("profile.order.club") {
                        Text(verbatim: club.name.isEmpty ? "—" : club.name)
                    }
                    .accessibilityIdentifier("profile.order.club")
                    if let leader = club.leaderMemberID, leader > 0, !followed {
                        Button("orderDetail.club.follow") { Task { await follow(leader) } }
                            .accessibilityIdentifier("profile.order.follow")
                    }
                }
            }
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
struct ProfileOrderConsentSection: View {
    let order: ProfileOrder
    @EnvironmentObject private var session: AppSession
    @State private var offer: ComplianceMarketingConsent?

    var body: some View {
        Group {
            if let offer {
                Section("profile.order.consent") {
                    if let name = offer.merchantName, !name.isEmpty {
                        Text(verbatim: name).accessibilityIdentifier("profile.order.consent.name")
                    }
                    Button("profile.order.follow") { Task { await follow(offer.merchantOwnerMemberId) } }
                        .accessibilityIdentifier("profile.order.consent.follow")
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

    private func follow(_ memberID: Int) async {
        guard memberID > 0, let base = session.currentRuntimeDependencyContext?.baseURL else { return }
        let service = MemberRound2Service(baseURL: base, token: { [weak session] in session?.token }, transport: session.runtimeHTTPTransport)
        _ = await service.followClubOwner(memberID: memberID)
    }
}

private struct ProfileOrderTimelineStepRow: View {
    let step: ProfileOrderTimelineStep
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: step.state == .done ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(step.state == .done ? CYColor.brand : CYColor.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let label = step.label { Text(verbatim: label) }
                else if let key = step.labelKey { Text(LocalizedStringKey(key)) }
                if let time = step.time { Text(verbatim: time).cyText(.meta).foregroundStyle(CYColor.textSecondary).monospacedDigit() }
                else if let key = step.timeKey { Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.order.timeline.\(step.id)")
    }
}
