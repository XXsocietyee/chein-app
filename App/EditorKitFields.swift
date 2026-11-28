import SwiftUI

// Design hand-off r1 · Editor/Field, Editor/PopUp, Editor/Switch Row, Editor/Row, Editor/Option Row,
// Editor/Stepper and Editor/Number Row (CF-10, CF-14, CF-26, CF-27, CF-28, CF-34, CF-47, CF-74).

/// `Editor/Field` Kind.
enum EditorFieldKind: Equatable, Sendable {
    case line
    case area
}

/// Label above a field: label, red `*` when required, live counter at the trailing end.
struct EditorFieldLabel: View {
    let label: Text
    var required: Bool = false
    var counter: EditorCounter? = nil
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(spacing: 2) {
            label.cyText(.bodyMedium).foregroundStyle(palette.textSecondary)
            if required {
                Text(verbatim: "*").cyText(.bodyMedium).foregroundStyle(palette.danger).accessibilityHidden(true)
            }
            Spacer(minLength: CYSpacing.sm)
            if let counter {
                Text(verbatim: counter.text)
                    .cyText(.meta, monospacedDigit: true)
                    .foregroundStyle(counter.isAtLimit ? palette.danger : palette.textTertiary)
                    .contentTransition(.numericText())
                    .accessibilityHidden(true)
            }
        }
    }
}

/// One slot under each field: hint or error, never both (CF-10, ref 17). Error text sits on the
/// card surface, never on a pink fill (CF-66).
struct EditorFieldFootnote: View {
    var help: Text? = nil
    var error: Text? = nil
    @Environment(\.cyPalette) private var palette
    var body: some View {
        if let error {
            Label { error } icon: { Image(systemName: "exclamationmark.circle.fill") }
                .font(.footnote)
                .foregroundStyle(palette.danger)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
        } else if let help {
            help.cyText(.meta).foregroundStyle(palette.textTertiary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The one text field (CF-10). Line 44 high, Area 88 high; live counter `12/30` that turns red at the
/// limit (CF-28). `Return` moves on (CF-74).
struct EditorField: View {
    let label: Text
    @Binding var text: String
    var prompt: Text? = nil
    var kind: EditorFieldKind = .line
    var surface: EditorKitSurface = .onCard
    var required: Bool = false
    var limit: Int? = nil
    var help: Text? = nil
    var error: Text? = nil
    var showsLabel: Bool = true
    var accessibilityID: String? = nil

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            if showsLabel {
                EditorFieldLabel(label: label, required: required, counter: limit.map { EditorCounter(text: text, limit: $0) })
            }
            TextField(text: limitedText, prompt: prompt, axis: kind == .area ? .vertical : .horizontal) { label }
                .lineLimit(kind == .area ? 3...10 : 1...3)
                .cyText(.body)
                .foregroundStyle(isEnabled ? palette.textPrimary : palette.textDisabled)
                .focused($focused)
                .submitLabel(kind == .area ? .return : .next)
                .padding(.horizontal, EditorKitMetric.fieldPaddingX)
                .padding(.vertical, kind == .area ? 11 : 0)
                .frame(minHeight: kind == .area ? EditorKitMetric.areaHeight : EditorKitMetric.fieldHeight,
                       alignment: kind == .area ? .topLeading : .leading)
                .background(RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous).fill(surface.fieldFill(palette)))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderColor == .clear ? 0 : EditorKitMetric.selectedBorder)
                )
                .accessibilityValue(limit.map { Text(verbatim: EditorCounter(text: text, limit: $0).text) } ?? Text(verbatim: ""))
                .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
            EditorFieldFootnote(help: help, error: error)
        }
        .sensoryFeedback(.warning, trigger: limit.map { EditorCounter(text: text, limit: $0).isAtLimit } ?? false, condition: CYHapticTransition.isOn)
    }

    private var borderColor: Color {
        if error != nil { return palette.danger }
        if focused { return palette.textPrimary }
        return .clear
    }

    private var limitedText: Binding<String> {
        guard let limit else { return $text }
        return Binding(get: { text }, set: { text = EditorCounter.clamp($0, limit: limit) })
    }
}

