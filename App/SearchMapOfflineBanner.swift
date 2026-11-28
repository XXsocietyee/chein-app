import SwiftUI
import Network
import Observation

/// Network reachability only. It never reads location, never sends a request, and never
/// changes the chosen manual area; the explorer decides whether a reconnect refreshes.
@MainActor @Observable final class SearchMapConnectivity {
    private(set) var isOnline: Bool
    private let monitor: NWPathMonitor?
    init(forcedOnline: Bool? = nil) {
        if let forcedOnline {
            isOnline = forcedOnline; monitor = nil
        } else {
            isOnline = true
            let monitor = NWPathMonitor(); self.monitor = monitor
            monitor.pathUpdateHandler = { [weak self] path in
                let online = path.status == .satisfied
                Task { @MainActor [weak self] in self?.isOnline = online }
            }
            monitor.start(queue: DispatchQueue(label: "questify.connectivity.searchMap"))
        }
    }
    deinit { monitor?.cancel() }
    /// The current path, read synchronously for the 重试连接 button.
    func recheck() -> Bool {
        if let monitor { isOnline = monitor.currentPath.status == .satisfied }
        return isOnline
    }
    #if DEBUG
    /// Synthetic fixture control only; real builds follow NWPathMonitor.
    func setFixtureOnline(_ online: Bool) { guard monitor == nil else { return }; isOnline = online }
    #endif
}

/// A host or DEBUG fixture may inject a source; otherwise the explorer owns one monitor.
private struct SearchMapConnectivityKey: EnvironmentKey { static let defaultValue: SearchMapConnectivity? = nil }
extension EnvironmentValues {
    var searchMapConnectivity: SearchMapConnectivity? {
        get { self[SearchMapConnectivityKey.self] }
        set { self[SearchMapConnectivityKey.self] = newValue }
    }
}

/// Mini-program offline bar: 当前离线 + cache time + 重试连接.
struct SearchMapOfflineBannerView: View {
    let state: SearchMapOfflineBanner
    let stillOffline: Bool
    let retry: () -> Void
    var body: some View {
        if let key = state.key {
            GroupBox {
              VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(LocalizedStringKey(key)).font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "wifi.slash").foregroundStyle(.orange)
                }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("searchMap.w208.offline.message")
                if case .cached(let date) = state {
                    (Text("searchMap.w208.offline.cachedAt") + Text(verbatim: " ") + Text(date, format: .dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("searchMap.w208.offline.cachedAt")
                }
                if stillOffline {
                    Text("searchMap.w208.offline.stillOffline").font(.caption)
                        .foregroundStyle(CYColor.warningText)
                        .accessibilityIdentifier("searchMap.w208.offline.stillOffline")
                }
                Button("searchMap.w208.offline.retry", action: retry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("searchMap.w208.offline.retry")
                    .accessibilityLabel(Text("searchMap.w208.offline.retry"))
                    .accessibilityValue(spokenCache)
                    .accessibilityHint(Text(LocalizedStringKey(stillOffline ? "searchMap.w208.offline.stillOffline" : key)))
              }.frame(maxWidth: .infinity, alignment: .leading)
            }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(LocalizedStringKey(key)))
                .accessibilityValue(spokenCache)
                .accessibilityHint(Text(LocalizedStringKey(stillOffline ? "searchMap.w208.offline.stillOffline" : key)))
                .accessibilityIdentifier("searchMap.w208.offline")
        }
    }

    /// No cached clock is unknown. A shown time stays the clock already on the bar.
    private var spokenCache: Text {
        if case .cached(let date) = state {
            return Text(date, format: .dateTime.hour().minute())
        }
        return Text(verbatim: "—")
    }
}
