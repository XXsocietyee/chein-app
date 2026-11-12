import Network
import Observation
import SwiftUI

/// Path status for the offline capsule. Presentation only: no request is gated on it, and an unknown path is "online".
@MainActor @Observable final class NetworkReachability {
    private(set) var isOffline = false
    @ObservationIgnored private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status == .unsatisfied
            Task { @MainActor in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "chein.reachability"))
        self.monitor = monitor
    }

    func stop() { monitor?.cancel(); monitor = nil }
}

/// "Offline: showing saved content" capsule. It is an overlay, so showing or hiding it never moves the screen under it.
struct OfflineCapsule: View {
    var body: some View {
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

extension View {
    /// Shown on the four tab roots, under the navigation bar. Never intercepts touches.
    func offlineCapsule(_ reachability: NetworkReachability) -> some View {
        overlay(alignment: .top) {
            if reachability.isOffline {
                OfflineCapsule()
                    .padding(.top, 52)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .accessibilitySortPriority(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reachability.isOffline)
    }
}