/// `Editor/Field` Kind=Number: short, right-aligned, unit as suffix, number pad (CF-47).
struct EditorNumberField: View {
    @Binding var value: Int?
    var unit: EditorUnit? = nil
    var surface: EditorKitSurface = .onCard
    var isInvalid: Bool = false
    var accessibilityLabel: Text? = nil
    var accessibilityID: String? = nil

    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.s1_5) {
            TextField(text: digits) { accessibilityLabel ?? Text(verbatim: "") }
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .cyText(.numericBody)
                .foregroundStyle(palette.textPrimary)
                .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
            if let unit {
                EditorKitText.text(unit.key).cyText(.body).foregroundStyle(palette.textTertiary)
            }
        }
        .padding(.horizontal, EditorKitMetric.fieldPaddingX)
        .frame(minWidth: EditorKitMetric.numberFieldWidth, minHeight: EditorKitMetric.fieldHeight)
        .fixedSize(horizontal: true, vertical: false)
        .background(RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous).fill(surface.fieldFill(palette)))
        .overlay(
            RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous)
                .strokeBorder(isInvalid ? palette.danger : Color.clear, lineWidth: isInvalid ? EditorKitMetric.selectedBorder : 0)
        )
    }

    /// Digits only; an empty field is `nil` (unknown), never a magic 0.
    private var digits: Binding<String> {
        Binding(
            get: { value.map(String.init) ?? "" },
            set: { text in
                let filtered = String(text.filter(\.isASCII).filter(\.isNumber).prefix(9))
                value = filtered.isEmpty ? nil : Int(filtered)
            }
        )
    }
}

/// `Editor/Number Row`: label left, a number field with a unit suffix right, or a native stepper for
/// ranges up to 20 (CF-47). The range appears only as error text.
struct EditorNumberRow: View {
    let label: Text
    @Binding var value: Int?
    var unit: EditorUnit? = nil
    var range: ClosedRange<Int>? = nil
    var useStepper: Bool = false
    var surface: EditorKitSurface = .onCard
    var rangeError: Text? = nil
    var accessibilityID: String? = nil

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isOutOfRange: Bool {
        guard let range else { return false }
        return EditorNumber.isOutOfRange(value, range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
                : AnyLayout(HStackLayout(spacing: CYSpacing.md))
            layout {
                label.cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: CYSpacing.sm) }
                if useStepper, let range {
                    EditorStepper(value: Binding(get: { value ?? range.lowerBound }, set: { value = $0 }), range: range, unit: unit, fieldLabel: label)
                } else {
                    EditorNumberField(value: $value, unit: unit, surface: surface, isInvalid: isOutOfRange,
                                      accessibilityLabel: label, accessibilityID: accessibilityID)
                }
            }
            .frame(minHeight: EditorKitMetric.switchRowMinHeight)
            if isOutOfRange { EditorFieldFootnote(error: rangeError) }
        }
    }
}

/// `Editor/Stepper`: native stepper with the value shown between label and control (CF-15, ref 7).
struct EditorStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var unit: EditorUnit? = nil
    /// The host row's field name, so VoiceOver reads "Max tries, 3 times" instead of the number alone.
    var fieldLabel: Text? = nil
    @Environment(\.cyPalette) private var palette
    private var spokenValue: Text {
        if let unit { return Text(verbatim: "\(value) ") + EditorKitText.text(unit.key) }
        return Text(verbatim: String(value))
    }
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            HStack(spacing: 2) {
                Text(verbatim: String(value))
                    .cyText(.cardTitle, monospacedDigit: true)
                    .contentTransition(.numericText())
                if let unit { EditorKitText.text(unit.key).cyText(.body).foregroundStyle(palette.textTertiary) }
            }
            Stepper(value: $value, in: range) { Text(verbatim: String(value)) }
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
        .modifier(EditorStepperFieldLabel(label: fieldLabel, value: spokenValue))
    }
}

/// Names the combined stepper after its field when the host row passes one; otherwise the combined children stay as they are.
private struct EditorStepperFieldLabel: ViewModifier {
    let label: Text?
    let value: Text
    @ViewBuilder func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label).accessibilityValue(value)
        } else {
            content
        }
    }
}

/// `Editor/PopUp`: native pop-up button (`Picker(.menu)`) for 4+ options or long labels (ref 4).
struct EditorPopUp<Value: Hashable>: View {
    let label: Text
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> Text
    var required: Bool = false
    var surface: EditorKitSurface = .onCard
    var help: Text? = nil
    var error: Text? = nil
    var accessibilityID: String? = nil

    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            EditorFieldLabel(label: label, required: required)
            Menu {
                Picker(selection: $selection) {
                    ForEach(options, id: \.self) { title($0).tag($0) }
                } label: { label }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: CYSpacing.s1_5) {
                    title(selection).cyText(.body).foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                }
                .padding(.leading, EditorKitMetric.fieldPaddingX)
                .padding(.trailing, CYSpacing.md)
                .frame(minHeight: EditorKitMetric.fieldHeight)
                .background(RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous).fill(surface.fieldFill(palette)))
                .overlay(
                    RoundedRectangle(cornerRadius: EditorKitMetric.fieldRadius, style: .continuous)
                        .strokeBorder(error == nil ? Color.clear : palette.danger, lineWidth: error == nil ? 0 : EditorKitMetric.selectedBorder)
                )
                .contentShape(Rectangle())
            }
            .accessibilityLabel(label)
            .accessibilityValue(title(selection))
            .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
            EditorFieldFootnote(help: help, error: error)
        }
    }
}

