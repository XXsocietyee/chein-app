import SwiftUI

/// OWN-21.2 list and OWN-21.1 draft, on the template tab (`pages/template/index`). The section stays on screen when the client is missing.
@MainActor struct GameplayPresetSection: View {
    let canDraft: Bool
    @Environment(\.gameplayPresetClient) private var client
    @Environment(\.cyPalette) private var palette
    @StateObject private var model: GameplayPresetModel

    init(canDraft: Bool) {
        self.canDraft = canDraft
        _model = StateObject(wrappedValue: GameplayPresetModel(client: nil, canDraft: canDraft))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: W8Text.t("玩法预设", "Gameplay presets"))
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityIdentifier("preset.gameplay.title")
            phaseBody
        }
        .padding(CYSpacing.lg)
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityIdentifier("preset.gameplay.section")
        .task(id: client?.token) { await reload() }
    }

    @ViewBuilder private var phaseBody: some View {
        if client == nil {
            status(W8Text.t("预设列表还不能读取。", "The preset list cannot be read yet."), id: "preset.gameplay.unavailable")
        } else if model.phase == .loading || model.phase == .idle {
            ProgressView()
                .accessibilityLabel(Text(verbatim: W8Text.t("正在读取预设", "Loading presets")))
                .accessibilityIdentifier("preset.gameplay.loading")
        } else if model.phase == .empty {
            status(W8Text.t("还没有玩法预设。", "There are no gameplay presets."), id: "preset.gameplay.empty")
            retry
        } else if case .failed(let message) = model.phase {
            status(message, id: "preset.gameplay.error")
            retry
        } else {
            if let version = model.catalog?.catalogVersion {
                labeled(W8Text.t("目录版本", "Catalog version"), version)
            }
            if model.phase == .catalog {
                ForEach(model.catalog?.presets ?? []) { row in
                    Button {
                        Task { await model.open(presetKey: row.presetKey) }
                    } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(verbatim: row.title).cyText(.bodyCompact).foregroundStyle(palette.textPrimary)
                            Text(verbatim: row.purpose ?? WP09Copy.unknown).cyText(.meta).foregroundStyle(palette.textSecondary)
                            Text(verbatim: row.templateSourceLabel(chinese: W8Text.isChinese)).cyText(.meta).foregroundStyle(palette.textTertiary)
                        }
                        // A button label centres wrapped lines; a two-line purpose read as a ragged centred block.
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("preset.gameplay.row.\(row.presetKey)")
                }
            }
            if let preset = model.preset, model.inputsEditable || model.editorOpen {
                Text(verbatim: preset.title).cyText(.bodyCompact)
                todoList(preset.authorTodos)
                ForEach(preset.requiredFields) { field in
                    fieldControl(field)
                }
                if model.editorOpen, let id = model.receipt?.draftID {
                    labeled(W8Text.t("草稿", "Draft"), String(id))
                        .accessibilityIdentifier("preset.gameplay.draft")
                }
                if let message = model.message {
                    status(message, id: "preset.gameplay.message")
                }
                Button { Task { await model.create() } } label: { Text(verbatim: W8Text.t("建成草稿", "Create draft")).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canDraft)
                    .accessibilityIdentifier("preset.gameplay.create")
            }
        }
    }

    private var retry: some View {
        Button { Task { await reload() } } label: { Text(verbatim: W8Text.t("重试", "Try again")) }
            .accessibilityIdentifier("preset.gameplay.retry")
    }

    private func reload() async {
        model.adopt(client: client, canDraft: canDraft)
        await model.load()
    }

    private func status(_ text: String, id: String) -> some View {
        Text(verbatim: text).cyText(.meta).foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: title).cyText(.meta).foregroundStyle(palette.textTertiary)
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: value).cyText(.meta).foregroundStyle(palette.textPrimary)
        }
    }

    private func todoList(_ todos: [String]) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: W8Text.t("还要自己做", "Still to do")).cyText(.meta).foregroundStyle(palette.textTertiary)
            if todos.isEmpty {
                Text(verbatim: WP09Copy.unknown).cyText(.meta)
            } else {
                ForEach(Array(todos.enumerated()), id: \.offset) { _, item in
                    Text(verbatim: item).cyText(.bodyCompact).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("preset.gameplay.todos")
    }

    @ViewBuilder private func fieldControl(_ field: GameplayPresetField) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: field.label).cyText(.meta).foregroundStyle(palette.textSecondary)
            switch field.kind {
            case "choice" where !field.options.isEmpty:
                Picker(selection: textBinding(field.key)) {
                    Text(verbatim: WP09Copy.unknown).tag("")
                    ForEach(field.options, id: \.self) { option in Text(verbatim: option).tag(option) }
                } label: { Text(verbatim: field.label) }
            case "order":
                let rows = model.orderItems[field.key] ?? field.items
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(verbatim: item)
                        Spacer(minLength: CYSpacing.sm)
                        Button { model.move(field.key, from: index, up: true) } label: { Text(verbatim: W8Text.t("上移", "Move up")) }
                        Button { model.move(field.key, from: index, up: false) } label: { Text(verbatim: W8Text.t("下移", "Move down")) }
                    }
                }
            case "bin_map":
                ForEach(field.items, id: \.self) { item in
                    Picker(selection: binBinding(field: field.key, item: item, bins: field.bins)) {
                        Text(verbatim: WP09Copy.unknown).tag("")
                        ForEach(field.bins, id: \.self) { bin in Text(verbatim: bin).tag(bin) }
                    } label: { Text(verbatim: item) }
                }
            default:
                TextField("", text: textBinding(field.key))
            }
        }
        .accessibilityIdentifier("preset.gameplay.field.\(field.key)")
    }

    private func textBinding(_ key: String) -> Binding<String> {
        Binding(get: { model.textInputs[key] ?? "" }, set: { model.textInputs[key] = $0 })
    }

    private func binBinding(field: String, item: String, bins: [String]) -> Binding<String> {
        Binding(get: { model.binChoices[field]?[item] ?? "" }, set: { value in
            var map = model.binChoices[field] ?? [:]
            map[item] = bins.contains(value) ? value : ""
            model.binChoices[field] = map
        })
    }
}

private struct GameplayPresetClientKey: EnvironmentKey {
    static let defaultValue: GameplayPresetClient? = nil
}

extension EnvironmentValues {
    var gameplayPresetClient: GameplayPresetClient? {
        get { self[GameplayPresetClientKey.self] }
        set { self[GameplayPresetClientKey.self] = newValue }
    }
}

extension AppSession {
    /// Built from the session the root already holds. Missing configuration leaves the section visible and unread.
    func gameplayPresetClient() -> GameplayPresetClient? {
        guard let api = regionalConfiguration?.apiConfiguration, let token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return GameplayPresetClient(configuration: api, transport: runtimeHTTPTransport, token: token)
    }
}
