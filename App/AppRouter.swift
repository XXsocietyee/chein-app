import Observation

/// Strangler router. Owns only the Home tab's push path for now; every other NavigationStack stays local.
@MainActor @Observable final class AppRouter {
    var homePath: [AppRoute] = []

    func pushHome(_ destination: HomeFeedDestination) { homePath.append(AppRoute(destination)) }
    func resetHome() { homePath = [] }
}
