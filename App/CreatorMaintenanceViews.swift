import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// U08-03 creator maintenance workbench: problem → original content → fix draft → retest → new version → close.
/// The stage is the server's, derived from publish and retest facts; the app never advances it. Fixes are made and
/// published in the existing editor, and a new version never changes old runs.
@MainActor @Observable final class CreatorMaintenanceModel {
    enum Tab: Hashable { case feedback, tickets }
    enum Phase: Equatable { case idle, loading, loaded, failed(CreatorStudioFailure?) }
    /// An open whose response was lost; re-checked and re-sent with the same request id.
    struct PendingOpen: Equatable { let request: CreatorTicketOpenRequest }

    let service: CreatorStudioService
    var topics: [CreatorStudioTopic] = []
    var topicID: Int?
    var feedback: [CreatorFeedbackItem] = []
    var feedbackCursor: String?
    var tickets: [CreatorMaintenanceTicket] = []
    var ticketsCursor: String?
    var feedbackPhase: Phase = .idle
    var ticketsPhase: Phase = .idle
    var selected: Set<Int> = []
    var pendingOpen: PendingOpen?
    var writeIssue: CreatorStudioFailure?
    var writing = false

    init(service: CreatorStudioService) { self.service = service }

    func start(loadTopics: () async -> [CreatorStudioTopic]) async {
        var known = await loadTopics()
        await reloadTickets()
        for ticket in tickets where !known.contains(where: { $0.id == ticket.topicId }) {
            known.append(CreatorStudioTopic(id: ticket.topicId, title: ticket.topicName))
        }
        topics = known
        if topicID == nil || !known.contains(where: { $0.id == topicID }) { topicID = known.first?.id }
        await reloadFeedback()
    }

    /// Feedback is always read for one topic.
    func reloadFeedback() async {
        guard let topicID else { feedback = []; feedbackPhase = .loaded; return }
        feedbackPhase = .loading
        do {
            let page = try await service.feedback(topicID: topicID)
            guard topicID == self.topicID else { return }
            feedback = page.items; feedbackCursor = page.hasMore ? page.nextCursor : nil
            selected = selected.filter { id in page.items.contains { $0.feedbackId == id && $0.ticketId == nil } }
            feedbackPhase = .loaded
        } catch { feedbackPhase = .failed(error as? CreatorStudioFailure) }
    }

    func moreFeedback() async {
        guard let topicID, let cursor = feedbackCursor else { return }
        guard let page = try? await service.feedback(topicID: topicID, cursor: cursor), topicID == self.topicID else { return }
        feedback += page.items; feedbackCursor = page.hasMore ? page.nextCursor : nil
    }

    func reloadTickets() async {
        ticketsPhase = .loading
        do {
            let page = try await service.tickets()
            tickets = page.items; ticketsCursor = page.hasMore ? page.nextCursor : nil
            ticketsPhase = .loaded
        } catch { ticketsPhase = .failed(error as? CreatorStudioFailure) }
    }

    func moreTickets() async {
        guard let cursor = ticketsCursor, let page = try? await service.tickets(cursor: cursor) else { return }
        tickets += page.items; ticketsCursor = page.hasMore ? page.nextCursor : nil
    }

    func toggle(_ item: CreatorFeedbackItem) {
        guard item.ticketId == nil else { return }
        if selected.contains(item.feedbackId) { selected.remove(item.feedbackId) } else { selected.insert(item.feedbackId) }
    }

    /// Opens a ticket for the selected feedback of the current topic. Returns the ticket once the server confirms it.
    func open(title: String, note: String) async -> CreatorMaintenanceTicket? {
        let request: CreatorTicketOpenRequest
        if let pendingOpen { request = pendingOpen.request }
        else {
            guard let topicID, !selected.isEmpty else { return nil }
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            request = CreatorTicketOpenRequest(topicId: topicID, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                               note: trimmed.isEmpty ? nil : trimmed, feedbackIds: selected.sorted())
        }
        writing = true; writeIssue = nil
        defer { writing = false }
        if pendingOpen != nil, case .applied(let ticket)? = try? await service.openRequest(request.requestId) {
            return applied(ticket)
        }
        switch await service.openTicket(request) {
        case .applied(let ticket): return applied(ticket)
        case .rejected(let failure): pendingOpen = nil; writeIssue = failure; return nil
        case .unknown: pendingOpen = PendingOpen(request: request); return nil
        }
    }

