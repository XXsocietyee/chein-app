import SwiftUI

/// Renders `FreeExploreCancelModel` (IWP-1). Unmounted: no route, entry or composition uses it yet.
/// Strings use `W8Text` (inline zh/en); they are listed in docs/owner-plan/iwp-1-new-strings.md.
@MainActor struct BundleCancelView: View {
    @ObservedObject var model: FreeExploreCancelModel
    let canceler: BundleCancelCanceler
    let service: any FreeExploreLaunchServing
    let registrationID: FreeExploreLaunchID
    let reservationID: String
    /// Manual toggle only (no suggestion until the backend exposes a waiver-status read).
    @State private var useWaiver = false

    var body: some View {
        Form {
            Section { CYHeroHeader(verbatim: W8Text.t("取消预约", "Cancel reservation")) }.e1HeroRow()
            switch model.state {
            case .idle:
                Section {
                    Toggle(isOn: $useWaiver) { Text(verbatim: W8Text.t("使用本月豁免次数", "Use this month's waiver")) }
                    CYPillButton(verbatim: W8Text.t("查看取消结果", "Check cancellation")) { Task { await model.requestQuote(reservationID: reservationID, useWaiver: useWaiver) } }
                        .e1ActionRow()
                }
            case .quoting, .cancelling:
                CYLoadingStateView(rows: 1)
            case .awaitingConfirmation(_, _, let quote):
                Section {
                    Text(verbatim: quote.message)
                    CYPillButton(verbatim: W8Text.t("确认取消", "Confirm cancellation"), systemImage: "xmark.circle") { Task { await canceler.confirm(on: model) } }
                        .e1ActionRow()
                    CYPillButton(verbatim: W8Text.t("返回", "Back"), style: .tertiary) { model.dismiss() }.e1ActionRow()
                }
            case .cancelled(let status):
                Section { CYStatusChip(verbatim: W8Text.t("预约已取消（\(status)）", "Reservation cancelled (\(status))."), tone: .success, systemImage: "checkmark.circle.fill") }
            case .failed(let message):
                Section {
                    Text(verbatim: message)
                    CYPillButton(verbatim: W8Text.t("返回", "Back"), style: .secondary) { model.dismiss() }.e1ActionRow()
                }
            case .awaitingServerConfirmation:
                Section {
                    Text(verbatim: W8Text.t("正在等待服务器确认，请勿重复提交", "Waiting for the server to confirm. Please don't submit again."))
                    CYPillButton(verbatim: W8Text.t("刷新状态", "Refresh status"), style: .secondary, systemImage: "arrow.clockwise") {
                        Task {
                            await canceler.readBack(model: model, service: service,
                                                    registrationID: registrationID, reservationID: reservationID)
                        }
                    }
                    .e1ActionRow()
                }
            case .unavailable:
                Section { Text(verbatim: W8Text.t("暂未开放", "Not available yet")) }
            }
        }
        .formStyle(.grouped)
        .cyGroupedSurface()
        .cyHeroScreen()
    }
}
