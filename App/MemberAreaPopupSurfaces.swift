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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        NavigationStack {
            List {
                Section {
                    Text("member.favorites.recommendNote.body", tableName: "MemberProfile")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: MemberPopupCopy.table("member.favorites.recommendNote.title", table: "MemberProfile", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { onDismiss() } label: {
                        Text("member.favorites.recommendNote.dismiss", tableName: "MemberProfile")
                    }
                    .accessibilityIdentifier("member.favorites.recommendNote.dismiss")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Confirm unlike in liked topics (`subpackageMember/components/cy/scene-route-content/index.js:350`).
struct MemberTopicUnlikeConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmAlert(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
            MemberConfirmSheet(
                title: appLocalized("profile.exitDiscard.title", locale: locale),
                message: appLocalized("profile.exitDiscard.message", locale: locale),
                confirmTitle: appLocalized("profile.exitDiscard.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.exitDiscard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .reloadDiscard:
            MemberConfirmSheet(
                title: appLocalized("profile.reloadDiscard.title", locale: locale),
                message: appLocalized("profile.reloadDiscard.message", locale: locale),
                confirmTitle: appLocalized("profile.reloadDiscard.confirm", locale: locale),
                isDestructive: true,
                confirmIdentifier: "profile.reloadDiscard.confirm",
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        case .reviewRestore:
            MemberConfirmSheet(
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
            MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmSheet(
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
        MemberConfirmAlert(
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
        MemberOptionSheet(
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
        MemberOptionSheet(
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
        VStack(spacing: 12) {
            // System sheet header: inline title and the standard close glyph (no NavigationStack: the hosted chat may own one).
            HStack(spacing: 12) {
                Text(verbatim: title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action.close"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            if onExport != nil || onClear != nil {
                HStack(spacing: 8) {
                    if let onExport {
                        Button {
                            Task { await onExport() }
                        } label: {
                            Text(verbatim: MemberPopupCopy.text("导出我的对话记录", "Export my records", locale: locale))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("merchant.npcChat.export")
                    }
                    if onClear != nil {
                        Button(role: .destructive) {
                            confirmsClear = true
                        } label: {
                            Text(verbatim: MemberPopupCopy.text("清除我的对话记录", "Clear my records", locale: locale))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("merchant.npcChat.clear")
                    }
                }
                .padding(.horizontal, 16)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $confirmsClear) {
            MemberNPCLogDeleteConfirmSheet {
                confirmsClear = false
                if let onClear {
                    Task { await onClear() }
                }
            }
        }
    }
}

/// Discard confirmation when leaving cooperation invite editor with unsaved text.
struct MemberCoopInviteDiscardConfirmSheet: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void

    var body: some View {
        MemberConfirmSheet(
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
        NavigationStack {
            Form {
                if !targetName.isEmpty {
                    Section {
                        Text(verbatim: targetName)
                            .font(.headline)
                    }
                }

                if loading {
                    Section {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } else if topics.isEmpty {
                    ContentUnavailableView(
                        MemberPopupCopy.text("暂无可邀约主题，请先在项目工作台创建", "No topics ready to invite", locale: locale),
                        systemImage: "doc.text"
                    )
                } else {
                    Section {
                        ForEach(topics, id: \.id) { topic in
                            Button {
                                selectedTopicID = topic.id
                                draft.selectedChapterID = nil
                                Task { chapters = await loadChapters(topic.id) }
                            } label: {
                                HStack {
                                    Text(verbatim: topic.title)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTopicID == topic.id {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("member.coopInvite.topic.\(topic.id)")
                            .accessibilityAddTraits(selectedTopicID == topic.id ? .isSelected : [])
                        }
                    } header: {
                        Text(verbatim: MemberPopupCopy.text("选择项目主题", "Topic", locale: locale))
                    }

                    if !chapters.isEmpty {
                        Section {
                            ForEach(chapters, id: \.id) { chapter in
                                let numericID = Int(chapter.id) ?? 0
                                Button {
                                    draft.selectedChapterID = numericID
                                } label: {
                                    HStack {
                                        Text(verbatim: chapter.name.isEmpty ? "#\(chapter.id)" : chapter.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if draft.selectedChapterID == numericID {
                                            Image(systemName: "checkmark")
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .accessibilityIdentifier("member.coopInvite.chapter.\(chapter.id)")
                                .accessibilityAddTraits(draft.selectedChapterID == numericID ? .isSelected : [])
                            }
                        } header: {
                            Text(verbatim: MemberPopupCopy.text("选择邀约章节", "Chapter", locale: locale))
                        }
                    }

                    Section {
                        TextField(
                            MemberPopupCopy.text("填写合作说明（选填）", "Optional cooperation note", locale: locale),
                            text: $draft.note,
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                        .accessibilityLabel(MemberPopupCopy.text("合作说明", "Cooperation note", locale: locale))
                        .accessibilityIdentifier("member.coopInvite.note")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text(verbatim: MemberPopupCopy.text("发送邀约", "Send Invitation", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if dirty { showsDiscard = true } else { onClose() }
                    } label: {
                        Text(verbatim: MemberPopupCopy.text("关闭", "Close", locale: locale))
                    }
                    .accessibilityIdentifier("member.coopInvite.close")
                }
                if !loading && !topics.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
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
                        } label: {
                            Text(verbatim: MemberPopupCopy.text("发送", "Send", locale: locale))
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
        MemberConfirmAlert(
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

// MARK: - Native confirmation chrome (native r2)

/// Native replacement for `CYConfirmSheet` (same arguments): a system sheet with the title and message in an inset
/// grouped list, consequences as SF Symbol labels, and the confirm / cancel pair as system buttons in the bottom bar.
struct MemberConfirmSheet: View {
    private let title: String
    private let message: String
    private let confirmTitle: String
    private let cancelTitle: String?
    private let isDestructive: Bool
    private let confirmDisabled: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let titleIdentifier: String?
    private let consequences: [CYConfirmConsequence]
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, message: String, confirmTitle: String,
         cancelTitle: String? = nil,
         isDestructive: Bool = false, confirmDisabled: Bool = false,
         confirmIdentifier: String? = nil,
         cancelIdentifier: String? = nil, titleIdentifier: String? = nil,
         consequences: [CYConfirmConsequence] = [],
         onCancel: (() -> Void)? = nil,
         onConfirm: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.confirmDisabled = confirmDisabled
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.titleIdentifier = titleIdentifier
        self.consequences = consequences
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: title)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .memberOptionalIdentifier(titleIdentifier)
                    if !message.isEmpty {
                        Text(verbatim: message)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
            if !consequences.isEmpty {
                Section {
                    ForEach(consequences) { item in
                        Label {
                            Text(verbatim: item.text).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: item.systemImage).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("confirm.consequences")
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button(role: isDestructive ? .destructive : nil) {
                    onConfirm()
                } label: {
                    Text(verbatim: confirmTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(confirmDisabled)
                .memberOptionalIdentifier(confirmIdentifier)
                Button {
                    onCancel?()
                    dismiss()
                } label: {
                    Group {
                        if let cancelTitle { Text(verbatim: cancelTitle) } else { Text("action.cancel") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .memberOptionalIdentifier(cancelIdentifier)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Native replacement for the centred `CYModal` dialog (same arguments): a system `.alert`. The host shows this view
/// only while its flag is on and clears the flag in `onCancel` / `onConfirm`. Consequences join the alert message.
struct MemberConfirmAlert: View {
    private let title: String
    private let message: String
    private let consequences: [CYConfirmConsequence]
    private let cancelTitle: String?
    private let confirmTitle: String
    private let isDestructive: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    init(title: String, message: String, consequences: [CYConfirmConsequence] = [],
         cancelTitle: String? = nil, confirmTitle: String, isDestructive: Bool = false,
         confirmIdentifier: String? = nil, cancelIdentifier: String? = nil,
         onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.consequences = consequences
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    private var fullMessage: String {
        ([message] + consequences.map { "• " + $0.text }).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .alert(Text(verbatim: title), isPresented: Binding(get: { true }, set: { _ in })) {
                Button(role: isDestructive ? .destructive : nil, action: onConfirm) {
                    Text(verbatim: confirmTitle)
                }
                .accessibilityIdentifier(confirmIdentifier ?? "memberPopup.alert.confirm")
                Button(role: .cancel, action: onCancel) {
                    if let cancelTitle { Text(verbatim: cancelTitle) } else { Text("action.cancel") }
                }
                .accessibilityIdentifier(cancelIdentifier ?? "memberPopup.alert.cancel")
            } message: {
                Text(verbatim: fullMessage)
            }
    }
}

/// Native replacement for `CYOptionSheet` (same arguments): an inset grouped list of system rows in a sheet,
/// with the title inline and 关闭 in the toolbar. A danger item is a destructive button.
struct MemberOptionSheet<ID: Hashable>: View {
    let title: String
    let items: [CYOptionSheetItem<ID>]
    var selectedID: ID? = nil
    var closeIdentifier: String? = nil
    let onSelect: (ID) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        Button(role: item.isDanger ? .destructive : nil) {
                            onSelect(item.id)
                        } label: {
                            HStack {
                                if let systemImage = item.systemImage {
                                    Label {
                                        optionText(item)
                                    } icon: {
                                        Image(systemName: systemImage)
                                    }
                                } else {
                                    optionText(item)
                                }
                                Spacer(minLength: 8)
                                if item.id == selectedID {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(item.isDanger ? Color.red : Color.primary)
                        .accessibilityAddTraits(item.id == selectedID ? .isSelected : [])
                        .memberOptionalIdentifier(item.identifier)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close", action: onClose)
                        .memberOptionalIdentifier(closeIdentifier)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private func optionText(_ item: CYOptionSheetItem<ID>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: item.title)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = item.subtitle {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension View {
    @ViewBuilder func memberOptionalIdentifier(_ identifier: String?) -> some View {
        if let identifier { accessibilityIdentifier(identifier) } else { self }
    }
}
