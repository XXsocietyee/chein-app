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

/// Team and companion seats already on the registration detail. Seats open the existing
/// journey lobby. Club join stays on the club page, which already sends through
/// `ClubActionCoordinator`. This view does not follow, pay, refund, or create an order.
struct ProfileOrderTeamSeatClubSection: View {
    let order: ProfileOrder
    @EnvironmentObject private var session: AppSession
    @Environment(\.mpParity) private var mpParity

    var body: some View {
        if order.teamOpen || order.seatsOpen || order.club != nil {
            Section {
                if order.teamOpen {
                    Text("orderDetail.inviteTeammates")
                        .cyText(.body)
                        .accessibilityIdentifier("profile.order.teamOpen")
                }
                if order.seatsOpen {
                    seatsEntry
                }
                if let club = order.club {
                    clubRow(club)
                }
            }
        }
    }

    /// The coordinator already sends join, apply, and leave from the club page. Follow is not one of those actions, so this row does not post it.
    @ViewBuilder private func clubRow(_ club: ProfileOrderClub) -> some View {
        let name = Text(verbatim: club.name.isEmpty ? "—" : club.name).cyText(.body)
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

    @ViewBuilder private var seatsEntry: some View {
        if mpParity.journeySeats != nil {
            NavigationLink {
                MPParityDestination(route: .journeySeats(registrationID: String(order.id)))
            } label: {
                Text("orderDetail.seatsEntry").cyText(.body)
            }
            .accessibilityIdentifier("profile.order.seatsOpen")
        } else {
            Text("orderDetail.seatsEntry")
                .cyText(.body)
                .accessibilityIdentifier("profile.order.seatsOpen")
        }
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
