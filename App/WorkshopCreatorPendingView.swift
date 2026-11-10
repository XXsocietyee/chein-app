import SwiftUI

@MainActor struct WorkshopCreatorPendingView: View {
    @Bindable var controller: WorkshopCreatorPendingController
    let appearance: WorkshopCreatorPendingAppearance
    @State private var task: Task<Void, Never>?
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    private func creatorString(_ key: String) -> String { workshopCreatorLocalized(key, locale: locale) }
    @State private var declarationAppearance = WorkshopCreatorConsentAppearance()
    var body: some View {
        // Stable screen identity: an internal author → review branch switch is not Back.
        VStack(spacing: 0) {
            if controller.phase == .reviewing, let declaration = controller.declaration {
                VStack(spacing: 0) {
                    CYPillButton(verbatim: creatorString("workshopPending.back"), style: .tertiary, systemImage: "chevron.backward", fullWidth: false) {
                        declaration.close(declarationAppearance)
                        run(controller.offerBackToProposals(appearance))
                    }.accessibilityIdentifier("workshopPending.back").frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, CYSpacing.pageHorizontal)
                    WorkshopCreatorConsentView(controller: declaration, appearance: declarationAppearance, pendingDetail: controller.selectedDetail)
                        .id(declaration.identity)
                }
            } else {
                List {
                    Section { CYHeroHeader(verbatim: creatorString("workshopPending.title"), subtitle: creatorString("workshopPending.boundary")) }.e1HeroRow()
                    Section {
                        LabeledContent(creatorString("workshopCreator.source"), value: String(controller.sourceTemplateId)).monospacedDigit()
                    }
                    if let receipt = controller.declarationReceipt {
                        Section(creatorString("workshopPending.priorDeclaration")) {
                            Text(creatorString("workshopPending.priorDeclarationScope")).fixedSize(horizontal: false, vertical: true)
                            LabeledContent(creatorString("workshopCreator.package"), value: receipt.consentReference.moduleId)
                            LabeledContent(creatorString("workshopCreator.version"), value: receipt.consentReference.versionId)
                            LabeledContent(creatorString("workshopCreator.record"), value: receipt.consentReference.consentId)
                            Text(verbatim: receipt.declaredAt).font(.caption)
                        }.accessibilityIdentifier("workshopPending.declarationReceipt")
                    } else if let requestId = controller.declarationRequestId {
                        Section(creatorString("workshopPending.priorDeclaration")) {
                            Text(verbatim: requestId).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Text(creatorString("workshopCreator.unknown")).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if controller.phase == .loading || controller.phase == .submitting { CYLoadingStateView(rows: 1).accessibilityLabel(creatorString("workshopCreator.loading")).listRowBackground(Color.clear) }
                    if let issue = controller.issue { Text(creatorString(issueKey(issue))).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("workshopPending.issue") }
                    if let pending = controller.pending {
                        Section(creatorString("workshopPending.saved")) {
                            Text(verbatim: pending.requestId).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Text(creatorString("workshopPending.recovery"))
                            // The exact saved text remains reviewable; edits cannot replace this attempt.
                            Text(verbatim: pending.termsDocument).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            CYPillButton(verbatim: creatorString("workshopPending.retry"), style: .secondary, systemImage: "arrow.clockwise") { run(controller.offerRetry(appearance)) }
                                .disabled(!controller.canRetry).accessibilityIdentifier("workshopPending.retry").e1ActionRow()
                        }
                    }
                    if let receipt = controller.receipt {
                        Section(creatorString("workshopPending.recorded")) {
                            Text(verbatim: receipt.targetId).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Text(creatorString("workshopPending.historic"))
                            CYPillButton(verbatim: creatorString("workshopPending.another"), style: .secondary) { run(controller.offerAnotherProposal(appearance)) }
                                .disabled(controller.phase == .submitting || controller.phase == .loading)
                                .accessibilityIdentifier("workshopPending.another").e1ActionRow()
                        }
                    }
                    if let preview = controller.preview {
                        Section(creatorString("workshopCreator.exactSource")) {
                            ForEach(WorkshopCreatorPreview.fieldOrder, id: \.self) { name in
                                if let value = preview.textFields[name] {
                                    VStack(alignment: .leading) {
                                        Text(creatorString("workshopCreator.field." + name)).font(.caption)
                                        Text(verbatim: value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            Text(verbatim: preview.packageContentHash).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                        if !preview.omittedPlanningMetadata.isEmpty {
                            Section(creatorString("workshopCreator.omitted")) {
                                ForEach(preview.omittedPlanningMetadata, id: \.self) { field in Text(creatorString("workshopCreator.omitted." + field)) }
                            }
                        }
                        if controller.pending == nil { authorForm }
                        Section(creatorString("workshopPending.proposals")) {
                            if controller.items.isEmpty { Text(creatorString("workshopPending.empty")) }
                            ForEach(controller.items, id: \.targetId) { item in
                                Button {
                                    declarationAppearance = WorkshopCreatorConsentAppearance()
                                    run(controller.offerReview(item, appearance))
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(verbatim: item.versionId).fixedSize(horizontal: false, vertical: true)
                                        Text(verbatim: item.termsDocumentHash).font(.caption).fixedSize(horizontal: false, vertical: true)
                                        Text(verbatim: item.expiresAt).font(.caption).fixedSize(horizontal: false, vertical: true)
                                    }
                                }.disabled(controller.phase != .editing)
                                    .accessibilityIdentifier("workshopPending.target." + item.targetId)
                            }
                            if controller.hasMore {
                                CYPillButton(verbatim: creatorString("workshopPending.more"), style: .secondary) { run(controller.offerMore(appearance)) }
                                    .disabled(controller.phase != .editing).accessibilityIdentifier("workshopPending.more").e1ActionRow()
                            }
                        }
                    }
                    CYPillButton(verbatim: creatorString("workshopPending.refresh"), style: .secondary, systemImage: "arrow.clockwise") { run(controller.offerLoad(appearance)) }
                        .disabled(controller.phase == .loading || controller.phase == .submitting)
                        .accessibilityIdentifier("workshopPending.refresh").e1ActionRow()
                }.listStyle(.insetGrouped).cyGroupedSurface()
            }
        }.cyHeroScreen()
            .privacySensitive().accessibilityIdentifier("workshopPending.form")
            .disabled(scenePhase != .active)
            .onAppear {
                isVisible = true
                let action = controller.appear(appearance)
                if scenePhase == .active { run(action) }
                else { controller.suspend(appearance) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard isVisible else { return }
                if phase == .active { run(controller.resume(appearance)) }
                else { controller.suspend(appearance); task?.cancel(); task = nil }
            }
            .onDisappear { isVisible = false; controller.close(appearance); task?.cancel(); task = nil }
    }
    @ViewBuilder private var authorForm: some View {
        Section(creatorString("workshopPending.terms")) {
            Text(creatorString("workshopPending.termsHelp"))
            TextEditor(text: $controller.form.termsDocument).frame(minHeight: 180)
                .accessibilityIdentifier("workshopPending.termsDocument")
        }.disabled(controller.phase != .editing)
        Section(creatorString("workshopPending.choices")) {
            option("commercialUse", value: $controller.form.commercialUse, values: ["ALLOWED", "PROHIBITED"])
            option("adaptation", value: $controller.form.adaptation, values: ["BIND_RESOURCES_ONLY", "LOCAL_ADAPTATION"])
            option("translation", value: $controller.form.translation, values: ["ALLOWED", "PROHIBITED"])
            field("allowedRegions", value: $controller.form.allowedRegions)
            field("buyerKinds", value: $controller.form.buyerKinds)
            Text(creatorString("workshopPending.regionsHelp")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
            field("themeLimit", value: $controller.form.themeLimit)
            field("merchantLimit", value: $controller.form.merchantLimit)
            field("runLimit", value: $controller.form.runLimit)
            Text(creatorString("workshopPending.limitsHelp")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
            field("priceMinor", value: $controller.form.priceMinor)
            field("currency", value: $controller.form.currency)
            Text(creatorString("workshopPending.priceHelp")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
            field("expiresAt", value: $controller.form.expiresAt)
            Text(creatorString("workshopPending.expiryHelp")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
        }.disabled(controller.phase != .editing)
        Section(creatorString("workshopPending.required")) {
            Text(creatorString("workshopPending.fixedRestrictions")).fixedSize(horizontal: false, vertical: true)
            Text(creatorString("workshopPending.reviewRequired")).foregroundStyle(.secondary)
            CYPillButton(verbatim: creatorString("workshopPending.author")) { run(controller.offerAuthor(appearance)) }
                .disabled(!controller.canSubmit).accessibilityIdentifier("workshopPending.author").e1ActionRow()
        }
    }
    private func field(_ key: String, value: Binding<String>) -> some View {
        TextField(creatorString("workshopPending." + key), text: value, axis: .vertical)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("workshopPending." + key)
    }
    private func option(_ key: String, value: Binding<String>, values: [String]) -> some View {
        Picker(creatorString("workshopPending." + key), selection: value) {
            Text(creatorString("workshopPending.choose")).tag("")
            ForEach(values, id: \.self) { value in Text(creatorString("workshopPending.option." + value)).tag(value) }
        }.accessibilityIdentifier("workshopPending." + key)
    }
    private func run(_ action: WorkshopCreatorPendingController.Action?) {
        guard isVisible, scenePhase == .active, let action else { return }; task?.cancel(); task = Task { await action() }
    }
    private func issueKey(_ issue: WorkshopCreatorConsentIssue) -> String {
        switch issue {
        case .storage: return "workshopCreator.storage"
        case .disabled: return "workshopCreator.unavailable"
        case .stale, .unauthorized: return "workshopCreator.changed"
        case .unknown, .pending: return "workshopPending.unknown"
        case .invalid: return "workshopPending.invalid"
        default: return "workshopCreator.failed"
        }
    }
}
