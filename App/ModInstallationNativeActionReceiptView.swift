import SwiftUI

/// Only the signed-in player's original MOD command response. No other player's row or private config is rendered.
/// Embedded in the play list. It does not call `cyHeroScreen()` — that would clear the play screen's title.
@MainActor struct ModInstallationNativeActionReceiptView: View {
    let receipt: PlayAdvancedState
    let requestID: String
    @Environment(\.locale) private var locale
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    private var qa: Bool { receipt.modInstallationRuntime["kind"].text == "QA_PICK" }
    private var segment: PlayWireValue { qa ? receipt.playKit["qa"] : receipt.branch }
    private func copy(_ zh: String, _ en: String) -> String { self.zh ? zh : en }
    private func shown(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
    }
    var body: some View {
        Section {
            Text(verbatim: copy(
                "这是该原请求的服务端回执，不代表下方最新状态仍可提交；次数耗尽不等于答对。",
                "This is the original request's server receipt, not permission to submit in the latest state below. Exhausted attempts do not mean a correct answer."
            ))
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            labeled(copy("原请求", "Original request"), shown(requestID))
            labeled(copy("回执版本", "Receipt version"), String(receipt.version))
            if qa {
                if let passed = segment["passed"].bool {
                    verdict(
                        passed,
                        yes: copy("服务端判定：答对", "Server verdict: correct"),
                        no: copy("服务端判定：未答对", "Server verdict: not correct"),
                        symbol: passed ? "checkmark.circle" : "xmark.circle"
                    )
                }
                if let finished = segment["finished"].bool {
                    verdict(
                        finished,
                        yes: copy("本题已结束", "Question finished"),
                        no: copy("本题尚未结束", "Question not finished"),
                        symbol: finished ? "flag.checkered" : "hourglass"
                    )
                }
                if let tries = segment["attempts"].integer { labeled(copy("已用次数", "Attempts used"), String(tries)) }
                if let feedback = segment["lastFeedback"].text ?? segment["feedback"].text {
                    Text(verbatim: shown(feedback))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // The existing publicBranch contract exposes a step, not a fabricated outcomeCode.
                if let step = segment["currentStepId"].text { labeled(copy("服务端记录步骤", "Recorded server step"), shown(step)) }
                if let title = segment["currentStep"]["title"].text {
                    Text(verbatim: shown(title))
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let terminal = segment["currentStep"]["terminal"].bool {
                    verdict(
                        terminal,
                        yes: copy("该选择步骤已结束", "Choice step finished"),
                        no: copy("该选择步骤尚未结束", "Choice step not finished"),
                        symbol: terminal ? "flag.checkered" : "arrow.triangle.branch"
                    )
                }
            }
        } header: {
            Text(LocalizedStringKey(stringLiteral: copy("原动作回执（非当前状态）", "Original action receipt (not current state)")))
                .accessibilityAddTraits(.isHeader)
        }
        .privacySensitive()
        .accessibilityIdentifier("modInstallation.native.originalReceipt")
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: title)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: value)
                .cyText(.body, monospacedDigit: true)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Icon plus the existing sentence. Colour is never the only signal, and the sentence is not line-limited.
    private func verdict(_ on: Bool, yes: String, no: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(on ? CYColor.successText : CYColor.textSecondary)
                .accessibilityHidden(true)
            Text(verbatim: on ? yes : no)
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
