import SwiftUI

/// What the trailing control of a club card shows. Only `.join` and `.apply` render the single pill;
/// every other state is a status chip (or nothing), so a card never carries two pills.
enum CYClubCardAction: Equatable {
    case join, apply, pending, joined, owner, none

    fileprivate var isJoinPill: Bool { self == .join || self == .apply }
    fileprivate var isSettledMembership: Bool { self == .joined || self == .pending }
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

/// Shared id for the player's avatar moving from the join pill into the member strip on the same card.
private enum CYClubCardPlayer {
    static let geometryID = "me-avatar"
    static func seed(_ clubSeed: String) -> String { "\(clubSeed)-me" }
}

/// Overlapped member avatars (5 + "+N") with the member count. An unknown count is an em dash, never 0.
struct CYClubMemberStrip: View {
    let seed: String
    let count: Int?
    var avatarSize: CGFloat = 28
    /// Player face already counted in `count` once it has landed. Nil keeps the strip unchanged.
    var playerSeed: String? = nil
    var playerNamespace: Namespace.ID? = nil
    /// Empty leading slot of `avatarSize`, so the strip does not grow again when the avatar lands.
    var holdsPlayerSlot: Bool = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    private var known: Int? { count.flatMap { $0 >= 0 ? $0 : nil } }
    private var text: String { known.map { ClubMemberCountLocalization.text($0, locale: locale) } ?? "—" }
    private var includePlayer: Bool { holdsPlayerSlot || playerSeed != nil }
    /// Face count while the slot is reserved but the rolled number has not caught up yet.
    private var layoutTotal: Int? {
        guard let known else { return nil }
        guard holdsPlayerSlot, known < Int.max else { return known }
        return known + 1
    }

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            memberFaces
            Text(verbatim: text)
                .cyText(.meta).monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .foregroundStyle(palette.textSecondary)
                // One line, never hyphen-wrapped ("12 / mem- / bers"): the parent stacks the strip above a wide pill instead.
                .lineLimit(1).minimumScaleFactor(0.8)
                .fixedSize(horizontal: true, vertical: true)
                .animation(reduceMotion ? CYMotion.reduced : CYMotion.entrance, value: text)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var memberFaces: some View {
        if includePlayer {
            HStack(spacing: -avatarSize * 0.32) {
                leadingPlayer.zIndex(10)
                if let total = layoutTotal {
                    let others = max(total - 1, 0)
                    let visible = min(others, 4)
                    if visible > 0 {
                        E3AvatarStack(seeds: (0..<visible).map { "\(seed)-m\($0)" }, extra: total > 5 ? total - 5 : nil, size: avatarSize)
                            .accessibilityHidden(true)
                    }
                }
            }
        } else if let n = known, n > 0 {
            E3AvatarStack(seeds: (0..<min(n, 5)).map { "\(seed)-m\($0)" }, extra: n > 5 ? n - 5 : nil, size: avatarSize)
                .accessibilityHidden(true)
        } else {
            // MP: components/cy/club-card/index.wxml:15 (cards/members.svg, .cc__members 26rpx)
            MPAsset.FeatureIcon.members.resizable().scaledToFit().frame(width: 13, height: 13).accessibilityHidden(true)
        }
    }

    @ViewBuilder private var leadingPlayer: some View {
        if let playerSeed, !holdsPlayerSlot {
            E3Avatar(seed: playerSeed, size: avatarSize)
                .overlay(Circle().strokeBorder(CYColor.bgPage, lineWidth: 2))
                .accessibilityHidden(true)
                .modifier(CYClubPlayerFlight(namespace: reduceMotion ? nil : playerNamespace))
        } else {
            Color.clear.frame(width: avatarSize, height: avatarSize).accessibilityHidden(true)
        }
    }
}

/// Destination half of the pill → strip flight. No namespace means the face just fades in (Reduce Motion).
private struct CYClubPlayerFlight: ViewModifier {
    let namespace: Namespace.ID?
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: CYClubCardPlayer.geometryID, in: namespace, isSource: false)
        } else {
            content.transition(.opacity)
        }
    }
}

