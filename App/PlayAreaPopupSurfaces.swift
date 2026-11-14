import SwiftUI

/// Bilingual copy for play-area popups. zh-Hans is the mini-program string.
enum PlayAreaPopupCopy {
    static func text(_ zh: String, _ en: String, locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    /// Cash confirms stay closed on www.chengyinhub.com. A positive amount is an em dash while closed.
    static func moneyText(_ amount: String?, positive: Bool) -> String {
        guard ReviewedAreaSwitch.moneyPayments, let amount, !amount.isEmpty else { return positive ? "—" : (amount ?? "—") }
        return amount
    }

    static var paymentsOpen: Bool { ReviewedAreaSwitch.moneyPayments }
}

struct PlayAreaRoamFinishModal: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        CYModal(
            title: PlayAreaPopupCopy.text("结束本次漫游?", "End this roam?", locale: locale),
            message: PlayAreaPopupCopy.text(
                "足迹和探店都会保存,结算后可领足迹卡。",
                "Your footprints and shop visits are saved. After settlement you can collect the footprint card.",
                locale: locale),
            consequences: [
                CYConfirmConsequence(
                    systemImage: "flag",
                    text: PlayAreaPopupCopy.text(
                        "本次漫游立即结算,足迹与探店记录保留",
                        "This roam settles now. Footprints and shop visits stay.",
                        locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: PlayAreaPopupCopy.text(
                        "此操作不可撤销,结束后不能继续这一次漫游",
                        "This can't be undone. You can't continue this roam after it ends.",
                        locale: locale))
            ],
            cancelTitle: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale),
            confirmTitle: PlayAreaPopupCopy.text("结束漫游", "End roam", locale: locale),
            isDestructive: true,
            confirmIdentifier: "roam.live.finish.confirm",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

struct PlayAreaActivityAbandonModal: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        CYModal(
            title: PlayAreaPopupCopy.text("放弃未发布的活动？", "Give up this unpublished activity?", locale: locale),
            message: PlayAreaPopupCopy.text(
                "已填写的活动内容不会保留。",
                "What you entered in this activity will not be kept.",
                locale: locale),
            cancelTitle: PlayAreaPopupCopy.text("继续编辑", "Keep editing", locale: locale),
            confirmTitle: PlayAreaPopupCopy.text("放弃", "Give up", locale: locale),
            isDestructive: true,
            confirmIdentifier: "publishModes.abandon.confirm",
            cancelIdentifier: "publishModes.abandon.keepEditing",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

struct PlayAreaSeatCancelModal: View {
    @Environment(\.locale) private var locale
    let seatNo: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        CYModal(
            title: PlayAreaPopupCopy.text("撤销第 \(seatNo) 席的邀请?", "Cancel the invite for seat \(seatNo)?", locale: locale),
            message: PlayAreaPopupCopy.text(
                "已发出的邀请链接立即失效。席位回到可邀请，可以重新邀请别人。",
                "The invite link stops working. The seat can be offered to someone else.",
                locale: locale),
            consequences: [
                CYConfirmConsequence(
                    systemImage: "square.and.arrow.up",
                    text: PlayAreaPopupCopy.text("已发出的邀请链接立即失效", "The invite link stops working immediately.", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "person.2",
                    text: PlayAreaPopupCopy.text("席位回到可邀请，可以重新邀请别人", "The seat is open again and can be offered to someone else.", locale: locale))
            ],
            cancelTitle: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale),
            confirmTitle: PlayAreaPopupCopy.text("撤销邀请", "Cancel invite", locale: locale),
            isDestructive: true,
            confirmIdentifier: "journeySeats.cancel.confirm",
            cancelIdentifier: "journeySeats.cancel.dismiss",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

struct PlayAreaHostCancelModal: View {
    @Environment(\.locale) private var locale
    let paidCount: Int?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let count = paidCount.map(String.init) ?? "—"
        CYModal(
            title: PlayAreaPopupCopy.text("取消这场活动并退款?", "Cancel this event and refund?", locale: locale),
            message: PlayAreaPopupCopy.text(
                "将给 \(count) 位已付款玩家全额退款,不可撤销。活动同时下架。",
                count == "—"
                    ? "The paid attendee count is unknown. A refund is not confirmed."
                    : "\(count) paid players get a full refund. This can't be undone, and the event is unlisted.",
                locale: locale),
            consequences: [
                CYConfirmConsequence(
                    systemImage: "arrow.uturn.backward",
                    text: PlayAreaPopupCopy.text("已报名未核销的玩家全额退款,款项原路退回", "Unredeemed sign-ups are refunded in full to the original payment method.", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "calendar",
                    text: PlayAreaPopupCopy.text("活动下架,玩家不能再报名或进入", "The event is unlisted. Players can't sign up or enter.", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "exclamationmark.triangle",
                    text: PlayAreaPopupCopy.text("此操作不可撤销,取消后无法恢复这场活动", "This can't be undone. The event can't be restored.", locale: locale))
            ],
            cancelTitle: PlayAreaPopupCopy.text("再想想", "Not now", locale: locale),
            confirmTitle: PlayAreaPopupCopy.text("取消并退款", "Cancel and refund", locale: locale),
            isDestructive: true,
            confirmIdentifier: "activity.hostCancel.confirmDialog",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

struct PlayAreaNonRefundableModal: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let copy = CoreLoopCopy(locale: locale)
        CYModal(
            title: copy.tr(NonRefundable24hNotice.modalTitle),
            message: copy.tr(NonRefundable24hNotice.modalContent),
            cancelTitle: copy.tr(NonRefundable24hNotice.cancelButtonTitle),
            confirmTitle: copy.tr(NonRefundable24hNotice.confirmButtonTitle),
            confirmIdentifier: "registration.nonRefundable.confirm",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

struct PlayAreaWaitlistQuitModal: View {
    @Environment(\.locale) private var locale
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        CYModal(
            title: PlayAreaPopupCopy.text("退出候补队列?", "Leave the waitlist?", locale: locale),
            message: PlayAreaPopupCopy.text(
                "已保留的名额会立即让给下一位。之后还想来,可以重新排队,顺位从头算。",
                "The place you were holding goes to the next person. You can join again later, and your place starts over.",
                locale: locale),
            consequences: [
                CYConfirmConsequence(
                    systemImage: "calendar",
                    text: PlayAreaPopupCopy.text("已保留的名额会立即让给下一位", "The place you were holding goes to the next person.", locale: locale)),
                CYConfirmConsequence(
                    systemImage: "info.circle",
                    text: PlayAreaPopupCopy.text("之后还想来,可以重新排队,顺位从头算", "You can join the queue again later, and your place starts over.", locale: locale))
            ],
            cancelTitle: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale),
            confirmTitle: PlayAreaPopupCopy.text("退出候补", "Leave waitlist", locale: locale),
            isDestructive: true,
            confirmIdentifier: "registration.waitlist.confirmCancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

struct PlayAreaNearbyRangeSheet: View {
    @Environment(\.locale) private var locale
    let radii: [Int]
    let selected: Int
    let onSelect: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        CYOptionSheet(
            title: PlayAreaPopupCopy.text("范围", "Range", locale: locale),
            items: radii.map { CYOptionSheetItem(id: $0, title: "\($0 / 1000) km") },
            selectedID: selected,
            onSelect: onSelect,
            onClose: onClose
        )
        .cyDomainSheet(detents: [.half])
        .accessibilityIdentifier("nearby.rangeSheet")
    }
}

struct PlayAreaTeamReviewModal: View {
    @Environment(\.locale) private var locale
    let action: NearbyTeamAction
    let name: String
    var busy = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        switch action {
        case .apply:
            modal(
                title: PlayAreaPopupCopy.text("申请加入这支队伍？", "Ask to join this team?", locale: locale),
                message: PlayAreaPopupCopy.text("队长同意后会通知你。", "The leader will let you know after they decide.", locale: locale),
                confirm: PlayAreaPopupCopy.text("申请", "Apply", locale: locale),
                cancel: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale),
                destructive: false,
                confirmIdentifier: "nearby.confirm",
                busy: busy)
        case .withdraw:
            modal(
                title: PlayAreaPopupCopy.text("撤回申请？", "Withdraw this application?", locale: locale),
                message: PlayAreaPopupCopy.text("撤回后可以重新申请。", "You can apply again after you withdraw.", locale: locale),
                confirm: PlayAreaPopupCopy.text("撤回", "Withdraw", locale: locale),
                cancel: PlayAreaPopupCopy.text("不撤回", "Keep application", locale: locale),
                destructive: true,
                confirmIdentifier: "nearby.confirm",
                busy: busy)
        case .handle(_, _, let approved):
            if approved {
                modal(
                    title: PlayAreaPopupCopy.text("通过这条申请？", "Accept this application?", locale: locale),
                    message: name.isEmpty ? "—" : name,
                    confirm: PlayAreaPopupCopy.text("通过", "Accept", locale: locale),
                    cancel: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale),
                    destructive: false,
                    confirmIdentifier: "nearby.confirm",
                    busy: busy)
            } else {
                let who = name.isEmpty ? PlayAreaPopupCopy.text("这位玩家", "this player", locale: locale) : name
                CYModal(
                    title: PlayAreaPopupCopy.text("拒绝「\(who)」的申请？", "Decline \(who)'s application?", locale: locale),
                    message: PlayAreaPopupCopy.text(
                        "拒绝后对方不能再申请加入这支队伍。此操作不可撤销。",
                        "They can't apply to this team again. This can't be undone.",
                        locale: locale),
                    consequences: [
                        CYConfirmConsequence(
                            systemImage: "bell",
                            text: PlayAreaPopupCopy.text("对方会在「我的队伍」里看到「未通过」", "They'll see Not accepted under My teams.", locale: locale)),
                        CYConfirmConsequence(
                            systemImage: "exclamationmark.triangle",
                            text: PlayAreaPopupCopy.text("此操作不可撤销；对方不能再申请加入这支队伍", "This can't be undone. They can't apply to this team again.", locale: locale))
                    ],
                    cancelTitle: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale),
                    confirmTitle: PlayAreaPopupCopy.text("拒绝申请", "Decline application", locale: locale),
                    isDestructive: true,
                    isConfirmLoading: busy,
                    confirmIdentifier: "nearby.confirm",
                    cancelIdentifier: "nearby.cancel",
                    onCancel: onCancel,
                    onConfirm: onConfirm
                )
            }
        }
    }

    private func modal(title: String, message: String, confirm: String, cancel: String, destructive: Bool, confirmIdentifier: String, busy: Bool) -> some View {
        CYModal(
            title: title,
            message: message,
            cancelTitle: cancel,
            confirmTitle: confirm,
            isDestructive: destructive,
            isConfirmLoading: busy,
            confirmIdentifier: confirmIdentifier,
            cancelIdentifier: "nearby.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}
