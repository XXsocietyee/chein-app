import Foundation

/// Owner 2026-11-25 MP-first rule for cooperation writes (MC9-30-1).
/// China opens the non-money mutations the mini-program already sends.
/// Deposit create, deposit refund retry, and cancelling an accepted cooperation
/// (handle status 3 before the price lock) stay on the existing money gate:
/// a TEST host only, and never when `ReleaseMoneyWriteSwitch` blocks the path.
enum MPFirstCoopWrites {
    /// Default on, same as `MPFirstMerchantApprovals`.
    static let enabled = true

    static func admits(
        _ operation: CoopFlowMutation,
        market: RegionalMarket?,
        host: String?,
        cancelsAcceptedCooperation: Bool = false,
        testOrDebug: Bool = ReviewedAreaSwitch.compiledTestOrDebug
    ) -> Bool {
        if ReleaseMoneyWriteSwitch.blocks("/" + operation.path) { return false }
        let testHost = ReviewedAreaSwitch.merchantWrites(apiHost: host, testOrDebug: testOrDebug)
        // 取消合作 refunds a prepaid cooperation. It is not an MP-first write.
        if cancelsAcceptedCooperation { return testHost }
        if testHost { return true }
        guard enabled, china(market: market, host: host) else { return false }
        return nonMoneyCatalog(operation)
    }

    /// Perk-template executor. Templates are non-money; protected handle/invite writes use `admits`.
    static func admitsUnprotectedWrites(market: RegionalMarket?, host: String?) -> Bool {
        if ReviewedAreaSwitch.merchantWrites(apiHost: host) { return true }
        return enabled && china(market: market, host: host)
    }

    private static func china(market: RegionalMarket?, host: String?) -> Bool {
        if market == .china { return true }
        return host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == ReviewedAreaSwitch.productionAPIHost
    }

    /// Non-money `CoopFlowMutation`s. Accepted-cooperation cancel is filtered by the caller flag.
    private static func nonMoneyCatalog(_ operation: CoopFlowMutation) -> Bool {
        switch operation {
        case .invite, .decline, .withdraw, .confirm, .reject, .attachPerks, .review, .contact,
             .createTemplate, .deleteTemplate:
            return true
        case .handle(_, let action, _):
            return action == .accept || action == .reject || action == .cancel
        default:
            return false
        }
    }
}
