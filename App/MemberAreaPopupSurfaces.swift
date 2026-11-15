import SwiftUI

/// Bilingual helpers for member/settings/wallet/orders/tickets/coupons popups.
/// zh-Hans copy comes verbatim from the mini-program (`chengyinhub-xcx`).
enum MemberPopupCopy {
    static func text(_ zh: String, _ en: String, locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    static func table(_ key: String.LocalizationValue, table: String, locale: Locale) -> String {
        String(localized: LocalizedStringResource(key, table: table, locale: locale))
    }
}

/// Sign-out confirmation (`account.logout`, `pages/shezhi/shezhi.js:317` + `utils/danger-actions.js:1179`).
struct MemberSignOutConfirmSheet: View {
    @Environment(\.locale) private var locale
    let confirmIdentifier: String
    let onConfirm: () -> Void

    init(confirmIdentifier: String? = nil, onConfirm: @escaping () -> Void) {
        self.confirmIdentifier = confirmIdentifier ?? ("account" + ".signOut.confirm")
        self.onConfirm = onConfirm
    }

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("auth.signOutConfirm", locale: locale),
            message: MemberPopupCopy.text(
                "清除本机登录状态，下次进入需要重新登录。",
                "Clear sign-in state on this device. You will need to sign in again next time.",
                locale: locale),
            confirmTitle: appLocalized("auth.signOut", locale: locale),
            isDestructive: true,
            confirmIdentifier: confirmIdentifier,
            consequences: [
                CYConfirmConsequence(
                    systemImage: "rectangle.portrait.and.arrow.right",
                    text: MemberPopupCopy.text(
                        "本机登录态清除，下次进入需要重新登录",
                        "Sign-in state is cleared on this device.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "ticket",
                    text: MemberPopupCopy.text(
                        "已购通行证、订单和券都保留在账号里，不会丢",
                        "Purchased passes, orders and coupons stay saved in your account.",
                        locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Cancel account deregistration confirmation (`account.deregister.cancel`, `utils/danger-actions.js:1191`).
struct MemberDeregistrationCancelConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.table("compliance.cancelReview", table: "AccountCompliance", locale: locale),
            message: MemberPopupCopy.text(
                "撤销后账号立即恢复正常使用。",
                "Your account returns to normal use immediately after cancelling.",
                locale: locale),
            confirmTitle: MemberPopupCopy.table("compliance.cancelApplication", table: "AccountCompliance", locale: locale),
            isDestructive: true,
            confirmIdentifier: "compliance.cancel.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "checkmark.circle",
                    text: MemberPopupCopy.text(
                        "账号恢复正常，登录与购买不受影响",
                        "Sign-in and purchases continue working normally.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "arrow.uturn.left",
                    text: MemberPopupCopy.text(
                        "之后需要注销可以再次申请",
                        "You can submit a closure request again later if needed.",
                        locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Submit account deregistration confirmation (`account.deregister.submit`, `utils/deregister-flow.js`).
struct MemberDeregistrationSubmitConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("compliance.confirmSheet.title", locale: locale),
            message: appLocalized("compliance.confirmSheet.message", locale: locale),
            confirmTitle: appLocalized("compliance.confirmSheet.action", locale: locale),
            isDestructive: true,
            confirmIdentifier: "compliance.submit.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "hourglass",
                    text: MemberPopupCopy.text(
                        "提交后进入受理期，处理完成前仍可随时撤销",
                        "Once submitted, you can still cancel while the request is pending.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: MemberPopupCopy.text(
                        "审核通过并完成注销后，账号与数据将无法恢复",
                        "Once closure completes, the account and data cannot be recovered.",
                        locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Marketing channel opt-in/out confirmation (`pages/shezhi/marketing/index.wxml`).
struct MemberMarketingConsentConfirmSheet: View {
    @Environment(\.locale) private var locale
    let merchantName: String?
    let channelKey: String.LocalizationValue
    let optedIn: Bool
    let onConfirm: () -> Void

    var body: some View {
        let name = merchantName ?? appLocalized("compliance.merchant", locale: locale)
        let channel = appLocalized(channelKey, locale: locale)
        CYConfirmSheet(
            title: MemberPopupCopy.table("compliance.marketing.review", table: "MarketingConsentOriginalPresentation", locale: locale),
            message: "\(name) · \(channel)",
            confirmTitle: MemberPopupCopy.table(
                optedIn ? "compliance.marketing.confirmOptIn" : "compliance.marketing.confirmOptOut",
                table: "MarketingConsentOriginalPresentation",
                locale: locale),
            isDestructive: !optedIn,
            confirmIdentifier: "compliance.marketing.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Favorites & recommendations explanation sheet (`member.favorites.recommendNote`).
struct MemberFavoritesRecommendNoteSheet: View {
    @Environment(\.locale) private var locale
    let onDismiss: () -> Void

    var body: some View {
        CYSheetContainer(
            title: MemberPopupCopy.table("member.favorites.recommendNote.title", table: "MemberProfile", locale: locale),
            onClose: onDismiss
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text("member.favorites.recommendNote.body", tableName: "MemberProfile")
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("member.favorites.recommendNote.dismiss", style: .primary, tableName: "MemberProfile") {
                    onDismiss()
                }
                .accessibilityIdentifier("member.favorites.recommendNote.dismiss")
            }
            .padding(.bottom, CYSpacing.lg)
        }
        .cyDomainSheet(detents: [.half, .full])
    }
}

/// Confirm unlike in liked topics (`subpackageMember/components/cy/scene-route-content/index.js:350`).
struct MemberTopicUnlikeConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.table("member.unlike.confirmTitle", table: "MemberProfile", locale: locale),
            message: MemberPopupCopy.table("member.unlike.confirmMessage", table: "MemberProfile", locale: locale),
            confirmTitle: MemberPopupCopy.table("member.unlike.confirm", table: "MemberProfile", locale: locale),
            isDestructive: true,
            confirmIdentifier: "member.unlike.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Abandon unsubmitted bank withdrawal details (`subpackageA/pages/assetcenter/earnings/index.js:294`).
struct MemberBankWithdrawalDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.text("放弃本次提现填写？", "Discard unsubmitted bank details?", locale: locale),
            message: MemberPopupCopy.text("已填写的信息不会被保存", "Entered bank details will not be saved.", locale: locale),
            confirmTitle: appLocalized("bank.withdrawal.discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "bank.withdrawal.discard.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Confirm merchant swap on free-explore bundle (`subpackageMember/free-explore/index.js:265`).
struct MemberBundleSwapConfirmSheet: View {
    @Environment(\.locale) private var locale
    let merchantName: String
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.text("更换商家？", "Swap merchant?", locale: locale),
            message: MemberPopupCopy.text(
                "改选\(merchantName)，有效期不变。",
                "Switch to \(merchantName). Your validity period stays unchanged.",
                locale: locale),
            confirmTitle: MemberPopupCopy.text("更换", "Swap", locale: locale),
            isDestructive: false,
            confirmIdentifier: "freeExplore.swap.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Confirm submitting report appeal (`subpackageMember/report-detail/index.wxml:55`).
struct MemberReportAppealConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.text("确认提交申诉？", "Submit this appeal?", locale: locale),
            message: MemberPopupCopy.text(
                "提交后将由平台复核处理，处理结果会更新在本页进度中。",
                "The platform will review your appeal and update the status on this detail page.",
                locale: locale),
            confirmTitle: MemberPopupCopy.text("提交申诉", "Submit", locale: locale),
            isDestructive: false,
            confirmIdentifier: "report.appeal.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Confirm showing short-lived dynamic coupon code (`CouponCodeView`).
struct MemberCouponShowConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("couponCode.review", locale: locale),
            message: appLocalized("couponCode.review.detail", locale: locale),
            confirmTitle: appLocalized("couponCode.show", locale: locale),
            isDestructive: false,
            confirmIdentifier: "couponCode.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Discard coupon draft edit confirmation (`subpackageMember/couponInfo/couponInfo.js:208`).
struct MemberCouponDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("couponManagement.discardTitle", locale: locale),
            message: MemberPopupCopy.text(
                "已填写的优惠券内容不会保存。",
                "Entered coupon details will not be saved.",
                locale: locale),
            confirmTitle: appLocalized("couponManagement.discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "couponManagement.discard.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Stop issuing merchant coupon modal (`merchant.coupon.stop`, `subpackageMember/coupon/coupon.js:232`).
struct MemberCouponStopConfirmModal: View {
    @Environment(\.locale) private var locale
    let couponName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        CYModal(
            title: MemberPopupCopy.text("停发「\(couponName)」?", "Stop issuing \"\(couponName)\"?", locale: locale),
            message: MemberPopupCopy.text(
                "停发后将不再新增发放，但已领取的优惠券仍可正常核销。",
                "No new coupons will be issued, while claimed coupons can still be redeemed.",
                locale: locale),
            consequences: [
                CYConfirmConsequence(
                    systemImage: "ticket",
                    text: MemberPopupCopy.text(
                        "还没领的人再也领不到；已领到的券照常可用、可核销",
                        "Unclaimed users cannot claim it anymore; claimed coupons stay valid.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: MemberPopupCopy.text(
                        "此操作不可撤销，停发后无法恢复继续发放",
                        "This can't be undone. Issuing cannot be resumed after stopping.",
                        locale: locale))
            ],
            cancelTitle: appLocalized("action.cancel", locale: locale),
            confirmTitle: MemberPopupCopy.text("停发该券", "Stop issuing", locale: locale),
            isDestructive: true,
            confirmIdentifier: "couponManagement.stopModal.confirm",
            cancelIdentifier: "couponManagement" + ".stopModal.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Withdraw invoice application confirmation (`subpackageMember/invoice/base.js:162`).
struct MemberInvoiceWithdrawConfirmSheet: View {
    @Environment(\.locale) private var locale
    let confirmIdentifier: String
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.table("withdrawConfirm", table: "InvoiceLaunchUI", locale: locale),
            message: MemberPopupCopy.text(
                "撤回后，订单可重新申请开票。",
                "Orders can apply for an invoice again after withdrawing.",
                locale: locale),
            confirmTitle: MemberPopupCopy.table("withdraw", table: "InvoiceLaunchUI", locale: locale),
            isDestructive: true,
            confirmIdentifier: confirmIdentifier,
            onConfirm: onConfirm
        )
    }
}

/// Delete invoice title confirmation (`subpackageMember/invoice-titles/index.js:49`).
struct MemberInvoiceTitleDeleteConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.table("deleteConfirm", table: "InvoiceLaunchUI", locale: locale),
            message: MemberPopupCopy.text(
                "删除后不影响已提交的申请。",
                "Submitted applications are not affected.",
                locale: locale),
            confirmTitle: MemberPopupCopy.table("delete", table: "InvoiceLaunchUI", locale: locale),
            isDestructive: true,
            confirmIdentifier: "invoice.title.delete.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Delete all NPC chat logs confirmation (`ai.npc.chatData.delete`, `utils/danger-actions.js:789`).
struct MemberNPCLogDeleteConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: MemberPopupCopy.table("npcLogDelete.confirmTitle", table: "NPCChatLogDeletion", locale: locale),
            message: MemberPopupCopy.table("npcLogDelete.confirmMessage", table: "NPCChatLogDeletion", locale: locale),
            confirmTitle: MemberPopupCopy.table("npcLogDelete.confirm", table: "NPCChatLogDeletion", locale: locale),
            isDestructive: true,
            confirmIdentifier: "npcLogDelete.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "trash",
                    text: MemberPopupCopy.text(
                        "范围是你账号下所有 AI 对话（漫游向导和店铺形象），不只是当前这一段",
                        "Applies to all AI conversations under your account, not only the current thread.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "info.circle",
                    text: MemberPopupCopy.text(
                        "不影响你的漫游足迹、邮票、订单等其他数据",
                        "Your roam footprints, stamps, orders and other records stay intact.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: MemberPopupCopy.text(
                        "此操作不可撤销，删除后无法恢复这些对话",
                        "This can't be undone. Deleted conversations cannot be recovered.",
                        locale: locale))
            ],
            onConfirm: onConfirm
        )
    }
}

/// Orient-score action confirmation (`subpackageMember/orient-score/index.js:186,217,284`).
struct MemberOrientScoreConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("orientScore.review.confirmTitle", locale: locale),
            message: MemberPopupCopy.text(
                "确认后将按当前请求提交至计分系统处理。",
                "Once confirmed, this request will be sent to the scoring service.",
                locale: locale),
            confirmTitle: appLocalized("orientScore.review.send", locale: locale),
            isDestructive: false,
            confirmIdentifier: "orientScore.review.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Profile editor & draft discard confirmations (`ProfileEditView`, `ProfileDraftReviewSection`, `ProfileAvatarDraftSection`).
struct MemberProfileDiscardConfirmSheet: View {
    enum Kind { case exitDiscard, reloadDiscard, reviewRestore, avatarDiscard }

    @Environment(\.locale) private var locale
    let kind: Kind
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    init(kind: Kind, onCancel: (() -> Void)? = nil, onConfirm: @escaping () -> Void) {
        self.kind = kind
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        switch kind {
        case .exitDiscard:
            CYConfirmSheet(
                title: appLocalized("profile.exitDiscard.title", locale: locale),
                message: appLocalized("profile.exitDiscard.message", locale: locale),
                confirmTitle: appLocalized("profile.exitDiscard.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.exitDiscard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .reloadDiscard:
            CYConfirmSheet(
                title: appLocalized("profile.reloadDiscard.title", locale: locale),
                message: appLocalized("profile.reloadDiscard.message", locale: locale),
                confirmTitle: appLocalized("profile.reloadDiscard.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.reloadDiscard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .reviewRestore:
            CYConfirmSheet(
                title: appLocalized("profile.reviewRestore.title", locale: locale),
                message: appLocalized("profile.reviewRestore.message", locale: locale),
                confirmTitle: appLocalized("profile.reviewRestore.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.reviewRestore.confirm",
                cancelIdentifier: "profile" + ".reviewRestore.cancel",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .avatarDiscard:
            CYConfirmSheet(
                title: appLocalized("profile.avatar.discardTitle", locale: locale),
                message: MemberPopupCopy.text(
                    "放弃后将保留当前已保存的头像，不会上传或提交这张新头像。",
                    "Discarding keeps your saved avatar without uploading the new selection.",
                    locale: locale),
                confirmTitle: appLocalized("profile.avatar.discard", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.avatar.discard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
    }
}

/// Delete participant confirmation (`address.delete`, `utils/danger-actions.js:913`).
struct MemberParticipantDeleteConfirmSheet: View {
    @Environment(\.locale) private var locale
    let summary: String
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void

    init(summary: String, onCancel: (() -> Void)? = nil, onConfirm: @escaping () -> Void) {
        self.summary = summary
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        let bodyText = summary.isEmpty
            ? appLocalized("participant.list.deleteBody", locale: locale)
            : summary + "\n\n" + appLocalized("participant.list.deleteBody", locale: locale)
        CYConfirmSheet(
            title: appLocalized("participant.list.deleteTitle", locale: locale),
            message: bodyText,
            confirmTitle: appLocalized("participant.list.deleteConfirm", locale: locale),
            isDestructive: true,
            confirmIdentifier: "participant.list.delete.confirm",
            consequences: [
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: appLocalized("participant.list.deleteIrreversible", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "calendar",
                    text: appLocalized("participant.list.deleteKeepsRegistration", locale: locale))
            ],
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Submit complaint confirmation (`subpackageMember/complaint/index.js:304`).
struct MemberComplaintSubmitConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("profile.complaint.submit.confirmTitle", locale: locale),
            message: appLocalized("profile.complaint.submit.confirmBody", locale: locale),
            confirmTitle: appLocalized("profile.complaint.submit.action", locale: locale),
            isDestructive: false,
            confirmIdentifier: "profile.complaint.submit.confirm",
            onConfirm: onConfirm
        )
    }
}

/// Discard confirmation when leaving a dirty settings screen (`pages/shezhi/shezhi.wxml:91`).
struct MemberSettingsSceneDiscardModal: View {
    @Environment(\.locale) private var locale
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: MemberPopupCopy.text("放弃本轮修改", "Discard current changes?", locale: locale),
            message: MemberPopupCopy.text(
                "离开当前页面后，未提交的修改不会保存。",
                "Unsaved changes in this screen will be discarded if you leave.",
                locale: locale),
            cancelTitle: MemberPopupCopy.text("继续编辑", "Keep editing", locale: locale),
            confirmTitle: MemberPopupCopy.text("确认放弃", "Discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "memberPopup.sceneDiscard.confirm",
            cancelIdentifier: "memberPopup.sceneDiscard.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Option sheet choosing among multiple owned clubs from Settings (`pages/shezhi/shezhi.js:123`).
struct MemberSettingsClubPickerSheet: View {
    @Environment(\.locale) private var locale
    let clubs: [ClubRecord]
    let onSelect: (ClubRecord) -> Void
    let onClose: () -> Void

    var body: some View {
        CYOptionSheet(
            title: MemberPopupCopy.text("选择要管理的俱乐部", "Select a club to manage", locale: locale),
            items: clubs.map { club in
                CYOptionSheetItem(
                    id: club.id,
                    title: club.name,
                    subtitle: club.city,
                    systemImage: "flag"
                )
            },
            onSelect: { selectedID in
                if let match = clubs.first(where: { $0.id == selectedID }) {
                    onSelect(match)
                }
            },
            onClose: onClose
        )
    }
}

/// Option sheet for AI chat records (`subpackageMember/components/cy/ai-chat-records/index.wxml:1`).
struct MemberAIChatRecordsOptionSheet: View {
    @Environment(\.locale) private var locale
    let onSelect: (NPCChatRecordsOption) -> Void
    let onClose: () -> Void

    var body: some View {
        CYOptionSheet(
            title: MemberPopupCopy.text("AI 对话记录", "AI Chat Records", locale: locale),
            items: [
                CYOptionSheetItem(
                    id: .view,
                    title: MemberPopupCopy.text("查看对话记录", "View chat records", locale: locale),
                    systemImage: "doc.text.magnifyingglass"
                ),
                CYOptionSheetItem(
                    id: .export,
                    title: MemberPopupCopy.text("导出对话记录", "Export chat records", locale: locale),
                    systemImage: "square.and.arrow.up"
                ),
                CYOptionSheetItem(
                    id: .clear,
                    title: MemberPopupCopy.text("清除对话记录", "Clear chat records", locale: locale),
                    systemImage: "trash",
                    isDanger: true
                ),
            ],
            onSelect: onSelect,
            onClose: onClose
        )
    }
}

/// Full-screen / large detent DS sheet hosting merchant NPC chat plus export and clear controls
/// (`subpackageMember/components/cy/npc-chat/index.wxml:9`).
struct MemberMerchantNPCChatSheet<Content: View>: View {
    @Environment(\.locale) private var locale
    let title: String
    let onExport: (() async -> Void)?
    let onClear: (() async -> Void)?
    let onClose: () -> Void
    let content: Content

    @State private var confirmsClear = false

    init(
        title: String,
        onExport: (() async -> Void)? = nil,
        onClear: (() async -> Void)? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onExport = onExport
        self.onClear = onClear
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        CYSheetContainer(title: title, onClose: onClose) {
            VStack(spacing: CYSpacing.sm) {
                if onExport != nil || onClear != nil {
                    HStack(spacing: CYSpacing.sm) {
                        if let onExport {
                            CYPillButton(
                                verbatim: MemberPopupCopy.text("导出我的对话记录", "Export my records", locale: locale),
                                style: .secondary
                            ) {
                                Task { await onExport() }
                            }
                            .accessibilityIdentifier("merchant.npcChat.export")
                        }
                        if onClear != nil {
                            CYPillButton(
                                verbatim: MemberPopupCopy.text("清除我的对话记录", "Clear my records", locale: locale),
                                style: .tertiary
                            ) {
                                confirmsClear = true
                            }
                            .accessibilityIdentifier("merchant.npcChat.clear")
                        }
                    }
                }
                content
            }
        }
        .sheet(isPresented: $confirmsClear) {
            MemberNPCLogDeleteConfirmSheet {
                confirmsClear = false
                if let onClear {
                    Task { await onClear() }
                }
            }
            .cyDomainSheet(detents: [.half])
        }
    }
}

/// Discard confirmation when leaving cooperation invite editor with unsaved text.
struct MemberCoopInviteDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        CYConfirmSheet(
            title: appLocalized("coopflow.invite.discardPrompt", locale: locale),
            message: MemberPopupCopy.text(
                "返回后当前填写的邀约说明将不会被保存。",
                "Your unsaved invitation note will be lost.",
                locale: locale),
            confirmTitle: appLocalized("coopflow.invite.discard", locale: locale),
            isDestructive: true,
            confirmIdentifier: "coopflow.invite.discard.confirm",
            onConfirm: onConfirm
        )
    }
}

/// DS invitation sheet (`subpackageMember/components/cy/coop-invite-sheet/index.wxml:2`)
/// listing owned topics & invite chapters on member/merchant public home.
struct MemberCoopInviteSheet: View {
    @Environment(\.locale) private var locale
    let targetName: String
    let merchantMemberID: Int?
    let loadTopics: @MainActor () async -> [(id: Int, title: String)]
    let loadChapters: @MainActor (Int) async -> [TopicInviteChapter]
    let onOpenFullCoopFlow: (() -> Void)?
    let onClose: () -> Void

    @State private var topics: [(id: Int, title: String)] = []
    @State private var selectedTopicID: Int?
    @State private var chapters: [TopicInviteChapter] = []
    @State private var draft = MemberCoopInviteDraft()
    @State private var loading = false
    @State private var showsDiscard = false
    @State private var toastMessage: LocalizedStringKey?

    private var dirty: Bool { draft.selectedChapterID != nil || draft.normalizedNote != nil }

    var body: some View {
        CYSheetContainer(
            title: MemberPopupCopy.text("发送邀约", "Send Invitation", locale: locale),
            onClose: {
                if dirty { showsDiscard = true } else { onClose() }
            }
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if !targetName.isEmpty {
                    Text(verbatim: targetName)
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                }

                if loading {
                    CYSkeleton()
                } else if topics.isEmpty {
                    CYEmptyState(
                        systemImage: "doc.text",
                        LocalizedStringKey(MemberPopupCopy.text("暂无可邀约主题，请先在项目工作台创建", "No topics ready to invite", locale: locale)),
                        kind: .generic
                    )
                } else {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: MemberPopupCopy.text("选择项目主题", "Topic", locale: locale))
                            .font(CYTypography.sectionTitle)
                            .foregroundStyle(CYColor.textSecondary)
                        ForEach(topics, id: \.id) { topic in
                            Button {
                                selectedTopicID = topic.id
                                draft.selectedChapterID = nil
                                Task { chapters = await loadChapters(topic.id) }
                            } label: {
                                HStack {
                                    Text(verbatim: topic.title)
                                        .font(CYTypography.body)
                                        .foregroundStyle(CYColor.textPrimary)
                                    Spacer()
                                    if selectedTopicID == topic.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(CYColor.brand)
                                    }
                                }
                                .padding(.vertical, CYSpacing.xs)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("member.coopInvite.topic.\(topic.id)")
                            .accessibilityAddTraits(selectedTopicID == topic.id ? .isSelected : [])
                        }
                    }

                    if !chapters.isEmpty {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: MemberPopupCopy.text("选择邀约章节", "Chapter", locale: locale))
                                .font(CYTypography.sectionTitle)
                                .foregroundStyle(CYColor.textSecondary)
                            ForEach(chapters, id: \.id) { chapter in
                                let numericID = Int(chapter.id) ?? 0
                                Button {
                                    draft.selectedChapterID = numericID
                                } label: {
                                    HStack {
                                        Text(verbatim: chapter.name.isEmpty ? "#\(chapter.id)" : chapter.name)
                                            .font(CYTypography.body)
                                            .foregroundStyle(CYColor.textPrimary)
                                        Spacer()
                                        if draft.selectedChapterID == numericID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(CYColor.brand)
                                        }
                                    }
                                    .padding(.vertical, CYSpacing.xs)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("member.coopInvite.chapter.\(chapter.id)")
                                .accessibilityAddTraits(draft.selectedChapterID == numericID ? .isSelected : [])
                            }
                        }
                    }

                    TextField(
                        MemberPopupCopy.text("填写合作说明（选填）", "Optional cooperation note", locale: locale),
                        text: $draft.note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(MemberPopupCopy.text("合作说明", "Cooperation note", locale: locale))
                    .accessibilityIdentifier("member.coopInvite.note")

                    HStack(spacing: CYSpacing.sm) {
                        CYPillButton(
                            verbatim: MemberPopupCopy.text("关闭", "Close", locale: locale),
                            style: .secondary
                        ) {
                            if dirty { showsDiscard = true } else { onClose() }
                        }
                        .accessibilityIdentifier("member.coopInvite.close")
                        CYPillButton(
                            verbatim: MemberPopupCopy.text("发送", "Send", locale: locale),
                            style: .primary
                        ) {
                            if let onOpenFullCoopFlow {
                                onClose()
                                onOpenFullCoopFlow()
                            } else {
                                toastMessage = LocalizedStringKey(
                                    MemberPopupCopy.text(
                                        "俱乐部直发合作邀约已按合规策略收口至合作中心",
                                        "Cooperation invites open in the Cooperation Center",
                                        locale: locale)
                                )
                            }
                        }
                        .disabled(!draft.isReadyToSend || merchantMemberID == nil)
                        .accessibilityIdentifier("member.coopInvite.send")
                    }
                }
            }
        }
        .cyToast(message: $toastMessage, tone: .info)
        .sheet(isPresented: $showsDiscard) {
            MemberCoopInviteDiscardConfirmSheet {
                showsDiscard = false
                onClose()
            }
            .cyDomainSheet(detents: [.half])
        }
        .task {
            loading = true
            topics = await loadTopics()
            if let first = topics.first {
                selectedTopicID = first.id
                chapters = await loadChapters(first.id)
            }
            loading = false
        }
    }
}

/// Discard confirmation when closing a deep-linked scene with unsaved changes (`scene-deep-link/index.wxml:78`).
struct MemberDeepLinkDiscardModal: View {
    @Environment(\.locale) private var locale
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        let prompt = DeepLinkSceneDiscardPrompt()
        CYModal(
            title: MemberPopupCopy.text(prompt.title, "Discard current changes?", locale: locale),
            message: MemberPopupCopy.text(prompt.message, "Unsaved edits will be lost if you close.", locale: locale),
            cancelTitle: MemberPopupCopy.text(prompt.cancelTitle, "Keep editing", locale: locale),
            confirmTitle: MemberPopupCopy.text(prompt.confirmTitle, "Discard & close", locale: locale),
            isDestructive: true,
            confirmIdentifier: "deepLink.discard.confirm",
            cancelIdentifier: "deepLink.discard.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}
