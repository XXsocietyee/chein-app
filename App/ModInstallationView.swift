import SwiftUI

/// Owned-license entry only. Commerce owns the license; this feature owns real resource binding and installation.
@MainActor struct ModInstallationLicenseLink: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationLink {
            ModInstallationEntry(reference: reference, makeController: makeController, makeOriginalReader: makeOriginalReader, makeInstallationPair: makeInstallationPair)
        } label: {
            CYListRow(verbatim: installationString("open", locale: locale), trailing: .none) {
                CYRowIcon(systemImage: "square.and.arrow.down")
            }
        }
        .accessibilityLabel(installationText("open"))
    }
}

@MainActor struct ModInstallationEntry: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    var makeOriginalReader: (ModInstallationIdentity) -> H5OriginalInstallReader? = { _ in nil }
    var makeInstallationPair: ((ModInstallationIdentity) -> (controller: ModInstallationController?, originalReader: H5OriginalInstallReader?)?)? = nil
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    @State private var controller: ModInstallationController?
    @State private var originalReader: H5OriginalInstallReader?
    var body: some View {
        Group {
            if let controller, controller.isCurrent {
                ModInstallationView(controller: controller, originalReader: originalReader).id(ObjectIdentifier(controller))
            } else {
                Cloud25Screen(title: installationString("title", locale: locale), seed: reference.moduleId, symbol: "shippingbox.fill") {
                    CYEmptyState(systemImage: "lock.slash", "modInstallation.unavailable", tableName: "ModInstallation")
                    Cloud25Pill(title: installationString("reload", locale: locale), key: "reload", primary: true) { reopen() }
                }
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

    private enum Forward { case prepare, review, facts, recover }
    private var forward: Forward {
        if controller.attempt == nil, controller.options != nil { return .prepare }
        if controller.canConfirm { return .review }
        if controller.receipt?.state == .installed, let facts = controller.facts, !facts.confirmed { return .facts }
        return .recover
    }

    var body: some View {
        Cloud25Screen(title: installationString("title", locale: locale), seed: controller.identity.moduleId, symbol: "shippingbox.fill") {
            identityCard
            compatibilityCard
            if controller.attempt == nil { selectionCard }
            if let attempt = controller.attempt { attemptCard(attempt) }
            if controller.receipt?.state == .installed { factsCard }
            if !controller.history.isEmpty { historyCard }
            messageCard
        }
        .cyAnimation(value: controller.busy)
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
            Group {
                NavigationStack { ModInstallationTemplateEditorView(editor: editor) }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $editingQa, onDismiss: { Task { await controller.refreshFacts() } }) { editor in
            Group {
                NavigationStack { ModInstallationQaEditorView(editor: editor) }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $venue) { model in Group { NavigationStack { ModVenueOperationsView(model: model) } }.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(item: $editingTopic, onDismiss: { Task { await controller.refreshFacts() } }) { receipt in
            Group {
                NavigationStack { ModInstallationTopicEditor(receipt: receipt, isCurrent: { controller.isCurrent }) }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $confirmation) { receipt in
            Group {
                ModInstallationConfirmation(receipt: receipt, preview: controller.preview, canConfirm: controller.canConfirm && controller.receipt == receipt) {
                    confirmation = nil
                    Task { await controller.confirmInstall(receipt) }
                }
            }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(item: $factReview) { facts in
            Group {
                ModInstallationFactReview(facts: facts, canConfirm: controller.canConfirmFacts && controller.facts == facts) {
                    factReview = nil
                    Task { await controller.confirmFacts(facts) }
                }
            }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .confirmationDialog(installationString("cancelQuestion", locale: locale), isPresented: $showCancellation, titleVisibility: .visible) {
            Button(role: .destructive) {
                if let cancellation { Task { await controller.cancel(cancellation) } }
                cancellation = nil
            } label: { installationText("cancelRequest") }
            Button(role: .cancel) { cancellation = nil } label: { installationText("keepRequest") }
        } message: { installationText("cancelBoundary") }
    }

    private var identityCard: some View {
        let rawTitle = controller.options?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let shown = rawTitle.isEmpty ? Cloud25Copy.value(controller.identity.moduleId) : rawTitle
        return VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYImageCard(verbatim: shown, fallback: LocalizedStringKey(stringLiteral: "—"), meta: Cloud25Copy.value(controller.identity.releaseId))
                .accessibilityLabel(installationText("authorizedVersion") + Text(verbatim: " " + shown))
            CYInfoCard {
                Cloud25Header(title: installationString("authorizedVersion", locale: locale))
                InstallationFact("license", controller.identity.licenseId)
                InstallationFact("module", controller.identity.moduleId)
                InstallationFact("release", controller.identity.releaseId)
                InstallationFact("contentHash", controller.identity.contentHash)
                InstallationFact("termsHash", controller.identity.termsHash)
                installNote("boundary")
            }
        }
    }

    private var compatibilityCard: some View {
        CYInfoCard {
            if let value = controller.compatibility {
                CYStatusChip(verbatim: Cloud25Copy.value(value.reasonCode), tone: .info, systemImage: "checkmark.shield")
                    .accessibilityLabel(Text(verbatim: Cloud25Copy.value(value.reasonCode)))
                Text(verbatim: phrase(
                    "客户端 \(value.clientVersion)，最低版本 \(value.minimumClientVersion)；运行时 \(value.runtimeVersion)",
                    "Client \(value.clientVersion), minimum \(value.minimumClientVersion); runtime \(value.runtimeVersion)"))
                    .cyText(.body).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if controller.compatibilityReadFailed {
                CYErrorState(
                    LocalizedStringKey(stringLiteral: phrase(
                        "兼容结果暂时未知；原安装请求保留，不会自动重装。",
                        "Compatibility is unknown. The original installation request is retained, never automatically reinstalled.")),
                    retryTitle: LocalizedStringKey(stringLiteral: phrase("读取当前兼容条件", "Read current compatibility")),
                    onRetry: { Task { await controller.readCompatibility() } }
                )
                .disabled(!controller.canReadCompatibility || controller.busy)
            } else {
                Cloud25Pill(title: phrase("读取当前兼容条件", "Read current compatibility"), primary: false, enabled: controller.canReadCompatibility && !controller.busy) {
                    Task { await controller.readCompatibility() }
                }
            }
            installPlain(phrase(
                "技术兼容不等于安装授权。原依赖权利、资源、额度与版本仍由原安装服务确认。",
                "Technical compatibility is not installation authorization. Original dependency rights, resources, quota and version checks still apply."))
        }
    }

    @ViewBuilder private var selectionCard: some View {
        CYInfoCard {
            Cloud25Header(title: installationString("bindings", locale: locale))
            if let options = controller.options {
                if options.merchants.isEmpty {
                    CYEmptyState(systemImage: "building.2", "modInstallation.noMerchants", tableName: "ModInstallation")
                }
                merchantPicker(options)
                if controller.selectedMerchantId != nil { anchorAndBindings(options) }
                Cloud25Pill(title: installationString("prepare", locale: locale), key: "prepare", primary: forward == .prepare, systemImage: "arrow.down.circle", enabled: controller.canPrepare) {
                    Task { await controller.prepare() }
                }
            } else {
                CYSkeleton().accessibilityLabel(installationText("loadingOptions"))
                installNote("loadingOptions")
            }
            installNote("bindingsBoundary")
        }
    }

    private func merchantPicker(_ options: ModInstallationOptions) -> some View {
        Picker(selection: Binding(get: { controller.selectedMerchantId }, set: { value in
            Task { await controller.selectMerchant(value) }
        })) {
            installationText("choose").tag(Int64?.none)
            ForEach(options.merchants) { item in Text(verbatim: item.label).tag(Optional(item.id)) }
        } label: { installationText("merchant") }
        .disabled(!controller.canSelect)
        .frame(minHeight: CYSpacing.minTouchTarget)
    }

    @ViewBuilder private func anchorAndBindings(_ options: ModInstallationOptions) -> some View {
        let anchors = options.resources.filter { $0.kind == .poi && $0.region != nil }
        Picker(selection: Binding(get: { controller.selectedAnchorPoiId }, set: { controller.selectAnchor($0) })) {
            installationText("choose").tag(Int64?.none)
            ForEach(anchors) { item in
                Text(verbatim: item.label + " · " + (item.region ?? "")).tag(Optional(item.id))
            }
        } label: { installationText("anchor") }
        .disabled(!controller.canSelect)
        .frame(minHeight: CYSpacing.minTouchTarget)
        if anchors.isEmpty { CYNoteBanner(text: installationText("noAnchor"), symbol: "mappin.slash", tone: .warning) }
        if controller.selectedAnchorPoiId == nil { installNote("chooseAnchorFirst") }
        ForEach(options.requiredBindings) { requirement in
            let resources = controller.bindingResources(for: requirement)
            Picker(selection: Binding(get: { controller.selections[requirement.id] }, set: { controller.select($0, for: requirement) })) {
                installationText("choose").tag(Int64?.none)
                ForEach(resources) { item in Text(verbatim: item.label).tag(Optional(item.id)) }
            } label: {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    installationText("kind." + requirement.kind.rawValue)
                    Text(verbatim: requirement.key).cyText(.meta).monospaced().foregroundStyle(CYColor.textTertiary)
                }
            }
            .disabled(!controller.canSelect || controller.selectedAnchorPoiId == nil)
            .frame(minHeight: CYSpacing.minTouchTarget)
            if controller.selectedAnchorPoiId != nil, resources.isEmpty {
                CYNoteBanner(text: installationText("missingResource"), symbol: "exclamationmark.triangle", tone: .warning)
            }
        }
        if options.requiredBindings.isEmpty { installNote("noPlaceholders") }
    }

    private func attemptCard(_ attempt: ModInstallationAttempt) -> some View {
        CYInfoCard {
            Cloud25Header(title: installationString("originalReceipt", locale: locale))
            InstallationFact("request", attempt.request.requestId)
            if let fact = originalFact, fact.requestID == attempt.request.requestId {
                CYStatusChip(verbatim: catalogState(fact.state), tone: .info, systemImage: "arrow.clockwise")
                    .accessibilityLabel(installationText("state." + fact.state))
            }
            if originalReader != nil {
                if originalReadBusy { CYSkeleton().accessibilityLabel(Text("cy.state.loading")) }
                if originalReadUnknown {
                    CYNoteBanner(text: installationText("unknown"), symbol: "questionmark.circle", tone: .warning)
                }
                Cloud25Pill(title: phrase("回读原安装请求", "Read original installation request"), primary: false, enabled: !originalReadBusy && controller.isCurrent && scenePhase == .active) {
                    Task { await readOriginalInstallFact() }
                }
            }
            InstallationFact("merchant", attempt.merchantLabel)
            InstallationFact("anchor", attempt.anchorLabel)
            InstallationFact("region", attempt.region)
            if attempt.pendingAction != nil {
                CYNoteBanner(text: installationText("unknown"), symbol: "questionmark.circle", tone: .warning)
            }
            if controller.canRetryOriginalPrepare {
                Cloud25Pill(title: installationString("retryOriginal", locale: locale), key: "retryOriginal", primary: false) {
                    Task { await controller.retryOriginalPrepare() }
                }
            }
            if let receipt = attempt.receipt {
                InstallationReceiptFacts(receipt: receipt)
                if controller.canConfirm {
                    Cloud25Pill(title: installationString("reviewInstall", locale: locale), key: "reviewInstall", primary: forward == .review, systemImage: "checkmark.circle") {
                        confirmation = receipt
                    }
                }
                if controller.canCancel { cancelControl(receipt) }
                draftActions(receipt)
                if controller.canStartAnother {
                    Cloud25Pill(title: installationString("startAnother", locale: locale), key: "startAnother", primary: false) {
                        Task { await controller.startAnother() }
                    }
                }
            }
        }
    }

    @ViewBuilder private var factsCard: some View {
        CYInfoCard {
            Cloud25Header(title: installationString("facts.title", locale: locale))
            if let receipt = controller.receipt, receipt.topicID != nil, !receipt.bindings.isEmpty {
                Cloud25Pill(title: phrase("场地同意、营业窗口与现场动态码", "Venue consent, opening hours and on-site dynamic codes"), primary: false, enabled: !controller.busy && controller.isCurrent) {
                    venue = controller.venueOperations(receipt)
                }
            }
            if let facts = controller.facts {
                installNote(facts.confirmed ? "facts.confirmed" : "facts.required")
                InstallationFact("facts.draftHash", facts.draftContentHash)
                Cloud25Pill(title: installationString("facts.review", locale: locale), key: "facts.review", primary: forward == .facts, systemImage: "checklist") {
                    factReview = facts
                }
                if controller.receipt?.topicID != nil, facts.hasQaEditorCandidate {
                    Cloud25Pill(title: installationString("qaEdit.title", locale: locale), key: "qaEdit.title", primary: false, enabled: !controller.busy && controller.isCurrent) {
                        editingQa = controller.qaEditor()
                    }
                }
            }
            if controller.attempt?.pendingFacts != nil {
                CYNoteBanner(text: installationText("facts.unknown"), symbol: "questionmark.circle", tone: .warning)
            }
            Cloud25Pill(title: installationString("facts.refresh", locale: locale), key: "facts.refresh", primary: false, enabled: !controller.busy) {
                Task { await controller.refreshFacts() }
            }
            installNote("facts.boundary")
        }
    }

    private var historyCard: some View {
        CYInfoCard {
            Cloud25Header(title: installationString("history", locale: locale))
            ForEach(controller.history) { receipt in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYStatusChip(verbatim: catalogState(receipt.state.rawValue), tone: receiptTone(receipt.state), systemImage: receiptSymbol(receipt.state))
                        .accessibilityLabel(installationText("state." + receipt.state.rawValue))
                    CYListRow(verbatim: Cloud25Copy.value(receipt.requestId), meta: receipt.createdAt.isEmpty ? nil : receipt.createdAt, trailing: .none) {
                        CYRowIcon(systemImage: "doc.text")
                    }
                    if controller.attempt == nil || controller.attempt?.request.requestId == receipt.requestId || (controller.receipt?.terminal == true && controller.attempt?.pendingFacts == nil) {
                        Cloud25Pill(title: installationString("restoreReceipt", locale: locale), key: "restoreReceipt", primary: false, enabled: !controller.busy && controller.isCurrent) {
                            Task { await controller.restore(receipt) }
                        }
                    }
                    draftActions(receipt)
                }
            }
        }
    }

    private var messageCard: some View {
        CYInfoCard {
            if controller.busy { CYSkeleton().accessibilityLabel(Text("cy.state.loading")) }
            if controller.messageKey == "error.readCapacity" {
                CYNoteBanner(text: Text(verbatim: phrase(
                    "原选项或安装历史尚未完整读取，超过本次安全读取容量。不能据此认定没有在途请求或新建安装；原请求和回执保留，请重试原回查。",
                    "The original options or history exceeded the safe read capacity and are incomplete. No absence of pending requests is assumed and no new installation is enabled. Original requests and receipts are retained.")),
                    symbol: "exclamationmark.triangle", tone: .warning)
            } else if controller.messageKey == "originalRecovered" {
                CYNoteBanner(text: Text(verbatim: phrase(
                    "已找到并恢复原在途安装请求；没有创建新请求。",
                    "An original pending installation was found and restored; no new request was created.")),
                    symbol: "arrow.uturn.backward", tone: .info)
            } else if let key = controller.messageKey {
                CYNoteBanner(text: installationText(key), symbol: "info.circle", tone: .info)
            }
            Cloud25Pill(title: installationString("recover", locale: locale), key: "recover", primary: forward == .recover, systemImage: "arrow.clockwise", enabled: !controller.busy) {
                Task { await controller.recover() }
            }
            installNote("recoveryBoundary")
        }
    }

    @ViewBuilder private func draftActions(_ receipt: ModInstallationReceipt) -> some View {
        if receipt.memberTemplateID != nil, controller.isCurrent {
            ModInstalledTextReadEntry(makeReader: { controller.installedTextReader(receipt) })
            Cloud25Pill(title: installationString("editDraft", locale: locale), key: "editDraft", primary: false) {
                editing = controller.templateEditor(receipt)
            }
        }
        if receipt.topicID != nil, controller.isCurrent {
            Cloud25Pill(title: installationString("editDraft", locale: locale), key: "editDraft", primary: false) {
                editingTopic = receipt
            }
        }
    }

    private func cancelControl(_ receipt: ModInstallationReceipt) -> some View {
        Button(role: .destructive) {
            cancellation = receipt
            showCancellation = true
        } label: {
            installationText("cancelRequest")
                .cyText(.bodyMedium)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(installationText("cancelRequest"))
    }

    private func phrase(_ zh: String, _ en: String) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }
    private func catalogState(_ raw: String) -> String {
        let resolved = installationString("state." + raw, locale: locale)
        return resolved == "modInstallation.state." + raw ? Cloud25Copy.value(raw) : resolved
    }
    private func installNote(_ key: String) -> some View {
        installationText(key).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
    }
    private func installPlain(_ text: String) -> some View {
        Text(verbatim: text).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
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
            Cloud25Screen(title: installationString("reviewInstall", locale: locale), seed: receipt.requestId, symbol: "checkmark.seal") {
                CYInfoCard {
                    InstallationFact("request", receipt.requestId)
                    InstallationFact("license", receipt.licenseId)
                    InstallationFact("merchant", String(receipt.merchantId))
                    InstallationFact("anchor", String(receipt.anchorPoiId))
                    InstallationFact("release", receipt.releaseId)
                    InstallationFact("contentHash", receipt.contentHash)
                    InstallationFact("termsHash", receipt.termsHash)
                    InstallationReceiptFacts(receipt: receipt)
                }
                if let preview { previewCard(preview) }
                CYInfoCard {
                    installationText("confirmBoundary").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Cloud25Pill(title: installationString("confirmInstall", locale: locale), key: "confirmInstall", primary: true, systemImage: "checkmark", enabled: canConfirm, action: confirm)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { installationText("back") } } }
        }
    }
    private func previewCard(_ preview: ModInstallationPreview) -> some View {
        CYInfoCard {
            Cloud25Header(title: installationString("previewContent", locale: locale))
            ForEach(preview.fields.keys.filter { $0 != "advancedConfigJson" && $0 != "qmodTopicGraphJson" && $0 != "compositionReceiptJson" }.sorted(), id: \.self) { field in
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    installationText("field." + field).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    Text(verbatim: preview.fields[field] ?? "").textSelection(.enabled).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let json = preview.fields["advancedConfigJson"], let graph = try? ModInstallationNativeGraph(json: json) {
                InstallationNativeGraphContent(graph: graph)
            }
            if let json = preview.fields["qmodTopicGraphJson"], let graph = try? ModInstallationTopicGraph(json: json) {
                InstallationTopicGraphContent(graph: graph)
            }
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
            Cloud25Screen(title: installationString("facts.title", locale: locale), seed: facts.requestId, symbol: "checklist") {
                CYInfoCard {
                    InstallationFact("request", facts.requestId)
                    InstallationFact("draft", String(facts.draftId))
                    InstallationFact("merchant", String(facts.merchantId))
                    InstallationFact("facts.draftHash", facts.draftContentHash)
                    InstallationFact("bindingHash", facts.bindingHash)
                }
                CYInfoCard {
                    Cloud25Header(title: installationString("facts.currentContent", locale: locale))
                    Text(verbatim: facts.title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: facts.rules).cyText(.body).foregroundStyle(CYColor.textPrimary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if let json = facts.advancedConfigJson, !json.isEmpty {
                        if let graph = try? ModInstallationNativeGraph(json: json) {
                            InstallationNativeGraphContent(graph: graph)
                        } else {
                            installationText("graph.currentConfiguration").cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: json).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                CYInfoCard {
                    Cloud25Header(title: installationString("bindings", locale: locale))
                    ForEach(facts.bindings) { binding in
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            installationText("kind." + binding.kind.rawValue).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            Text(verbatim: binding.key + ": " + binding.label).cyText(.body).fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: String(binding.resourceId)).cyText(.numericBody)
                            Text(verbatim: binding.fingerprint).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                CYInfoCard {
                    installationText("facts.boundary").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if facts.confirmed {
                        CYStatusChip(verbatim: installationString("facts.confirmed", locale: locale), tone: .success, systemImage: "checkmark")
                            .accessibilityLabel(installationText("facts.confirmed"))
                    } else {
                        Toggle(isOn: $readFacts) { installationText("facts.readConfirmation") }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                        Cloud25Pill(title: installationString("facts.confirm", locale: locale), key: "facts.confirm", primary: true, enabled: readFacts && canConfirm, action: confirm)
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { installationText("back") } } }
        }
    }
}

private struct InstallationReceiptFacts: View {
    let receipt: ModInstallationReceipt
    @Environment(\.locale) private var locale
    var body: some View {
        CYStatusChip(verbatim: stateLabel, tone: receiptTone(receipt.state), systemImage: receiptSymbol(receipt.state))
            .accessibilityLabel(installationText("state." + receipt.state.rawValue))
        InstallationFact("region", receipt.region)
        InstallationFact("bindingHash", receipt.bindingHash)
        if let id = receipt.draftId { InstallationFact("draft", String(id)) }
        if let error = receipt.errorCode { InstallationFact("serverError", error) }
        if let composition = receipt.composition { ModCompositionInstallationReceiptView(value: composition) }
        ForEach(receipt.bindings) { binding in
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                installationText("kind." + binding.kind.rawValue).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: binding.key + ": " + binding.label).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                Text(verbatim: String(binding.resourceId)).cyText(.numericBody).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: binding.fingerprint).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
        ForEach(receipt.requiredGates, id: \.self) { gate in
            installationText("gate." + gate).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var stateLabel: String {
        let resolved = installationString("state." + receipt.state.rawValue, locale: locale)
        return resolved == "modInstallation.state." + receipt.state.rawValue ? receipt.state.rawValue : resolved
    }
}

private struct InstallationNativeGraphContent: View {
    let graph: ModInstallationNativeGraph
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Cloud25Header(title: installationString("graph.title", locale: locale))
            InstallationFact("graph.start", graph.startStepId)
            ForEach(graph.steps) { step in
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(verbatim: step.id + " · " + step.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: step.body).cyText(.body).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if step.terminal {
                        InstallationFact("graph.end", Cloud25Copy.joined(step.outcomeCode, step.outcomeLabel))
                    }
                    ForEach(step.options) { option in
                        Text(verbatim: option.id + " · " + option.label + " → " + option.nextStepId).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            installationText("graph.boundary").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InstallationFact: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        CYFactRow(label: installationText(key), value: Cloud25Copy.value(value))
    }
}

func installationText(_ key: String) -> Text { Text(LocalizedStringKey("modInstallation." + key), tableName: "ModInstallation") }
func installationString(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "modInstallation." + key), table: "ModInstallation", locale: locale))
}
private func receiptTone(_ state: ModInstallationReceipt.State) -> CYStatusTone {
    switch state {
    case .installed: return .success
    case .prepared: return .info
    case .failed: return .danger
    case .cancelled: return .warning
    }
}
private func receiptSymbol(_ state: ModInstallationReceipt.State) -> String {
    switch state {
    case .installed: return "checkmark.seal"
    case .prepared: return "clock"
    case .failed: return "exclamationmark.triangle"
    case .cancelled: return "xmark.circle"
    }
}

/// Always reachable from an owned frozen license, including revoked/suspended licenses.
/// Navigation does not revive installation, editing, runtime, quota or release authority.
@MainActor struct ModInstallationOriginalRecoveryLink: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModInstallationController?
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationLink {
            ModInstallationOriginalRecoveryEntry(reference: reference, makeController: makeController)
        } label: {
            CYListRow(verbatim: installationString("originalRecovery.open", locale: locale), trailing: .none) {
                CYRowIcon(systemImage: "arrow.counterclockwise")
            }
        }
        .accessibilityIdentifier("modInstallation.originalRecovery." + reference.licenseId)
        .accessibilityLabel(installationText("originalRecovery.open"))
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
                Cloud25Screen(title: installationString("originalRecovery.title", locale: locale), seed: reference.licenseId, symbol: "arrow.counterclockwise") {
                    CYEmptyState(systemImage: "lock.slash", "modInstallation.originalRecovery.unavailable", tableName: "ModInstallation")
                    Cloud25Pill(title: installationString("originalRecovery.reopen", locale: locale), key: "originalRecovery.reopen", primary: true, enabled: phase == .active) { reopen() }
                }
            }
        }
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
        Cloud25Screen(title: installationString("originalRecovery.title", locale: locale), seed: controller.identity.licenseId, symbol: "arrow.counterclockwise") {
            if controller.busy || !hasRead {
                CYSkeleton()
                    .accessibilityIdentifier("modInstallationOriginalRecovery.loading")
                    .accessibilityLabel(installationText("originalRecovery.loading"))
            }
            CYInfoCard {
                Cloud25Header(title: installationString("originalRecovery.identitySection", locale: locale))
                InstallationFact("license", controller.identity.licenseId)
                InstallationFact("module", controller.identity.moduleId)
                InstallationFact("release", controller.identity.releaseId)
                installationText("originalRecovery.boundary").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            CYInfoCard {
                Cloud25Header(title: installationString("originalRecovery.localSection", locale: locale))
                if let request = controller.originalRecoveryRequestID {
                    Text(verbatim: request).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    if let saved = controller.originalRecoverySavedReceipt {
                        CYStatusChip(verbatim: installationString("originalRecovery.savedReceipt", locale: locale), tone: .info, systemImage: "doc.text")
                            .accessibilityLabel(installationText("originalRecovery.savedReceipt"))
                        ModInstallationOriginalReceiptSummary(receipt: saved)
                    }
                } else if ModInstallationOriginalRecoveryPresentation.showsNoLocalRequest(hasRead: hasRead, busy: controller.busy,
                                                                                          requestID: controller.originalRecoveryRequestID,
                                                                                          storageUnavailable: controller.originalRecoveryStorageUnavailable) {
                    CYEmptyState(systemImage: "doc", "modInstallation.originalRecovery.noLocalRequest", tableName: "ModInstallation")
                }
                if controller.originalRecoveryStorageUnavailable {
                    CYNoteBanner(text: installationText("originalRecovery.storageUnavailable"), symbol: "externaldrive.badge.exclamationmark", tone: .warning)
                }
                if controller.originalRecoveryRequestUnknown {
                    CYNoteBanner(text: installationText("originalRecovery.requestUnknown"), symbol: "questionmark.circle", tone: .warning)
                }
            }
            if let receipt = controller.originalRecoveryReceipt {
                CYInfoCard {
                    Cloud25Header(title: installationString("originalRecovery.resultSection", locale: locale))
                    ModInstallationOriginalReceiptSummary(receipt: receipt)
                    installationText("originalRecovery.resultBoundary").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if receipt.memberTemplateID != nil {
                        ModInstalledTextReadEntry(makeReader: { controller.installedTextReader(receipt) })
                    }
                }
            }
            CYInfoCard {
                Cloud25Header(title: installationString("originalRecovery.historySection", locale: locale))
                ForEach(controller.originalRecoveryHistory) { receipt in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        ModInstallationOriginalReceiptSummary(receipt: receipt)
                        Cloud25Pill(title: installationString("originalRecovery.readRequest", locale: locale), key: "originalRecovery.readRequest", primary: false, enabled: !controller.busy && controller.isCurrent && phase == .active) {
                            Task { await readHistory(receipt) }
                        }
                    }
                }
                if ModInstallationOriginalRecoveryPresentation.showsEmptyHistory(hasRead: controller.originalRecoveryHistoryRead,
                                                                                 busy: controller.busy, count: controller.originalRecoveryHistory.count,
                                                                                 unknown: controller.originalRecoveryHistoryUnknown) {
                    CYEmptyState(systemImage: "clock", "modInstallation.originalRecovery.emptyHistory", tableName: "ModInstallation")
                }
                if controller.originalRecoveryHistoryUnknown {
                    CYNoteBanner(text: installationText("originalRecovery.historyUnknown"), symbol: "questionmark.circle", tone: .warning)
                }
                Cloud25Pill(title: installationString("originalRecovery.refresh", locale: locale), key: "originalRecovery.refresh", primary: true, systemImage: "arrow.clockwise", enabled: !controller.busy && controller.isCurrent && phase == .active) {
                    Task { await refresh() }
                }
            }
        }
        .privacySensitive()
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
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            InstallationFact("request", receipt.requestId)
            InstallationFact("license", receipt.licenseId)
            InstallationFact("release", receipt.releaseId)
            InstallationFact("contentHash", receipt.contentHash)
            InstallationFact("termsHash", receipt.termsHash)
            InstallationReceiptFacts(receipt: receipt)
        }
    }
}

// MARK: - Lane chrome (player dark, one hero title, 16pt gutters)

enum Cloud25Copy {
    static let dash = "—"

    /// Empty and the sentinel UNKNOWN become an em dash. A real 0, including `"0"`, stays.
    static func value(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "UNKNOWN" { return dash }
        return trimmed
    }

    static func joined(_ left: String?, _ right: String?) -> String {
        let parts = [left, right].compactMap { item -> String? in
            guard let item else { return nil }
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return parts.isEmpty ? dash : parts.joined(separator: " · ")
    }
}

struct Cloud25Header: View {
    let title: String
    var body: some View {
        CYSectionHeader(LocalizedStringKey(stringLiteral: title))
            .accessibilityLabel(Text(verbatim: title))
    }
}

struct Cloud25Pill: View {
    let title: String
    var key: String? = nil
    var primary = false
    var systemImage: String? = nil
    var enabled = true
    let action: () -> Void
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        CYPillButton(verbatim: title, style: primary ? .primary : .secondary, systemImage: systemImage) {
            if primary, !reduceMotion { CYHaptics.impactMedium.play() }
            action()
        }
        .disabled(!enabled)
        .accessibilityLabel(key.map { installationText($0) } ?? Text(verbatim: title))
    }
}

/// One visible title, from `CYHeroHeader` / `cyHeroScreen`. Page gutters are 16pt.
struct Cloud25Screen<Content: View>: View {
    let title: String
    let seed: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                Color.clear
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay { CYCoverArt(seed: seed.isEmpty ? symbol : seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.lg) }
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                    .accessibilityHidden(true)
                CYHeroHeader(verbatim: title)
                content()
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.jumbo)
        }
        .scrollDismissesKeyboard(.interactively)
        .cyDomainPageBackground()
        .cyHeroScreen()
        .themeDomain(.player)
    }
}
