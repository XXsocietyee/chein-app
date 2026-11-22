import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Self-contained presentation row for `I04` points ledger readback and order cancellation points conservation.
public struct AssetPointsCancellationRow: Identifiable, Equatable, Sendable {
    public enum ConservationState: String, Equatable, Sendable {
        case conservedByAuthority
        case awaitingServerReadback
        case discrepancyDetected
    }

    public let id: String
    public let orderNumber: String
    public let deductedPoints: Int
    public let refundedPointsFromAuthority: Int?
    public let state: ConservationState
    public let note: String
    /// English counterpart of `note` (nil = no translation known; the view then shows `note`).
    public let noteEnglish: String?

    public init(
        id: String,
        orderNumber: String,
        deductedPoints: Int,
        refundedPointsFromAuthority: Int?,
        state: ConservationState,
        note: String,
        noteEnglish: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.deductedPoints = deductedPoints
        self.refundedPointsFromAuthority = refundedPointsFromAuthority
        self.state = state
        self.note = note
        self.noteEnglish = noteEnglish
    }

    public var badgeText: String {
        switch state {
        case .conservedByAuthority:
            return "CONSERVED"
        case .awaitingServerReadback:
            return "PENDING_READBACK"
        case .discrepancyDetected:
            return "MISMATCH"
        }
    }

    public func deltaSummary(english: Bool) -> String {
        guard english else { return deltaSummaryText }
        if let refunded = refundedPointsFromAuthority {
            return "Deducted -\(deductedPoints) · Authoritative refund +\(refunded)"
        }
        return "Deducted -\(deductedPoints) · Refund awaiting server readback"
    }

    public func noteText(english: Bool) -> String { english ? (noteEnglish ?? note) : note }

    public var deltaSummaryText: String {
        if let refunded = refundedPointsFromAuthority {
            return "扣减 -\(deductedPoints) · 权威退回 +\(refunded)"
        }
        return "扣减 -\(deductedPoints) · 退回待服务端回读"
    }
}

/// Self-contained snapshot for `I04` points ledger readback and order cancellation points conservation.
public struct AssetPointsAndOrderCancellationSnapshot: Equatable, Sendable {
    public let ownerScope: String
    public let authoritativeBalancePoints: Int?
    public let rows: [AssetPointsCancellationRow]

    public init(
        ownerScope: String,
        authoritativeBalancePoints: Int?,
        rows: [AssetPointsCancellationRow]
    ) {
        self.ownerScope = ownerScope
        self.authoritativeBalancePoints = authoritativeBalancePoints
        self.rows = rows
    }

    public static let empty = AssetPointsAndOrderCancellationSnapshot(
        ownerScope: "unloaded",
        authoritativeBalancePoints: nil,
        rows: []
    )

    public init(
        ownerScope: String,
        authoritativeBalancePoints: Int?,
        orders: [ProfileOrder]
    ) {
        self.ownerScope = ownerScope
        self.authoritativeBalancePoints = authoritativeBalancePoints
        self.rows = orders.compactMap { order in
            guard let deducted = order.pointUsed, deducted > 0 else { return nil }
            let refunded = order.pointsReturned
            let state: AssetPointsCancellationRow.ConservationState
            let note: String
            let noteEnglish: String
            if let refunded {
                if refunded == deducted {
                    state = .conservedByAuthority
                    note = "订单取消后经服务端流水回读确认 \(refunded) 积分原路退回，本地不自造余额"
                    noteEnglish = "After the cancellation, the server ledger confirmed \(refunded) points were returned to the original account; no balance is computed locally"
                } else {
                    state = .discrepancyDetected
                    note = "退回积分与扣减积分不一致，需人工复核"
                    noteEnglish = "Returned points do not match deducted points; manual review is required"
                }
            } else {
                state = .awaitingServerReadback
                note = "取消请求已受理，积分余额与退回明细等待服务端权威回读 (I04)"
                noteEnglish = "Cancellation accepted; the points balance and refund details are awaiting authoritative server readback (I04)"
            }
            return AssetPointsCancellationRow(
                id: "order-\(order.id)",
                orderNumber: order.registrationNo ?? String(order.id),
                deductedPoints: deducted,
                refundedPointsFromAuthority: refunded,
                state: state,
                note: note,
                noteEnglish: noteEnglish
            )
        }
    }

