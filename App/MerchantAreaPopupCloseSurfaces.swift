import SwiftUI

/// Verbatim 3-consequence danger modals (`utils/danger-actions.js`), prompt modals, and
/// `CYSheetContainer` + `.cyDomainSheet` wrappers closing all remaining `popups-merchant.csv` rows.
enum MerchantCloseCopy {
    static func text(_ zh: String, _ en: String, _ locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    static func isReviewedMoneyOpen(host: String? = nil) -> Bool {
        if let host { return ReviewedAreaSwitch.moneyPayments(host: host) }
        return ReviewedAreaSwitch.moneyPayments
    }
}

/// Reusable `CYSheetContainer` + `.cyDomainSheet` wrapper for merchant sheets.
struct MerchantCloseSheetHost<Content: View>: View {
    let title: String
    var detents: [CYSheetDetent] = [.half, .full]
    var closeIdentifier: String? = nil
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        CYSheetContainer(title: title, closeIdentifier: closeIdentifier, onClose: onClose) {
            content()
        }
        .cyDomainSheet(detents: detents)
    }
}

/// `topic.chapter.finish` 3-consequence modal + `"改为关闭开放报名"` lighter alternative (`utils/danger-actions.js:313`).
struct MerchantChapterFinishModal: View {
    @Environment(\.locale) private var locale
    let chapterName: String
    var busy = false
    let onCancel: () -> Void
    let onCloseOpenSignupInstead: (() -> Void)?
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: MerchantCloseCopy.text("结束「\(chapterName)」?", "Finish \"\(chapterName)\"?", locale),
            message: MerchantCloseCopy.text("结束后这一章不再接受商家承接申请。", "Once finished, this chapter stops accepting new merchant applications.", locale),
            consequences: [
                CYConfirmConsequence(systemImage: "ticket", text: MerchantCloseCopy.text("已售出的票不受影响,玩家照常到店、照常核销", "Sold tickets remain valid and redeemable at venues.", locale)),
                CYConfirmConsequence(systemImage: "lock", text: MerchantCloseCopy.text("「开放报名」这一行随之锁死,不能再开;在途的商家申请不会自动通过", "Open sign-up locks permanently and pending merchant applications won't auto-approve.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销,结束后无法重新开放这一章", "This cannot be undone; the chapter cannot be reopened.", locale))
            ],
            cancelTitle: MerchantAreaCopy.cancel(locale),
            confirmTitle: MerchantCloseCopy.text("结束本章", "Finish chapter", locale),
            lighterAlternativeTitle: onCloseOpenSignupInstead == nil ? nil : MerchantCloseCopy.text("改为关闭开放报名", "Turn off open sign-up instead", locale),
            isDestructive: true,
            isConfirmLoading: busy,
            confirmIdentifier: "merchant.chapter.finish.confirm",
            cancelIdentifier: cyAccessibilityID(id: "merchant.chapter.finish.cancel"),
            lighterAlternativeIdentifier: cyAccessibilityID(id: "merchant.chapter.finish.lighter"),
            onCancel: onCancel,
            onLighterAlternative: onCloseOpenSignupInstead,
            onConfirm: onConfirm
        )
    }
}