/// The one trailing control of a club card.
struct CYClubCardTrailing: View {
    let action: CYClubCardAction
    let onJoin: () -> Void
    var joinIdentifier: String? = nil
    /// Drives the in-place morph of the Join / Apply pill (dots, then green check). Idle for every static card.
    var morph: CYMorphState = .idle
    /// Keeps the pill's width and height after it becomes a shorter chip, so the footer does not jump.
    var anchor: CYClubCardAction? = nil
    /// Player face overlaid on the pill (not in its layout) so the width stays the idle label.
    var playerSeed: String? = nil
    var playerNamespace: Namespace.ID? = nil
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        ZStack(alignment: .trailing) {
            widthAnchor
            Group {
                switch action {
                case .join:
                    pill("club.action.join", identifier: joinIdentifier ?? "club.card.join")
                case .apply:
                    pill("club.action.apply", identifier: joinIdentifier ?? "club.card.apply")
                case .pending: CYStatusChip("club.membership.pending", tone: .warning, systemImage: "clock")
                case .joined: CYStatusChip("club.membership.joined", tone: .success, systemImage: "checkmark")
                case .owner: CYStatusChip("club.role.creator", tone: .neutral, systemImage: "crown")
                case .none: EmptyView()
                }
            }
            .transition(.opacity)
        }
        .animation(CYMotion.reduced, value: action)
    }

    @ViewBuilder private var widthAnchor: some View {
        if let anchor, anchor.isJoinPill {
            let title: LocalizedStringKey = anchor == .apply ? "club.action.apply" : "club.action.join"
            CYMorphButton(title, state: .idle, fullWidth: false, compact: true, action: {})
                .hidden()
                .accessibilityHidden(true)
        }
    }

    private func pill(_ title: LocalizedStringKey, identifier: String) -> some View {
        CYMorphButton(title, state: morph, fullWidth: false, compact: true, action: onJoin)
            .identifier(identifier)
            .overlay(alignment: .leading) { playerSource }
    }

    @ViewBuilder private var playerSource: some View {
        if let playerSeed, let playerNamespace, !reduceMotion {
            E3Avatar(seed: playerSeed, size: 24)
                .matchedGeometryEffect(id: CYClubCardPlayer.geometryID, in: playerNamespace, isSource: true)
                .transition(.identity)
                .padding(.leading, CYSpacing.sm)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Join / Apply → Joined / Pending on one card. The avatar flies into the strip already in the footer,
/// the count rolls, then the pill settles into the existing status chip. Nothing here joins or writes.
private struct CYClubCardMotion<Content: View>: View {
    let action: CYClubCardAction
    var morph: CYMorphState = .idle
    let seed: String
    let count: Int?
    var avatarSize: CGFloat = 28
    let onJoin: () -> Void
    var joinIdentifier: String? = nil
    @ViewBuilder var content: (CYClubMemberStrip, CYClubCardTrailing) -> Content

    private struct Key: Equatable {
        let seed: String
        let action: CYClubCardAction
    }
    private enum Flight { case idle, traveling, landed }

    @Namespace private var playerSpace
    @QuestifyReduceMotion private var reduceMotion
    @State private var armed = false
    @State private var shown: CYClubCardAction?
    @State private var flight: Flight = .idle
    @State private var anchor: CYClubCardAction?
    @State private var baseline: Int?
    @State private var bumped = false
    @State private var generation = 0
    @State private var task: Task<Void, Never>?

    private var visualAction: CYClubCardAction { shown ?? action }
    private var displayedCount: Int? {
        guard bumped, let baseline, baseline >= 0 else { return count }
        return baseline < Int.max ? baseline + 1 : baseline
    }
    private var trailingMorph: CYMorphState {
        guard visualAction.isJoinPill else { return .idle }
        return flight == .idle ? morph : .done
    }

    var body: some View {
        content(strip, trailing)
            .onChange(of: Key(seed: seed, action: action), initial: true) { previous, next in
                follow(previous, next)
            }
            .onChange(of: count) { _, new in
                guard bumped, new != baseline else { return }
                bumped = false
                baseline = nil
            }
    }

    private var strip: CYClubMemberStrip {
        let traveling = flight == .traveling && !reduceMotion
        let player = flight == .idle ? nil : CYClubCardPlayer.seed(seed)
        return CYClubMemberStrip(
            seed: seed, count: displayedCount, avatarSize: avatarSize,
            playerSeed: player, playerNamespace: (flight == .landed && !reduceMotion) ? playerSpace : nil,
            holdsPlayerSlot: traveling)
    }

    private var trailing: CYClubCardTrailing {
        CYClubCardTrailing(
            action: visualAction, onJoin: onJoin, joinIdentifier: joinIdentifier, morph: trailingMorph, anchor: anchor,
            playerSeed: (flight == .traveling && !reduceMotion) ? CYClubCardPlayer.seed(seed) : nil,
            playerNamespace: playerSpace)
    }

    private func follow(_ previous: Key, _ next: Key) {
        guard armed else {
            armed = true
            shown = next.action
            return
        }
        guard previous.seed == next.seed else { reset(to: next.action); return }
        let from = previous.action, to = next.action
        guard from != to else { return }
        guard from.isJoinPill, to.isSettledMembership else {
            if flight == .landed, to.isSettledMembership { shown = to; return }
            reset(to: to)
            return
        }
        let canBump = count.map { $0 >= 0 && $0 < Int.max } ?? false
        generation &+= 1
        let token = generation
        baseline = count
        anchor = from
        shown = from
        task?.cancel()
        if reduceMotion {
            withAnimation(CYMotion.reduced) {
                flight = .landed
                bumped = canBump
                shown = to
            }
            return
        }
        withAnimation(CYMotion.entrance) { flight = .traveling }
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, token == generation else { return }
            withAnimation(CYMotion.entrance) {
                flight = .landed
                bumped = canBump
            }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, token == generation else { return }
            withAnimation(CYMotion.reduced) { shown = to }
        }
    }

    private func reset(to action: CYClubCardAction) {
        generation &+= 1
        task?.cancel()
        flight = .idle
        bumped = false
        baseline = nil
        anchor = nil
        shown = action
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
    var morph: CYMorphState = .idle
    let onOpen: () -> Void
    let onJoin: () -> Void
    var identifier: String? = nil
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Button(action: onOpen) {
                CYImageCard(verbatim: name.trimmingCharacters(in: .whitespacesAndNewlines), fallback: "club.untitled",
                            meta: place, imageURL: coverURL, aspectRatio: prominent ? nil : 2.0, style: .hero)
                    .cachingFeedImage()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier ?? "club.card")
            footer
        }
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        CYClubCardMotion(action: action, morph: morph, seed: seed, count: memberCount, onJoin: onJoin,
                         joinIdentifier: identifier.map { $0 + ".join" }) { strip, trailing in
            // Side by side while the strip and the pill both fit on one line; otherwise (wide pill, AX sizes) the pill drops below.
            ViewThatFits(in: .horizontal) {
                if !typeSize.isAccessibilitySize {
                    HStack(alignment: .center, spacing: CYSpacing.sm) { strip; Spacer(minLength: CYSpacing.sm); trailing }
                }
                VStack(alignment: .leading, spacing: CYSpacing.sm) { strip; trailing }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CYSpacing.xs)
        }
    }
}

