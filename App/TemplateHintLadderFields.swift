import SwiftUI

/// UG-11 hint group. It sits in the finish section where the three legacy hint fields were, after the
/// answer and feedback fields, so feedback stays first and hints follow. One run-wide free count at the top;
/// each layer is type, content and points. No JSON key names, no per-layer free count, no gem or coin price.
@MainActor struct TemplateHintLadderFields: View {
    @ObservedObject var model: TemplateAuthoringModel

    var body: some View {
        if model.draft.finishEnabled {
            Toggle("templateHint.enabled", isOn: Binding(get: { model.draft.advanced.hintLadderOn }, set: { on in
                edit { $0.setHintLadder(on: on) }
            }))
            .disabled(!model.canEdit)
            .accessibilityIdentifier("templateHint.enabled")
            if model.draft.advanced.hintLadderOn { ladder }
        }
    }

    @ViewBuilder private var ladder: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("templateHint.freeUses").font(.subheadline)
            TextField("templateHint.freeUses.placeholder", text: Binding(get: { model.draft.advanced.hintFreeUsesText }, set: { text in
                edit { $0.setHintFreeUses(Self.digits(text)) }
            }))
            .keyboardType(.numberPad)
            .accessibilityIdentifier("templateHint.freeUses")
            Text("templateHint.freeUses.note").cyText(.bodyCompact).foregroundStyle(.secondary)
            if let issue = model.draft.advanced.hintQuotaIssue {
                Text(LocalizedStringKey(issue)).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("templateHint.freeUses.issue")
            }
        }
        let issues = model.draft.advanced.hintLayerIssues
        ForEach(model.draft.advanced.hintLayers) { layer in
            layerEditor(layer, issue: issues[layer.index])
        }
        if model.draft.advanced.hintLayers.count < TemplateHintLadder.maxLayers {
            Button("templateHint.addLayer", systemImage: "plus") { edit { $0.addHintLayer() } }
                .disabled(!model.canEdit)
                .accessibilityIdentifier("templateHint.addLayer")
        }
        Text("templateHint.preview.note").cyText(.bodyCompact).foregroundStyle(.secondary)
    }

    private func layerEditor(_ layer: TemplateHintLayerDraft, issue: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack {
                Text("templateHint.layer \(layer.index + 1)").cyText(.cardTitle)
                Spacer()
                Button(role: .destructive) { edit { $0.removeHintLayer(layer.index) } } label: {
                    Image(systemName: "minus.circle")
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(!model.canEdit)
                .accessibilityLabel(Text("templateHint.removeLayer \(layer.index + 1)"))
                .accessibilityIdentifier("templateHint.remove.\(layer.index)")
            }
            Picker("templateHint.type", selection: Binding(get: { layer.type }, set: { type in edit { $0.setHintType(layer.index, type) } })) {
                ForEach(TemplateHintLadder.types, id: \.self) { Text(LocalizedStringKey(TemplateHintLadder.typeLabelKey($0))).tag($0) }
            }
            .accessibilityIdentifier("templateHint.type.\(layer.index)")
            content(layer)
            if layer.type != "SKIP" {
                TextField("templateHint.points.placeholder", text: Binding(get: { layer.points }, set: { text in
                    edit { $0.setHintPoints(layer.index, Self.digits(text)) }
                }))
                .keyboardType(.numberPad)
                .accessibilityLabel(Text("templateHint.points"))
                .accessibilityIdentifier("templateHint.points.\(layer.index)")
            } else {
                Text("templateHint.skip.note").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
            if let issue {
                Text(LocalizedStringKey(issue)).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("templateHint.issue.\(layer.index)")
            }
        }
        .padding(.vertical, 4)
        .disabled(!model.canEdit)
    }

    @ViewBuilder private func content(_ layer: TemplateHintLayerDraft) -> some View {
        let text = Binding(get: { layer.payload }, set: { value in edit { $0.setHintPayload(layer.index, value) } })
        switch layer.type {
        case "TEXT":
            TextField("templateHint.text.placeholder", text: text, axis: .vertical).lineLimit(2...6)
                .accessibilityIdentifier("templateHint.payload.\(layer.index)")
        case "ANSWER":
            TextField("templateHint.answer.placeholder", text: text, axis: .vertical).lineLimit(1...4)
                .accessibilityIdentifier("templateHint.payload.\(layer.index)")
        case "IMAGE":
            TextField("templateHint.image.placeholder", text: text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("templateHint.payload.\(layer.index)")
        case "LETTER":
            TextField("templateHint.letter.placeholder", text: Binding(get: { layer.payload }, set: { value in
                edit { $0.setHintPayload(layer.index, Self.digits(value)) }
            }))
            .keyboardType(.numberPad)
            .accessibilityIdentifier("templateHint.payload.\(layer.index)")
        case "DIGIT":
            Text("templateHint.digit.note").cyText(.bodyCompact).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private func edit(_ change: (inout TemplateAdvancedDraft) -> Void) {
        guard model.canEdit else { return }
        change(&model.draft.advanced)
        model.changed()
    }

    private static func digits(_ text: String) -> String { String(text.filter(\.isASCII).filter(\.isNumber).prefix(6)) }
}
