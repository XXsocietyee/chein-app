import SwiftUI

/// Normal owned-license entry. The identity comes from the freshly decoded original license snapshot,
/// not a catalog item or a numeric template ID. The server verifies it again before any report write.
@MainActor struct ModOwnedContentReportLink: View {
    let reference: ModInstallationIdentity
    @Environment(\.locale) private var locale
    private var title: String { locale.language.languageCode?.identifier == "zh" ? "举报原已购版本 / 恢复回执" : "Report purchased version / recover receipt" }
    var body: some View {
        NavigationLink { ModOwnedContentReportView(reference: reference) } label: {
            CYListRow(verbatim: title, trailing: .none) { CYRowIcon(systemImage: "flag") }
        }
        .accessibilityIdentifier("workshopCommerce.originalReleaseReport")
        .accessibilityLabel(Text(verbatim: title))
    }
}

@MainActor private struct ModOwnedContentReportView: View {
    let reference: ModInstallationIdentity
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: ModOwnedReportController?
    @State private var reason = ""
    @State private var confirming = false
    private func text(_ zh: String, _ en: String) -> String { locale.language.languageCode?.identifier == "zh" ? zh : en }
    private var reportShown: Bool {
        guard let controller, controller.isCurrent, controller.target != nil else { return false }
        return controller.pending?.receipt == nil || controller.pending?.receipt?.state == "UNKNOWN"
    }
    var body: some View {
        Cloud25Screen(title: text("原版本举报", "Original-version report"), seed: reference.moduleId, symbol: "flag") {
            CYImageCard(
                verbatim: Cloud25Copy.value(controller?.target?.title ?? reference.moduleId),
                fallback: LocalizedStringKey(stringLiteral: "—"),
                meta: Cloud25Copy.value(reference.releaseId)
            )
            CYInfoCard {
                CYListRow(verbatim: Cloud25Copy.value(reference.moduleId), meta: Cloud25Copy.value(reference.releaseId), trailing: .none) {
                    CYRowIcon(systemImage: "shippingbox")
                }
                Text(verbatim: Cloud25Copy.value(reference.contentHash)).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: text("仅举报这个原已购不可变版本。受理回执和审核状态不代表侵权判定、下架、退款或运行许可。",
                                    "Reports only this original immutable purchased version. Receipt and review status do not establish infringement, withdrawal, refund or runtime permission."))
                    .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if let controller, controller.isCurrent {
                if controller.busy { CYSkeleton().accessibilityLabel(Text("cy.state.loading")) }
                if let target = controller.target { targetCard(controller, target) }
                if let pending = controller.pending { receiptCard(pending) }
                if !controller.message.isEmpty {
                    CYNoteBanner(text: Text(verbatim: text("本次读取或提交未确认。保留原请求和已读回执；先重读原结果。身份或批准失效时会清除本页展示。",
                                                          "This read or submission is unconfirmed. The original request and prior receipt are retained; reread the original result. Identity or approval loss clears this page.")),
                                 symbol: "questionmark.circle", tone: .warning)
                }
                Cloud25Pill(title: text("重读目标与原回执", "Reread target and original receipt"), primary: !reportShown, enabled: !controller.busy) {
                    Task { await controller.refresh() }
                }
            } else {
                CYEmptyState(systemImage: "flag.slash", LocalizedStringKey(stringLiteral: text(
                    "原版本举报读取未配置或当前身份 / 批准已失效。没有发送举报；原请求只在同账号同域恢复。",
                    "Original-version report reading is unconfigured or identity/approval expired. No report is sent; the original request is recoverable only in the same account and realm.")))
            }
        }
        .confirmationDialog(text("向原审核提交该版本举报？", "Submit this version report to the original audit service?"), isPresented: $confirming) {
            Button(text("确认提交原请求", "Confirm original request")) { if let controller { Task { await controller.submit(reason: reason) } } }
            Button(text("取消", "Cancel"), role: .cancel) { }
        } message: {
            Text(verbatim: text("不发起下架、退款或资金动作。结果不明时只恢复同一 UUID。", "No withdrawal, refund or funds action. An uncertain outcome recovers only the same UUID."))
        }
        .task(id: session.modOwnedReportRevision) {
            controller?.invalidate(); reason = ""; confirming = false
            let opened = session.makeModOwnedReportController(reference: reference); controller = opened
            await opened?.refresh()
            if let opened {
                let delay = max(0, opened.expiresAt.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(delay)); guard !Task.isCancelled else { return }; opened.invalidate() }
                catch { } // Navigation/account change already invalidates the captured service.
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, let controller { Task { await controller.refresh() } }
        }
        .onDisappear { confirming = false; controller?.invalidate(); controller = nil; reason = "" }
    }

