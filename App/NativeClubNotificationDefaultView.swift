import SwiftUI

/// N01 shared policy author. Personal notification preferences remain on their existing screen.
/// Reopening / foreground reads current authority and the original receipt, never auto-submits.
@MainActor struct NativeClubNotificationDefaultView: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    let makeFlow: () -> NativeChannelNotificationCoordinator?
    let sourceCurrent: () -> Bool
    @State private var model: NativeChannelNotificationCoordinator?
    @State private var selection = NativeChannelNotificationLevel.mentions
    @State private var review: Review?
    @State private var attempted = false
    private struct Review: Identifiable {
        let id = UUID()
        let club: String
        let version: Int64
        let level: NativeChannelNotificationLevel
    }
    private func copy(_ zh: String, _ en: String) -> String { locale.pick(zh, en) }
    var body: some View {
        Form {
            if sourceCurrent(), let model, model.isCurrent {
                if let row = model.clubDefault {
                    Section {
                        Label(
                            row.level == .all ? copy("当前：所有消息", "Current: All messages") : copy("当前：仅提及我", "Current: Only @mentions"),
                            systemImage: row.level == .all ? "bell" : "at"
                        )
                        .foregroundStyle(.tint)
                        LabeledContent {
                            Text(verbatim: String(row.version))
                        } label: {
                            Text(verbatim: copy("政策版本", "Policy version"))
                            Text(verbatim: row.configured ? copy("原政策版本 \(row.version)", "Policy version \(row.version)") : copy("尚未设置，使用正式默认：仅提及我", "Not configured; using default: Only @mentions"))
                        }
                        Picker(copy("共同默认", "Shared default"), selection: $selection) {
                            Text(copy("所有消息", "All messages")).tag(NativeChannelNotificationLevel.all)
                            Text(copy("仅提及我", "Only @mentions")).tag(NativeChannelNotificationLevel.mentions)
                        }
                        .disabled(!model.canSaveClubDefault)
                        .accessibilityLabel(Text(verbatim: copy("共同默认", "Shared default")))
                        Button {
                            review = Review(club: row.clubID, version: row.version, level: selection)
                        } label: {
                            Label(copy("核对并保存", "Review and save"), systemImage: "checkmark.circle")
                        }
                        .disabled(!model.canSaveClubDefault)
                    } header: {
                        Text(verbatim: copy("俱乐部共同默认，不是我的个人设置", "Club shared default, not your personal setting"))
                    } footer: {
                        Text(verbatim: copy("只在成员自己的频道、分类和俱乐部偏好继承时使用；不会取消任何人的静音、免打扰或系统权限。", "Used only when a member inherits channel, category, and club preferences; never overrides personal mutes, DND, or system permissions."))
                    }
                }
                Section {
                    if model.isBusy {
                        Label {
                            Text(verbatim: copy("正在读取原服务", "Reading service state"))
                                .foregroundStyle(.secondary)
                        } icon: {
                            ProgressView()
                        }
                    }
                    if let request = model.pendingRequestID {
                        LabeledContent {
                            Text(verbatim: request)
                                .textSelection(.enabled)
                        } label: {
                            Text(verbatim: copy("原请求", "Original request"))
                            Text(verbatim: copy("结果未确定时只回读原请求，不重发，也不会另建请求覆盖它。", "While the outcome is pending, only the original request is read back; it is not resent or overwritten."))
                        }
                    }
                    if let rejected = model.sharedDefaultRejection {
                        Label(
                            rejected == "CLUB_DEFAULT_VERSION_EXHAUSTED"
                                ? copy("原请求未写入：政策版本已不可递增。", "Original request not applied: policy version cannot be incremented.")
                                : copy("原请求已明确拒绝；不会自动重试。请核对最新政策后重新确认。", "Original request was rejected and will not auto-retry. Please review the latest policy and confirm again."),
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(CYColor.dangerText)
                    }
                    if isReadFailure(model.state) {
                        ContentUnavailableView {
                            Label(status(model.state), systemImage: "exclamationmark.triangle")
                        } actions: {
                            Button(reloadTitle(model)) { reload(model) }
                                .buttonStyle(.bordered)
                                .disabled(reloadDisabled(model))
                        }
                    } else {
                        Text(verbatim: status(model.state))
                        Button {
                            reload(model)
                        } label: {
                            Label(reloadTitle(model), systemImage: "arrow.clockwise")
                        }
                        .disabled(reloadDisabled(model))
                    }
                } header: {
                    Text(verbatim: copy("原请求与当前状态", "Original request & current status"))
                }
            } else if attempted {
                ContentUnavailableView {
                    Label(copy("共同默认当前不可用", "Shared default unavailable"), systemImage: "bell.slash")
                } description: {
                    Text(verbatim: copy("需要原俱乐部管理权限及独立通知操作授权；本页不会授予权限。", "Requires club management permission and notification operation grant; this page does not grant permissions."))
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView(copy("正在读取原权限", "Reading permissions"))
                    Spacer()
                }
            }
        }
        .navigationTitle(Text(verbatim: copy("俱乐部共同通知默认", "Club Shared Notification Default")))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task { await reopen() }
        .onChange(of: phase) { _, value in
            if value == .active { Task { await reopen() } } else { clear() }
        }
        .onChange(of: sourceCurrent()) { _, current in if !current { clear() } }
        .onChange(of: model?.clubDefault?.version) { _, _ in
            review = nil; selection = model?.clubDefault?.level ?? .mentions
        }
        .onDisappear { clear() }
        .cySheet(item: $review) { item in
            NavigationStack {
                Form {
                    Section {
                        Label(
                            item.level == .all ? copy("所有消息", "All messages") : copy("仅提及我", "Only @mentions"),
                            systemImage: item.level == .all ? "bell" : "at"
                        )
                        .foregroundStyle(.tint)
                    } footer: {
                        Text(verbatim: copy("基于原版本 \(item.version)，不修改成员自己的偏好。", "Based on version \(item.version); does not modify members' personal preferences."))
                    }
                }
                .navigationTitle(Text(verbatim: copy("修改所有继承此政策的俱乐部频道默认通知", "Update default notifications for all club channels inheriting this policy")))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy("取消", "Cancel"), role: .cancel) { review = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copy("确认保存共同默认", "Confirm saving shared default")) {
                            guard sourceCurrent(), let model, model.canSaveClubDefault,
                                  model.clubDefault?.clubID == item.club, model.clubDefault?.version == item.version else { review = nil; return }
                            review = nil
                            Task { await model.saveClubDefault(level: item.level, expectedVersion: item.version) }
                        }
                    }
                }
                .privacySensitive()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    private func clear() { review = nil; selection = .mentions; model?.deactivate(); model = nil }
    private func reopen() async {
        clear(); attempted = true
        guard sourceCurrent(), let candidate = makeFlow(), candidate.sharedClubDefaultMode else { return }
        model = candidate
        await candidate.activate()
        guard sourceCurrent(), model === candidate else { candidate.deactivate(); return }
        selection = candidate.clubDefault?.level ?? .mentions
    }
    private func reload(_ model: NativeChannelNotificationCoordinator) {
        review = nil
        Task { await model.refresh() }
    }
    private func reloadTitle(_ model: NativeChannelNotificationCoordinator) -> String {
        model.pendingRequestID == nil ? copy("重新读取当前政策", "Reload current policy") : copy("回读原请求", "Read back original request")
    }
    private func reloadDisabled(_ model: NativeChannelNotificationCoordinator) -> Bool {
        model.isBusy || (model.pendingRequestID != nil && !model.canCheckReceipt)
    }
    private func isReadFailure(_ state: NativeChannelNotificationState) -> Bool {
        switch state {
        case .refreshFailed, .failed: return true
        default: return false
        }
    }
    private func status(_ state: NativeChannelNotificationState) -> String {
        switch state {
        case .applied: return copy("原请求已写入；展示来自重新读取的当前政策。", "Original request applied; displaying the freshly reloaded policy.")
        case .appliedRedacted: return copy("原请求已完成，当前已无权读取结果内容。", "Original request completed; you no longer have permission to read the result.")
        case .pending, .outcomeUnknown: return copy("原请求结果待核对，未认定成功或失败。", "Original request outcome pending verification; neither confirmed nor failed.")
        case .persistenceFailed: return copy("原请求存储不可确认；已停止提交。", "Original request persistence could not be verified; submission stopped.")
        case .accessClosed: return copy("原权限已关闭，当前政策已清除。", "Permission closed; current policy cleared.")
        case .refreshFailed, .failed: return copy("当前状态读取未完成，不使用旧政策代替。", "Current status read incomplete; stale policy is not shown.")
        default: return copy("仅使用当前原服务及原请求回执。", "Uses only the live service and original request receipt.")
        }
    }
}
