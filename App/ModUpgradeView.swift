import SwiftUI

/// Production entry from either original purchased metadata or commerce-owned license identity.
@MainActor struct ModUpgradeLicenseLink: View {
    let reference: ModInstallationIdentity
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NavigationLink {
            ModUpgradeEntry(reference: reference, makeController: { session.makeModUpgradeController(reference: $0) })
        } label: {
            Label { upgradeText("open") } icon: { Image(systemName: "arrow.up.circle") }
        }
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
            else { ModUpgradeUnavailable { reopen() } }
        }
        .onAppear { if controller?.isCurrent != true { reopen() } }
        .onChange(of: session.sessionRevision) { _, _ in reopen() }
        .onChange(of: session.account?.id) { _, _ in reopen() }
        .onChange(of: session.account?.effectiveRole) { _, _ in reopen() }
        // Navigation into the existing installer/acquisition is not logout. Return keeps the same durable intent.
    }
    private func reopen() { controller?.invalidate(); controller = makeController(reference) }
}

private struct ModUpgradeUnavailable: View {
    let refresh: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYHeroHeader(LocalizedStringKey("modUpgrade.title"), tableName: "ModUpgrade") {
                ModUpgradeCover(seed: "mod-upgrade", symbol: "arrow.up.circle")
            }
            CYEmptyState(systemImage: "arrow.triangle.2.circlepath", LocalizedStringKey("modUpgrade.unavailable"), tableName: "ModUpgrade")
            CYPillButton(verbatim: upgradeString("refresh", locale: locale), systemImage: "arrow.clockwise", action: refresh)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .cyHeroScreen()
    }
}

