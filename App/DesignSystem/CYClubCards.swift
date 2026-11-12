import SwiftUI

/// What the trailing control of a club card shows. Only `.join` and `.apply` render the single pill;
/// every other state is a status chip (or nothing), so a card never carries two pills.
enum CYClubCardAction: Equatable {
    case join, apply, pending, joined, owner, none
}

extension ClubRecord {
    /// Card state from the same flags the detail panel reads. Tapping the pill runs the host's gated action
    /// (the club home joins in place through the action coordinator; other hosts open the detail); this never grants a join.
    func cardAction(viewerIsMerchant: Bool) -> CYClubCardAction {
        if isOwner { return .owner }
        if isJoined { return .joined }
        if viewerIsMerchant { return .none }
        if joinPending { return .pending }
        return (needsApproval && joinPolicySupported) ? .apply : .join
    }
}

/// Overlapped member avatars (5 + "+N") with the member count. An unknown count is an em dash, never 0.
struct CYClubMemberStrip: View {
    let seed: String
    let count: Int?
    var avatarSize: CGFloat = 28
    /// Set together while a join avatar is flying into this strip.
    var meSeed: String? = nil
    var meNamespace: Namespace.ID? = nil
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    private var known: Int? { count.flatMap { $0 >= 0 ? $0 : nil } }
    private var text: String { known.map { ClubMemberCountLocalization.text($0, locale: locale) } ?? "—" }

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if let meSeed, let meNamespace {
                E3Avatar(seed: meSeed, size: avatarSize)
                    .matchedGeometryEffect(id: "club-me-\(seed)", in: meNamespace)
                    .accessibilityHidden(true)
            }
            if let n = known, n > 0 {
                E3AvatarStack(seeds: (0..<min(n, 5)).map { "\(seed)-m\($0)" }, extra: n > 5 ? n - 5 : nil, size: avatarSize)
                    .accessibilityHidden(true)
            } else if meSeed == nil {
                Image(systemName: "person.2").foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            }
            Text(verbatim: text)
                .font(CYTypography.meta).monospacedDigit()
                .foregroundStyle(palette.textSecondary)
                .contentTransition(.numericText())
                // One line, never hyphen-wrapped ("12 / mem- / bers"): the parent stacks the strip above a wide pill instead.
                .lineLimit(1).minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: true)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }
}

/// The one trailing control of a club card.
struct CYClubCardTrailing: View {
    let action: CYClubCardAction
    let onJoin: () -> Void
    var joinIdentifier: String? = nil
    /// Drives the in-place morph of the Join / Apply pill (dots, then green check). Idle for every static card.
    var morph: CYMorphState = .idle

    var body: some View {
        Group {
            switch action {
            case .join:
                CYMorphButton("club.action.join", state: morph, fullWidth: false, compact: true, action: onJoin)
                    .identifier(joinIdentifier ?? "club.card.join")
            case .apply:
                CYMorphButton("club.action.apply", state: morph, fullWidth: false, compact: true, action: onJoin)
                    .identifier(joinIdentifier ?? "club.card.apply")
            case .pending: CYStatusChip("club.membership.pending", tone: .warning, systemImage: "clock")
            case .joined: CYStatusChip("club.membership.joined", tone: .success, systemImage: "checkmark")
            case .owner: CYStatusChip("club.role.creator", tone: .info, systemImage: "crown")
            case .none: EmptyView()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(CYMotion.reduced, value: action)
    }
}

/// Discover / directory card: big cover with the name over a scrim, then one footer line
/// (avatar stack + count on the left, the single Join pill or status chip on the right).
struct CYClubPhotoCard: View {
    let name: String
    let place: String?
    let coverURL: URL?
    let memberCount: Int?
    let seed: String
    var prominent = false
    let action: CYClubCardAction
    let onOpen: () -> Void
    let onJoin: () -> Void
    var identifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Button(action: onOpen) {
                CYImageCard(verbatim: name.trimmingCharacters(in: .whitespacesAndNewlines), fallback: "club.untitled",
                            meta: place, imageURL: coverURL, aspectRatio: prominent ? nil : 2.0, style: .hero)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier ?? "club.card")
            footer
        }
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        CYClubCardJoinLine(action: action, seed: seed, memberCount: memberCount, onJoin: onJoin,
                           joinIdentifier: identifier.map { $0 + ".join" })
            .padding(.horizontal, CYSpacing.xs)
    }
}

