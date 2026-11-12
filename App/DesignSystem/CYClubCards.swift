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
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette

    private var known: Int? { count.flatMap { $0 >= 0 ? $0 : nil } }
    private var text: String { known.map { ClubMemberCountLocalization.text($0, locale: locale) } ?? "—" }

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if let n = known, n > 0 {
                E3AvatarStack(seeds: (0..<min(n, 5)).map { "\(seed)-m\($0)" }, extra: n > 5 ? n - 5 : nil, size: avatarSize)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "person.2").foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            }
            Text(verbatim: text)
                .font(CYTypography.meta).monospacedDigit()
                .foregroundStyle(palette.textSecondary)
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

    var body: some View {
        switch action {
        case .join:
            CYPillButton("club.action.join", fullWidth: false, compact: true, action: onJoin)
                .accessibilityIdentifier(joinIdentifier ?? "club.card.join")
        case .apply:
            CYPillButton("club.action.apply", fullWidth: false, compact: true, action: onJoin)
                .accessibilityIdentifier(joinIdentifier ?? "club.card.apply")
        case .pending: CYStatusChip("club.membership.pending", tone: .warning, systemImage: "clock")
        case .joined: CYStatusChip("club.membership.joined", tone: .success, systemImage: "checkmark")
        case .owner: CYStatusChip("club.role.creator", tone: .info, systemImage: "crown")
        case .none: EmptyView()
        }
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
    @Environment(\.dynamicTypeSize) private var typeSize

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
        let trailing = CYClubCardTrailing(action: action, onJoin: onJoin, joinIdentifier: identifier.map { $0 + ".join" })
        let strip = CYClubMemberStrip(seed: seed, count: memberCount)
        // Side by side while the strip and the pill both fit on one line; otherwise (wide pill, AX sizes) the pill drops below.
        return ViewThatFits(in: .horizontal) {
            if !typeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: CYSpacing.sm) { strip; Spacer(minLength: CYSpacing.sm); trailing }
            }
            VStack(alignment: .leading, spacing: CYSpacing.sm) { strip; trailing }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            let info = VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Group {
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("club.untitled") }
                    else { Text(verbatim: name) }
                }
                .font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                CYClubMemberStrip(seed: seed, count: memberCount, avatarSize: 20)
            }
            let trailing = CYClubCardTrailing(action: action, onJoin: onOpen)
            // Logo | info | pill on one line when it fits; otherwise the pill moves under the info (always at AX sizes).
            ViewThatFits(in: .horizontal) {
                if !typeSize.isAccessibilitySize {
                    HStack(alignment: .center, spacing: CYSpacing.md) { logo; info; Spacer(minLength: CYSpacing.sm); trailing }
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        HStack(alignment: .center, spacing: CYSpacing.md) { logo; info }
                        trailing
                    }
                }
                VStack(alignment: .leading, spacing: CYSpacing.md) { logo; info; trailing }
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
