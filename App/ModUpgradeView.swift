import SwiftUI

/// Production entry from either original purchased metadata or commerce-owned license identity.
@MainActor struct ModUpgradeLicenseLink: View {
    let reference: ModInstallationIdentity
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NavigationLink {
            ModUpgradeEntry(reference: reference, makeController: { session.makeModUpgradeController(reference: $0) })
        } label: { upgradeText("open") }
        .accessibilityIdentifier("modUpgrade.open." + reference.licenseId)
    }
}

@MainActor struct ModUpgradeEntry: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModUpgradeController?
    @EnvironmentObject private var session: AppSession
    @State private var controller: ModUpgradeController?
    var body: some View {
        Group {
            if let controller, controller.isCurrent { ModUpgradeView(controller: controller).id(ObjectIdentifier(controller)) }
            else {
                VStack(spacing: 16) {
                    upgradeText("unavailable")
                    Button { reopen() } label: { upgradeText("refresh") }
                }.padding()
            }
        }
        .onAppear { if controller?.isCurrent != true { reopen() } }
        .onChange(of: session.sessionRevision) { _, _ in reopen() }
        .onChange(of: session.account?.id) { _, _ in reopen() }
        .onChange(of: session.account?.effectiveRole) { _, _ in reopen() }
        // Navigation into the existing installer/acquisition is not logout. Return keeps the same durable intent.
    }
    private func reopen() { controller?.invalidate(); controller = makeController(reference) }
}

