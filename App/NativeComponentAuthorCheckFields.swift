import SwiftUI

/// Common check fields only; identity and specialized consumers remain untouched and visible in the original preview.
@MainActor struct NativeComponentAuthorCheckFields: View {
    @ObservedObject var model: NativeConditionAuthorController
    private var root: NativeConditionAuthorPath { .init() }
    private var check: [String: ProjectEditJSON] { model.document?.value.object ?? [:] }
    private var binding: NativeComponentAuthorBinding? { model.catalog?.component }
    var body: some View {
        Section("同场景原检定") {
            LabeledContent("原 checkId", value: check["checkId"]?.text ?? "不可读取")
            picker("skill", "注册属性 / 原角色技能", options: (binding?.counters ?? []) + (binding?.skills.keys.sorted() ?? []))
            picker("tier", "原难度档", options: ["easy", "medium", "hard"])
            picker("category", "原情境类别", options: ["PHY", "OBS", "SOC", "WIL"], optional: true)
            if binding?.whiteRed == true || check["kind"] != nil { picker("kind", "白 / 红检定", options: binding?.whiteRed == true ? ["WHITE", "RED"] : [], optional: true) }
            picker("failCostTag", "原已注册失败代价标签", options: binding?.tags ?? [], optional: true)
            TextField("成功文案", text: text("successText"), axis: .vertical)
            TextField("失败文案", text: text("failText"), axis: .vertical)
            Text("没有自动 DC、加值或结果。checkId、启用开关及原 passive/team/opposed/empathy 专属字段保持原值；失败/兜底分支继续走原路线编辑与发布校验。")
                .cyText(.meta).foregroundStyle(.secondary)
        }.disabled(!model.canEdit)
        Section("原条件修正") {
            let mods = check["mods"]?.array ?? []
            ForEach(Array(mods.enumerated()), id: \.offset) { i, value in
                NavigationLink {
                    NativeComponentAuthorModifierFields(model: model, path: root.field("mods").index(i))
                } label: { Text(value.object?["label"]?.text ?? "未填写说明的修正") }
            }.onDelete { model.remove($0, from: root.field("mods")) }
                .onMove { model.move($0, to: $1, in: root.field("mods")) }
            if check["mods"] == nil || check["mods"]?.array != nil {
                Button("添加明确条件修正") {
                    let value: ProjectEditJSON = .object(["label": .string(""), "value": .string(""), "when": .array([])])
                    if check["mods"] == nil { model.setField("mods", at: root, to: .array([value])) }
                    else { model.append(value, to: root.field("mods")) }
                }.disabled(!model.canEdit || mods.count >= 128)
            }
        }.deleteDisabled(!model.canEdit).moveDisabled(!model.canEdit)
        ForEach(["advantageIf", "disadvantageIf", "retryIf"], id: \.self) { key in
            if check[key] != nil {
                NativeConditionAuthorExpressionSection(model: model, path: root.field(key), effect: false)
                Section { Button("移除此可选条件：" + key, role: .destructive) { model.removeField(key, at: root) }.disabled(!model.canEdit) }
            } else if key != "retryIf" || (binding?.whiteRed == true && check["kind"] == .string("WHITE")) {
                Section { Button("配置原条件：" + key) { model.setField(key, at: root, to: .array([])) }.disabled(!model.canEdit) }
            }
        }
        ForEach(["successEffects", "failEffects", "critEffects", "fumbleEffects"], id: \.self) { key in
            if check[key] != nil { NativeConditionAuthorExpressionSection(model: model, path: root.field(key), effect: true) }
            else { Section { Button("配置原结果效果：" + key) { model.setField(key, at: root, to: .array([])) }.disabled(!model.canEdit) } }
        }
    }
    private func text(_ key: String) -> Binding<String> {
        Binding(get: { check[key]?.text ?? "" }, set: { value in
            if value.isEmpty { model.removeField(key, at: root) } else { model.setField(key, at: root, to: .string(value)) }
        })
    }
    private func picker(_ key: String, _ title: String, options: [String], optional: Bool = false) -> some View {
        let current = check[key]?.text ?? ""
        return Picker(title, selection: Binding(get: { current }, set: { value in
            if optional && value.isEmpty { model.removeField(key, at: root) } else { model.setField(key, at: root, to: .string(value)) }
        })) {
            Text(optional ? "未配置（保留原语义）" : "请选择").tag("")
            if !current.isEmpty && !options.contains(current) { Text("原值（不可用）：" + current).tag(current) }
            ForEach(options, id: \.self) { Text(verbatim: $0).tag($0) }
        }
    }
}

@MainActor private struct NativeComponentAuthorModifierFields: View {
    @ObservedObject var model: NativeConditionAuthorController
    let path: NativeConditionAuthorPath
    private var row: [String: ProjectEditJSON] { model.value(path)?.object ?? [:] }
    var body: some View {
        Form {
            Section("原修正说明及数值") {
                TextField("给玩家看的说明", text: text("label"), axis: .vertical)
                Picker("修正来源", selection: Binding(get: { row["var"] == nil ? "value" : "var" }, set: { mode in
                    guard let value = model.value(path), var next = value.object else { return }
                    next.removeValue(forKey: mode == "var" ? "value" : "var"); next[mode] = .string("")
                    _ = model.replace(path, expected: value, with: .object(next))
                })) { Text("明确整数").tag("value"); Text("原注册属性 / 技能").tag("var") }
                if row["var"] != nil {
                    let options = (model.catalog?.component?.counters ?? []) + (model.catalog?.component?.skills.keys.sorted().map { "skill." + $0 } ?? [])
                    Picker("原修正变量", selection: text("var")) {
                        Text("请选择").tag("")
                        if let current = row["var"]?.text, !current.isEmpty && !options.contains(current) { Text(verbatim: current).tag(current) }
                        ForEach(options, id: \.self) { Text(verbatim: $0).tag($0) }
                    }
                } else {
                    TextField("明确整数（可为负）", text: Binding(get: { NativeAuthorNumericInput.display(row["value"]) }, set: {
                        model.setField("value", at: path, to: NativeAuthorNumericInput.numberInput($0))
                    })).keyboardType(.numbersAndPunctuation)
                }
            }.disabled(!model.canEdit)
            if row["when"] != nil { NativeConditionAuthorExpressionSection(model: model, path: path.field("when"), effect: false) }
            else { Section { Button("配置原只读条件") { model.setField("when", at: path, to: .array([])) }.disabled(!model.canEdit) } }
        }.navigationTitle("原检定修正").navigationBarTitleDisplayMode(.inline)
    }
    private func text(_ key: String) -> Binding<String> {
        Binding(get: { row[key]?.text ?? "" }, set: { model.setField(key, at: path, to: .string($0)) })
    }
}

/// Labels only. The original compiler, not this list, defines arithmetic semantics.
enum NativeComponentAuthorLabels {
    static let operations = ["ADD": "ADD · 加减原属性", "MIN": "MIN · 原属性下限操作", "MAX": "MAX · 原属性上限操作",
                             "RESET": "RESET · 原定义初始值", "CLAMP": "CLAMP · 原定义范围"]
}
