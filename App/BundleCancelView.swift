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
            stateBody
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
            Section {
                Toggle(isOn: $useWaiver) { Text(verbatim: phrase("使用本月豁免次数", "Use this month's waiver")) }
            }
            Section {
                Button {
                    Task { await model.requestQuote(reservationID: reservationID, useWaiver: useWaiver) }
                } label: {
                    Label(phrase("查看取消结果", "Check cancellation"), systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityLabel(Text(verbatim: phrase("查看取消结果", "Check cancellation")))
            }
        case .quoting:
            loading(phrase("正在查询取消结果", "Checking cancellation"))
        case .cancelling:
            loading(phrase("正在取消", "Cancelling"))
        case .awaitingConfirmation(_, _, let quote):
            Section {
                Cloud03Note(text: Text(verbatim: Cloud03Copy.shown(quote.message)), symbol: "text.quote", tone: .neutral)
            }
            Section {
                Button(role: .destructive) { Task { await canceler.confirm(on: model) } } label: {
                    Text(verbatim: phrase("确认取消", "Confirm cancellation"))
                }
                .accessibilityLabel(Text(verbatim: phrase("确认取消", "Confirm cancellation")))
                Button { model.dismiss() } label: {
                    Text(verbatim: phrase("返回", "Back"))
                }
                .accessibilityLabel(Text(verbatim: phrase("返回", "Back")))
            }
        case .cancelled(let status):
            Section {
                Cloud03Note(
                    text: Text(verbatim: phrase(
                        "预约已取消（\(Cloud03Copy.shown(status))）",
                        "Reservation cancelled (\(Cloud03Copy.shown(status)))."
                    )),
                    symbol: "checkmark.circle",
                    tone: .success
                )
            }
        case .failed(let message):
            Section {
                Cloud03Note(text: Text(verbatim: Cloud03Copy.shown(message)), symbol: "exclamationmark.triangle", tone: .danger)
            }
            Section {
                Button { model.dismiss() } label: {
                    Text(verbatim: phrase("返回", "Back"))
                }
                .accessibilityLabel(Text(verbatim: phrase("返回", "Back")))
            }
        case .awaitingServerConfirmation:
            Section {
                Cloud03Note(
                    text: Text(verbatim: phrase(
                        "正在等待服务器确认，请勿重复提交",
                        "Waiting for the server to confirm. Please don't submit again."
                    )),
                    symbol: "clock",
                    tone: .warning
                )
                Button {
                    Task {
                        await canceler.readBack(
                            model: model,
                            service: service,
                            registrationID: registrationID,
                            reservationID: reservationID
                        )
                    }
                } label: {
                    Label(phrase("刷新状态", "Refresh status"), systemImage: "arrow.clockwise")
                }
                .accessibilityLabel(Text(verbatim: phrase("刷新状态", "Refresh status")))
            }
        case .unavailable:
            ContentUnavailableView(phrase("暂未开放", "Not open yet"), systemImage: "exclamationmark.circle")
                .listRowBackground(Color.clear)
        }
    }

    private func loading(_ label: String) -> some View {
        Section {
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(verbatim: label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
