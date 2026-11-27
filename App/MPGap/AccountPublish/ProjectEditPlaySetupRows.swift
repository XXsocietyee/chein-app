import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The account host's creator-tools service, read by the topic editor's 主题详情 sheet for the
/// 可玩时段 / 开局前准备 rows. Nil (signed out, no grant, preview, fixture) hides the rows.
struct TopicPlaySetupSource {
    let ownerKey: String
    let make: () -> TopicCreatorEditorService?
}

private struct TopicPlaySetupSourceKey: EnvironmentKey {
    static let defaultValue: TopicPlaySetupSource? = nil
}

extension EnvironmentValues {
    var topicPlaySetupSource: TopicPlaySetupSource? {
        get { self[TopicPlaySetupSourceKey.self] }
        set { self[TopicPlaySetupSourceKey.self] = newValue }
    }
}

/// MP `publish/fabu/topic-detail-sheet.wxml:213-214`: after the game rules, two cards
/// 可玩时段 (only when no 归属俱乐部, `clubIndex < 0`) and 开局前准备 (`N 项` / `未设置`), each opening
/// its own sheet. Native: two rows of the 主题详情 sheet that push one page each.
@MainActor struct ProjectEditPlaySetupRows: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.topicPlaySetupSource) private var source

    var body: some View {
        if let source {
            if let topicID = model.coordinator.publicationTopicID, topicID > 0, let service = source.make() {
                ProjectEditPlaySetupLoadedRows(makeTools: { TopicCreatorToolsModel(service: service, topicID: Int64(topicID), ownerKey: source.ownerKey) },
                                               showsWindow: model.draft.clubID == nil, enabled: model.canEdit)
                    .id(topicID)
            } else {
                // MP 线索与物品 pattern: these settings are saved on the topic, so a new draft says so instead of a dead row.
                Section {
                    Text("creatorEditor.playSetup.saveFirst", tableName: "CreatorEditorUI")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: {
                    Text("creatorEditor.playSetup.header", tableName: "CreatorEditorUI")
                }
            }
        }
    }
}

@MainActor private struct ProjectEditPlaySetupLoadedRows: View {
    @StateObject var tools: TopicCreatorToolsModel
    let showsWindow: Bool
    let enabled: Bool
    @State private var loaded = false

    init(makeTools: @escaping () -> TopicCreatorToolsModel, showsWindow: Bool, enabled: Bool) {
        _tools = StateObject(wrappedValue: makeTools())
        self.showsWindow = showsWindow
        self.enabled = enabled
    }

    var body: some View {
        Section {
            if showsWindow {
                NavigationLink {
                    TopicPlaySetupPage(tools: tools, part: .window)
                } label: {
                    LabeledContent {
                        Text(TopicPlaySetupFormat.windowSummary(tools.setup.window))
                    } label: {
                        Label { Text("creatorEditor.window", tableName: "CreatorEditorUI") } icon: { Image(systemName: "clock") }
                    }
                }
                .disabled(!enabled || !loaded)
                .accessibilityIdentifier("projectEdit.topicDetail.playWindow")
            }
            NavigationLink {
                TopicPlaySetupPage(tools: tools, part: .prep)
            } label: {
                LabeledContent {
                    Text(TopicPlaySetupFormat.prepSummary(tools.setup.prepItems.count))
                } label: {
                    Label { Text("creatorEditor.prep", tableName: "CreatorEditorUI") } icon: { Image(systemName: "checklist") }
                }
            }
            .disabled(!enabled || !loaded)
            .accessibilityIdentifier("projectEdit.topicDetail.prep")
        }
        .task {
            guard !loaded else { return }
            await tools.load()
            loaded = true
        }
    }
}

enum TopicPlaySetupFormat {
    static func windowSummary(_ window: TopicPlayWindow) -> LocalizedStringResource {
        if window.mode == .custom, let start = window.start, let end = window.end {
            return LocalizedStringResource("creatorEditor.window.range \(start) \(end)", table: "CreatorEditorUI")
        }
        return LocalizedStringResource(String.LocalizationValue("creatorEditor.window." + window.mode.rawValue), table: "CreatorEditorUI")
    }

    static func prepSummary(_ count: Int) -> LocalizedStringResource {
        if count == 0 { return LocalizedStringResource("creatorEditor.prep.none", table: "CreatorEditorUI") }
        return LocalizedStringResource("creatorEditor.prep.count \(count)", table: "CreatorEditorUI")
    }
}

/// One pushed page for the MP choice-sheet (可玩时段) or the MP start-prep sheet (开局前准备), with 保存.
@MainActor struct TopicPlaySetupPage: View {
    enum Part { case window, prep }
    @ObservedObject var tools: TopicCreatorToolsModel
    let part: Part

    var body: some View {
        Form {
            if let message = tools.message {
                Section { Text(LocalizedStringKey(message), tableName: "CreatorEditorUI").foregroundStyle(.secondary) }
            }
            switch part {
            case .window: TopicPlayWindowFields(tools: tools)
            case .prep: TopicPrepFields(tools: tools)
            }
        }
        .navigationTitle(part == .window ? Text("creatorEditor.window", tableName: "CreatorEditorUI") : Text("creatorEditor.prep", tableName: "CreatorEditorUI"))
        .navigationBarTitleDisplayMode(.inline)
        .disabled(tools.busy)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await tools.savePlaySetup() } } label: { Text("creatorEditor.save", tableName: "CreatorEditorUI") }
                    .accessibilityIdentifier("creatorEditor.playSetup.save")
            }
        }
    }
}