    private func applied(_ ticket: CreatorMaintenanceTicket) -> CreatorMaintenanceTicket {
        pendingOpen = nil; selected = []
        replace(ticket)
        Task { await reloadFeedback() }
        return ticket
    }

    func replace(_ ticket: CreatorMaintenanceTicket) {
        if let index = tickets.firstIndex(where: { $0.ticketId == ticket.ticketId }) { tickets[index] = ticket }
        else { tickets.insert(ticket, at: 0) }
    }
}

@MainActor struct CreatorMaintenanceWorkbenchView: View {
    let loadTopics: () async -> [CreatorStudioTopic]
    @State private var model: CreatorMaintenanceModel
    @State private var tab: CreatorMaintenanceModel.Tab = .feedback
    @State private var composing = false
    @State private var openedID: Int?

    init(service: CreatorStudioService, loadTopics: @escaping () async -> [CreatorStudioTopic]) {
        self.loadTopics = loadTopics
        _model = State(initialValue: CreatorMaintenanceModel(service: service))
    }

    var body: some View {
        List {
            Section {
                Picker("creatorStudio.maintenance.tab", selection: $tab) {
                    Text("creatorStudio.maintenance.tab.feedback").tag(CreatorMaintenanceModel.Tab.feedback)
                    Text("creatorStudio.maintenance.tab.tickets").tag(CreatorMaintenanceModel.Tab.tickets)
                }.cyAdaptiveSegmented().accessibilityIdentifier("creatorStudio.maintenance.tab")
            } footer: { Text("creatorStudio.maintenance.flow") }
            if tab == .feedback { feedbackSections } else { ticketSections }
        }
        .appNavigationTitle("creatorStudio.maintenance.title").navigationBarTitleDisplayMode(.inline)
        .task { await model.start(loadTopics: loadTopics) }
        .refreshable { await model.reloadTickets(); await model.reloadFeedback() }
        .cySheet(isPresented: $composing) {
            Group {
                CreatorTicketComposeSheet(model: model) { ticket in composing = false; openedID = ticket.ticketId; tab = .tickets }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $openedID) { id in CreatorTicketDetailView(model: model, ticketID: id) }
        .cyDomainScreen(.topicEditor)
    }

    @ViewBuilder private var feedbackSections: some View {
        if model.topics.count > 1 {
            Section {
                Picker("creatorStudio.maintenance.topic", selection: Binding(get: { model.topicID }, set: { id in
                    model.topicID = id; model.selected = []
                    Task { await model.reloadFeedback() }
                })) {
                    ForEach(model.topics) { topic in Text(verbatim: topic.title ?? "#\(topic.id)").tag(Optional(topic.id)) }
                }.accessibilityIdentifier("creatorStudio.maintenance.topic")
            }
        }
        Section {
            switch model.feedbackPhase {
            case .idle, .loading: ProgressView().frame(maxWidth: .infinity)
            case .failed(let failure): CreatorStudioIssueView(failure: failure) { Task { await model.reloadFeedback() } }
            case .loaded:
                if model.topicID == nil { ContentUnavailableView("creatorStudio.issue.noTopics", systemImage: "square.stack.3d.up.slash") }
                else if model.feedback.isEmpty { ContentUnavailableView("creatorStudio.feedback.empty", systemImage: "checkmark.bubble") }
                ForEach(model.feedback) { item in
                    Button { model.toggle(item) } label: { CreatorFeedbackRow(item: item, selected: model.selected.contains(item.feedbackId)) }
                        .buttonStyle(.plain).disabled(item.ticketId != nil)
                        .accessibilityIdentifier("creatorStudio.feedback.\(item.feedbackId)")
                }
                if model.feedbackCursor != nil {
                    Button("creatorStudio.more") { Task { await model.moreFeedback() } }
                }
            }
        } header: { Text("creatorStudio.feedback.header") } footer: { Text("creatorStudio.feedback.privacy") }
        if !model.selected.isEmpty || model.pendingOpen != nil {
            Section {
                Button { composing = true } label: { Label("creatorStudio.ticket.open", systemImage: "plus.rectangle.on.rectangle") }
                    .accessibilityIdentifier("creatorStudio.ticket.open")
            }
        }
    }

    @ViewBuilder private var ticketSections: some View {
        Section {
            switch model.ticketsPhase {
            case .idle, .loading: ProgressView().frame(maxWidth: .infinity)
            case .failed(let failure): CreatorStudioIssueView(failure: failure) { Task { await model.reloadTickets() } }
            case .loaded:
                if model.tickets.isEmpty { ContentUnavailableView("creatorStudio.tickets.empty", systemImage: "wrench.and.screwdriver") }
                ForEach(model.tickets) { ticket in
                    NavigationLink { CreatorTicketDetailView(model: model, ticketID: ticket.ticketId) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent {
                                CreatorTicketStageChip(stage: ticket.knownStage)
                            } label: {
                                Text(verbatim: ticket.title).font(.headline).lineLimit(2)
                            }
                            if let name = ticket.topicName { Text(verbatim: name).font(.subheadline).foregroundStyle(.secondary) }
                            Text("creatorStudio.ticket.feedbackCount \(ticket.feedback.count)").font(.footnote).foregroundStyle(.tertiary)
                        }
                    }.accessibilityIdentifier("creatorStudio.ticket.\(ticket.ticketId)")
                }
                if model.ticketsCursor != nil {
                    Button("creatorStudio.more") { Task { await model.moreTickets() } }
                }
            }
        } header: { Text("creatorStudio.tickets.header") }
    }
}

