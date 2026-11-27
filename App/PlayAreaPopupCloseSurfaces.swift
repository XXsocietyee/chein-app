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
            placeholder: PlayCloseCopy.text("想跟队长说一句(可选):同场打算、几个人…", "Optional note for captain: plan, party size…", locale),
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

/// Official attendance & contact surface (`pages/activity/components/event-attendance/index.wxml`).
/// Player (MP `wx:else`): 集合与联系 (meeting row → 导航, host row → 拨打; 集合信息加载失败 + 重试) → 到场签到 with
/// its chip (已签到 · HH:mm / 出示我的签到码 / 签到码结果未确认 · 刷新) → sheet 我的签到码 (QR, 号码布, 更换签到码).
@MainActor struct OfficialAttendanceSectionView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.popupCloseActions) private var popupCloseActions

    let eventID: Int
    let activityID: Int
    let organizer: Bool

    @State private var snapshot: OfficialAttendanceSnapshot?
    @State private var contact: OfficialPlayContact?
    @State private var loaded = false
    @State private var showingCodeSheet = false
    @State private var showingMyCode = false
    @State private var showingRotateConfirm = false
    @State private var showingDialConfirm = false
    @State private var claimUnknown = false
    @State private var inputCredential = ""
    @State private var busy = false
    @State private var toastMessage: String?

    private var player: OfficialAttendancePlayerView? {
        guard let snapshot else { return nil }
        return OfficialAttendancePlayerView(snapshot: snapshot, contact: contact)
    }
    private var loadFailed: Bool { loaded && snapshot == nil && popupCloseActions.loadAttendance != nil }

    var body: some View {
        Group {
            if organizer {
                organizerSection
            } else if !loaded {
                // P10: say what is happening while the first read runs (also keeps the load task attached).
                Section {
                    Label { Text(verbatim: PlayCloseCopy.text("正在读取集合与签到信息…", "Loading meeting and check-in info…", locale)) } icon: { ProgressView() }
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("attendance.player.loading")
                }
            } else {
                meetSection
                checkinSection
            }
        }
        .task(id: eventID) { await load() }
        .cySheet(isPresented: $showingCodeSheet) { organizerCodeSheet }
        .sheet(isPresented: $showingMyCode) { myCodeSheet }
        .cyModalOverlay(isPresented: showingRotateConfirm) {
            PlayAttendanceRotateModal(
                busy: busy,
                onCancel: { showingRotateConfirm = false },
                onConfirm: { rotateCode() }
            )
        }
        .cyModalOverlay(isPresented: showingDialConfirm) {
            PlayAttendanceDialModal(
                hostName: dialName,
                onCancel: { showingDialConfirm = false },
                onConfirm: {
                    showingDialConfirm = false
                    if let rawPhone = contact?.phone, !rawPhone.isEmpty,
                       let telURL = URL(string: "tel:\(rawPhone)") {
                        openURL(telURL)
                    } else {
                        toastMessage = PlayCloseCopy.text("拨号未完成，请重试", "The call did not start. Try again.", locale)
                    }
                }
            )
        }
        .cyToast(verbatimMessage: $toastMessage)
    }

    private var dialName: String {
        let name = contact?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? PlayCloseCopy.text("主办", "the organizer", locale) : name
    }

    // MARK: Player — 集合与联系

    @ViewBuilder private var meetSection: some View {
        if loadFailed {
            Section {
                CYInlineError(verbatim: PlayCloseCopy.text("集合信息加载失败", "Meeting info did not load", locale),
                              retryTitle: "action.retry") { Task { await load() } }
                    .accessibilityIdentifier("attendance.player.error")
            } header: {
                Text(verbatim: PlayCloseCopy.text("集合与联系", "Meeting & contact", locale))
            }
        } else if let player, !player.meetName.isEmpty || !player.phone.isEmpty {
            Section {
                if !player.meetName.isEmpty {
                    Button { navigate() } label: {
                        LabeledContent {
                            if player.canNavigate { Text(verbatim: PlayCloseCopy.text("导航", "Directions", locale)) }
                        } label: {
                            Label { Text(verbatim: meetLine(player)) } icon: { Image(systemName: "mappin.and.ellipse") }
                        }
                    }
                    .disabled(!player.canNavigate)
                    .accessibilityIdentifier("attendance.player.meet")
                }
                if !player.phone.isEmpty {
                    Button { showingDialConfirm = true } label: {
                        LabeledContent {
                            Text(verbatim: PlayCloseCopy.text("拨打", "Call", locale))
                        } label: {
                            Label { Text(verbatim: hostLine(player)) } icon: { Image(systemName: "phone") }
                        }
                    }
                    .accessibilityIdentifier("attendance.contact.dial")
                }
            } header: {
                Text(verbatim: PlayCloseCopy.text("集合与联系", "Meeting & contact", locale))
            }
        }
    }

    private func meetLine(_ player: OfficialAttendancePlayerView) -> String {
        if let month = player.meetMonth, let day = player.meetDay {
            return PlayCloseCopy.text("\(month)月\(day)日 \(player.meetTime) · \(player.meetName)集合",
                                      "Meet at \(player.meetName) · \(month)/\(day) \(player.meetTime)", locale)
        }
        return PlayCloseCopy.text("\(player.meetName)集合", "Meet at \(player.meetName)", locale)
    }

    private func hostLine(_ player: OfficialAttendancePlayerView) -> String {
        if player.hostName.isEmpty { return PlayCloseCopy.text("联系主办", "Contact the organizer", locale) }
        return PlayCloseCopy.text("联系主办 · \(player.hostName)", "Contact the organizer · \(player.hostName)", locale)
    }

    private func navigate() {
        guard let snapshot, let lat = snapshot.latitude, let lng = snapshot.longitude else { return }
        var parts = URLComponents()
        parts.scheme = "maps"
        parts.host = ""
        parts.queryItems = [URLQueryItem(name: "ll", value: "\(lat),\(lng)"),
                            URLQueryItem(name: "q", value: snapshot.meetingName.isEmpty ? snapshot.meetingAddress : snapshot.meetingName)]
        if let url = parts.url { openURL(url) }
    }

    // MARK: Player — 到场签到

    @ViewBuilder private var checkinSection: some View {
        if let checkin = player?.checkin {
            Section {
                if checkin.done {
                    LabeledContent {
                        Text(verbatim: PlayCloseCopy.text("已记录", "Recorded", locale))
                    } label: {
                        Label { Text(verbatim: PlayCloseCopy.text("已签到 · \(checkin.doneAt)", "Checked in · \(checkin.doneAt)", locale)) } icon: { Image(systemName: "checkmark.circle.fill") }
                    }
                    .accessibilityIdentifier("attendance.player.done")
                } else if checkin.show {
                    Button { showMyCode() } label: {
                        LabeledContent {
                            Text(verbatim: PlayCloseCopy.text("出示", "Show", locale))
                        } label: {
                            Label { Text(verbatim: PlayCloseCopy.text("出示我的签到码", "Show my check-in code", locale)) } icon: { Image(systemName: "qrcode") }
                        }
                    }
                    .accessibilityIdentifier("attendance.player.open")
                }
                if claimUnknown {
                    Button { Task { await load() } } label: {
                        Text(verbatim: PlayCloseCopy.text("签到码结果未确认 · 刷新", "Check-in code not confirmed · Refresh", locale))
                    }
                    .accessibilityIdentifier("attendance.player.unknown")
                }
            } header: {
                HStack {
                    Text(verbatim: PlayCloseCopy.text("到场签到", "Check-in", locale))
                    Spacer()
                    CYStatusChip(verbatim: chipText(checkin.chip), tone: checkin.ok ? .success : .neutral)
                }
            }
        }
    }

    private func chipText(_ chip: OfficialAttendancePlayerView.CheckinChip) -> String {
        switch chip {
        case .done: return PlayCloseCopy.text("已签到", "Checked in", locale)
        case .closed: return PlayCloseCopy.text("已截止", "Closed", locale)
        case .opensAt(let time): return PlayCloseCopy.text("\(time) 开放", "Opens \(time)", locale)
        case .open: return PlayCloseCopy.text("可签到", "Open", locale)
        }
    }

    private func showMyCode() {
        showingMyCode = true
        if snapshot?.credential.isEmpty != false, !busy { claimCode() }
    }

    /// MP `cy-sheet` 我的签到码: QR (or 正在加载… / 加载失败 · 轻点重试), 号码布, 更换签到码 before check-in.
    private var myCodeSheet: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.lg) {
                if let qr = snapshot?.qrImage, let url = URL(string: qr), qr.hasPrefix("https://") {
                    AsyncImage(url: url) { image in image.resizable().interpolation(.none).scaledToFit() } placeholder: { ProgressView() }
                        .frame(maxWidth: 240, maxHeight: 240)
                        .accessibilityLabel(Text(verbatim: PlayCloseCopy.text("我的签到码", "My check-in code", locale)))
                } else if busy || !loaded {
                    ProgressView { Text(verbatim: PlayCloseCopy.text("正在加载…", "Loading…", locale)) }
                } else {
                    Button { claimCode() } label: {
                        Text(verbatim: PlayCloseCopy.text("加载失败 · 轻点重试", "Didn't load · Tap to retry", locale))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("attendance.code.retry")
                }
                if let bib = snapshot?.bib, !bib.isEmpty {
                    Text(verbatim: PlayCloseCopy.text("号码布 \(bib)", "Bib \(bib)", locale))
                        .font(.title3.monospacedDigit())
                }
                if let snapshot, !snapshot.credential.isEmpty, snapshot.checkedAtText.isEmpty {
                    Button { showingMyCode = false; showingRotateConfirm = true } label: {
                        Text(verbatim: PlayCloseCopy.text("更换签到码", "Change check-in code", locale))
                    }
                    .buttonStyle(.borderless)
                    .disabled(busy)
                    .accessibilityIdentifier("attendance.rotate.trigger")
                }
            }
            .padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(Text(verbatim: PlayCloseCopy.text("我的签到码", "My check-in code", locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showingMyCode = false } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text(verbatim: PlayCloseCopy.close(locale)))
                        .accessibilityIdentifier("attendance.code.close")
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("attendance.code.sheet")
    }

    // MARK: Organizer (unchanged entry: code settings and verification)

    private var organizerSection: some View {
        Section {
            if let snapshot {
                if !snapshot.meetingName.isEmpty {
                    LabeledContent(PlayCloseCopy.text("集合点", "Meeting point", locale), value: snapshot.meetingName)
                }
            }
            Button {
                showingCodeSheet = true
            } label: {
                Text(verbatim: PlayCloseCopy.text("签到码设置与核验", "Check-in code & verification", locale))
            }
            .accessibilityIdentifier("attendance.organizer.open")
        } header: {
            Text(verbatim: PlayCloseCopy.text("赛事联络与到场签到", "Event contact & check-in", locale))
        }
    }

    private var organizerCodeSheet: some View {
        PlayCloseSheetHost(
            title: PlayCloseCopy.text("现场签到管理", "Attendance Management", locale),
            detents: [.half],
            onClose: { showingCodeSheet = false }
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Button {
                    showingCodeSheet = false
                    showingRotateConfirm = true
                } label: {
                    Text(verbatim: PlayCloseCopy.text("更换签到码", "Rotate check-in code", locale))
                }
                .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                CYField(
                    label: PlayCloseCopy.text("签到码", "Check-in code", locale),
                    placeholder: PlayCloseCopy.text("完整签到码（不是号码布）", "Full check-in code (not the bib)", locale),
                    text: $inputCredential
                )
                Button {
                    submitVerify()
                } label: {
                    Text(verbatim: PlayCloseCopy.text("核验到场签到", "Verify check-in", locale))
                }
                .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, isLoading: busy))
                .disabled(busy || inputCredential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.lg)
        }
    }

    // MARK: Reads and commands

    private func load() async {
        if let loadAttendance = popupCloseActions.loadAttendance {
            snapshot = await loadAttendance(eventID, organizer)
        }
        if !organizer, activityID > 0, let loadContact = popupCloseActions.loadOfficialContact {
            contact = await loadContact(activityID)
        }
        if snapshot != nil { claimUnknown = false }
        loaded = true
    }

    /// MP `attendance-claim` with no fields: the server issues this player's code.
    private func claimCode() {
        guard let sendCommand = popupCloseActions.sendAttendanceCommand else { return }
        busy = true
        Task {
            let receipt = await sendCommand(eventID, .attendanceClaim, [:])
            if receipt == nil { claimUnknown = true }
            await load()
            busy = false
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

    private func submitVerify() {
        let code = inputCredential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, let sendCommand = popupCloseActions.sendAttendanceCommand else { return }
        busy = true
        Task {
            defer { busy = false }
            let receipt = await sendCommand(eventID, .attendanceVerify, ["credential": code])
            if receipt?.state == .applied {
                showingCodeSheet = false
                inputCredential = ""
                toastMessage = PlayCloseCopy.text("核验成功", "Verified", locale)
                await load()
            } else {
                toastMessage = PlayCloseCopy.text(receipt?.message.isEmpty == false ? (receipt?.message ?? "") : "操作未成功",
                                                  "Action failed", locale)
            }
        }
    }
}
