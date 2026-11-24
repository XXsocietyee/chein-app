import SwiftUI

@MainActor struct CityNeutralTaskEntry: View {
    let board: CityReadBoard
    let factory: (@MainActor (CityReadBoard) -> CityNeutralTaskController)?
    var body: some View {
        if let factory {
            NavigationLink { CityNeutralTaskView(controller: factory(board)) } label: {
                Label { Text("cityNeutral.entry", tableName: "CityNeutralTask") } icon: { Image(systemName: "questionmark.circle") }
            }
        } else { Text("cityNeutral.status.disabled", tableName: "CityNeutralTask") }
    }
}
@MainActor struct CityNeutralTaskView: View {
    @State var controller: CityNeutralTaskController
    @State private var selections: [String:String] = [:]
    @State private var originalResult: CityNeutralTaskResultRecoveryController?
    @Environment(\.scenePhase) private var scenePhase
    private let table = "CityNeutralTask"
    var body: some View {
        let live = controller.current && scenePhase == .active
        CityNeutralTaskContent(
            snapshot: live ? controller.snapshot : nil, messageKey: controller.messageKey, busy: controller.busy,
            pendingRequestID: live ? controller.pendingRequestID : nil, receipt: live ? controller.receipt : nil,
            allows: { controller.allows($0) }, selections: $selections,
            reload: { selections = [:]; Task { await controller.load() } },
            accept: { controller.prepare($0) }, submit: { controller.prepare($0, optionID: selections[$0.id]) },
            selectionChanged: { controller.cancelConfirmation() },
            recover: { Task { await controller.recover() } }, canRecover: !controller.busy && controller.current,
            openResult: { originalResult = controller.makeResultRecoveryController() })
        .navigationTitle(Text("cityNeutral.title", tableName: table)).navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("cityNeutral.screen")
        .task { await controller.load() }
        .onChange(of: controller.current) { _, current in if !current { controller.invalidate(); selections = [:]; originalResult = nil } }
        .onChange(of: controller.snapshot) { _, _ in selections = [:] }
        .onChange(of: scenePhase) { _, phase in controller.invalidate(); selections = [:]; if phase == .active { Task { await controller.load() } } }
        .onDisappear {
            if originalResult != nil { controller.suspendForResult() } else { controller.invalidate() }
            selections = [:]
        }
        // Keep the destination independent of receipt rows cleared by parent disappearance.
        .navigationDestination(isPresented: Binding(get: { originalResult != nil }, set: { if !$0 { originalResult = nil } })) {
            if let originalResult { CityNeutralTaskResultRecoveryView(controller: originalResult) }
        }
        .sheet(item: Binding(get: { controller.current && scenePhase == .active ? controller.confirmation : nil }, set: { if $0 == nil { controller.cancelConfirmation() } })) { captured in Group {
            NavigationStack {
                Form {
                    Text(LocalizedStringKey(captured.command.kind == .accept ? "cityNeutral.accept" : "cityNeutral.submit"), tableName: table)
                    Text(verbatim: captured.task.definition.title)
                    row("cityNeutral.release", captured.binding.rulesReleaseId)
                    row("cityNeutral.round", captured.binding.rules.roundId)
                    row("cityNeutral.attempts", "\(captured.task.attempts) / \(captured.task.definition.maxAttempts)")
                    if let option = captured.task.definition.options.first(where: { $0.id == captured.command.optionId }) { row("cityNeutral.answer", option.label) }
                    Text("cityNeutral.confirmHint", tableName: table)
                    Button { Task { await controller.confirm(captured) } } label: { Text("cityNeutral.confirmNow", tableName: table) }.disabled(!controller.canWrite)
                    Button { controller.cancelConfirmation() } label: { Text("cityNeutral.cancel", tableName: table) }
                }.cyGroupedSurface().navigationTitle(Text("cityNeutral.confirmTitle", tableName: table)).navigationBarTitleDisplayMode(.inline)
            }
            .cyPlayerSheetGlass()
        }.cySheet(detents: [.large]) }
        .cyDomainScreen(.game)
        .cyHideTabBar(true)
    }
    private func row(_ key: String, _ value: String) -> some View { LabeledContent { Text(verbatim: value).textSelection(.enabled) } label: { Text(LocalizedStringKey(key), tableName: table) } }
}

