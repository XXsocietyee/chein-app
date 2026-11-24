import SwiftUI

private func nativeAttributeText(_ key: String) -> String {
    NSLocalizedString(key, tableName: "NativeAttributeAuthor", bundle: .main, value: key, comment: "")
}

/// Minimal bridge to the separate recursive32 editor. It edits only the supplied original
/// condition. No evaluator, grammar migration, or effect editor exists in this consumer.
@MainActor protocol NativeAttributeAuthorConditionEditing {
    func editor(condition: ProjectEditJSON?, binding: NativeAttributeAuthorBinding,
                registeredKeys: [String], isCurrent: @escaping () -> Bool,
                save: @escaping (ProjectEditJSON?) -> Bool) -> AnyView
}
@MainActor protocol NativeAttributeAuthorModuleReportRendering {
    func view(_ readback: NativeAttributeAuthorModulePreflight) -> AnyView
}

@MainActor struct NativeAttributeAuthorEntry: View {
    let makeCoordinator: () -> NativeAttributeAuthorCoordinator
    var localDraftOnly = false
    var conditionEditor: (any NativeAttributeAuthorConditionEditing)? = nil
    var moduleReportRenderer: (any NativeAttributeAuthorModuleReportRendering)? = nil
    var onSourceRetired: ((NativeAttributeAuthorBinding) -> Void)? = nil
    var body: some View {
        NavigationLink {
            NativeAttributeAuthorView(coordinator: makeCoordinator(), conditionEditor: conditionEditor, moduleReportRenderer: moduleReportRenderer, onSourceRetired: onSourceRetired)
        } label: { Label(nativeAttributeText(localDraftOnly ? "nativeAttribute.localDraft" : "nativeAttribute.title"), systemImage: "slider.horizontal.3") }
        .accessibilityIdentifier("nativeAttribute.entry")
    }
}

@MainActor struct NativeAttributeAuthorView: View {
    @State var coordinator: NativeAttributeAuthorCoordinator
    var conditionEditor: (any NativeAttributeAuthorConditionEditing)? = nil
    var moduleReportRenderer: (any NativeAttributeAuthorModuleReportRendering)? = nil
    var onSourceRetired: ((NativeAttributeAuthorBinding) -> Void)? = nil
    var close: (() -> Void)? = nil
    @State private var projectReview: NativeAttributeAuthorProjectAction?
    @State private var leaving = false
    @Environment(\.dismiss) private var dismiss
    private var saveIsPrimary: Bool { coordinator.phase != .review }
    var body: some View {
        cyDomainBody.cyDomainScreen(.topicEditor)
    }

