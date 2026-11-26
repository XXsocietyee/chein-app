import SwiftUI

/// Shared DesignSystem modals, option sheets, and result containers closing all remaining
/// `popups-play.csv` rows with verbatim mini-program `zh-Hans` copy and natural English.
enum PlayCloseCopy {
    static func text(_ zh: String, _ en: String, _ locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    static func cancel(_ locale: Locale) -> String { text("取消", "Cancel", locale) }
    static func confirm(_ locale: Locale) -> String { text("确认", "Confirm", locale) }
    static func close(_ locale: Locale) -> String { text("关闭", "Close", locale) }
}

/// Optional captain-note prompt for nearby team applications (`subpackageRoam/nearby/index.js:636`).
struct PlayNearbyApplyNoteModal: View {
    @Environment(\.locale) private var locale
    let teamName: String
    @Binding var note: String
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var trimmedLength: Int {
        note.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var validation: String? {
        guard trimmedLength > NearbyTeamRequest.maxApplyMessageLength else { return nil }
        return PlayCloseCopy.text(
            "留言最多 \(NearbyTeamRequest.maxApplyMessageLength) 字（当前 \(trimmedLength)）",
            "Note can be at most \(NearbyTeamRequest.maxApplyMessageLength) characters (\(trimmedLength))",
            locale
        )
    }

    var body: some View {
        CYPromptModal(
            title: PlayCloseCopy.text("申请加入这支队伍", "Apply to join this team", locale),
            message: teamName.isEmpty ? nil : teamName,
            text: $note,
            placeholder: PlayCloseCopy.text("想跟队长说一句(可选):同场打算、几个人…", "Optional note for captain: plan, party size...", locale),
            validationMessage: validation,
            cancelTitle: PlayCloseCopy.cancel(locale),
            confirmTitle: PlayCloseCopy.text("提交申请", "Submit application", locale),
            isConfirmLoading: busy,
            cancelIdentifier: cyAccessibilityID(id: "nearby.apply.cancel"),
            confirmIdentifier: "nearby.apply.confirm",
            onCancel: onCancel,
            onConfirm: {
                guard trimmedLength <= NearbyTeamRequest.maxApplyMessageLength else { return }
                onConfirm()
            }
        )
    }
}

/// Map visual styles for Nearby Teams (`subpackageRoam/nearby/index.wxml:311`).
enum PlayNearbyMapStyle: String, CaseIterable, Hashable, Identifiable {
    case paper, standard, dark, cyber2077
    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .standard: return PlayCloseCopy.text("白（标准浅色）", "Light (Standard)", locale)
        case .dark: return PlayCloseCopy.text("黑（暗夜视图）", "Dark (Night)", locale)
        case .paper: return PlayCloseCopy.text("纸本", "Paper", locale)
        case .cyber2077: return PlayCloseCopy.text("2077", "2077", locale)
        }
    }

    func subtitle(locale: Locale) -> String {
        switch self {
        case .standard: return PlayCloseCopy.text("清晰道路与门店标注", "Clear streets and venue pins", locale)
        case .dark: return PlayCloseCopy.text("适合夜间漫游与户外队旗识别", "Low-glare night map view", locale)
        case .paper: return PlayCloseCopy.text("温润羊皮纸质感城市底图", "Warm parchment city tone", locale)
        case .cyber2077: return PlayCloseCopy.text("霓虹高对比夜行标尺", "High-contrast night tactical grid", locale)
        }
    }
}

/// `地图样式` `CYOptionSheet` (`subpackageRoam/nearby/index.wxml:311`).
struct PlayAreaNearbyMapStyleSheet: View {
    @Environment(\.locale) private var locale
    let selected: PlayNearbyMapStyle
    let onSelect: (PlayNearbyMapStyle) -> Void
    let onClose: () -> Void

    var body: some View {
        CYOptionSheet(
            title: PlayCloseCopy.text("地图样式", "Map style", locale),
            items: PlayNearbyMapStyle.allCases.map {
                CYOptionSheetItem(id: $0, title: $0.title(locale: locale), subtitle: $0.subtitle(locale: locale))
            },
            selectedID: selected,
            onSelect: onSelect,
            onClose: onClose
        )
        .cyDomainSheet(detents: [.half])
        .accessibilityIdentifier("nearby.mapStyleSheet")
    }
}

