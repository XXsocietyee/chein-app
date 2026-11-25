import SwiftUI

/// Message-center coop-invite strip. The mini-program shows received/sent cooperation invites above the
/// conversation list; each card opens the existing invite detail where accept / decline / reply live.
/// This view only reads (`CooperationReading.inbox`) and never reports a write.
/// Embedded under the inbox's own title, so it does not call `cyHeroScreen` (that would clear the parent bar).
@MainActor struct IMCoopInviteStripView: View {
    let reader: any CooperationReading
    @State private var pickedDirection: CooperationDirection = .received
    /// R7-PC-D8-1: the message center's 收件箱 / 发件箱 tab fixes the direction and hides the strip's own picker.
    @Environment(\.imCoopInviteDirection) private var fixedDirection
    private var direction: CooperationDirection { fixedDirection ?? pickedDirection }
    @State private var phase: Phase = .loading
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    enum Phase {
        case loading
        case ready([IMCoopInviteCard])
        case failed(CooperationIssue)
    }

    private var chinese: Bool { ChannelCopy.isChinese(locale) }
    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    var body: some View {
        if reader.isAuthenticated && reader.isConfigured {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
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
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Text(verbatim: copy("合作邀请", "Cooperation invites"))
                .cyText(.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if direction == .received { IMInviteReminderToggle() }
            Spacer(minLength: CYSpacing.sm)
            if fixedDirection == nil {
                Picker(copy("邀请方向", "Invite direction"), selection: $pickedDirection) {
                    Text(verbatim: copy("收到", "Received")).tag(CooperationDirection.received)
                    Text(verbatim: copy("发出", "Sent")).tag(CooperationDirection.sent)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                .accessibilityIdentifier("im.coopStrip.direction")
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYSkeleton()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: copy("正在加载合作邀请", "Loading invites")))
                .accessibilityIdentifier("im.coopStrip.loading")
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let issue):
            failureRow(issue)
        case .ready(let cards) where cards.isEmpty:
            CYStateLayout(
                kind: .inbox,
                title: Text(verbatim: direction == .received ? copy("还没有收到合作邀请", "No invites received yet")
                                                             : copy("还没有发出的邀请", "No invites sent yet")), // MP im/list/index.wxml:106
                artSize: 88
            )
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

    private func failureRow(_ issue: CooperationIssue) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYStateLayout(kind: issue.canRetry ? .failure : .offline, title: Text(verbatim: failureText(issue)), artSize: 88)
            if issue.canRetry {
                CYPillButton(verbatim: copy("重试", "Retry"), style: .secondary, fullWidth: false) { Task { await load() } }
                    .accessibilityIdentifier("im.coopStrip.retry")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("im.coopStrip.error")
    }

    private func cardView(_ card: IMCoopInviteCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cover(card)
            cardCopy(card)
        }
        .frame(width: 280, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: inviteLabel(card)))
        .accessibilityHint(Text(verbatim: copy("打开邀请详情", "Opens invite details")))
    }

    private func cover(_ card: IMCoopInviteCard) -> some View {
        CYCoverArt(seed: card.id, symbol: "person.2")
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private func cardCopy(_ card: IMCoopInviteCard) -> some View {
        let topic = card.topicName ?? copy("未命名主题", "Untitled project")
        let partner = (card.key.direction == .received ? copy("来自 ", "From ") : copy("发给 ", "To "))
            + (card.partnerName ?? copy("合作方", "Partner"))
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(verbatim: card.statusText(chinese: chinese), tone: chipTone(card.tone), systemImage: chipSymbol(card.tone))
            Text(verbatim: topic)
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: partner)
                .cyText(.meta)
                .foregroundStyle(palette.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let line = card.message ?? card.termsLine(chinese: chinese) {
                Text(verbatim: line)
                    .cyText(.bodyCompact)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if card.awaitsMyAnswer {
                Label(copy("点开处理", "Open to respond"), systemImage: "arrow.right.circle")
                    .cyText(.caption, weight: .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inviteLabel(_ card: IMCoopInviteCard) -> String {
        let who = card.partnerName ?? card.topicName ?? "—"
        return copy("合作邀请：", "Cooperation invite: ") + who + "，" + card.statusText(chinese: chinese)
    }

    private func chipTone(_ tone: IMCoopInviteCard.Tone) -> CYStatusTone {
        switch tone {
        case .pending: return .warning
        case .accepted: return .success
        case .rejected: return .danger
        case .muted: return .neutral
        }
    }

    private func chipSymbol(_ tone: IMCoopInviteCard.Tone) -> String {
        switch tone {
        case .pending: return "clock"
        case .accepted: return "checkmark"
        case .rejected: return "xmark"
        case .muted: return "minus"
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
            // Production reader: `api/coop/list` only. Fixtures still project `inbox.invitations`.
            let section: CooperationSection<CooperationInvites>
            if let reader = reader as? CooperationSessionReader {
                section = .content(try await reader.inviteList())
            } else {
                section = try await reader.inbox(direction: requested).invitations
            }
            guard !Task.isCancelled, requested == direction else { return }
            switch section {
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
private struct IMCoopInviteDirectionKey: EnvironmentKey {
    static var defaultValue: CooperationDirection? { nil }
}
extension EnvironmentValues {
    var imCoopInviteDirection: CooperationDirection? {
        get { self[IMCoopInviteDirectionKey.self] }
        set { self[IMCoopInviteDirectionKey.self] = newValue }
    }
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
