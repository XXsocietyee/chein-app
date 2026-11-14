import SwiftUI

/// OWN-U02-04. The source line stays visible. Continue-current is local. Diff and save-as-new are not offered without a server action.
struct SourceLineageSection: View {
    let revisionID: String?
    @State private var continued = false

    private var facts: SourceLineagePresentation { SourceLineagePresentation(sourceContentRevisionId: revisionID) }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: W8Text.t("来源版本", "Source version")).font(CYTypography.meta)
            Text(verbatim: facts.historyLine(chinese: W8Text.isChinese))
                .font(CYTypography.bodyCompact)
                .accessibilityIdentifier("sourceLineage.identity")
            labeled(W8Text.t("继续当前版本", "Continue the current version"),
                    facts.continueCurrent ? (continued ? W8Text.t("继续使用这一版", "Staying on this version") : W8Text.t("可以继续", "Available")) : WP09Copy.unknown)
            labeled(W8Text.t("查看新版差异", "View the new-version diff"), WP09Copy.unknown)
            labeled(W8Text.t("另存新草稿", "Save as a new draft"), WP09Copy.unknown)
            if facts.continueCurrent {
                Button {
                    continued = true
                } label: { Text(verbatim: W8Text.t("继续当前版本", "Continue the current version")) }
                .accessibilityIdentifier("sourceLineage.continue")
            }
        }
        .accessibilityIdentifier("sourceLineage.section")
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: title).font(CYTypography.meta)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: value).font(CYTypography.meta)
        }
    }
}

/// OWN-U06-02 and OWN-U06-04 on the team page. Missing facts are an em dash. Club headcount is not this session's participant count.
struct TeamRoleAndSharedSection: View {
    let role: TeamPlayRoleFacts?
    let shared: TeamSharedOutcome?

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: W8Text.t("我的角色与私密线索", "My role and private clues")).font(CYTypography.cardTitle)
                .accessibilityIdentifier("team.role.section")
            labeled(W8Text.t("我的角色", "My role"), role?.myRoleLabel)
            labeled(W8Text.t("我的任务", "My task"), role?.myTask)
            labeled(W8Text.t("我能贡献的证据", "Evidence I can contribute"), role?.myEvidence.joined(separator: "\n"))
            labeled(W8Text.t("当前等谁", "Who is waited on"), role?.waitingOn)
            labeled(W8Text.t("只属于我的线索", "Clues that are only mine"), role?.myPrivateClues.joined(separator: "\n"))
            Text(verbatim: W8Text.t("组织者与共同成果", "Organizer and shared results")).font(CYTypography.cardTitle)
                .accessibilityIdentifier("team.shared.section")
            labeled(W8Text.t("当前谁需要处理", "Who needs to act"), shared?.whoMustAct)
            labeled(W8Text.t("章节放行", "Chapter release"), shared?.chapterRelease)
            Text(verbatim: shared?.pausedLine(chinese: W8Text.isChinese) ?? WP09Copy.unknown).font(CYTypography.meta)
                .accessibilityIdentifier("team.shared.paused")
            labeled(W8Text.t("共同成果", "Shared result"), shared?.summary)
            labeled(W8Text.t("统计范围", "Population"), shared?.population)
            labeled(W8Text.t("时间窗", "Time window"), shared?.timeWindow)
            labeled(W8Text.t("俱乐部人数", "Club headcount"), shared?.countLine(shared?.clubHeadcount))
            labeled(W8Text.t("本局参与人数", "People in this session"), shared?.countLine(shared?.sessionParticipants))
        }
        .accessibilityIdentifier("team.roleAndShared")
    }

    private func labeled(_ title: String, _ value: String?) -> some View {
        let shown = value?.isEmpty == false ? value! : WP09Copy.unknown
        return HStack(alignment: .firstTextBaseline) {
            Text(verbatim: title).font(CYTypography.meta)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: shown).font(CYTypography.bodyCompact).multilineTextAlignment(.trailing)
        }
    }
}

/// OWN-U07-01. Amounts come from the server. Mixed tickets do not borrow one ticket's terms.
struct OrderDeliverySection: View {
    let delivery: OrderDeliveryFacts?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: W8Text.t("交付", "Delivery")).font(CYTypography.cardTitle)
            if let delivery {
                Text(verbatim: delivery.headline(chinese: W8Text.isChinese))
                    .accessibilityIdentifier("order.delivery.headline")
                if !delivery.mixedTickets {
                    labeled(W8Text.t("谁受益", "Who benefits"), delivery.beneficiaryKind)
                    labeled(W8Text.t("服务开始", "Service starts"), delivery.serviceStartAt)
                    labeled(W8Text.t("服务结束", "Service ends"), delivery.serviceEndAt)
                }
                if let refund = delivery.refundLine(chinese: W8Text.isChinese) {
                    labeled(W8Text.t("退款规则", "Refund rule"), refund)
                }
                labeled(W8Text.t("金额", "Amount"), delivery.amountLine)
            } else {
                Text(verbatim: WP09Copy.unknown).accessibilityIdentifier("order.delivery.unknown")
            }
        }
        .accessibilityIdentifier("order.delivery.section")
    }

    private func labeled(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(verbatim: title).font(CYTypography.meta)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: value?.isEmpty == false ? value! : WP09Copy.unknown).font(CYTypography.meta)
        }
    }
}

