import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// fix-r9 member PLY-25-2: the MP sends sync / settle / receipt from 本局计分, so the app does too.
// MP `subpackageMember/orient-score/index.wxml:25-44` (pending card + 结算结果 buttons),
// `index.js:146-187` (recover), `:220-262` (resumeSync), `:268-337` (confirmWrite / write).
// Score settle moves points and explore XP only; it is not money.

/// One writer per account, session epoch and round, so a pending id survives a page reload.
@MainActor enum OrientScoreSettlementProduction {
    private static var writers: [String: OrientScoreSettlementWriter] = [:]

    static func writer(session: AppSession, score: OrientSessionScore) -> OrientScoreSettlementWriter? {
        guard let runtime = session.currentRuntimeDependencyContext,
              runtime.role == "player" || runtime.role == "club",
              let api = session.regionalConfiguration?.apiConfiguration else { return nil }
        let key = "\(runtime.session.accountID)|\(runtime.session.epoch)|\(runtime.session.namespace)|\(score.sessionID)|\(score.scope.topicID)|\(score.scope.activityID)"
        if let existing = writers[key] {
            existing.note(score)
            return existing
        }
        let journal = Self.journal(accountID: runtime.session.accountID, namespace: runtime.session.namespace, sessionID: score.sessionID)
        guard let created = try? OrientScoreSettlementWriter(
            configuration: api, transport: session.runtimeHTTPTransport,
            token: { [weak session] in session?.token },
            ownerNamespace: runtime.session.namespace, accountID: runtime.session.accountID,
            role: runtime.role, score: score, journal: journal) else { return nil }
        writers[key] = created
        return created
    }

    /// Same account, namespace, and round keep one file, so a killed app still has the idempotency key.
    private static func journal(accountID: Int, namespace: String, sessionID: Int) -> OrientScoreSettlementFileJournal? {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return try? OrientScoreSettlementFileJournal(directory: root, accountID: accountID, namespace: namespace, sessionID: sessionID)
    }
}

@MainActor final class OrientScoreSettlementModel: ObservableObject {
    @Published private(set) var busy = false
    /// MP `notice` (one line, keyed).
    @Published private(set) var noticeKey: String?
    @Published private(set) var pendingKind: OrientScoreSettlementWriter.Kind?
    /// MP pending with no request id: 请人工核对, and no replay.
    @Published private(set) var needsManualReview = false
    /// The saved row could not be read. The card shows 原操作 and does not offer 请人工核对.
    @Published private(set) var journalUnreadable = false
    @Published private(set) var canSync = false
    @Published private(set) var canSettle = false
    @Published private(set) var pendingReviewCount = 0
    private var writer: OrientScoreSettlementWriter?
    /// Re-reads the score after a confirmed write (MP `this.load()`).
    var reload: () async -> Void = {}

    var hasWriter: Bool { writer != nil }

    func attach(session: AppSession?, score: OrientSessionScore?) {
        guard let session, let score else { writer = nil; refresh(nil); return }
        writer = OrientScoreSettlementProduction.writer(session: session, score: score)
        refresh(score)
        // MP `restorePending`: a saved pending write is recovered on the next load.
        if (pendingKind != nil || needsManualReview || journalUnreadable), !busy { Task { await recover() } }
    }

    private func refresh(_ score: OrientSessionScore?) {
        canSync = score?.canSync ?? false
        canSettle = score?.canSettle ?? false
        pendingReviewCount = score?.pendingReviewCount ?? 0
        pendingKind = writer?.pendingKind
        needsManualReview = writer?.needsManualReview ?? false
        journalUnreadable = writer?.journalUnreadable ?? false
    }

    func write(_ kind: OrientScoreSettlementWriter.Kind) async {
        guard let writer, !busy, pendingKind == nil, !journalUnreadable else { return }
        busy = true
        noticeKey = nil
        let outcome = await writer.write(kind)
        busy = false
        pendingKind = writer.pendingKind
        switch outcome {
        case .confirmed(let done):
            noticeKey = done == .settle ? "orientScore.notice.settleDone" : "orientScore.notice.syncDone"
            await reload()
        case .rejected:
            noticeKey = "orientScore.notice.notSent"
        case .unknown:
            noticeKey = "orientScore.notice.unknown"
        case .notStored:
            noticeKey = "orientScore.notice.notStored"
        }
    }

