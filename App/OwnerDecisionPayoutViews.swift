// WP-10 (owner decisions D-05): the read-only payout receiver and merchant payout-account screens. Renamed from
// ClubPayoutReceiverView / MerchantPayoutAccountView when WP-01/05 (wp-0105) landed fuller screens under those names.
import SwiftUI

/// Club personal receiver. Status and unbind are native. Bind needs a `wx.login` code,
/// so this screen tells the owner to bind in the mini-program and sends no bind request.
struct OwnerDecisionClubPayoutReceiverView: View {
    @Environment(\.locale) private var locale
    let clubID: Int?
    var session: AppSession?
    var fixture: OwnerDecisionScreenFixture?

    @State private var phase: OwnerDecisionScreenPhase = .loading
    @State private var status: OwnerDecisionReceiverStatus?
    @State private var message: String?
    @State private var confirming = false

    var body: some View {
        List {
            switch shown {
            case .loading:
                CYSkeleton().accessibilityIdentifier("club.receiver.loading")
            case .empty:
                Text(verbatim: t("还没有俱乐部", "No club yet"))
                    .accessibilityIdentifier("club.receiver.empty")
            case .error:
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: message ?? t("个人收款状态暂不可用", "Payout receiver status is unavailable"))
                    Button(t("重试", "Try again")) { Task { await load() } }
                        .frame(minHeight: 44)
                }.accessibilityIdentifier("club.receiver.error")
            case .ready:
                if let status {
                    Section {
                        LabeledContent(t("状态", "Status")) {
                            Text(verbatim: stateLabel(status.page))
                        }
                        if !status.payoutText.isEmpty {
                            Text(verbatim: t(status.payoutText, "Starts when the platform turns payouts on"))
                        }
                        if !status.pauseText.isEmpty {
                            Text(verbatim: t("绑定尚未确认", "Binding is not confirmed yet"))
                        }
                    }
                    Section {
                        Text(verbatim: t(OwnerDecisionReceiverCopy.bindHandoff, "Finish binding in the mini-program"))
                        Text(verbatim: OwnerDecisionReceiverCopy.miniProgramPath)
                            .font(.footnote)
                            .textSelection(.enabled)
                        Button(t("复制路径", "Copy path")) { copy(OwnerDecisionReceiverCopy.miniProgramPath) }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("club.receiver.copyPath")
                    } header: {
                        Text(verbatim: t("绑定", "Binding"))
                    }
                    if status.canUnbind {
                        Button(t(OwnerDecisionReceiverCopy.unbindConfirm, "Unbind"), role: .destructive) {
                            confirming = true
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("club.receiver.unbind")
                    }
                    if let message, !message.isEmpty {
                        Text(verbatim: message).accessibilityIdentifier("club.receiver.notice")
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: t("个人收款", "Personal receiver")))
        .accessibilityIdentifier("club.receiver.screen")
        .confirmationDialog(Text(verbatim: t(OwnerDecisionReceiverCopy.unbindTitle, "Unbind personal payout?")),
                            isPresented: $confirming, titleVisibility: .visible) {
            Button(t(OwnerDecisionReceiverCopy.unbindConfirm, "Unbind"), role: .destructive) {
                Task { await unbind() }
            }
            Button(t("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(verbatim: t(OwnerDecisionReceiverCopy.unbindConsequence, "New club income pauses until you bind again."))
        }
        .task { await load() }
    }

    private var shown: OwnerDecisionScreenPhase { fixture?.phase ?? phase }

    private func t(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    private func stateLabel(_ page: OwnerDecisionReceiverStatus.Page) -> String {
        switch page {
        case .unbound: return t("未绑定", "Not bound")
        case .paused: return t("已暂停", "Paused")
        case .bound: return t("已绑定", "Bound")
        }
    }

    private func load() async {
        if fixture != nil {
            status = fixture?.status
            message = fixture?.message
            return
        }
        guard let clubID, clubID > 0 else { phase = .empty; return }
        phase = .loading
        guard let client = makeClient() else {
            phase = .error
            message = t("个人收款状态暂不可用", "Payout receiver status is unavailable")
            return
        }
        if let value = await client.status(clubID: clubID) {
            status = value
            phase = .ready
        } else {
            phase = .error
            message = t("个人收款状态暂不可用", "Payout receiver status is unavailable")
        }
    }

    private func unbind() async {
        guard fixture == nil, let clubID, let client = makeClient() else {
            message = t("解除未发送", "Unbind was not sent")
            return
        }
        let result = await client.unbind(clubID: clubID)
        if result == .acknowledged {
            message = t(OwnerDecisionReceiverCopy.unbindDone, "Unbound")
            await load()
        } else if result == .notSent {
            message = t("解除未发送", "Unbind was not sent")
            phase = .ready
        } else {
            message = t("解除失败，请重试", "Couldn’t unbind. Try again.")
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

enum OwnerDecisionScreenPhase: Equatable { case loading, empty, error, ready }

struct OwnerDecisionScreenFixture {
    var phase: OwnerDecisionScreenPhase
    var status: OwnerDecisionReceiverStatus? = nil
    var account: OwnerDecisionMerchantAccount? = nil
    var message: String? = nil
    var denied = false
}

struct ClubPayoutReceiverEntry: View {
    let clubID: Int?
    @EnvironmentObject private var session: AppSession
    var body: some View { OwnerDecisionClubPayoutReceiverView(clubID: clubID, session: session) }
}

/// Merchant payout account. Read-only, and only when access/me grants finance read.
/// There is no edit and no cash-out action. A signing link, when the server sends one, can be copied.
struct OwnerDecisionMerchantPayoutAccountView: View {
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
    var body: some View { OwnerDecisionMerchantPayoutAccountView(session: session, permissions: permissions) }
}
