import SwiftUI

/// The existing phase remains separate from progress. A full bar is not a new success event.
struct PlayTaskSummaryView: View {
    @Environment(\.themeDomain) private var domain
    @Environment(\.cyPalette) private var palette
    let snapshot: PlaySnapshot
    let phase: String
    @State private var branchHistorySelection: PlayBranchHistorySelection?
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    private var summary: PlayTaskSummaryPresentation { .init(snapshot: snapshot) }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if let title = snapshot.result.topicName {
                Text(verbatim: title)
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            LabeledContent("playx.state") { PlayRuntimePhaseText(phase: phase) }
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
            if let done = summary.completed, let total = summary.total, let fraction = summary.fraction {
                CYProgressBar(
                    title: appLocalized("playx.progress", locale: locale),
                    completed: done,
                    total: total,
                    loadFailed: phase == "failed"
                )
                Text(verbatim: String(format: appLocalized("referenceTask.completedCount", locale: locale), locale: locale, done, total))
                    .cyText(.meta, weight: .semibold).monospacedDigit()
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("referenceTask.count")
                ProgressView(value: fraction)
                    .accessibilityLabel(Text("playx.progress"))
                    .accessibilityValue(Text(verbatim: String(format: appLocalized("referenceTask.completedCount", locale: locale), locale: locale, done, total)))
                    .accessibilityIdentifier("referenceTask.progress")
                    .transaction { if reduceMotion { $0.animation = nil } }
                    .hidden()
                    .frame(height: 0)
            } else {
                // pages/play/index: UNKNOWN progress is the em dash from PlayIndexPageReadiness, never 0/0.
                let readiness = PlayIndexPageReadiness(phase: phase, readsEnabled: true, unresolved: false, snapshot: snapshot)
                CYProgressBar(
                    title: appLocalized("playx.progress", locale: locale),
                    completed: nil,
                    total: nil,
                    loadFailed: phase == "failed"
                )
                LabeledContent("playx.progress") {
                    Text(verbatim: readiness.progressText).monospacedDigit()
                        .accessibilityLabel(Text("play.progress.unknown"))
                        .accessibilityIdentifier("referenceTask.phaseOnly")
                }
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
            }
            if let selection = PlayBranchHistorySelection(snapshot: snapshot), phase == "ready" || phase == "unknown" {
                CYPillButton(verbatim: branchHistoryLocalized("branchHistory.open", locale: locale), style: .tertiary, systemImage: "list.bullet.rectangle") {
                    branchHistorySelection = selection
                }.accessibilityIdentifier("branchHistory.open")
            }
        }
        .cyText(.body)
        .foregroundStyle(palette.textPrimary)
        .tint(palette.actionPrimaryBg)
        .accessibilityElement(children: .contain)
        .sheet(item: $branchHistorySelection) { selection in Group {
            PlayBranchHistoryView(history: selection.presentation(snapshot: snapshot))
        }.cySheet(detents: [.large]) }
        .onChange(of: PlayBranchHistorySelection(snapshot: snapshot)) { _, current in
            if current != branchHistorySelection { branchHistorySelection = nil }
        }
        .onDisappear { branchHistorySelection = nil }
        .onChange(of: phase) { _, value in
            if value != "ready" && value != "unknown" { branchHistorySelection = nil }
        }
    }
}

