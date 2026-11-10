import SwiftUI

/// Only the signed-in player's original MOD command response. No other player's row or private config is rendered.
@MainActor struct ModInstallationNativeActionReceiptView: View {
    let receipt: PlayAdvancedState
    let requestID: String
    @Environment(\.locale) private var locale
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    private var qa: Bool { receipt.modInstallationRuntime["kind"].text == "QA_PICK" }
    private var segment: PlayWireValue { qa ? receipt.playKit["qa"] : receipt.branch }
    var body: some View {
        Section {
            Text(verbatim: zh ? "这是该原请求的服务端回执，不代表下方最新状态仍可提交；次数耗尽不等于答对。" : "This is the original request's server receipt, not permission to submit in the latest state below. Exhausted attempts do not mean a correct answer.")
                .font(.footnote)
            LabeledContent(zh ? "原请求" : "Original request") { Text(verbatim: requestID).textSelection(.enabled) }
            LabeledContent(zh ? "回执版本" : "Receipt version") { Text(verbatim: String(receipt.version)) }
            if qa {
                if let passed = segment["passed"].bool {
                    CYStatusChip(verbatim: zh ? (passed ? "服务端判定：答对" : "服务端判定：未答对") : (passed ? "Server verdict: correct" : "Server verdict: not correct"),
                                 tone: passed ? .success : .warning, systemImage: passed ? "checkmark.circle" : "xmark.circle")
                }
                if let finished = segment["finished"].bool {
                    Text(verbatim: zh ? (finished ? "本题已结束" : "本题尚未结束") : (finished ? "Question finished" : "Question not finished"))
                }
                if let tries = segment["attempts"].integer { LabeledContent(zh ? "已用次数" : "Attempts used") { Text(verbatim: String(tries)) } }
                if let feedback = segment["lastFeedback"].text ?? segment["feedback"].text { Text(verbatim: feedback) }
            } else {
                // The existing publicBranch contract exposes a step, not a fabricated outcomeCode.
                if let step = segment["currentStepId"].text { LabeledContent(zh ? "服务端记录步骤" : "Recorded server step") { Text(verbatim: step) } }
                if let title = segment["currentStep"]["title"].text { Text(verbatim: title) }
                if let terminal = segment["currentStep"]["terminal"].bool {
                    Text(verbatim: zh ? (terminal ? "该选择步骤已结束" : "该选择步骤尚未结束") : (terminal ? "Choice step finished" : "Choice step not finished"))
                }
            }
        } header: { Text(verbatim: zh ? "原动作回执（非当前状态）" : "Original action receipt (not current state)") }
        .privacySensitive().accessibilityIdentifier("modInstallation.native.originalReceipt")
    }
}
