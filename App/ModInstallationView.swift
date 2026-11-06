import SwiftUI

/// Owned-license entry only. Commerce owns the license; this feature owns real resource binding and installation.
@MainActor struct ModInstallationLicenseLink: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    var body: some View {
        NavigationLink {
            ModInstallationEntry(reference: reference, makeController: makeController, makeOriginalReader: makeOriginalReader, makeInstallationPair: makeInstallationPair)
        } label: { installationText("open") }
    }
}

@MainActor struct ModInstallationEntry: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    @EnvironmentObject private var session: AppSession
    @State private var controller: ModInstallationController?
    @State private var originalReader: H5OriginalInstallReader?
    var body: some View {
        Group {
            if let controller, controller.isCurrent {
                ModInstallationView(controller: controller, originalReader: originalReader).id(ObjectIdentifier(controller))
            } else {
                VStack(spacing: 16) {
                    installationText("unavailable")
                    Button { reopen() } label: { installationText("reload") }
                }.padding()
            }
        }
        .onAppear { if controller?.isCurrent != true { reopen() } }
        .onChange(of: session.sessionRevision) { _, _ in reopen() }
        .onChange(of: session.account?.id) { _, _ in reopen() }
        .onChange(of: session.account?.effectiveRole) { _, _ in reopen() }
        // Do not invalidate on disappearance: pushing the real editor and returning must remain usable.
        // The service lease independently rejects account/role/token/realm/approval changes.
    }
    private func reopen() {
        controller?.invalidate()
        if let makeInstallationPair {
            let pair = makeInstallationPair(reference)
            controller = pair?.controller
            originalReader = pair?.originalReader
            return
        }
        controller = makeController(reference)
        originalReader = makeOriginalReader(reference)
    }
}

