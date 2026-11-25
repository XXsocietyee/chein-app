import SwiftUI

extension AppSession {
    /// Projection, entries and live check-in codes reuse the existing merchant-content service. MC8-26-1 (MP-first,
    /// owner 2026-11-25): invite / ready / pause / resume / verify go to `api/game/session/command` and
    /// `api/game/session/receipt` as the MP sends them (utils/game-session-client.js:395,516).
    var merchantGameNodeService: any MerchantGameNodeServing {
        let reads = MerchantGameNodeContentReader(service: merchantContentService)
        guard let api = regionalConfiguration?.apiConfiguration, let market = regionalConfiguration?.market else { return reads }
        let writes = MerchantGameNodeHTTPService(configuration: api, transport: runtimeHTTPTransport,
            currentSession: { [weak self] in self?.currentMerchantGameNodeSession }, journal: MPFirstMerchantGameNodeService.journal,
            gates: .mpFirst, market: market)
        return MPFirstMerchantGameNodeService(reads: reads, writes: writes)
    }
    var currentMerchantGameNodeSession: MerchantGameNodeSession? {
        guard let account, let token, let namespace = storageScope?.service else { return nil }
        return try? MerchantGameNodeSession(accountID: account.id, epoch: gate.currentStamp, storageScope: namespace, token: token)
    }
}

/// Reads from the merchant-content reader, writes from the MP-first command service.
@MainActor final class MPFirstMerchantGameNodeService: MerchantGameNodeServing {
    private let reads: MerchantGameNodeContentReader
    private let writes: MerchantGameNodeHTTPService
    /// Process-lifetime pending index for game-node commands (same request id on retry within the run).
    static let journal = MerchantGameNodeMemoryJournal()
    init(reads: MerchantGameNodeContentReader, writes: MerchantGameNodeHTTPService) { self.reads = reads; self.writes = writes }
    var scope: UUID { reads.scope }
    var isAuthenticated: Bool { reads.isAuthenticated }
    var permitsWrites: Bool { writes.permitsWrites }
    func loadProjection(activityID: Int) async -> MerchantGameNodeLoadResult { await reads.loadProjection(activityID: activityID) }
    func loadEntries() async -> MerchantGameNodeEntriesResult { await reads.loadEntries() }
    func issueLiveCode(activityID: Int, nodeID: Int) async -> MerchantGameNodeLiveCodeResult { await reads.issueLiveCode(activityID: activityID, nodeID: nodeID) }
    func submit(_ command: MerchantGameNodeCommand) async -> MerchantGameNodeWriteResult { await writes.submit(command) }
    func readReceipt(activityID: Int, requestID: String) async throws -> MerchantGameNodeReceiptResult { try await writes.readReceipt(activityID: activityID, requestID: requestID) }
    func persistPending(_ index: MerchantGameNodePendingIndex) -> Bool { writes.persistPending(index) }
    func restorePending(activityID: Int) -> MerchantGameNodePendingIndex? { writes.restorePending(activityID: activityID) }
    func clearPending(activityID: Int) { writes.clearPending(activityID: activityID) }
}

/// Session-scoped host; a sign-out or account change replaces the page and its coordinator.
@MainActor struct SessionMerchantGameNodeView: View {
    @ObservedObject var session: AppSession
    let activityID: Int
    var nodeID: Int? = nil
    var focusPause = false
    var body: some View {
        MerchantGameNodeView(service: session.merchantGameNodeService, activityID: activityID, nodeID: nodeID, focusPause: focusPause)
            .id("\(session.sessionRevision)-\(session.merchantContentService.scope)")
    }
}
