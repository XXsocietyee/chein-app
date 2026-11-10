import SwiftUI

/// Message-center coop-invite strip. The mini-program shows received/sent cooperation invites above the
/// conversation list; each card opens the existing invite detail where accept / decline / reply live.
/// This view only reads (`CooperationReading.inbox`) and never reports a write.
@MainActor struct IMCoopInviteStripView: View {
    let reader: any CooperationReading
    @State private var direction: CooperationDirection = .received
    @State private var phase: Phase = .loading
    @Environment(\.locale) private var locale

    enum Phase {
        case loading
        case ready([IMCoopInviteCard])
        case failed(CooperationIssue)
    }

    private var chinese: Bool { ChannelCopy.isChinese(locale) }
    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    var body: some View {
        if reader.isAuthenticated && reader.isConfigured {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                header
                content
            }
            .padding(.vertical, CYSpacing.sm)
            .task(id: direction) { await load() }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("im.coopStrip")
        }
    }

    private var header: some View {
        HStack(spacing: CYSpacing.md) {
            Text(verbatim: copy("合作邀请", "Cooperation invites"))
                .font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Picker(copy("邀请方向", "Invite direction"), selection: $direction) {
                Text(verbatim: copy("收到", "Received")).tag(CooperationDirection.received)
                Text(verbatim: copy("发出", "Sent")).tag(CooperationDirection.sent)
            }
            .pickerStyle(.segmented).frame(maxWidth: 180)
            .accessibilityIdentifier("im.coopStrip.direction")
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYSkeleton()
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: copy("正在加载合作邀请", "Loading invites")))
                .accessibilityIdentifier("im.coopStrip.loading")
        case .failed(let issue):
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(CYColor.warningText).accessibilityHidden(true)
                Text(verbatim: failureText(issue)).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                Spacer(minLength: 0)
                if issue.canRetry {
                    CYPillButton(verbatim: copy("重试", "Retry"), style: .secondary, fullWidth: false) { Task { await load() } }
                        .accessibilityIdentifier("im.coopStrip.retry")
                }
            }.accessibilityElement(children: .combine).accessibilityIdentifier("im.coopStrip.error")
        case .ready(let cards) where cards.isEmpty:
            Text(verbatim: direction == .received ? copy("还没有收到合作邀请", "No invites received yet")
                                                   : copy("还没有发出的合作邀请", "No invites sent yet"))
                .font(CYTypography.bodyCompact).foregroundStyle(CYColor.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("im.coopStrip.empty")
        case .ready(let cards):
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                    ForEach(cards) { card in
                        NavigationLink {
                            CooperationInviteDetailView(key: card.key, reader: reader)
                        } label: { cardView(card) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("im.coopStrip.card.\(card.id)")
                    }
                }
            }
        }
    }

    private func cardView(_ card: IMCoopInviteCard) -> some View {
        CYCard(variant: .surface, radius: CYRadius.md, padding: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip(verbatim: card.statusText(chinese: chinese), tone: chipTone(card.tone))
                    Text(verbatim: (card.key.direction == .received ? copy("来自 ", "From ") : copy("发给 ", "To "))
                         + (card.partnerName ?? copy("合作方", "Partner")))
                        .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary).lineLimit(1)
                }
                Text(verbatim: card.topicName ?? copy("未命名主题", "Untitled project"))
                    .font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                if let line = card.message ?? card.termsLine(chinese: chinese) {
                    Text(verbatim: line).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary).lineLimit(2)
                }
                if card.awaitsMyAnswer {
                    Label(copy("点开处理", "Open to respond"), systemImage: "arrow.right.circle")
                        .font(CYTypography.caption.weight(.semibold)).foregroundStyle(CYColor.accentText)
                }
            }
            .frame(width: 240, alignment: .leading)
            .frame(minHeight: 44, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: copy("合作邀请：", "Cooperation invite: ")
            + (card.partnerName ?? card.topicName ?? "") + "，" + card.statusText(chinese: chinese)))
        .accessibilityHint(Text(verbatim: copy("打开邀请详情", "Opens invite details")))
    }

    private func chipTone(_ tone: IMCoopInviteCard.Tone) -> CYStatusTone {
        switch tone {
        case .pending: return .warning
        case .accepted: return .success
        case .rejected: return .danger
        case .muted: return .neutral
        }
    }

    private func failureText(_ issue: CooperationIssue) -> String {
        switch issue {
        case .forbidden: return copy("暂无权限查看合作邀请", "You can't view cooperation invites")
        case .login: return copy("登录后查看合作邀请", "Sign in to see cooperation invites")
        case .unavailable, .unconfigured: return copy("合作邀请暂不可用", "Cooperation invites are unavailable")
        default: return copy("合作邀请加载失败", "Couldn't load cooperation invites")
        }
    }

    private func load() async {
        let requested = direction
        phase = .loading
        do {
            let inbox = try await reader.inbox(direction: requested)
            guard !Task.isCancelled, requested == direction else { return }
            switch inbox.invitations {
            case .content(let invites): phase = .ready(IMCoopInviteCard.cards(invites, direction: requested))
            case .failure(let issue): phase = .failed(issue)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, requested == direction else { return }
            phase = .failed(CooperationIssue(error))
        }
    }
}

/// Composition hook: the root puts a strip factory in the environment; the message center renders it above the list.
private struct IMCoopInviteStripKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}
extension EnvironmentValues {
    var imCoopInviteStrip: (@MainActor () -> AnyView)? {
        get { self[IMCoopInviteStripKey.self] }
        set { self[IMCoopInviteStripKey.self] = newValue }
    }
}

#if DEBUG
#Preview("Coop invite strip") {
    NavigationStack {
        List { IMCoopInviteStripView(reader: CooperationFixtureReader(scenario: .content)) }
    }
}
#Preview("Coop invite strip – empty") {
    NavigationStack {
        List { IMCoopInviteStripView(reader: CooperationFixtureReader(scenario: .empty)) }
    }
}
#Preview("Coop invite strip – failure") {
    NavigationStack {
        List { IMCoopInviteStripView(reader: CooperationFixtureReader(scenario: .failure)) }
    }
}
#endif