@MainActor private struct ModInstallationView: View {
    @Environment(\.themeDomain) private var domain
    @State var controller: ModInstallationController
    var originalReader: H5OriginalInstallReader? = nil
    @State private var originalFact: WorkshopOriginalInstallFact?
    @State private var originalReadGeneration: UInt64 = 0
    @State private var originalReadBusy = false
    @State private var originalReadUnknown = false
    @State private var confirmation: ModInstallationReceipt?
    @State private var factReview: ModInstallationFacts?
    @State private var cancellation: ModInstallationReceipt?
    @State private var editing: ModInstallationTemplateEditor?
    @State private var editingQa: ModInstallationQaEditor?
    @State private var editingTopic: ModInstallationReceipt?
    @State private var venue: ModVenueOperations?
    @State private var showCancellation = false
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Form {
            Section {
                if let title = controller.options?.title { Text(verbatim: title).font(Theme.Font.sectionTitle).fixedSize(horizontal: false, vertical: true) }
                InstallationFact("license", controller.identity.licenseId)
                InstallationFact("module", controller.identity.moduleId)
                InstallationFact("release", controller.identity.releaseId)
                InstallationFact("contentHash", controller.identity.contentHash)
                InstallationFact("termsHash", controller.identity.termsHash)
                installationText("boundary").font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } header: { installationText("authorizedVersion") }

            Section {
                if let value = controller.compatibility {
                    Text(verbatim: value.reasonCode)
                    Text(locale.language.languageCode?.identifier == "zh" ? "客户端 \(value.clientVersion)，最低版本 \(value.minimumClientVersion)；运行时 \(value.runtimeVersion)" : "Client \(value.clientVersion), minimum \(value.minimumClientVersion); runtime \(value.runtimeVersion)")
                }
                if controller.compatibilityReadFailed { Text(locale.language.languageCode?.identifier == "zh" ? "兼容结果暂时未知；原安装请求保留，不会自动重装。" : "Compatibility is unknown. The original installation request is retained, never automatically reinstalled.") }
                Button(locale.language.languageCode?.identifier == "zh" ? "读取当前兼容条件" : "Read current compatibility") {
                    Task { await controller.readCompatibility() }
                }.disabled(!controller.canReadCompatibility || controller.busy)
                Text(locale.language.languageCode?.identifier == "zh" ? "技术兼容不等于安装授权。原依赖权利、资源、额度与版本仍由原安装服务确认。" : "Technical compatibility is not installation authorization. Original dependency rights, resources, quota and version checks still apply.")
                    .font(Theme.Font.label).foregroundStyle(.secondary)
            }
            if controller.attempt == nil { selectionSection }
            if let attempt = controller.attempt {
                Section {
                    InstallationFact("request", attempt.request.requestId)
                    if let fact = originalFact, fact.requestID == attempt.request.requestId {
                        installationText("state." + fact.state)
                    }
                    if originalReader != nil {
                        if originalReadBusy { ProgressView() }
                        if originalReadUnknown { installationText("unknown").foregroundStyle(Theme.Generated.color("--cy-color-status-warning", in: domain) ?? .orange) }
                        Button(locale.language.languageCode?.identifier == "zh" ? "回读原安装请求" : "Read original installation request") {
                            Task { await readOriginalInstallFact() }
                        }.disabled(originalReadBusy || !controller.isCurrent || scenePhase != .active)
                    }
                    InstallationFact("merchant", attempt.merchantLabel)
                    InstallationFact("anchor", attempt.anchorLabel)
                    InstallationFact("region", attempt.region)
                    if attempt.pendingAction != nil { installationText("unknown").foregroundStyle(Theme.Generated.color("--cy-color-status-warning", in: domain) ?? .orange) }
                    if controller.canRetryOriginalPrepare {
                        Button { Task { await controller.retryOriginalPrepare() } } label: { installationText("retryOriginal") }
                    }
                    if let receipt = attempt.receipt {
                        InstallationReceiptFacts(receipt: receipt)
                        if controller.canConfirm {
                            Button { confirmation = receipt } label: { installationText("reviewInstall") }
                        }
                        if controller.canCancel {
                            Button(role: .destructive) { cancellation = receipt; showCancellation = true } label: { installationText("cancelRequest") }
                        }
                        if receipt.memberTemplateID != nil, controller.isCurrent {
                            ModInstalledTextReadEntry(makeReader: { controller.installedTextReader(receipt) })
                            Button { editing = controller.templateEditor(receipt) } label: { installationText("editDraft") }
                        }
                        if receipt.topicID != nil, controller.isCurrent {
                            Button { editingTopic = receipt } label: { installationText("editDraft") }
                        }
                        if controller.canStartAnother {
                            Button { Task { await controller.startAnother() } } label: { installationText("startAnother") }
                        }
                    }
                } header: { installationText("originalReceipt") }
            }
            if controller.receipt?.state == .installed {
                Section {
                    if let receipt = controller.receipt, receipt.topicID != nil, !receipt.bindings.isEmpty {
                        Button(locale.language.languageCode?.identifier == "zh" ? "场地同意、营业窗口与现场动态码" : "Venue consent, opening hours and on-site dynamic codes") { venue = controller.venueOperations(receipt) }.disabled(controller.busy || !controller.isCurrent)
                    }
                    if let facts = controller.facts {
                        installationText(facts.confirmed ? "facts.confirmed" : "facts.required")
                        InstallationFact("facts.draftHash", facts.draftContentHash)
                        Button { factReview = facts } label: { installationText("facts.review") }
                        if controller.receipt?.topicID != nil, facts.hasQaEditorCandidate {
                            Button { editingQa = controller.qaEditor() } label: { installationText("qaEdit.title") }.disabled(controller.busy || !controller.isCurrent)
                        }
                    }
                    if controller.attempt?.pendingFacts != nil { installationText("facts.unknown") }
                    Button { Task { await controller.refreshFacts() } } label: { installationText("facts.refresh") }
                        .disabled(controller.busy)
                    installationText("facts.boundary").font(Theme.Font.label).foregroundStyle(.secondary)
                } header: { installationText("facts.title") }
            }
            if !controller.history.isEmpty {
                Section {
                    ForEach(controller.history) { receipt in
                        VStack(alignment: .leading, spacing: 6) {
                            installationText("state." + receipt.state.rawValue)
                            Text(verbatim: receipt.requestId).font(Theme.Font.label).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: receipt.createdAt).font(Theme.Font.label).foregroundStyle(.secondary)
                            if controller.attempt == nil || controller.attempt?.request.requestId == receipt.requestId || (controller.receipt?.terminal == true && controller.attempt?.pendingFacts == nil) {
                                Button { Task { await controller.restore(receipt) } } label: { installationText("restoreReceipt") }
                                    .disabled(controller.busy || !controller.isCurrent)
                            }
                            if receipt.memberTemplateID != nil, controller.isCurrent {
                                ModInstalledTextReadEntry(makeReader: { controller.installedTextReader(receipt) })
                                Button { editing = controller.templateEditor(receipt) } label: { installationText("editDraft") }
                            }
                            if receipt.topicID != nil, controller.isCurrent {
                                Button { editingTopic = receipt } label: { installationText("editDraft") }
                            }
                        }
                    }
                } header: { installationText("history") }
            }
            Section {
                if controller.busy { ProgressView() }
                if controller.messageKey == "error.readCapacity" {
                    Text(locale.language.languageCode?.identifier == "zh" ?
                        "原选项或安装历史尚未完整读取，超过本次安全读取容量。不能据此认定没有在途请求或新建安装；原请求和回执保留，请重试原回查。" :
                        "The original options or history exceeded the safe read capacity and are incomplete. No absence of pending requests is assumed and no new installation is enabled. Original requests and receipts are retained.")
                        .foregroundStyle(.secondary)
                } else if controller.messageKey == "originalRecovered" {
                    Text(locale.language.languageCode?.identifier == "zh" ?
                        "已找到并恢复原在途安装请求；没有创建新请求。" : "An original pending installation was found and restored; no new request was created.")
                        .foregroundStyle(.secondary)
                } else if let key = controller.messageKey { installationText(key).foregroundStyle(.secondary) }
                Button { Task { await controller.recover() } } label: { installationText("recover") }.disabled(controller.busy)
                installationText("recoveryBoundary").font(Theme.Font.label).foregroundStyle(.secondary)
            }
        }
        .font(Theme.Font.body)
        .navigationTitle(installationString("title", locale: locale))
        .task { await controller.recover() }
        .task(id: originalInstallReadKey) { await readOriginalInstallFact() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                guard controller.isCurrent else { suspendOriginalInstallRead(); return }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            suspendOriginalInstallRead()
            if phase == .active {
                Task { await controller.recover(); await readOriginalInstallFact() }
            }
        }
        .onDisappear { suspendOriginalInstallRead() }
        .sheet(item: $editing, onDismiss: { Task { await controller.refreshFacts() } }) { editor in
            NavigationStack { ModInstallationTemplateEditorView(editor: editor) }
        }
        .sheet(item: $editingQa, onDismiss: { Task { await controller.refreshFacts() } }) { editor in
            NavigationStack { ModInstallationQaEditorView(editor: editor) }
        }
        .sheet(item: $venue) { model in NavigationStack { ModVenueOperationsView(model: model) } }
        .sheet(item: $editingTopic, onDismiss: { Task { await controller.refreshFacts() } }) { receipt in
            NavigationStack { ModInstallationTopicEditor(receipt: receipt, isCurrent: { controller.isCurrent }) }
        }
        .sheet(item: $confirmation) { receipt in
            ModInstallationConfirmation(receipt: receipt, preview: controller.preview, canConfirm: controller.canConfirm && controller.receipt == receipt) {
                confirmation = nil
                Task { await controller.confirmInstall(receipt) }
            }
        }
        .sheet(item: $factReview) { facts in
            ModInstallationFactReview(facts: facts, canConfirm: controller.canConfirmFacts && controller.facts == facts) {
                factReview = nil
                Task { await controller.confirmFacts(facts) }
            }
        }
        .confirmationDialog(installationString("cancelQuestion", locale: locale), isPresented: $showCancellation, titleVisibility: .visible) {
            Button(role: .destructive) {
                if let cancellation { Task { await controller.cancel(cancellation) } }
                cancellation = nil
            } label: { installationText("cancelRequest") }
            Button(role: .cancel) { cancellation = nil } label: { installationText("keepRequest") }
        } message: { installationText("cancelBoundary") }
    }
    /// A request ID is stable across PREPARED/installed/cancelled; it is not a permanent read cache key.
    private var originalInstallReadKey: String {
        [controller.attempt?.request.requestId ?? "", controller.receipt?.state.rawValue ?? "",
         controller.attempt?.pendingAction?.rawValue ?? ""].joined(separator: ":")
    }
    private func suspendOriginalInstallRead() {
        originalReadGeneration &+= 1
        originalReadBusy = false; originalReadUnknown = false; originalFact = nil
    }
    private func readOriginalInstallFact() async {
        suspendOriginalInstallRead()
        guard scenePhase == .active, controller.isCurrent,
              let requestID = controller.attempt?.request.requestId,
              let reader = originalReader else { return }
        guard let installIdentity = WorkshopInstallIdentity(
            licenseId: controller.identity.licenseId,
            moduleId: controller.identity.moduleId,
            releaseId: controller.identity.releaseId,
            contentHash: controller.identity.contentHash,
            termsHash: controller.identity.termsHash) else { return }
        let held = originalReadGeneration, readKey = originalInstallReadKey
        originalReadBusy = true
        defer { if held == originalReadGeneration { originalReadBusy = false } }
        do {
            let fact = try await reader.request(requestID, identity: installIdentity)
            guard held == originalReadGeneration, !Task.isCancelled, scenePhase == .active,
                  controller.isCurrent, originalInstallReadKey == readKey,
                  controller.attempt?.request.requestId == requestID else { return }
            guard fact.requestID == requestID else { throw WorkshopOriginalInstallError.unknown }
            originalFact = fact
        } catch {
            guard held == originalReadGeneration, !Task.isCancelled, scenePhase == .active,
                  controller.isCurrent, originalInstallReadKey == readKey else { return }
            // Unknown retains the original controller/journal. It can be read again, never reinstalled here.
            originalReadUnknown = true
        }
    }
    @ViewBuilder private var selectionSection: some View {
        Section {
            if let options = controller.options {
                if options.merchants.isEmpty { installationText("noMerchants") }
                Picker(selection: Binding(get: { controller.selectedMerchantId }, set: { value in
                    Task { await controller.selectMerchant(value) }
                })) {
                    installationText("choose").tag(Int64?.none)
                    ForEach(options.merchants) { item in Text(verbatim: item.label).tag(Optional(item.id)) }
                } label: { installationText("merchant") }.disabled(!controller.canSelect)
                if controller.selectedMerchantId != nil {
                    let anchors = options.resources.filter { $0.kind == .poi && $0.region != nil }
                    Picker(selection: Binding(get: { controller.selectedAnchorPoiId }, set: { controller.selectAnchor($0) })) {
                        installationText("choose").tag(Int64?.none)
                        ForEach(anchors) { item in
                            Text(verbatim: item.label + " · " + (item.region ?? "")).tag(Optional(item.id))
                        }
                    } label: { installationText("anchor") }.disabled(!controller.canSelect)
                    if anchors.isEmpty { installationText("noAnchor") }
                    if controller.selectedAnchorPoiId == nil { installationText("chooseAnchorFirst") }
                    ForEach(options.requiredBindings) { requirement in
                        let resources = controller.bindingResources(for: requirement)
                        Picker(selection: Binding(get: { controller.selections[requirement.id] }, set: { controller.select($0, for: requirement) })) {
                            installationText("choose").tag(Int64?.none)
                            ForEach(resources) { item in Text(verbatim: item.label).tag(Optional(item.id)) }
                        } label: {
                            VStack(alignment: .leading) {
                                installationText("kind." + requirement.kind.rawValue)
                                Text(verbatim: requirement.key).font(.caption)
                            }
                        }.disabled(!controller.canSelect || controller.selectedAnchorPoiId == nil)
                        if controller.selectedAnchorPoiId != nil, resources.isEmpty { installationText("missingResource") }
                    }
                    if options.requiredBindings.isEmpty { installationText("noPlaceholders") }
                }
                Button { Task { await controller.prepare() } } label: { installationText("prepare") }
                    .disabled(!controller.canPrepare)
            } else { installationText("loadingOptions") }
        } header: { installationText("bindings") } footer: { installationText("bindingsBoundary") }
    }
}