/// "Your clubs" row card: 56pt logo, name, member count, status chip. The whole row opens the club.
struct CYClubRowCard: View {
    let name: String
    let logoURL: URL?
    let memberCount: Int?
    let seed: String
    let action: CYClubCardAction
    let onOpen: () -> Void
    var identifier: String? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onOpen) {
            let title = Group {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("club.untitled") }
                else { Text(verbatim: name) }
            }
            .font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .center, spacing: CYSpacing.md) { logo; title }
                CYClubCardJoinLine(action: action, seed: seed, memberCount: memberCount, onJoin: onOpen, avatarSize: 20)
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 0.5))
            .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "club.rowCard")
    }

    private var logo: some View {
        ZStack {
            CYIMCoverArt(seed: seed + name)
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Strip and pill share one namespace. A join/apply -> joined/pending change flies the player's avatar
/// into the strip and rolls the count, then the pill becomes the status chip. Already-joined cards
/// do not invent an extra member. Reduce Motion crossfades.
private struct CYClubCardJoinLine: View {
    let action: CYClubCardAction
    let seed: String
    let memberCount: Int?
    let onJoin: () -> Void
    var joinIdentifier: String? = nil
    var avatarSize: CGFloat = 28
    var morph: CYMorphState = .idle

    @Namespace private var flight
    @State private var sourceVisible = false
    @State private var arrived = false
    @State private var showChip = false
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var inbound: Bool { action == .joined || action == .pending }

    var body: some View {
        let shownCount = memberCount.map { $0 + ((arrived && action == .joined) ? 1 : 0) }
        let strip = CYClubMemberStrip(
            seed: seed, count: shownCount, avatarSize: avatarSize,
            meSeed: arrived ? "\(seed)-me" : nil, meNamespace: flight)
        ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: CYSpacing.sm) {
                    strip
                    Spacer(minLength: CYSpacing.sm)
                    trailing
                }
            }
            VStack(alignment: .leading, spacing: CYSpacing.sm) { strip; trailing }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { if inbound { showChip = true } }
        .onChange(of: action) { old, new in
            let fromPill = old == .join || old == .apply
            let toChip = new == .joined || new == .pending
            guard fromPill && toChip else {
                if new == .join || new == .apply { sourceVisible = false; arrived = false; showChip = false }
                return
            }
            if reduceMotion {
                arrived = new == .joined
                showChip = true
                return
            }
            sourceVisible = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(30))
                withAnimation(CYMotion.entrance) { sourceVisible = false; arrived = new == .joined }
                try? await Task.sleep(for: .milliseconds(480))
                withAnimation(CYMotion.reduced) { showChip = true }
            }
        }
    }

    @ViewBuilder private var trailing: some View {
        if showChip {
            CYClubCardTrailing(action: action, onJoin: onJoin, joinIdentifier: joinIdentifier, morph: morph)
        } else {
            CYClubCardTrailing(
                action: inbound ? (action == .pending ? .apply : .join) : action,
                onJoin: onJoin, joinIdentifier: joinIdentifier, morph: morph)
                .overlay(alignment: .trailing) {
                    if sourceVisible {
                        E3Avatar(seed: "\(seed)-me", size: max(16, avatarSize * 0.75))
                            .matchedGeometryEffect(id: "club-me-\(seed)", in: flight)
                            .padding(.trailing, 4)
                    }
                }
        }
    }
}