struct CreatorFeedbackRow: View {
    let item: CreatorFeedbackItem
    var selected = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.ticketId != nil ? "link" : selected ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(CreatorFeedbackRow.category(item.category)).font(.footnote.weight(.semibold)).foregroundStyle(.tint)
                    if let version = item.configVersion { Text("creatorStudio.version \(version)").font(.footnote).foregroundStyle(.secondary) }
                    if let ticket = item.ticketId { Text("creatorStudio.feedback.inTicket \(ticket)").font(.footnote).foregroundStyle(.tertiary) }
                }
                if let content = item.content { Text(verbatim: content).font(.body).foregroundStyle(.primary) }
                if let node = item.nodeName { Label { Text(verbatim: node) } icon: { Image(systemName: "mappin") }.font(.footnote).foregroundStyle(.secondary) }
                if let date = item.createdAt { Text(verbatim: String(date.prefix(16)).replacingOccurrences(of: "T", with: " ")).font(.footnote).foregroundStyle(.tertiary) }
            }
        }.contentShape(Rectangle())
    }

    static func category(_ raw: String?) -> LocalizedStringKey {
        switch raw {
        case "PLACE": return "creatorStudio.category.place"
        case "QUESTION": return "creatorStudio.category.question"
        default: return "creatorStudio.category.other"
        }
    }
}

struct CreatorTicketStageChip: View {
    let stage: CreatorMaintenanceTicket.Stage?
    var body: some View {
        switch stage {
        case .reported?: Text("creatorStudio.stage.reported").font(.footnote).foregroundStyle(.orange)
        case .fixDrafted?: Text("creatorStudio.stage.fixDrafted").font(.footnote).foregroundStyle(.tint)
        case .fixPublished?: Text("creatorStudio.stage.fixPublished").font(.footnote).foregroundStyle(.tint)
        case .retested?: Text("creatorStudio.stage.retested").font(.footnote).foregroundStyle(.green)
        case .closed?: Text("creatorStudio.stage.closed").font(.footnote).foregroundStyle(.secondary)
        case nil: Text("creatorStudio.stage.unknown").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

@MainActor struct CreatorTicketComposeSheet: View {
    @Bindable var model: CreatorMaintenanceModel
    let onOpened: (CreatorMaintenanceTicket) -> Void
    @State private var title = ""
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let pending = model.pendingOpen {
                    Section {
                        Label("creatorStudio.write.unknown", systemImage: "questionmark.circle").foregroundStyle(.orange)
                        Text(verbatim: pending.request.title).font(.headline)
                    }
                } else {
                    Section("creatorStudio.ticket.titleField") {
                        TextField("creatorStudio.ticket.titlePlaceholder", text: $title)
                            .submitLabel(.next)
                            .accessibilityIdentifier("creatorStudio.ticket.title")
                    }
                    Section {
                        TextField("creatorStudio.ticket.notePlaceholder", text: $note, axis: .vertical).lineLimit(3...6)
                    } header: { Text("creatorStudio.ticket.noteField") } footer: { Text("creatorStudio.ticket.selected \(model.selected.count)") }
                }
                if let issue = model.writeIssue { Section { CreatorStudioWriteIssueText(failure: issue).foregroundStyle(.red) } }
                Section {} footer: { Text("creatorStudio.ticket.baselineNote") }
            }
            .navigationTitle("creatorStudio.ticket.open").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("creatorStudio.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { if let ticket = await model.open(title: title, note: note) { onOpened(ticket) } }
                    } label: {
                        Text(model.pendingOpen == nil ? "creatorStudio.ticket.confirmOpen" as LocalizedStringKey : "creatorStudio.write.recheck" as LocalizedStringKey)
                    }
                    .disabled(model.writing || (model.pendingOpen == nil && (title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 80 || note.count > 500)))
                    .accessibilityIdentifier("creatorStudio.ticket.confirmOpen")
                }
            }
        }
    }
}

