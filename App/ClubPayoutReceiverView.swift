import SwiftUI

/// Club personal receiver. Status and unbind are native. Bind needs a `wx.login` code,
/// so this screen tells the owner to bind in the mini-program and sends no bind request.
struct ClubPayoutReceiverView: View {
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
    var body: some View { ClubPayoutReceiverView(clubID: clubID, session: session) }
}