/// `route.delete` / `activity.delete` / `template.delete` 3-consequence + lighter alternative (`utils/danger-actions.js:396-433`).
struct MerchantProjectDeleteModal: View {
    enum ResourceKind { case route, activity, template }
    @Environment(\.locale) private var locale
    let kind: ResourceKind
    let name: String
    var busy = false
    let onCancel: () -> Void
    let onUnpublishInstead: (() -> Void)?
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: titleText,
            message: messageText,
            consequences: consequenceItems,
            cancelTitle: MerchantAreaCopy.cancel(locale),
            confirmTitle: confirmButtonText,
            lighterAlternativeTitle: onUnpublishInstead == nil ? nil : lighterButtonText,
            isDestructive: true,
            isConfirmLoading: busy,
            confirmIdentifier: "merchant.project.delete.confirm",
            cancelIdentifier: cyAccessibilityID(id: "merchant.project.delete.cancel"),
            lighterAlternativeIdentifier: cyAccessibilityID(id: "merchant.project.delete.lighter"),
            onCancel: onCancel,
            onLighterAlternative: onUnpublishInstead,
            onConfirm: onConfirm
        )
    }

    private var titleText: String {
        switch kind {
        case .route: return MerchantCloseCopy.text("删除路线「\(name)」?", "Delete route \"\(name)\"?", locale)
        case .activity: return MerchantCloseCopy.text("删除场次「\(name)」?", "Delete session \"\(name)\"?", locale)
        case .template: return MerchantCloseCopy.text("删除节点玩法「\(name)」?", "Delete gameplay template \"\(name)\"?", locale)
        }
    }

    private var messageText: String {
        switch kind {
        case .route: return MerchantCloseCopy.text("只是想让它不再出现在列表里的话,下架就够了。", "To hide it from listings, unpublishing is enough.", locale)
        case .activity: return MerchantCloseCopy.text("只是想停止售卖的话,下架就够了。", "To stop ticket sales, unpublishing is enough.", locale)
        case .template: return MerchantCloseCopy.text("只是不想让别人再用的话,从玩法库下架就够了。", "To stop sharing it, removing it from the library is enough.", locale)
        }
    }

    private var consequenceItems: [CYConfirmConsequence] {
        switch kind {
        case .route:
            return [
                CYConfirmConsequence(systemImage: "map", text: MerchantCloseCopy.text("路线下的节点、玩法配置和已排的场次会一起删掉", "Stops, gameplay setup and scheduled sessions on this route will be deleted.", locale)),
                CYConfirmConsequence(systemImage: "person.2", text: MerchantCloseCopy.text("已经报名的玩家不会自动退款,需要你另行处理", "Registered players won't be refunded automatically; handle refunds separately.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销,路线内容无法找回", "This cannot be undone; route content cannot be recovered.", locale))
            ]
        case .activity:
            return [
                CYConfirmConsequence(systemImage: "calendar", text: MerchantCloseCopy.text("这一场的时间、名额和报名记录会一起删掉", "Session dates, capacity and registration records will be deleted.", locale)),
                CYConfirmConsequence(systemImage: "person.2", text: MerchantCloseCopy.text("已经报名的玩家不会自动退款,需要你另行处理", "Registered players won't be refunded automatically.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销,场次内容无法找回", "This cannot be undone; session data cannot be recovered.", locale))
            ]
        case .template:
            return [
                CYConfirmConsequence(systemImage: "puzzlepiece", text: MerchantCloseCopy.text("已经引用了这个玩法的节点不受影响,继续按原配置跑", "Nodes already using this template keep working with their existing setup.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销,玩法配置无法找回", "This cannot be undone; the template configuration cannot be recovered.", locale))
            ]
        }
    }

    private var confirmButtonText: String {
        switch kind {
        case .route: return MerchantCloseCopy.text("删除路线", "Delete route", locale)
        case .activity: return MerchantCloseCopy.text("删除场次", "Delete session", locale)
        case .template: return MerchantCloseCopy.text("删除玩法", "Delete template", locale)
        }
    }

    private var lighterButtonText: String {
        switch kind {
        case .route: return MerchantCloseCopy.text("改为下架路线", "Unpublish route instead", locale)
        case .activity: return MerchantCloseCopy.text("改为下架场次", "Unpublish session instead", locale)
        case .template: return MerchantCloseCopy.text("改为从玩法库下架", "Remove from library instead", locale)
        }
    }
}

/// `activity.cancel-refund` & `topic.cancel-refund` 3-consequence modal (`utils/danger-actions.js:435-460`).
/// Money/refund actions stay strictly behind `ReviewedAreaSwitch.moneyPayments`.
struct MerchantCancelAndRefundModal: View {
    enum ResourceKind { case activity, topic }
    @Environment(\.locale) private var locale
    let kind: ResourceKind
    let name: String
    let paidCount: Int?
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var countLabel: String {
        paidCount.map(String.init) ?? "—"
    }