@MainActor private struct ModInstallationConfirmation: View {
    let receipt: ModInstallationReceipt
    let preview: ModInstallationPreview?
    let canConfirm: Bool
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InstallationFact("request", receipt.requestId)
                    InstallationFact("license", receipt.licenseId)
                    InstallationFact("merchant", String(receipt.merchantId))
                    InstallationFact("anchor", String(receipt.anchorPoiId))
                    InstallationFact("release", receipt.releaseId)
                    InstallationFact("contentHash", receipt.contentHash)
                    InstallationFact("termsHash", receipt.termsHash)
                    InstallationReceiptFacts(receipt: receipt)
                }
                if let preview {
                    Section {
                        ForEach(preview.fields.keys.filter { $0 != "advancedConfigJson" && $0 != "qmodTopicGraphJson" && $0 != "compositionReceiptJson" }.sorted(), id: \.self) { field in
                            VStack(alignment: .leading) {
                                installationText("field." + field).font(Theme.Font.label).foregroundStyle(.secondary)
                                Text(verbatim: preview.fields[field] ?? "").textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let json = preview.fields["advancedConfigJson"], let graph = try? ModInstallationNativeGraph(json: json) {
                            InstallationNativeGraphContent(graph: graph)
                        }
                        if let json = preview.fields["qmodTopicGraphJson"], let graph = try? ModInstallationTopicGraph(json: json) {
                            InstallationTopicGraphContent(graph: graph)
                        }
                    } header: { installationText("previewContent") }
                }
                Section {
                    installationText("confirmBoundary")
                    Button(action: confirm) { installationText("confirmInstall") }.disabled(!canConfirm)
                }
            }
            .font(Theme.Font.body)
            .navigationTitle(installationString("reviewInstall", locale: locale))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { installationText("back") } } }
        }
    }
}

