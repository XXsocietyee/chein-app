import SwiftUI

/// `PLY-25-2` / `25-3` / `25-4` / `25-5`: Orient score leaderboard sheet, per-row/missing-node appeal sheet,
/// and owner-gated sync/settle section.
public struct OrientScoreLeaderboardSheetView: View {
    public let rows: [OrientScoreLeaderboardItem]
    public let myRow: OrientScoreLeaderboardItem?
    public var onClose: () -> Void

    public init(
        rows: [OrientScoreLeaderboardItem],
        myRow: OrientScoreLeaderboardItem? = nil,
        onClose: @escaping () -> Void
    ) {
        self.rows = rows
        self.myRow = myRow
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("orientScore.board.title"), style: .player, onClose: onClose)
            if rows.isEmpty {
                ContentUnavailableView("orientScore.board.empty", systemImage: "list.number")
            } else {
                List {
                    if let myRow {
                        Section("orientScore.board.mineSection") {
                            rowView(myRow)
                        }
                    }
                    Section("orientScore.board.allSection") {
                        ForEach(rows) { row in
                            rowView(row)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func rowView(_ row: OrientScoreLeaderboardItem) -> some View {
        HStack {
            Text("\(row.rank)")
                .cyText(.numericBody, monospacedDigit: true)
                .frame(width: 32, alignment: .leading)
            (row.isMine ? Text("orientScore.board.mine") : Text("orientScore.board.player"))
                .cyText(.bodyMedium)
            Spacer()
            Text("\(row.scoreText) · \(row.elapsedText)")
                .cyText(.meta, monospacedDigit: true)
                .foregroundStyle(CYColor.textSecondary)
        }
    }
}

public struct OrientScoreAppealSheetView: View {
    public let kind: OrientReviewSheetKind
    public let entryID: String?
    public let isBusy: Bool
    public let errorMessage: String?
    public var onSubmit: (_ nodeID: Int?, _ reason: String) -> Void
    public var onClose: () -> Void

    @State private var nodeIDText = ""
    @State private var reason = ""

    public init(
        kind: OrientReviewSheetKind,
        entryID: String? = nil,
        isBusy: Bool = false,
        errorMessage: String? = nil,
        onSubmit: @escaping (_ nodeID: Int?, _ reason: String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.kind = kind
        self.entryID = entryID
        self.isBusy = isBusy
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: kind == .appeal ? Text("orientScore.review.appeal") : Text("orientScore.review.dispute"), style: .player, onClose: onClose)
            Form {
                if entryID != nil {
                    Section {
                        Text("orientScore.appeal.singleEntry")
                            .cyText(.bodyCompact)
                    }
                } else if kind == .appeal {
                    Section("orientScore.appeal.missingNodeTitle") {
                        TextField("orientScore.appeal.missingNodePlaceholder", text: $nodeIDText)
                            .keyboardType(.numberPad)
                    }
                }

                Section {
                    TextEditor(text: $reason)
                        .frame(minHeight: 120)
                        .onChange(of: reason) { _, newValue in
                            let clamped = OrientAppealValidator.clampReason(newValue)
                            if clamped != newValue { reason = clamped }
                        }
                } header: {
                    Text("orientScore.appeal.reasonTitle")
                } footer: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack {
                            Spacer()
                            Text("\(reason.count)/\(OrientAppealValidator.maxReasonLength)")
                                .cyText(.meta, monospacedDigit: true)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .cyText(.meta)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button("common.submit") {
                        let parsedNode = entryID == nil ? Int(nodeIDText.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
                        onSubmit(parsedNode, reason.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .buttonStyle(.cyPrimary)
                    .frame(maxWidth: .infinity)
                    .disabled(isBusy || !OrientAppealValidator.isValid(kind: kind, entryID: entryID, nodeIDText: nodeIDText, reason: reason))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

public struct OrientScoreSettlementGapSection: View {
    public let canSync: Bool
    public let canSettle: Bool
    public let pendingReviewCount: Int
    /// Owner-gated: sync/settle stay disabled until owner enables orient settlement.
    public let settlementActionsEnabled: Bool
    public var onSync: () -> Void = {}
    public var onSettle: () -> Void = {}

    @State private var confirmSync = false
    @State private var confirmSettle = false

    public init(
        canSync: Bool,
        canSettle: Bool,
        pendingReviewCount: Int = 0,
        settlementActionsEnabled: Bool = false,
        onSync: @escaping () -> Void = {},
        onSettle: @escaping () -> Void = {}
    ) {
        self.canSync = canSync
        self.canSettle = canSettle
        self.pendingReviewCount = pendingReviewCount
        self.settlementActionsEnabled = settlementActionsEnabled
        self.onSync = onSync
        self.onSettle = onSettle
    }

    public var body: some View {
        if canSync || canSettle || pendingReviewCount > 0 {
            Section {
                if pendingReviewCount > 0 {
                    Text("orientScore.pendingReview \(pendingReviewCount)")
                        .cyText(.meta, monospacedDigit: true)
                        .foregroundStyle(CYColor.textSecondary)
                }
                if canSync {
                    Button("orientScore.syncTasks") { confirmSync = true }
                        .buttonStyle(.bordered)
                        .disabled(!settlementActionsEnabled)
                        .confirmationDialog("orientScore.syncTasks.confirmTitle", isPresented: $confirmSync, titleVisibility: .visible) {
                            Button("orientScore.syncTasks", action: onSync)
                            Button("common.cancel", role: .cancel) {}
                        }
                }
                if canSettle {
                    Button("orientScore.settleRun") { confirmSettle = true }
                        .buttonStyle(.cyPrimary)
                        .disabled(!settlementActionsEnabled)
                        .confirmationDialog("orientScore.settleRun.confirmTitle", isPresented: $confirmSettle, titleVisibility: .visible) {
                            Button("orientScore.settleRun", action: onSettle)
                            Button("common.cancel", role: .cancel) {}
                        }
                }
            } footer: {
                if !settlementActionsEnabled {
                    Text("orientScore.settlementGated")
                        .cyText(.meta)
                }
            }
        }
    }
}
