import SwiftUI

struct ModCompositionInstallationReceiptView: View {
    let value: ModCompositionInstallationReceipt
    @Environment(\.locale) private var locale
    private var usesChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(usesChinese ? "原多依赖安装组" : "Original dependency installation group").font(Theme.Font.sectionTitle)
            Text(verbatim: "lock=" + value.lockHash).font(Theme.Font.label.monospaced()).fixedSize(horizontal: false, vertical: true)
            Text(usesChinese ? "确认会同时安装所列依赖，并分别使用各原许可的一次安装额度。仅创建私有稿，仍需事实确认与原审核发布。读取原结果不会再次安装或消耗额度。" : "Confirmation installs the listed dependencies together, using one installation allowance from each original license. Only private drafts are created; fact confirmation and the original review and publication process still apply. Reading the original result does not install again or use allowance.")
                .font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(value.parts) { part in
                VStack(alignment: .leading) {
                    Text(verbatim: part.packageId + " @ " + part.packageVersion + " / " + part.releaseId).font(Theme.Font.cardTitle)
                    Text(verbatim: (usesChinese ? "原请求 " : "Original request ") + part.requestId).font(Theme.Font.label.monospaced())
                    Text(verbatim: (usesChinese ? "原许可 " : "Original license ") + part.licenseId).font(Theme.Font.label)
                    Text(verbatim: part.contentHash).font(Theme.Font.label.monospaced())
                    Text(verbatim: part.compilerVersion + " / " + part.compiledHash).font(Theme.Font.label.monospaced())
                    Text(verbatim: (usesChinese ? "组合权利 " : "Composition grant ") + part.grantHash).font(Theme.Font.label.monospaced())
                }.fixedSize(horizontal: false, vertical: true)
            }
        }.privacySensitive().textSelection(.enabled)
    }
}
