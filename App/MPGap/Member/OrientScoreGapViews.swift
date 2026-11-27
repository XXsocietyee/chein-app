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

    // NAT-R11-2: plain navigation bar with a system close button (MP orient-score/index.wxml cy-sheet).
    public var body: some View {
        NavigationStack {
            boardContent
                .navigationTitle(Text("orientScore.board.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) }
                }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var boardContent: some View {
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

    // NAT-R11-2: plain navigation bar with a system close button (MP orient-score/index.wxml cy-sheet).
    public var body: some View {
        NavigationStack {
            appealForm
                .navigationTitle(kind == .appeal ? Text("orientScore.review.appeal") : Text("orientScore.review.dispute"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private var appealForm: some View {
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
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isBusy || !OrientAppealValidator.isValid(kind: kind, entryID: entryID, nodeIDText: nodeIDText, reason: reason))
                }
            }
    }
}

/// MP 结算结果 actions (`orient-score/index.wxml:39-41`, `index.js:268-283` confirm modal).
/// PLY-25-2: mounted by `OrientScoreSettlementActions`; no app-only gate (MP-first).
public struct OrientScoreSettlementGapSection: View {
    public let canSync: Bool
    public let canSettle: Bool
    public let pendingReviewCount: Int
    /// MP `busy || !!pending`.
    public let busy: Bool
    public var onSync: () -> Void = {}
    public var onSettle: () -> Void = {}

    @State private var confirmSync = false
    @State private var confirmSettle = false

    public init(
        canSync: Bool,
        canSettle: Bool,
        pendingReviewCount: Int = 0,
        busy: Bool = false,
        onSync: @escaping () -> Void = {},
        onSettle: @escaping () -> Void = {}
    ) {
        self.canSync = canSync
        self.canSettle = canSettle
        self.pendingReviewCount = pendingReviewCount
        self.busy = busy
        self.onSync = onSync
        self.onSettle = onSettle
    }

    public var body: some View {
        if canSync || canSettle || pendingReviewCount > 0 {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if canSync {
                    Button { confirmSync = true } label: {
                        Text("orientScore.syncTasks").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)
                    .accessibilityIdentifier("orientScore.sync")
                    .confirmationDialog("orientScore.sync.confirmTitle", isPresented: $confirmSync, titleVisibility: .visible) {
                        Button("orientScore.write.confirm", action: onSync)
                        Button("common.cancel", role: .cancel) {}
                    } message: {
                        Text("orientScore.sync.confirmMessage")
                    }
                }
                if pendingReviewCount > 0 {
                    Text("orientScore.pendingReview \(pendingReviewCount)")
                        .cyText(.meta, monospacedDigit: true)
                        .foregroundStyle(CYColor.textSecondary)
                }
                if canSettle {
                    Button { confirmSettle = true } label: {
                        Text("orientScore.settleRun").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy)
                    .accessibilityIdentifier("orientScore.settle")
                    .confirmationDialog("orientScore.settle.confirmTitle", isPresented: $confirmSettle, titleVisibility: .visible) {
                        Button("orientScore.write.confirm", action: onSettle)
                        Button("common.cancel", role: .cancel) {}
                    } message: {
                        Text("orientScore.settle.confirmMessage")
                    }
                }
            }
        }
    }
}