@MainActor private struct ModUpgradeView: View {
    @Environment(\.themeDomain) private var domain
    @State var controller: ModUpgradeController
    @State private var confirming: ModUpgradeCandidate?
    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    var body: some View {
        Form {
            Section {
                if let title = controller.sourceTitle { Text(verbatim: title).font(Theme.Font.sectionTitle).fixedSize(horizontal: false, vertical: true) }
                UpgradeFact("oldLicense", controller.source.licenseId)
                UpgradeFact("oldVersion", controller.source.releaseId)
                UpgradeFact("oldContentHash", controller.source.contentHash)
                UpgradeFact("oldTermsHash", controller.source.termsHash)
                upgradeText("boundary").fixedSize(horizontal: false, vertical: true)
            } header: { upgradeText("original") }
            if let intent = controller.intent, let target = intent.target {
                Section {
                    UpgradeFact("targetVersion", target.releaseId)
                    UpgradeFact("newLicense", target.licenseId)
                    if let original = intent.installation { UpgradeFact("originalRequest", original.requestId) }
                    ModUpgradeFrozenComparisonView(candidate: intent.candidate)
                    Text("这里是原选择时保存的比较，不是当前授权或安装成功证明。继续只使用原选择与原请求。")
                    upgradeText("recoveryBoundary")
                    if intent.installation == nil {
                        Button { controller.discardUnstaged() } label: { upgradeText("discardUnstaged") }
                    }
                    if intent.installation != nil, intent.rejectionReason == nil {
                        Button { Task { await controller.finishUninstalledOriginal() } } label: { upgradeText("finishUninstalled") }.disabled(controller.busy)
                    }
                    if let reason = intent.rejectionReason {
                        Text(verbatim: reason).font(Theme.Font.label).foregroundStyle(Theme.Generated.color("--cy-color-status-danger", in: domain) ?? .red).fixedSize(horizontal: false, vertical: true)
                        Button { controller.discardRejected() } label: { upgradeText("discardRejected") }
                    }
                    NavigationLink {
                        VStack(spacing: 0) {
                            if let reason = controller.rejectionReason {
                                Text(verbatim: reason).font(Theme.Font.label).foregroundStyle(Theme.Generated.color("--cy-color-status-danger", in: domain) ?? .red).fixedSize(horizontal: false, vertical: true).padding()
                            }
                            ModInstallationEntry(reference: target, makeController: { _ in controller.makeInstallationController() })
                        }
                    } label: { upgradeText("continueOriginal") }
                } header: { upgradeText("savedSelection") }
            } else {
                Section {
                    ForEach(controller.candidates) { candidate in
                        Button { controller.select(candidate) } label: {
                            VStack(alignment: .leading) {
                                Text(verbatim: candidate.title).font(Theme.Font.cardTitle)
                                Text(verbatim: candidate.targetReleaseId).font(Theme.Font.label).foregroundStyle(.secondary)
                                upgradeText("ordering." + candidate.ordering.rawValue).font(Theme.Font.label)
                                upgradeText("authorization." + candidate.authorization.rawValue).font(Theme.Font.label)
                            }.fixedSize(horizontal: false, vertical: true)
                        }.disabled(controller.busy)
                    }
                    if controller.candidates.isEmpty, controller.sourceTitle != nil,
                       controller.messageKey == nil, !controller.busy { upgradeText("empty") }
                    if controller.nextCursor != nil {
                        Button { Task { await controller.recover(more: true) } } label: { upgradeText("more") }.disabled(controller.busy)
                    }
                } header: { upgradeText("candidates") }
                if let selected = controller.selected { comparison(selected) }
            }
            if let key = controller.messageKey {
                if key == "error.comparisonTooLarge" {
                    Text("单个版本的完整比较超出可保存范围，未截断条款或冒认无差异；当前无法确认此升级，原选择与原请求仍保留。")
                        .foregroundStyle(.secondary)
                } else { upgradeText(key).foregroundStyle(.secondary) }
            }
            Button { Task { await controller.recover() } } label: { upgradeText("refresh") }.disabled(controller.busy)
        }
        .font(Theme.Font.body)
        .navigationTitle(upgradeString("title", locale: locale))
        .privacySensitive()
        .onAppear { Task { await controller.recover() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await controller.recover() } } }
        .confirmationDialog(upgradeString("confirmQuestion", locale: locale), isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } })) {
            if let reviewed = confirming {
                Button { controller.confirm(reviewed, confirmedByBuyer: true); confirming = nil } label: { upgradeText("confirm") }
            }
            Button(role: .cancel) { confirming = nil } label: { upgradeText("cancel") }
        } message: { upgradeText("reviewNext") }
    }
    @ViewBuilder private func comparison(_ candidate: ModUpgradeCandidate) -> some View {
        Section {
            UpgradeFact("targetVersion", candidate.targetReleaseId)
            UpgradeFact("targetContentHash", candidate.targetContentHash)
            UpgradeFact("targetTermsHash", candidate.targetTermsHash)
            UpgradeFact("offer", candidate.offerId)
            if let package = candidate.packageId { UpgradeFact("package", package) }
            if let version = candidate.packageVersion { UpgradeFact("packageVersion", version) }
            upgradeText("ordering." + candidate.ordering.rawValue)
            ModUpgradeFrozenComparisonView(candidate: candidate)
            upgradeText("bindings").font(.headline)
            ForEach(candidate.requiredBindings) { binding in Text(verbatim: binding.kind.rawValue + ":" + binding.key) }
            ForEach(candidate.conflicts, id: \.self) { Text(verbatim: $0).foregroundStyle(.red) }
            upgradeText("reviewNext").font(.footnote)
            if candidate.compatibility == .blocked { upgradeText("blocked") }
            else if candidate.authorization == .acquisitionRequired {
                upgradeText("acquisitionBoundary")
                WorkshopCommerceAccountLink(makeController: { session.makeWorkshopCommerceController() }, makeInstallationPair: { reference in
                    guard let context = session.makeModInstallationWithOriginalReader(reference: reference) else { return nil }
                    return (context.controller, context.originalReader)
                }, initialOfferId: candidate.offerId)
            } else if candidate.compatibility == .compatible {
                Button { confirming = candidate } label: { upgradeText("select") }.disabled(!controller.canConfirm)
            } else { upgradeText("blocked") }
        } header: { upgradeText("comparison") }
    }
}

