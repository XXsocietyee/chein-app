import Network
import Observation
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Global connectivity state aligned with mini-program `utils/network-status.js`.
/// Presentation + retry/queue notification only: no read or write is gated behind it blindly.
@MainActor @Observable final class NetworkReachability {
    private(set) var isOffline = false
    private(set) var lastConnectedAt: Date? = Date()
    private(set) var stillOfflineAfterRecheck = false
    @ObservationIgnored private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status != .unsatisfied
            Task { @MainActor [weak self] in
                self?.applyConnectivity(online: online)
            }
        }
        monitor.start(queue: DispatchQueue(label: "chein.reachability"))
        self.monitor = monitor
    }

    func stop() { monitor?.cancel(); monitor = nil }

    @discardableResult
    func recheck() -> Bool {
        if let monitor {
            let online = monitor.currentPath.status != .unsatisfied
            applyConnectivity(online: online)
            stillOfflineAfterRecheck = !online
            return online
        }
        stillOfflineAfterRecheck = isOffline
        return !isOffline
    }

    func applyConnectivity(online: Bool) {
        let nextOffline = !online
        SharedNetworkReachabilityState.shared.setOnline(online)
        if online {
            lastConnectedAt = Date()
            stillOfflineAfterRecheck = false
        }
        guard isOffline != nextOffline else { return } // Deduplicate identical emissions (`network-status.js`).
        isOffline = nextOffline
    }

    #if DEBUG
    func setSimulatedOffline(_ offline: Bool) {
        applyConnectivity(online: !offline)
    }
    #endif
}

/// "Offline: showing saved content" banner backed by `CYStatusOfflineBanner`.
struct OfflineCapsule: View {
    var cachedAt: Date? = nil
    var stillOffline: Bool = false
    var onRetry: (() -> Void)? = nil

    var body: some View {
        if let onRetry {
            CYStatusOfflineBanner(
                messageKey: "cy.state.offline.banner.title",
                cachedAt: cachedAt,
                stillOffline: stillOffline,
                onRetry: onRetry
            )
            .accessibilityIdentifier("offline.capsule")
        } else {
            Label("offline.capsule", systemImage: "wifi.slash")
                .font(CYTypography.meta.weight(.semibold))
                .foregroundStyle(CYColor.textPrimary)
                .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(CYColor.borderStrong, lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("offline.capsule"))
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("offline.capsule")
        }
    }
}

extension View {
    /// Shown on the root shells under the navigation bar.
    func offlineCapsule(_ reachability: NetworkReachability) -> some View {
        overlay(alignment: .top) {
            if reachability.isOffline {
                OfflineCapsule(
                    cachedAt: reachability.lastConnectedAt,
                    stillOffline: reachability.stillOfflineAfterRecheck,
                    onRetry: { _ = reachability.recheck() }
                )
                .padding(.horizontal, CYSpacing.md)
                .padding(.top, CYSpacing.xs)
                .transition(.opacity)
                .accessibilitySortPriority(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reachability.isOffline)
    }
}
