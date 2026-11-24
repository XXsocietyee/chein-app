import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - Story Rule Sentence Editor & Topic Story Participation Views
// Ported from `pages/publish/components/story-rule-editor/index.wxml`, `pages/topic/components/project-join/index.wxml`, and `pages/club/topic-story/index.wxml`.

@available(macOS 14.0, *)
@MainActor struct StoryRuleEditorView: View {
    @Bindable var model: StoryRuleEditorModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let layer = model.layer {
                layerSheet(layer)
            } else {
                rulesContent
            }
        }
        .padding()
        .cyDomainScreen(.topicEditor)
    }

    @ViewBuilder
    private var rulesContent: some View {
        if !model.error.isEmpty {
            Text(model.error)
                .cyText(.meta)
                .foregroundStyle(.red)
        }

        // Conditions Section
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("storyRule.conditionsTitle")
                    .cyText(.bodyMedium)
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
                        .cyText(.meta, weight: .semibold)
                }
                .buttonStyle(.bordered)
            }
        }

        Divider()

        // Effects Section
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("storyRule.effectsTitle")
                    .cyText(.bodyMedium)
                Spacer()
                if model.effectRows.count > 1 && !model.readOnly {
                    Button(LocalizedStringKey(model.sorting ? "storyRule.sortDone" : "storyRule.sortStart")) {
                        model.toggleSort()
                    }
                    .cyText(.meta)
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
                        .cyText(.meta, weight: .semibold)
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
                        .cyText(.meta)
                }
                .padding(.leading, 16)

            case "groupDel":
                Button(role: .destructive) {
                    model.onRemove(path: row.path)
                } label: {
                    Label(row.text, systemImage: "trash")
                        .cyText(.meta)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(CYColor.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
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
                        Label(ChannelCopy.text("上移", "Move up", locale: locale), systemImage: "arrow.up")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(CYColor.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))

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
                            .cyText(.meta)
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
                .cyText(.meta)
            }

            Button(role: .destructive) {
                model.onRemove(path: path)
            } label: {
                Label("storyRule.removeSentence", systemImage: "trash")
                    .cyText(.meta)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .background(CYColor.textSecondary.opacity(0.05), in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
    }

    @ViewBuilder
    private func layerSheet(_ layer: StoryRuleLayerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(layer.title)
                    .cyText(.cardTitle)
                Spacer()
                Button("storyRule.back") {
                    model.closeLayer()
                }
                .cyText(.meta)
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
                                    .cyText(.bodyMedium)
                                Spacer()
                                if lRow.hasNames {
                                    Image(systemName: lRow.open ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                }
                            }
                            .padding(8)
                            .background(CYColor.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
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

/// Result of the last answer attempt for one station. There is deliberately no success case:
/// answers cannot be sent from the app yet, so a valid attempt can only be "blocked".
enum StoryAnswerFeedback: Equatable {
    case invalid(String)
    case blocked
}

@available(macOS 14.0, *)
@MainActor struct StoryParticipationView: View {
    @Bindable var coordinator: StoryParticipationCoordinator
    let onJoinTap: () -> Void
    let onSubmitNodeAnswer: (Int) -> Void
    /// Shows the "joining is not available yet" banner under the join card after the player taps Join.
    var joinBlocked: Bool = false
    var answerFeedback: [Int: StoryAnswerFeedback] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            joinCard

            if !coordinator.errorMessage.isEmpty {
                Label(coordinator.errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.dangerText)
            }

            if coordinator.chapters.isEmpty {
                CYEmptyStateView(
                    systemImage: "book.closed",
                    title: LocalizedStringKey(W8Text.t("还没有剧情章节", "No story chapters yet")),
                    description: LocalizedStringKey(W8Text.t("主题发布章节后会显示在这里。", "Chapters appear here once the theme publishes them.")))
            }

            ForEach(coordinator.chapters) { chapter in
                chapterCard(chapter)
            }
        }
    }

    // MARK: Join

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYCard(variant: .elevated) {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    HStack(alignment: .center, spacing: CYSpacing.md) {
                        Text(LocalizedStringKey(coordinator.joinState.isMerchant ? "storyRule.joinMerchant" : "storyRule.joinPlayer"))
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: CYSpacing.sm)
                        Button(coordinator.joinState.joinActionTitle, action: onJoinTap)
                            .buttonStyle(.cyPrimary(fullWidth: false))
                            .disabled(!coordinator.joinState.canSubmitJoin)
                            .accessibilityIdentifier("story.join")
                    }

                    if !coordinator.joinState.stations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: CYSpacing.sm) {
                                ForEach(Array(coordinator.joinState.stations.enumerated()), id: \.element.id) { idx, station in
                                    stationChip(station, selected: coordinator.joinState.selectedStationIndex == idx) {
                                        coordinator.joinState.switchStation(to: idx)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if joinBlocked {
                PlayWriteUnavailableBanner(surface: .storyJoin)
            }
        }
    }

    private func stationChip(_ station: StoryProjectStation, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(station.name)
                    .cyText(.label)
                    .foregroundStyle(selected ? CYColor.brand : CYColor.textPrimary)
                if !station.roleName.isEmpty {
                    Text(station.roleName)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
            }
            .padding(.horizontal, CYSpacing.md)
            .padding(.vertical, CYSpacing.sm)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .background(selected ? CYColor.brandSoft : CYColor.bgSurfaceSubtle,
                        in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Chapters

    private func chapterCard(_ chapter: StoryTopicChapter) -> some View {
        let expanded = coordinator.expandedChapterNo == chapter.chapterNo
        return CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Button {
                    coordinator.expandedChapterNo = expanded ? nil : chapter.chapterNo
                } label: {
                    HStack {
                        Text(chapter.title)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: CYSpacing.sm)
                        Text("storyRule.stationCount \(chapter.nodes.count)")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textTertiary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityValue(expanded ? W8Text.t("已展开", "Expanded") : W8Text.t("已折叠", "Collapsed"))

                if expanded {
                    ForEach(chapter.nodes) { node in nodeCard(node) }
                }
            }
        }
    }

    private func nodeCard(_ node: StoryTopicNode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack {
                Text(node.name)
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                if node.answered {
                    Label("storyRule.answered", systemImage: "checkmark.circle.fill")
                        .cyText(.caption)
                        .foregroundStyle(CYColor.successText)
                }
            }
            if !node.walkText.isEmpty || !node.durationText.isEmpty {
                Text([node.walkText, node.durationText].filter { !$0.isEmpty }.joined(separator: " · "))
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textTertiary)
            }
            if !node.storyContent.isEmpty {
                Text(node.storyContent)
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if node.isAnswerable { answerControls(node) }
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
    }

    @ViewBuilder
    private func answerControls(_ node: StoryTopicNode) -> some View {
        if !node.questionTitle.isEmpty {
            Text(node.questionTitle)
                .cyText(.label)
                .foregroundStyle(CYColor.textPrimary)
        }
        if node.questionType == 1 && !node.options.isEmpty {
            ForEach(node.options) { opt in
                let selected = coordinator.draftAnswers[node.nodeId] == opt.key
                Button {
                    coordinator.selectAnswer(nodeId: node.nodeId, value: opt.key)
                } label: {
                    HStack(spacing: CYSpacing.md) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected ? CYColor.brand : CYColor.textTertiary)
                            .accessibilityHidden(true)
                        Text("\(opt.key). \(opt.label)")
                            .cyText(.bodyCompact)
                            .foregroundStyle(CYColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        } else {
            TextField(LocalizedStringKey("storyRule.answerPlaceholder"), text: Binding(
                get: { coordinator.draftAnswers[node.nodeId] ?? "" },
                set: { coordinator.selectAnswer(nodeId: node.nodeId, value: $0) }
            ))
            .cyText(.body)
            .padding(.horizontal, CYSpacing.md)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
        }

        if let feedback = answerFeedback[node.nodeId] {
            switch feedback {
            case .invalid(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.dangerText)
            case .blocked:
                PlayWriteUnavailableBanner(surface: .storyAnswer)
            }
        }

        Button(LocalizedStringKey("storyRule.submitAnswer")) {
            onSubmitNodeAnswer(node.nodeId)
        }
        .buttonStyle(.cySecondary(fullWidth: true))
        .accessibilityIdentifier("story.submitAnswer.\(node.nodeId)")
    }
}

#if DEBUG
#Preview("Story participation") {
    let model = StoryParticipationCoordinator(topicId: 1, fromSource: "topic")
    model.loadStoryNodes([
        .object([
            "nodeId": .integer(1), "chapterNo": .integer(1), "chapterTitle": .string("Chapter 1"),
            "name": .string("Old clock tower"), "description": .string("A quiet corner of the square.")
        ])
    ])
    return ScrollView {
        StoryParticipationView(coordinator: model, onJoinTap: {}, onSubmitNodeAnswer: { _ in }, joinBlocked: true)
            .padding()
        .cyDomainScreen(.topicEditor)
    }
    .background(CYColor.bgPage)
}
#endif
