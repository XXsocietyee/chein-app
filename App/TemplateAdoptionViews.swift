import SwiftUI

/// Per-owner adoption journal (`author:template-adoption:v1:<owner>:<scope>:<sourceId>`), kept in user defaults
/// like the mini-program's storage. Only the command facts are stored; no token, no draft content.
struct TemplateAdoptionJournal {
    let owner: Int
    let scope: String
    let sourceID: Int
    var defaults: UserDefaults = .standard

    private var key: String {
        let allowed = CharacterSet.alphanumerics
        return "author:template-adoption:v1:" + String(owner) + ":"
            + (scope.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") + ":" + String(sourceID)
    }
    func load() throws -> TemplateAdoptionService.Record? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(TemplateAdoptionService.Record.self, from: data)
    }
    func save(_ record: TemplateAdoptionService.Record) throws {
        defaults.set(try JSONEncoder().encode(record), forKey: key)
        guard try load() == record else { throw PlayerCapabilityFailure.outcomeUnknown }
    }
    func clear() { defaults.removeObject(forKey: key) }
}

/// 「采用为我的草稿」 for a public template. Every retry resumes the journaled command; none mints a new request.
struct TemplateAdoptButton: View {
    let sourceTemplateID: Int
    let accountID: Int
    let scope: String
    let client: PlayerCapabilityClient
    var onAdopted: (SquareGovernanceJSON) -> Void = { _ in }
    @Environment(\.locale) private var locale
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { Task { await adopt() } } label: {
                Label(PlayerCapabilityCopy.text("采用为我的草稿", "Adopt as my draft", locale), systemImage: "square.and.arrow.down")
            }
            .disabled(busy)
            .accessibilityIdentifier("template.adopt")
            if busy { ProgressView() }
            if let message {
                Text(verbatim: message).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func adopt() async {
        guard !busy else { return }
        busy = true; message = nil
        let journal = TemplateAdoptionJournal(owner: accountID, scope: scope, sourceID: sourceTemplateID)
        let outcome = await TemplateAdoptionService(client: client).adopt(sourceID: sourceTemplateID, owner: accountID, scope: scope,
            load: { try journal.load() }, save: { try journal.save($0) }, clear: { journal.clear() })
        switch outcome {
        case .ready(let draft):
            message = PlayerCapabilityCopy.text("已采用，草稿在「我的玩法」里", "Adopted into your drafts", locale)
            onAdopted(draft)
        case .rejected(let text), .unconfirmed(let text):
            message = text
        }
        busy = false
    }
}

/// Last confirmed `binding-status` read for one topic. A failed read keeps the last confirmed view; it never
/// draws 「没有待办」. Owned by a modifier on an always-present host (a `.task` on an empty section never runs).
@MainActor final class TemplateLocationTodosStore: ObservableObject {
    @Published private(set) var todos: TemplateAdoptionService.LocationTodos?
    private var loadedTopic: Int?

    func load(topicID: Int, scope: String, client: PlayerCapabilityClient) async {
        if loadedTopic != topicID { todos = nil; loadedTopic = topicID }
        if let value = try? await TemplateAdoptionService(client: client).bindingStatus(topicID: topicID, scope: scope),
           loadedTopic == topicID {
            todos = value
        }
    }
}

/// U02-03/U02-04 地点待办. Only `level=error` blocks publishing; warn is advisory. No contract: nothing is drawn.
struct TemplateLocationTodosSection: View {
    let topicID: Int
    let scope: String
    let client: PlayerCapabilityClient
    /// Author nodes that have a place (`bindableNodes`): id and 「名称 · 地址」.
    let bindableNodes: [(id: Int, label: String)]
    @ObservedObject var store: TemplateLocationTodosStore
    @Environment(\.locale) private var locale
    private var todos: TemplateAdoptionService.LocationTodos? { store.todos }
    @State private var busySlot: String?
    @State private var rowError: [String: String] = [:]
    @State private var picking: TemplateAdoptionService.LocationRow?

