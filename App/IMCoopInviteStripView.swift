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
    @Environment(\.dynamicTypeSize) private var typeSize

    enum Phase {
        case loading
        case ready([IMCoopInviteCard])
        case failed(CooperationIssue)
    }

    private var chinese: Bool { ChannelCopy.isChinese(locale) }
    private func copy(_ zh: String, _ en: String) -> String { ChannelCopy.text(zh, en, locale: locale) }

    var body: some View {
        if reader.isAuthenticated && reader.isConfigured {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .padding(.vertical, 8)
            .task(id: direction) { await load() }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("im.coopStrip")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: copy("合作邀请", "Cooperation invites"))
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if direction == .received { IMInviteReminderToggle() }
            Spacer(minLength: 8)
            if fixedDirection == nil {
                Picker(copy("邀请方向", "Invite direction"), selection: $pickedDirection) {
                    Text(verbatim: copy("收到", "Received")).tag(CooperationDirection.received)
                    Text(verbatim: copy("发出", "Sent")).tag(CooperationDirection.sent)
                }
                .cyAdaptiveSegmented()
                .frame(maxWidth: 220)
                .accessibilityIdentifier("im.coopStrip.direction")
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: copy("正在加载合作邀请", "Loading invites")))
                .accessibilityIdentifier("im.coopStrip.loading")
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let issue):
            failureRow(issue)
        case .ready(let cards) where cards.isEmpty:
            Label(direction == .received ? copy("还没有收到合作邀请", "No invites received yet")
                                         : copy("还没有发出的邀请", "No invites sent yet"), // MP im/list/index.wxml:106
                  systemImage: "tray")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("im.coopStrip.empty")
        case .ready(let cards):
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(cards) { card in
                        NavigationLink {
                            CooperationInviteDetailView(key: card.key, reader: reader)
                        } label: { cardView(card) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("im.coopStrip.card.\(card.id)")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func failureRow(_ issue: CooperationIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(failureText(issue), systemImage: issue.canRetry ? "exclamationmark.triangle" : "wifi.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if issue.canRetry {
                Button { Task { await load() } } label: { Text(verbatim: copy("重试", "Retry")) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("im.coopStrip.retry")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("im.coopStrip.error")
    }

    /// System `GroupBox` (closest stock control to the MP invite card); no generated cover art.
    private func cardView(_ card: IMCoopInviteCard) -> some View {
        GroupBox {
            cardCopy(card)
        }
        // G-042 (design P1): sized to the strip, not a fixed 280 pt. Three quarters of the width shows the next card
        // peeking (as the App Store's shelves do); at accessibility sizes one card takes the full width.
        .containerRelativeFrame(.horizontal, count: typeSize.isAccessibilitySize ? 1 : 4,
                                span: typeSize.isAccessibilitySize ? 1 : 3, spacing: 12, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: inviteLabel(card)))
        .accessibilityHint(Text(verbatim: copy("打开邀请详情", "Opens invite details")))
    }

    private func cardCopy(_ card: IMCoopInviteCard) -> some View {
        let topic = card.topicName ?? copy("未命名主题", "Untitled project")
        let partner = (card.key.direction == .received ? copy("来自 ", "From ") : copy("发给 ", "To "))
            + (card.partnerName ?? copy("合作方", "Partner"))
        return VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(verbatim: card.statusText(chinese: chinese))
            } icon: {
                Image(systemName: chipSymbol(card.tone)).foregroundStyle(chipColor(card.tone))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Text(verbatim: topic)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: partner)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let line = card.message ?? card.termsLine(chinese: chinese) {
                Text(verbatim: LocaleDisplay.yuanAmounts(in: line, locale: locale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if card.awaitsMyAnswer {
                Label(copy("点开处理", "Open to respond"), systemImage: "arrow.right.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inviteLabel(_ card: IMCoopInviteCard) -> String {
        let who = card.partnerName ?? card.topicName ?? "—"
        return copy("合作邀请：", "Cooperation invite: ") + who + "，" + card.statusText(chinese: chinese)
    }

    private func chipColor(_ tone: IMCoopInviteCard.Tone) -> Color {
        switch tone {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .muted: return .secondary
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
            case .content(let invites):
                let cards = IMCoopInviteCard.cards(invites, direction: requested)
                phase = .ready(cards)
                // Native r2 M4: a received invite this device has not announced yet → invitation island
                // (View opens the same invite detail where accept / decline live).
                if requested == .received {
                    IslandInviteBridge.received(cards) { card in
                        MPNotificationTapRouter.shared.open(pagePath: IslandRoutes.coopInvite(id: card.key.id))
                    }
                }
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
