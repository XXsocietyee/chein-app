import Foundation

/// Empty-state copy for the points ledger, mirroring subpackageMember/points-history/index.wxml:
/// an empty ledger says "no points records yet"; an empty 获得 / 使用 filter on a non-empty ledger
/// names the missing direction instead of repeating the generic line.
public enum WalletPointsLedgerEmptyState {
    /// `direction` is the segmented selection: "all", "income" or "expense".
    public static func key(direction: String, isIncomeLedger: Bool, isPointsLedger: Bool) -> String {
        if isIncomeLedger { return "wallet.income.empty" }
        guard isPointsLedger else { return "wallet.empty" }
        switch direction {
        case "income": return "wallet.points.empty.income"
        case "expense": return "wallet.points.empty.expense"
        default: return "wallet.points.empty.all"
        }
    }
}
