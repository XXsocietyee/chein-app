import SwiftUI

/// Message-center coop-invite strip. The mini-program shows received/sent cooperation invites above the
/// conversation list; each card opens the existing invite detail where accept / decline / reply live.
/// This view only reads (`CooperationReading.inbox`) and never reports a write.
/// Embedded under the inbox's own title, so it does not call `cyHeroScreen` (that would clear the parent bar).
@MainActor struct IMCoopInviteStripView: View {
    let reader: any CooperationReading
    @State private var direction: CooperationDirection = .received
    @State private var phase: Phase = .loading
    @State private var stagger = CYStaggerGate()
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
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

    private var stripTitle: some View {
        Text(verbatim: copy("合作邀请", "Cooperation invites"))
            .font(CYTypography.sectionTitle)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var directionPicker: some View {
        Picker(copy("邀请方向", "Invite direction"), selection: $direction) {
            Text(verbatim: copy("收到", "Received")).tag(CooperationDirection.received)
            Text(verbatim: copy("发出", "Sent")).tag(CooperationDirection.sent)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("im.coopStrip.direction")
    }

    @ViewBuilder private var header: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.sm) { stripTitle; directionPicker }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                stripTitle
                Spacer(minLength: CYSpacing.sm)
                directionPicker.frame(maxWidth: 220)
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
            failureState(issue)
        case .ready(let cards) where cards.isEmpty:
            CYStateLayout(
                kind: .inbox,
                title: Text(verbatim: direction == .received ? copy("还没有收到合作邀请", "No invites received yet")
                                                             : copy("还没有发出的合作邀请", "No invites sent yet")),
                artSize: 88
            )
            .accessibilityIdentifier("im.coopStrip.empty")
        case .ready(let cards):
            if typeSize.isAccessibilitySize {
                LazyVStack(alignment: .leading, spacing: CYSpacing.md) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in cardLink(card, index: index) }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in cardLink(card, index: index) }
                    }
                }
            }
        }
    }

    private func cardLink(_ card: IMCoopInviteCard, index: Int) -> some View {
        NavigationLink {
            CooperationInviteDetailView(key: card.key, reader: reader)
        } label: { cardView(card) }
        .buttonStyle(CYPressScaleStyle())
        .accessibilityIdentifier("im.coopStrip.card.\(card.id)")
        .cyStaggeredAppear(index: index, gate: stagger)
    }

    private func cardView(_ card: IMCoopInviteCard) -> some View {
        cardChrome(card) {
            cardCopy(card)
        }
    }

    private func cardChrome<Content: View>(_ card: IMCoopInviteCard, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(3.0 / 2.0, contentMode: .fit)
                .overlay { cover(card) }
                .clipped()
            content()
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(IMInviteCardWidth(accessibility: typeSize.isAccessibilitySize))
        .background(palette.bgElevated, in: shape)
        .overlay { shape.strokeBorder(palette.borderSubtle, lineWidth: 1).allowsHitTesting(false) }
        .clipShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: inviteLabel(card)))
        .accessibilityHint(Text(verbatim: copy("打开邀请详情", "Opens invite details")))
    }

    private func cardCopy(_ card: IMCoopInviteCard) -> some View {
        let topic = card.topicName ?? copy("未命名主题", "Untitled project")
        let partner = (card.key.direction == .received ? copy("来自 ", "From ") : copy("发给 ", "To "))
            + (card.partnerName ?? copy("合作方", "Partner"))
        let lines = typeSize.isAccessibilitySize ? 8 : 2
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYStatusChip(verbatim: card.statusText(chinese: chinese), tone: chipTone(card.tone), systemImage: chipSymbol(card.tone))
            Text(verbatim: topic)
                .font(CYTypography.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: partner)
                .font(CYTypography.meta)
                .foregroundStyle(palette.textTertiary)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
            if let line = card.message ?? card.termsLine(chinese: chinese) {
                Text(verbatim: line)
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(lines)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if card.awaitsMyAnswer {
                Label(copy("点开处理", "Open to respond"), systemImage: "arrow.right.circle")
                    .font(CYTypography.caption.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inviteLabel(_ card: IMCoopInviteCard) -> String {
        let who = card.partnerName ?? card.topicName ?? "—"
        return copy("合作邀请：", "Cooperation invite: ") + who + "，" + card.statusText(chinese: chinese)
    }

    @ViewBuilder private func cover(_ card: IMCoopInviteCard) -> some View {
        if let raw = card.coverURL, let url = URL(string: raw), url.scheme?.lowercased() == "https" {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else { CYCoverArt(seed: card.id, symbol: "person.2") }
            }
        } else {
            CYCoverArt(seed: card.id, symbol: "person.2")
        }
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

    private func failureState(_ issue: CooperationIssue) -> some View {
        let retry: (title: String, action: () -> Void)? = issue.canRetry
            ? (title: copy("重试", "Retry"), action: { Task { await load() } })
            : nil
        return CYStateLayout(
            kind: issue.canRetry ? .failure : .offline,
            title: Text(verbatim: failureText(issue)),
            primaryVerbatim: retry,
            primaryStyle: .secondary,
            primaryIdentifier: issue.canRetry ? "im.coopStrip.retry" : nil,
            artSize: 88
        )
        .accessibilityIdentifier("im.coopStrip.error")
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

/// Shelf width grows with accessibility sizes. Kept out of the card expression so the type checker stays bounded.
private struct IMInviteCardWidth: ViewModifier {
    let accessibility: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if accessibility {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content.frame(width: 280, alignment: .leading)
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
#Preview("Coop invite strip · player") {
    NavigationStack {
        IMCoopInviteStripView(reader: CooperationFixtureReader(scenario: .content))
            .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    .themeDomain(.player)
}
#Preview("Coop invite strip · merchant") {
    NavigationStack {
        IMCoopInviteStripView(reader: CooperationFixtureReader(scenario: .empty))
            .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    .themeDomain(.merchant)
}
#Preview("Coop invite strip · failure") {
    NavigationStack {
        IMCoopInviteStripView(reader: CooperationFixtureReader(scenario: .failure))
            .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    .themeDomain(.player)
}
#endif
