import SwiftUI

/// An installed native text/choice receipt is only a reference; the factory needs a separate read grant.
@MainActor struct ModInstalledTextReadEntry: View {
    let makeReader: @MainActor () -> ModInstalledTextReader?
    @State private var reader: ModInstalledTextReader?
    @State private var visible = false
    @State private var unavailable = false
    @Environment(\.locale) private var locale
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    private var presented: Binding<ModInstalledTextReader?> {
        let expected = reader?.id
        return Binding(get: { reader?.id == expected ? reader : nil }, set: { replacement in
            guard reader?.id == expected else { return }
            if reader?.id != replacement?.id { reader?.retire() }
            reader = replacement
        })
    }
    var body: some View {
        Button(zh ? "读取原安装文字/选择题正文" : "Read original installed text/choice content") {
            guard visible, reader == nil else { return }
            guard let captured = makeReader() else { unavailable = true; return }
            unavailable = false; reader = captured
        }.accessibilityIdentifier("modInstalledText.entry")
        if unavailable {
            Text(zh ? "独立正文读取未获配置或原安装当前不可用；不会重装、购买或清理原记录。" : "Protected reading is not configured or the original installation is unavailable. No reinstall, purchase or record deletion occurs.")
                .font(.caption)
        }
        Color.clear.frame(height: 0).sheet(item: presented) { captured in
            ModInstalledTextReadView(reader: captured) {
                captured.retire(); guard reader === captured else { return }; presented.wrappedValue = nil
            }.id(captured.id)
        }
        .onAppear { visible = true }
        .onDisappear { visible = false; reader?.retire(); reader = nil }
    }
}

@MainActor private struct ModInstalledTextReadView: View {
    let reader: ModInstalledTextReader
    let onClose: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @State private var installed = true
    @State private var retry: Task<Void, Never>?
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(zh ? "仅本人原生文字/选择题原安装快照，不是当前编辑稿，不授权保存、导出、发布或开局。qmod、组合主题和H5仍使用其原入口。" : "Your original native text/choice snapshot only—not the current edited draft, or permission to save, export, publish or play. qmod, composed topics and H5 keep their existing entries.")
                }
                if phase != .active {
                    Text(zh ? "已隐藏私密正文" : "Private content hidden")
                } else if reader.loading {
                    ProgressView()
                } else if let value = reader.content, reader.available {
                    Section(zh ? "原安装与冻结版本" : "Original installation and frozen version") {
                        LabeledContent(zh ? "原请求" : "Original request", value: value.requestId)
                        LabeledContent(zh ? "许可" : "License", value: value.licenseId)
                        LabeledContent(zh ? "版本" : "Release", value: value.releaseId)
                        LabeledContent(zh ? "原安装稿" : "Original draft", value: String(value.draftId))
                        Text(verbatim: value.contentHash).font(.caption.monospaced())
                        Text(verbatim: value.bindingHash).font(.caption.monospaced())
                    }
                    Section(zh ? "受保护文字" : "Protected text") {
                        Picker(zh ? "快照" : "Snapshot", selection: $installed) {
                            Text(zh ? "原绑定安装稿" : "Original bound copy").tag(true)
                            Text(zh ? "已购冻结原文" : "Licensed frozen source").tag(false)
                        }.pickerStyle(.segmented)
                        if let fields = try? value.fields(installed: installed) {
                            ForEach(ModInstalledTextRead.fieldNames, id: \.self) { name in
                                if let text = fields[name] {
                                    DisclosureGroup {
                                        Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
                                    } label: { Text(LocalizedStringKey("modInstallation.field." + name), tableName: "ModInstallation") }
                                }
                            }
                        }
                    }
                    Section(zh ? "原冻结用途条款" : "Frozen use terms") {
                        Text(verbatim: value.termsVersion); Text(verbatim: value.termsHash).font(.caption.monospaced())
                        Text(verbatim: value.useDuration); Text(verbatim: value.updatePolicy); Text(verbatim: value.redistribution)
                        ForEach(value.allowedRegions, id: \.self) { Text(verbatim: $0) }
                        Text(zh ? "当前读取仍需有效许可和原资源使用权限；普通下架不改写这些原条款。" : "Reading still requires a current license and original resource-use rights; ordinary delisting does not rewrite these terms.")
                    }
                } else {
                    Text(zh ? "本次正文未确认。可能是读取未批准、许可/资源权限变更、非原生文字格式或暂时不可读；不据此认定原安装失败。" : "Content is unconfirmed: reading may be unapproved, rights may have changed, the profile may not be native text, or the read may be unavailable. This does not mean the original installation failed.")
                    Button(zh ? "重读同一原请求" : "Read the same original request") {
                        retry?.cancel(); retry = Task { await reader.reload() }
                    }.disabled(!reader.available)
                }
            }
            .navigationTitle(zh ? "原安装正文" : "Original installed text")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(zh ? "关闭" : "Close") { reader.retire(); retry?.cancel(); onClose() }
            } }
        }.privacySensitive()
        .task(id: phase) {
            guard phase == .active else { reader.suspend(); return }
            await reader.reload()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled, reader.refreshVisiblePermission() else { return }
            }
        }
        .onChange(of: phase) { _, next in if next != .active { reader.suspend(); retry?.cancel() } }
        .onDisappear { reader.retire(); retry?.cancel() }
    }
}
