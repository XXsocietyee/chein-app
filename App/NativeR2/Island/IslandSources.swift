import SwiftUI

/// Foreground push → island. The kind comes from the payload's page path; the text is the notification's own
/// title and body (already localized by the sender). Tap / the primary action routes like a banner tap.
@MainActor enum IslandPushPresenter {
    static func present(title: String, body: String, payload: [String: String], route: @escaping @MainActor () -> Void) {
        let page = payload.values.first?.lowercased() ?? ""
        let kind = kind(forPage: page)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading: IslandText = trimmedTitle.isEmpty
            ? (trimmedBody.isEmpty ? .key("island.push.fallback") : .verbatim(trimmedBody))
            : .verbatim(trimmedTitle)
        let detail: IslandText? = trimmedTitle.isEmpty || trimmedBody.isEmpty ? nil : .verbatim(trimmedBody)
        let routable = !page.isEmpty
        var actions: [IslandAction] = []
        switch kind {
        case .invitation where routable:
            // Accept / decline live on the invite page (they need its confirmation); the island opens it.
            actions = [IslandAction(title: .key("island.action.view"), prominent: true, handler: route),
                       IslandAction(title: .key("island.action.later")) {}]
        case .message where routable:
            actions = [IslandAction(title: .key("island.action.reply"), systemImage: "arrowshape.turn.up.left.fill",
                                    prominent: true, handler: route)]
        default:
            if routable { actions = [IslandAction(title: .key("island.action.open"), prominent: true, handler: route)] }
        }
        IslandCenter.shared.show(IslandItem(kind: kind, title: heading, subtitle: detail, actions: actions,
                                            open: routable ? route : nil,
                                            lifetime: kind == .invitation ? .seconds(8) : .seconds(4),
                                            startsExpanded: kind == .invitation))
    }

    /// Page-path classification (mini-program paths, see `MiniProgramPageLink`).
    static func kind(forPage page: String) -> IslandKind {
        if page.contains("invite") || page.contains("invitation") || page.contains("team/join") { return .invitation }
        if page.contains("/im/") || page.contains("channel") || page.contains("chat") || page.contains("message") { return .message }
        if page.contains("checkin") || page.contains("stamp") { return .arrival }
        return .status(.info)
    }
}

/// Game hint ladder → island. When a hint level's content is revealed, the island shows it with "下一条提示",
/// which reopens the ladder (the next level still needs its own confirmation there; no request from here).
struct IslandHintBridge: ViewModifier {
    let model: PlayHelpLadderModel?
    let openLadder: () -> Void

    private var revealed: [Int] {
        model?.rows.compactMap { $0.content == nil ? nil : $0.level } ?? []
    }

    func body(content: Content) -> some View {
        content.onChange(of: revealed) { old, new in
            guard IslandCenter.isEnabled, let model, let level = Set(new).subtracting(old).max(),
                  let row = model.row(level) else { return }
            let isImage = (row.contentType ?? row.type) == "IMAGE"
            let text: IslandText = isImage ? .key("island.hint.image") : .verbatim(row.content ?? "")
            let hasNext = model.rows.contains { $0.level > level && $0.content == nil && $0.tappable }
            var actions: [IslandAction] = []
            if hasNext {
                actions.append(IslandAction(title: .key("island.hint.next"), systemImage: "lightbulb", prominent: true) { openLadder() })
            }
            IslandCenter.shared.show(IslandItem(kind: .hint, title: .key(row.typeLabelKey), subtitle: text,
                                                actions: actions, open: openLadder, lifetime: .seconds(6),
                                                dedupeKey: "hint", startsExpanded: true))
        }
    }
}

extension View {
    /// NativeGameShell: hint revealed → island.
    func islandHints(_ model: PlayHelpLadderModel?, openLadder: @escaping () -> Void) -> some View {
        modifier(IslandHintBridge(model: model, openLadder: openLadder))
    }
}

/// Story audio → `.media` island (play / pause from the island) and the story-audio Live Activity.
/// Reads only `PlatformAudioPlayback.state`; play / pause call the same `toggle()` as the mini player.
@MainActor enum IslandMediaBridge {
    static let dedupeKey = "story.audio"

