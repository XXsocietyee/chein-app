import SwiftUI

@MainActor struct CityOnsiteTaskEntry: View {
    let board: CityReadBoard
    let factory: (@MainActor (CityReadBoard) -> CityOnsiteTaskController)?
    let arrivalFactory: (@MainActor (CityReadBoard) -> CityArrivalEvidenceController)?
    var body: some View {
        if let factory {
            NavigationLink { CityOnsiteTaskView(controller: factory(board), board: board, arrivalFactory: arrivalFactory) } label: {
                Label { Text("cityOnsite.entry", tableName: "CityOnsiteTask") } icon: { Image(systemName: "questionmark.circle") }
            }
        } else { Text("cityOnsite.status.disabled", tableName: "CityOnsiteTask") }
    }
}
@MainActor struct CityOnsiteTaskView: View {
    @State var controller: CityOnsiteTaskController
    let board: CityReadBoard
    let arrivalFactory: (@MainActor (CityReadBoard) -> CityArrivalEvidenceController)?
    @State private var selections: [String:String] = [:]
    @State private var visible = false
    @State private var readRequest = UUID()
    @Environment(\.scenePhase) private var scenePhase
    private let table = "CityOnsiteTask"
    private var interactive: Bool { visible && scenePhase == .active && controller.current }
    var body: some View {
        CityOnsiteTaskContent(
            snapshot: interactive ? controller.snapshot : nil, messageKey: controller.messageKey, busy: controller.busy, interactive: interactive,
            selectedResult: interactive ? controller.selectedResult : nil, originalRequestID: interactive ? controller.originalRequestID : nil,
            pendingRequestID: controller.pendingRequestID, receipt: interactive ? controller.receipt : nil,
            allows: { controller.allows($0) }, selections: $selections,
            reload: { guard interactive else { return }; selections = [:]; readRequest = UUID() },
            accept: { guard interactive else { return }; controller.prepare($0) },
            submit: { guard interactive else { return }; controller.prepare($0, optionID: selections[$0.id]) },
            selectionChanged: { controller.cancelConfirmation() },
            readResult: { readResult($0) }, closeResult: { controller.closeResult() }, recover: { recoverOriginal() }) {
                CityArrivalEvidenceEntry(board: board, factory: arrivalFactory)
            }
        .navigationTitle(Text("cityOnsite.title", tableName: table)).navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("cityOnsite.screen")
        .task(id: readRequest) {
            guard visible, scenePhase == .active, !Task.isCancelled else { return }
            await controller.load(activity: controller.activityID)
        }
        .onAppear { visible = true; controller.activate(); readRequest = UUID() }
        .onChange(of: controller.snapshot) { _, _ in selections = [:] }
        .onChange(of: scenePhase) { _, phase in
            controller.suspend(); selections = [:]
            if visible, phase == .active { controller.activate(); readRequest = UUID() }
        }
        .onChange(of: controller.current) { _, current in if !current { controller.invalidate(); selections = [:] } }
        .onDisappear { visible = false; controller.suspend(); selections = [:] }
        .sheet(item: Binding(get: { interactive ? controller.confirmation : nil }, set: { if $0 == nil { controller.cancelConfirmation() } })) { captured in Group {
            NavigationStack {
                Form {
                    Text(LocalizedStringKey(captured.command.kind == .accept ? "cityOnsite.accept" : "cityOnsite.submit"), tableName: table)
                    Text(verbatim: captured.task.definition.title)
                    row("cityOnsite.release", captured.binding.rulesReleaseId)
                    row("cityOnsite.round", captured.binding.rules.roundId)
                    row("cityOnsite.attempts", "\(captured.task.attempts) / \(captured.task.definition.maxAttempts)")
                    if let option = captured.task.definition.options.first(where: { $0.id == captured.command.optionId }) { row("cityOnsite.answer", option.label) }
                    row("cityOnsite.evidence", captured.command.evidenceId)
                    if let evidence = captured.task.evidence { row("cityOnsite.evidenceExpires", evidence.expiresAt) }
                    row("cityOnsite.acceptanceReason", captured.task.definition.acceptanceReason)
                    Text("cityOnsite.confirmHint", tableName: table)
                    Button { guard interactive else { return }; Task { await controller.confirm(captured) } } label: { Text("cityOnsite.confirmNow", tableName: table) }.disabled(!interactive || !controller.canWrite)
                    Button { controller.cancelConfirmation() } label: { Text("cityOnsite.cancel", tableName: table) }
                }.cyGroupedSurface().navigationTitle(Text("cityOnsite.confirmTitle", tableName: table)).navigationBarTitleDisplayMode(.inline)
            }
            .cyPlayerSheetGlass()
        }.cySheet(detents: [.large]) }
        .cyDomainScreen(.game)
        .cyHideTabBar(true)
    }
    private func recoverOriginal() {
        guard interactive else { return }; let activity = controller.activityID
        Task { await controller.recover(activity: activity) }
    }
    private func readResult(_ id: String) {
        guard interactive else { return }; let activity = controller.activityID
        Task { await controller.readResult(id, activity: activity) }
    }
    private func row(_ key: String, _ value: String) -> some View { LabeledContent { Text(verbatim: value).textSelection(.enabled) } label: { Text(LocalizedStringKey(key), tableName: table) } }
}