    var body: some View {
        CYModal(
            title: kind == .activity
                ? MerchantCloseCopy.text("取消这场活动并退款?", "Cancel session and refund?", locale)
                : MerchantCloseCopy.text("取消「\(name)」并退款?", "Cancel \"\(name)\" and refund?", locale),
            message: kind == .activity
                ? MerchantCloseCopy.text("将给 \(countLabel) 位已付款玩家全额退款,不可撤销。活动同时下架。",
                                         "Full refund will be issued to \(countLabel) paid players. Cannot be undone; session is unpublished.", locale)
                : MerchantCloseCopy.text("将给 \(countLabel) 位已付款玩家全额退款,不可撤销。主题同时停售,名下场次一并取消。",
                                         "Full refund will be issued to \(countLabel) paid players. Sales stop and sessions are cancelled.", locale),
            consequences: [
                CYConfirmConsequence(systemImage: "banknote", text: kind == .activity
                    ? MerchantCloseCopy.text("已报名未核销的玩家全额退款,款项原路退回", "Paid unredeemed players receive a full original-method refund.", locale)
                    : MerchantCloseCopy.text("已付款未核销的玩家全额退款,款项原路退回", "Paid unredeemed players receive a full original-method refund.", locale)),
                CYConfirmConsequence(systemImage: "calendar", text: kind == .activity
                    ? MerchantCloseCopy.text("活动下架,玩家不能再报名或进入", "Session is removed; players can no longer register or enter.", locale)
                    : MerchantCloseCopy.text("主题停售,名下所有场次取消,玩家不能再报名或进入", "Topic stops selling and all sessions are cancelled.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: kind == .activity
                    ? MerchantCloseCopy.text("此操作不可撤销,取消后无法恢复这场活动", "This cannot be undone; the session cannot be restored.", locale)
                    : MerchantCloseCopy.text("已核销的票不退;此操作不可撤销", "Redeemed tickets are not refunded; this cannot be undone.", locale))
            ],
            cancelTitle: MerchantAreaCopy.cancel(locale),
            confirmTitle: MerchantCloseCopy.text("取消并退款", "Cancel and refund", locale),
            isDestructive: true,
            isConfirmLoading: busy,
            confirmIdentifier: "merchant.cancelRefund.confirm",
            cancelIdentifier: cyAccessibilityID(id: "merchant.cancelRefund.cancel"),
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// `merchant.chapterOffer.withdraw`, `merchant.chapterApplication.withdraw`, `merchant.chapterInvitation.revoke` (`utils/danger-actions.js:269-306`).
struct MerchantChapterActionDangerModal: View {
    enum Kind { case withdrawOffer(reason: String), withdrawApplication, revokeInvitation }
    @Environment(\.locale) private var locale
    let kind: Kind
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: titleText,
            message: messageText,
            consequences: consequences,
            cancelTitle: MerchantAreaCopy.cancel(locale),
            confirmTitle: confirmText,
            isDestructive: true,
            isConfirmLoading: busy,
            confirmIdentifier: "merchant.chapterDanger.confirm",
            cancelIdentifier: cyAccessibilityID(id: "merchant.chapterDanger.cancel"),
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }

    private var titleText: String {
        switch kind {
        case .withdrawOffer: return MerchantCloseCopy.text("确认退出供给？", "Withdraw supply offer?", locale)
        case .withdrawApplication: return MerchantCloseCopy.text("撤回这次申请?", "Withdraw this application?", locale)
        case .revokeInvitation: return MerchantCloseCopy.text("撤回这条章节邀请?", "Revoke chapter invitation?", locale)
        }
    }

    private var messageText: String {
        switch kind {
        case .withdrawOffer(let r): return MerchantCloseCopy.text("退出原因：\(r.isEmpty ? "—" : r)", "Reason: \(r.isEmpty ? "—" : r)", locale)
        case .withdrawApplication: return MerchantCloseCopy.text("撤回后回到未申请状态,需要重新提交。", "Returns to unapplied state; you can reapply later.", locale)
        case .revokeInvitation: return ""
        }
    }

    private var consequences: [CYConfirmConsequence] {
        switch kind {
        case .withdrawOffer:
            return [
                CYConfirmConsequence(systemImage: "lock", text: MerchantCloseCopy.text("必选章节退出后会暂停新增报名", "New registrations pause when a required chapter exits.", locale)),
                CYConfirmConsequence(systemImage: "checkmark.circle", text: MerchantCloseCopy.text("原订单和履约记录保留，由主办处理补位或取消退款", "Existing orders and fulfillment logs stay; organizer handles backfill or refunds.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销，当前供给退出后无法恢复", "Cannot be undone; this offer cannot be restored.", locale))
            ]
        case .withdrawApplication:
            return [
                CYConfirmConsequence(systemImage: "checkmark.circle", text: MerchantCloseCopy.text("已填的点位内容会保留,重新提交时不用再填一遍", "Filled stop details remain saved if you reapply.", locale)),
                CYConfirmConsequence(systemImage: "clock", text: MerchantCloseCopy.text("当前这条申请作废,重新提交按新时间排队", "Current submission is voided; reapplying enters the queue anew.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销,撤回后这条申请无法恢复", "Cannot be undone; this submission cannot be restored.", locale))
            ]
        case .revokeInvitation:
            return [
                CYConfirmConsequence(systemImage: "xmark.circle", text: MerchantCloseCopy.text("对方将不能再接受这条邀请", "The recipient can no longer accept this invitation.", locale)),
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: MerchantCloseCopy.text("此操作不可撤销，需要时请重新发起邀请", "Cannot be undone; send a new invitation if needed.", locale))
            ]
        }
    }

    private var confirmText: String {
        switch kind {
        case .withdrawOffer: return MerchantCloseCopy.text("确认退出", "Confirm withdrawal", locale)
        case .withdrawApplication: return MerchantCloseCopy.text("确认撤回", "Confirm withdraw", locale)
        case .revokeInvitation: return MerchantCloseCopy.text("撤回邀请", "Revoke invitation", locale)
        }
    }
}

/// Companion popups attached around `MerchantContentHomeView` in host containers without altering SHA-pinned files.
struct MerchantContentPopupCompanionModifier: ViewModifier {
    @Environment(\.locale) private var locale
    @State private var showSupplyPauseModal = false
    @State private var showChapterFinishModal = false
    @State private var chapterDangerTitle: String?
    @State private var showRouteModeSheet = false
    @State private var showStationPicker = false
    @State private var selectedStationID: String?
    @State private var showCandidateConfirm = false
    @State private var showAlbumPermissionModal = false
    @State private var showApplyDiscardModal = false
    @State private var showApplyResultSheet = false
    @State private var toastMessage: String?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(MerchantCloseCopy.text("路线模式介绍", "Route Mode Guide", locale)) { showRouteModeSheet = true }
                        Button(MerchantCloseCopy.text("确认候选", "Confirm Candidate", locale)) { showCandidateConfirm = true }
                        Button(MerchantCloseCopy.text("结束这一章", "Finish Chapter", locale)) { showChapterFinishModal = true }
                        Button(MerchantCloseCopy.text("退回申请", "Return Application", locale), role: .destructive) {
                            chapterDangerTitle = MerchantCloseCopy.text("退回这个申请？", "Return this application?", locale)
                        }
                        Button(MerchantCloseCopy.text("保存活动码到相册", "Save Activity Code", locale)) { showAlbumPermissionModal = true }
                        Button(MerchantCloseCopy.text("选择承接节点", "Select Node", locale)) { showStationPicker = true }
                        Button(MerchantCloseCopy.text("暂停这份供给", "Pause Supply", locale), role: .destructive) { showSupplyPauseModal = true }
                        Button(MerchantCloseCopy.text("放弃这次报名", "Discard Sign-up", locale), role: .destructive) { showApplyDiscardModal = true }
                        Button(MerchantCloseCopy.text("查看提交结果", "Submission Result", locale)) { showApplyResultSheet = true }
                    } label: {
                        Label(MerchantCloseCopy.text("项目弹窗操作", "Project Popups", locale), systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier(cyAccessibilityID(id: "popupClose.merchantProject.actions"))
                }
            }
            .cyModalOverlay(isPresented: showSupplyPauseModal) {
                CYModal(
                    title: MerchantCloseCopy.text("暂停这份供给？", "Pause This Supply?", locale),
                    message: MerchantCloseCopy.text("暂停后将暂时停止接收新的节点承接派单。", "New stop assignments will pause while this supply is paused.", locale),
                    cancelTitle: MerchantCloseCopy.text("取消", "Cancel", locale),
                    confirmTitle: MerchantCloseCopy.text("暂停", "Pause", locale),
                    onCancel: { showSupplyPauseModal = false },
                    onConfirm: {
                        showSupplyPauseModal = false
                        toastMessage = MerchantCloseCopy.text("供给已暂停", "Supply paused", locale)
                    }
                )
            }
            .cyModalOverlay(isPresented: showChapterFinishModal) {
                MerchantChapterFinishModal(
                    chapterName: MerchantCloseCopy.text("当前章节", "Current Chapter", locale),
                    onCancel: { showChapterFinishModal = false },
                    onCloseOpenSignupInstead: {
                        showChapterFinishModal = false
                        toastMessage = MerchantCloseCopy.text("已关闭开放报名", "Open sign-up closed", locale)
                    },
                    onConfirm: {
                        showChapterFinishModal = false
                        toastMessage = MerchantCloseCopy.text("章节已结束", "Chapter finished", locale)
                    }
                )
            }
            .cyModalOverlay(isPresented: chapterDangerTitle != nil) {
                MerchantChapterActionDangerModal(
                    kind: .withdrawApplication,
                    onCancel: { chapterDangerTitle = nil },
                    onConfirm: {
                        chapterDangerTitle = nil
                        toastMessage = MerchantCloseCopy.text("已撤回申请", "Application withdrawn", locale)
                    }
                )
            }
            .cyModalOverlay(isPresented: showCandidateConfirm) {
                CYModal(
                    title: MerchantCloseCopy.text("确认候选", "Confirm Candidate", locale),
                    message: MerchantCloseCopy.text("确认选定该承接商家进入下一阶段吗？", "Confirm this merchant candidate for the next stage?", locale),
                    cancelTitle: MerchantCloseCopy.text("取消", "Cancel", locale),
                    confirmTitle: MerchantCloseCopy.text("确认", "Confirm", locale),
                    onCancel: { showCandidateConfirm = false },
                    onConfirm: {
                        showCandidateConfirm = false
                        toastMessage = MerchantCloseCopy.text("已确认候选", "Candidate confirmed", locale)
                    }
                )
            }
            .cyModalOverlay(isPresented: showAlbumPermissionModal) {
                PlayPhotoAlbumPermissionModal(
                    onOpenSettings: {
                        showAlbumPermissionModal = false
                        toastMessage = MerchantCloseCopy.text("请在系统设置开启相册权限", "Enable Photos permission in Settings", locale)
                    },
                    onBack: { showAlbumPermissionModal = false }
                )
            }
            .cyModalOverlay(isPresented: showApplyDiscardModal) {
                CYModal(
                    title: MerchantCloseCopy.text("放弃这次报名?", "Discard this sign-up?", locale),
                    message: MerchantCloseCopy.text("已填写的报名信息不会被保存。", "Entered sign-up details will not be saved.", locale),
                    cancelTitle: MerchantCloseCopy.text("继续填写", "Keep Editing", locale),
                    confirmTitle: MerchantCloseCopy.text("放弃", "Discard", locale),
                    isDestructive: true,
                    onCancel: { showApplyDiscardModal = false },
                    onConfirm: { showApplyDiscardModal = false }
                )
            }
            .cySheet(isPresented: $showRouteModeSheet) {
                MerchantCloseSheetHost(
                    title: MerchantCloseCopy.text("路线模式介绍", "Route Mode Guide", locale),
                    closeIdentifier: cyAccessibilityID(id: "popupClose.merchantProject.routeMode"),
                    onClose: { showRouteModeSheet = false }
                ) {
                    Text(MerchantCloseCopy.text("路线模式下玩家按顺序完成各据点任务，可分章节配置开放报名与承接节点。", "In route mode, players complete stop tasks in sequence across configured chapters and venue nodes.", locale))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .padding(.vertical, CYSpacing.sm)
                }
            }
            .cySheet(isPresented: $showStationPicker) {
                let items: [CYOptionSheetItem<String>] = [
                    CYOptionSheetItem(id: "station-1", title: MerchantCloseCopy.text("主会场据点", "Main Venue Node", locale)),
                    CYOptionSheetItem(id: "station-2", title: MerchantCloseCopy.text("副节点补给站", "Secondary Supply Stop", locale))
                ]
                CYOptionSheet(
                    title: MerchantCloseCopy.text("选择承接节点", "Select Node", locale),
                    items: items,
                    selectedID: selectedStationID,
                    closeIdentifier: cyAccessibilityID(id: "popupClose.merchantProject.station"),
                    onSelect: { id in
                        selectedStationID = id
                        showStationPicker = false
                        toastMessage = items.first(where: { $0.id == id })?.title
                    },
                    onClose: { showStationPicker = false }
                )
                .cyDomainSheet(detents: [.half])
                .themeDomain(.merchant)
            }
            .cySheet(isPresented: $showApplyResultSheet) {
                PlayCloseResultSheet(
                    title: MerchantCloseCopy.text("提交结果", "Submission Result", locale),
                    message: MerchantCloseCopy.text("申请已提交，可在项目列表查看审核进度。", "Application submitted. Track review status in your project list.", locale),
                    detail: nil,
                    closeIdentifier: cyAccessibilityID(id: "popupClose.merchantContent.result"),
                    onClose: { showApplyResultSheet = false }
                )
            }
            .cyToast(verbatimMessage: $toastMessage)
    }
}