@MainActor private struct ModUpgradeView: View {
    @State var controller: ModUpgradeController
    @State private var confirming: ModUpgradeCandidate?
    @EnvironmentObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    private var hasForwardPrimary: Bool {
        if controller.intent?.target != nil { return true }
        guard let selected = controller.selected else { return false }
        return selected.compatibility != .blocked
    }
    var body: some View {
        List {
            Section {
                CYHeroHeader(LocalizedStringKey("modUpgrade.title"), tableName: "ModUpgrade") {
                    ModUpgradeCover(seed: controller.source.licenseId, symbol: "arrow.up.circle")
                }
            }.e1HeroRow()
            if controller.busy, controller.candidates.isEmpty, controller.intent == nil {
                Section { CYSkeleton() }
            }
            Section {
                if let title = controller.sourceTitle {
                    CYImageCard(verbatim: cyShownValue(title), fallback: "modUpgrade.title", meta: cyShownValue(controller.source.releaseId))
                        .listRowSeparator(.hidden)
                }
                UpgradeFact("oldLicense", controller.source.licenseId)
                UpgradeFact("oldVersion", controller.source.releaseId)
                UpgradeFact("oldContentHash", controller.source.contentHash)
                UpgradeFact("oldTermsHash", controller.source.termsHash)
                upgradeText("boundary")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: { upgradeHeader("original") }
            if let intent = controller.intent, let target = intent.target {
                Section {
                    UpgradeFact("targetVersion", target.releaseId)
                    UpgradeFact("newLicense", target.licenseId)
                    if let original = intent.installation { UpgradeFact("originalRequest", original.requestId) }
                    ModUpgradeFrozenComparisonView(candidate: intent.candidate)
                    Text("这里是原选择时保存的比较，不是当前授权或安装成功证明。继续只使用原选择与原请求。")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    upgradeText("recoveryBoundary")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if intent.installation == nil {
                        CYPillButton(verbatim: upgradeString("discardUnstaged", locale: locale), style: .tertiary) { controller.discardUnstaged() }
                            .e1ActionRow()
                    }
                    if intent.installation != nil, intent.rejectionReason == nil {
                        CYPillButton(verbatim: upgradeString("finishUninstalled", locale: locale), style: .secondary) { Task { await controller.finishUninstalledOriginal() } }
                            .disabled(controller.busy)
                            .e1ActionRow()
                    }
                    if let reason = intent.rejectionReason {
                        Label {
                            Text(verbatim: cyShownValue(reason))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.dangerText)
                        CYPillButton(verbatim: upgradeString("discardRejected", locale: locale), style: .tertiary) { controller.discardRejected() }
                            .e1ActionRow()
                    }
                    NavigationLink {
                        VStack(spacing: 0) {
                            if let reason = controller.rejectionReason {
                                Text(verbatim: cyShownValue(reason))
                                    .cyText(.bodyCompact)
                                    .foregroundStyle(CYColor.dangerText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(CYSpacing.pageHorizontal)
                            }
                            ModInstallationEntry(reference: target, makeController: { _ in controller.makeInstallationController() })
                        }
                    } label: { upgradeText("continueOriginal") }
                    .buttonStyle(CYPillButtonStyle())
                    .e1ActionRow()
                } header: { upgradeHeader("savedSelection") }
            } else {
                Section {
                    ForEach(controller.candidates) { candidate in
                        Button { controller.select(candidate) } label: { candidateRow(candidate) }
                            .disabled(controller.busy)
                    }
                    if controller.candidates.isEmpty, controller.sourceTitle != nil,
                       controller.messageKey == nil, !controller.busy {
                        CYEmptyState(systemImage: "square.stack.3d.up", LocalizedStringKey("modUpgrade.empty"), tableName: "ModUpgrade")
                    }
                    if controller.nextCursor != nil {
                        CYPillButton(verbatim: upgradeString("more", locale: locale), style: .secondary) { Task { await controller.recover(more: true) } }
                            .disabled(controller.busy)
                            .e1ActionRow()
                    }
                } header: { upgradeHeader("candidates") }
                if let selected = controller.selected { comparison(selected) }
            }
            if let key = controller.messageKey {
                Section {
                    if key == "error.comparisonTooLarge" {
                        Label {
                            Text("单个版本的完整比较超出可保存范围，未截断条款或冒认无差异；当前无法确认此升级，原选择与原请求仍保留。")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(CYColor.textSecondary)
                    } else {
                        Label {
                            upgradeText(key).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(CYColor.textSecondary)
                    }
                }
            }
            Section {
                CYPillButton(verbatim: upgradeString("refresh", locale: locale), style: hasForwardPrimary ? .secondary : .primary, systemImage: "arrow.clockwise") {
                    Task { await controller.recover() }
                }
                .disabled(controller.busy)
                .e1ActionRow()
            }
        }
        .listStyle(.insetGrouped)
        .cyText(.body)
        .cyGroupedSurface()
        .cyHeroScreen()
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

    private func candidateRow(_ candidate: ModUpgradeCandidate) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(verbatim: cyShownValue(candidate.title), meta: cyShownValue(candidate.targetReleaseId), trailing: .none) {
                ModUpgradeThumb(seed: candidate.title, symbol: "arrow.up.circle")
            }
            HStack(spacing: CYSpacing.sm) {
                CYStatusChip(verbatim: upgradeString("ordering." + candidate.ordering.rawValue, locale: locale), systemImage: orderingSymbol(candidate.ordering))
                CYStatusChip(verbatim: upgradeString("authorization." + candidate.authorization.rawValue, locale: locale), tone: authorizationTone(candidate.authorization), systemImage: authorizationSymbol(candidate.authorization))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func orderingSymbol(_ ordering: ModUpgradeCandidate.Ordering) -> String {
        switch ordering {
        case .newerPackageVersion: "arrow.up.circle"
        case .otherReviewedRelease: "doc"
        }
    }
    private func authorizationTone(_ authorization: ModUpgradeCandidate.Authorization) -> CYStatusTone {
        switch authorization {
        case .authorized: .success
        case .acquisitionRequired: .warning
        }
    }
    private func authorizationSymbol(_ authorization: ModUpgradeCandidate.Authorization) -> String {
        switch authorization {
        case .authorized: "checkmark.circle"
        case .acquisitionRequired: "exclamationmark.circle"
        }
    }

    @ViewBuilder private func comparison(_ candidate: ModUpgradeCandidate) -> some View {
        Section {
            UpgradeFact("targetVersion", candidate.targetReleaseId)
            UpgradeFact("targetContentHash", candidate.targetContentHash)
            UpgradeFact("targetTermsHash", candidate.targetTermsHash)
            UpgradeFact("offer", candidate.offerId)
            if let package = candidate.packageId { UpgradeFact("package", package) }
            if let version = candidate.packageVersion { UpgradeFact("packageVersion", version) }
            CYStatusChip(verbatim: upgradeString("ordering." + candidate.ordering.rawValue, locale: locale), systemImage: orderingSymbol(candidate.ordering))
            ModUpgradeFrozenComparisonView(candidate: candidate)
            upgradeText("bindings")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(candidate.requiredBindings) { binding in
                Text(verbatim: cyShownValue(binding.kind.rawValue + ":" + binding.key))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(candidate.conflicts, id: \.self) { conflict in
                Label {
                    Text(verbatim: cyShownValue(conflict)).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .cyText(.bodyCompact)
                .foregroundStyle(CYColor.dangerText)
            }
            upgradeText("reviewNext")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            switch candidate.compatibility {
            case .blocked:
                Label { upgradeText("blocked").fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: "nosign")
                }
                .foregroundStyle(CYColor.dangerText)
            case .compatible:
                if candidate.authorization == .acquisitionRequired {
                    upgradeText("acquisitionBoundary")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    WorkshopCommerceAccountLink(makeController: { session.makeWorkshopCommerceController() }, makeInstallationPair: { reference in
                        guard let context = session.makeModInstallationWithOriginalReader(reference: reference) else { return nil }
                        return (context.controller, context.originalReader)
                    }, initialOfferId: candidate.offerId)
                } else {
                    CYPillButton(verbatim: upgradeString("select", locale: locale), systemImage: "checkmark.circle") { confirming = candidate }
                        .disabled(!controller.canConfirm)
                        .e1ActionRow()
                }
            }
        } header: { upgradeHeader("comparison") }
    }
}

/// One rendering for current comparison, the exact confirmed intent and read-only restart recovery.
/// These are contract facts only: no grant, physical venue consent, publication or run authority.
@MainActor private struct ModUpgradeFrozenComparisonView: View {
    let candidate: ModUpgradeCandidate
    /// i18n r3: every label is a `modUpgrade.r3.*` key (en + zh-Hans) in plain words; lists join with the locale's separator.
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            fact("modUpgrade.r3.comparisonHash", candidate.comparisonHash)
            note("modUpgrade.r3.hashNote")
            upgradeText("changedFields")
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if candidate.changedFields.isEmpty { upgradeText("noChangedFields").cyText(.body).foregroundStyle(CYColor.textSecondary) }
            ForEach(candidate.changedFields, id: \.self) { field in
                changeLabel(field)
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let comparison = candidate.termsComparison {
                fact("modUpgrade.r3.creatorId", String(comparison.creatorId))
                DisclosureGroup("modUpgrade.r3.sourceTerms") { terms(comparison.source) }
                DisclosureGroup(LocalizedStringKey(candidate.authorization == .authorized ? "modUpgrade.r3.targetTermsOwned" : "modUpgrade.r3.targetTermsForSale")) {
                    terms(comparison.target)
                }
                note("modUpgrade.r3.compareNote")
            } else {
                note("modUpgrade.r3.comparisonUnknown")
            }
        }
        .cyText(.body)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
    @ViewBuilder private func terms(_ terms: WorkshopCommerceTerms) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            fact("modUpgrade.r3.termsVersion", terms.version)
            fact("modUpgrade.r3.termsHash", terms.hash)
            fact("modUpgrade.r3.contentHash", terms.contentHash)
            fact("modUpgrade.r3.commercialUse", permission(terms.commercialUse))
            fact("modUpgrade.r3.allowedRegions", list(terms.allowedRegions))
            fact("modUpgrade.r3.installationLimit", String(terms.installationLimit))
            fact("modUpgrade.r3.useDuration", terms.useDuration)
            fact("modUpgrade.r3.updatePolicy", terms.updatePolicy)
            fact("modUpgrade.r3.redistribution", terms.redistribution)
            fact("modUpgrade.r3.refundPolicy", terms.refundPolicyReference)
            if let rights = terms.compositionRights {
                fact("modUpgrade.r3.rightsProfile", rights.profile)
                fact("modUpgrade.r3.rightsHash", rights.grantHash)
                fact("modUpgrade.r3.authorReviewer", "\(rights.author) / \(rights.reviewer)")
                fact("modUpgrade.r3.applicationDecision", rights.applicationRequestId + " / " + rights.decisionId)
                fact("modUpgrade.r3.sourceReview", "\(rights.sourceKind):\(rights.sourceId) / \(rights.auditTaskId)")
                fact("modUpgrade.r3.sourceHash", rights.sourceHash)
                fact("modUpgrade.r3.draftHash", rights.draftHash)
                fact("modUpgrade.r3.packageVersion", rights.packageId + " / " + rights.packageVersion)
                fact("modUpgrade.r3.release", rights.releaseId)
                fact("modUpgrade.r3.rightsContentHash", rights.contentHash)
                fact("modUpgrade.r3.approvedAt", rights.approvedAt)
                fact("modUpgrade.r3.scopeAuthors", ids(rights.scope.authors))
                fact("modUpgrade.r3.scopeSubjects", ids(rights.scope.installationSubjects))
                fact("modUpgrade.r3.scopeVenues", ids(rights.scope.venues))
                fact("modUpgrade.r3.scopeRegions", list(rights.scope.regions))
                fact("modUpgrade.r3.scopeCommercialUse", permission(rights.scope.commercialUse))
                fact("modUpgrade.r3.translation", permission(rights.scope.translation))
                fact("modUpgrade.r3.adaptation", permission(rights.scope.adaptation))
                fact("modUpgrade.r3.remix", permission(rights.scope.remix))
                fact("modUpgrade.r3.embeddedRedistribution", permission(rights.scope.embeddedRedistribution))
                if rights.hasExplicitPhysicalVenues, let pois = rights.scope.venuePoiIds {
                    fact("modUpgrade.r3.venueScopeVersion", rights.scope.venueScopeVersion ?? "UNKNOWN")
                    fact("modUpgrade.r3.venuePois", ids(pois))
                } else {
                    note("modUpgrade.r3.venuePoisUnknown")
                }
                fact("modUpgrade.r3.evidence", list(rights.scope.evidenceReferences))
            } else {
                note("modUpgrade.r3.noCompositionRights")
            }
        }.padding(.vertical, CYSpacing.xs)
    }
    private func fact(_ title: LocalizedStringKey, _ value: String) -> some View {
        CYFactRow(label: Text(title), value: cyShownValue(value))
    }
    private func note(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func permission(_ allowed: Bool) -> String {
        appLocalized(allowed ? "modUpgrade.r3.permission.allowed" : "modUpgrade.r3.permission.notGranted", locale: locale)
    }
    private func list(_ values: [String]) -> String { values.joined(separator: appLocalized("i18nR3.listSeparator", locale: locale)) }
    private func ids(_ values: [Int64]) -> String { list(values.map { String($0) }) }
    /// MP-style change line per composition-rights scope field; unknown fields show the raw field path.
    private func changeLabel(_ field: String) -> Text {
        let fields = ["authors", "installationSubjects", "venues", "regions", "commercialUse", "translation", "adaptation",
                      "remix", "embeddedRedistribution", "evidenceReferences", "venueScopeVersion", "venuePoiIds"]
        let prefix = "terms.compositionRights.scope."
        let name = field.hasPrefix(prefix) ? String(field.dropFirst(prefix.count)) : ""
        if fields.contains(name) { return Text(LocalizedStringKey("modUpgrade.r3.change." + name)) }
        if field == "terms.compositionRights" { return Text("modUpgrade.r3.change.compositionRights") }
        return Text(verbatim: field)
    }
}
private struct UpgradeFact: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        CYFactRow(label: upgradeText(key), value: cyShownValue(value))
    }
}
private func upgradeHeader(_ key: String) -> some View {
    upgradeText(key)
        .cyText(.sectionTitle)
        .foregroundStyle(CYColor.textPrimary)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
}
private func upgradeText(_ key: String) -> Text { Text(LocalizedStringKey("modUpgrade." + key), tableName: "ModUpgrade") }
private func upgradeString(_ key: String, locale: Locale) -> String {
    String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: "modUpgrade." + key), table: "ModUpgrade", locale: locale))
}
private func cyShownValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "—" }
    if trimmed.caseInsensitiveCompare("UNKNOWN") == .orderedSame { return "—" }
    return value
}

