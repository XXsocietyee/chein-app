import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// U02-03 / U02-04 "地点待办" in the topic editor (mini pages/publish/components/location-todos).
/// One entry row plus a sheet. Reads /binding-status; writes only through /binding (server checks owner,
/// edit window, city and revision). Only level=error says "blocks publishing"; warn is a hint.
/// Hidden while the binding client is gated or the topic has no place contract.
@MainActor struct TopicLocationTodosSection: View {
    let nodes: [TopicLocationEditorNode]
    @StateObject private var model: TopicLocationTodosModel
    @State private var open = false

    init(topicID: Int, scope: String?, nodes: [TopicLocationEditorNode]) {
        self.nodes = nodes
        _model = StateObject(wrappedValue: TopicLocationTodosModel(client: TopicTemplateAdoptionFactory.makeBindingClient(),
                                                                   topicId: topicID, scope: scope))
    }

    var body: some View {
        Group {
            if let todos = model.todos {
                Section {
                    Button { open = true } label: {
                        HStack {
                            Label(W8Text.t("地点待办", "Place to-dos"), systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(todos.summaryText ?? W8Text.t("\(todos.rows.count) 个地点", "\(todos.rows.count) place(s)"))
                                .foregroundStyle(todos.blockingCount > 0 ? Color.red : Color.secondary)
                        }
                    }
                    .accessibilityIdentifier("locationTodos.entry")
                }
                .cySheet(isPresented: $open) {
                    NavigationStack {
                        TopicLocationTodosSheet(model: model, nodes: nodes)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(W8Text.t("完成", "Done")) { open = false }
                                        .disabled(model.busySlot != nil)
                                        .accessibilityIdentifier("locationTodos.done")
                                }
                            }
                    }
                    .presentationDetents([.large])
                    .themeDomain(.topicEditor)
                    .interactiveDismissDisabled(model.busySlot != nil)
                }
            }
        }
        .task { await model.load() }
    }
}

@MainActor private struct TopicLocationTodosSheet: View {
    @ObservedObject var model: TopicLocationTodosModel
    let nodes: [TopicLocationEditorNode]
    @State private var picking: TopicLocationTodoRow?
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            if let todos = model.todos {
                Section {
                    ForEach(todos.rows) { row in
                        TopicLocationTodoRowView(row: row, mapped: todos.editorNode(for: row, in: nodes),
                                                 busy: model.busySlot == row.slotKey, anyBusy: model.busySlot != nil,
                                                 error: model.rowErrors[row.slotKey],
                                                 confirm: { node in Task { await model.bind(row, nodeId: node.id) } },
                                                 pick: {
                                                     if nodes.isEmpty { model.pickError(row) } else { picking = row }
                                                 })
                    }
                } footer: {
                    Text(W8Text.t("模板的地点要求和你这份草稿的实际地点分开保存。换了地址后，请确认相关题面、现场答案和照片仍然成立。",
                                  "The template's place requirements and your draft's actual places are saved separately. After changing an address, check that the related prompts, on-site answers and photos still hold."))
                        .accessibilityIdentifier("locationTodos.reconfirmNote")
                }
            }
        }
        .navigationTitle(W8Text.t("地点待办", "Place to-dos"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .cySheet(item: $picking) { row in
            NavigationStack {
                List(nodes, id: \.id) { node in
                    Button {
                        picking = nil
                        if let nodeID = Int64(node.id) {
                            Task { await model.bind(row, nodeId: String(nodeID)) }  // canonical numeric id
                        }
                    } label: {
                        HStack {
                            Label(node.name.isEmpty ? node.place : "\(node.name) · \(node.place)", systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.primary)
                            Spacer()
                            if row.nodeId == node.id {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .navigationTitle(MerchantAreaCopy.text("选择节点", "Choose a stop", locale))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(MerchantAreaCopy.cancel(locale)) { picking = nil }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .accessibilityIdentifier("locationTodos.sheet")
    }
}

@MainActor private struct TopicLocationTodoRowView: View {
    let row: TopicLocationTodoRow
    let mapped: (node: TopicLocationEditorNode, claimed: Bool)?
    let busy: Bool
    let anyBusy: Bool
    let error: String?
    let confirm: (TopicLocationEditorNode) -> Void
    let pick: () -> Void

    private func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Text(row.title).font(.body).foregroundStyle(.primary).lineLimit(2)
                if row.blocking {
                    Text(W8Text.t("挡住发布", "Blocks publishing")).font(.caption).foregroundStyle(.red)
                        .accessibilityIdentifier("locationTodos.blocking")
                } else if row.warning {
                    Text(W8Text.t("待复核", "To review")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let mapped { Text(mapped.node.place).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
            Text(TopicLocationTodos.statusText(row.status)).font(.subheadline)
                .foregroundStyle(row.blocking ? Color.red : Color.secondary)
            // What to look at / what to do / when it can't be seen: shown only when the author contract has them.
            if let what = nonempty(row.observationTarget) {
                Text(W8Text.t("看什么：\(what)", "Look at: \(what)")).font(.subheadline).foregroundStyle(.secondary)
            }
            if let how = nonempty(row.observationAction) {
                Text(W8Text.t("怎么做：\(how)", "What to do: \(how)")).font(.subheadline).foregroundStyle(.secondary)
            }
            if let fallback = TopicLocationTodos.fallbackText(row.alternativePolicy) {
                Text(fallback).font(.subheadline).foregroundStyle(.secondary)
            }
            if let message = nonempty(row.issueMessage) {
                Text(message).font(.subheadline).foregroundStyle(row.blocking ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: CYSpacing.sm) {
                if let mapped, mapped.claimed {
                    Button(busy ? W8Text.t("确认中…", "Confirming…") : W8Text.t("确认地点", "Confirm place")) { confirm(mapped.node) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text(W8Text.t("确认\(row.title)的地点", "Confirm the place for \(row.title)")))
                        .accessibilityIdentifier("locationTodos.confirm.\(row.slotKey)")
                } else if mapped == nil {
                    Button(busy ? W8Text.t("绑定中…", "Saving…") : W8Text.t("选择节点", "Choose a stop")) { pick() }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text(W8Text.t("为\(row.title)选择节点", "Choose a stop for \(row.title)")))
                        .accessibilityIdentifier("locationTodos.pick.\(row.slotKey)")
                }
            }
            .disabled(anyBusy)
            if let error {
                Text(error).font(.subheadline).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("locationTodos.error.\(row.slotKey)")
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locationTodos.row.\(row.slotKey)")
    }
}