struct CityOnsiteTaskContent<Entry: View>: View {
    let snapshot: CityOnsiteTaskSnapshot?
    let messageKey: String
    let busy: Bool
    let interactive: Bool
    let selectedResult: CityOnsiteTaskResult?
    let originalRequestID: UUID?
    let pendingRequestID: UUID?
    let receipt: CityOnsiteTaskReceipt?
    let allows: (CityOnsiteTask) -> Bool
    @Binding var selections: [String: String]
    let reload: () -> Void
    let accept: (CityOnsiteTask) -> Void
    let submit: (CityOnsiteTask) -> Void
    let selectionChanged: () -> Void
    let readResult: (String) -> Void
    let closeResult: () -> Void
    let recover: () -> Void
    @ViewBuilder let arrivalEntry: () -> Entry
    private let table = "CityOnsiteTask"
    var body: some View {
        CYCardPage {
            CYArtCoverHeader(title: Text("cityOnsite.title", tableName: table), subtitle: Text("cityOnsite.boundary", tableName: table),
                             symbol: "figure.walk.motion", seed: "onsite") { EmptyView() }
        } content: {
            CYNoteBanner(text: Text(LocalizedStringKey(messageKey), tableName: table), symbol: busy ? "hourglass" : "info.circle")
                .accessibilityIdentifier("cityOnsite.status")
            CYInfoCard(symbol: "checkmark.shield.fill") {
                Text("cityOnsite.evidenceEntryHint", tableName: table).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                arrivalEntry().cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).frame(minHeight: 44)
            }
            if let value = snapshot {
                if value.status == "JOIN_REQUIRED" { CYNoteBanner(text: Text("cityOnsite.joinRequired", tableName: table), symbol: "person.badge.plus") }
                if value.status == "TEAM_NOT_READY" { CYNoteBanner(text: Text("cityOnsite.teamNotReady", tableName: table), symbol: "person.2.slash") }
                if value.tasks.isEmpty && value.status != "JOIN_REQUIRED" { CYEmptyState(systemImage: "figure.walk", "cityOnsite.noTasks", tableName: table) }
                ForEach(value.tasks) { task in
                    VStack(spacing: CYSpacing.sm) {
                        CityTaskCard(
                            title: task.definition.title, question: task.definition.question, status: task.status,
                            statusText: Text(LocalizedStringKey("cityOnsite.taskStatus." + task.status), tableName: table),
                            attempts: task.attempts, maxAttempts: task.definition.maxAttempts,
                            options: task.definition.options.map { .init(id: $0.id, label: $0.label) },
                            selection: Binding(get: { selections[task.id] ?? "" }, set: { selections[task.id] = $0; selectionChanged() }),
                            table: table, enabled: allows(task),
                            note: Text(LocalizedStringKey(task.canAct ? "cityOnsite.eligible" : "cityOnsite.ineligible"), tableName: table),
                            resultNote: task.result == nil ? nil : Text("cityOnsite.resultBoundary", tableName: table),
                            details: details(task), accept: { accept(task) }, submit: { submit(task) })
                        if let result = task.result {
                            CYPillButton(LocalizedStringKey("cityOnsite.readResult"), style: .secondary, tableName: table) { readResult(result.resultId) }
                                .disabled(busy || !interactive)
                        }
                    }
                }
                if let binding = value.binding {
                    CYInfoCard {
                        CYDetailsDisclosure(title: Text("cityOnsite.frozen", tableName: table)) {
                            CYFactRow(label: Text("cityOnsite.release", tableName: table), value: binding.rulesReleaseId)
                            CYFactRow(label: Text("cityOnsite.round", tableName: table), value: binding.rules.roundId)
                            if let team = value.teamId { CYFactRow(label: Text("cityOnsite.team", tableName: table), value: team) }
                            if let session = value.sessionId { CYFactRow(label: Text("cityOnsite.session", tableName: table), value: session) }
                        }
                    }
                }
            }
            if let result = selectedResult {
                CYInfoCard(title: Text("cityOnsite.originalResult", tableName: table), symbol: "doc.text.magnifyingglass") {
                    CYStatusChip(LocalizedStringKey("cityOnsite.taskStatus." + result.outcome), tone: result.outcome == "COMPLETED" ? .success : .neutral)
                    Text("cityOnsite.historicalResultBoundary", tableName: table).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    CYDetailsDisclosure(title: Text("cityOnsite.result", tableName: table)) {
                        CYFactRow(label: Text("cityOnsite.result", tableName: table), value: result.resultId)
                        CYFactRow(label: Text("cityOnsite.request", tableName: table), value: result.requestId)
                        CYFactRow(label: Text("cityOnsite.point", tableName: table), value: result.pointId)
                        CYFactRow(label: Text("cityOnsite.evidence", tableName: table), value: result.evidenceId)
                        CYFactRow(label: Text("cityOnsite.completedAt", tableName: table), value: result.createdAt)
                    }
                    CYPillButton(LocalizedStringKey("cityOnsite.closeResult"), style: .secondary, tableName: table, action: closeResult).disabled(busy)
                }
            }
            if let id = originalRequestID {
                CYInfoCard(title: Text(LocalizedStringKey(pendingRequestID == nil ? "cityOnsite.originalRequestHint" : "cityOnsite.pendingHint"), tableName: table), symbol: "clock.badge.questionmark") {
                    CYFactRow(label: Text("cityOnsite.request", tableName: table), value: id.uuidString)
                    CYPillButton(LocalizedStringKey("cityOnsite.recover"), tableName: table, action: recover).disabled(busy || !interactive)
                }
            }
            if let receipt {
                CYInfoCard(title: Text(LocalizedStringKey(receipt.succeeded ? "cityOnsite.receiptRecorded" : "cityOnsite.receiptRejected"), tableName: table),
                           symbol: receipt.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill") {
                    CYFactRow(label: Text("cityOnsite.request", tableName: table), value: receipt.requestId)
                    if let code = receipt.errorCode { CYFactRow(label: Text("cityOnsite.rejectionCode", tableName: table), value: code) }
                    if let result = receipt.result {
                        CYPillButton(LocalizedStringKey("cityOnsite.readResult"), style: .secondary, tableName: table) { readResult(result.resultId) }.disabled(busy || !interactive)
                    }
                }
            }
            if snapshot != nil {
                CYPillButton(LocalizedStringKey("cityOnsite.reload"), style: .tertiary, systemImage: "arrow.clockwise", tableName: table, action: reload).disabled(busy || !interactive)
            }
        }
    }
    private func details(_ task: CityOnsiteTask) -> [(Text, String)] {
        var rows: [(Text, String)] = [(Text("cityOnsite.point", tableName: table), task.definition.pointId),
                                      (Text("cityOnsite.acceptanceReason", tableName: table), task.definition.acceptanceReason)]
        if let e = task.evidence { rows += [(Text("cityOnsite.evidence", tableName: table), e.evidenceId), (Text("cityOnsite.evidenceExpires", tableName: table), e.expiresAt)] }
        if let r = task.result { rows += [(Text("cityOnsite.result", tableName: table), r.resultId), (Text("cityOnsite.completedAt", tableName: table), r.createdAt)] }
        return rows
    }
}
