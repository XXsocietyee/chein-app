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
    @Environment(\.themeDomain) private var domain
    @State var coordinator: NativeAttributeAuthorCoordinator
    var conditionEditor: (any NativeAttributeAuthorConditionEditing)? = nil
    var moduleReportRenderer: (any NativeAttributeAuthorModuleReportRendering)? = nil
    var onSourceRetired: ((NativeAttributeAuthorBinding) -> Void)? = nil
    var close: (() -> Void)? = nil
    @State private var projectReview: NativeAttributeAuthorProjectAction?
    @State private var leaving = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section { CYHeroHeader(verbatim: nativeAttributeText("nativeAttribute.title")).listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            Section {
                LabeledContent(nativeAttributeText("nativeAttribute.topic"), value: String(coordinator.binding.topicID))
                LabeledContent(nativeAttributeText("nativeAttribute.version"), value: String(coordinator.draft?.binding.sourceConfigVersion ?? coordinator.binding.sourceConfigVersion))
                if coordinator.localDraftOnly { Text(nativeAttributeText("nativeAttribute.localDraftNotice")).font(Theme.Font.label).accessibilityIdentifier("nativeAttribute.localOnly") }
                if coordinator.binding.isLocked { Label(nativeAttributeText("nativeAttribute.frozen"), systemImage: "lock.fill") }
                if coordinator.busy { ProgressView().accessibilityLabel(Text(nativeAttributeText("nativeAttribute.loading"))) }
                if let issue = coordinator.issue {
                    Text(verbatim: nativeAttributeText(issue)).foregroundStyle(Theme.Color.textSecondary(in: domain)).accessibilityIdentifier("nativeAttribute.issue")
                }
                if coordinator.phase == .confirmed && coordinator.projectResult == nil {
                    Label(nativeAttributeText("nativeAttribute.confirmed"), systemImage: "checkmark.circle")
                }
            }
            // Local file inspection only (Qmod import): no coordinator, service or transport is passed in,
            // so opening it can never issue a request. It sits behind the same author entry gate.
            Section {
                NavigationLink { QmodAuthorImportView() } label: { Label("qmodImport.title", systemImage: "doc.badge.plus") }
                    .accessibilityIdentifier("nativeAttribute.qmodImport")
            }
            if let draft = coordinator.draft {
                Section(nativeAttributeText("nativeAttribute.definitions")) {
                    ForEach(draft.rows) { row in
                        NavigationLink {
                            NativeAttributeAuthorForm(row: row, coordinator: coordinator, conditionEditor: conditionEditor)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Space.s1) {
                                Text(verbatim: row.label.isEmpty ? row.key : row.label).font(Theme.Font.sectionTitle)
                                Text(verbatim: row.key).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                                if row.isDefinition {
                                    Text(verbatim: "\(row.minimum)…\(row.maximum) · \(row.initial)").font(Theme.Font.label)
                                } else { Text(nativeAttributeText("nativeAttribute.legacy")).font(Theme.Font.label) }
                            }
                            .accessibilityElement(children: .combine)
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
                        Button { _ = coordinator.add() } label: { Label(nativeAttributeText("nativeAttribute.add"), systemImage: "plus") }
                            .accessibilityIdentifier("nativeAttribute.add")
                        if coordinator.usesVersionedDefinitions {
                            CYPillButton(verbatim: nativeAttributeText("nativeAttribute.addBasicRegistration"), style: .secondary) { _ = coordinator.add(registrationOnly: true) }
                            Text(nativeAttributeText(coordinator.localDraftOnly ? "nativeAttribute.localDraftNotice" : "nativeAttribute.versionedSaveNotice")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                        } else {
                            CYPillButton(verbatim: nativeAttributeText("nativeAttribute.addDefinitionDraft"), style: .secondary) { _ = coordinator.add(registrationOnly: false) }
                            Text(nativeAttributeText("nativeAttribute.extensionLocalOnly")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                        }
                    }
                }
                if !coordinator.binding.isLocked && !coordinator.localDraftOnly {
                    Section {
                        CYPillButton(verbatim: nativeAttributeText("nativeAttribute.checkSave")) { Task { await coordinator.prepareSave() } }
                            .disabled(!coordinator.canSave).accessibilityIdentifier("nativeAttribute.checkSave")
                        if coordinator.pending != nil {
                            CYPillButton(verbatim: nativeAttributeText("nativeAttribute.readback"), style: .secondary) { Task { await coordinator.readback() } }
                                .disabled(coordinator.busy).accessibilityIdentifier("nativeAttribute.readback")
                        }
                        if coordinator.canRecoverUnsentDraft && coordinator.draft?.binding != coordinator.binding {
                            Button(nativeAttributeText("nativeAttribute.restoreLocal")) { Task { await coordinator.recoverUnsentDraft() } }.disabled(coordinator.busy)
                        }
                    }
                    projectFlowSection
                }
            }
            if let check = coordinator.publishCheckResult {
                Section(nativeAttributeText("nativeAttribute.publishCheck")) {
                    ForEach(check.issues) { finding in
                        NativeAttributeAuthorDiagnosticIssueView(issue: finding)
                    }
                    if check.issues.isEmpty { Text(nativeAttributeText("nativeAttribute.noPublishIssues")) }
                    Text(nativeAttributeText("nativeAttribute.savedSourceCheck")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                }
            }
            if let preflight = coordinator.modulePreflightResult {
                Section(nativeAttributeText("nativeAttribute.modulePreflight")) {
                    if let renderer = moduleReportRenderer { renderer.view(preflight) }
                    else {
                        LabeledContent(nativeAttributeText("nativeAttribute.topic"), value: String(preflight.topicID))
                        LabeledContent(nativeAttributeText("nativeAttribute.version"), value: String(preflight.configVersion))
                        Label(nativeAttributeText(preflight.ready ? "nativeAttribute.moduleNoErrors" : "nativeAttribute.moduleHasErrors"), systemImage: preflight.ready ? "info.circle" : "exclamationmark.circle")
                        ForEach(preflight.issues) { NativeAttributeAuthorDiagnosticIssueView(issue: $0) }
                    }
                    Text(nativeAttributeText("nativeAttribute.diagnosticOnly")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                    Text(nativeAttributeText("nativeAttribute.savedSourceCheck")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                }
            }
            if let refs = coordinator.referenceReadback {
                Section(nativeAttributeText("nativeAttribute.references")) {
                    ForEach(Array(refs.positions.enumerated()), id: \.offset) { _, position in Text(verbatim: position) }
                    if let reason = refs.incompleteReason { Text(verbatim: nativeAttributeText(reason)) }
                    if refs.permitsDelete { Text(nativeAttributeText("nativeAttribute.referenceClear")) }
                }
            }
            if coordinator.phase == .review {
                Section(nativeAttributeText("nativeAttribute.review")) {
                    ForEach(Array(coordinator.warnings.enumerated()), id: \.offset) { _, warning in Text(verbatim: nativeAttributeText(warning)) }
                    Text(nativeAttributeText(coordinator.reviewDeletesKey == nil ? "nativeAttribute.saveReview" : "nativeAttribute.deleteReview"))
                    CYPillButton(verbatim: nativeAttributeText("nativeAttribute.confirm")) { Task { await coordinator.confirm() } }
                        .accessibilityIdentifier("nativeAttribute.confirm")
                    Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) { coordinator.cancelReview() }
                }
            }
        }
        .font(Theme.Font.body).tint(Theme.Color.accent(in: domain)).cyGroupedSurface().cyHeroScreen()
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
        } message: { Text(nativeAttributeText("nativeAttribute.leaveMessage")) }
        .confirmationDialog(nativeAttributeText("nativeAttribute.projectReview"), isPresented: Binding(get: { projectReview != nil }, set: { if !$0 { projectReview = nil } }), titleVisibility: .visible) {
            if let action = projectReview {
                Button(nativeAttributeText("nativeAttribute.action.\(action.rawValue)")) {
                    projectReview = nil; Task { await coordinator.performProjectAction(action) }
                }
            }
            Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) { projectReview = nil }
        } message: { Text(nativeAttributeText("nativeAttribute.originalFlow")) }
        .task { await coordinator.load() }
        .onChange(of: coordinator.retiredSourceBinding) { _, next in if let next { onSourceRetired?(next) } }
    }
    private var projectFlowSection: some View {
        Section(nativeAttributeText("nativeAttribute.projectFlow")) {
            Button(nativeAttributeText("nativeAttribute.publishCheck")) { Task { await coordinator.readPublishCheck() } }
                .disabled(!coordinator.canReadPublishCheck).accessibilityIdentifier("nativeAttribute.publishCheck")
            Button(nativeAttributeText("nativeAttribute.modulePreflight")) { Task { await coordinator.readModulePreflight() } }
                .disabled(!coordinator.canReadModulePreflight).accessibilityIdentifier("nativeAttribute.modulePreflight")
            ForEach([NativeAttributeAuthorProjectAction.saveDraft, .preview, .publish], id: \.rawValue) { action in
                Button(nativeAttributeText("nativeAttribute.action.\(action.rawValue)")) { projectReview = action }
                    .disabled(!coordinator.canUseProjectFlow)
                    .accessibilityIdentifier("nativeAttribute.action.\(action.rawValue)")
            }
            Text(nativeAttributeText("nativeAttribute.originalFlow")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
        }
    }
    private func closeAuthor() {
        // Capture a real confirmed source-retirement result before retire clears presentation.
        // A close event alone never asks the host to reload or treats UNKNOWN as acknowledged.
        if let retired = coordinator.retiredSourceBinding { onSourceRetired?(retired) }
        if let close { close() } else { coordinator.retire(); dismiss() }
    }
}

/// Both original diagnostics use the same native row. Field/code/message come from the
/// server; no client code-to-field mapping or second validation engine is introduced.
@MainActor private struct NativeAttributeAuthorDiagnosticIssueView: View {
    let issue: NativeAttributeAuthorPublishIssue
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            Label(nativeAttributeText(issue.level == "error" ? "nativeAttribute.checkError" : "nativeAttribute.checkWarning"), systemImage: issue.level == "error" ? "exclamationmark.circle" : "exclamationmark.triangle")
            Text(verbatim: issue.message)
            LabeledContent(nativeAttributeText("nativeAttribute.issueCode"), value: issue.code)
            if let field = issue.field { LabeledContent(nativeAttributeText("nativeAttribute.issueField"), value: field) }
            if let node = issue.nodeID { LabeledContent(nativeAttributeText("nativeAttribute.node"), value: String(node)) }
        }.accessibilityElement(children: .combine)
    }
}

