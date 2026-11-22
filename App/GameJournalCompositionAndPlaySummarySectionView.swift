import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif

/// Self-contained row for Wave-3 `I02` `GameJournalComposition` (`userStamps` + `completedTasks`
/// composition and `I00` standalone `loadUserStamps()` non-regression).
public struct GameJournalSliceRow: Sendable, Equatable, Identifiable {
    public enum SliceKind: String, Sendable, Equatable {
        case userStamps = "userStamps"
        case completedTasks = "completedTasks"
        case standaloneStampNonRegression = "standaloneStampNonRegression"
    }

    public enum Status: String, Sendable, Equatable {
        case ready
        case partialDegraded
        case failed
    }

    public let id: String
    public let kind: SliceKind
    public let title: String
    public let sourceContract: String
    public let itemCount: Int
    public let status: Status
    public let detail: String

    public init(
        id: String,
        kind: SliceKind,
        title: String,
        sourceContract: String,
        itemCount: Int,
        status: Status,
        detail: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.sourceContract = sourceContract
        self.itemCount = itemCount
        self.status = status
        self.detail = detail
    }

    public var badgeText: String {
        switch status {
        case .ready:
            return "READY"
        case .partialDegraded:
            return "DEGRADED"
        case .failed:
            return "FAILED"
        }
    }
}

/// Self-contained snapshot for Wave-3 `I02` `GameJournalComposition` and `I00` `loadUserStamps()` non-regression.
public struct GameJournalCompositionSnapshot: Sendable, Equatable {
    public let sessionOwnerScope: String
    public let standaloneLoadUserStampsIntact: Bool
    public let rows: [GameJournalSliceRow]

    public init(
        sessionOwnerScope: String,
        standaloneLoadUserStampsIntact: Bool,
        rows: [GameJournalSliceRow]
    ) {
        self.sessionOwnerScope = sessionOwnerScope
        self.standaloneLoadUserStampsIntact = standaloneLoadUserStampsIntact
        self.rows = rows
    }

    public static let defaultReady = GameJournalCompositionSnapshot(
        sessionOwnerScope: "member-i02-journal",
        standaloneLoadUserStampsIntact: true,
        rows: [
            GameJournalSliceRow(
                id: "user-stamps",
                kind: .userStamps,
                title: "已获印章切片 (userStamps)",
                sourceContract: "GameJournalComposition.userStamps · I02",
                itemCount: 6,
                status: .ready,
                detail: "按会话作用域聚合印章摘要，支持部分字段缺失时单切片降级展示"
            ),
            GameJournalSliceRow(
                id: "completed-tasks",
                kind: .completedTasks,
                title: "已完成任务切片 (completedTasks)",
                sourceContract: "GameJournalComposition.completedTasks · I02",
                itemCount: 4,
                status: .ready,
                detail: "按权威完赛记录聚合任务摘要，不伪造未确认奖励或时长"
            ),
            GameJournalSliceRow(
                id: "i00-standalone-stamps",
                kind: .standaloneStampNonRegression,
                title: "独立印章读取无回归 (loadUserStamps)",
                sourceContract: "loadUserStamps() · I00 Non-Regression",
                itemCount: 6,
                status: .ready,
                detail: "手账组合层保持独立印章列表路由与解码契约零回归"
            )
        ]
    )

    public var totalStampsCount: Int {
        rows.first(where: { $0.kind == .userStamps })?.itemCount ?? 0
    }

    public var totalCompletedTasksCount: Int {
        rows.first(where: { $0.kind == .completedTasks })?.itemCount ?? 0
    }

    public var isFullyReady: Bool {
        standaloneLoadUserStampsIntact && rows.allSatisfy { $0.status == .ready }
    }

    public var summaryText: String {
        "印章 \(totalStampsCount) 枚 · 完成任务 \(totalCompletedTasksCount) 项 · I00 独立读取 \(standaloneLoadUserStampsIntact ? "无回归" : "异常")"
    }
}

/// Renders Wave-3 `I02` `GameJournalComposition` (`userStamps` + `completedTasks` & `I00` standalone
/// `loadUserStamps()` non-regression) using `Text(verbatim:)` throughout.
@MainActor
public struct GameJournalCompositionAndPlaySummarySectionView: View {
    public let snapshot: GameJournalCompositionSnapshot

    public init(snapshot: GameJournalCompositionSnapshot = .defaultReady) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                HStack(spacing: CYSpacing.sm) {
                    Text(verbatim: "手账组合与游玩摘要")
                        .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: CYSpacing.sm)
                    CYStatusChip(verbatim: snapshot.isFullyReady ? "组合就绪" : "存在降级或异常", tone: snapshot.isFullyReady ? .success : .warning,
                                 systemImage: snapshot.isFullyReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .accessibilityIdentifier("gameJournalComposition.overallBadge")
                }
                HStack(spacing: CYSpacing.sm) {
                    stat(snapshot.totalStampsCount, "印章", "seal.fill")
                    stat(snapshot.totalCompletedTasksCount, "完成任务", "checkmark.circle.fill")
                }
                .accessibilityIdentifier("gameJournalComposition.summary")
                Label {
                    Text(verbatim: snapshot.standaloneLoadUserStampsIntact ? "独立印章读取保持正常" : "独立印章读取出现回归")
                        .cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                } icon: {
                    Image(systemName: snapshot.standaloneLoadUserStampsIntact ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(snapshot.standaloneLoadUserStampsIntact ? CYColor.successText : CYColor.warningText)
                }
                .accessibilityIdentifier("gameJournalComposition.standaloneNonRegression")
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.rows.enumerated()), id: \.element.id) { index, row in
                        CYTimelineItem(first: index == 0, last: index == snapshot.rows.count - 1, symbol: icon(row.kind),
                                       tint: row.status == .ready ? CYColor.successText : (row.status == .failed ? CYColor.dangerText : CYColor.warningText)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: row.title).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                                Text(verbatim: "\(row.itemCount) 项 · " + row.detail).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("gameJournalComposition.row.\(row.id)")
                    }
                }
                CYDetailsDisclosure(title: Text(verbatim: "数据来源")) {
                    ForEach(snapshot.rows) { row in
                        CYFactRow(label: Text(verbatim: row.badgeText), value: row.sourceContract)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .listRowInsets(EdgeInsets(top: 6, leading: CYSpacing.pageHorizontal, bottom: 6, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
        .accessibilityIdentifier("gameJournalComposition.section")
    }

    private func stat(_ n: Int, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: CYSpacing.md) {
            Image(systemName: symbol).font(.title3).foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: String(n)).cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                Text(verbatim: label).cyText(.caption).foregroundStyle(CYColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func icon(_ kind: GameJournalSliceRow.SliceKind) -> String {
        switch kind { case .userStamps: "seal.fill"; case .completedTasks: "checklist"; case .standaloneStampNonRegression: "tray.full.fill" }
    }

    private func tone(_ status: GameJournalSliceRow.Status) -> CYStatusTone {
        switch status { case .ready: .success; case .partialDegraded: .warning; case .failed: .danger }
    }
}