/// Maps runtime node, coordinator phase, recovery receipt, and offline flags to the 6-state `CYTaskStatusCard`.
enum PlayTaskStatusCardMapper {
    @MainActor
    static func state(
        node: PlayNode,
        snapshot: PlaySnapshot,
        model: PlayExperienceCoordinator,
        locale: Locale,
        ctaTitle: String,
        onOpen: @escaping () -> Void,
        onRefresh: @escaping () -> Void
    ) -> CYTaskStatusState {
        let copy = CoreLoopCopy(locale: locale)
        if snapshot.isLocked(node) {
            let reason = snapshot.lockReason(node) ?? copy.t("完成前置点位后解锁", "Complete prerequisite stop to unlock")
            let prereqTitle = node.unlockAfterNodeID.flatMap { id in
                snapshot.visibleNodes.first(where: { $0.id == id })?.name
            }
            return .locked(requirement: reason, prereqTitle: prereqTitle, onOpenPrereq: nil)
        }
        if model.remoteRunSaveFailed || model.routeNotice == .unsynced {
            return .offlineAwaitingSync(
                draftId: "NODE-\(node.id)",
                savedAt: copy.t("待同步", "Pending"),
                onSyncNow: onRefresh,
                onViewDraft: onOpen
            )
        }
        if let recovery = model.submitRecovery, recovery.nodeID == node.id {
            switch recovery {
            case .checking, .pending:
                return .submitting(requestId: "REQ-\(node.id)")
            case .confirmed:
                return .completed(
                    receiptNo: "DONE-\(node.id)",
                    completedAt: copy.t("已核验完成", "Verified"),
                    onViewReceipt: onOpen
                )
            case .failed(_, let refusal):
                return .retryableFailure(
                    requestId: "REQ-\(node.id)",
                    detail: refusal.message ?? copy.t("提交未生效，可先核对原回执或重试", "Submission not applied; check receipt or retry"),
                    onQueryOriginalReceipt: onRefresh,
                    onRetry: onOpen
                )
            case .conflict:
                return .retryableFailure(
                    requestId: "SYNC-\(node.id)",
                    detail: copy.t("路线状态已更新，请刷新后再提交", "Route state updated; refresh before retrying"),
                    onQueryOriginalReceipt: onRefresh,
                    onRetry: onOpen
                )
            }
        }
        if model.phase == .submitting || model.phase == .needsReadback {
            return .submitting(requestId: "REQ-\(node.id)")
        }
        if model.unresolved || model.phase == .failed {
            return .retryableFailure(
                requestId: "REQ-\(node.id)",
                detail: copy.t("结果尚未确认，先刷新回执而不重复扣次", "Outcome unconfirmed; refresh receipt before retrying"),
                onQueryOriginalReceipt: onRefresh,
                onRetry: onOpen
            )
        }
        if snapshot.isDone(node) {
            return .completed(
                receiptNo: "DONE-\(node.id)",
                completedAt: copy.t("已完成", "Completed"),
                onViewReceipt: onOpen
            )
        }
        let methodLabel: String = {
            let task = PlayNodeTask.resolve(mode: snapshot.result.mode, node: node)
            let arrivalText: String = {
                if node.arrived == true { return copy.t(" · 已到达", " · Arrived") }
                if node.needGPS == true || node.needScan == true { return copy.t(" · 需到场验证", " · Arrival needed") }
                return ""
            }()
            switch task {
            case .answer: return copy.t("线索解谜", "Puzzle") + arrivalText
            case .photo: return copy.t("拍照打卡", "Photo") + arrivalText
            case .scan: return copy.t("扫码验证", "Scan") + arrivalText
            default: return copy.t("现场任务", "Task") + arrivalText
            }
        }()
        return .available(methodLabel: methodLabel, ctaTitle: ctaTitle, onStart: onOpen)
    }

    static func routeCompletion(for node: PlayNode, in snapshot: PlaySnapshot, currentNodeID: Int?) -> CYRouteNodeCompletion {
        if snapshot.isDone(node) { return .completed }
        if snapshot.isLocked(node) { return .locked }
        if node.id == currentNodeID { return .current }
        return .upcoming
    }

    /// F-05: row state from `PlayStationListPresentation`; same mapping as `routeCompletion(for:in:currentNodeID:)`.
    static func routeCompletion(_ state: PlayStationListRow.State) -> CYRouteNodeCompletion {
        switch state {
        case .completed: return .completed
        case .locked: return .locked
        case .current: return .current
        case .available: return .upcoming
        }
    }

    static func arrivalRequirement(for node: PlayNode) -> CYRouteArrivalRequirement {
        if node.needScan == true { return .qr }
        if node.needGPS == true { return .gps }
        return .neutral("自由到达")
    }
}

struct PlayTaskStatusBadge: View {
    let node: PlayNode
    let snapshot: PlaySnapshot
    private var status: PlayTaskStatusPresentation { .init(node: node, snapshot: snapshot) }
    var body: some View {
        QuestifyStatusBadge(title: LocalizedStringKey(status.labelKey), systemImage: status.symbol,
                            emphasized: status == .available, stateKey: status.rawValue)
            .accessibilityIdentifier("referenceTask.status.\(node.id)")
    }
}