@MainActor struct NativeAttributeAuthorForm: View {
    @Environment(\.themeDomain) private var domain
    @State var row: NativeAttributeAuthorRow
    let coordinator: NativeAttributeAuthorCoordinator
    var conditionEditor: (any NativeAttributeAuthorConditionEditing)? = nil
    @State private var deleteReview = false
    @Environment(\.dismiss) private var dismiss
    private var editable: Bool { coordinator.canEdit && row.sourceIsSupported }
    var body: some View {
        Form {
            if let issue = coordinator.issue { Section { Text(verbatim: nativeAttributeText(issue)) } }
            Section(nativeAttributeText("nativeAttribute.identity")) {
                TextField(nativeAttributeText("nativeAttribute.label"), text: $row.label).accessibilityIdentifier("nativeAttribute.label")
                TextField(nativeAttributeText("nativeAttribute.key"), text: $row.key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .disabled(row.existingKey != nil).accessibilityIdentifier("nativeAttribute.key")
                Picker(nativeAttributeText("nativeAttribute.type"), selection: $row.keyType) {
                    ForEach(["counter","flag","relation","tag"], id: \.self) { type in Text(nativeAttributeText("nativeAttribute.type.\(type)")).tag(type) }
                }.disabled(row.existingKey != nil)
                Picker(nativeAttributeText("nativeAttribute.scope"), selection: $row.scope) {
                    ForEach(["run","party","deployment"], id: \.self) { scope in Text(nativeAttributeText("nativeAttribute.scope.\(scope)")).tag(scope) }
                }.disabled(row.existingKey != nil)
                if row.existingKey != nil { Text(nativeAttributeText("nativeAttribute.immutable")).font(Theme.Font.label) }
            }.disabled(!editable)
            if row.isDefinition {
                Section { Text(nativeAttributeText(coordinator.localDraftOnly ? "nativeAttribute.localDraftNotice" : coordinator.usesVersionedDefinitions ? "nativeAttribute.versionedSaveNotice" : "nativeAttribute.extensionLocalOnly")) }
                Section(nativeAttributeText("nativeAttribute.range")) {
                    number(nativeAttributeText("nativeAttribute.initial"), text: $row.initial)
                    number(nativeAttributeText("nativeAttribute.minimum"), text: $row.minimum)
                    number(nativeAttributeText("nativeAttribute.maximum"), text: $row.maximum)
                }.disabled(!editable)
                Section(nativeAttributeText("nativeAttribute.presentation")) {
                    Picker(nativeAttributeText("nativeAttribute.display"), selection: $row.display) {
                        ForEach(["bar","number","icon","hidden"], id: \.self) { mode in Text(nativeAttributeText("nativeAttribute.display.\(mode)")).tag(mode) }
                    }
                    TextField(nativeAttributeText("nativeAttribute.color"), text: $row.color).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(nativeAttributeText("nativeAttribute.icon"), text: $row.icon).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle(nativeAttributeText("nativeAttribute.visible"), isOn: $row.visible)
                    Picker(nativeAttributeText("nativeAttribute.persistScope"), selection: $row.persistScope) {
                        Text(nativeAttributeText("nativeAttribute.persist.run")).tag("run")
                        Text(nativeAttributeText("nativeAttribute.persist.topic")).tag("topic")
                    }
                    number(nativeAttributeText("nativeAttribute.sortOrder"), text: $row.sortOrder)
                }.disabled(!editable)
                if row.isCounter {
                    Section(nativeAttributeText("nativeAttribute.rules")) {
                        ForEach($row.rules) { $rule in
                            NativeAttributeAuthorRuleForm(rule: $rule, binding: coordinator.binding,
                                registeredKeys: coordinator.draft?.rows.map(\.key) ?? [], conditionEditor: conditionEditor,
                                coordinator: coordinator, rowSnapshot: row)
                            Button(nativeAttributeText("nativeAttribute.copyRule")) { row.rules.append(rule.duplicate()) }.disabled(row.rules.count >= 20)
                        }
                        .onDelete { row.rules.remove(atOffsets: $0) }
                        .onMove { row.rules.move(fromOffsets: $0, toOffset: $1) }
                        Button(nativeAttributeText("nativeAttribute.addRule")) { row.rules.append(.init()) }.disabled(row.rules.count >= 20)
                    }.disabled(!editable)
                }
                Section(nativeAttributeText("nativeAttribute.preview")) { NativeAttributeAuthorPreview(row: row) }
            } else {
                Section {
                    number(nativeAttributeText("nativeAttribute.initial"), text: $row.initial)
                    Text(nativeAttributeText("nativeAttribute.registrationScopeNotice")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
                }.disabled(!editable)
            }
            Section {
                if !row.sourceIsSupported { Text(nativeAttributeText("nativeAttribute.unsupported")) }
                if row.unsupportedReason != nil && row.sourceIsSupported { Text(nativeAttributeText("nativeAttribute.invalid")) }
                CYPillButton(verbatim: nativeAttributeText("nativeAttribute.keepChanges")) { if coordinator.replace(row) { dismiss() } }
                    .disabled(!editable || row.unsupportedReason != nil)
                    .accessibilityIdentifier("nativeAttribute.keepChanges")
                if row.existingKey == nil {
                    Button(nativeAttributeText("nativeAttribute.removeLocal"), role: .destructive) { coordinator.removeUnsaved(row.id); dismiss() }.disabled(!coordinator.canEdit)
                } else if !coordinator.localDraftOnly {
                    Button(nativeAttributeText("nativeAttribute.checkDelete"), role: .destructive) { deleteReview = true }
                        .disabled(!coordinator.canDelete)
                        .accessibilityIdentifier("nativeAttribute.checkDelete")
                }
            }
        }
        .font(Theme.Font.body).tint(Theme.Color.accent(in: domain)).navigationTitle(row.label.isEmpty ? Text(nativeAttributeText("nativeAttribute.add")) : Text(verbatim: row.label))
        .toolbar { if editable { EditButton() } }
        .confirmationDialog(nativeAttributeText("nativeAttribute.checkDelete"), isPresented: $deleteReview, titleVisibility: .visible) {
            Button(nativeAttributeText("nativeAttribute.readReferences"), role: .destructive) {
                Task { await coordinator.prepareDelete(row.key); dismiss() }
            }
            Button(nativeAttributeText("nativeAttribute.cancel"), role: .cancel) {}
        } message: { Text(nativeAttributeText("nativeAttribute.deleteCheckMessage")) }
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
        LabeledContent { TextField(title, text: text).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) } label: { Text(title) }
    }
}

@MainActor private struct NativeAttributeAuthorRuleForm: View {
    @Environment(\.themeDomain) private var domain
    @Binding var rule: NativeAttributeAuthorRule
    let binding: NativeAttributeAuthorBinding
    let registeredKeys: [String]
    let conditionEditor: (any NativeAttributeAuthorConditionEditing)?
    let coordinator: NativeAttributeAuthorCoordinator
    let rowSnapshot: NativeAttributeAuthorRow
    var body: some View {
        VStack(alignment: .leading) {
            Picker(nativeAttributeText("nativeAttribute.event"), selection: $rule.event) {
                ForEach(NativeAttributeAuthorRule.events, id: \.self) { event in Text(nativeAttributeText("nativeAttribute.event.\(event)")).tag(event) }
            }
            Picker(nativeAttributeText("nativeAttribute.operation"), selection: $rule.operation) {
                ForEach(NativeAttributeAuthorRule.operations, id: \.self) { operation in Text(nativeAttributeText("nativeAttribute.op.\(operation)")).tag(operation) }
            }
            if rule.needsValue { TextField(nativeAttributeText("nativeAttribute.value"), text: $rule.value).keyboardType(.numbersAndPunctuation) }
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
            } else { Text(nativeAttributeText("nativeAttribute.conditionPreserved")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain)) }
        }
    }
}