struct CityNeutralTaskContent: View {
    let snapshot: CityNeutralTaskSnapshot?
    let messageKey: String
    let busy: Bool
    let pendingRequestID: UUID?
    let receipt: CityNeutralTaskReceipt?
    let allows: (CityNeutralTask) -> Bool
    @Binding var selections: [String: String]
    let reload: () -> Void
    let accept: (CityNeutralTask) -> Void
    let submit: (CityNeutralTask) -> Void
    let selectionChanged: () -> Void
    let recover: () -> Void
    let canRecover: Bool
    let openResult: () -> Void
    private let table = "CityNeutralTask"
    @Environment(\.locale) private var locale
    var body: some View {
        CYCardPage {
            CYArtCoverHeader(title: Text("cityNeutral.title", tableName: table), subtitle: Text("cityNeutral.boundary", tableName: table),
                             symbol: "checklist", seed: "neutral") { EmptyView() }
        } content: {
            CYNoteBanner(text: Text(LocalizedStringKey(messageKey), tableName: table), symbol: busy ? "hourglass" : "info.circle")
                .accessibilityIdentifier("cityNeutral.status")
            if let value = snapshot {
                if value.status == "JOIN_REQUIRED" { CYNoteBanner(text: Text("cityNeutral.joinRequired", tableName: table), symbol: "person.badge.plus") }
                if value.status == "TEAM_NOT_READY" { CYNoteBanner(text: Text("cityNeutral.teamNotReady", tableName: table), symbol: "person.2.slash") }
                if value.tasks.isEmpty && value.status != "JOIN_REQUIRED" {
                    CYEmptyState(systemImage: "checklist", "cityNeutral.noTasks", tableName: table)
                }
                ForEach(value.tasks) { task in
                    CityTaskCard(
                        title: task.definition.title, question: task.definition.question, status: task.status,
                        statusText: Text(LocalizedStringKey("cityNeutral.taskStatus." + task.status), tableName: table),
                        attempts: task.attempts, maxAttempts: task.definition.maxAttempts,
                        options: task.definition.options.map { .init(id: $0.id, label: $0.label) },
                        selection: Binding(get: { selections[task.id] ?? "" }, set: { selections[task.id] = $0; selectionChanged() }),
                        table: table, enabled: allows(task), note: task.status == "ACTIVE" ? Text("cityNeutral.sharedAttempts", tableName: table) : nil,
                        resultNote: task.result == nil ? nil : Text("cityNeutral.resultBoundary", tableName: table),
                        details: task.result.map { [(Text("cityNeutral.result", tableName: table), $0.resultId), (Text("cityNeutral.request", tableName: table), $0.requestId),
                                                    (Text("cityNeutral.completedAt", tableName: table), $0.createdAt)] } ?? [],
                        accept: { accept(task) }, submit: { submit(task) })
                }
                if let binding = value.binding {
                    CYInfoCard {
                        CYDetailsDisclosure(title: Text("cityNeutral.frozen", tableName: table)) {
                            CYFactRow(label: Text("cityNeutral.release", tableName: table), value: binding.rulesReleaseId)
                            CYFactRow(label: Text("cityNeutral.round", tableName: table), value: binding.rules.roundId)
                            if let team = value.teamId { CYFactRow(label: Text("cityNeutral.team", tableName: table), value: team) }
                            if let session = value.sessionId { CYFactRow(label: Text("cityNeutral.session", tableName: table), value: session) }
                        }
                    }
                }
            }
            if let id = pendingRequestID {
                CYInfoCard(title: Text("cityNeutral.pendingHint", tableName: table), symbol: "clock.badge.questionmark") {
                    CYFactRow(label: Text("cityNeutral.request", tableName: table), value: id.uuidString)
                    CYPillButton(LocalizedStringKey("cityNeutral.recover"), tableName: table, action: recover).disabled(!canRecover)
                }
            }
            if let receipt {
                CYInfoCard(title: Text(LocalizedStringKey(receipt.succeeded ? "cityNeutral.receiptRecorded" : "cityNeutral.receiptRejected"), tableName: table),
                           symbol: receipt.succeeded ? "checkmark.seal.fill" : "xmark.octagon.fill") {
                    CYFactRow(label: Text("cityNeutral.request", tableName: table), value: receipt.requestId)
                    if receipt.task != nil {
                        CYPillButton(LocalizedStringKey("cityNeutralResult.open"), style: .secondary, tableName: "CityNeutralTaskResultRecovery", action: openResult)
                            .accessibilityIdentifier("cityNeutral.result.open")
                    }
                }
            }
            if snapshot != nil {
                CYPillButton(LocalizedStringKey("cityNeutral.reload"), style: .tertiary, systemImage: "arrow.clockwise", tableName: table, action: reload).disabled(busy)
            }
        }
    }
}
