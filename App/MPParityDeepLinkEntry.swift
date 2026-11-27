import SwiftUI
import UserNotifications

// P-A deep-link router. Universal links, chein:// links and notification taps that name a mini-program page with a
// native screen land on `MPParityRoute`. Kept out of AppSession.swift and AppCompositionRoot.swift (size ratchet).

extension MPParityRoute {
    /// The parsed link is already reviewed in Core; the route keeps the page's own query reading.
    init?(link: MiniProgramPageLink) {
        self.init(miniProgramPath: link.page, query: link.query)
    }
}

extension HomeLanding {
    /// Page links with a native player screen land on 首页; errors, invitations, door and merchant links keep the entry sheet.
    init?(intent: NativeEntryIntent) {
        switch intent {
        case .miniProgramPage(let link):
            if let tab = Self.tabRoots[link.page] { self.init(target: .tab(tab)); return }
            // Merchant pages (out of the player app) keep the entry sheet and its discard confirmation.
            guard !link.page.contains("merchant"), let route = MPParityRoute(link: link) else { return nil }
            self.init(target: .page(route))
        case .content(let content):
            guard content.kind == .topic else { return nil }
            self.init(target: .topic(content.id))
        default:
            return nil
        }
    }

    /// MP `app.json` tabBar pages: a link to one switches tabs, as MP `switchTab` does.
    static let tabRoots: [String: RootTab] = [
        "pages/index/index": .home,
        "pages/roam/index": .roam,
        "pages/template/index": .publish,
        "pages/talent/list/index": .club,
        "pages/member/index/index": .mine
    ]
}

/// Presented by `NativeEntryLandingView` for links that do not land on 首页 (see `HomeLanding`). The root sheet sits outside the player root environment, so the parity
/// bindings are installed here again; every screen keeps its own sign-in, capability and money gating.
@MainActor struct MPParityPageEntry: View {
    let link: MiniProgramPageLink
    @ObservedObject var session: AppSession
    let goHome: () -> Void

    var body: some View {
        Group {
            if let route = MPParityRoute(link: link) {
                MPParityDestination(route: route)
                    .environmentObject(session)
                    .modifier(MPParityPassEnvironment(session: session))
            } else {
                NativeRouteErrorView(failure: .unsupported, goHome: { session.dismissNativeEntry(); goHome() })
            }
        }
        .id(session.sessionRevision)
        .accessibilityIdentifier("mp.deepLink.page")
    }
}

extension AppSession {
    /// `chein://mp/<page>?<query>`. True when the URL was a chein mp link and was handled (valid or not).
    func receiveMiniProgramPageURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == CheinDeepLink.scheme, url.host?.lowercased() == "mp" else { return false }
        if let link = MiniProgramPageLink(cheinURL: url) { receiveNativeIntent(.miniProgramPage(link)) }
        else { receiveNativeIntent(.routeError(.unsupported)) }
        return true
    }

    /// Universal links. A reviewed path on a verified origin (`nativeEntryLinkPolicy`, empty until the domains are
    /// approved) routes like a chein link; anything else stays with the WeChat callback drivers as before.
    func receiveUniversalLink(_ activity: NSUserActivity) {
        if let url = activity.webpageURL, let intent = nativeEntryLinkPolicy.parse(url) { receiveNativeIntent(intent); return }
        receiveWeChatUserActivity(activity)
    }

    /// A referral, gift or seat landing opens the journey landing page. Opening it claims, pays or starts nothing.
    func openJourneyLanding(_ intake: JourneyLinkIntake) {
        receiveNativeIntent(.miniProgramPage(MiniProgramPageLink(journey: intake)))
    }
}

/// Notification taps. Only a source page path in the payload routes (`PushTapRouter` rejects schemes and hosts).
/// Foreground presentation (native r2 M4): with `nativeR2.island` on, a notification that arrives while the app is open
/// shows as an island (invitation / message / status by its page path) instead of the system banner; tapping it routes
/// exactly like a banner tap. Flag off: the system banner (design P1 G-027; it used to be dropped).
@MainActor final class MPNotificationTapRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = MPNotificationTapRouter()
    /// The mini-program subscribe-message field that carries the page path.
    nonisolated static let routeKeys = ["page"]
    /// mp-nav r3: actions that do not bring the app forward (City 稍后, a custom dismiss) never move the player.
    /// Before, 稍后 queued the `page` route, so the next launch jumped to 漫游 without the player asking.
    nonisolated static let nonOpeningActions: Set<String> = [CityNotifications.laterAction, UNNotificationDismissActionIdentifier]
    /// Posted on the main actor when an IM / channel notification arrives in the foreground (G-021).
    nonisolated static let foregroundMessageArrived = Notification.Name("chein.im.foregroundMessageArrived")
    private weak var session: AppSession?
    private var pending: NativeEntryIntent?

    /// Called from `QuestifyApp.init` so a tap that launches the app is delivered here (Apple requires the delegate
    /// before launch finishes). The intent waits until the root installs the session.
    func attach() {
        let center = UNUserNotificationCenter.current()
        if center.delegate !== self { center.delegate = self }
    }

    func install(_ session: AppSession) {
        attach()
        self.session = session
        if let pending { self.pending = nil; session.receiveNativeIntent(pending) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        guard !Self.nonOpeningActions.contains(response.actionIdentifier) else { completionHandler(); return }
        let userInfo = response.notification.request.content.userInfo
        var payload: [String: String] = [:]
        for key in Self.routeKeys { if let value = userInfo[key] as? String { payload[key] = value } }
        completionHandler()
        Task { @MainActor in MPNotificationTapRouter.shared.route(payload) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        var payload: [String: String] = [:]
        for key in Self.routeKeys { if let value = content.userInfo[key] as? String { payload[key] = value } }
        let title = content.title, body = content.body, routePayload = payload
        Task { @MainActor in
            // G-021: an IM / channel push while the app is open tells an open conversation to read its newer page
            // (the same guarded read as pull to refresh; nothing reads when no conversation is on screen).
            if IslandPushPresenter.kind(forPage: routePayload.values.first?.lowercased() ?? "") == .message {
                NotificationCenter.default.post(name: MPNotificationTapRouter.foregroundMessageArrived, object: nil)
            }
            // G-027 (design P1): flag off, the system banner shows instead of the push being dropped while open.
            guard IslandCenter.isEnabled else { completionHandler([.banner, .list, .sound, .badge]); return }
            IslandPushPresenter.present(title: title, body: body, payload: routePayload) { MPNotificationTapRouter.shared.route(routePayload) }
            // Kept in Notification Center; the island replaces the banner and sound while the app is open.
            completionHandler([.list, .badge])
        }
    }

    /// Opens a reviewed mini-program page path the same way a notification tap does (island actions use it).
    func open(pagePath: String) { route([Self.routeKeys[0]: pagePath]) }

    private func route(_ payload: [String: String]) {
        guard let intent = PushTapRouter(routeKeys: Self.routeKeys).intent(userInfo: payload) else { return }
        if let session { session.receiveNativeIntent(intent) } else { pending = intent }
    }
}