/// `Editor/Switch Row`: label, optional one-line footnote saying what "on" does, native 51 × 31 switch (CF-14, CF-37).
struct EditorSwitchRow: View {
    let label: Text
    @Binding var isOn: Bool
    var footnote: Text? = nil
    var accessibilityID: String? = nil
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                label.cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                if let footnote {
                    footnote.cyText(.meta).foregroundStyle(palette.textTertiary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(palette.success)
        .frame(minHeight: EditorKitMetric.switchRowMinHeight)
        .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
    }
}

/// `Editor/Row` accessory.
enum EditorRowAccessory: Sendable {
    case chevron
    case popUp
    case none
}

/// `Editor/Row`: settings / picker cell (CF-26, CF-27). Icon, label (red dot when required and empty),
/// current value in grey at the right, accessory. No verb pills. Use as a `NavigationLink` label.
struct EditorRow: View {
    let label: Text
    var value: Text? = nil
    var systemImage: String? = nil
    var showsDot: Bool = false
    var accessory: EditorRowAccessory = .chevron
    var isLocked: Bool = false

    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.s2_5) {
            if let systemImage {
                Image(systemName: systemImage).font(.body).foregroundStyle(palette.textSecondary)
                    .frame(width: 24).accessibilityHidden(true)
            }
            label.cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            if showsDot {
                Circle().fill(palette.danger).frame(width: 6, height: 6)
                    .accessibilityLabel(EditorKitText.text("editorKit.row.required"))
            }
            Spacer(minLength: CYSpacing.sm)
            if let value {
                value.cyText(.body).foregroundStyle(palette.textTertiary).multilineTextAlignment(.trailing)
            }
            if isLocked {
                Image(systemName: "lock.fill").font(.footnote).foregroundStyle(palette.textTertiary)
                    .accessibilityLabel(EditorKitText.text("editorKit.row.locked"))
            } else {
                switch accessory {
                case .chevron:
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                case .popUp:
                    Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                case .none:
                    EmptyView()
                }
            }
        }
        .frame(minHeight: EditorKitMetric.rowMinHeight)
        .contentShape(Rectangle())
    }
}

/// `Editor/Option Row`. Style List: trailing check mark. Style Card: 1.5 pt black border plus a filled
/// check when selected (CF-34). No radios, no square checkboxes, no green tint.
struct EditorOptionRow: View {
    enum Style: Sendable { case list, card }
    let label: Text
    var detail: Text? = nil
    let isSelected: Bool
    var style: Style = .list
    let action: () -> Void

    @Environment(\.cyPalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    label.cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        detail.cyText(.meta).foregroundStyle(palette.textTertiary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                checkmark
            }
            .padding(.horizontal, style == .card ? EditorKitMetric.fieldPaddingX : 0)
            .padding(.vertical, style == .card ? CYSpacing.md : CYSpacing.s2_5)
            .frame(minHeight: style == .card ? 56 : EditorKitMetric.rowMinHeight)
            .background {
                if style == .card {
                    RoundedRectangle(cornerRadius: EditorKitMetric.cardRadius, style: .continuous).fill(palette.bgElevated)
                }
            }
            .modifier(EditorOptionalSelectedBorder(active: style == .card, isSelected: isSelected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    @ViewBuilder private var checkmark: some View {
        switch style {
        case .list:
            Image(systemName: "checkmark").font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? palette.textPrimary : Color.clear)
                .accessibilityHidden(true)
        case .card:
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? palette.textPrimary : palette.borderStrong)
                .accessibilityHidden(true)
        }
    }
}

private struct EditorOptionalSelectedBorder: ViewModifier {
    let active: Bool
    let isSelected: Bool
    func body(content: Content) -> some View {
        if active { content.editorSelectedBorder(isSelected) } else { content }
    }
}

/// Applies an accessibility identifier only when one is given.
struct EditorOptionalIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier { content.accessibilityIdentifier(identifier) } else { content }
    }
}

/// CF-57: read-only legacy data as plain label–value text in a grey panel with a lock and one line.
struct EditorReadOnlyGroup: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: Text
        let value: String?
    }
    let items: [Item]
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label { EditorKitText.text("editorKit.readOnly.note") } icon: { Image(systemName: "lock.fill") }
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.textSecondary)
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline) {
                    item.label.font(.subheadline).foregroundStyle(palette.textSecondary)
                    Spacer(minLength: CYSpacing.sm)
                    Text(verbatim: EditorUnknown.display(item.value))
                        .font(.subheadline).foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.trailing).textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: EditorKitMetric.cardRadius, style: .continuous).fill(palette.bgPage))
    }
}