struct CreatorStudioWriteIssueText: View {
    let failure: CreatorStudioFailure
    var body: some View {
        switch failure {
        case .rejected(_, let code, _) where code == "FIX_NOT_PUBLISHED": Text("creatorStudio.write.fixNotPublished")
        case .rejected(_, let code, _) where code == "TICKET_VERSION_CONFLICT": Text("creatorStudio.write.versionConflict")
        case .rejected(_, let code, _) where code == "TOPIC_NOT_PUBLISHED": Text("creatorStudio.write.topicNotPublished")
        case .rejected(_, let code, _) where code == "FEEDBACK_ALREADY_LINKED": Text("creatorStudio.write.alreadyLinked")
        case .rejected(_, let code, _) where code == "CLOSE_REASON_REQUIRED": Text("creatorStudio.write.reasonRequired")
        case .rejected(_, _, let message?): Text(verbatim: message)
        default: Text("creatorStudio.issue.failed")
        }
    }
}

@MainActor struct CreatorTicketDetailView: View {
    @Bindable var model: CreatorMaintenanceModel
    let ticketID: Int
    @State private var ticket: CreatorMaintenanceTicket?
    @State private var failure: CreatorStudioFailure?
    @State private var loading = true
    @State private var closing: CreatorTicketCloseChoice?