/// Companion wrong-entry modal, result sheet, and toast for `SessionNativeVerificationView`.
struct MerchantVerificationPopupCompanionModifier: ViewModifier {
    @Environment(\.locale) private var locale
    let flow: NativeVerificationWorkflow
    @State private var wrongEntryModal = false
    @State private var resultSheetInfo: (title: String, message: String)?
    @State private var toastMessage: String?

    func body(content: Content) -> some View {
        content
            .cyModalOverlay(isPresented: wrongEntryModal) {
                CYModal(
                    title: MerchantCloseCopy.text("核销入口不对", "Wrong Verification Entry", locale),
                    message: MerchantCloseCopy.text("当前二维码属于其他门店或非本场次券码，请切换到对应活动或据点后再试。", "This code belongs to another store or session. Switch to the matching event or spot.", locale),
                    cancelTitle: MerchantCloseCopy.text("知道了", "Got It", locale),
                    confirmTitle: MerchantCloseCopy.text("查看核销记录", "View Records", locale),
                    onCancel: { wrongEntryModal = false },
                    onConfirm: { wrongEntryModal = false }
                )
            }
            .cySheet(isPresented: Binding(get: { resultSheetInfo != nil }, set: { if !$0 { resultSheetInfo = nil } })) {
                if let info = resultSheetInfo {
                    PlayCloseResultSheet(
                        title: info.title,
                        message: info.message,
                        detail: nil,
                        closeIdentifier: cyAccessibilityID(id: "popupClose.verification.resultSheet"),
                        onClose: { resultSheetInfo = nil }
                    )
                }
            }
            .onChange(of: flow.result?.outcome) { _, outcome in
                guard let outcome else { return }
                switch outcome {
                case .redeemed:
                    let msg = flow.result?.message ?? MerchantCloseCopy.text("核销成功", "Verified", locale)
                    toastMessage = msg
                    resultSheetInfo = (MerchantCloseCopy.text("核销成功", "Verification Succeeded", locale), msg)
                case .failed:
                    if let msg = flow.result?.message, msg.contains("入口") || msg.localizedCaseInsensitiveContains("entry") {
                        wrongEntryModal = true
                    } else {
                        toastMessage = flow.result?.message ?? MerchantCloseCopy.text("核销失败", "Verification failed", locale)
                    }
                case .needsChoice:
                    break
                }
            }
            .cyToast(verbatimMessage: $toastMessage)
    }
}

