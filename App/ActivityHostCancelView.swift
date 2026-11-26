import SwiftUI

/// Host cancel-and-refund panel and confirmation sheet for `pages/activity/detail`
/// (`subpackageMember/components/cy/scene-play-activity-detail` + `utils/danger-actions.js`).
@MainActor final class ActivityHostCancelModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case blocked(String?)
        case unknownCount
        case networkError
        case ready(paidPlayers: Int)
        case cancelled(String?)
    }

    let activityID: Int
    private let access: any ActivityHostCancelAccess
    @Published var phase: Phase = .loading
    @Published var reason: String = ""
    @Published var busy: Bool = false
    @Published var submitError: String? = nil

    init(activityID: Int, access: any ActivityHostCancelAccess) {
        self.activityID = activityID
        self.access = access
    }

    var paidPlayers: Int? {
        if case .ready(let count) = phase { return count }
        return nil
    }

    var canSubmit: Bool {
        !busy && ActivityHostCancelRules.canSubmit(reason: reason, paidPlayers: paidPlayers)
    }

    func loadPreview() async {
        guard !busy else { return }
        phase = .loading
        submitError = nil
        do {
            let preview = try await access.preview(activityID: activityID)
            switch preview {
            case .paidPlayers(let count):
                phase = .ready(paidPlayers: count)
            case .blocked(let msg):
                phase = .blocked(msg)
            case .unknownCount:
                phase = .unknownCount
            }
        } catch is CancellationError {
        } catch {
            phase = .networkError
        }
    }

    func submit() async -> Bool {
        guard canSubmit else { return false }
        busy = true
        submitError = nil
        defer { busy = false }
        do {
            let outcome = try await access.cancel(activityID: activityID, reason: reason)
            switch outcome {
            case .cancelled(let msg):
                phase = .cancelled(msg)
                return true
            case .rejected(let msg):
                submitError = msg?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? msg : "取消失败"
                return false
            }
        } catch is CancellationError {
            return false
        } catch {
            submitError = "取消失败"
            return false
        }
    }
}