@MainActor private struct ModInstallationFactReview: View {
    let facts: ModInstallationFacts
    let canConfirm: Bool
    let confirm: () -> Void
    @State private var readFacts = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InstallationFact("request", facts.requestId)
                    InstallationFact("draft", String(facts.draftId))
                    InstallationFact("merchant", String(facts.merchantId))
                    InstallationFact("facts.draftHash", facts.draftContentHash)
                    InstallationFact("bindingHash", facts.bindingHash)
                }
                Section {
                    Text(verbatim: facts.title).font(Theme.Font.sectionTitle).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: facts.rules).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if let json = facts.advancedConfigJson, !json.isEmpty {
                        if let graph = try? ModInstallationNativeGraph(json: json) {
                            InstallationNativeGraphContent(graph: graph)
                        } else {
                            // The owner may have added other supported native mechanisms in the real editor.
                            // Never hide them behind a partial graph preview during fact confirmation.
                            installationText("graph.currentConfiguration")
                            Text(verbatim: json).font(Theme.Font.label.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: { installationText("facts.currentContent") }
                Section {
                    ForEach(facts.bindings) { binding in
                        VStack(alignment: .leading) {
                            installationText("kind." + binding.kind.rawValue)
                            Text(verbatim: binding.key + ": " + binding.label)
                            Text(verbatim: String(binding.resourceId)).font(Theme.Font.label)
                            Text(verbatim: binding.fingerprint).font(Theme.Font.label).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: { installationText("bindings") }
                Section {
                    installationText("facts.boundary")
                    if facts.confirmed { installationText("facts.confirmed") }
                    else {
                        Toggle(isOn: $readFacts) { installationText("facts.readConfirmation") }
                        Button(action: confirm) { installationText("facts.confirm") }.disabled(!readFacts || !canConfirm)
                    }
                }
            }
            .font(Theme.Font.body)
            .navigationTitle(installationString("facts.title", locale: locale))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { installationText("back") } } }
        }
    }
}