/// One rendering for current comparison, the exact confirmed intent and read-only restart recovery.
/// These are contract facts only: no grant, physical venue consent, publication or run authority.
@MainActor private struct ModUpgradeFrozenComparisonView: View {
    let candidate: ModUpgradeCandidate
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fact("比较 hash", candidate.comparisonHash)
            Text("hash 仅关联原冻结版本，不是客户端核准签名或当前使用许可。")
                .font(Theme.Font.label).foregroundStyle(.secondary)
            upgradeText("changedFields").font(Theme.Font.sectionTitle)
            if candidate.changedFields.isEmpty { upgradeText("noChangedFields") }
            ForEach(candidate.changedFields, id: \.self) { field in
                Text(verbatim: changeLabel(field)).font(Theme.Font.label)
            }
            if let comparison = candidate.termsComparison {
                fact("原权利作者 ID", String(comparison.creatorId))
                DisclosureGroup("原已购冻结条款") { terms(comparison.source) }
                DisclosureGroup(candidate.authorization == .authorized ? "目标已购冻结条款" : "目标销售条款（尚未取得）") {
                    terms(comparison.target)
                }
                Text("请逐项比较前后授权。未列入的主体、地点、翻译或改编权不能推定拥有；版本选择不会扩大原许可，旧稿和旧场次不会自动迁移。")
                    .font(Theme.Font.label).foregroundStyle(.secondary)
            } else {
                Text("完整冻结条款比较 UNKNOWN。旧响应或旧 journal 没有这些详情，不代表权益相同或全权；不能据此确认新的升级。已存在的原请求仍可只读恢复。")
                    .font(Theme.Font.label).foregroundStyle(.secondary)
            }
        }.font(Theme.Font.body).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
    }
    @ViewBuilder private func terms(_ terms: WorkshopCommerceTerms) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fact("条款版本", terms.version)
            fact("条款 hash", terms.hash)
            fact("内容 hash", terms.contentHash)
            fact("商业使用", permission(terms.commercialUse))
            fact("允许地区", terms.allowedRegions.joined(separator: "、"))
            fact("冻结安装限额（非当前剩余额度）", String(terms.installationLimit))
            fact("使用期间", terms.useDuration)
            fact("版本更新权", terms.updatePolicy)
            fact("原始素材再分发", terms.redistribution)
            fact("退款政策引用", terms.refundPolicyReference)
            if let rights = terms.compositionRights {
                fact("组合授权 profile", rights.profile)
                fact("组合授权 hash", rights.grantHash)
                fact("作者 / 审核人 ID", "\(rights.author) / \(rights.reviewer)")
                fact("原申请 / 决定", rights.applicationRequestId + " / " + rights.decisionId)
                fact("来源 / 原审核", "\(rights.sourceKind):\(rights.sourceId) / \(rights.auditTaskId)")
                fact("来源 hash", rights.sourceHash)
                fact("原稿 hash", rights.draftHash)
                fact("授权包 / 版本", rights.packageId + " / " + rights.packageVersion)
                fact("授权 release", rights.releaseId)
                fact("授权内容 hash", rights.contentHash)
                fact("批准时间", rights.approvedAt)
                fact("可用作者 ID", ids(rights.scope.authors))
                fact("可安装主体 ID", ids(rights.scope.installationSubjects))
                fact("许可商户 ID（非地点同意）", ids(rights.scope.venues))
                fact("组合许可地区", rights.scope.regions.joined(separator: "、"))
                fact("组合商业使用", permission(rights.scope.commercialUse))
                fact("翻译", permission(rights.scope.translation))
                fact("改编", permission(rights.scope.adaptation))
                fact("remix", permission(rights.scope.remix))
                fact("嵌入式再分发（非原素材转售）", permission(rights.scope.embeddedRedistribution))
                if rights.hasExplicitPhysicalVenues, let pois = rights.scope.venuePoiIds {
                    fact("地点范围版本", rights.scope.venueScopeVersion ?? "UNKNOWN")
                    fact("许可原 POI ID", ids(pois))
                } else {
                    Text("原 POI 授权范围 UNKNOWN；不代表任意场地可用，也不代替场地方同意或到场证明。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                fact("权利依据引用", rights.scope.evidenceReferences.joined(separator: "、"))
            } else {
                Text("该份冻结条款未包含组合授权；不默认授予主体/地点、翻译、改编、remix 或嵌入式再分发权。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(verbatim: title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.footnote)
        }
    }
    private func permission(_ allowed: Bool) -> String { allowed ? "仅冻结范围内允许" : "未授予" }
    private func ids(_ values: [Int64]) -> String { values.map { String($0) }.joined(separator: "、") }
    private func changeLabel(_ field: String) -> String {
        let labels = ["authors": "可用作者", "installationSubjects": "可安装主体", "venues": "许可商户",
                      "regions": "许可地区", "commercialUse": "商业使用", "translation": "翻译", "adaptation": "改编",
                      "remix": "remix", "embeddedRedistribution": "嵌入式再分发", "evidenceReferences": "权利依据",
                      "venueScopeVersion": "地点范围版本", "venuePoiIds": "许可原 POI"]
        let prefix = "terms.compositionRights.scope."
        if field.hasPrefix(prefix), let label = labels[String(field.dropFirst(prefix.count))] { return "组合授权变化：" + label }
        if field == "terms.compositionRights" { return "组合授权或其原审核凭证变化（详见前后冻结条款）" }
        return field
    }
}
private struct UpgradeFact: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            upgradeText(key).font(Theme.Font.label).foregroundStyle(.secondary)
            Text(verbatim: value).font(Theme.Font.body).fixedSize(horizontal: false, vertical: true)
        }.textSelection(.enabled)
    }
}
private func upgradeText(_ key: String) -> Text { Text(LocalizedStringKey("modUpgrade." + key), tableName: "ModUpgrade") }
private func upgradeString(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "modUpgrade." + key), table: "ModUpgrade", locale: locale))
}