    var body: some View {
        Group {
            if let todos {
                Section {
                    if let source = todos.sourceTopicText {
                        Text(verbatim: [source, todos.sourceRevisionText, todos.intentText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(todos.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent {
                                Text(verbatim: row.statusText).font(.footnote)
                                    .foregroundStyle(row.blocking ? AnyShapeStyle(.red) : (row.warn ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary)))
                            } label: {
                                Text(verbatim: row.title).font(.headline)
                            }
                            if !row.what.isEmpty || !row.how.isEmpty {
                                Text(verbatim: [row.what, row.how].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            if !row.issueText.isEmpty { Text(verbatim: row.issueText).font(.footnote).foregroundStyle(.orange) }
                            if let error = rowError[row.slotKey] { Text(verbatim: error).font(.footnote).foregroundStyle(.red) }
                            Button(PlayerCapabilityCopy.text("选节点绑定", "Bind a node", locale)) {
                                if bindableNodes.isEmpty { rowError[row.slotKey] = PlayerCapabilityCopy.text("先在章节里给节点设置这座城市的地点并保存", "First set a place in this city for a node in your chapters, then save", locale) }
                                else { picking = row }
                            }
                            .buttonStyle(.borderless)
                            .disabled(busySlot != nil)
                            .accessibilityIdentifier("template.location.bind.\(row.slotKey)")
                        }
                    }
                } header: {
                    Text(verbatim: PlayerCapabilityCopy.text("地点待办", "Location to-dos", locale) + (todos.summary.isEmpty ? "" : " · " + todos.summary))
                }
            }
        }
        .confirmationDialog(
            PlayerCapabilityCopy.text("绑定到哪个节点", "Bind to which node", locale),
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            titleVisibility: .visible,
            presenting: picking
        ) { row in
            ForEach(bindableNodes.indices, id: \.self) { index in
                Button(bindableNodes[index].label) { Task { await bind(row, nodeID: bindableNodes[index].id) } }
            }
        }
    }

    private func load() async {
        await store.load(topicID: topicID, scope: scope, client: client)
    }

    private func bind(_ row: TemplateAdoptionService.LocationRow, nodeID: Int) async {
        picking = nil
        busySlot = row.slotKey; rowError[row.slotKey] = nil
        do {
            try await TemplateAdoptionService(client: client).bind(topicID: topicID, scope: scope, slotKey: row.slotKey,
                                                                   nodeID: nodeID, expectedRevision: row.revision)
        } catch PlayerCapabilityFailure.outcomeUnknown {
            rowError[row.slotKey] = PlayerCapabilityCopy.text("绑定结果未确认，已重新读取", "Couldn't confirm the binding, so we reloaded it", locale)
        } catch {
            rowError[row.slotKey] = PlayerCapabilityCopy.failure(error, fallback: PlayerCapabilityCopy.text("绑定失败", "Couldn't bind", locale))
        }
        busySlot = nil
        await load()
    }
}

/// My-project actions: BL-120 另存为模板 and 提交广场审核. Each id has at most one request in flight.
struct TemplateProjectActions: View {
    enum Kind { case topic, template }
    let id: Int
    let title: String
    let kind: Kind
    let scope: String
    let client: PlayerCapabilityClient
    var reload: () -> Void = {}
    @Environment(\.locale) private var locale
    @State private var busy = false
    @State private var confirming = false
    @State private var toast: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(kind == .topic ? PlayerCapabilityCopy.text("另存为模板", "Save as template", locale)
                                  : PlayerCapabilityCopy.text("提交广场审核", "Submit to the market", locale)) {
                if kind == .topic { confirming = true } else { Task { await run() } }
            }
            .disabled(busy)
            .accessibilityIdentifier(kind == .topic ? "template.saveAs.\(id)" : "template.marketSubmit.\(id)")
            if let toast { Text(verbatim: toast).font(.footnote).foregroundStyle(.secondary) }
        }
        .confirmationDialog(
            PlayerCapabilityCopy.text("另存为模板", "Save as template", locale),
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button(PlayerCapabilityCopy.text("另存为模板", "Save as template", locale)) { Task { await run() } }
        } message: {
            if title.isEmpty { Text("templateAdoption.shelfNotice.untitled") }
            else { Text("templateAdoption.shelfNotice \(appQuoted(title, locale: locale))") }
        }
    }

    private func run() async {
        guard !busy else { return }
        busy = true; toast = nil
        let service = TemplateAdoptionService(client: client)
        do {
            if kind == .topic { try await service.saveAsTemplate(topicID: id, scope: scope); toast = PlayerCapabilityCopy.text("已另存为主题模板", "Saved as a template", locale) }
            else { try await service.submitToMarket(templateID: id, scope: scope); toast = PlayerCapabilityCopy.text("已提交广场审核", "Submitted to the market for review", locale) }
            reload()
        } catch {
            toast = PlayerCapabilityCopy.failure(error, fallback: kind == .topic ? PlayerCapabilityCopy.text("另存为模板失败", "Couldn't save as a template", locale) : PlayerCapabilityCopy.text("提交失败", "Couldn't submit", locale))
        }
        busy = false
    }
}
