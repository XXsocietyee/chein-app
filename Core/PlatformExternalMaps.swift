import Foundation
import Observation

public struct PlatformMapDestination: Equatable, Sendable {
    public let name: String
    public let address: String?
    public let latitude: Double?
    public let longitude: Double?
    public init(name: String, address: String? = nil, latitude: Double?, longitude: Double?) {
        self.name = name; self.address = address; self.latitude = latitude; self.longitude = longitude
    }
    public var hasCoordinates: Bool {
        guard let latitude, let longitude else { return false }
        // Preserve source's zero sentinel (either axis); additionally reject out-of-range values.
        return latitude.isFinite && longitude.isFinite && latitude != 0 && longitude != 0 && abs(latitude) <= 90 && abs(longitude) <= 180
    }
    public var copyText: String {
        let address = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name + " " + (address.isEmpty ? "\(latitude.map { String($0) } ?? "") , \(longitude.map { String($0) } ?? "")" : address)
    }
}
public enum PlatformMapState: Equatable { case gated, idle, opening, opened, noCoordinates, copied, launchFailed, copyFailed }
/// P1-21: MP `wx.openLocation` lets the player pick Apple Maps, AMap or Baidu Maps; native lists the installed ones.
public enum PlatformMapApp: String, CaseIterable, Sendable {
    case apple, amap, baidu
    /// Query scheme for `canOpenURL` (listed in Info.plist `LSApplicationQueriesSchemes`); Apple Maps needs none.
    public var queryScheme: String? {
        switch self {
        case .apple: return nil
        case .amap: return "iosamap"
        case .baidu: return "baidumap"
        }
    }
}
extension PlatformMapDestination {
    /// Walking directions to this destination in a third-party map app. Roam coordinates are GCJ-02 (MP `gcj02`),
    /// which AMap (`dev=0`) and Baidu (`coord_type=gcj02`) take as-is. Apple Maps opens through MapKit, so nil.
    public func launchURL(in app: PlatformMapApp) -> URL? {
        guard hasCoordinates, let latitude, let longitude else { return nil }
        var components = URLComponents()
        switch app {
        case .apple:
            return nil
        case .amap:
            components.scheme = "iosamap"
            components.host = "path"
            components.queryItems = [
                URLQueryItem(name: "sourceApplication", value: "Chein"),
                URLQueryItem(name: "dlat", value: String(latitude)),
                URLQueryItem(name: "dlon", value: String(longitude)),
                URLQueryItem(name: "dname", value: name),
                URLQueryItem(name: "dev", value: "0"),
                URLQueryItem(name: "t", value: "2")
            ]
        case .baidu:
            components.scheme = "baidumap"
            components.host = "map"
            components.path = "/direction"
            let target = "latlng:" + String(latitude) + "," + String(longitude) + "|name:" + name
            components.queryItems = [
                URLQueryItem(name: "destination", value: target),
                URLQueryItem(name: "coord_type", value: "gcj02"),
                URLQueryItem(name: "mode", value: "walking"),
                URLQueryItem(name: "src", value: "ios.chein.roam")
            ]
        }
        return components.url
    }
}
@MainActor public protocol PlatformMapOpening {
    func open(_ destination: PlatformMapDestination) async -> Bool
    func installedApps() -> [PlatformMapApp]
    func open(_ destination: PlatformMapDestination, in app: PlatformMapApp) async -> Bool
}
@MainActor extension PlatformMapOpening {
    public func installedApps() -> [PlatformMapApp] { [.apple] }
    public func open(_ destination: PlatformMapDestination, in app: PlatformMapApp) async -> Bool {
        guard app == .apple else { return false }
        return await open(destination)
    }
}
@MainActor public protocol PlatformAddressCopying { func copy(_ text: String) throws }
@MainActor @Observable public final class PlatformExternalMaps {
    public private(set) var state: PlatformMapState = .gated
    public private(set) var selected: PlatformMapDestination?
    private let opener: any PlatformMapOpening
    private let copier: any PlatformAddressCopying
    private let enabled: Bool
    private var generation = 0
    public init(opener: any PlatformMapOpening, copier: any PlatformAddressCopying, enabled: Bool = false) {
        self.opener = opener; self.copier = copier; self.enabled = enabled
    }
    public func select(_ destination: PlatformMapDestination?) { generation += 1; selected = destination; state = enabled ? .idle : .gated }
    /// Map apps the review dialog offers, Apple Maps first; empty while gated.
    public var apps: [PlatformMapApp] { enabled ? opener.installedApps() : [] }
    /// Only call after the user confirms this selected destination will be sent to Apple Maps.
    public func openReviewedDestination(_ destination: PlatformMapDestination, in app: PlatformMapApp = .apple) async {
        guard enabled, selected == destination, state != .opening else { return }
        guard destination.hasCoordinates else { state = .noCoordinates; return }
        generation += 1; let token = generation; state = .opening
        let opened = await opener.open(destination, in: app)
        guard token == generation, selected == destination else { return }
        state = opened ? .opened : .launchFailed
        // Copy is a separate explicit action: no silent clipboard mutation.
    }
    public func copySelectedAddress() {
        guard enabled, let selected else { return }
        do { try copier.copy(selected.copyText); state = .copied } catch { state = .copyFailed }
    }
    public func invalidate() { generation += 1; selected = nil; state = enabled ? .idle : .gated }
}
@MainActor public final class SyntheticPlatformMapAdapter: PlatformMapOpening, PlatformAddressCopying {
    public var result = false
    public var failCopy = false
    public var installed: [PlatformMapApp] = [.apple]
    public private(set) var opened: [PlatformMapDestination] = []
    public private(set) var openedApps: [PlatformMapApp] = []
    public private(set) var copied: [String] = []
    public init() {}
    public func open(_ destination: PlatformMapDestination) async -> Bool { opened.append(destination); return result }
    public func installedApps() -> [PlatformMapApp] { installed }
    public func open(_ destination: PlatformMapDestination, in app: PlatformMapApp) async -> Bool {
        openedApps.append(app); opened.append(destination); return result
    }
    public func copy(_ text: String) throws { if failCopy { throw CocoaError(.fileWriteUnknown) }; copied.append(text) }
}