/// Photo library permission prompt (`subpackageRoam/session/index.js:451`).
struct PlayPhotoAlbumPermissionModal: View {
    @Environment(\.locale) private var locale
    let onOpenSettings: () -> Void
    let onBack: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("需要相册权限", "Photo library access required", locale),
            message: PlayCloseCopy.text("在设置里允许保存到相册，返回后点“重试保存”。", "Allow saving to Photos in Settings, then return and tap Retry Save.", locale),
            cancelTitle: PlayCloseCopy.text("返回", "Back", locale),
            confirmTitle: PlayCloseCopy.text("去设置", "Settings", locale),
            confirmIdentifier: "play.albumPermission.settings",
            cancelIdentifier: cyAccessibilityID(id: "play.albumPermission.back"),
            onCancel: onBack,
            onConfirm: onOpenSettings
        )
    }
}

/// Payment confirmation still pending (`pages/activity/baoming/baoming.js:1973, 1988`).
/// Must remain behind `PlayAreaPopupCopy.paymentsOpen` (`ReviewedAreaSwitch.moneyPayments`).
struct PlayPaymentPendingModal: View {
    @Environment(\.locale) private var locale
    let detailed: Bool
    let onGoOrders: () -> Void
    let onClose: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("支付结果待确认", "Payment status pending", locale),
            message: detailed
                ? PlayCloseCopy.text("这笔付款还在确认中，请勿重复支付。稍后可到「我的-订单」查看最终状态。",
                                     "This payment is still being confirmed. Please do not pay again; check Me > Orders shortly.", locale)
                : PlayCloseCopy.text("请勿重复支付，稍后到订单中查看结果",
                                     "Please do not pay again; check the final result in your orders shortly.", locale),
            cancelTitle: PlayCloseCopy.text("稍后再看", "Later", locale),
            confirmTitle: PlayCloseCopy.text("查看订单", "View orders", locale),
            confirmIdentifier: "registration.paymentPending.orders",
            cancelIdentifier: cyAccessibilityID(id: "registration.paymentPending.close"),
            onCancel: onClose,
            onConfirm: onGoOrders
        )
    }
}

/// Rotate attendance code confirm modal (`pages/activity/components/event-attendance/index.js:136`).
struct PlayAttendanceRotateModal: View {
    @Environment(\.locale) private var locale
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("更换签到码？", "Rotate check-in code?", locale),
            message: PlayCloseCopy.text("旧码会失效，签到记录保留。", "The previous code will stop working, while existing check-in records remain.", locale),
            cancelTitle: PlayCloseCopy.cancel(locale),
            confirmTitle: PlayCloseCopy.text("更换", "Rotate", locale),
            isDestructive: true,
            isConfirmLoading: busy,
            confirmIdentifier: "attendance.rotate.confirm",
            cancelIdentifier: "attendance.rotate.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Dial organizer phone confirm (`pages/activity/components/event-attendance/index.js:165`).
struct PlayAttendanceDialModal: View {
    @Environment(\.locale) private var locale
    let hostName: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("拨打电话", "Call organizer", locale),
            message: PlayCloseCopy.text("拨打「\(hostName)」的电话？", "Call \(hostName)?", locale),
            cancelTitle: PlayCloseCopy.cancel(locale),
            confirmTitle: PlayCloseCopy.text("拨打", "Call", locale),
            confirmIdentifier: "attendance.dial.confirm",
            cancelIdentifier: "attendance.dial.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Plan-fallback default ending confirmation (`pages/club/topic-detail/plan-fallback.js:46`).
struct PlayDirectorPlanFallbackConfirmModal: View {
    @Environment(\.locale) private var locale
    let reason: String
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("确认默认结局收尾", "Confirm default ending wrap-up", locale),
            message: PlayCloseCopy.text(
                "将以默认结局收尾，未完成的交易会释放，不消耗物资。原因：\(reason)",
                "End this run with the default ending. Unfinished trades will be released without consuming items. Reason: \(reason)",
                locale
            ),
            cancelTitle: PlayCloseCopy.cancel(locale),
            confirmTitle: PlayCloseCopy.text("确认收尾", "Confirm wrap-up", locale),
            isDestructive: true,
            isConfirmLoading: busy,
            confirmIdentifier: "director.planFallback.confirm",
            cancelIdentifier: "director.planFallback.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// PlayKit album retry review modal (`pages/play/components/playkit-album/index.js:34`).
struct PlayKitAlbumRetryModal: View {
    @Environment(\.locale) private var locale
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("查看/重试审核", "View / retry review", locale),
            message: PlayCloseCopy.text(
                "照片尚未提交相册。将查看原照片的审核结果；若已被拒绝或暂不可用，可能重新提交审核。审核批准后自动提交相册，如未自动提交请再次点击完成。",
                "Photo not yet submitted to album. Check the original review status or resubmit if needed.",
                locale
            ),
            cancelTitle: PlayCloseCopy.cancel(locale),
            confirmTitle: PlayCloseCopy.text("查看/重试", "Check / retry", locale),
            confirmIdentifier: "playkit.album.retry.confirm",
            cancelIdentifier: "playkit.album.retry.cancel",
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// Unsaved edit guard for Roam & Play composer/editor flows (`pages/roam/index.wxml:992`, `pages/play/index.wxml:1761`).
struct PlayUnsavedEditModal: View {
    @Environment(\.locale) private var locale
    let onKeepEditing: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        CYModal(
            title: PlayCloseCopy.text("放弃未保存修改？", "Discard unsaved changes?", locale),
            message: PlayCloseCopy.text("关闭后当前填写的内容不会被保存。", "Changes will not be saved if you close now.", locale),
            cancelTitle: PlayCloseCopy.text("继续编辑", "Keep editing", locale),
            confirmTitle: PlayCloseCopy.text("放弃", "Discard", locale),
            isDestructive: true,
            confirmIdentifier: "play.unsaved.discard",
            cancelIdentifier: cyAccessibilityID(id: "play.unsaved.keep"),
            onCancel: onKeepEditing,
            onConfirm: onDiscard
        )
    }
}

/// Reusable `CYSheetContainer` + `.cyDomainSheet` host wrapper for play-area sheets & result sheets.
struct PlayCloseSheetHost<Content: View>: View {
    let title: String
    var detents: [CYSheetDetent] = [.half, .full]
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        CYSheetContainer(title: title, onClose: onClose) {
            content()
        }
        .cyDomainSheet(detents: detents)
    }
}

/// Shared `cy-result-sheet` presentation inside `CYSheetContainer` for play & topic flows.
struct PlayCloseResultSheet: View {
    @Environment(\.locale) private var locale
    let title: String
    let message: String
    var detail: String? = nil
    var primaryTitle: String? = nil
    var onPrimary: (() -> Void)? = nil
    var closeIdentifier: String? = nil
    let onClose: () -> Void

