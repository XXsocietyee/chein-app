import SwiftUI

/// fix/r3-merchant-coop-a: the MP merchant pages replace the whole page with one state when the first read
/// fails, using page-specific copy. `MerchantBusinessPage` used to show the generic error text and retry instead.
/// - MC7-04-1 verify-records/index.wxml:15 · 当前身份不能查看核销记录
/// - MC7-13-4 reviews/index.wxml:22-25 · 当前身份不能管理口碑 / 登录后查看口碑管理
/// - MC7-14-8 customer/index.wxml:13,54-55 · 当前身份不能查看客户 (search and filters hidden)
/// - MC7-15-3 / MC7-15-5 customer/detail/index.wxml:11-20 · 找不到这位客户 / 当前身份不能查看客户 / 客户详情加载失败
/// - MC7-16-1 / MC7-17-2 aftercare(/detail)/index.wxml:17-21 · 当前身份不能查看退款售后
/// - ledger pages (MC7-06-2) · 当前身份不能查看这份商家账本
/// - MC7-07-3 ledger/order-detail/index.wxml:57-64 · 核销记录不可见 (+ 返回核销列表) / 核销详情加载失败
struct MerchantBusinessPageGate: Equatable {
    enum Kind: Equatable { case signIn, denied, notFound(backKey: String), loadFailed(message: String?) }
    let kind: Kind
    let titleKey: String

    /// Only a page with nothing loaded is replaced; write failures keep the loaded page and its inline error.
    static func resolve(query: MerchantBusinessQuery, failureKey: String?, failure: MerchantBusinessFailure?,
                        hasSnapshot: Bool, isBusy: Bool, loadedRecordMissing: Bool = false) -> Self? {
        if loadedRecordMissing, !isBusy, case .redemption = query { return redemptionMissing }
        guard let failureKey, !hasSnapshot, !isBusy else { return nil }
        switch failureKey {
        case "auth.expired":
            return .init(kind: .signIn, titleKey: signInKey(query))
        case MerchantBusinessFailure.denied.key:
            guard let key = deniedKey(query) else { return nil }
            return .init(kind: .denied, titleKey: key)
        default:
            var message: String?
            if case .rejected(_, let text) = failure { message = text }
            let notFound: Bool = { if case .rejected(let code, _) = failure { return code == 404 }; return false }()
            switch query {
            case .customer:
                if notFound { return .init(kind: .notFound(backKey: "merchant.gate.customer.backToList"), titleKey: "merchant.gate.customer.notFound") }
                return .init(kind: .loadFailed(message: message), titleKey: "merchant.gate.customer.loadFailed")
            case .redemption:
                // MC7-07-1 / finance-detail-load.js: 404, or a message saying 记录不存在 / 记录不可见, is the missing record.
                let missing: Bool = {
                    guard case .rejected(let code, let text) = failure else { return false }
                    return MerchantFinanceDetailLoad.isMissingRecord(code: String(code), statusCode: nil, message: text)
                }()
                if notFound || missing { return redemptionMissing }
                return .init(kind: .loadFailed(message: message), titleKey: "merchant.gate.redemption.loadFailed")
            default:
                return nil
            }
        }
    }

    private static let redemptionMissing = Self(kind: .notFound(backKey: "merchant.gate.redemption.backToList"),
                                                titleKey: "merchant.gate.redemption.missing")

    private static func signInKey(_ query: MerchantBusinessQuery) -> String {
        if case .reviews = query { return "merchant.gate.reviews.signIn" }
        return "merchant.gate.signIn"
    }

    private static func deniedKey(_ query: MerchantBusinessQuery) -> String? {
        switch query {
        case .verificationRecords, .redemption: return "merchant.gate.verifyRecords.denied"
        case .reviews: return "merchant.gate.reviews.denied"
        case .customers, .customer: return "merchant.gate.customers.denied"
        case .aftercare, .refund: return "merchant.gate.aftercare.denied"
        case .overview, .redemptions, .entries, .batches, .batch: return "merchant.gate.ledger.denied"
        default: return nil
        }
    }
}

struct MerchantBusinessPageGateView: View {
    let gate: MerchantBusinessPageGate
    let retry: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch gate.kind {
        case .signIn:
            MerchantSignInState(title: LocalizedStringKey(gate.titleKey), identifier: "merchant.business.gate.signIn")
        case .denied:
            MerchantDeniedState(title: LocalizedStringKey(gate.titleKey), identifier: "merchant.business.gate.denied")
        case .notFound(let backKey):
            ContentUnavailableView {
                Label(LocalizedStringKey(gate.titleKey), systemImage: "questionmark.folder")
            } actions: {
                Button { dismiss() } label: {
                    Text(LocalizedStringKey(backKey)).frame(minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("merchant.business.gate.notFound.back")
            }
            .accessibilityIdentifier("merchant.business.gate.notFound")
        case .loadFailed(let message):
            MerchantLoadFailedState(title: LocalizedStringKey(gate.titleKey), message: message,
                                    identifier: "merchant.business.gate.loadFailed", retry: retry)
        }
    }
}