/// "Your clubs" row card: 56pt logo, name, member count, status chip. The whole row opens the club.
struct CYClubRowCard: View {
    let name: String
    let logoURL: URL?
    let memberCount: Int?
    let seed: String
    let action: CYClubCardAction
    var morph: CYMorphState = .idle
    let onOpen: () -> Void
    var identifier: String? = nil
    /// Chips (level, tags, 主题 N) drawn inside the card under the member strip (polish-d-r1), not as a loose line below it.
    var tags: AnyView? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onOpen) {
            CYClubCardMotion(action: action, morph: morph, seed: seed, count: memberCount, avatarSize: 20, onJoin: onOpen) { strip, trailing in
                let info = VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Group {
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("club.untitled") }
                        else { Text(verbatim: name) }
                    }
                    // skill-r2 `Club/List Card` (`210:8452`): name t-head 17, thumbnail 72 r12.
                    .cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    strip
                    if let tags { tags.padding(.top, CYSpacing.xxs) }
                }
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
                .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "club.rowCard")
    }

    private var logo: some View {
        ZStack {
            CYIMCoverArt(seed: seed + name)
            if let logoURL {
                PlayerFeedRemoteImage(url: logoURL, maxPixel: 168, placeholder: { Color.clear }, failure: { Color.clear })
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}
