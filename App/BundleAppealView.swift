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
    @QuestifyReduceMotion private var reduceMotion

    private func text(_ zh: String, _ en: String) -> Text { Text(verbatim: W8Text.t(zh, en)) }
    private func phrase(_ zh: String, _ en: String) -> String { W8Text.t(zh, en) }

    private var busy: Bool { model.state == .submitting }
    private var locked: Bool {
        switch model.state {
        case .submitting, .awaitingReadback, .readbackNotFound, .submitted: return true
        default: return false
        }
    }

    var body: some View {
        Cloud03Screen(
            title: phrase("申诉", "Appeal"),
            seed: "bundle-appeal",
            symbol: "exclamationmark.bubble"
        ) {
            formSection
            Section {
                statusBlock
            }
            Section {
                submitButton
                recoveryButtons
            }
        }
        .cyAnimation(value: model.state)
        .task { model.restore() }
        .onChange(of: model.state) { _, new in
            guard !reduceMotion else { return }
            if case .submitted = new { CYHaptics.success.play() }
            if case .blocked = new { CYHaptics.warning.play() }
        }
    }

    private var formSection: some View {
        Section {
            Picker(selection: $reason) {
                text("商家忘记核销", "Merchant forgot to scan").tag(BundleAppealReason.merchantForgotScan)
                text("其他", "Other").tag(BundleAppealReason.other)
            } label: { text("申诉原因", "Reason") }
            TextField(phrase("补充说明（最多500字）", "Note (up to 500 characters)"), text: $note, axis: .vertical)
                .lineLimit(3...8)
                .accessibilityLabel(Text(verbatim: phrase("补充说明（最多500字）", "Note (up to 500 characters)")))
                .onChange(of: note) { _, value in
                    if value.count > BundleAppealLimits.maxNoteCharacters { note = String(value.prefix(BundleAppealLimits.maxNoteCharacters)) }
                }
            Label(
                phrase(
                    "已附证据 \(evidenceRefs.count)/\(BundleAppealLimits.maxEvidenceRefs)",
                    "Evidence attached \(evidenceRefs.count)/\(BundleAppealLimits.maxEvidenceRefs)"
                ),
                systemImage: "paperclip"
            )
        } footer: {
            text(
                "提交后将进入审核，审核结果以服务器为准；提交不代表已退款或已核销。",
                "Your appeal will be submitted for review. The outcome is decided by the server; submitting does not refund or redeem anything."
            )
        }
        .disabled(locked)
    }

    @ViewBuilder private var statusBlock: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .submitting:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(verbatim: phrase("正在提交", "Submitting"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .submitted(let appeal):
            submittedStatus(appeal)
        case .awaitingReadback:
            Cloud03Note(
                text: text("未能确认是否已提交，请先查询结果。", "We couldn't confirm whether it was submitted. Check the result first."),
                symbol: "questionmark.circle",
                tone: .warning
            )
        case .readbackNotFound:
            Cloud03Note(
                text: text("暂未查到该申诉。可以再次查询，或使用同一申请重新提交。", "No record yet. Check again, or send the same appeal again."),
                symbol: "magnifyingglass",
                tone: .warning
            )
        case .blocked(let code):
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Cloud03Note(
                    text: text("服务器未接受这次申诉。", "The server did not accept this appeal."),
                    symbol: "exclamationmark.triangle",
                    tone: .danger
                )
                if let code {
                    Text(verbatim: Cloud03Copy.shown(code))
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .loginRequired:
            Cloud03Note(
                text: text("请先登录后再试，已保存的申诉不会丢失。", "Sign in and try again. Your saved appeal is kept."),
                symbol: "person.crop.circle.badge.exclamationmark",
                tone: .warning
            )
        case .storageFailed:
            Cloud03Note(
                text: text("无法在本机保存申诉，未发送。", "Couldn't save the appeal on this device. Nothing was sent."),
                symbol: "externaldrive.badge.exclamationmark",
                tone: .danger
            )
        case .unavailable:
            ContentUnavailableView {
                Label { text("申诉功能暂未开放。", "Appeals aren't open yet.") } icon: { Image(systemName: "wifi.slash") }
            }
        case .failed:
            Cloud03Note(
                text: text("内容不符合要求，请检查后重试。", "Check the details and try again."),
                symbol: "exclamationmark.circle",
                tone: .danger
            )
        }
    }

    private func submittedStatus(_ appeal: BundleAppeal) -> some View {
        let shown = model.presentation(for: appeal)
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Cloud03Note(text: Text(verbatim: Cloud03Copy.shown(shown.title)), symbol: "clock", tone: .info)
            if let detail = shown.detail {
                Text(verbatim: Cloud03Copy.shown(detail))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                await model.submit(
                    registrationID: registrationID,
                    unitID: unitID,
                    reason: reason,
                    note: note,
                    evidenceRefs: evidenceRefs
                )
            }
        } label: {
            Label(phrase("提交申诉", "Submit appeal"), systemImage: "paperplane")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(locked)
        .accessibilityLabel(Text(verbatim: phrase("提交申诉", "Submit appeal")))
    }

    @ViewBuilder private var recoveryButtons: some View {
        switch model.state {
        case .awaitingReadback:
            Button {
                Task { await model.recover() }
            } label: {
                Label(phrase("查询提交结果", "Check result"), systemImage: "arrow.clockwise")
            }
            .disabled(busy)
            .accessibilityLabel(Text(verbatim: phrase("查询提交结果", "Check result")))
        case .readbackNotFound:
            Group {
                Button {
                    Task { await model.recover() }
                } label: {
                    Label(phrase("再次查询", "Check again"), systemImage: "arrow.clockwise")
                }
                .accessibilityLabel(Text(verbatim: phrase("再次查询", "Check again")))
                Button {
                    Task { await model.retryOriginal() }
                } label: {
                    Text(verbatim: phrase("重新提交同一申诉", "Send the same appeal again"))
                }
                .accessibilityLabel(Text(verbatim: phrase("重新提交同一申诉", "Send the same appeal again")))
            }
        default:
            EmptyView()
        }
    }
}