    var body: some View {
        CYSheetContainer(title: title, closeIdentifier: closeIdentifier, onClose: onClose) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text(verbatim: message)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                if let detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
                CurA11yActions {
                    if let primaryTitle, let onPrimary {
                        Button(action: onPrimary) {
                            Text(verbatim: primaryTitle)
                        }
                        .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
                    }
                    Button(action: onClose) {
                        Text(verbatim: PlayCloseCopy.close(locale))
                    }
                    .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                }
            }
            .padding(CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.lg)
        }
        .cyDomainSheet(detents: [.half])
    }
}

/// Official attendance & contact surface (`pages/activity/components/event-attendance/index.js`).
@MainActor struct OfficialAttendanceSectionView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.popupCloseActions) private var popupCloseActions

    let eventID: Int
    let activityID: Int
    let organizer: Bool

    @State private var snapshot: OfficialAttendanceSnapshot?
    @State private var contact: OfficialPlayContact?
    @State private var showingCodeSheet = false
    @State private var showingRotateConfirm = false
    @State private var showingDialConfirm = false
    @State private var inputCredential = ""
    @State private var busy = false
    @State private var toastMessage: String?

    var body: some View {
        if snapshot != nil || contact != nil || organizer {
            Section {
                if let snapshot {
                    if !snapshot.meetingName.isEmpty {
                        LabeledContent(PlayCloseCopy.text("集合点", "Meeting point", locale), value: snapshot.meetingName)
                    }
                    if !snapshot.credential.isEmpty {
                        LabeledContent(PlayCloseCopy.text("签到码", "Check-in code", locale), value: snapshot.credential)
                    }
                    if !snapshot.checkedAtText.isEmpty {
                        LabeledContent(PlayCloseCopy.text("已签到", "Checked in", locale), value: snapshot.checkedAtText)
                    }
                }
                if organizer {
                    Button {
                        showingCodeSheet = true
                    } label: {
                        Text(verbatim: PlayCloseCopy.text("签到码设置与核验", "Check-in code & verification", locale))
                    }
                    .accessibilityIdentifier("attendance.organizer.open")
                } else {
                    Button {
                        showingCodeSheet = true
                    } label: {
                        Text(verbatim: PlayCloseCopy.text("现场签到", "Event check-in", locale))
                    }
                    .accessibilityIdentifier("attendance.player.open")
                }
                if let contact, !contact.phone.isEmpty {
                    Button {
                        showingDialConfirm = true
                    } label: {
                        Text(verbatim: PlayCloseCopy.text("联系主办", "Call organizer", locale))
                    }
                    .accessibilityIdentifier("attendance.contact.dial")
                }
            } header: {
                Text(verbatim: PlayCloseCopy.text("现场签到与联系", "On-site Check-in & Contact", locale))
            }
            .task(id: eventID) {
                if let loadAttendance = popupCloseActions.loadAttendance {
                    snapshot = await loadAttendance(eventID, organizer)
                }
                if activityID > 0, let loadContact = popupCloseActions.loadOfficialContact {
                    contact = await loadContact(activityID)
                }
            }
            .cySheet(isPresented: $showingCodeSheet) {
                PlayCloseSheetHost(
                    title: PlayCloseCopy.text(organizer ? "现场签到管理" : "输入签到码", organizer ? "Attendance Management" : "Enter Check-in Code", locale),
                    detents: [.half],
                    onClose: { showingCodeSheet = false }
                ) {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        if let code = snapshot?.credential, !code.isEmpty {
                            Text(verbatim: PlayCloseCopy.text("当前签到码：\(code)", "Current code: \(code)", locale))
                                .cyText(.cardTitle)
                                .foregroundStyle(CYColor.textPrimary)
                        }
                        if organizer {
                            Button {
                                showingCodeSheet = false
                                showingRotateConfirm = true
                            } label: {
                                Text(verbatim: PlayCloseCopy.text("更换签到码", "Rotate check-in code", locale))
                            }
                            .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                            .accessibilityIdentifier("attendance.rotate.trigger")
                        }
                        CYField(
                            label: PlayCloseCopy.text("签到码", "Check-in code", locale),
                            placeholder: PlayCloseCopy.text("输入签到码", "Enter code", locale),
                            text: $inputCredential
                        )
                        Button {
                            submitVerifyOrClaim()
                        } label: {
                            Text(verbatim: PlayCloseCopy.text(organizer ? "核验签到码" : "确认签到", organizer ? "Verify code" : "Check in", locale))
                        }
                        .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, isLoading: busy))
                        .disabled(busy || inputCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(CYSpacing.pageHorizontal)
                    .padding(.bottom, CYSpacing.lg)
                }
            }
            .cyModalOverlay(isPresented: showingRotateConfirm) {
                PlayAttendanceRotateModal(
                    busy: busy,
                    onCancel: { showingRotateConfirm = false },
                    onConfirm: { rotateCode() }
                )
            }
            .cyModalOverlay(isPresented: showingDialConfirm) {
                PlayAttendanceDialModal(
                    hostName: contact?.name.isEmpty == false ? (contact?.name ?? "") : PlayCloseCopy.text("主办方", "Organizer", locale),
                    onCancel: { showingDialConfirm = false },
                    onConfirm: {
                        showingDialConfirm = false
                        if let rawPhone = contact?.phone, !rawPhone.isEmpty,
                           let telURL = URL(string: "tel:\(rawPhone)") {
                            openURL(telURL)
                        } else {
                            toastMessage = PlayCloseCopy.text("主办电话不可用", "Organizer phone unavailable", locale)
                        }
                    }
                )
            }
            .cyToast(verbatimMessage: $toastMessage)
        }
    }

    private func rotateCode() {
        guard let sendCommand = popupCloseActions.sendAttendanceCommand else {
            showingRotateConfirm = false
            return
        }
        busy = true
        Task {
            defer { busy = false; showingRotateConfirm = false }
            let receipt = await sendCommand(eventID, .attendanceRotate, [:])
            if receipt?.state == .applied {
                toastMessage = PlayCloseCopy.text("签到码已更换", "Check-in code rotated", locale)
                if let loadAttendance = popupCloseActions.loadAttendance {
                    snapshot = await loadAttendance(eventID, organizer)
                }
            } else {
                toastMessage = PlayCloseCopy.text(receipt?.message.isEmpty == false ? (receipt?.message ?? "") : "更换签到码失败",
                                                  "Could not rotate code", locale)
            }
        }
    }

    private func submitVerifyOrClaim() {
        let code = inputCredential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, let sendCommand = popupCloseActions.sendAttendanceCommand else { return }
        busy = true
        Task {
            defer { busy = false }
            let action: OfficialAttendanceAction = organizer ? .attendanceVerify : .attendanceClaim
            let receipt = await sendCommand(eventID, action, ["credential": code])
            if receipt?.state == .applied {
                showingCodeSheet = false
                inputCredential = ""
                toastMessage = PlayCloseCopy.text(organizer ? "核验成功" : "签到成功", organizer ? "Verified" : "Checked in", locale)
                if let loadAttendance = popupCloseActions.loadAttendance {
                    snapshot = await loadAttendance(eventID, organizer)
                }
            } else {
                toastMessage = PlayCloseCopy.text(receipt?.message.isEmpty == false ? (receipt?.message ?? "") : "操作未成功",
                                                  "Action failed", locale)
            }
        }
    }
}
