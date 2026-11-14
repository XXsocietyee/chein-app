import SwiftUI

/// Merchant payout account. Read-only, and only when access/me grants finance read.
/// There is no edit and no withdraw. A signing link, when the server sends one, can be copied.
struct MerchantPayoutAccountView: View {
    @Environment(\.locale) private var locale
    var session: AppSession?
    var permissions: [String]
    var fixture: OwnerDecisionScreenFixture?

    @State private var phase: OwnerDecisionScreenPhase = .loading
    @State private var account: OwnerDecisionMerchantAccount?
    @State private var message: String?
    @State private var allowed = false

    var body: some View {
        List {
            if !allowed && fixture?.denied != false && (fixture?.denied == true || (!allowed && fixture == nil && phase != .loading)) {
                Text(verbatim: t("没有财务查看权限", "Finance read is not granted"))
                    .accessibilityIdentifier("merchant.payoutAccount.denied")
            } else {
                switch shown {
                case .loading:
                    CYSkeleton().accessibilityIdentifier("merchant.payoutAccount.loading")
                case .empty:
                    Text(verbatim: t("未开通", "Not set up"))
                        .accessibilityIdentifier("merchant.payoutAccount.empty")
                case .error:
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text(verbatim: message ?? t("收款账户加载失败", "Couldn’t load the payout account"))
                        Button(t("重试", "Try again")) { Task { await load() } }.frame(minHeight: 44)
                    }.accessibilityIdentifier("merchant.payoutAccount.error")
                case .ready:
                    if let account {
                        if account.phase == .unavailable {
                            Text(verbatim: t("收款账户暂不可用", "Payout account is unavailable"))
                                .accessibilityIdentifier("merchant.payoutAccount.unavailable")
                        } else if account.phase == .none {
                            Text(verbatim: t("未开通", "Not set up"))
                                .accessibilityIdentifier("merchant.payoutAccount.empty")
                        } else {
                            LabeledContent(t("状态", "Status")) { Text(verbatim: account.stateText.isEmpty ? "—" : account.stateText) }
                            if !account.stateDesc.isEmpty { Text(verbatim: account.stateDesc) }
                            LabeledContent(t("商户号", "Merchant account")) { Text(verbatim: account.maskedAccount.isEmpty ? "—" : account.maskedAccount) }
                            if let sign = account.signURL {
                                Text(verbatim: sign).font(.footnote).textSelection(.enabled)
                                Button(t("复制签约链接", "Copy signing link")) { copy(sign) }
                                    .frame(minHeight: 44)
                                    .accessibilityIdentifier("merchant.payoutAccount.copy")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: t("收款账户", "Payout account")))
        .accessibilityIdentifier("merchant.payoutAccount.screen")
        .task { await load() }
    }

    private var shown: OwnerDecisionScreenPhase { fixture?.phase ?? phase }

    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private func load() async {
        if let fixture {
            allowed = !fixture.denied
            account = fixture.account
            message = fixture.message
            return
        }
        phase = .loading
        guard OwnerDecisionMerchantAccount.allowsFinance(permissions) else {
            allowed = false
            phase = .ready
            return
        }
        allowed = true
        guard let client = makeClient() else {
            phase = .error
            message = t("收款账户加载失败", "Couldn’t load the payout account")
            return
        }
        if let value = await client.account() {
            account = value
            phase = value.phase == .none ? .empty : .ready
        } else {
            phase = .error
            message = t("收款账户加载失败", "Couldn’t load the payout account")
        }
    }

    private func makeClient() -> OwnerDecisionPayoutClient? {
        guard let session, let configuration = session.regionalConfiguration?.apiConfiguration,
              let token = session.token, AuthRequestBuilder.isValidToken(token) else { return nil }
        let host = configuration.baseURL.host
        return OwnerDecisionPayoutClient(configuration: configuration, transport: session.composition.makeTransport(),
                                          token: token, payoutOpen: ReviewedAreaSwitch.payout(host: host),
                                          merchantWritesOpen: ReviewedAreaSwitch.merchantWrites(host: host))
    }

    private func copy(_ text: String) {
        UIPasteboard.general.setItems([["public.utf8-plain-text": text]],
                                      options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
    }
}

struct MerchantPayoutAccountEntry: View {
    let permissions: [String]
    @EnvironmentObject private var session: AppSession
    var body: some View { MerchantPayoutAccountView(session: session, permissions: permissions) }
}
