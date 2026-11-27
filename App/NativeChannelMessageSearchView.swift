import SwiftUI

@MainActor struct NativeChannelMessageSearchView: View {
    @Bindable var model: NativeChannelMessageSearch
    @State private var keyword = ""
    @State private var author = ""
    @State private var from = ""
    @State private var to = ""
    @State private var invalidFilter = false
    @State private var readTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var phase
    @Environment(\.themeDomain) private var domain
    @Environment(\.dismiss) private var dismiss
    var locateOriginal: ((NativeChannelMessageID) -> Void)?
    private var groups: [(String, [NativeChannelMessageSnapshot])] {
        var keys: [String] = []; var grouped: [String: [NativeChannelMessageSnapshot]] = [:]
        for row in model.rows {
            let date = row.message.createdAt ?? ""
            let key = date.range(of: "^\\d{4}-\\d{2}-\\d{2}", options: .regularExpression).map { String(date[$0]) } ?? "—"
            if grouped[key] == nil { keys.append(key) }; grouped[key, default: []].append(row)
        }
        return keys.map { ($0, grouped[$0] ?? []) }
    }
    var body: some View {
        List {
            Section {
                TextField("", text: $author, prompt: Text("search.author", tableName: "NativeChannelMessage")).keyboardType(.numberPad)
                    .accessibilityLabel(Text("search.author", tableName: "NativeChannelMessage"))
                TextField("", text: $from, prompt: Text("search.from", tableName: "NativeChannelMessage"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel(Text("search.from", tableName: "NativeChannelMessage"))
                TextField("", text: $to, prompt: Text("search.to", tableName: "NativeChannelMessage"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel(Text("search.to", tableName: "NativeChannelMessage"))
                if invalidFilter {
                    Label {
                        Text("search.invalid", tableName: "NativeChannelMessage")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityElement(children: .combine)
                }
                Button { search() } label: { Text("search.run", tableName: "NativeChannelMessage") }
                    .accessibilityLabel(Text("search.run", tableName: "NativeChannelMessage"))
            } header: {
                Text("d7.channelSearch.filters")
            }
            if model.isCurrent {
                if let oldest = model.oldestSearchableAt {
                    LabeledContent {
                        Text(verbatim: shown(oldest)).monospacedDigit()
                    } label: { Text("search.retention", tableName: "NativeChannelMessage") }
                }
                if let reason = model.degradedReason {
                    Label {
                        Text(LocalizedStringKey(degradationKey(reason)), tableName: "NativeChannelMessage")
                    } icon: {
                        Image(systemName: "info.circle").accessibilityHidden(true)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
                ForEach(groups, id: \.0) { group in
                    Section {
                        ForEach(group.1, id: \.id) { row in
                            Button { if model.isCurrent { locateOriginal?(row.id) } } label: {
                                HStack {
                                    Label {
                                        Text(verbatim: shown(row.content))
                                    } icon: {
                                        Image(systemName: symbol(for: row.kind)).foregroundStyle(.secondary)
                                    }
                                    if locateOriginal != nil {
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary).accessibilityHidden(true)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .foregroundStyle(.primary)
                            .disabled(locateOriginal == nil)
                            .accessibilityIdentifier("ncm47.search.\(row.id.rawValue)")
                            .accessibilityLabel(Text(verbatim: shown(row.content)))
                        }
                    } header: {
                        Text(verbatim: group.0)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                if model.rows.isEmpty && model.query != nil && !model.loading && !model.failed {
                    ContentUnavailableView {
                        Label { Text("search.empty", tableName: "NativeChannelMessage") } icon: { Image(systemName: "magnifyingglass") }
                    }
                }
                if model.hasMore {
                    Button { more() } label: { Text("search.more", tableName: "NativeChannelMessage") }
                        .disabled(model.loading)
                        .accessibilityLabel(Text("search.more", tableName: "NativeChannelMessage"))
                }
            } else {
                ContentUnavailableView {
                    Label { Text("access.closed", tableName: "NativeChannelMessage") } icon: { Image(systemName: "lock") }
                }
            }
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            if model.failed {
                Section {
                    ContentUnavailableView {
                        Label { Text("load.failed", tableName: "NativeChannelMessage") } icon: { Image(systemName: "exclamationmark.triangle") }
                    } actions: {
                        Button("messaging.retry") { search() }
                            .buttonStyle(.bordered)
                    }
                    .disabled(!model.isCurrent || model.loading || phase != .active)
                }
            }
        }
        .nativeChannelScreen()
        .listStyle(.insetGrouped)
        .tint(Theme.Color.accent(in: domain))
        .searchable(text: $keyword, prompt: Text("search.keyword", tableName: "NativeChannelMessage"))
        .onSubmit(of: .search, search)
        .onChange(of: keyword) { _, _ in retireRead() }
        .onChange(of: author) { _, _ in retireRead() }
        .onChange(of: from) { _, _ in retireRead() }
        .onChange(of: to) { _, _ in retireRead() }
        .onChange(of: phase) { _, value in if value != .active { retireRead() } }
        .onChange(of: model.isCurrent) { _, value in if !value { retireRead() } }
        .navigationTitle(Text("search.title", tableName: "NativeChannelMessage"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
        .onDisappear { retireRead() }
        .privacySensitive()
    }
    /// Unknown copy is an em dash. A real value, including a real 0, stays as written.
    private func shown(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : (value ?? "—")
    }
    private func symbol(for kind: NativeChannelMessageKind) -> String {
        switch kind {
        case .image: return "photo"
        case .voice: return "waveform"
        case .video: return "video"
        case .file: return "doc"
        case .location: return "mappin.and.ellipse"
        case .poll, .pollResult: return "chart.bar"
        case .card: return "rectangle.on.rectangle"
        default: return "text.bubble"
        }
    }
    private func search() {
        guard phase == .active, model.isCurrent else { retireRead(); return }
        readTask?.cancel()
        let member = author.isEmpty ? nil : NativeChannelMessageID(rawValue: author)
        guard author.isEmpty || member != nil else { invalidFilter = true; model.retire(); return }
        let query = NativeChannelMessageQuery(keyword: keyword, from: from.isEmpty ? nil : from, to: to.isEmpty ? nil : to, authorID: member)
        do { try query.validate() }
        catch { invalidFilter = true; model.retire(); return }
        invalidFilter = false
        readTask = Task { await model.replace(query) }
    }
    private func more() {
        guard phase == .active, model.isCurrent else { retireRead(); return }
        readTask?.cancel()
        readTask = Task { await model.more() }
    }
    private func retireRead() {
        readTask?.cancel(); readTask = nil; model.retire()
    }
    private func degradationKey(_ reason: String) -> String {
        switch reason {
        case "SHORT_KEYWORD_LIKE": return "search.shortKeyword"
        case "RETENTION_BOUNDARY": return "search.retentionClipped"
        case "SHORT_KEYWORD_AND_RETENTION_BOUNDARY": return "search.shortAndClipped"
        default: return "search.degraded"
        }
    }
}