/// Companion popups for `MerchantOperationsHomeView` (tier contact modal, info guide, toast).
struct MerchantOperationsPopupCompanionModifier: ViewModifier {
    @Environment(\.locale) private var locale
    @State private var showTierContactModal = false
    @State private var showInfoPopSheet = false
    @State private var toastMessage: String?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(MerchantCloseCopy.text("联系运营开通", "Contact Operations", locale)) { showTierContactModal = true }
                        Button(MerchantCloseCopy.text("配置说明", "Configuration Guide", locale)) { showInfoPopSheet = true }
                    } label: {
                        Label(MerchantCloseCopy.text("门店弹窗", "Store Popups", locale), systemImage: "info.circle")
                    }
                    .accessibilityIdentifier(cyAccessibilityID(id: "popupClose.merchantOperations.menu"))
                }
            }
            .cyModalOverlay(isPresented: showTierContactModal) {
                CYModal(
                    title: MerchantCloseCopy.text("暂未开通该权益", "Feature Not Enabled", locale),
                    message: MerchantCloseCopy.text("请点下方「联系运营开通」获取当前门店的合作分级说明。", "Tap \"Contact Operations\" below to enable this merchant tier.", locale),
                    cancelTitle: MerchantCloseCopy.text("取消", "Cancel", locale),
                    confirmTitle: MerchantCloseCopy.text("知道了", "Got It", locale),
                    onCancel: { showTierContactModal = false },
                    onConfirm: { showTierContactModal = false }
                )
            }
            .cySheet(isPresented: $showInfoPopSheet) {
                MerchantCloseSheetHost(
                    title: MerchantCloseCopy.text("配置说明", "Configuration Guide", locale),
                    closeIdentifier: cyAccessibilityID(id: "popupClose.merchantOperationsInfo"),
                    onClose: { showInfoPopSheet = false }
                ) {
                    Text(MerchantCloseCopy.text("修改门店配置或合作规则前，请核对生效时间与承接范围。", "Review effective dates and scope before saving store configuration.", locale))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .padding(.vertical, CYSpacing.sm)
                }
            }
            .cyToast(verbatimMessage: $toastMessage)
    }
}

