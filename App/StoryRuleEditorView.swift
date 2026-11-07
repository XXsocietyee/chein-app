import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - Story Rule Sentence Editor & Topic Story Participation Views
// Ported from `pages/publish/components/story-rule-editor/index.wxml`, `pages/topic/components/project-join/index.wxml`, and `pages/club/topic-story/index.wxml`.

@available(macOS 14.0, *)
@MainActor struct StoryRuleEditorView: View {
    @Bindable var model: StoryRuleEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let layer = model.layer {
                layerSheet(layer)
            } else {
                rulesContent
            }
        }
        .padding()
    }

    @ViewBuilder
    private var rulesContent: some View {
        if !model.error.isEmpty {
            Text(model.error)
                .font(.caption)
                .foregroundStyle(.red)
        }

        // Conditions Section
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("storyRule.conditionsTitle")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if model.showTopSeg {
                    Picker("", selection: Binding(
                        get: { model.topSegValue },
                        set: { model.onTopMode($0) }
                    )) {
                        Text("storyRule.matchAll").tag("AND")
                        Text("storyRule.matchAny").tag("OR")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
            }

            ForEach(model.conditionRows) { row in
                conditionRowView(row)
            }

            if !model.readOnly {
                Button {
                    model.openAdd(target: "conditions")
                } label: {
                    Label("storyRule.addCondition", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }

        Divider()

        // Effects Section
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("storyRule.effectsTitle")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if model.effectRows.count > 1 && !model.readOnly {
                    Button(LocalizedStringKey(model.sorting ? "storyRule.sortDone" : "storyRule.sortStart")) {
                        model.toggleSort()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }

            ForEach(model.effectRows) { row in
                effectRowView(row)
            }

            if !model.readOnly {
                Button {
                    model.openAdd(target: "effects")
                } label: {
                    Label("storyRule.addEffect", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func conditionRowView(_ row: StoryRuleRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch row.type {
            case "groupSeg":
                Picker("", selection: Binding(
                    get: { row.mode ?? "AND" },
                    set: { model.onGroupMode(path: row.path, mode: $0) }
                )) {
                    Text("storyRule.matchAll").tag("AND")
                    Text("storyRule.matchAny").tag("OR")
                }
                .pickerStyle(.segmented)
                .padding(.leading, 16)

            case "groupAdd":
                Button {
                    model.openAdd(target: row.path)
                } label: {
                    Label(row.text, systemImage: "plus")
                        .font(.caption)
                }
                .padding(.leading, 16)

            case "groupDel":
                Button(role: .destructive) {
                    model.onRemove(path: row.path)
                } label: {
                    Label(row.text, systemImage: "trash")
                        .font(.caption)
                }
                .padding(.leading, 16)

            default:
                Button {
                    model.toggleRow(path: row.path, type: row.type)
                } label: {
                    HStack {
                        Text(row.text)
                            .font(.subheadline)
                            .foregroundStyle(row.unsupported ? .secondary : .primary)
                        Spacer()
                        Image(systemName: row.open ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.leading, CGFloat(row.depth * 16))

                if row.open, let editor = row.editor {
                    rowInlineEditor(path: row.path, editor: editor)
                        .padding(.leading, CGFloat(row.depth * 16 + 8))
                }
            }
        }
    }

    @ViewBuilder
    private func effectRowView(_ row: StoryRuleRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    model.toggleRow(path: row.path, type: row.type)
                } label: {
                    HStack {
                        Text(row.text)
                            .font(.subheadline)
                            .foregroundStyle(row.unsupported ? .secondary : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                if model.sorting && row.canUp {
                    Button {
                        model.onMoveUp(path: row.path)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            if row.open, let editor = row.editor {
                rowInlineEditor(path: row.path, editor: editor)
                    .padding(.leading, 8)
            }
        }
    }

    @ViewBuilder
    private func rowInlineEditor(path: String, editor: StoryRuleRowEditor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let neg = editor.neg {
                Picker("", selection: Binding(
                    get: { neg.value },
                    set: { model.onNegate(path: path, value: $0) }
                )) {
                    ForEach(neg.options, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let names = editor.names {
                Picker("", selection: Binding(
                    get: { names.value },
                    set: { model.onPickName(path: path, key: $0) }
                )) {
                    ForEach(names.options, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.segmented)
            } else if let renameLabel = editor.renameLabel {
                Button {
                    model.openRename(path: path)
                } label: {
                    HStack {
                        Text("storyRule.renameTarget \(renameLabel)")
                        Spacer()
                        Text("storyRule.renameAction")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
            }

            if let cmp = editor.cmp {
                Picker("", selection: Binding(
                    get: { cmp.value },
                    set: { model.onCompare(path: path, cmpIndex: $0) }
                )) {
                    ForEach(cmp.options, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let result = editor.result {
                Picker("", selection: Binding(
                    get: { result.value },
                    set: { model.onResult(path: path, resultIndex: $0) }
                )) {
                    ForEach(result.options, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let varOp = editor.varOp {
                Picker("", selection: Binding(
                    get: { varOp.value },
                    set: { model.onVarOp(path: path, opIndex: $0) }
                )) {
                    ForEach(varOp.options, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let amount = editor.amount {
                Stepper(
                    "\(amount.label)：\(amount.value)",
                    value: Binding(
                        get: { amount.value },
                        set: { model.onAmount(path: path, amount: $0) }
                    ),
                    in: amount.min...amount.max
                )
                .font(.caption)
            }

            Button(role: .destructive) {
                model.onRemove(path: path)
            } label: {
                Label("storyRule.removeSentence", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func layerSheet(_ layer: StoryRuleLayerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(layer.title)
                    .font(.headline)
                Spacer()
                Button("storyRule.back") {
                    model.closeLayer()
                }
                .font(.caption)
            }

            TextField("storyRule.layerSearch", text: Binding(
                get: { model.query },
                set: { model.onLayerQuery($0) }
            ))
            .textFieldStyle(.roundedBorder)

            ForEach(model.layerRows) { lRow in
                VStack(alignment: .leading, spacing: 6) {
                    if !lRow.label.isEmpty {
                        Button {
                            model.onLayerKind(lRow.kind)
                        } label: {
                            HStack {
                                Text(lRow.label)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if lRow.hasNames {
                                    Image(systemName: lRow.open ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }

                    if lRow.open {
                        ForEach(lRow.names, id: \.key) { item in
                            Button {
                                model.onLayerName(item.key)
                            } label: {
                                HStack {
                                    Text(item.label)
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .font(.caption)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

@available(macOS 14.0, *)
@MainActor struct StoryParticipationView: View {
    @Bindable var coordinator: StoryParticipationCoordinator
    let onJoinTap: () -> Void
    let onSubmitNodeAnswer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Project Join & Station Switcher Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LocalizedStringKey(coordinator.joinState.isMerchant ? "storyRule.joinMerchant" : "storyRule.joinPlayer"))
                        .font(.headline)
                    Spacer()
                    Button(coordinator.joinState.joinActionTitle, action: onJoinTap)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!coordinator.joinState.canSubmitJoin)
                }

                if !coordinator.joinState.stations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(coordinator.joinState.stations.enumerated()), id: \.element.id) { idx, station in
                                Button {
                                    coordinator.joinState.switchStation(to: idx)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(station.name)
                                            .font(.caption.weight(.semibold))
                                        if !station.roleName.isEmpty {
                                            Text(station.roleName)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        coordinator.joinState.selectedStationIndex == idx
                                            ? Color.accentColor.opacity(0.18)
                                            : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            if !coordinator.errorMessage.isEmpty {
                Text(coordinator.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Club Topic Story Chapters
            ForEach(coordinator.chapters) { chapter in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        coordinator.expandedChapterNo = (coordinator.expandedChapterNo == chapter.chapterNo) ? nil : chapter.chapterNo
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .font(.headline)
                            Spacer()
                            Text("storyRule.stationCount \(chapter.nodes.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if coordinator.expandedChapterNo == chapter.chapterNo {
                        ForEach(chapter.nodes) { node in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(node.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if node.answered {
                                        Text("storyRule.answered")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                }
                                if !node.walkText.isEmpty || !node.durationText.isEmpty {
                                    Text([node.walkText, node.durationText].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if !node.storyContent.isEmpty {
                                    Text(node.storyContent)
                                        .font(.caption)
                                }
                                if node.isAnswerable {
                                    if !node.questionTitle.isEmpty {
                                        Text(node.questionTitle)
                                            .font(.caption.weight(.semibold))
                                    }
                                    if node.questionType == 1 && !node.options.isEmpty {
                                        ForEach(node.options) { opt in
                                            let selected = coordinator.draftAnswers[node.nodeId] == opt.key
                                            Button {
                                                coordinator.selectAnswer(nodeId: node.nodeId, value: opt.key)
                                            } label: {
                                                HStack {
                                                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                                                    Text("\(opt.key). \(opt.label)")
                                                        .font(.caption)
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    } else {
                                        TextField("storyRule.answerPlaceholder", text: Binding(
                                            get: { coordinator.draftAnswers[node.nodeId] ?? "" },
                                            set: { coordinator.selectAnswer(nodeId: node.nodeId, value: $0) }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                    }
                                    Button("storyRule.submitAnswer") {
                                        onSubmitNodeAnswer(node.nodeId)
                                    }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(10)
                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
