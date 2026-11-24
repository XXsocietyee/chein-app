import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Mini-program `pages/publish/fabu` embeds `story-rule-editor` per route mapping.
/// DESIGNED local home: the rule sentences live in the chapter's preserved draft metadata (`routeRules`);
/// nothing is sent anywhere until the existing publish pipeline adopts the key.
@available(macOS 14.0, *)
@MainActor struct ProjectEditChapterRulesSection: View {
    @Binding var chapter: ProjectEditChapter

    private var ruleCount: Int {
        let rules = chapter.preserved["routeRules"]?.object
        return (rules?["conditions"]?.array?.count ?? 0) + (rules?["effects"]?.array?.count ?? 0)
    }

    var body: some View {
        Section {
            NavigationLink {
                ProjectEditChapterRulesEditor(chapter: $chapter)
            } label: {
                LabeledContent(W8Text.t("剧情规则", "Story rules"),
                               value: ruleCount == 0 ? W8Text.t("未设置", "Not set") : W8Text.t("\(ruleCount) 条", "\(ruleCount)"))
                    .frame(minHeight: 44)
            }
            .accessibilityLabel(W8Text.t("编辑本章剧情规则", "Edit this chapter's story rules"))
        } footer: {
            Text(verbatim: W8Text.t("用句子描述条件与效果，保存在本章草稿中。", "Describe conditions and effects as sentences; they are kept in this chapter's draft."))
        }
    }
}

@available(macOS 14.0, *)
@MainActor private struct ProjectEditChapterRulesEditor: View {
    @Binding var chapter: ProjectEditChapter
    @State private var model: StoryRuleEditorModel?

    var body: some View {
        ScrollView {
            if let model {
                StoryRuleEditorView(model: model)
                    .onChange(of: model.draft) { _, value in save(value) }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .navigationTitle(W8Text.t("剧情规则", "Story rules")).navigationBarTitleDisplayMode(.inline)
        .task {
            guard model == nil else { return }
            model = StoryRuleEditorModel(value: load(), nodeIds: Set(chapter.nodes.map(\.id)), identity: chapter.id)
        }
        .onDisappear { model?.detach() }
    }

    private func load() -> PlayWireValue {
        guard let stored = chapter.preserved["routeRules"],
              let data = try? JSONEncoder().encode(stored),
              let value = try? JSONDecoder().decode(PlayWireValue.self, from: data), value.object != nil else {
            return .object(["conditions": .array([]), "effects": .array([])])
        }
        return value
    }

    private func save(_ value: PlayWireValue) {
        guard let data = try? JSONEncoder().encode(value),
              let stored = try? JSONDecoder().decode(ProjectEditJSON.self, from: data) else { return }
        chapter.preserved["routeRules"] = stored
    }
}
