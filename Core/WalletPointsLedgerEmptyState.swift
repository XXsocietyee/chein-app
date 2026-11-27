import Foundation

/// Empty-state copy for the points ledger, mirroring subpackageMember/points-history/index.wxml:
/// an empty ledger says "no points records yet"; an empty 获得 / 使用 filter on a non-empty ledger
/// names the missing direction instead of repeating the generic line.
public enum WalletPointsLedgerEmptyState {
    /// `direction` is the segmented selection: "all", "income" or "expense".
    /// R11-PC-D-2: an income ledger names its filter (MP subpackageA/components/scene-asset-income-detail/index.js:62-68:
    /// `all` → 还没有收益记录, otherwise `<tab label>还没有收益`).
    public static func key(direction: String, isIncomeLedger: Bool, isPointsLedger: Bool, incomeFilter: WalletIncomeFilter = .all) -> String {
        if isIncomeLedger {
            switch incomeFilter {
            case .all: return "wallet.income.empty"
            case .create: return "wallet.income.empty.create"
            case .brand: return "wallet.income.empty.brand"
            }
        }
        guard isPointsLedger else { return "wallet.empty" }
        switch direction {
        case "income": return "wallet.points.empty.income"
        case "expense": return "wallet.points.empty.expense"
        default: return "wallet.points.empty.all"
        }
    }
}
