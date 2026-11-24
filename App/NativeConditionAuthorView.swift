import SwiftUI

/// Mount inside the host's NavigationStack; no competing navigation or save service.
@MainActor struct NativeConditionAuthorView: View {
    @StateObject private var model: NativeConditionAuthorController
    private let reader: (any NativeConditionAuthorReadbackServing)?
    private let projectVisit: NativeAuthorProjectVisit?
    private let close: (() -> Void)?
    @State private var confirmingClose = false
    private func text(_ key: String) -> String { NSLocalizedString(key, tableName: "NativeConditionAuthor", bundle: .main, comment: "") }
    init(host: any NativeConditionAuthorDraftHosting, reader: (any NativeConditionAuthorReadbackServing)? = nil,
         projectVisit: NativeAuthorProjectVisit? = nil, close: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: NativeConditionAuthorController(host: host)); self.reader = reader
        self.projectVisit = projectVisit; self.close = close
    }
    var body: some View {
        List {
            Section {
                CYHeroHeader("nativeCondition.title") {
                    CYCoverArt(seed: "nativeCondition.title", symbol: "arrow.triangle.branch", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .accessibilityHidden(true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if let document = model.document {
                if !model.canEdit {
                    Section { CYStatusChip("nativeCondition.readOnly", tone: .neutral, systemImage: "lock") }
                }
                if document.surface == .routeGraph {
                    branches("edges", fallback: false)
                    branches("fallbacks", fallback: true)
                } else if document.surface == .componentCheck {
                    NativeComponentAuthorCheckFields(model: model)
                } else {
                    NativeConditionAuthorExpressionSection(model: model, path: .init(), effect: document.surface == .templateEffects || document.surface == .componentEffects)
                }
                Section {
                    NavigationLink { NativeConditionAuthorPreview(model: model, authoritative: false) } label: {
                        CYListRow("nativeCondition.preview", trailing: .none) { CYRowIcon(systemImage: "eye") }
                    }
                    if reader != nil {
                        CYPillButton("nativeCondition.readAuthoritative", style: .secondary) { if let reader { Task { await model.read(using: reader) } } }
                            .disabled(document.hasChanges)
                    }
                    if model.session?.authoritative != nil {
                        NavigationLink { NativeConditionAuthorPreview(model: model, authoritative: true) } label: {
                            CYListRow("nativeCondition.authoritative", trailing: .none) { CYRowIcon(systemImage: "checkmark.seal") }
                        }
                    }
                }
                if !model.issues.isEmpty {
                    Section {
                        ForEach(model.issues) { issue in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                CYStatusChip(LocalizedStringKey("nativeCondition.issue." + issue.code), tone: .warning, systemImage: "exclamationmark.triangle")
                                Text(verbatim: issue.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : issue.path)
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !issue.detail.isEmpty {
                                    Text(verbatim: issue.detail)
                                        .cyText(.meta)
                                        .foregroundStyle(CYColor.textTertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }.accessibilityElement(children: .combine)
                        }
                    } header: { CYSectionHeader("nativeCondition.validation") }
                }
                Section {
                    CYPillButton("nativeCondition.saveDraft", action: model.save)
                        .disabled(!model.canEdit || model.issues.count > 0 || !document.hasChanges)
                        .accessibilityIdentifier("nativeCondition.saveOriginalDraft")
                    if model.session?.state == .localSaved {
                        CYStatusChip("nativeCondition.localSaved", tone: .success, systemImage: "checkmark.circle")
                    }
                } footer: { Text("nativeCondition.originalFlow") }
            } else {
                Section { CYEmptyState(systemImage: "doc.text", "nativeCondition.unavailable", kind: .projects) }
            }
            if let key = model.errorKey {
                Section { CYStatusChip(LocalizedStringKey(key), tone: .danger, systemImage: "exclamationmark.triangle") }
            }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .cyAnimation(value: model.revision)
        .toolbar {
            ToolbarItem { EditButton().disabled(!model.canEdit) }
            if close != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(text("nativeCondition.close")) {
                        if model.document?.hasChanges == true { confirmingClose = true }
                        else { finishClose() }
                    }.accessibilityIdentifier("nativeCondition.closeProjectChild")
                }
            }
        }
        .confirmationDialog(text("nativeCondition.discardTitle"), isPresented: $confirmingClose, titleVisibility: .visible) {
            Button(text("nativeCondition.discardAndClose"), role: .destructive) { finishClose() }
            Button(text("nativeCondition.keepEditing"), role: .cancel) {}
        } message: { Text(verbatim: text("nativeCondition.discardMessage")) }
        .onAppear {
            model.refresh()
            let owner = model
            projectVisit?.onRetire { [weak owner] in owner?.retire() }
        }
        .accessibilityIdentifier("nativeCondition.author")
        .cyDomainScreen(.topicEditor)
    }
    private func finishClose() { model.retire(); close?() }
    @ViewBuilder private func branches(_ key: String, fallback: Bool) -> some View {
        let path = NativeConditionAuthorPath().field(key)
        let rows = model.value(path)?.nativeConditionArray ?? []
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                NavigationLink {
                    NativeConditionAuthorBranchView(model: model, path: path.index(index), fallback: fallback)
                } label: {
                    let fields = row.nativeConditionObject ?? [:]
                    let raw = fields["id"]?.nativeConditionText ?? String(index + 1)
                    let shown = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
                    let from = fields["fromNodeId"]?.nativeConditionInteger.map(String.init) ?? "—"
                    let to = fields["toNodeId"]?.nativeConditionInteger.map(String.init) ?? "—"
                    CYListRow(verbatim: shown, meta: "\(from) → \(to)", trailing: .none) {
                        CYCoverArt(seed: shown, symbol: "arrow.triangle.branch", showsDebugLabel: false, cornerRadius: CYRadius.sm)
                            .frame(width: 40, height: 40)
                            .accessibilityHidden(true)
                    }
                }
            }.onDelete { model.remove($0, from: path) }.onMove { model.move($0, to: $1, in: path) }
            Button("nativeCondition.addBranch") {
                let row: ProjectEditJSON = .object(fallback ? [:] : ["id": .string(""), "trigger": .object(["type": .string(""), "outcomeCode": .string("")]), "conditions": .array([]), "effects": .array([])])
                if model.value(path) == nil { model.setField(key, at: .init(), to: .array([row])) } else { model.append(row, to: path) }
            }.disabled(!model.canEdit || rows.count >= 1024)
        } header: {
            CYSectionHeader(LocalizedStringKey(fallback ? "nativeCondition.fallbacks" : "nativeCondition.branches"))
        }
        .deleteDisabled(!model.canEdit).moveDisabled(!model.canEdit)
    }
}

@MainActor private struct NativeConditionAuthorBranchView: View {
    @ObservedObject var model: NativeConditionAuthorController
    let path: NativeConditionAuthorPath
    let fallback: Bool
    var body: some View {
        Form {
            Section {
                CYHeroHeader("nativeCondition.branch")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if let value = model.value(path), let row = value.nativeConditionObject {
                Section {
                    if !fallback { TextField("nativeCondition.field.id", text: text("id", row)) }
                    selection("fromNodeId", row, options: model.catalog?.nodes ?? [], integer: true)
                    selection("toNodeId", row, options: model.catalog?.nodes ?? [], integer: true)
                    if !fallback {
                        selection("type", row["trigger"]?.nativeConditionObject ?? [:], options: model.catalog?.triggers ?? [], integer: false, trigger: true)
                        let source = row["fromNodeId"]?.nativeConditionInteger.map(String.init) ?? ""
                        let trigger = row["trigger"]?.nativeConditionObject?["type"]?.nativeConditionText ?? ""
                        let outcomes = (model.catalog?.sourceOutcomes[source] ?? []).filter { $0.triggerType == trigger }.map { NativeConditionAuthorOption(id: $0.code, label: $0.label) }
                        selection("outcomeCode", row["trigger"]?.nativeConditionObject ?? [:], options: outcomes, integer: false, trigger: true)
                    }
                    ForEach(["priority", "weight", "maxVisits"], id: \.self) { key in
                        TextField(LocalizedStringKey("nativeCondition.field." + key), text: text(key, row, integer: true)).keyboardType(.numbersAndPunctuation)
                            .contextMenu { Button("nativeCondition.unset") { model.removeField(key, at: path) } }
                    }
                    ForEach(["once", "allowLoop"], id: \.self) { key in
                        Toggle(LocalizedStringKey("nativeCondition.field." + key), isOn: Binding(get: { row[key] == .bool(true) }, set: { model.setField(key, at: path, to: .bool($0)) }))
                    }
                }.disabled(!model.canEdit)
                if !fallback {
                    if row["conditions"] == nil {
                        Button("nativeCondition.addCondition") { model.setField("conditions", at: path, to: .array([])) }.disabled(!model.canEdit)
                    } else { NativeConditionAuthorExpressionSection(model: model, path: path.field("conditions"), effect: false) }
                }
                if row["effects"] == nil {
                    Button("nativeCondition.addEffect") { model.setField("effects", at: path, to: .array([])) }.disabled(!model.canEdit)
                } else { NativeConditionAuthorExpressionSection(model: model, path: path.field("effects"), effect: true) }
            } else { CYEmptyState(systemImage: "doc.text", "nativeCondition.unavailable", kind: .projects) }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { EditButton().disabled(!model.canEdit) }
    }
    private func text(_ key: String, _ row: [String: ProjectEditJSON], integer: Bool = false) -> Binding<String> {
        Binding(get: { row[key]?.nativeConditionText ?? row[key]?.nativeConditionNumber.map { NSDecimalNumber(decimal: $0).stringValue } ?? "" }, set: { value in
            if integer {
                model.setField(key, at: path, to: Int64(value).map { .number(Decimal($0)) } ?? .string(value))
            } else { model.setField(key, at: path, to: .string(value)) }
        })
    }
    private func selection(_ key: String, _ row: [String: ProjectEditJSON], options: [NativeConditionAuthorOption], integer: Bool, trigger: Bool = false) -> some View {
        let current = row[key]?.nativeConditionText ?? row[key]?.nativeConditionInteger.map(String.init) ?? ""
        return Picker(LocalizedStringKey("nativeCondition.field." + key), selection: Binding(get: { current }, set: { value in
            let entry: ProjectEditJSON = integer ? Int64(value).map { .number(Decimal($0)) } ?? .string(value) : .string(value)
            if trigger {
                let original = model.value(path)?.nativeConditionObject?["trigger"]?.nativeConditionObject ?? [:]
                var object = original; object[key] = entry; model.setField("trigger", at: path, to: .object(object))
            } else { model.setField(key, at: path, to: entry) }
        })) {
            if !options.contains(where: { $0.id == current }) { Text(verbatim: current.isEmpty ? "—" : current).tag(current) }
            ForEach(options) { option in Text(verbatim: option.label).tag(option.id) }
        }
    }
}

@MainActor struct NativeConditionAuthorExpressionSection: View {
    @ObservedObject var model: NativeConditionAuthorController
    let path: NativeConditionAuthorPath
    let effect: Bool
    var body: some View {
        Section {
            if let value = model.value(path) {
                if let array = value.nativeConditionArray {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, value in link(value, at: path.index(index)) }
                        .onDelete { model.remove($0, from: path) }.onMove { model.move($0, to: $1, in: path) }
                    Button(effect ? "nativeCondition.addEffect" : "nativeCondition.addCondition") {
                        model.append(NativeConditionAuthorFields.blank(operation: effect ? "SET" : "EQ", effect: effect), to: path)
                    }.disabled(!model.canEdit)
                } else { link(value, at: path) }
            }
        } header: {
            CYSectionHeader(LocalizedStringKey(effect ? "nativeCondition.effects" : "nativeCondition.conditions"))
        }
        .deleteDisabled(!model.canEdit).moveDisabled(!model.canEdit)
    }
    private func link(_ value: ProjectEditJSON, at path: NativeConditionAuthorPath) -> some View {
        let op = value.nativeConditionArray != nil ? "ALL_OF_ARRAY" : value.nativeConditionObject?["op"]?.nativeConditionText ?? "UNKNOWN"
        let symbol = effect ? "sparkles" : "line.3.horizontal.decrease.circle"
        return NavigationLink {
            NativeConditionAuthorNodeView(model: model, path: path, effect: effect)
        } label: {
            if let title = NativeComponentAuthorLabels.operations[op] {
                CYListRow(verbatim: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : title, trailing: .none) { CYRowIcon(systemImage: symbol) }
            } else {
                CYListRow(LocalizedStringKey("nativeCondition.op." + op), trailing: .none) { CYRowIcon(systemImage: symbol) }
            }
        }
    }
}

@MainActor private struct NativeConditionAuthorNodeView: View {
    @ObservedObject var model: NativeConditionAuthorController
    let path: NativeConditionAuthorPath
    let effect: Bool
    @State private var showFields = false
    @State private var pendingOperation: String?
    private var op: String { model.value(path)?.nativeConditionObject?["op"]?.nativeConditionText ?? "" }
    var body: some View {
        Form {
            Section {
                CYHeroHeader(LocalizedStringKey(effect ? "nativeCondition.effect" : "nativeCondition.condition"))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if let value = model.value(path) {
                if value.nativeConditionArray != nil {
                    NativeConditionAuthorExpressionSection(model: model, path: path, effect: effect)
                } else {
                    Section {
                        Picker("nativeCondition.operation", selection: Binding(get: { op }, set: { pendingOperation = $0 })) {
                            let registered = NativeConditionAuthorValidation.registeredOperations.filter { model.catalog?.rpg?.supportedOperations.contains($0) == true }
                            let operations = (effect ? (model.catalog?.component == nil ? NativeConditionAuthorValidation.effectOperations : NativeConditionAuthorValidation.componentEffectOperations) : NativeConditionAuthorValidation.conditionOperations + registered)
                                .filter { (model.document?.surface != .attributeCondition && model.catalog?.component == nil) || $0 != "CONSUME_ITEM" }
                            if !operations.contains(op) { Text(verbatim: op).tag(op) }
                            ForEach(operations, id: \.self) { operation in
                                if let title = NativeComponentAuthorLabels.operations[operation] { Text(verbatim: title).tag(operation) }
                                else { Text(LocalizedStringKey("nativeCondition.op." + operation)).tag(operation) }
                            }
                        }.disabled(!model.canEdit)
                        Button("nativeCondition.editFields") { showFields = true }.disabled(!model.canEdit)
                    }
                    if ["ALL_OF", "ANY_OF"].contains(op) {
                        NativeConditionAuthorExpressionSection(model: model, path: path.field("children"), effect: false)
                    } else if op == "NOT" {
                        NativeConditionAuthorExpressionSection(model: model, path: path.field("child"), effect: false)
                    } else if op == "RANDOM_CHOICE" {
                        choices(value)
                    }
                    Section {
                        Text(verbatim: NativeConditionAuthorPresentation.json(value))
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else { CYEmptyState(systemImage: "doc.text", "nativeCondition.unavailable", kind: .projects) }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { EditButton().disabled(!model.canEdit) }
        .sheet(isPresented: $showFields) { Group {
            if let value = model.value(path), let revision = model.document?.revision {
                NavigationStack { NativeConditionAuthorFieldForm(model: model, path: path, original: value, capturedRevision: revision, effect: effect) }
            }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("nativeCondition.changeOperation", isPresented: Binding(get: { pendingOperation != nil }, set: { if !$0 { pendingOperation = nil } })) {
            Button("nativeCondition.replaceOperation", role: .destructive) {
                if let operation = pendingOperation, let original = model.value(path) {
                    _ = model.replace(path, expected: original, with: NativeConditionAuthorFields.changingOperation(original, to: operation, effect: effect))
                }; pendingOperation = nil
            }
        } message: { Text("nativeCondition.changeOperationDetail") }
    }
    @ViewBuilder private func choices(_ value: ProjectEditJSON) -> some View {
        let choicesPath = path.field("choices"), rows = value.nativeConditionObject?["choices"]?.nativeConditionArray ?? []
        Section {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, _ in
                NavigationLink {
                    NativeConditionAuthorChoiceView(model: model, path: choicesPath.index(i))
                } label: {
                    CYListRow("nativeCondition.choice", trailing: .value(String(i + 1))) { CYRowIcon(systemImage: "square.grid.2x2") }
                }
            }.onDelete { model.remove($0, from: choicesPath) }.onMove { model.move($0, to: $1, in: choicesPath) }
            Button("nativeCondition.addChoice") { model.append(.object(["weight": .number(1), "effects": .array([])]), to: choicesPath) }
                .disabled(!model.canEdit || rows.count >= 32)
        } header: { CYSectionHeader("nativeCondition.choices") }
        .deleteDisabled(!model.canEdit).moveDisabled(!model.canEdit)
    }
}

@MainActor private struct NativeConditionAuthorChoiceView: View {
    @ObservedObject var model: NativeConditionAuthorController
    let path: NativeConditionAuthorPath
    var body: some View {
        Form {
            Section {
                CYHeroHeader("nativeCondition.choice")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                TextField("nativeCondition.field.weight", text: Binding(get: {
                    model.value(path)?.nativeConditionObject?["weight"]?.nativeConditionText ?? model.value(path)?.nativeConditionObject?["weight"]?.nativeConditionInteger.map(String.init) ?? ""
                }, set: { model.setField("weight", at: path, to: Int64($0).map { .number(Decimal($0)) } ?? .string($0)) })).keyboardType(.numberPad)
            }.disabled(!model.canEdit)
            NativeConditionAuthorExpressionSection(model: model, path: path.field("effects"), effect: true)
        }
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { EditButton().disabled(!model.canEdit) }
    }
}

enum NativeConditionAuthorPresentation {
    static func json(_ value: ProjectEditJSON) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "" }; return String(decoding: data, as: UTF8.self)
    }
}

@MainActor private struct NativeConditionAuthorPreview: View {
    @ObservedObject var model: NativeConditionAuthorController
    let authoritative: Bool
    var body: some View {
        List {
            if model.isCurrent, let document = authoritative ? model.session?.authoritative : model.document {
                Section {
                    CYHeroHeader("nativeCondition.preview")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    CYStatusChip(authoritative ? "nativeCondition.authoritative" : "nativeCondition.declarationPreview", tone: authoritative ? .info : .neutral, systemImage: authoritative ? "checkmark.seal" : "doc.text")
                }
                Section {
                    Text(verbatim: (try? document.serialized()) ?? document.original)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else { CYEmptyState(systemImage: "doc.text", "nativeCondition.unavailable", kind: .projects) }
        }
        .cyGroupedSurface()
        .cyHeroScreen()
    }
}