    func recover() async {
        guard let writer, !busy else { return }
        if writer.journalUnreadable {
            noticeKey = "orientScore.notice.storage"
            return
        }
        if writer.needsManualReview {
            noticeKey = "orientScore.notice.manualHint"
            return
        }
        guard pendingKind != nil else { return }
        busy = true
        let outcome = await writer.recover()
        busy = false
        pendingKind = writer.pendingKind
        if case .confirmed(let done) = outcome {
            noticeKey = done == .settle ? "orientScore.notice.settleConfirmed" : "orientScore.notice.syncConfirmed"
            await reload()
        } else {
            noticeKey = "orientScore.notice.recoverUnknown"
        }
    }

    func resumeSync() async {
        guard let writer, !busy, pendingKind == .sync else { return }
        busy = true
        let outcome = await writer.resumeSync()
        busy = false
        pendingKind = writer.pendingKind
        if case .confirmed = outcome {
            noticeKey = "orientScore.notice.syncConfirmed"
            await reload()
        } else {
            noticeKey = "orientScore.notice.resumeUnknown"
        }
    }

    /// MP `requestManualReview`. A confirmed post reloads the score and leaves the unkeyed row in place.
    func requestManualReview() async {
        guard let writer, !busy, writer.needsManualReview else { return }
        busy = true
        noticeKey = nil
        let outcome = await writer.requestManualReview()
        busy = false
        needsManualReview = writer.needsManualReview
        pendingKind = writer.pendingKind
        if case .confirmed = outcome {
            await reload()
            noticeKey = "orientScore.notice.manualHint"
        } else {
            noticeKey = "orientScore.notice.manualUnknown"
        }
    }
}

/// MP pending card (`index.wxml:25-31`): notice, kind label, 查看结果, 请人工核对, 继续同步.
/// 请人工核对 shows only when the saved row has no request id. 继续同步 needs a sync request id.
@MainActor struct OrientScoreSettlementPendingCard: View {
    @ObservedObject var model: OrientScoreSettlementModel
    @State private var confirmResume = false
    @State private var confirmManual = false

    var body: some View {
        if model.noticeKey != nil || model.pendingKind != nil || model.needsManualReview || model.journalUnreadable {
            // NAT-10 (native-r2): a list Section, not a card.
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(LocalizedStringKey(model.noticeKey ?? "orientScore.notice.pending"))
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("orientScore.settlement.notice")
                    if model.journalUnreadable || model.pendingKind != nil {
                        Text(LocalizedStringKey(kindKey))
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Button { Task { await model.recover() } } label: {
                            Text("orientScore.pending.recover").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.busy)
                        .accessibilityIdentifier("orientScore.pending.recover")
                        if model.needsManualReview {
                            Button { confirmManual = true } label: {
                                Text("orientScore.pending.manual").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.busy)
                            .accessibilityIdentifier("orientScore.pending.manual")
                        }
                        if model.pendingKind == .sync, !model.needsManualReview, !model.journalUnreadable {
                            Button { confirmResume = true } label: {
                                Text("orientScore.pending.resume").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.busy)
                            .accessibilityIdentifier("orientScore.pending.resume")
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .confirmationDialog("orientScore.resume.confirmTitle", isPresented: $confirmResume, titleVisibility: .visible) {
                Button("orientScore.pending.resume") { Task { await model.resumeSync() } }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("orientScore.resume.confirmMessage")
            }
            .confirmationDialog("orientScore.manual.confirmTitle", isPresented: $confirmManual, titleVisibility: .visible) {
                Button("orientScore.manual.confirm") { Task { await model.requestManualReview() } }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("orientScore.manual.confirmMessage")
            }
        }
    }

    private var kindKey: String {
        if model.journalUnreadable { return "orientScore.kind.unknown" }
        return model.pendingKind == .settle ? "orientScore.kind.settle" : "orientScore.kind.sync"
    }
}

/// MP 结算结果 card actions (`index.wxml:39-41`), mounted inside the app's settlement card.
@MainActor struct OrientScoreSettlementActions: View {
    @ObservedObject var model: OrientScoreSettlementModel

    var body: some View {
        if model.hasWriter {
            OrientScoreSettlementGapSection(
                canSync: model.canSync,
                canSettle: model.canSettle,
                pendingReviewCount: model.pendingReviewCount,
                busy: model.busy || model.pendingKind != nil || model.journalUnreadable,
                onSync: { Task { await model.write(.sync) } },
                onSettle: { Task { await model.write(.settle) } })
        }
    }
}