    var body: some View {
        List {
            if loading && ticket == nil { ProgressView().frame(maxWidth: .infinity) }
            else if let ticket { content(ticket) }
            else { CreatorStudioIssueView(failure: failure) { Task { await load() } } }
        }
        .appNavigationTitle("creatorStudio.ticket.detail").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .cySheet(item: $closing) { choice in
            Group {
                if let ticket {
                    CreatorTicketCloseSheet(service: model.service, ticket: ticket, resolution: choice.resolution) { updated in
                        closing = nil; self.ticket = updated; model.replace(updated)
                    }
                }
            }
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .cyDomainScreen(.topicEditor)
    }

    private func load() async {
        loading = true; defer { loading = false }
        do { let value = try await model.service.ticket(id: ticketID); ticket = value; failure = nil; model.replace(value) }
        catch { failure = error as? CreatorStudioFailure }
    }

    @ViewBuilder private func content(_ ticket: CreatorMaintenanceTicket) -> some View {
        Section {
            LabeledContent {
                CreatorTicketStageChip(stage: ticket.knownStage)
            } label: {
                Text(verbatim: ticket.title).font(.headline)
            }
            if let name = ticket.topicName { Text(verbatim: name).font(.subheadline).foregroundStyle(.secondary) }
            if let note = ticket.note { Text(verbatim: note) }
        }
        Section {
            stageRow("creatorStudio.flow.problem", done: true, detail: Text("creatorStudio.ticket.feedbackCount \(ticket.feedback.count)"))
            stageRow("creatorStudio.flow.original", done: true, detail: Text("creatorStudio.version \(ticket.baseline.configVersion)"))
            stageRow("creatorStudio.flow.draft", done: ticket.evidence.fixDrafted, detail: ticket.current.draftConfigVersion.map { Text("creatorStudio.version \($0)") })
            stageRow("creatorStudio.flow.newVersion", done: ticket.evidence.fixPublished, detail: ticket.current.publishedConfigVersion.map { Text("creatorStudio.version \($0)") })
            stageRow("creatorStudio.flow.retest", done: ticket.evidence.retestedByAuthor, detail: nil)
            stageRow("creatorStudio.flow.close", done: ticket.isClosed, detail: ticket.resolution.map { Text($0 == "FIXED" ? "creatorStudio.resolution.fixed" : "creatorStudio.resolution.noChange") })
        } header: { Text("creatorStudio.flow.header") } footer: { Text("creatorStudio.flow.footer") }
        if let reason = ticket.closeReason {
            Section("creatorStudio.close.reason") { Text(verbatim: reason) }
        }
        Section("creatorStudio.feedback.header") {
            ForEach(ticket.feedback) { CreatorFeedbackRow(item: $0) }
        }
        if !ticket.isClosed {
            Section {
                Button { closing = .init(resolution: .fixed) } label: { Label("creatorStudio.close.fixed", systemImage: "checkmark.seal") }
                    .disabled(!ticket.canCloseFixed).accessibilityIdentifier("creatorStudio.close.fixed")
                Button("creatorStudio.close.noChange") { closing = .init(resolution: .noChange) }
                    .accessibilityIdentifier("creatorStudio.close.noChange")
            } footer: {
                if !ticket.canCloseFixed { Text("creatorStudio.close.fixedNeedsVersion") }
            }
        }
    }

    private func stageRow(_ title: LocalizedStringKey, done: Bool, detail: Text?) -> some View {
        LabeledContent {
            if let detail { detail.monospacedDigit() }
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(done ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
            }
        }.accessibilityElement(children: .combine)
    }
}

/// Sheet item for the chosen close resolution.
struct CreatorTicketCloseChoice: Identifiable {
    let resolution: CreatorTicketCloseRequest.Resolution
    var id: String { resolution.rawValue }
}

@MainActor struct CreatorTicketCloseSheet: View {
    let service: CreatorStudioService
    let ticket: CreatorMaintenanceTicket
    let resolution: CreatorTicketCloseRequest.Resolution
    let onClosed: (CreatorMaintenanceTicket) -> Void
    @State private var reason = ""
    /// Kept across retries so an unknown result re-sends the same request (the server replays it).
    @State private var pending: CreatorTicketCloseRequest?
    @State private var unknown = false
    @State private var issue: CreatorStudioFailure?
    @State private var sending = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(resolution == .fixed ? "creatorStudio.close.fixedBody" : "creatorStudio.close.noChangeBody")
                    if resolution == .fixed, let version = ticket.current.publishedConfigVersion {
                        LabeledContent("creatorStudio.flow.newVersion") { Text("creatorStudio.version \(version)").monospacedDigit() }
                    }
                }
                Section("creatorStudio.close.reason") {
                    TextField(resolution == .fixed ? "creatorStudio.close.reasonOptional" : "creatorStudio.close.reasonRequired", text: $reason, axis: .vertical)
                        .lineLimit(2...5).disabled(pending != nil).accessibilityIdentifier("creatorStudio.close.reasonField")
                }
                if unknown { Section { Label("creatorStudio.write.unknown", systemImage: "questionmark.circle").foregroundStyle(.orange) } }
                if let issue { Section { CreatorStudioWriteIssueText(failure: issue).foregroundStyle(.red) } }
            }
            .navigationTitle(resolution == .fixed ? "creatorStudio.close.fixed" : "creatorStudio.close.noChange").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("creatorStudio.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await send() } } label: {
                        Text(unknown ? "creatorStudio.write.recheck" as LocalizedStringKey : "creatorStudio.close.confirm" as LocalizedStringKey)
                    }
                    .disabled(sending || !draft.isComplete || reason.count > 500)
                    .accessibilityIdentifier("creatorStudio.close.confirm")
                }
            }
        }
    }

    private var draft: CreatorTicketCloseRequest {
        pending ?? CreatorTicketCloseRequest(expectedVersion: ticket.version, resolution: resolution,
                                             reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func send() async {
        let request = draft
        pending = request; sending = true; issue = nil
        defer { sending = false }
        switch await service.closeTicket(id: ticket.ticketId, request) {
        case .applied(let updated): pending = nil; unknown = false; onClosed(updated)
        case .rejected(let failure): pending = nil; unknown = false; issue = failure
        case .unknown: unknown = true
        }
    }
}
