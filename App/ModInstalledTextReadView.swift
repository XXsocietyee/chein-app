import SwiftUI

/// An installed native text/choice receipt is only a reference; the factory needs a separate read grant.
@MainActor struct ModInstalledTextReadEntry: View {
    let makeReader: @MainActor () -> ModInstalledTextReader?
    @State private var reader: ModInstalledTextReader?
    @State private var visible = false
    @State private var unavailable = false
    @Environment(\.locale) private var locale
    private var zh: Bool { locale.language.languageCode?.identifier == "zh" }
    private var entryTitle: String { zh ? "读取原安装文字/选择题正文" : "Read original installed text/choice content" }
    private var unavailableCopy: String {
        zh ? "独立正文读取未获配置或原安装当前不可用；不会重装、购买或清理原记录。" : "Protected reading is not configured or the original installation is unavailable. No reinstall, purchase or record deletion occurs."
    }
    private var presented: Binding<ModInstalledTextReader?> {
        let expected = reader?.id
        return Binding(get: { reader?.id == expected ? reader : nil }, set: { replacement in
            guard reader?.id == expected else { return }
            if reader?.id != replacement?.id { reader?.retire() }
            reader = replacement
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYPillButton(verbatim: entryTitle, style: .secondary, systemImage: "text.book.closed") {
                guard visible, reader == nil else { return }
                guard let captured = makeReader() else { unavailable = true; return }
                unavailable = false; reader = captured
            }
            .accessibilityIdentifier("modInstalledText.entry")
            .accessibilityLabel(Text(verbatim: entryTitle))
            if unavailable {
                CYNoteBanner(text: Text(verbatim: unavailableCopy), symbol: "lock.slash", tone: .warning)
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false; reader?.retire(); reader = nil }
        .cySheet(item: presented) { captured in
            Group {
                ModInstalledTextReadView(reader: captured) {
                    captured.retire(); guard reader === captured else { return }; presented.wrappedValue = nil
                }.id(captured.id)
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
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
            Cloud25Screen(title: zh ? "原安装正文" : "Original installed text", seed: reader.installation.requestId, symbol: "text.book.closed") {
                CYInfoCard {
                    Text(verbatim: zh
                         ? "仅本人原生文字/选择题原安装快照，不是当前编辑稿，不授权保存、导出、发布或开局。qmod、组合主题和H5仍使用其原入口。"
                         : "Your original native text/choice snapshot only—not the current edited draft, or permission to save, export, publish or play. qmod, composed topics and H5 keep their existing entries.")
                        .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                if phase != .active {
                    CYEmptyState(systemImage: "lock", LocalizedStringKey(stringLiteral: zh ? "已隐藏私密正文" : "Private content hidden"))
                } else if reader.loading {
                    CYSkeleton().accessibilityLabel(Text("cy.state.loading"))
                } else if let value = reader.content, reader.available {
                    identity(value)
                    protected(value)
                    terms(value)
                } else {
                    CYEmptyState(
                        systemImage: "exclamationmark.triangle",
                        LocalizedStringKey(stringLiteral: zh
                            ? "本次正文未确认。可能是读取未批准、许可/资源权限变更、非原生文字格式或暂时不可读；不据此认定原安装失败。"
                            : "Content is unconfirmed: reading may be unapproved, rights may have changed, the profile may not be native text, or the read may be unavailable. This does not mean the original installation failed."),
                        actionTitle: LocalizedStringKey(stringLiteral: zh ? "重读同一原请求" : "Read the same original request"),
                        actionStyle: .primary,
                        kind: .failure,
                        action: {
                            retry?.cancel()
                            retry = Task { await reader.reload() }
                        }
                    )
                    .disabled(!reader.available)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(zh ? "关闭" : "Close") { reader.retire(); retry?.cancel(); onClose() }
                    .accessibilityLabel(Text(verbatim: zh ? "关闭" : "Close"))
            } }
        }
        .privacySensitive()
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

    private func identity(_ value: ModInstalledTextRead) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYImageCard(
                verbatim: Cloud25Copy.value(value.moduleId),
                fallback: LocalizedStringKey(stringLiteral: "—"),
                meta: Cloud25Copy.value(value.releaseId)
            )
            CYInfoCard {
            Cloud25Header(title: zh ? "原安装与冻结版本" : "Original installation and frozen version")
            CYFactRow(label: Text(verbatim: zh ? "原请求" : "Original request"), value: Cloud25Copy.value(value.requestId))
            CYFactRow(label: Text(verbatim: zh ? "许可" : "License"), value: Cloud25Copy.value(value.licenseId))
            CYFactRow(label: Text(verbatim: zh ? "版本" : "Release"), value: Cloud25Copy.value(value.releaseId))
            CYFactRow(label: Text(verbatim: zh ? "原安装稿" : "Original draft"), value: String(value.draftId))
            Text(verbatim: Cloud25Copy.value(value.contentHash)).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: Cloud25Copy.value(value.bindingHash)).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func protected(_ value: ModInstalledTextRead) -> some View {
        CYInfoCard {
            Cloud25Header(title: zh ? "受保护文字" : "Protected text")
            Picker(zh ? "快照" : "Snapshot", selection: $installed) {
                Text(zh ? "原绑定安装稿" : "Original bound copy").tag(true)
                Text(zh ? "已购冻结原文" : "Licensed frozen source").tag(false)
            }
            .cyAdaptiveSegmented()
            .frame(minHeight: CYSpacing.minTouchTarget)
            if let fields = try? value.fields(installed: installed) {
                ForEach(ModInstalledTextRead.fieldNames, id: \.self) { name in
                    if let text = fields[name] {
                        DisclosureGroup {
                            Text(verbatim: text).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                        } label: {
                            Text(LocalizedStringKey("modInstallation.field." + name), tableName: "ModInstallation")
                                .cyText(.cardTitle)
                        }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                }
            }
        }
    }

    private func terms(_ value: ModInstalledTextRead) -> some View {
        CYInfoCard {
            Cloud25Header(title: zh ? "原冻结用途条款" : "Frozen use terms")
            CYFactRow(label: Text(verbatim: zh ? "条款版本" : "Terms version"), value: Cloud25Copy.value(value.termsVersion))
            Text(verbatim: Cloud25Copy.value(value.termsHash)).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            CYFactRow(label: Text(verbatim: zh ? "使用期限" : "Use duration"), value: Cloud25Copy.value(value.useDuration))
            CYFactRow(label: Text(verbatim: zh ? "更新政策" : "Update policy"), value: Cloud25Copy.value(value.updatePolicy))
            CYFactRow(label: Text(verbatim: zh ? "再分发" : "Redistribution"), value: Cloud25Copy.value(value.redistribution))
            ForEach(value.allowedRegions, id: \.self) { region in
                CYStatusChip(verbatim: Cloud25Copy.value(region), tone: .neutral, systemImage: "globe")
                    .accessibilityLabel(Text(verbatim: Cloud25Copy.value(region)))
            }
            Text(verbatim: zh
                 ? "当前读取仍需有效许可和原资源使用权限；普通下架不改写这些原条款。"
                 : "Reading still requires a current license and original resource-use rights; ordinary delisting does not rewrite these terms.")
                .cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