private struct InstallationReceiptFacts: View {
    let receipt: ModInstallationReceipt
    var body: some View {
        installationText("state." + receipt.state.rawValue).font(Theme.Font.sectionTitle).fixedSize(horizontal: false, vertical: true)
        InstallationFact("region", receipt.region)
        InstallationFact("bindingHash", receipt.bindingHash)
        if let id = receipt.draftId { InstallationFact("draft", String(id)) }
        if let error = receipt.errorCode { InstallationFact("serverError", error) }
        if let composition = receipt.composition { ModCompositionInstallationReceiptView(value: composition) }
        ForEach(receipt.bindings) { binding in
            VStack(alignment: .leading, spacing: 4) {
                installationText("kind." + binding.kind.rawValue).font(Theme.Font.label)
                Text(verbatim: binding.key + ": " + binding.label)
                Text(verbatim: String(binding.resourceId)).font(Theme.Font.label)
                Text(verbatim: binding.fingerprint).font(Theme.Font.label).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
        ForEach(receipt.requiredGates, id: \.self) { installationText("gate." + $0).font(Theme.Font.label).foregroundStyle(.secondary) }
    }
}
private struct InstallationNativeGraphContent: View {
    let graph: ModInstallationNativeGraph
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            installationText("graph.title").font(Theme.Font.sectionTitle)
            InstallationFact("graph.start", graph.startStepId)
            ForEach(graph.steps) { step in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: step.id + " · " + step.title).font(Theme.Font.sectionTitle)
                    Text(verbatim: step.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if step.terminal {
                        InstallationFact("graph.end", (step.outcomeCode ?? "") + " · " + (step.outcomeLabel ?? ""))
                    }
                    ForEach(step.options) { option in
                        Text(verbatim: option.id + " · " + option.label + " → " + option.nextStepId).font(Theme.Font.label).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            installationText("graph.boundary").font(Theme.Font.label).foregroundStyle(.secondary)
        }
    }
}
private struct InstallationFact: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            installationText(key).font(Theme.Font.label).foregroundStyle(.secondary)
            Text(verbatim: value).font(Theme.Font.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
private func installationText(_ key: String) -> Text { Text(LocalizedStringKey("modInstallation." + key), tableName: "ModInstallation") }
private func installationString(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "modInstallation." + key), table: "ModInstallation", locale: locale))
}

