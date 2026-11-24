import SwiftUI

/// Rendered only inside the current authorized MerchantBusinessPage snapshot.
/// No separate fetch, cached destination, evidence download or mutation is introduced.
/// Order follows pages/merchant/aftercare/detail: hero, status card (平台处理, 商家意见, 款项结果,
/// 退款单号, 申请时间, 已转平台客服, 可退截止, 退款政策), 申请原因, 客户, 处理记录.
struct MerchantAftercareProgressView: View {
    let progress: MerchantAftercareProgress
    @State private var phoneTimeZone = TimeZone.current
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: heroSubtitle)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                if progress.amount.raw != nil {
                    Text(verbatim: progress.amount.display)
                        .cyText(.data2XL)
                        .monospacedDigit()
                        .foregroundStyle(CYColor.textPrimary)
                } else {
                    Text("merchant.aftercareProgress.amountUnknown")
                        .cyText(.dataXL)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
            .padding(.vertical, CYSpacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("merchant.business.row.refund.\(progress.refundID)")
        }
        Section {
            LabeledContent("merchant.aftercareProgress.platform") {
                Text(LocalizedStringKey("merchant.business.state." + progress.processing.rawValue))
            }.accessibilityIdentifier("merchant.aftercareProgress.platform")
            LabeledContent("merchant.aftercareProgress.opinion") {
                Text(LocalizedStringKey("merchant.aftercareProgress.opinion." + progress.opinion.rawValue))
            }.accessibilityIdentifier("merchant.aftercareProgress.opinion")
            LabeledContent("merchant.aftercareProgress.funds") {
                Text(LocalizedStringKey("merchant.aftercareProgress.funds." + progress.funds.rawValue))
            }.accessibilityIdentifier("merchant.aftercareProgress.funds")
            // Source: tapping the refund number copies it (copyRefundNo).
            Button {
                LocalPasteboard.copy(progress.refundNumber ?? "#\(progress.refundID)")
            } label: {
                LabeledContent("merchant.aftercareProgress.refundNumber") {
                    Label {
                        Text(verbatim: progress.refundNumber ?? "#\(progress.refundID)").monospacedDigit()
                    } icon: { Image(systemName: "doc.on.doc") }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.copyRefundNumber")))
            .accessibilityIdentifier("merchantOps.aftercare.copyRefundNumber")
            if let created = progress.createdAt {
                LabeledContent("merchant.aftercareProgress.requestedAt",
                               value: MerchantAftercareTime.event(created, phoneTimeZone: phoneTimeZone))
            }
            if let takeover = progress.platformTakeoverAt {
                LabeledContent("merchant.aftercareProgress.takeover",
                               value: MerchantAftercareTime.event(takeover, phoneTimeZone: phoneTimeZone))
            }
            if let deadline = progress.refundDeadline {
                LabeledContent("merchant.aftercareProgress.deadlineBeijing", value: MerchantAftercareTime.deadline(deadline))
            }
            if progress.policyCode != nil || progress.policyVersion != nil {
                LabeledContent("merchant.aftercareProgress.policy") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: MerchantOpsCopy.text(MerchantAftercareParity.policyKey(progress.policyCode)))
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("merchantOps.aftercare.policyText")
                        if let version = progress.policyVersion {
                            Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.policyVersion %lld", version))
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
            }
        }
        // A merchant opinion never reads as a refund; the consequence copy follows the source RESPONSE_FLOW.
        if let decision = MerchantAftercareDecision(rawValue: progress.opinion.rawValue) {
            Section {
                Text(verbatim: MerchantOpsCopy.text(MerchantAftercareResponseGuide.consequenceKey(decision)))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("merchantOps.aftercare.opinionConsequence")
            }
        }
        if let reason = progress.reason {
            Section("merchant.business.field.reason") { Text(verbatim: reason).cyText(.body) }
        }
        if let name = progress.customerNickname {
            Section("merchant.aftercareProgress.customer") {
                LabeledContent("merchant.business.field.customerNickname", value: name)
            }
        }
        Section("merchant.aftercareProgress.history") {
            ForEach(progress.events) { event in
                VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
                    switch event.kind {
                    case .requested:
                        Label("merchant.aftercareProgress.requested", systemImage: "doc.text")
                    case .platformTakeover:
                        Label("merchant.aftercareProgress.takeover", systemImage: "person.crop.circle.badge.clock")
                    case .response(let response):
                        Label(LocalizedStringKey("merchant.aftercareProgress.decision." + response.decision.rawValue), systemImage: "text.bubble")
                        Text(LocalizedStringKey(response.actorKey)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        if let content = response.content { Text(verbatim: content).cyText(.body) }
                        if response.evidence != .none && response.evidence != .notProvided {
                            Text(LocalizedStringKey("merchant.aftercareProgress.evidence." + response.evidence.rawValue))
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    if let time = event.occurredAt {
                        Text(verbatim: MerchantAftercareTime.event(time, phoneTimeZone: phoneTimeZone))
                            .cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchant.aftercareProgress.event." + event.id)
            }
            ForEach(Array(MerchantAftercareParity.platformSteps(progress.processing).enumerated()), id: \.offset) { index, step in
                LabeledContent {
                    Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.stepState." + step.state.rawValue))
                } label: {
                    Text(verbatim: MerchantOpsCopy.text(step.titleKey))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchantOps.aftercare.step.\(index)")
            }
        }
        Section {
            Label {
                Text(verbatim: MerchantOpsCopy.text("merchantOps.aftercare.help")).cyText(.meta)
            } icon: { Image(systemName: "questionmark.circle") }
            .foregroundStyle(CYColor.textSecondary)
            .accessibilityIdentifier("merchantOps.aftercare.help")
        }
        .onAppear { phoneTimeZone = .current }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            phoneTimeZone = .current
        }
    }
    private var heroSubtitle: String {
        let source = MerchantOpsCopy.text(MerchantAftercareParity.sourceKey(progress.sourceType))
        return progress.activityTitle.map { source + " · " + $0 } ?? source
    }
}
