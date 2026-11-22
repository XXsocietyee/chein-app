import SwiftUI

/// P0-14 生成式 AI 内容显式标识 (mini-program `utils/aigc-label.js`).
/// - `AIGCLabel`: the mono 「AI 生成」 tag, shown where the content's `publishMode == ai_simple`
///   (topic story header, play title card kicker).
/// - Filing number: `/api/config/features → aigcFilingNo` (≤ 64 chars), shown in About and under the AI draft
///   tool; empty ⇒ nothing rendered. Injected from root composition via `.environment(\.aigcFilingNumber, …)`.
enum AIGCDisclosure {
    /// Mirrors `isAiGenerated(publishMode)`.
    static func isAIGenerated(publishMode: String?) -> Bool {
        publishMode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ai_simple"
    }
    /// Mirrors `filingNo`: trimmed, first 64 characters, empty ⇒ nil.
    static func filingNumber(_ raw: String?) -> String? {
        let value = String((raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        return value.isEmpty ? nil : value
    }
}

private struct AIGCFilingNumberKey: EnvironmentKey { static let defaultValue: String? = nil }
extension EnvironmentValues {
    var aigcFilingNumber: String? {
        get { self[AIGCFilingNumberKey.self] }
        set { self[AIGCFilingNumberKey.self] = newValue }
    }
}

struct AIGCLabel: View {
    var body: some View {
        Label("mpd.aigc.label", systemImage: "sparkles")
            .cyText(.caption, weight: .semibold)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
            .foregroundStyle(CYColor.textSecondary)
            .background(CYColor.bgSurfaceSubtle, in: Capsule())
            .overlay(Capsule().strokeBorder(CYColor.textTertiary.opacity(0.35), lineWidth: 0.5))
            .accessibilityIdentifier("aigc.label")
    }
}

/// The filing line itself; renders nothing without a number.
struct AIGCFilingNumberText: View {
    @Environment(\.aigcFilingNumber) private var raw
    var body: some View {
        if let number = AIGCDisclosure.filingNumber(raw) {
            Text("mpd.aigc.filing \(number)")
                .cyText(.caption).foregroundStyle(CYColor.textTertiary)
                .textSelection(.enabled)
                .accessibilityIdentifier("aigc.filing")
        }
    }
}
