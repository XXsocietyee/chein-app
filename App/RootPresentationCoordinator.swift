import Foundation
import Observation

/// One owner for what the root may present or replay right now. Two jobs:
/// 1. Presentation order: the consent gate goes first; the native-entry sheet and the Roam area picker wait for it.
/// 2. chein:// intents: one pending link (last wins) that waits for the tabs, sign-in and any open Passport sheet,
///    then replays once; it expires after five minutes instead of being dropped silently.
@MainActor @Observable final class RootPresentationCoordinator {
    static let linkLifetime: TimeInterval = 5 * 60
    /// True while the usage-consent gate sheet is on screen.
    var consentActive = false
    private(set) var blockingSheets: Set<String> = []
    private(set) var pendingLink: CheinDeepLink?
    /// Last referral, gift, or seat landing. Recording it does not claim, pay, or start a run.
    private(set) var pendingJourney: JourneyLinkIntake?
    private var pendingSince: Date?
    /// mp-nav r3: a link or notification page that lands as a push on the 首页 stack, consumed once by that stack.
    var homeLanding: HomeLanding?

    var hasBlockingSheet: Bool { !blockingSheets.isEmpty }
    /// Native entry and the area picker never overlap the consent gate (consent first, the rest queue).
    var allowsSecondaryRootSheet: Bool { !consentActive }

    /// A tab-level sheet (Settings, Cooperation, ticket wallet) reports itself so a replayed link never lands behind it.
    func setSheet(_ id: String, open: Bool) {
        if open { blockingSheets.insert(id) } else { blockingSheets.remove(id) }
    }

    func enqueue(_ link: CheinDeepLink, now: Date = Date()) { pendingLink = link; pendingSince = now }

    func noteJourney(_ intake: JourneyLinkIntake) { pendingJourney = intake }

    func clear() { pendingLink = nil; pendingSince = nil; pendingJourney = nil }

    /// Returns the pending link once when it can be shown, and drops it when older than `linkLifetime`.
    func takeLink(now: Date = Date(), tabsVisible: Bool, signedIn: Bool) -> CheinDeepLink? {
        guard let link = pendingLink, let since = pendingSince else { return nil }
        if now.timeIntervalSince(since) > Self.linkLifetime { clear(); return nil }
        guard tabsVisible, !consentActive, !hasBlockingSheet else { return nil }
        if case .ticket = link, !signedIn { return nil }
        clear()
        return link
    }
}

/// mp-nav r3: the MP opens a shared / subscribe-message page as the first page with a home button. Native: the same
/// page pushed on the 首页 stack, so the system back button returns to 首页 (no root sheet with a close button).
struct HomeLanding: Equatable {
    enum Target: Equatable {
        case page(MPParityRoute)
        case topic(Int)
        /// A tab-root MP page (MP switchTab): select the tab, push nothing.
        case tab(RootTab)
    }
    let id = UUID()
    let target: Target
}