private struct ModUpgradeCover: View {
    let seed: String
    var symbol: String
    @ScaledMetric(relativeTo: .largeTitle) private var height: CGFloat = 168
    var body: some View {
        CYCoverArt(seed: seed, symbol: symbol, cornerRadius: CYRadius.lg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

private struct ModUpgradeThumb: View {
    let seed: String
    var symbol: String
    var body: some View {
        CYCoverArt(seed: seed.isEmpty ? "mod" : seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.sm)
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }
}

@MainActor struct ModUpgradeOriginalRecoveryLink: View {
    let reference: ModInstallationIdentity
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NavigationLink {
            ModUpgradeOriginalRecoveryEntry(reference: reference, makeController: { session.makeModUpgradeController(reference: $0) })
        } label: {
            Label("读取原升级结果 / 重启恢复", systemImage: "arrow.counterclockwise")
        }
        .accessibilityIdentifier("modUpgrade.originalRecovery." + reference.licenseId)
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
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    CYHeroHeader(verbatim: "原升级结果恢复") {
                        ModUpgradeCover(seed: reference.licenseId, symbol: "arrow.counterclockwise")
                    }
                    CYEmptyState(systemImage: "lock.slash", LocalizedStringKey("原升级结果读取许可或当前会话不可用；未重发请求。"))
                    CYPillButton(verbatim: "重新打开原读取范围") { reopen() }
                }
                .padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .cyDomainPageBackground()
                .cyHeroScreen()
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
        List {
            Section {
                CYHeroHeader(verbatim: "原升级结果恢复") {
                    ModUpgradeCover(seed: controller.source.licenseId, symbol: "arrow.counterclockwise")
                }
            }.e1HeroRow()
            Section {
                UpgradeFact("oldLicense", controller.source.licenseId)
                UpgradeFact("oldVersion", controller.source.releaseId)
                Text("只读原 source→target 选择与同一升级请求结果。不查询可升级目录、不重新 stage、不安装、不取消、不删除 journal。旧许可、旧稿与旧 run 不会被覆盖。")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: { recoveryHeader("原升级来源") }
            if let intent = controller.originalRecoveryIntent {
                Section {
                    UpgradeFact("targetVersion", intent.candidate.targetReleaseId)
                    if let target = intent.target { UpgradeFact("newLicense", target.licenseId) }
                    if let original = intent.installation { UpgradeFact("originalRequest", original.requestId) }
                    else { Text("原选择尚无本机绑定的安装请求；不据此重建 UUID 或自动提交。").cyText(.body).fixedSize(horizontal: false, vertical: true) }
                    if let reason = intent.rejectionReason {
                        Text(verbatim: cyShownValue(reason))
                            .cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ModUpgradeFrozenComparisonView(candidate: intent.candidate)
                    Text("原本机比较仅说明当时确认的冻结条款；不把它当成当前有效权益或服务端成功结果。")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: { recoveryHeader("原本机选择 · 不代表已安装") }
            } else if controller.originalRecoveryRead {
                Section { Text("本机无可读取的原升级选择；不是服务端从未升级的证明。可在目标许可的原安装历史查本人已装结果。").cyText(.body).fixedSize(horizontal: false, vertical: true) }
            }
            if let receipt = controller.originalRecoveryReceipt {
                Section {
                    ModInstallationOriginalReceiptSummary(receipt: receipt)
                    Text("原安装回执不授予新的版本、发布或运行权利；撤权后仍保留原发生事实。")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if receipt.state == .cancelled || receipt.state == .failed {
                        Text("这是原请求未完成安装的结果，不是卸载旧稿、回退旧 release/run、退款或客户端退还额度的证明。")
                            .cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if receipt.state == .installed {
                        Text("生成的是目标版本的新私有稿；不据此替换旧稿、旧 release 或旧 run，也不执行版本降级。")
                            .cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if receipt.state == .prepared || receipt.state == .installed {
                        CYPillButton(verbatim: "只读原请求的预览 / 当前草稿", style: .secondary, systemImage: "doc.text") { Task { await controller.readOriginalContent() } }
                            .disabled(controller.busy || !controller.isCurrent)
                            .e1ActionRow()
                    }
                } header: { recoveryHeader("本次同一原升级请求结果") }
            }
            if let preview = controller.originalRecoveryPreview {
                Section {
                    Text("这是原 PREPARED 请求的绑定计划，不是已经安装、发布、运行或可以回滚的证明。")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let raw = preview.fields["qmodTopicGraphJson"], let graph = try? ModInstallationTopicGraph(json: raw) {
                        InstallationTopicGraphContent(graph: graph)
                    }
                    ForEach(preview.fields.keys.filter { $0 != "qmodTopicGraphJson" && $0 != "compositionReceiptJson" }.sorted(), id: \.self) { key in
                        DisclosureGroup(key) {
                            Text(verbatim: cyShownValue(preview.fields[key] ?? ""))
                                .cyText(.meta).monospaced()
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: { recoveryHeader("同一原请求 · 安装前冻结预览") }
            }
            if let facts = controller.originalRecoveryFacts {
                Section {
                    Text(verbatim: cyShownValue(facts.title))
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: "draftId: \(facts.draftId) · draftContentHash: " + facts.draftContentHash)
                        .cyText(.meta).monospaced()
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("这是原草稿读取服务返回的当前配置，可能已被作者编辑；不是原冻结内容、当前许可、审核发布或运行结果的替代证明。")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    DisclosureGroup("当前规则") { Text(verbatim: facts.rules).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                    if let raw = facts.advancedConfigJson {
                        DisclosureGroup("当前结构 / graph 配置（只读原字节）") {
                            Text(verbatim: raw).cyText(.meta).monospaced().textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: { recoveryHeader("同一原请求 · 当前安装稿读回") }
            }
            if controller.originalRecoveryContentUnknown {
                Text("预览 / 当前稿读取 UNKNOWN 或当前读取权限已撤；仍保留上次已验证的同一原安装回执，不改读别的版本、不重装。")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if controller.originalRecoveryUnknown { Text("本次原升级结果 UNKNOWN；404、超时或异常均不清理原选择、不换键重发。").cyText(.body).fixedSize(horizontal: false, vertical: true) }
            if controller.originalRecoveryStorageUnavailable { Text("原本机 journal 不可读；未删除或替换。").cyText(.body).fixedSize(horizontal: false, vertical: true) }
            Section {
                CYPillButton(verbatim: "刷新同一原升级请求", systemImage: "arrow.clockwise") { Task { await controller.recoverOriginalReceipt() } }
                    .disabled(controller.busy || !controller.isCurrent)
                    .e1ActionRow()
            }
            if controller.busy { Section { CYSkeleton() } }
        }
        .listStyle(.insetGrouped)
        .cyText(.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .task { await controller.recoverOriginalReceipt() }
    }
}

private func recoveryHeader(_ title: String) -> some View {
    Text(verbatim: title)
        .cyText(.sectionTitle)
        .foregroundStyle(CYColor.textPrimary)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
}
