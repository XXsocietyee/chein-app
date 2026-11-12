import SwiftUI

/// Mount inside the existing NavigationStack with a stable, scope-specific reader.
/// This screen never starts a purchase, requests location or silently opens a scanner.
@MainActor
struct PlaySessionView: View {
    let reader: any PlayReading
    @State private var model: PlayViewModel
    @State private var selectedNodeID: Int?
    @State private var freePackOpen = false
    @State private var presentedMode: Int?
    init(reader: any PlayReading) {
        self.reader = reader; _model = State(initialValue: PlayViewModel(reader: reader))
    }
    var body: some View {
        Group {
            if !reader.scope.isValid {
                mapPanel { PlayIssueView(issue: .init(APIError.invalidRequest)) }
            } else if !reader.isConfigured {
                mapPanel { PlayIssueView(issue: .init(APIError.notConfigured)) }
            } else if reader.identity == nil {
                mapPanel { PlayIssueView(issue: .init(APIError.unauthorized)) }
            } else if model.isLoading {
                mapPanel { CYSkeleton().padding(CYSpacing.lg).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).accessibilityIdentifier("play.loading") }
            } else if let issue = model.visibleIssue {
                mapPanel { PlayIssueView(issue: issue) { Task { await model.load(keepingReceipt: true) } } }
            } else if let snapshot = model.visibleSnapshot {
                if snapshot.result.mode == 2 {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            FreeExplorationCardBrowser(snapshot: snapshot, packOpen: $freePackOpen) { id in
                                guard model.visibleSnapshot == snapshot, model.visibleSnapshot?.result.mode == 2 else { return }
                                selectedNodeID = id
                            }
                        }.padding(CYSpacing.lg)
                    }.background(CYColor.bgPage).accessibilityIdentifier("playFree.read.overview")
                } else if snapshot.result.mode == 1 { mapPanel { overview(snapshot) } }
                else { CYEmptyState(systemImage: "questionmark.circle", "playMode.unavailable") }
            } else {
                mapPanel { PlayIssueView(issue: .init(APIError.malformedResponse)) { Task { await model.load() } } }
            }
        }
        .privacySensitive()
        .appNavigationTitle(key: model.visibleSnapshot?.result.mode == 2 ? "playFree.title" : "play.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("play.refresh", systemImage: "arrow.clockwise") { Task { await model.load(keepingReceipt: true) } }
                    .disabled(model.isLoading || model.isSubmitting || reader.identity == nil || !reader.isConfigured)
                    .accessibilityIdentifier("play.refresh")
            }
        }
        .navigationDestination(item: $selectedNodeID) { nodeID in
            if model.visibleSnapshot?.result.mode == 2 { FreeExplorationReadStoreView(nodeID: nodeID, model: model) }
            else if model.visibleSnapshot?.result.mode == 1 { PlayNodeDetailView(nodeID: nodeID, model: model) }
            else { Text("playMode.unavailable") }
        }
        .task(id: reader.identity) { await model.load() }
        .onChange(of: reader.identity) { _, _ in selectedNodeID = nil; freePackOpen = false; presentedMode = nil }
        .onChange(of: model.visibleSnapshot?.result.mode) { _, mode in
            guard let mode else { return }
            if presentedMode != mode { selectedNodeID = nil; freePackOpen = false; presentedMode = mode }
        }
    }
    /// Map-first chrome: static map ground behind a three-detent panel that holds the unchanged content.
    private func mapPanel<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        CYMapScaffold(detent: .medium, map: { CYMapPlaceholder() }, controls: { EmptyView() }, floating: { EmptyView() }, panel: content)
    }
    private func overview(_ snapshot: PlaySnapshot) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let name = snapshot.result.topicName, !name.isEmpty {
                        Text(verbatim: name).font(CYTypography.sheetTitle).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("play.topicName")
                    }
                    Label(LocalizedStringKey(snapshot.availability.titleKey), systemImage: statusSymbol(snapshot.availability))
                        .font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("play.status")
                    if let total = snapshot.result.total, let done = snapshot.displayedDoneCount, total > 0 {
                        ProgressView(value: Double(min(done, total)), total: Double(total))
                        LabeledContent("play.progress") { Text(verbatim: "\(done) / \(total)").font(CYTypography.numericBody).monospacedDigit() }
                    } else {
                        // UNKNOWN progress is the em dash (PlayIndexPageReadiness.unknownMark), not a sentence or 0/0.
                        LabeledContent("play.progress") {
                            Text(verbatim: PlayIndexPageReadiness.unknownMark).font(CYTypography.numericBody)
                                .accessibilityLabel(Text("play.progress.unknown"))
                        }.foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("play.progress.unknown")
                    }
                    if let description = snapshot.result.topicDescription, !description.isEmpty { Text(verbatim: description) }
                    if let note = snapshot.result.timeNote, !note.isEmpty { Text(verbatim: note).foregroundStyle(.secondary) }
                    if let expires = snapshot.result.expiresAt, !expires.isEmpty {
                        LabeledContent("play.expiresAt") { Text(verbatim: expires) }
                    }
                    if let status = snapshot.route?.status, !status.isEmpty {
                        LabeledContent("play.routeStatus") { Text(verbatim: status) }
                    }
                }.padding(.vertical, 4)
            }
            if snapshot.availability != .active && snapshot.availability != .completed {
                Section { Text(LocalizedStringKey(snapshot.availability.detailKey)).foregroundStyle(.secondary) }
            }
            if let receipt = model.visibleReceipt { Section { PlayReceiptView(receipt: receipt) } }
            if snapshot.availability != .registrationRequired {
                Section("play.nodes") {
                    if snapshot.visibleNodes.isEmpty {
                        Text(LocalizedStringKey(snapshot.result.nodes.isEmpty ? "play.empty.detail" : "play.nodes.hidden")).foregroundStyle(.secondary)
                    }
                    ForEach(snapshot.visibleNodes) { node in
                        Button { selectedNodeID = node.id } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: snapshot.isDone(node) ? "checkmark.circle.fill" : snapshot.isLocked(node) ? "lock.circle" : "circle")
                                    .font(.title3).foregroundStyle(snapshot.isDone(node) ? CYColor.successText : CYColor.textTertiary)
                                VStack(alignment: .leading, spacing: 5) {
                                    if let name = node.name, !name.isEmpty { Text(verbatim: name).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                                    else { Text("play.node.untitled").font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                                    if let chapterID = node.chapterID, let chapter = snapshot.result.chapters.first(where: { $0.id == chapterID }),
                                       let name = chapter.name, !name.isEmpty {
                                        Text(verbatim: name).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let hook = node.hookText, !hook.isEmpty { Text(verbatim: hook).font(.subheadline).foregroundStyle(.secondary) }
                                    Text(LocalizedStringKey(snapshot.isDone(node) ? "play.node.completed" : snapshot.isLocked(node) ? "play.node.locked" : "play.node.open"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("play.node.\(node.id)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .refreshable { await model.load(keepingReceipt: true) }
        .accessibilityIdentifier("play.overview")
    }
    private func statusSymbol(_ availability: PlaySessionAvailability) -> String {
        switch availability { case .completed: return "checkmark.seal.fill"
        case .active: return "figure.walk"
        case .empty: return "map"
        default: return "lock.circle" }
    }
}

struct PlayReceiptView: View {
    let receipt: PlayAnswerReceipt
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("play.answer.accepted", systemImage: "checkmark.circle").font(CYTypography.bodyMedium).foregroundStyle(CYColor.successText)
            if let xp = receipt.xp { LabeledContent("play.xp") { Text(verbatim: String(xp)) } }
            if let score = receipt.puzzleScore { LabeledContent("play.puzzleScore") { Text(verbatim: String(score)) } }
            if receipt.completed == true { Text("play.answer.routeCompleted") }
        }.accessibilityIdentifier("play.answer.receipt")
    }
}