    static func stateChanged(_ state: PlatformAudioState, title: String?, toggle: @escaping @MainActor () -> Void) {
        guard IslandCenter.isEnabled else { return }
        let name: IslandText = title.flatMap { $0.isEmpty ? nil : IslandText.verbatim($0) } ?? IslandText.key("island.media.title")
        switch state {
        case .playing, .paused:
            let playing = state == .playing
            let since = playing ? Date() : nil
            let toggleAction = IslandAction(title: .key(playing ? "island.media.pause" : "island.media.play"),
                                            keepsIsland: true, handler: toggle)
            let item = IslandItem(kind: .media, title: name,
                                  subtitle: .key(playing ? "island.media.playing" : "island.media.paused"),
                                  actions: [toggleAction], lifetime: .seconds(4),
                                  media: IslandMedia(isPlaying: playing, playingSince: since), dedupeKey: dedupeKey)
            if playing {
                IslandCenter.shared.show(item)
            } else {
                IslandCenter.shared.update(dedupeKey: dedupeKey) { current in
                    current.subtitle = item.subtitle; current.actions = item.actions; current.media = item.media
                }
            }
            QuestLiveActivityCenter.shared.storyAudio(title: title, isPlaying: playing)
        case .ended, .failed, .disposed:
            IslandCenter.shared.withdraw(dedupeKey: dedupeKey)
            QuestLiveActivityCenter.shared.endStoryAudio()
        case .gated, .idle, .loading:
            break
        }
    }
}

/// Unread counts that an existing read already returned (IM unread total, channel unread summary) → `.message`
/// island when they go up while the app is open. The first value after launch only primes the baseline.
@MainActor enum IslandUnreadBridge {
    private static var lastTotals: [String: Int] = [:]

    static func observe(source: String, total: Int?, title: (Int) -> IslandText, open: @escaping @MainActor () -> Void) {
        guard let total, total >= 0 else { return }
        defer { lastTotals[source] = total }
        guard IslandCenter.isEnabled, let previous = lastTotals[source], total > previous else { return }
        let added = total - previous
        IslandCenter.shared.show(IslandItem(kind: .message,
                                            title: title(added),
                                            actions: [IslandAction(title: .key("island.action.open"), prominent: true, handler: open)],
                                            open: open, dedupeKey: "unread." + source))
    }
}

/// Cooperation invites from the message-center strip's existing `api/coop/list` read → `.invitation` island
/// for invites awaiting my answer that this device has not announced yet. First read primes silently.
@MainActor enum IslandInviteBridge {
    private static let storageKey = "island.announcedCoopInvites"

    static func received(_ cards: [IMCoopInviteCard], open: @escaping @MainActor (IMCoopInviteCard) -> Void) {
        let pending = cards.filter { $0.awaitsMyAnswer && $0.key.direction == .received }
        let ids = Set(pending.map(\.id))
        let defaults = UserDefaults.standard
        guard let stored = defaults.array(forKey: storageKey) as? [String] else {
            defaults.set(Array(ids), forKey: storageKey)
            return
        }
        let known = Set(stored)
        let fresh = pending.filter { !known.contains($0.id) }
        defaults.set(Array(known.union(ids).suffix(200)), forKey: storageKey)
        guard IslandCenter.isEnabled, let first = fresh.first else { return }
        let title: IslandText = fresh.count == 1
            ? (first.topicName.map { IslandText.verbatim($0) } ?? IslandText.key("island.invite.coop.title"))
            : .localized("island.invite.coop.many \(fresh.count)")
        let subtitle: IslandText? = fresh.count == 1 ? first.partnerName.map { IslandText.verbatim($0) } : nil
        IslandCenter.shared.show(IslandItem(kind: .invitation, title: title, subtitle: subtitle,
                                            actions: [IslandAction(title: .key("island.action.view"), prominent: true) { open(first) },
                                                      IslandAction(title: .key("island.action.later")) {}],
                                            open: { open(first) }, lifetime: .seconds(8),
                                            dedupeKey: "invite.coop", startsExpanded: true))
    }
}

/// Reviewed mini-program page paths the island opens through `MPNotificationTapRouter.open(pagePath:)`.
enum IslandRoutes {
    static let messageCenter = "subpackageB/pages/im/list/index"
    static func coopInvite(id: Int) -> String { "pages/coop/invite-detail/index?inviteId=\(id)&box=received" }
}