    private func targetCard(_ controller: ModOwnedReportController, _ target: ModOwnedReportTarget) -> some View {
        let confirmTitle = text(controller.pending == nil ? "确认举报" : "使用原请求重试",
                                controller.pending == nil ? "Confirm report" : "Retry original request")
        let canSubmit = controller.canWrite && !reason.isEmpty && (controller.pending.map { $0.reasonSHA256 == ModOwnedReportPending.digest(reason) } ?? true)
        return CYInfoCard {
            Text(verbatim: target.title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            Picker(text("原举报原因", "Original report reason"), selection: $reason) {
                Text(verbatim: text("请选择", "Choose a reason")).tag("")
                ForEach(target.reasons) { item in Text(verbatim: item.label).tag(item.code) }
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            if reportShown {
                Cloud25Pill(title: confirmTitle, primary: true, enabled: canSubmit) { confirming = true }
            }
            Text(verbatim: text("未配置写入批准时只能读取。未知结果必须保留同一请求；重试须重新选择原原因，不会自动发起举报。",
                                "Without write approval this is read-only. Unknown outcomes retain the same request; retry requires selecting the original reason. Reports are never submitted automatically."))
                .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func receiptCard(_ pending: ModOwnedReportPending) -> some View {
        CYInfoCard {
            Cloud25Header(title: text("原请求回执", "Original request receipt"))
            Text(verbatim: pending.requestId).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            CYStatusChip(verbatim: Cloud25Copy.value(pending.receipt?.state ?? ""), tone: tone(pending.receipt?.state), systemImage: "flag")
                .accessibilityLabel(Text(verbatim: Cloud25Copy.value(pending.receipt?.state ?? "")))
            if let receipt = pending.receipt, receipt.state != "UNKNOWN" {
                Text(verbatim: text("原审核举报已留痕；这不是处置结果。", "The original audit report was recorded; this is not a disposition."))
                    .cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                if receipt.state == "ALREADY_REPORTED" {
                    Text(verbatim: text("本人在同一原审核轮次已有举报；本次没有重复追加原因。", "You already reported in this original review round; this request did not append another reason."))
                        .cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
                if let task = receipt.auditTaskId {
                    CYFactRow(label: Text(verbatim: "AuditTask"), value: String(task))
                }
                if let record = receipt.auditRecordId {
                    CYFactRow(label: Text(verbatim: "AuditRecord"), value: String(record))
                }
                if let status = receipt.auditStatus {
                    CYFactRow(label: Text(verbatim: "auditStatus"), value: String(status))
                } else {
                    Text(verbatim: text("当前审核状态未知。", "Current review status is unknown."))
                        .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(verbatim: text("未读到原受理结果；不能当成失败或重新生成请求。", "The original outcome has not been read. This is not a rejection and does not permit a new request."))
                    .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tone(_ state: String?) -> CYStatusTone {
        switch state {
        case "SUBMITTED": return .success
        case "ALREADY_REPORTED": return .info
        case "UNKNOWN", nil, "": return .warning
        default: return .neutral
        }
    }
}