/// MP choice-sheet options (theme-d20.js `WINDOWS`): glyph per mode, hours under 只在白天 / 只在夜间;
/// 自定义 reveals 开始 / 结束.
@MainActor struct TopicPlayWindowFields: View {
    @ObservedObject var tools: TopicCreatorToolsModel

    /// MP end option `次日 02:00` reads "02:00 next day" in English; other ends are plain times.
    static func windowEndLabel(_ end: String) -> Text {
        let time = end.replacingOccurrences(of: "^次日\\s*", with: "", options: .regularExpression)
        if time == end { return Text(verbatim: end) }
        return Text("creatorEditor.window.nextDay \(time)", tableName: "CreatorEditorUI")
    }
    static func windowHours(_ mode: TopicPlayWindow.Mode) -> String? {
        switch mode {
        case .day: return "06:00–20:00"
        case .night: return "20:00–06:00"
        case .any, .custom: return nil
        }
    }
    static func windowGlyph(_ mode: TopicPlayWindow.Mode) -> String {
        switch mode {
        case .any: return "infinity"
        case .day: return "sun.max"
        case .night: return "moon.stars"
        case .custom: return "clock"
        }
    }

    var body: some View {
        Section {
            Picker(selection: $tools.setup.window.mode) {
                ForEach(TopicPlayWindow.Mode.allCases, id: \.self) { mode in
                    Label {
                        Text(LocalizedStringKey("creatorEditor.window." + mode.rawValue), tableName: "CreatorEditorUI")
                        if let hours = Self.windowHours(mode) { Text(verbatim: hours) }
                    } icon: { Image(systemName: Self.windowGlyph(mode)) }
                    .tag(mode)
                }
            } label: { Text("creatorEditor.window", tableName: "CreatorEditorUI") }
            if tools.setup.window.mode == .custom {
                Picker(selection: Binding(get: { tools.setup.window.start ?? TopicPlayWindow.starts[0] }, set: { tools.setup.window.start = $0 })) {
                    ForEach(TopicPlayWindow.starts, id: \.self) { Text(verbatim: $0).tag($0) }
                } label: { Text("creatorEditor.window.start", tableName: "CreatorEditorUI") }
                Picker(selection: Binding(get: { tools.setup.window.end ?? TopicPlayWindow.ends[0] }, set: { tools.setup.window.end = $0 })) {
                    ForEach(TopicPlayWindow.ends, id: \.self) { end in Self.windowEndLabel(end).tag(end) }
                } label: { Text("creatorEditor.window.end", tableName: "CreatorEditorUI") }
            }
        }
    }
}

/// MP `publish/components/start-prep`: 准备项 (swipe delete, 编辑 = reorder, add row ≤20 characters, no
/// duplicates, hidden at 6) → 建议 (first three `PREP_SUGGESTIONS` not yet added).
@MainActor struct TopicPrepFields: View {
    @ObservedObject var tools: TopicCreatorToolsModel
    @State private var newPrep = ""

    private static let suggestionKeys = (1...6).map { "creatorEditor.prep.suggestion." + String($0) }
    private static let maxLength = 20

    private var suggestions: [String] {
        let have = Set(tools.setup.prepItems)
        let all = Self.suggestionKeys.map { String(localized: String.LocalizationValue($0), table: "CreatorEditorUI") }
        return Array(all.filter { !have.contains($0) }.prefix(3))
    }
    private var canAdd: Bool { tools.setup.prepItems.count < TopicPlaySetup.maximumPrepItems }

    private func add(_ text: String) -> Bool {
        let item = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
        guard !item.isEmpty, canAdd, !tools.setup.prepItems.contains(item) else { return false }
        tools.setup.prepItems.append(item)
        return true
    }

    var body: some View {
        Section {
            ForEach(Array(tools.setup.prepItems.enumerated()), id: \.offset) { _, item in Text(verbatim: item) }
                .onDelete { tools.setup.prepItems.remove(atOffsets: $0) }
                .onMove { tools.setup.prepItems.move(fromOffsets: $0, toOffset: $1) }
            if canAdd {
                HStack {
                    TextField(text: Binding(get: { newPrep }, set: { newPrep = String($0.prefix(Self.maxLength)) })) { Text("creatorEditor.prep.add", tableName: "CreatorEditorUI") }
                        .submitLabel(.done)
                        .onSubmit { if add(newPrep) { newPrep = "" } }
                    Button {
                        if add(newPrep) { newPrep = "" }
                    } label: { Text("creatorEditor.prep.addAction", tableName: "CreatorEditorUI") }
                        .buttonStyle(.borderless)
                        .disabled(newPrep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        } header: {
            HStack {
                Text("creatorEditor.prep", tableName: "CreatorEditorUI")
                Spacer()
                if !tools.setup.prepItems.isEmpty { EditButton().font(.footnote) }
            }
        } footer: {
            Text("creatorEditor.prep.footer", tableName: "CreatorEditorUI")
        }
        .accessibilityIdentifier("creatorEditor.prep")
        if canAdd && !suggestions.isEmpty {
            Section {
                ForEach(suggestions, id: \.self) { item in
                    Button { _ = add(item) } label: { Label { Text(verbatim: item) } icon: { Image(systemName: "plus.circle.fill") } }
                }
            } header: { Text("creatorEditor.prep.suggestions", tableName: "CreatorEditorUI") }
        }
    }
}
