import Foundation

/// 1128 gap #11 (O-08; R10, 收款模型定稿 §3 "平台不打款"): every 提现 entry opens a popup with the platform support
/// WeChat id and a Copy button. The MP keeps the id in one constant (`chengyinhub-xcx/utils/withdraw-cs.js:8`
/// `WITHDRAW_CS_WECHAT_ID`); the app bundles the same public contact through the Info.plist key
/// `QuestifyWithdrawSupportWeChatID` (xcconfig `QUESTIFY_WITHDRAW_SUPPORT_WECHAT_ID`, Config/OwnerValues.xcconfig).
/// No request is sent: there is no withdraw call and no contact endpoint.
enum WithdrawalSupportBundledSource {
    static let infoKey = "QuestifyWithdrawSupportWeChatID"
    /// Changes only when the bundled contact policy changes; the copy action compares it.
    static let revision = "mp-withdraw-cs-2026-09-15"
    static let approvalID = "bundled-withdraw-cs"
    /// One day; the reader re-reads on every open and every copy.
    static let lifetime: TimeInterval = 86_400

    /// The bundled id, or nil when the build left it empty or unexpanded.
    static func weChatID(_ raw: Any?) -> String? {
        guard let text = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              !text.contains("$("), (try? WithdrawalSupportContact(weChatID: text)) != nil else { return nil }
        return text
    }

    static var bundledWeChatID: String? { weChatID(Bundle.main.object(forInfoDictionaryKey: infoKey)) }

    /// Approved only on a reviewed deployment that bundles an id. Fixtures and unconfigured builds keep "未配置".
    static func approval(reviewed: Bool, market: RegionalMarket?, weChatID: String?) -> WithdrawalSupportApproval? {
        guard reviewed, let market, weChatID != nil else { return nil }
        return WithdrawalSupportApproval(id: approvalID, market: market)
    }

    static func configuration(namespace: String?, market: RegionalMarket?, weChatID: String?, now: Date) -> WithdrawalSupportConfiguration? {
        guard let namespace, let market, let weChatID, let contact = try? WithdrawalSupportContact(weChatID: weChatID) else { return nil }
        return try? WithdrawalSupportConfiguration(namespace: namespace, market: market, revision: revision,
                                                   expiresAt: now.addingTimeInterval(lifetime), contact: contact)
    }
}

@MainActor extension AppSession {
    /// The Release reader: the bundled contact, scoped to the signed-in wallet namespace.
    func makeBundledWithdrawalSupportReader() -> WithdrawalSupportReader {
        let id = WithdrawalSupportBundledSource.bundledWeChatID
        let market = regionalConfiguration?.market
        let reviewed = composition.reviewed != nil
        // The wallet scope's namespace is this session's storage service (`walletCommerceScope`); the reader still
        // compares it with the live scope on every read and copy.
        let namespace = storageScope?.service
        return makeWithdrawalSupportReader(source: {
            WithdrawalSupportBundledSource.configuration(namespace: namespace, market: market, weChatID: id, now: Date())
        }, approval: { WithdrawalSupportBundledSource.approval(reviewed: reviewed, market: market, weChatID: id) })
    }
}
