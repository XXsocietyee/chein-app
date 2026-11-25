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
        guard let created = try? OrientScoreSettlementWriter(
            configuration: api, transport: session.runtimeHTTPTransport,
            token: { [weak session] in session?.token },
            ownerNamespace: runtime.session.namespace, accountID: runtime.session.accountID,
            role: runtime.role, score: score) else { return nil }
        writers[key] = created
        return created
    }
}

@MainActor final class OrientScoreSettlementModel: ObservableObject {
    @Published private(set) var busy = false
    /// MP `notice` (one line, keyed).
    @Published private(set) var noticeKey: String?
    @Published private(set) var pendingKind: OrientScoreSettlementWriter.Kind?
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
        if pendingKind != nil, !busy { Task { await recover() } }
    }

    private func refresh(_ score: OrientSessionScore?) {
        canSync = score?.canSync ?? false
        canSettle = score?.canSettle ?? false
        pendingReviewCount = score?.pendingReviewCount ?? 0
        pendingKind = writer?.pendingKind
    }

    func write(_ kind: OrientScoreSettlementWriter.Kind) async {
        guard let writer, !busy, pendingKind == nil else { return }
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
        }
    }

    func recover() async {
        guard let writer, !busy, pendingKind != nil else { return }
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
}

/// MP pending card (`index.wxml:25-31`): notice, 原操作 label, 查看结果, 继续同步.
/// 请人工核对 is not shown: the MP shows it only for a pending record with no request id, which this writer never keeps.
@MainActor struct OrientScoreSettlementPendingCard: View {
    @ObservedObject var model: OrientScoreSettlementModel
    @State private var confirmResume = false

    var body: some View {
        if model.noticeKey != nil || model.pendingKind != nil {
            CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(LocalizedStringKey(model.noticeKey ?? "orientScore.notice.pending"))
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("orientScore.settlement.notice")
                    if let kind = model.pendingKind {
                        Text(LocalizedStringKey(kind == .sync ? "orientScore.kind.sync" : "orientScore.kind.settle"))
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Button { Task { await model.recover() } } label: {
                            Text("orientScore.pending.recover").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.cySecondary(fullWidth: true))
                        .disabled(model.busy)
                        .accessibilityIdentifier("orientScore.pending.recover")
                        if kind == .sync {
                            Button { confirmResume = true } label: {
                                Text("orientScore.pending.resume").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            }
                            .buttonStyle(.cySecondary(fullWidth: true))
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
        }
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
                busy: model.busy || model.pendingKind != nil,
                onSync: { Task { await model.write(.sync) } },
                onSettle: { Task { await model.write(.settle) } })
        }
    }
}