    @ViewBuilder private var cyDomainBody: some View {
        List {
            Section {
                CYHeroHeader(verbatim: nativeAttributeText("nativeAttribute.title")) {
                    NativeAttributeCover(seed: "native-attribute-\(coordinator.binding.topicID)", symbol: "slider.horizontal.3")
                }
            }.e1HeroRow()
            Section {
                CYListRow(verbatim: nativeAttributeText("nativeAttribute.topic"), trailing: .value(String(coordinator.binding.topicID))) {
                    CYRowIcon(systemImage: "number")
                }
                CYListRow(verbatim: nativeAttributeText("nativeAttribute.version"), trailing: .value(String(coordinator.draft?.binding.sourceConfigVersion ?? coordinator.binding.sourceConfigVersion))) {
                    CYRowIcon(systemImage: "clock")
                }
                if coordinator.localDraftOnly {
                    Text(verbatim: nativeAttributeText("nativeAttribute.localDraftNotice"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nativeAttribute.localOnly")
                }
                if coordinator.binding.isLocked {
                    CYStatusChip(verbatim: nativeAttributeText("nativeAttribute.frozen"), tone: .warning, systemImage: "lock.fill")
                }
                if coordinator.busy {
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: nativeAttributeText("nativeAttribute.loading")))
                }
                if let issue = coordinator.issue {
                    Label {
                        Text(verbatim: nativeAttributeText(issue))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("nativeAttribute.issue")
                }
                if coordinator.phase == .confirmed && coordinator.projectResult == nil {
                    CYStatusChip(verbatim: nativeAttributeText("nativeAttribute.confirmed"), tone: .success, systemImage: "checkmark.circle")
                }
            }
            // Local file inspection only (Qmod import): no coordinator, service or transport is passed in,
            // so opening it can never issue a request. It sits behind the same author entry gate.
            Section {
                NavigationLink { QmodAuthorImportView() } label: { Label("qmodImport.title", systemImage: "doc.badge.plus") }
                    .accessibilityIdentifier("nativeAttribute.qmodImport")
            }
            if let draft = coordinator.draft {
                Section {
                    ForEach(draft.rows) { row in
                        NavigationLink {
                            NativeAttributeAuthorForm(row: row, coordinator: coordinator, conditionEditor: conditionEditor)
                        } label: {
                            attributeRow(row)
                        }
                        .accessibilityIdentifier("nativeAttribute.row.\(row.key)")
                    }
                    .onMove { offsets, destination in
                        var all = draft.rows
                        all.move(fromOffsets: offsets, toOffset: destination)
                        coordinator.reorder(all.filter(\.isDefinition).map(\.key))
                    }
                    .moveDisabled(!coordinator.canEdit || draft.rows.contains { !$0.isDefinition })
                    if coordinator.canEdit {
                        Button { _ = coordinator.add() } label: {
                            Label(nativeAttributeText("nativeAttribute.add"), systemImage: "plus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityIdentifier("nativeAttribute.add")
                        if coordinator.usesVersionedDefinitions {
                            CYPillButton(verbatim: nativeAttributeText("nativeAttribute.addBasicRegistration"), style: .secondary) { _ = coordinator.add(registrationOnly: true) }
                                .e1ActionRow()
                            Text(verbatim: nativeAttributeText(coordinator.localDraftOnly ? "nativeAttribute.localDraftNotice" : "nativeAttribute.versionedSaveNotice"))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            CYPillButton(verbatim: nativeAttributeText("nativeAttribute.addDefinitionDraft"), style: .secondary) { _ = coordinator.add(registrationOnly: false) }
                                .e1ActionRow()
                            Text(verbatim: nativeAttributeText("nativeAttribute.extensionLocalOnly"))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: { attributeHeader("nativeAttribute.definitions") }
                if !coordinator.binding.isLocked && !coordinator.localDraftOnly {
                    Section {
                        CYPillButton(verbatim: nativeAttributeText("nativeAttribute.checkSave"), style: saveIsPrimary ? .primary : .secondary, systemImage: "checkmark.circle") {
                            Task { await coordinator.prepareSave() }
                        }
                        .disabled(!coordinator.canSave)
                        .accessibilityIdentifier("nativeAttribute.checkSave")
                        .e1ActionRow()
                        if coordinator.pending != nil {
                            CYPillButton(verbatim: nativeAttributeText("nativeAttribute.readback"), style: .secondary) { Task { await coordinator.readback() } }
                                .disabled(coordinator.busy)
                                .accessibilityIdentifier("nativeAttribute.readback")
                                .e1ActionRow()
                        }
                        if coordinator.canRecoverUnsentDraft && coordinator.draft?.binding != coordinator.binding {
                            Button(nativeAttributeText("nativeAttribute.restoreLocal")) { Task { await coordinator.recoverUnsentDraft() } }
                                .disabled(coordinator.busy)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                    }
                    projectFlowSection
                }
            }
            if let check = coordinator.publishCheckResult {
                Section {
                    ForEach(check.issues) { finding in
                        NativeAttributeAuthorDiagnosticIssueView(issue: finding)
                    }
                    if check.issues.isEmpty { Text(verbatim: nativeAttributeText("nativeAttribute.noPublishIssues")).cyText(.body).fixedSize(horizontal: false, vertical: true) }
                    Text(verbatim: nativeAttributeText("nativeAttribute.savedSourceCheck"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: { attributeHeader("nativeAttribute.publishCheck") }
            }
            if let preflight = coordinator.modulePreflightResult {
                Section {
                    if let renderer = moduleReportRenderer { renderer.view(preflight) }
                    else {
                        CYListRow(verbatim: nativeAttributeText("nativeAttribute.topic"), trailing: .value(String(preflight.topicID))) {
                            CYRowIcon(systemImage: "number")
                        }
                        CYListRow(verbatim: nativeAttributeText("nativeAttribute.version"), trailing: .value(String(preflight.configVersion))) {
                            CYRowIcon(systemImage: "clock")
                        }
                        CYStatusChip(
                            verbatim: nativeAttributeText(preflight.ready ? "nativeAttribute.moduleNoErrors" : "nativeAttribute.moduleHasErrors"),
                            tone: preflight.ready ? .success : .danger,
                            systemImage: preflight.ready ? "info.circle" : "exclamationmark.circle"
                        )
                        ForEach(preflight.issues) { NativeAttributeAuthorDiagnosticIssueView(issue: $0) }
                    }
                    Text(verbatim: nativeAttributeText("nativeAttribute.diagnosticOnly"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: nativeAttributeText("nativeAttribute.savedSourceCheck"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: { attributeHeader("nativeAttribute.modulePreflight") }
            }
            if let refs = coordinator.referenceReadback {
                Section {
                    ForEach(Array(refs.positions.enumerated()), id: \.offset) { _, position in
                        Text(verbatim: cyShownValue(position))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let reason = refs.incompleteReason {
                        Text(verbatim: nativeAttributeText(reason))
                            .cyText(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if refs.permitsDelete { Text(verbatim: nativeAttributeText("nativeAttribute.referenceClear")).cyText(.body).fixedSize(horizontal: false, vertical: true) }
                } header: { attributeHeader("nativeAttribute.references") }
            }
            if coordinator.phase == .review {
                Section {
                    ForEach(Array(coordinator.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(verbatim: nativeAttributeText(warning))
                            .cyText(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(verbatim: nativeAttributeText(coordinator.reviewDeletesKey == nil ? "nativeAttribute.saveReview" : "nativeAttribute.deleteReview"))
                        .cyText(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    CYPillButton(verbatim: nativeAttributeText("nativeAttribute.confirm"), systemImage: "checkmark.circle") { Task { await coordinator.confirm() } }
                        .accessibilityIdentifier("nativeAttribute.confirm")
                        .e1ActionRow()
                    Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) { coordinator.cancelReview() }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                } header: { attributeHeader("nativeAttribute.review") }
            }
        }
        .listStyle(.insetGrouped)
        .cyText(.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar {
            if coordinator.canEdit { ToolbarItem { EditButton() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button(nativeAttributeText("nativeAttribute.close")) {
                    if coordinator.draft?.hasChanges == true || coordinator.pending != nil { leaving = true }
                    else { closeAuthor() }
                }
            }
        }
        .navigationBarBackButtonHidden(coordinator.draft?.hasChanges == true || coordinator.pending != nil)
        .confirmationDialog(nativeAttributeText("nativeAttribute.leaveTitle"), isPresented: $leaving, titleVisibility: .visible) {
            Button(nativeAttributeText("nativeAttribute.keepAndClose")) { closeAuthor() }
            Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) {}
        } message: { Text(verbatim: nativeAttributeText("nativeAttribute.leaveMessage")) }
        .confirmationDialog(nativeAttributeText("nativeAttribute.projectReview"), isPresented: Binding(get: { projectReview != nil }, set: { if !$0 { projectReview = nil } }), titleVisibility: .visible) {
            if let action = projectReview {
                Button(nativeAttributeText("nativeAttribute.action.\(action.rawValue)")) {
                    projectReview = nil; Task { await coordinator.performProjectAction(action) }
                }
            }
            Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) { projectReview = nil }
        } message: { Text(verbatim: nativeAttributeText("nativeAttribute.originalFlow")) }
        .task { await coordinator.load() }
        .onChange(of: coordinator.retiredSourceBinding) { _, next in if let next { onSourceRetired?(next) } }
    }

    private func attributeRow(_ row: NativeAttributeAuthorRow) -> some View {
        let title = cyShownValue(row.label.isEmpty ? row.key : row.label)
        let range = "\(cyShownValue(row.minimum))…\(cyShownValue(row.maximum)) · \(cyShownValue(row.initial))"
        let meta = row.label.isEmpty
            ? (row.isDefinition ? range : nativeAttributeText("nativeAttribute.legacy"))
            : cyShownValue(row.key)
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYListRow(verbatim: title, meta: meta, trailing: .chevron) {
                NativeAttributeThumb(seed: row.key.isEmpty ? title : row.key, symbol: "slider.horizontal.3")
            }
            if !row.label.isEmpty && row.isDefinition {
                Text(verbatim: range)
                    .cyText(.numericBody)
                    .foregroundStyle(CYColor.textSecondary)
            } else if !row.label.isEmpty {
                CYStatusChip(verbatim: nativeAttributeText("nativeAttribute.legacy"), tone: .neutral, systemImage: "clock.arrow.circlepath")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var projectFlowSection: some View {
        Section {
            Button(nativeAttributeText("nativeAttribute.publishCheck")) { Task { await coordinator.readPublishCheck() } }
                .disabled(!coordinator.canReadPublishCheck)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("nativeAttribute.publishCheck")
            Button(nativeAttributeText("nativeAttribute.modulePreflight")) { Task { await coordinator.readModulePreflight() } }
                .disabled(!coordinator.canReadModulePreflight)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("nativeAttribute.modulePreflight")
            ForEach([NativeAttributeAuthorProjectAction.saveDraft, .preview, .publish], id: \.rawValue) { action in
                Button(nativeAttributeText("nativeAttribute.action.\(action.rawValue)")) { projectReview = action }
                    .disabled(!coordinator.canUseProjectFlow)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("nativeAttribute.action.\(action.rawValue)")
            }
            Text(verbatim: nativeAttributeText("nativeAttribute.originalFlow"))
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: { attributeHeader("nativeAttribute.projectFlow") }
    }
    private func closeAuthor() {
        // Capture a real confirmed source-retirement result before retire clears presentation.
        // A close event alone never asks the host to reload or treats UNKNOWN as acknowledged.
        if let retired = coordinator.retiredSourceBinding { onSourceRetired?(retired) }
        if let close { close() } else { coordinator.retire(); dismiss() }
    }
}

private func attributeHeader(_ key: String) -> some View {
    Text(verbatim: nativeAttributeText(key))
        .cyText(.sectionTitle)
        .foregroundStyle(CYColor.textPrimary)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
}

/// Both original diagnostics use the same native row. Field/code/message come from the
/// server; no client code-to-field mapping or second validation engine is introduced.
@MainActor private struct NativeAttributeAuthorDiagnosticIssueView: View {
    let issue: NativeAttributeAuthorPublishIssue
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(
                verbatim: nativeAttributeText(issue.level == "error" ? "nativeAttribute.checkError" : "nativeAttribute.checkWarning"),
                tone: issue.level == "error" ? .danger : .warning,
                systemImage: issue.level == "error" ? "exclamationmark.circle" : "exclamationmark.triangle"
            )
            Text(verbatim: cyShownValue(issue.message))
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            LabeledContent(nativeAttributeText("nativeAttribute.issueCode"), value: cyShownValue(issue.code))
            if let field = issue.field { LabeledContent(nativeAttributeText("nativeAttribute.issueField"), value: cyShownValue(field)) }
            if let node = issue.nodeID { LabeledContent(nativeAttributeText("nativeAttribute.node"), value: String(node)) }
        }.accessibilityElement(children: .combine)
    }
}

@MainActor struct NativeAttributeAuthorForm: View {
    @State var row: NativeAttributeAuthorRow
    let coordinator: NativeAttributeAuthorCoordinator
    var conditionEditor: (any NativeAttributeAuthorConditionEditing)? = nil
    @State private var deleteReview = false
    @Environment(\.dismiss) private var dismiss
    private var editable: Bool { coordinator.canEdit && row.sourceIsSupported }
    var body: some View {
        Form {
            Section {
                CYHeroHeader(verbatim: row.label.isEmpty ? nativeAttributeText("nativeAttribute.add") : row.label) {
                    NativeAttributeCover(seed: row.key.isEmpty ? "attribute" : row.key, symbol: "slider.horizontal.3")
                }
            }.e1HeroRow()
            if let issue = coordinator.issue {
                Section {
                    Text(verbatim: nativeAttributeText(issue))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                TextField(nativeAttributeText("nativeAttribute.label"), text: $row.label).accessibilityIdentifier("nativeAttribute.label")
                TextField(nativeAttributeText("nativeAttribute.key"), text: $row.key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .disabled(row.existingKey != nil).accessibilityIdentifier("nativeAttribute.key")
                Picker(nativeAttributeText("nativeAttribute.type"), selection: $row.keyType) {
                    ForEach(["counter","flag","relation","tag"], id: \.self) { type in Text(verbatim: nativeAttributeText("nativeAttribute.type.\(type)")).tag(type) }
                }.disabled(row.existingKey != nil)
                Picker(nativeAttributeText("nativeAttribute.scope"), selection: $row.scope) {
                    ForEach(["run","party","deployment"], id: \.self) { scope in Text(verbatim: nativeAttributeText("nativeAttribute.scope.\(scope)")).tag(scope) }
                }.disabled(row.existingKey != nil)
                if row.existingKey != nil {
                    Text(verbatim: nativeAttributeText("nativeAttribute.immutable"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: { attributeHeader("nativeAttribute.identity") }
            .disabled(!editable)
            if row.isDefinition {
                Section {
                    Text(verbatim: nativeAttributeText(coordinator.localDraftOnly ? "nativeAttribute.localDraftNotice" : coordinator.usesVersionedDefinitions ? "nativeAttribute.versionedSaveNotice" : "nativeAttribute.extensionLocalOnly"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    number(nativeAttributeText("nativeAttribute.initial"), text: $row.initial)
                    number(nativeAttributeText("nativeAttribute.minimum"), text: $row.minimum)
                    number(nativeAttributeText("nativeAttribute.maximum"), text: $row.maximum)
                } header: { attributeHeader("nativeAttribute.range") }
                .disabled(!editable)
                Section {
                    Picker(nativeAttributeText("nativeAttribute.display"), selection: $row.display) {
                        ForEach(["bar","number","icon","hidden"], id: \.self) { mode in Text(verbatim: nativeAttributeText("nativeAttribute.display.\(mode)")).tag(mode) }
                    }
                    TextField(nativeAttributeText("nativeAttribute.color"), text: $row.color).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(nativeAttributeText("nativeAttribute.icon"), text: $row.icon).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle(nativeAttributeText("nativeAttribute.visible"), isOn: $row.visible)
                    Picker(nativeAttributeText("nativeAttribute.persistScope"), selection: $row.persistScope) {
                        Text(verbatim: nativeAttributeText("nativeAttribute.persist.run")).tag("run")
                        Text(verbatim: nativeAttributeText("nativeAttribute.persist.topic")).tag("topic")
                    }
                    number(nativeAttributeText("nativeAttribute.sortOrder"), text: $row.sortOrder)
                } header: { attributeHeader("nativeAttribute.presentation") }
                .disabled(!editable)
                if row.isCounter {
                    Section {
                        ForEach($row.rules) { $rule in
                            NativeAttributeAuthorRuleForm(rule: $rule, binding: coordinator.binding,
                                registeredKeys: coordinator.draft?.rows.map(\.key) ?? [], conditionEditor: conditionEditor,
                                coordinator: coordinator, rowSnapshot: row)
                            Button(nativeAttributeText("nativeAttribute.copyRule")) { row.rules.append(rule.duplicate()) }
                                .disabled(row.rules.count >= 20)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .onDelete { row.rules.remove(atOffsets: $0) }
                        .onMove { row.rules.move(fromOffsets: $0, toOffset: $1) }
                        Button(nativeAttributeText("nativeAttribute.addRule")) { row.rules.append(.init()) }
                            .disabled(row.rules.count >= 20)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    } header: { attributeHeader("nativeAttribute.rules") }
                    .disabled(!editable)
                }
                Section { NativeAttributeAuthorPreview(row: row) } header: { attributeHeader("nativeAttribute.preview") }
            } else {
                Section {
                    number(nativeAttributeText("nativeAttribute.initial"), text: $row.initial)
                    Text(verbatim: nativeAttributeText("nativeAttribute.registrationScopeNotice"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.disabled(!editable)
            }
            Section {
                if !row.sourceIsSupported { Text(verbatim: nativeAttributeText("nativeAttribute.unsupported")).cyText(.body).fixedSize(horizontal: false, vertical: true) }
                if row.unsupportedReason != nil && row.sourceIsSupported { Text(verbatim: nativeAttributeText("nativeAttribute.invalid")).cyText(.body).fixedSize(horizontal: false, vertical: true) }
                CYPillButton(verbatim: nativeAttributeText("nativeAttribute.keepChanges"), systemImage: "checkmark.circle") { if coordinator.replace(row) { dismiss() } }
                    .disabled(!editable || row.unsupportedReason != nil)
                    .accessibilityIdentifier("nativeAttribute.keepChanges")
                    .e1ActionRow()
                if row.existingKey == nil {
                    Button(nativeAttributeText("nativeAttribute.removeLocal"), role: .destructive) { coordinator.removeUnsaved(row.id); dismiss() }
                        .disabled(!coordinator.canEdit)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                } else if !coordinator.localDraftOnly {
                    Button(nativeAttributeText("nativeAttribute.checkDelete"), role: .destructive) { deleteReview = true }
                        .disabled(!coordinator.canDelete)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("nativeAttribute.checkDelete")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyText(.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { if editable { EditButton() } }
        .confirmationDialog(nativeAttributeText("nativeAttribute.checkDelete"), isPresented: $deleteReview, titleVisibility: .visible) {
            Button(nativeAttributeText("nativeAttribute.readReferences"), role: .destructive) {
                Task { await coordinator.prepareDelete(row.key); dismiss() }
            }
            Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) {}
        } message: { Text(verbatim: nativeAttributeText("nativeAttribute.deleteCheckMessage")) }
        .onChange(of: row.keyType) { _, type in
            guard row.existingKey == nil else { return }
            let suffix = row.key.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).last.map(String.init) ?? ""
            row.key = (type == "flag" ? "clue" : type) + "." + suffix
            if row.isDefinition && (type == "flag" || type == "tag") { row.minimum = "0"; row.maximum = "1"; row.initial = "0" }
            if type != "counter" { row.rules = [] }
        }
        .onChange(of: row) { _, edited in if editable { coordinator.replace(edited) } }
    }
    private func number(_ title: String, text: Binding<String>) -> some View {
        LabeledContent { TextField(title, text: text).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).cyText(.numericBody) } label: { Text(verbatim: title) }
    }
}

@MainActor private struct NativeAttributeAuthorRuleForm: View {
    @Binding var rule: NativeAttributeAuthorRule
    let binding: NativeAttributeAuthorBinding
    let registeredKeys: [String]
    let conditionEditor: (any NativeAttributeAuthorConditionEditing)?
    let coordinator: NativeAttributeAuthorCoordinator
    let rowSnapshot: NativeAttributeAuthorRow
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Picker(nativeAttributeText("nativeAttribute.event"), selection: $rule.event) {
                ForEach(NativeAttributeAuthorRule.events, id: \.self) { event in Text(verbatim: nativeAttributeText("nativeAttribute.event.\(event)")).tag(event) }
            }
            Picker(nativeAttributeText("nativeAttribute.operation"), selection: $rule.operation) {
                ForEach(NativeAttributeAuthorRule.operations, id: \.self) { operation in Text(verbatim: nativeAttributeText("nativeAttribute.op.\(operation)")).tag(operation) }
            }
            if rule.needsValue {
                TextField(nativeAttributeText("nativeAttribute.value"), text: $rule.value)
                    .keyboardType(.numbersAndPunctuation)
                    .cyText(.numericBody)
            }
            if let editor = conditionEditor {
                NavigationLink("nativeAttribute.condition") {
                    let target = NativeAttributeAuthorConditionTarget(coordinator: coordinator, row: rowSnapshot, rule: rule)
                    editor.editor(condition: rule.condition, binding: binding, registeredKeys: registeredKeys,
                        isCurrent: { target.isCurrent }) { value in
                            guard target.save(value) else { return false }
                            rule.condition = value
                            return true
                        }
                }
            } else {
                Text(verbatim: nativeAttributeText("nativeAttribute.conditionPreserved"))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor private struct NativeAttributeAuthorPreview: View {
    let row: NativeAttributeAuthorRow
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: nativeAttributeText("nativeAttribute.declarationPreview"))
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if row.visible && row.display != "hidden" {
                HStack {
                    if row.display == "icon" { Image(systemName: "circle.fill").foregroundStyle(previewColor).accessibilityHidden(true) }
                    Text(verbatim: cyShownValue(row.label))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    Text(verbatim: cyShownValue(row.initial))
                        .cyText(.numericBody)
                        .foregroundStyle(previewColor)
                }
                if row.display == "bar", let lo = Double(row.minimum), let hi = Double(row.maximum), let value = Double(row.initial), lo < hi {
                    ProgressView(value: min(max(value - lo, 0), hi - lo), total: hi - lo)
                        .accessibilityLabel(Text(verbatim: row.label))
                        .accessibilityValue(Text(verbatim: "\(row.initial), \(row.minimum)…\(row.maximum)"))
                }
                if !row.icon.isEmpty {
                    Text(verbatim: row.icon)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(verbatim: nativeAttributeText("nativeAttribute.hiddenPreview"))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(previewColor)
        .accessibilityElement(children: .combine)
        // Registry icon names belong to the existing product catalog, not necessarily SF Symbols.
        // The preview never invents an icon mapping or runs SESSION_START/rules.
    }
    private var previewColor: Color {
        guard row.color.count == 7, row.color.first == "#", let rgb = UInt32(row.color.dropFirst(), radix: 16) else { return CYColor.textPrimary }
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }
}

private struct NativeAttributeCover: View {
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

private struct NativeAttributeThumb: View {
    let seed: String
    var symbol: String
    var body: some View {
        CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.sm)
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }
}

private func cyShownValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "—" }
    if trimmed.caseInsensitiveCompare("UNKNOWN") == .orderedSame { return "—" }
    return value
}