    public var conservedCount: Int {
        rows.filter { $0.state == .conservedByAuthority }.count
    }

    public var pendingReadbackCount: Int {
        rows.filter { $0.state == .awaitingServerReadback }.count
    }

    public var discrepancyCount: Int {
        rows.filter { $0.state == .discrepancyDetected }.count
    }

    public var isConservationCompliant: Bool {
        discrepancyCount == 0
    }

    public func balanceDisplay(english: Bool) -> String {
        guard english else { return balanceDisplayText }
        if let balance = authoritativeBalancePoints { return "\(balance) points (authoritative server readback)" }
        return "— (awaiting authoritative server readback)"
    }

    public func summary(english: Bool) -> String {
        english ? "Conserved \(conservedCount) · Pending readback \(pendingReadbackCount) · Mismatched \(discrepancyCount)" : summaryText
    }

    public var balanceDisplayText: String {
        if let balance = authoritativeBalancePoints {
            return "\(balance) 积分（服务端权威回读）"
        }
        return "—（待服务端权威回读）"
    }

    public var summaryText: String {
        "守恒确认 \(conservedCount) · 待回读 \(pendingReadbackCount) · 异常 \(discrepancyCount)"
    }
}

/// Renders `I04` points ledger readback and order cancellation points conservation using `Text(verbatim:)` throughout.
@MainActor
public struct AssetPointsAndOrderCancellationSectionView: View {
    public let snapshot: AssetPointsAndOrderCancellationSnapshot
    @Environment(\.locale) private var locale
    private var english: Bool { locale.language.languageCode?.identifier != "zh" }

    public init(snapshot: AssetPointsAndOrderCancellationSnapshot = .empty) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Section {
            HStack {
                Text(verbatim: english ? "Points ledger and refund conservation (I04)" : "积分流水与退单守恒 (I04)")
                    .cyText(.bodyMedium)
                Spacer()
                Text(verbatim: snapshot.isConservationCompliant ? (english ? "Conserved (I04_OK)" : "守恒合规 (I04_OK)") : (english ? "Ledger mismatch" : "存在账目偏差"))
                    .cyText(.caption, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((snapshot.isConservationCompliant ? CYColor.successText : CYColor.dangerText).opacity(0.15), in: Capsule())
                    .foregroundStyle(snapshot.isConservationCompliant ? CYColor.successText : CYColor.dangerText)
                    .accessibilityIdentifier("assetPointsCancellation.overallBadge")
            }

            LabeledContent {
                Text(verbatim: snapshot.balanceDisplay(english: english))
                    .cyText(.numericBody)
            } label: {
                Text(verbatim: english ? "Authoritative points balance" : "当前权威积分余额")
            }
            .accessibilityIdentifier("assetPointsCancellation.balance")

            LabeledContent {
                Text(verbatim: snapshot.summary(english: english))
                    .cyText(.numericBody)
            } label: {
                Text(verbatim: english ? "Refund conservation summary" : "退单守恒统计")
            }
            .accessibilityIdentifier("assetPointsCancellation.summary")

            ForEach(snapshot.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: row.orderNumber)
                            .font(.subheadline.monospaced().weight(.semibold))
                        Spacer()
                        Text(verbatim: row.badgeText)
                            .cyText(.caption, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor(for: row.state).opacity(0.15), in: Capsule())
                            .foregroundStyle(badgeColor(for: row.state))
                    }
                    Text(verbatim: row.deltaSummary(english: english))
                        .cyText(.meta, monospacedDigit: true)
                    Text(verbatim: row.noteText(english: english))
                        .cyText(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("assetPointsCancellation.row.\(row.id)")
            }
        } header: {
            Text(verbatim: english ? "Asset points and order cancellation conservation check (I04)" : "资产积分与订单取消守恒核查 (I04)")
        }
        .accessibilityIdentifier("assetPointsCancellation.section")
    }

    private func badgeColor(for state: AssetPointsCancellationRow.ConservationState) -> Color {
        switch state {
        case .conservedByAuthority:
            return .green
        case .awaitingServerReadback:
            return .orange
        case .discrepancyDetected:
            return .red
        }
    }
}