/// Always reachable from an owned frozen license, including revoked/suspended licenses.
/// Navigation does not revive installation, editing, runtime, quota or release authority.
@MainActor struct ModInstallationOriginalRecoveryLink: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    var body: some View {
        NavigationLink {
            ModInstallationOriginalRecoveryEntry(reference: reference, makeController: makeController)
        } label: { installationText("originalRecovery.open") }.accessibilityIdentifier("modInstallation.originalRecovery." + reference.licenseId)
    }
}
@MainActor private struct ModInstallationOriginalRecoveryEntry: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var phase
    @Environment(\.locale) private var locale
    @State private var controller: ModInstallationController?
    var body: some View {
        Group {
            if phase == .active, let controller, controller.isCurrent {
                ModInstallationOriginalRecoveryView(controller: controller).id(ObjectIdentifier(controller))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        installationText("originalRecovery.unavailable").fixedSize(horizontal: false, vertical: true)
                        Button { reopen() } label: { installationText("originalRecovery.reopen") }
                            .disabled(phase != .active)
                    }.padding()
                }
            }
        }
        .navigationTitle(installationString("originalRecovery.title", locale: locale))
        .privacySensitive()
        .onAppear { if controller?.isCurrent != true { reopen() } }
        .onChange(of: session.sessionRevision) { _, _ in reopen() }
        .onChange(of: session.account?.id) { _, _ in reopen() }
        .onChange(of: session.account?.effectiveRole) { _, _ in reopen() }
        .onChange(of: phase) { _, value in if value == .active { reopen() } else { retire() } }
        .onDisappear { retire() }
    }
    private func retire() { controller?.invalidate(); controller = nil }
    private func reopen() { retire(); guard phase == .active else { return }; controller = makeController(reference) }
}
@MainActor private struct ModInstallationOriginalRecoveryView: View {
    @State var controller: ModInstallationController
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @State private var hasRead = false
    var body: some View {
        Form {
            if controller.busy || !hasRead {
                Section {
                    ProgressView { installationText("originalRecovery.loading") }
                        .accessibilityIdentifier("modInstallationOriginalRecovery.loading")
                }
            }
            Section {
                InstallationFact("license", controller.identity.licenseId)
                InstallationFact("module", controller.identity.moduleId)
                InstallationFact("release", controller.identity.releaseId)
                installationText("originalRecovery.boundary").font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } header: { installationText("originalRecovery.identitySection") }
            Section {
                if let request = controller.originalRecoveryRequestID {
                    Text(verbatim: request).font(Theme.Font.label).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if let saved = controller.originalRecoverySavedReceipt {
                        installationText("originalRecovery.savedReceipt").font(Theme.Font.sectionTitle).fixedSize(horizontal: false, vertical: true)
                        ModInstallationOriginalReceiptSummary(receipt: saved)
                    }
                } else if ModInstallationOriginalRecoveryPresentation.showsNoLocalRequest(hasRead: hasRead, busy: controller.busy,
                                                                                          requestID: controller.originalRecoveryRequestID,
                                                                                          storageUnavailable: controller.originalRecoveryStorageUnavailable) {
                    installationText("originalRecovery.noLocalRequest").fixedSize(horizontal: false, vertical: true)
                }
                if controller.originalRecoveryStorageUnavailable { installationText("originalRecovery.storageUnavailable").fixedSize(horizontal: false, vertical: true) }
                if controller.originalRecoveryRequestUnknown { installationText("originalRecovery.requestUnknown").fixedSize(horizontal: false, vertical: true) }
            } header: { installationText("originalRecovery.localSection") }
            if let receipt = controller.originalRecoveryReceipt {
                Section {
                    ModInstallationOriginalReceiptSummary(receipt: receipt)
                    installationText("originalRecovery.resultBoundary").font(Theme.Font.label).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if receipt.memberTemplateID != nil {
                        ModInstalledTextReadEntry(makeReader: { controller.installedTextReader(receipt) })
                    }
                } header: { installationText("originalRecovery.resultSection") }
            }
            Section {
                ForEach(controller.originalRecoveryHistory) { receipt in
                    VStack(alignment: .leading) {
                        ModInstallationOriginalReceiptSummary(receipt: receipt)
                        Button { Task { await readHistory(receipt) } } label: { installationText("originalRecovery.readRequest") }
                            .disabled(controller.busy || !controller.isCurrent || phase != .active)
                    }
                }
                if ModInstallationOriginalRecoveryPresentation.showsEmptyHistory(hasRead: controller.originalRecoveryHistoryRead,
                                                                                 busy: controller.busy, count: controller.originalRecoveryHistory.count,
                                                                                 unknown: controller.originalRecoveryHistoryUnknown) {
                    installationText("originalRecovery.emptyHistory").fixedSize(horizontal: false, vertical: true)
                }
                if controller.originalRecoveryHistoryUnknown { installationText("originalRecovery.historyUnknown").fixedSize(horizontal: false, vertical: true) }
            } header: { installationText("originalRecovery.historySection") }
            Section {
                Button { Task { await refresh() } } label: { installationText("originalRecovery.refresh") }
                    .disabled(controller.busy || !controller.isCurrent || phase != .active)
            }
        }
        .font(Theme.Font.body)
        .navigationTitle(installationString("originalRecovery.title", locale: locale)).privacySensitive()
        .task { await refresh() }
    }
    private func refresh() async {
        guard phase == .active, controller.isCurrent, !Task.isCancelled else { return }
        await controller.recoverOriginalReceipts()
        guard phase == .active, controller.isCurrent, !Task.isCancelled else { return }
        hasRead = true
    }
    private func readHistory(_ receipt: ModInstallationReceipt) async {
        guard phase == .active, controller.isCurrent, !Task.isCancelled else { return }
        await controller.readOriginalHistoryReceipt(receipt)
    }
}

/// Derived visibility only; never interprets missing local/history facts as a transaction result.
enum ModInstallationOriginalRecoveryPresentation {
    static func showsNoLocalRequest(hasRead: Bool, busy: Bool, requestID: String?, storageUnavailable: Bool) -> Bool {
        hasRead && !busy && requestID == nil && !storageUnavailable
    }
    static func showsEmptyHistory(hasRead: Bool, busy: Bool, count: Int, unknown: Bool) -> Bool {
        hasRead && !busy && count == 0 && !unknown
    }
}

/// Original receipt summary shared by install and upgrade recovery, never an executable destination.
struct ModInstallationOriginalReceiptSummary: View {
    let receipt: ModInstallationReceipt
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InstallationFact("request", receipt.requestId)
            InstallationFact("license", receipt.licenseId)
            InstallationFact("release", receipt.releaseId)
            InstallationFact("contentHash", receipt.contentHash)
            InstallationFact("termsHash", receipt.termsHash)
            InstallationReceiptFacts(receipt: receipt)
        }
    }
}
