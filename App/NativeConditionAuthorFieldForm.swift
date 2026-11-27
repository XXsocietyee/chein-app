import SwiftUI

@MainActor struct NativeConditionAuthorFieldForm: View {
    @ObservedObject var model: NativeConditionAuthorController
    let path: NativeConditionAuthorPath
    let original: ProjectEditJSON
    let capturedRevision: UInt64
    let effect: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var candidate: [String: ProjectEditJSON]
    @State private var numericInputs: [String: String]
    @State private var error = false
    init(model: NativeConditionAuthorController, path: NativeConditionAuthorPath, original: ProjectEditJSON,
         capturedRevision: UInt64, effect: Bool) {
        self.model = model; self.path = path; self.original = original; self.capturedRevision = capturedRevision; self.effect = effect
        let row = original.nativeConditionObject ?? [:]
        _candidate = State(initialValue: row)
        _numericInputs = State(initialValue: row.reduce(into: [:]) { result, pair in
            if let number = pair.value.nativeConditionNumber { result[pair.key] = NSDecimalNumber(decimal: number).stringValue }
        })
    }
    private var operation: String { candidate["op"]?.nativeConditionText ?? "" }
    private var fields: [NativeConditionAuthorField] { NativeConditionAuthorFields.fields(operation: operation, effect: effect) }
    private var isCurrent: Bool {
        model.canEdit && model.document?.revision == capturedRevision && NativeConditionAuthorTree.exact(model.value(path), original)
    }
    var body: some View {
        Form {
            if model.isCurrent {
                Section { Text(LocalizedStringKey("nativeCondition.op." + operation)) }
                ForEach(fields) { field in
                    Section { input(field) }
                }
                if operation == "TIME_BETWEEN" { Section { Text("nativeCondition.epochWindow") } }
                if operation == "GRANT_BADGE" { Section { Text("nativeCondition.topicMedalOnly") } }
                if operation == "EMIT_EVENT" { Section { Text("nativeCondition.customEventOnly") } }
                if error { Section { Text("nativeCondition.fieldFailed").foregroundStyle(CYColor.dangerText) } }
                if !isCurrent { Section { Text("nativeCondition.unavailable") } }
            } else { Text("nativeCondition.unavailable") }
        }.navigationTitle("nativeCondition.editFields").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("nativeCondition.cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("nativeCondition.done", action: commit).disabled(!isCurrent) }
        }
    }
    private func string(_ key: String) -> Binding<String> {
        Binding(get: { candidate[key]?.nativeConditionText ?? candidate[key]?.nativeConditionInteger.map(String.init) ?? "" }, set: { candidate[key] = .string($0) })
    }
    @ViewBuilder private func input(_ field: NativeConditionAuthorField) -> some View {
        switch field.input {
        case .number, .integer:
            TextField(LocalizedStringKey("nativeCondition.field." + field.key), text: Binding(get: { numericInputs[field.key] ?? "" }, set: { numericInputs[field.key] = $0 }))
                .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .string:
            TextField(LocalizedStringKey("nativeCondition.field." + field.key), text: string(field.key), axis: .vertical)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        case .strings:
            NativeConditionAuthorStringsForm(values: Binding(get: { candidate[field.key]?.nativeConditionArray ?? [] }, set: { candidate[field.key] = .array($0) }))
        case .roles:
            ForEach(NativeConditionAuthorValidation.roles, id: \.self) { role in
                Toggle(LocalizedStringKey("nativeCondition.role." + role), isOn: Binding(get: {
                    candidate[field.key]?.nativeConditionArray?.contains(.string(role)) == true
                }, set: { enabled in
                    var values = candidate[field.key]?.nativeConditionArray ?? []
                    if enabled && !values.contains(.string(role)) { values.append(.string(role)) }
                    if !enabled { values.removeAll { $0 == .string(role) } }
                    candidate[field.key] = .array(values)
                }))
            }
        case .variable(let isString, let writable):
            let options = model.attributes.filter { $0.type == (isString ? .string : .number) && (!writable || $0.writable) }
                .filter { !writable || (!$0.key.hasPrefix("sys.passed.") && !$0.key.hasPrefix("sys.quest.") && !OriginalRpgGrowthFacts.reserved($0.key) && !NativeRpgEnvironmentTemplateDraft.conditionKeys.contains($0.key) && !OriginalRpgProgressConditions.reserved($0.key)) }
                .filter { !["ADD", "MIN", "MAX", "RESET", "CLAMP"].contains(operation) || model.catalog?.component?.dynamicCounters.contains($0.key) == true }
            picker(field.key, options: options.map { .init(id: $0.key, label: $0.label + " · " + $0.key) })
            if options.isEmpty { Text("nativeCondition.noAttributes").cyText(.bodyCompact) }
        case .node: picker(field.key, options: model.catalog?.nodes ?? [])
        case .item:
            let held = ["ITEM_HELD", "ITEM_ACQUIRED"].contains(operation)
            picker(field.key, options: (model.catalog?.items ?? []) + (held ? model.catalog?.medals ?? [] : []))
        case .medal: picker(field.key, options: model.catalog?.medals ?? [])
        case .edge:
            picker(field.key, options: model.edgeReferences)
        case .comparator:
            picker(field.key, options: NativeConditionAuthorValidation.comparisons.map { .init(id: $0, label: $0) })
        case .check: picker(field.key, options: model.catalog?.rpg?.checks ?? [])
        case .condition: picker(field.key, options: model.catalog?.rpg?.conditions ?? [])
        case .equipment: picker(field.key, options: model.catalog?.rpg?.equipment ?? [])
        case .checkResults:
            ForEach(model.catalog?.rpg?.checkResults ?? []) { option in
                Toggle(option.label, isOn: Binding(get: { candidate[field.key]?.nativeConditionArray?.contains(.string(option.id)) == true }, set: { enabled in
                    var values = candidate[field.key]?.nativeConditionArray ?? []
                    if enabled && !values.contains(.string(option.id)) { values.append(.string(option.id)) }
                    if !enabled { values.removeAll { $0 == .string(option.id) } }
                    candidate[field.key] = .array(values)
                }))
            }
        }
    }
    private func picker(_ key: String, options: [NativeConditionAuthorOption]) -> some View {
        let current = candidate[key]?.nativeConditionText ?? candidate[key]?.nativeConditionInteger.map(String.init) ?? ""
        return Picker(LocalizedStringKey("nativeCondition.field." + key), selection: string(key)) {
            if !options.contains(where: { $0.id == current }) { Text(verbatim: current.isEmpty ? "—" : current).tag(current) }
            ForEach(options) { Text(verbatim: $0.label).tag($0.id) }
        }
    }
    private func commit() {
        guard isCurrent else { error = true; return }
        var row = candidate
        for field in fields {
            switch field.input {
            case .number:
                guard let text = numericInputs[field.key], let n = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
                      text.range(of: "^-?(?:0|[1-9][0-9]*)(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$", options: .regularExpression) != nil,
                      NSDecimalNumber(decimal: n).doubleValue.isFinite else { error = true; return }
                row[field.key] = .number(n)
            case .integer:
                guard let text = numericInputs[field.key], let n = Int64(text) else { error = true; return }; row[field.key] = .number(Decimal(n))
            case .node:
                if let text = row[field.key]?.nativeConditionText {
                    guard let n = Int64(text) else { error = true; return }; row[field.key] = .number(Decimal(n))
                }
            default: break
            }
        }
        if model.replace(path, expected: original, with: .object(row), revision: capturedRevision) { dismiss() } else { error = true }
    }
}

@MainActor private struct NativeConditionAuthorStringsForm: View {
    @Binding var values: [ProjectEditJSON]
    var body: some View {
        ForEach(values.indices, id: \.self) { index in
            HStack {
                TextField("nativeCondition.field.value", text: Binding(get: { values.indices.contains(index) ? values[index].nativeConditionText ?? "" : "" }, set: {
                    if values.indices.contains(index) { values[index] = .string($0) }
                }), axis: .vertical)
                Button(role: .destructive) { if values.indices.contains(index) { values.remove(at: index) } } label: { Image(systemName: "minus.circle").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                    .accessibilityLabel("nativeCondition.removeValue").buttonStyle(.borderless)
                Button { if index > 0 && values.indices.contains(index) { values.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                    .disabled(index == 0).accessibilityLabel("nativeCondition.moveUp").buttonStyle(.borderless)
            }
        }
        Button("nativeCondition.addValue") { values.append(.string("")) }.disabled(values.count >= 200)
    }
}
