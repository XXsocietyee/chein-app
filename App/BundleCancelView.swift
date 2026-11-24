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
    @QuestifyReduceMotion private var reduceMotion

    private func phrase(_ zh: String, _ en: String) -> String { W8Text.t(zh, en) }

    var body: some View {
        Cloud03Screen(
            title: phrase("取消预约", "Cancel reservation"),
            seed: reservationID.isEmpty ? "bundle-cancel" : reservationID,
            symbol: "calendar.badge.minus"
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                stateBody
            }
        }
        .cyAnimation(value: model.state)
        .onChange(of: model.state) { _, new in
            guard !reduceMotion else { return }
            switch new {
            case .cancelled: CYHaptics.success.play()
            case .failed: CYHaptics.warning.play()
            default: break
            }
        }
    }

    @ViewBuilder private var stateBody: some View {
        switch model.state {
        case .idle:
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYInfoCard {
                    Toggle(isOn: $useWaiver) { Text(verbatim: phrase("使用本月豁免次数", "Use this month's waiver")) }
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }
                CYPillButton(verbatim: phrase("查看取消结果", "Check cancellation"), systemImage: "doc.text.magnifyingglass") {
                    Task { await model.requestQuote(reservationID: reservationID, useWaiver: useWaiver) }
                }
                .accessibilityLabel(Text(verbatim: phrase("查看取消结果", "Check cancellation")))
            }
        case .quoting:
            loading(phrase("正在查询取消结果", "Checking cancellation"))
        case .cancelling:
            loading(phrase("正在取消", "Cancelling"))
        case .awaitingConfirmation(_, _, let quote):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYNoteBanner(text: Text(verbatim: Cloud03Copy.shown(quote.message)), symbol: "text.quote", tone: .neutral)
                Button(role: .destructive) { Task { await canceler.confirm(on: model) } } label: {
                    Text(verbatim: phrase("确认取消", "Confirm cancellation"))
                }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
                .accessibilityLabel(Text(verbatim: phrase("确认取消", "Confirm cancellation")))
                CYPillButton(verbatim: phrase("返回", "Back"), style: .secondary) { model.dismiss() }
                    .accessibilityLabel(Text(verbatim: phrase("返回", "Back")))
            }
        case .cancelled(let status):
            CYNoteBanner(
                text: Text(verbatim: phrase(
                    "预约已取消（\(Cloud03Copy.shown(status))）",
                    "Reservation cancelled (\(Cloud03Copy.shown(status)))."
                )),
                symbol: "checkmark.circle",
                tone: .success
            )
        case .failed(let message):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYNoteBanner(text: Text(verbatim: Cloud03Copy.shown(message)), symbol: "exclamationmark.triangle", tone: .danger)
                CYPillButton(verbatim: phrase("返回", "Back"), style: .primary) { model.dismiss() }
                    .accessibilityLabel(Text(verbatim: phrase("返回", "Back")))
            }
        case .awaitingServerConfirmation:
            VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYNoteBanner(
                text: Text(verbatim: phrase(
                    "正在等待服务器确认，请勿重复提交",
                    "Waiting for the server to confirm. Please don't submit again."
                )),
                symbol: "clock",
                tone: .warning
            )
            CYPillButton(verbatim: phrase("刷新状态", "Refresh status"), systemImage: "arrow.clockwise") {
                Task {
                    await canceler.readBack(
                        model: model,
                        service: service,
                        registrationID: registrationID,
                        reservationID: reservationID
                    )
                }
            }
            .accessibilityLabel(Text(verbatim: phrase("刷新状态", "Refresh status")))
            }
        case .unavailable:
            CYStateLayout(kind: .offline, title: Text(verbatim: phrase("暂未开放", "Not open yet")))
        }
    }

    private func loading(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYSkeleton().accessibilityHidden(true)
            Text(verbatim: label)
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
