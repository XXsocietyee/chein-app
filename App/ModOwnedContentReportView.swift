import SwiftUI

/// Normal owned-license entry. The identity comes from the freshly decoded original license snapshot,
/// not a catalog item or a numeric template ID. The server verifies it again before any report write.
@MainActor struct ModOwnedContentReportLink: View {
    let reference: ModInstallationIdentity
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationLink { ModOwnedContentReportView(reference: reference) } label: {
            Text(locale.language.languageCode?.identifier == "zh" ? "举报原已购版本 / 恢复回执" : "Report purchased version / recover receipt")
        }.accessibilityIdentifier("workshopCommerce.originalReleaseReport")
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
    var body: some View {
        Form {
            CYHeroHeader(verbatim: text("原版本举报", "Original-version report"))
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                Text(verbatim: reference.moduleId).font(Theme.Font.cardTitle).fixedSize(horizontal: false, vertical: true); Text(verbatim: reference.releaseId).font(Theme.Font.label.monospaced()).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: reference.contentHash).font(Theme.Font.label.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text(text("仅举报这个原已购不可变版本。受理回执和审核状态不代表侵权判定、下架、退款或运行许可。",
                          "Reports only this original immutable purchased version. Receipt and review status do not establish infringement, withdrawal, refund or runtime permission.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
            }
            if let controller, controller.isCurrent {
                if let target = controller.target {
                    Section {
                        Text(verbatim: target.title).font(Theme.Font.sheetTitle).fixedSize(horizontal: false, vertical: true)
                        Picker(text("原举报原因", "Original report reason"), selection: $reason) {
                            Text(text("请选择", "Choose a reason")).tag("")
                            ForEach(target.reasons) { item in Text(verbatim: item.label).tag(item.code) }
                        }
                        if controller.pending?.receipt == nil || controller.pending?.receipt?.state == "UNKNOWN" {
                            Button(text(controller.pending == nil ? "确认举报" : "使用原请求重试",
                                        controller.pending == nil ? "Confirm report" : "Retry original request")) { confirming = true }
                                .disabled(!controller.canWrite || reason.isEmpty || (controller.pending.map { $0.reasonSHA256 != ModOwnedReportPending.digest(reason) } ?? false))
                        }
                        Text(text("未配置写入批准时只能读取。未知结果必须保留同一请求；重试须重新选择原原因，不会自动发起举报。",
                                  "Without write approval this is read-only. Unknown outcomes retain the same request; retry requires selecting the original reason. Reports are never submitted automatically.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let pending = controller.pending {
                    Section(text("原请求回执", "Original request receipt")) {
                        Text(verbatim: pending.requestId).font(Theme.Font.label.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: pending.receipt?.state ?? "UNKNOWN").font(Theme.Font.cardTitle).fixedSize(horizontal: false, vertical: true)
                        if let receipt = pending.receipt, receipt.state != "UNKNOWN" {
                            Text(text("原审核举报已留痕；这不是处置结果。", "The original audit report was recorded; this is not a disposition.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
                            if receipt.state == "ALREADY_REPORTED" {
                                Text(text("本人在同一原审核轮次已有举报；本次没有重复追加原因。", "You already reported in this original review round; this request did not append another reason.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
                            }
                            if let task = receipt.auditTaskId { Text(verbatim: "AuditTask: \(task)").font(Theme.Font.label.monospaced()).fixedSize(horizontal: false, vertical: true) }
                            if let record = receipt.auditRecordId { Text(verbatim: "AuditRecord: \(record)").font(Theme.Font.label.monospaced()).fixedSize(horizontal: false, vertical: true) }
                            if let status = receipt.auditStatus { Text(verbatim: "auditStatus: \(status)").font(Theme.Font.label).fixedSize(horizontal: false, vertical: true) }
                            else { Text(text("当前审核状态未知。", "Current review status is unknown.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true) }
                        } else { Text(text("未读到原受理结果；不能当成失败或重新生成请求。", "The original outcome has not been read. This is not a rejection and does not permit a new request.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true) }
                    }
                }
                if !controller.message.isEmpty {
                    Text(text("本次读取或提交未确认。保留原请求和已读回执；先重读原结果。身份或批准失效时会清除本页展示。",
                              "This read or submission is unconfirmed. The original request and prior receipt are retained; reread the original result. Identity or approval loss clears this page.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
                }
                CYPillButton(verbatim: text("重读目标与原回执", "Reread target and original receipt"), style: .secondary) { Task { await controller.refresh() } }
                    .disabled(controller.busy)
            } else {
                Text(text("原版本举报读取未配置或当前身份 / 批准已失效。没有发送举报；原请求只在同账号同域恢复。",
                          "Original-version report reading is unconfigured or identity/approval expired. No report is sent; the original request is recoverable only in the same account and realm.")).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .cyHeroScreen()
        .confirmationDialog(text("向原审核提交该版本举报？", "Submit this version report to the original audit service?"), isPresented: $confirming) {
            Button(text("确认提交原请求", "Confirm original request")) { if let controller { Task { await controller.submit(reason: reason) } } }
            Button(text("取消", "Cancel"), role: .cancel) { }
        } message: {
            Text(text("不发起下架、退款或资金动作。结果不明时只恢复同一 UUID。", "No withdrawal, refund or funds action. An uncertain outcome recovers only the same UUID."))
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
}
