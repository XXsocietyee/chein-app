import SwiftUI

/// Appeal form for a voucher the merchant forgot to scan. Unmounted; no route, no composition wiring.
/// All copy says "submitted for review"; nothing here says refunded or consumed. Evidence references come
/// from the existing own-media upload path via `evidenceRefs` (no uploader is added here).
@MainActor struct BundleAppealView: View {
    @ObservedObject var model: BundleAppealModel
    let registrationID: FreeExploreLaunchID
    let unitID: FreeExploreLaunchID
    @Binding var evidenceRefs: [String]
    @State private var reason: BundleAppealReason = .merchantForgotScan
    @State private var note = ""

    private func text(_ zh: String, _ en: String) -> Text { Text(W8Text.t(zh, en)) }

    private var busy: Bool { model.state == .submitting }
    private var locked: Bool {
        switch model.state {
        case .submitting, .awaitingReadback, .readbackNotFound, .submitted: return true
        default: return false
        }
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $reason) {
                    text("商家忘记核销", "Merchant forgot to scan").tag(BundleAppealReason.merchantForgotScan)
                    text("其他", "Other").tag(BundleAppealReason.other)
                } label: { text("申诉原因", "Reason") }
                TextField(W8Text.t("补充说明（最多500字）", "Note (up to 500 characters)"), text: $note, axis: .vertical)
                    .onChange(of: note) { _, value in
                        if value.count > BundleAppealLimits.maxNoteCharacters { note = String(value.prefix(BundleAppealLimits.maxNoteCharacters)) }
                    }
                text("已附证据 \(evidenceRefs.count)/\(BundleAppealLimits.maxEvidenceRefs)",
                     "Evidence attached \(evidenceRefs.count)/\(BundleAppealLimits.maxEvidenceRefs)")
            }
            .disabled(locked)
            Section {
                text("提交后将进入审核，审核结果以服务器为准；提交不代表已退款或已核销。",
                     "Your appeal will be submitted for review. The outcome is decided by the server; submitting does not refund or redeem anything.")
                    .font(.footnote)
            }
            statusSection
            Section {
                CYPillButton(verbatim: W8Text.t("提交申诉", "Submit appeal"), style: .primary) {
                    Task { await model.submit(registrationID: registrationID, unitID: unitID, reason: reason,
                                              note: note, evidenceRefs: evidenceRefs) }
                }
                .disabled(locked)
            }
        }
        .task { model.restore() }
    }

    @ViewBuilder private var statusSection: some View {
        switch model.state {
        case .idle: EmptyView()
        case .submitting: Section { CYLoadingStateView(rows: 1) }
        case .submitted(let appeal):
            let shown = model.presentation(for: appeal)
            Section {
                Text(shown.title)
                if let detail = shown.detail { Text(detail).font(.footnote) }
            }
        case .awaitingReadback:
            Section {
                text("未能确认是否已提交，请先查询结果。", "We couldn't confirm whether it was submitted. Check the result first.")
                CYPillButton(verbatim: W8Text.t("查询提交结果", "Check result"), style: .secondary) { Task { await model.recover() } }.disabled(busy)
            }
        case .readbackNotFound:
            Section {
                text("暂未查到该申诉。可以再次查询，或使用同一申请重新提交。", "No record yet. Check again, or send the same appeal again.")
                CYPillButton(verbatim: W8Text.t("再次查询", "Check again"), style: .secondary) { Task { await model.recover() } }
                CYPillButton(verbatim: W8Text.t("重新提交同一申诉", "Send the same appeal again"), style: .tertiary) { Task { await model.retryOriginal() } }
            }
        case .blocked(let code):
            Section {
                text("服务器未接受这次申诉。", "The server did not accept this appeal.")
                if let code { Text(code).font(.footnote.monospaced()) }
            }
        case .loginRequired: Section { text("请先登录后再试，已保存的申诉不会丢失。", "Sign in and try again. Your saved appeal is kept.") }
        case .storageFailed: Section { text("无法在本机保存申诉，未发送。", "Couldn't save the appeal on this device. Nothing was sent.") }
        case .unavailable: Section { text("申诉功能暂不可用。", "Appeals aren't available yet.") }
        case .failed: Section { text("内容不符合要求，请检查后重试。", "Please check the details and try again.") }
        }
    }
}