@MainActor private struct NativeAttributeAuthorPreview: View {
    @Environment(\.themeDomain) private var domain
    let row: NativeAttributeAuthorRow
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            Text(nativeAttributeText("nativeAttribute.declarationPreview")).font(Theme.Font.label).foregroundStyle(Theme.Color.textSecondary(in: domain))
            if row.visible && row.display != "hidden" {
                HStack {
                    if row.display == "icon" { Image(systemName: "circle.fill").foregroundStyle(previewColor).accessibilityHidden(true) }
                    Text(verbatim: row.label)
                    Spacer()
                    Text(verbatim: row.initial).monospacedDigit().foregroundStyle(previewColor)
                }
                if row.display == "bar", let lo = Double(row.minimum), let hi = Double(row.maximum), let value = Double(row.initial), lo < hi {
                    ProgressView(value: min(max(value - lo, 0), hi - lo), total: hi - lo)
                        .accessibilityLabel(Text(verbatim: row.label)).accessibilityValue(Text(verbatim: "\(row.initial), \(row.minimum)…\(row.maximum)"))
                }
                if !row.icon.isEmpty { Text(verbatim: row.icon).font(Theme.Font.label) }
            } else { Text(nativeAttributeText("nativeAttribute.hiddenPreview")) }
        }
        .tint(previewColor)
        // Registry icon names belong to the existing product catalog, not necessarily SF Symbols.
        // The preview never invents an icon mapping or runs SESSION_START/rules.
    }
    private var previewColor: Color {
        guard row.color.count == 7, row.color.first == "#", let rgb = UInt32(row.color.dropFirst(), radix: 16) else { return .accentColor }
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }
}
