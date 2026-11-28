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
    /// MP `replacePlace`: change only this stop's address in the editor's own place picker (not a re-bind).
    let replace: ((String) -> Void)?
    @StateObject private var model: TopicLocationTodosModel
    @State private var open = false

    init(topicID: Int, scope: String?, nodes: [TopicLocationEditorNode], replace: ((String) -> Void)? = nil) {
        self.nodes = nodes
        self.replace = replace
        _model = StateObject(wrappedValue: TopicLocationTodosModel(client: TopicTemplateAdoptionFactory.makeBindingClient(),
                                                                   topicId: topicID, scope: scope))
    }

    private func replacePlace(_ nodeID: String) {
        open = false
        replace?(nodeID)
    }

    /// Passed to the sheet only when the editor supplied `replace` (MP shows 替换地点 only then).
    private var replaceAction: ((String) -> Void)? {
        guard replace != nil else { return nil }
        return { nodeID in replacePlace(nodeID) }
    }

    private func countText(_ todos: TopicLocationTodos) -> String {
        todos.summaryText ?? W8Text.t("\(todos.rows.count) 个地点", "\(todos.rows.count) place(s)")
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
                            Text(countText(todos))
                                .foregroundStyle(todos.blockingCount > 0 ? CYColor.dangerText : Color.secondary)
                        }
                    }
                    .accessibilityIdentifier("locationTodos.entry")
                }
                .cySheet(isPresented: $open) {
                    NavigationStack {
                        TopicLocationTodosSheet(model: model, nodes: nodes, replace: replaceAction)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
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
    let replace: ((String) -> Void)?
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
                                                 replace: replace,
                                                 pick: {
                                                     if nodes.isEmpty { model.pickError(row) } else { picking = row }
                                                 })
                    }
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
    let replace: ((String) -> Void)?
    let pick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Text(row.title).font(.body).foregroundStyle(.primary).lineLimit(2)
                if row.blocking {
                    Text(W8Text.t("挡住发布", "Blocks publishing")).font(.caption).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("locationTodos.blocking")
                } else if row.warning {
                    Text(W8Text.t("待复核", "To review")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let mapped { Text(mapped.node.place).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
            Text(TopicLocationTodos.statusText(row.status)).font(.subheadline)
                .foregroundStyle(row.blocking ? CYColor.dangerText : Color.secondary)
            // MP b4-u02-03: each row is name + current address + status, then its actions (no extra lines).
            HStack(spacing: CYSpacing.sm) {
                if let mapped, let replace {
                    Button(W8Text.t("替换地点", "Replace place")) { replace(mapped.node.id) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text(W8Text.t("替换\(row.title)的地点", "Replace the place for \(row.title)")))
                        .accessibilityIdentifier("locationTodos.replace.\(row.slotKey)")
                }
                if let mapped, mapped.claimed {
                    Button(busy ? W8Text.t("确认中…", "Confirming…") : W8Text.t("确认地点", "Confirm place")) { confirm(mapped.node) }
                        .buttonStyle(.borderedProminent)
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
                Text(error).font(.subheadline).foregroundStyle(CYColor.dangerText)
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