@MainActor struct ModUpgradeOriginalRecoveryLink: View {
    let reference: ModInstallationIdentity
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NavigationLink("读取原升级结果 / 重启恢复") {
            ModUpgradeOriginalRecoveryEntry(reference: reference, makeController: { session.makeModUpgradeController(reference: $0) })
        }.accessibilityIdentifier("modUpgrade.originalRecovery." + reference.licenseId)
    }
}
@MainActor private struct ModUpgradeOriginalRecoveryEntry: View {
    let reference: ModInstallationIdentity
    let makeController: (ModInstallationIdentity) -> ModUpgradeController?
    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var phase
    @State private var controller: ModUpgradeController?
    var body: some View {
        Group {
            if let controller, controller.isCurrent {
                ModUpgradeOriginalRecoveryView(controller: controller).id(ObjectIdentifier(controller))
            } else {
                VStack {
                    Text("原升级结果读取许可或当前会话不可用；未重发请求。")
                    Button("重新打开原读取范围") { reopen() }
                }.padding()
            }
        }
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
@MainActor private struct ModUpgradeOriginalRecoveryView: View {
    @State var controller: ModUpgradeController
    var body: some View {
        Form {
            Section("原升级来源") {
                UpgradeFact("oldLicense", controller.source.licenseId)
                UpgradeFact("oldVersion", controller.source.releaseId)
                Text("只读原 source→target 选择与同一升级请求结果。不查询可升级目录、不重新 stage、不安装、不取消、不删除 journal。旧许可、旧稿与旧 run 不会被覆盖。")
            }
            if let intent = controller.originalRecoveryIntent {
                Section("原本机选择 · 不代表已安装") {
                    UpgradeFact("targetVersion", intent.candidate.targetReleaseId)
                    if let target = intent.target { UpgradeFact("newLicense", target.licenseId) }
                    if let original = intent.installation { UpgradeFact("originalRequest", original.requestId) }
                    else { Text("原选择尚无本机绑定的安装请求；不据此重建 UUID 或自动提交。") }
                    if let reason = intent.rejectionReason { Text(verbatim: reason).font(Theme.Font.label) }
                    ModUpgradeFrozenComparisonView(candidate: intent.candidate)
                    Text("原本机比较仅说明当时确认的冻结条款；不把它当成当前有效权益或服务端成功结果。")
                }
            } else if controller.originalRecoveryRead {
                Section { Text("本机无可读取的原升级选择；不是服务端从未升级的证明。可在目标许可的原安装历史查本人已装结果。") }
            }
            if let receipt = controller.originalRecoveryReceipt {
                Section("本次同一原升级请求结果") {
                    ModInstallationOriginalReceiptSummary(receipt: receipt)
                    Text("原安装回执不授予新的版本、发布或运行权利；撤权后仍保留原发生事实。")
                    if receipt.state == .cancelled || receipt.state == .failed {
                        Text("这是原请求未完成安装的结果，不是卸载旧稿、回退旧 release/run、退款或客户端退还额度的证明。")
                    } else if receipt.state == .installed {
                        Text("生成的是目标版本的新私有稿；不据此替换旧稿、旧 release 或旧 run，也不执行版本降级。")
                    }
                    if receipt.state == .prepared || receipt.state == .installed {
                        Button("只读原请求的预览 / 当前草稿") { Task { await controller.readOriginalContent() } }
                            .disabled(controller.busy || !controller.isCurrent)
                    }
                }
            }
            if let preview = controller.originalRecoveryPreview {
                Section("同一原请求 · 安装前冻结预览") {
                    Text("这是原 PREPARED 请求的绑定计划，不是已经安装、发布、运行或可以回滚的证明。")
                    if let raw = preview.fields["qmodTopicGraphJson"], let graph = try? ModInstallationTopicGraph(json: raw) {
                        InstallationTopicGraphContent(graph: graph)
                    }
                    ForEach(preview.fields.keys.filter { $0 != "qmodTopicGraphJson" && $0 != "compositionReceiptJson" }.sorted(), id: \.self) { key in
                        DisclosureGroup(key) { Text(verbatim: preview.fields[key] ?? "").font(Theme.Font.label.monospaced()).textSelection(.enabled) }
                    }
                }
            }
            if let facts = controller.originalRecoveryFacts {
                Section("同一原请求 · 当前安装稿读回") {
                    Text(verbatim: facts.title).font(Theme.Font.sectionTitle).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: "draftId: \(facts.draftId) · draftContentHash: " + facts.draftContentHash).font(Theme.Font.label).textSelection(.enabled)
                    Text("这是原草稿读取服务返回的当前配置，可能已被作者编辑；不是原冻结内容、当前许可、审核发布或运行结果的替代证明。")
                    DisclosureGroup("当前规则") { Text(verbatim: facts.rules).textSelection(.enabled) }
                    if let raw = facts.advancedConfigJson {
                        DisclosureGroup("当前结构 / graph 配置（只读原字节）") {
                            Text(verbatim: raw).font(Theme.Font.label.monospaced()).textSelection(.enabled)
                        }
                    }
                }
            }
            if controller.originalRecoveryContentUnknown {
                Text("预览 / 当前稿读取 UNKNOWN 或当前读取权限已撤；仍保留上次已验证的同一原安装回执，不改读别的版本、不重装。")
            }
            if controller.originalRecoveryUnknown { Text("本次原升级结果 UNKNOWN；404、超时或异常均不清理原选择、不换键重发。") }
            if controller.originalRecoveryStorageUnavailable { Text("原本机 journal 不可读；未删除或替换。") }
            Button("刷新同一原升级请求") { Task { await controller.recoverOriginalReceipt() } }.disabled(controller.busy || !controller.isCurrent)
            if controller.busy { ProgressView() }
        }
        .font(Theme.Font.body)
        .navigationTitle("原升级结果恢复").privacySensitive()
        .task { await controller.recoverOriginalReceipt() }
    }
}
