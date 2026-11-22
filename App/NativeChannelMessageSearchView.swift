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
                CYHeroHeader("search.title", tableName: "NativeChannelMessage")
                    .channelKitInset(clear: true)
            }
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
                    .cyText(.meta)
                    .foregroundStyle(CYColor.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
                CYPillButton("search.run", tableName: "NativeChannelMessage") { search() }
                    .accessibilityLabel(Text("search.run", tableName: "NativeChannelMessage"))
                    .channelKitInset(clear: true)
            } header: {
                CYSectionHeader("d7.channelSearch.filters")
            }
            if model.isCurrent {
                if let oldest = model.oldestSearchableAt {
                    LabeledContent {
                        Text(verbatim: shown(oldest)).cyText(.numericBody).monospacedDigit()
                    } label: { Text("search.retention", tableName: "NativeChannelMessage") }
                }
                if let reason = model.degradedReason {
                    Label {
                        Text(LocalizedStringKey(degradationKey(reason)), tableName: "NativeChannelMessage")
                    } icon: {
                        Image(systemName: "info.circle").accessibilityHidden(true)
                    }
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
                ForEach(groups, id: \.0) { group in
                    Section {
                        ForEach(group.1, id: \.id) { row in
                            Button { if model.isCurrent { locateOriginal?(row.id) } } label: {
                                CYListRow(verbatim: shown(row.content), trailing: locateOriginal == nil ? CYListRowTrailing.none : .chevron) {
                                    ChannelCoverTile(seed: row.id.rawValue, symbol: symbol(for: row.kind))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(locateOriginal == nil)
                            .accessibilityIdentifier("ncm47.search.\(row.id.rawValue)")
                            .accessibilityLabel(Text(verbatim: shown(row.content)))
                        }
                    } header: {
                        Text(verbatim: group.0)
                            .cyText(.sectionTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                if model.rows.isEmpty && model.query != nil && !model.loading && !model.failed {
                    CYEmptyState(systemImage: "magnifyingglass", "search.empty", tableName: "NativeChannelMessage", kind: .search)
                        .channelKitInset(clear: true)
                }
                if model.hasMore {
                    CYPillButton("search.more", style: .secondary, tableName: "NativeChannelMessage") { more() }
                        .disabled(model.loading)
                        .accessibilityLabel(Text("search.more", tableName: "NativeChannelMessage"))
                        .channelKitInset(clear: true)
                }
            } else {
                CYEmptyState(systemImage: "lock", "access.closed", tableName: "NativeChannelMessage")
                    .channelKitInset(clear: true)
            }
            if model.loading { CYSkeleton().channelKitInset(clear: true) }
            if model.failed {
                Section {
                    CYEmptyState(
                        systemImage: "exclamationmark.triangle",
                        "load.failed",
                        tableName: "NativeChannelMessage",
                        actionTitle: "messaging.retry",
                        actionStyle: .secondary,
                        kind: .failure
                    ) { search() }
                    .disabled(!model.isCurrent || model.loading || phase != .active)
                    .channelKitInset(clear: true)
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
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.done") { dismiss() } } }
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

private struct ChannelCoverTile: View {
    let seed: String
    let symbol: String
    var body: some View {
        Color.clear
            .frame(width: 40, height: 40)
            .overlay {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ChannelKitInset: ViewModifier {
    var clear = false
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(clear ? Color.clear : CYColor.bgElevated)
            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: CYSpacing.md, trailing: CYSpacing.lg))
    }
}

private extension View {
    func channelKitInset(clear: Bool = false) -> some View {
        modifier(ChannelKitInset(clear: clear))
    }
}