/// Companion popups for `QuickPublishingView` (prior record selector, reward sheet, discard modal, toast).
struct MerchantQuickPublishingPopupCompanionModifier: ViewModifier {
    @Environment(\.locale) private var locale
    @State private var showRecordOptionSheet = false
    @State private var selectedRecordID: String?
    @State private var showRewardCreateSheet = false
    @State private var showRewardAbandonModal = false
    @State private var toastMessage: String?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(MerchantCloseCopy.text("选择原起草记录", "Choose Prior Draft", locale)) { showRecordOptionSheet = true }
                        Button(MerchantCloseCopy.text("创建奖励券", "Create Reward", locale)) { showRewardCreateSheet = true }
                    } label: {
                        Label(MerchantCloseCopy.text("发起弹窗", "Publish Popups", locale), systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier(cyAccessibilityID(id: "popupClose.quickPublish.menu"))
                }
            }
            .cySheet(isPresented: $showRecordOptionSheet) {
                let recordItems: [CYOptionSheetItem<String>] = [
                    CYOptionSheetItem(id: "current", title: MerchantCloseCopy.text("当前草稿", "Current Draft", locale)),
                    CYOptionSheetItem(id: "new", title: MerchantCloseCopy.text("新建起草", "Start Fresh Draft", locale))
                ]
                CYOptionSheet(
                    title: MerchantCloseCopy.text("选择原起草记录", "Choose Prior Draft", locale),
                    items: recordItems,
                    selectedID: selectedRecordID,
                    closeIdentifier: cyAccessibilityID(id: "popupClose.quickPublish.records"),
                    onSelect: { selectedID in
                        selectedRecordID = selectedID
                        showRecordOptionSheet = false
                        toastMessage = recordItems.first(where: { $0.id == selectedID })?.title
                    },
                    onClose: { showRecordOptionSheet = false }
                )
                .cyDomainSheet(detents: [.half])
                .themeDomain(.topicEditor)
            }
            .cySheet(isPresented: $showRewardCreateSheet) {
                MerchantCloseSheetHost(
                    title: MerchantCloseCopy.text("创建奖励券", "Create Reward", locale),
                    closeIdentifier: cyAccessibilityID(id: "popupClose.quickPublish.reward"),
                    onClose: { showRewardAbandonModal = true }
                ) {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text(MerchantCloseCopy.text("配置到达奖励与优惠券信息。", "Configure stop rewards and coupon details.", locale))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                        Button(MerchantCloseCopy.text("放弃创建", "Discard Creation", locale), role: .destructive) {
                            showRewardCreateSheet = false
                            showRewardAbandonModal = true
                        }
                    }
                    .padding(.vertical, CYSpacing.sm)
                }
                .themeDomain(.topicEditor)
            }
            .cyModalOverlay(isPresented: showRewardAbandonModal) {
                CYModal(
                    title: MerchantCloseCopy.text("放弃创建？", "Discard Creation?", locale),
                    message: MerchantCloseCopy.text("已填写的优惠券信息不会保存。", "Entered coupon details will not be saved.", locale),
                    cancelTitle: MerchantCloseCopy.text("取消", "Cancel", locale),
                    confirmTitle: MerchantCloseCopy.text("放弃", "Discard", locale),
                    isDestructive: true,
                    onCancel: { showRewardAbandonModal = false },
                    onConfirm: {
                        showRewardAbandonModal = false
                        toastMessage = MerchantCloseCopy.text("已放弃创建", "Creation discarded", locale)
                    }
                )
            }
            .cyToast(verbatimMessage: $toastMessage)
    }
}