@MainActor struct ActivityHostCancelSection: View {
    let detail: ActivityDetail
    let access: any ActivityHostCancelAccess
    var onCancelled: () async -> Void
    @Environment(\.locale) private var locale
    @State private var showingSheet = false
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        if !detail.isCancelled,
           ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: access.accountID) {
            Section {
                Button(role: .destructive) {
                    showingSheet = true
                } label: {
                    Label { Text(verbatim: c.t("取消活动并退款", "Cancel event & refund")) } icon: { Image(systemName: "xmark.octagon") }
                }
                .disabled(!access.enabled)
                .accessibilityIdentifier("activity.hostCancel.open")
                .accessibilityLabel(Text(verbatim: c.t("取消活动并退款", "Cancel event & refund")))
            } header: {
                Text(c.t("主办管理", "Host management"))
            } footer: {
                if PlayAreaPopupCopy.paymentsOpen {
                    Text(c.t("取消后将给所有未核销的已付款玩家原路全额退款，活动同时下架。",
                             "Cancelling issues a full refund to all unredeemed paid attendees and unlists the event."))
                } else {
                    Text(verbatim: "—")
                }
            }
            .cySheet(isPresented: $showingSheet) {
                ActivityHostCancelSheet(detail: detail, access: access) {
                    showingSheet = false
                    await onCancelled()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

@MainActor struct ActivityHostCancelSheet: View {
    let detail: ActivityDetail
    @StateObject private var model: ActivityHostCancelModel
    var onCompleted: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var confirming = false
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    init(detail: ActivityDetail, access: any ActivityHostCancelAccess, onCompleted: @escaping () async -> Void) {
        self.detail = detail
        self.onCompleted = onCompleted
        _model = StateObject(wrappedValue: ActivityHostCancelModel(activityID: detail.summary.id, access: access))
    }

    var body: some View {
        NavigationStack {
            List {
                switch model.phase {
                case .loading:
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(verbatim: c.t("正在核对已付款人数…", "Checking paid attendee count…"))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("activity.hostCancel.loading")
                    }
                case .blocked(let msg):
                    Section {
                        let shown = msg?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? c.tr(msg!)
                            : c.t("当前无法取消", "Cannot cancel right now")
                        Label {
                            Text(verbatim: shown)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        .accessibilityIdentifier("activity.hostCancel.blocked")

                        Button {
                            Task { await model.loadPreview() }
                        } label: { Text(verbatim: c.t("重新检查", "Check again")) }
                        .accessibilityIdentifier("activity.hostCancel.recheck")
                        .accessibilityLabel(Text(verbatim: c.t("重新检查", "Check again")))
                    }
                case .unknownCount, .networkError:
                    Section {
                        ContentUnavailableView {
                            Label {
                                Text(verbatim: c.t("无法确认已付款人数，请稍后再试",
                                                   "Could not verify paid attendee count. Please try again later."))
                            } icon: { Image(systemName: "exclamationmark.triangle") }
                        } description: {
                            Text(verbatim: c.t("请检查网络后重新检查", "Check your connection and try again."))
                        } actions: {
                            Button {
                                Task { await model.loadPreview() }
                            } label: { Text(verbatim: c.t("重新检查", "Check again")) }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(Text(verbatim: c.t("重新检查", "Check again")))
                        }
                        .accessibilityIdentifier("activity.hostCancel.error")
                    }
                case .ready(let paidCount):
                    readyContent(paidCount: paidCount)
                case .cancelled(let serverMsg):
                    Section {
                        Label { Text(verbatim: c.t("活动已取消", "Event cancelled")) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            .font(.headline)
                        Text(verbatim: ActivityHostCancelRules.completionNotice(serverMessage: serverMsg).map { c.tr($0) }
                                ?? c.t("已提交全额退款，到账时间以微信通知为准",
                                       "Full refund submitted; arrival depends on payment provider notification"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("activity.hostCancel.notice")

                        Button {
                            Task { await onCompleted() }
                        } label: { Text(verbatim: c.t("完成", "Done")) }
                        .accessibilityIdentifier("activity.hostCancel.done")
                        .accessibilityLabel(Text(verbatim: c.t("完成", "Done")))
                    }
                    .accessibilityIdentifier("activity.hostCancel.cancelled")
                }
            }
            .listStyle(.insetGrouped)
            .cyPageTitle(verbatim: c.t("取消活动并退款", "Cancel event & refund"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(c.t("关闭", "Close")) {
                        // After a successful cancel, closing is the acknowledgement: refresh the parent as "Done" does.
                        if case .cancelled = model.phase { Task { await onCompleted() } } else { dismiss() }
                    }
                        .disabled(model.busy)
                        .accessibilityIdentifier("activity.hostCancel.close")
                        .accessibilityLabel(Text(verbatim: c.t("关闭", "Close")))
                }
            }
            .task { await model.loadPreview() }
            .alert(Text(verbatim: PlayAreaPopupCopy.text("取消这场活动并退款?", "Cancel this event and refund?", locale: locale)),
                   isPresented: Binding(get: { confirming && PlayAreaPopupCopy.paymentsOpen }, set: { if !$0 { confirming = false } })) {
                Button(role: .cancel) { confirming = false } label: {
                    Text(verbatim: PlayAreaPopupCopy.text("再想想", "Not now", locale: locale))
                }
                Button(role: .destructive) {
                    confirming = false
                    Task { _ = await model.submit() }
                } label: {
                    Text(verbatim: PlayAreaPopupCopy.text("取消并退款", "Cancel and refund", locale: locale))
                }
                .accessibilityIdentifier("activity.hostCancel.confirmDialog")
            } message: {
                Text(verbatim: confirmMessage)
            }
        }
        .accessibilityIdentifier("activity.hostCancel.sheet")
    }

    /// Same copy as the MP danger-action dialog (`PlayAreaHostCancelModal`).
    private var confirmMessage: String {
        let count = model.paidPlayers.map(String.init) ?? "—"
        return PlayAreaPopupCopy.text(
            "将给 \(count) 位已付款玩家全额退款,不可撤销。活动同时下架。",
            count == "—"
                ? "The paid attendee count is unknown. A refund is not confirmed."
                : "\(count) paid players get a full refund. This can't be undone, and the event is unlisted.",
            locale: locale)
    }

    @ViewBuilder
    private func readyContent(paidCount: Int) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: detail.summary.name.isEmpty ? c.t("未命名活动", "Untitled event") : detail.summary.name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: PlayAreaPopupCopy.paymentsOpen
                    ? c.tr("将给 \(paidCount) 位已付款玩家全额退款,不可撤销。活动同时下架。")
                    : "—")
                    .foregroundStyle(PlayAreaPopupCopy.paymentsOpen ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("activity.hostCancel.summary")

            if PlayAreaPopupCopy.paymentsOpen {
                Label { Text(verbatim: c.t("已报名玩家将收到取消通知", "Registered attendees will be notified of the cancellation")) } icon: { Image(systemName: "bell.badge") }
                Label { Text(verbatim: c.t("已支付订单将原路全额退回", "Paid orders will be refunded in full to the original payment method")) } icon: { Image(systemName: "arrow.uturn.backward.circle") }
                Label { Text(verbatim: c.t("活动下架后不可恢复", "The event will be unlisted and cannot be restored")) } icon: { Image(systemName: "xmark.bin") }
            } else {
                Label { Text(verbatim: "—") } icon: { Image(systemName: "minus") }
                    .accessibilityIdentifier("activity.hostCancel.moneyClosed")
            }
        } header: {
            Text(verbatim: c.t("操作影响", "Consequences"))
        }

        Section {
            TextField(
                c.t("填写取消原因（会展示给已报名用户）", "Enter cancellation reason (shown to registered attendees)"),
                text: $model.reason,
                axis: .vertical
            )
            .lineLimit(2...5)
            .disabled(model.busy)
            .accessibilityLabel(Text(verbatim: c.t("取消原因", "Cancellation reason")))
            .accessibilityIdentifier("activity.hostCancel.reason")

            if let err = model.submitError {
                Label {
                    Text(verbatim: c.tr(err)).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .foregroundStyle(.red)
                .accessibilityIdentifier("activity.hostCancel.submitError")
            }
        } header: {
            Text(verbatim: c.t("取消原因", "Cancellation reason"))
        } footer: {
            // Validation sits in the section footer, as the system draws it.
            let trimmed = ActivityHostCancelRules.trimmedReason(model.reason)
            HStack(alignment: .firstTextBaseline) {
                if trimmed.count > ActivityHostCancelRules.reasonLimit {
                    Text(verbatim: c.t("取消原因不超过 100 字", "Cancellation reason cannot exceed 100 characters"))
                        .foregroundStyle(.red)
                } else if trimmed.isEmpty {
                    Text(verbatim: c.t("请填写取消原因", "Please enter a cancellation reason"))
                }
                Spacer(minLength: 8)
                Text(verbatim: "\(trimmed.count)/\(ActivityHostCancelRules.reasonLimit)")
                    .monospacedDigit()
                    .foregroundStyle(trimmed.count > ActivityHostCancelRules.reasonLimit ? Color.red : Color.secondary)
            }
        }

        Section {
            Button(role: .destructive) {
                guard PlayAreaPopupCopy.paymentsOpen else { return }
                confirming = true
            } label: {
                Text(verbatim: c.t("确认取消并退款", "Confirm cancel & refund"))
                    .frame(maxWidth: .infinity)
            }
            .disabled(!model.canSubmit || !PlayAreaPopupCopy.paymentsOpen)
            .accessibilityIdentifier("activity.hostCancel.confirm")
            .accessibilityLabel(Text(verbatim: c.t("确认取消并退款", "Confirm cancel & refund")))
        }
    }
}
