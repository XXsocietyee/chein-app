import SwiftUI

/// Embedded in the installation receipt. It does not own the navigation bar, so it does not call `cyHeroScreen()` — that would clear the parent screen's only title.
struct ModCompositionInstallationReceiptView: View {
    let value: ModCompositionInstallationReceipt
    @Environment(\.locale) private var locale
    private var usesChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    private func copy(_ zh: String, _ en: String) -> String { usesChinese ? zh : en }
    private func shown(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYSectionHeader(LocalizedStringKey(stringLiteral: copy("原多依赖安装组", "Original dependency installation group")))
            line(systemImage: "lock", text: "lock=" + shown(value.lockHash))
            Text(verbatim: copy(
                "确认会同时安装所列依赖，并分别使用各原许可的一次安装额度。仅创建私有稿，仍需事实确认与原审核发布。读取原结果不会再次安装或消耗额度。",
                "Confirmation installs the listed dependencies together, using one installation allowance from each original license. Only private drafts are created; fact confirmation and the original review and publication process still apply. Reading the original result does not install again or use allowance."
            ))
            .font(CYTypography.body)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            ForEach(value.parts) { part in
                partCard(part)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .privacySensitive()
        .textSelection(.enabled)
    }

    private func partCard(_ part: ModCompositionInstallationReceipt.Part) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(
                verbatim: shown(part.packageId) + " @ " + shown(part.packageVersion) + " / " + shown(part.releaseId),
                trailing: .none
            ) {
                CYCoverArt(seed: part.packageId + "@" + part.packageVersion, symbol: "shippingbox", showsDebugLabel: false, cornerRadius: CYRadius.sm)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            line(systemImage: "number", text: copy("原请求 ", "Original request ") + shown(part.requestId))
            line(systemImage: "checkmark.seal", text: copy("原许可 ", "Original license ") + shown(part.licenseId))
            line(systemImage: "number", text: shown(part.contentHash))
            line(systemImage: "cpu", text: shown(part.compilerVersion) + " / " + shown(part.compiledHash))
            line(systemImage: "key", text: copy("组合权利 ", "Composition grant ") + shown(part.grantHash))
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// Full-width line so a hash wraps instead of truncating. The icon is decorative.
    private func line(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: systemImage)
            Text(verbatim: text)
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
