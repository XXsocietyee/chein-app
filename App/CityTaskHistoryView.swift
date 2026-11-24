import SwiftUI

struct CityTaskHistoryEntry: View {
    let factory: (@MainActor () -> CityTaskHistoryController)?
    var body: some View {
        NavigationLink {
            CityTaskHistoryView(controller: factory?() ?? .init(service: nil))
        } label: { Label { Text("cityHistory.entry", tableName: "CityTaskHistory") } icon: { Image(systemName: "clock.arrow.circlepath") } }
        .accessibilityIdentifier("city.history.entry")
    }
}
@MainActor struct CityTaskHistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller: CityTaskHistoryController
    @State private var visible = false
    @State private var readID = UUID()
    private let table = "CityTaskHistory"
    init(controller: CityTaskHistoryController) { _controller = State(initialValue: controller) }
    private var interactive: Bool { visible && scenePhase == .active && controller.current }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                CYHeroHeader("cityHistory.title", tableName: table)
                Text("cityHistory.boundary", tableName: table).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                Text(LocalizedStringKey(controller.messageKey), tableName: table).cyText(.body).foregroundStyle(CYColor.textSecondary)
                if controller.busy { CYSkeleton() }
                CYPillButton("cityHistory.refresh", style: .secondary, tableName: table) { read(.refresh) }.disabled(controller.busy || !controller.current)
                if interactive, let detail = controller.detail {
                    detailContent(detail)
                } else if interactive {
                    ForEach(controller.items) { item in
                        Button { read(.select(item)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    if let title = item.title { Text(verbatim: title).cyText(.cardTitle) } else { Text("cityHistory.titleUnavailable", tableName: table).cyText(.cardTitle) }
                                    Spacer(minLength: 8)
                                    CYStatusChip(status(item.status), tone: item.status == "PASSED" ? .success : item.status == "EXHAUSTED" ? .danger : .info)
                                }
                                Text(verbatim: item.boardId + " · " + item.seasonId).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                                Text(verbatim: item.acceptedAt).cyText(.meta).foregroundStyle(CYColor.textTertiary).monospacedDigit()
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                        }.buttonStyle(.plain).disabled(controller.busy || !controller.current).accessibilityIdentifier("city.history.item.\(item.id)")
                    }
                    if controller.nextBeforeID != nil {
                        Button { read(.more) } label: { Text("cityHistory.more", tableName: table) }.disabled(controller.busy || !controller.current)
                    }
                }
            }.padding()
        }
        .accessibilityIdentifier("city.history.screen")
        .task(id: readID) { guard visible, scenePhase == .active, !Task.isCancelled else { return }; await controller.load() }
        .onAppear { visible = true; readID = UUID() }
        .onChange(of: scenePhase) { _, _ in controller.invalidate(); readID = UUID() }
        .onChange(of: controller.current) { _, current in if !current { controller.invalidate() } }
        .onDisappear { visible = false; readID = UUID(); controller.invalidate() }
    }
    @ViewBuilder private func detailContent(_ detail: CityTaskHistoryDetail) -> some View {
        Button { read(.returnToList) } label: { Text("cityHistory.back", tableName: table) }.disabled(controller.busy)
        if let title = detail.instance.title { Text(verbatim: title).cyText(.sectionTitle) }
        Text(status(detail.instance.status), tableName: table).cyText(.cardTitle)
        Text("cityHistory.historicalOnly", tableName: table).cyText(.bodyCompact)
        field("cityHistory.instance", detail.instance.id)
        field("cityHistory.board", detail.instance.boardId + " / " + detail.instance.seasonId + " / " + detail.instance.roundId)
        field("cityHistory.task", detail.instance.taskId + " / " + detail.instance.pointId)
        field("cityHistory.release", String(detail.instance.releaseId) + " / " + detail.instance.rulesReleaseId)
        field("cityHistory.hash", detail.instance.contentHash)
        field("cityHistory.evidence", detail.instance.evidenceId)
        field("cityHistory.acceptedAt", detail.instance.acceptedAt)
        field("cityHistory.attempts", "\(detail.instance.attempts) / \(detail.instance.maxAttempts)")
        Button { read(.receipt(detail.instance.acceptRequestId)) } label: { Text("cityHistory.acceptReceipt", tableName: table) }.disabled(controller.busy || !controller.current)
        Text("cityHistory.timeline", tableName: table).cyText(.cardTitle)
        if detail.attempts.isEmpty { Text("cityHistory.noAttempts", tableName: table) }
        ForEach(detail.attempts) { attempt in
            VStack(alignment: .leading, spacing: 4) {
                field("cityHistory.attempt", String(attempt.attemptNumber))
                field("cityHistory.answer", attempt.optionId)
                Text(LocalizedStringKey(attempt.passed ? "cityHistory.passedAnswer" : "cityHistory.failedAnswer"), tableName: table)
                field("cityHistory.recordedAt", attempt.createdAt)
                field("cityHistory.evidenceCheckedAt", attempt.evidenceCheckedAt)
                Button { read(.receipt(attempt.requestId)) } label: { Text("cityHistory.answerReceipt", tableName: table) }.disabled(controller.busy || !controller.current)
            }.cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
        }
        if let result = detail.result {
            Text("cityHistory.originalResult", tableName: table).cyText(.cardTitle)
            field("cityHistory.resultID", result.resultId)
            Text(status(result.outcome), tableName: table)
            field("cityHistory.recordedAt", result.createdAt)
            field("cityHistory.evidenceExpiresAt", result.evidenceExpiresAt)
            field("cityHistory.resultRequest", result.requestId)
            Text("cityHistory.noEffects", tableName: table)
        }
        if let receipt = controller.receipt {
            Text("cityHistory.receipt", tableName: table).cyText(.cardTitle)
            field("cityHistory.resultRequest", receipt.requestID)
            Text(LocalizedStringKey(receipt.status == "UNKNOWN" ? "cityHistory.receiptUnknown" : "cityHistory.receiptComplete"), tableName: table)
            field("cityHistory.httpStatus", String(receipt.httpStatus))
            if let code = receipt.errorCode { field("cityHistory.errorCode", code) }
            if let result = receipt.result { field("cityHistory.resultID", result.resultId) }
        }
    }
    private func read(_ action: CityTaskHistoryController.ReadAction) {
        guard visible, scenePhase == .active, let review = controller.captureRead(action) else { return }
        let visit = readID
        Task {
            guard visible, scenePhase == .active, readID == visit, !Task.isCancelled else { return }
            await controller.perform(review)
        }
    }
    private func field(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(LocalizedStringKey(key), tableName: table).cyText(.meta).foregroundStyle(.secondary); Text(verbatim: value).textSelection(.enabled) }
    }
    private func status(_ value: String) -> LocalizedStringKey {
        switch value { case "PASSED": "cityHistory.task.passed"; case "EXHAUSTED": "cityHistory.task.exhausted"; default: "cityHistory.task.active" }
    }
}
