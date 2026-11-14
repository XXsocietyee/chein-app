import SwiftUI

/// Visible loading, empty, error, and ready states for the WP-10 payout screens.
/// `--owner-decision-fixture=receiver-loading|receiver-empty|receiver-error|receiver|merchant-loading|merchant-empty|merchant-error|merchant-denied|merchant`
struct OwnerDecisionFixtureHost: View {
    let mode: String

    var body: some View {
        NavigationStack {
            switch mode {
            case "receiver-loading":
                ClubPayoutReceiverView(clubID: 9003, fixture: .init(phase: .loading))
            case "receiver-empty":
                ClubPayoutReceiverView(clubID: nil, fixture: .init(phase: .empty))
            case "receiver-error":
                ClubPayoutReceiverView(clubID: 9003, fixture: .init(phase: .error, message: "个人收款状态暂不可用"))
            case "merchant-loading":
                MerchantPayoutAccountView(permissions: [OwnerDecisionReceiverCopy.financePermission], fixture: .init(phase: .loading))
            case "merchant-empty":
                MerchantPayoutAccountView(permissions: [OwnerDecisionReceiverCopy.financePermission],
                                           fixture: .init(phase: .empty, account: OwnerDecisionMerchantAccount.shape(["available": true, "state": "NONE"])))
            case "merchant-error":
                MerchantPayoutAccountView(permissions: [OwnerDecisionReceiverCopy.financePermission], fixture: .init(phase: .error, message: "收款账户加载失败"))
            case "merchant-denied":
                MerchantPayoutAccountView(permissions: [], fixture: .init(phase: .ready, denied: true))
            case "merchant":
                MerchantPayoutAccountView(permissions: [OwnerDecisionReceiverCopy.financePermission], fixture: readyAccount)
            default:
                ClubPayoutReceiverView(clubID: 9003, fixture: readyReceiver)
            }
        }
    }

    private var readyReceiver: OwnerDecisionScreenFixture {
        .init(phase: .ready, status: OwnerDecisionReceiverStatus.shape([
            "available": true, "receiverState": "VERIFIED", "paused": false, "payoutEnabled": false, "canUnbind": true
        ]))
    }

    private var readyAccount: OwnerDecisionScreenFixture {
        .init(phase: .ready, account: OwnerDecisionMerchantAccount.shape([
            "available": true, "state": "NEED_SIGN", "stateDesc": "等待本人签约",
            "signUrl": "https://www.chengyinhub.com/sign/example"
        ]))
    }
}