/// OWN-U07-02. Checking, received, pending, cancelled, failed and unknown stay separate. SDK success does not unlock a pending order.
struct OrderPaymentReturnSection: View {
    let loading: Bool
    let payment: Int?
    let registration: Int?
    let channels: [String]?
    private var phase: PaymentReturnPhase { PaymentReturnPhase(loading: loading, payment: payment, registration: registration) }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: W8Text.t("支付返回后核对", "Check the order after payment")).font(CYTypography.cardTitle)
            Text(verbatim: phase.title(chinese: W8Text.isChinese))
                .accessibilityIdentifier("order.paymentReturn.phase")
            Text(verbatim: PaymentChannelNote(channels: channels, chinese: W8Text.isChinese).text)
                .font(CYTypography.meta)
            Text(verbatim: phase.unlocksEntitlement
                 ? W8Text.t("订单已到账。", "The order has been received.")
                 : W8Text.t("支付返回成功而订单仍待确认时，不开放权益。", "A payment return that succeeds while the order is still pending does not unlock the purchase."))
                .font(CYTypography.meta)
                .accessibilityIdentifier("order.paymentReturn.entitlement")
        }
        .accessibilityIdentifier("order.paymentReturn.section")
    }
}

/// OWN-U07-04. Pending, processing and completed amounts are the server's. An incomplete set does not show a definite total.
struct OrderPartialRefundSection: View {
    let settlement: OrderSettlementFacts?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: W8Text.t("部分退款", "Partial refund")).font(CYTypography.cardTitle)
            let facts = settlement
            labeled(W8Text.t("处理阶段", "Stage"), facts?.stageLine ?? WP09Copy.unknown)
            labeled(W8Text.t("可退金额", "Refundable amount"), facts?.pendingLine ?? WP09Copy.unknown)
            labeled(W8Text.t("处理中金额", "Amount in progress"), facts?.processingLine ?? WP09Copy.unknown)
            labeled(W8Text.t("已完成金额", "Completed amount"), facts?.completedLine ?? WP09Copy.unknown)
            labeled(W8Text.t("合计", "Total"), facts?.totalLine(chinese: W8Text.isChinese) ?? WP09Copy.text("合计未齐", "The total is not complete", chinese: W8Text.isChinese))
        }
        .accessibilityIdentifier("order.refundImpact.section")
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: title).font(CYTypography.meta)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: value).font(CYTypography.meta).accessibilityIdentifier("order.refundImpact.value")
        }
    }
}

/// OWN-U07-05. Accrual is not the marketing allocation and it is not a withdrawable balance. Unknown shows no amount.
struct CreatorAccrualSection: View {
    let projection: CreatorAccrualProjection
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: W8Text.t("创作者应计", "Creator accrual")).font(CYTypography.cardTitle)
            ForEach(Array(projection.lines(chinese: W8Text.isChinese).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: line.title).font(CYTypography.meta)
                    Spacer(minLength: CYSpacing.sm)
                    Text(verbatim: line.value).font(CYTypography.bodyCompact).multilineTextAlignment(.trailing)
                }
            }
            if !projection.showsAmounts {
                Text(verbatim: W8Text.t("稍后重试", "Try again later")).font(CYTypography.meta)
            }
        }
        .accessibilityIdentifier("wallet.accrual.section")
    }
}

/// OWN-U07-03. The reason stays on screen. The confirm write follows ReviewedAreaSwitch and stays closed on www.chengyinhub.com.
private struct WP09APIHostKey: EnvironmentKey { static let defaultValue: String? = nil }

extension EnvironmentValues {
    var wp09APIHost: String? {
        get { self[WP09APIHostKey.self] }
        set { self[WP09APIHostKey.self] = newValue }
    }
}

enum WorkshopPaidInstallAuthority {
    static let reason = "PAID_INSTALL_AUTHORITY_UNAVAILABLE"
    static func confirmSends(host: String?) -> Bool { ReviewedAreaSwitch.moneyPayments(apiHost: host) }
    static func notice(chinese: Bool) -> String {
        WP09Copy.text("付费安装权限不可用（\(reason)）。不会在这台设备上假装安装已经完成。",
                      "Paid install authority is unavailable (\(reason)). This device will not pretend an install finished.",
                      chinese: chinese)
    }
}
